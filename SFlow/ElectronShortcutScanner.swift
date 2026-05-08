import AppKit
import Foundation

enum ElectronShortcutScanner {

    // MARK: - Regex extraction

    private static let acceleratorPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"accelerator:\s*['"]([^'"]+)['"]"#),
        try! NSRegularExpression(pattern: #"shortcut:\s*['"]([^'"]+)['"]"#),
        try! NSRegularExpression(pattern: #"registerShortcut\(['"]([^'"]+)['"]"#),
    ]

    private static let labelPattern = try! NSRegularExpression(
        pattern: #"(?:label|title):\s*['"]([^'"]{2,50})['"]"#)

    /// Scans `text` for Electron accelerator patterns, searching backwards for a label/title.
    /// Only adds entries where a label was found (label becomes the lookup key).
    static func extractShortcuts(from text: String, into result: inout [String: MenuBarEntry]) {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        for pattern in acceleratorPatterns {
            for match in pattern.matches(in: text, range: fullRange) {
                guard let accelRange = Range(match.range(at: 1), in: text) else { continue }
                let accelerator = String(text[accelRange])
                let keys = BundleStringsScanner.parseElectronAccelerator(accelerator)
                let modifiers: Set<String> = ["meta", "ctrl", "shift", "alt"]
                guard keys.contains(where: { !modifiers.contains($0) }) else { continue }

                // Search backwards up to 200 chars for label:/title:
                let matchStart = match.range.location
                let searchStart = max(0, matchStart - 200)
                let searchRange = NSRange(location: searchStart, length: matchStart - searchStart)
                let labelMatches = labelPattern.matches(in: text, range: searchRange)
                guard let labelMatch = labelMatches.last,
                      let labelRange = Range(labelMatch.range(at: 1), in: text) else { continue }

                let hint = String(text[labelRange])
                let key = hint.lowercased()
                if result[key] == nil {
                    result[key] = MenuBarEntry(keys: keys, hint: hint)
                }
            }
        }
    }

    // MARK: - Electron detection

    static func isElectronApp(_ app: NSRunningApplication) -> Bool {
        guard let url = app.bundleURL else { return false }
        return isElectronBundle(at: url)
    }

    static func isElectronBundle(at bundleURL: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: bundleURL.appendingPathComponent("Contents/Resources/app.asar").path)
    }

    // MARK: - Scan entry points

    static func scan(app: NSRunningApplication) -> [String: MenuBarEntry] {
        guard let bundleURL = app.bundleURL else { return [:] }
        return scanASAR(at: bundleURL.appendingPathComponent("Contents/Resources/app.asar"))
    }

    static func scanASAR(at url: URL) -> [String: MenuBarEntry] {
        guard let (allFiles, dataOffset) = AsarReader.readHeader(from: url) else { return [:] }

        let jsFiles = allFiles.filter {
            $0.path.hasSuffix(".js") && !$0.path.hasPrefix("node_modules/")
        }

        // Targeted pass: files whose path contains shortcut-related keywords
        let keywords = ["shortcut", "keyboard", "keybind", "hotkey", "accelerator", "keymap"]
        let targeted = jsFiles.filter { file in
            let lower = file.path.lowercased()
            return keywords.contains(where: { lower.contains($0) })
        }

        var result: [String: MenuBarEntry] = [:]
        for file in targeted {
            if let data = AsarReader.readFile(file, in: url, dataOffset: dataOffset),
               let text = String(data: data, encoding: .utf8) {
                extractShortcuts(from: text, into: &result)
            }
        }
        if !result.isEmpty { return result }

        // Broad fallback: largest JS files up to 500KB, max 30
        let broad = jsFiles
            .filter { $0.size <= 500_000 }
            .sorted { $0.size > $1.size }
            .prefix(30)

        for file in broad {
            if let data = AsarReader.readFile(file, in: url, dataOffset: dataOffset),
               let text = String(data: data, encoding: .utf8) {
                extractShortcuts(from: text, into: &result)
            }
        }
        return result
    }
}
