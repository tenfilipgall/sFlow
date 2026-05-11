import AppKit
import Foundation

enum ElectronShortcutScanner {

    // MARK: - Notion-style web shortcut extraction

    // Patterns for {id:"xxx", ..., defaultKeyCombination:[...]} registries
    private static let notionIdPattern = try! NSRegularExpression(pattern: #"id:"([^"]+)""#)
    private static let notionComboPattern = try! NSRegularExpression(
        pattern: #"defaultKeyCombination:\[([^\]]{1,200})\]"#)
    private static let quotedStringInArray = try! NSRegularExpression(pattern: #""([^"]+)""#)

    /// Parses a web-style key combination like `"command+alt+g"` → `["meta","alt","g"]`.
    static func parseWebKeyCombo(_ combo: String) -> [String] {
        combo.components(separatedBy: "+").compactMap { part in
            switch part.lowercased() {
            case "command", "cmd":   return "meta"
            case "ctrl", "control": return "ctrl"
            case "shift":           return "shift"
            case "alt", "option":   return "alt"
            case let k where k.count == 1: return k
            default: return nil
            }
        }
    }

    private static let notionDescPattern = try! NSRegularExpression(
        pattern: #"description:"([^"]{2,80})""#)

    /// Parses Notion-style shortcut registries found in cached web JS:
    /// `{id:"openSlipperySlopeHomeTab",...,defaultKeyCombination:[t.isApple?"command+alt+g":"ctrl+alt+g"]}`
    /// Always picks the first (Apple/Mac) key combo from ternary expressions.
    /// Returns `[shortcutId → keys]`.
    static func extractNotionStyleShortcuts(from text: String) -> [String: [String]] {
        var result: [String: [String]] = [:]
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        for idMatch in notionIdPattern.matches(in: text, range: full) {
            guard let idRange = Range(idMatch.range(at: 1), in: text) else { continue }
            let shortcutId = String(text[idRange])

            let searchStart = idMatch.range.upperBound
            let searchLen = min(400, ns.length - searchStart)
            guard searchLen > 0 else { continue }
            let searchRange = NSRange(location: searchStart, length: searchLen)

            guard let comboMatch = notionComboPattern.firstMatch(in: text, range: searchRange),
                  let comboRange = Range(comboMatch.range(at: 1), in: text) else { continue }

            let comboStr = String(text[comboRange])
            guard let qMatch = quotedStringInArray.firstMatch(
                      in: comboStr,
                      range: NSRange(comboStr.startIndex..., in: comboStr)),
                  let qRange = Range(qMatch.range(at: 1), in: comboStr) else { continue }

            let keys = parseWebKeyCombo(String(comboStr[qRange]))
            let modifierOnly: Set<String> = ["meta", "ctrl", "shift", "alt"]
            guard !keys.isEmpty, keys.contains(where: { !modifierOnly.contains($0) }) else { continue }

            if result[shortcutId] == nil { result[shortcutId] = keys }
        }

        return result
    }

    /// Like `extractNotionStyleShortcuts` but also extracts `description:` and converts to
    /// `[lookupKey → MenuBarEntry]` ready to merge directly into `MenuBarIndex`.
    ///
    /// Scans the text in source order. First definition for a given lookup key wins, matching
    /// the across-file merge policy. Sidebar-specific shortcuts (e.g. openSlipperySlopeHomeTab)
    /// appear earlier in the JS file than generic synonyms (openHome), so first-wins is correct.
    ///
    /// Lookup key = first "significant" word from the description (4+ chars, not a stop word).
    /// Example: "Open home tab in slippery slope sidebar" → "home"
    static func extractNotionStyleEntries(from text: String) -> [String: MenuBarEntry] {
        let stopWords: Set<String> = [
            "open", "toggle", "close", "show", "hide", "create", "new",
            "the", "in", "of", "tab", "page", "a", "an", "at", "for",
            "all", "both", "with", "from", "to", "and", "or",
        ]
        let modifierOnly: Set<String> = ["meta", "ctrl", "shift", "alt"]

        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        var result: [String: MenuBarEntry] = [:]

        // Single pass in source order so later entries (slippery slope) override earlier ones
        for idMatch in notionIdPattern.matches(in: text, range: full) {
            let searchStart = idMatch.range.upperBound
            let searchLen = min(400, ns.length - searchStart)
            guard searchLen > 0 else { continue }
            let searchRange = NSRange(location: searchStart, length: searchLen)

            // Must have defaultKeyCombination
            guard let comboMatch = notionComboPattern.firstMatch(in: text, range: searchRange),
                  let comboRange = Range(comboMatch.range(at: 1), in: text) else { continue }
            let comboStr = String(text[comboRange])
            guard let qMatch = quotedStringInArray.firstMatch(
                      in: comboStr, range: NSRange(comboStr.startIndex..., in: comboStr)),
                  let qRange = Range(qMatch.range(at: 1), in: comboStr) else { continue }
            let keys = parseWebKeyCombo(String(comboStr[qRange]))
            guard !keys.isEmpty, keys.contains(where: { !modifierOnly.contains($0) }) else { continue }

            // Extract description (optional — fall back to id)
            var rawDesc: String
            if let dm = notionDescPattern.firstMatch(in: text, range: searchRange),
               let dr = Range(dm.range(at: 1), in: text) {
                rawDesc = String(text[dr])
            } else if let idRange = Range(idMatch.range(at: 1), in: text) {
                rawDesc = String(text[idRange])
            } else { continue }

            let words = rawDesc.lowercased().components(separatedBy: " ")
            let key = words.first(where: { $0.count >= 4 && !stopWords.contains($0) })
                ?? rawDesc.lowercased()
            let hint = words
                .filter { $0.count >= 3 && !stopWords.contains($0) }
                .prefix(3)
                .map { $0.capitalized }
                .joined(separator: " ")

            if result[key] == nil {
                result[key] = MenuBarEntry(keys: keys, hint: hint.isEmpty ? rawDesc : hint)
            }
        }
        return result
    }

    // MARK: - Service Worker cache scanning

    /// Scans an Electron app's Chromium service worker cache for Notion-style shortcut definitions.
    ///
    /// Cache layout (Notion / Slack style):
    ///   `~/Library/Application Support/<AppName>/Partitions/<p>/Service Worker/CacheStorage/<h1>/<h2>/*_0`
    ///
    /// Each `*_0` file = 24-byte binary header + URL string + raw JS content (no HTTP headers).
    /// Files with `defaultKeyCombination` are parsed via `extractNotionStyleEntries`.
    ///
    /// Returns `[lookupKey → MenuBarEntry]` ready to merge into `MenuBarIndex`.
    static func scanServiceWorkerCache(appName: String) -> [String: MenuBarEntry] {
        let fm = FileManager.default
        let support = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(appName)")

        var swRoots: [URL] = []

        let directSW = support.appendingPathComponent("Service Worker/CacheStorage")
        if fm.fileExists(atPath: directSW.path) { swRoots.append(directSW) }

        let partitionsDir = support.appendingPathComponent("Partitions")
        if let parts = try? fm.contentsOfDirectory(at: partitionsDir, includingPropertiesForKeys: nil) {
            for part in parts {
                let sw = part.appendingPathComponent("Service Worker/CacheStorage")
                if fm.fileExists(atPath: sw.path) { swRoots.append(sw) }
            }
        }

        var result: [String: MenuBarEntry] = [:]

        for root in swRoots {
            guard let outerDirs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for outer in outerDirs {
                guard let innerDirs = try? fm.contentsOfDirectory(at: outer, includingPropertiesForKeys: nil) else { continue }
                for inner in innerDirs {
                    let sizeKey = URLResourceKey.fileSizeKey
                    guard let files = try? fm.contentsOfDirectory(at: inner, includingPropertiesForKeys: [sizeKey]) else { continue }
                    for file in files where file.lastPathComponent.hasSuffix("_0") {
                        guard let attrs = try? file.resourceValues(forKeys: [sizeKey]),
                              let size = attrs.fileSize,
                              size > 1_000, size < 1_000_000 else { continue }
                        guard let data = fm.contents(atPath: file.path) else { continue }
                        let text = String(decoding: data, as: UTF8.self)
                        guard text.contains("defaultKeyCombination") else { continue }
                        let found = extractNotionStyleEntries(from: text)
                        for (k, v) in found where result[k] == nil { result[k] = v }
                    }
                }
            }
        }

        return result
    }

    /// Convenience overload using `NSRunningApplication.localizedName`.
    static func scanServiceWorkerCache(app: NSRunningApplication) -> [String: MenuBarEntry] {
        guard let name = app.localizedName else { return [:] }
        return scanServiceWorkerCache(appName: name)
    }

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
