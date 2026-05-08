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
                guard !keys.isEmpty else { continue }

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
}
