import Foundation
import AppKit

enum BundleStringsScanner {

    /// Scans the app bundle's .strings files and extracts shortcut hints found in comments.
    /// Returns a dict of lowercased title → MenuBarEntry, to be merged into MenuBarCache.
    static func scan(app: NSRunningApplication) -> [String: MenuBarEntry] {
        guard let bundleURL = app.bundleURL else { return [:] }

        let lprojs = ["en.lproj", "Base.lproj", "English.lproj"]
        let candidates = ["MainMenu.strings", "Localizable.strings", "Actions.strings"]

        var result: [String: MenuBarEntry] = [:]
        for lproj in lprojs {
            for candidate in candidates {
                let url = bundleURL
                    .appendingPathComponent("Contents/Resources")
                    .appendingPathComponent(lproj)
                    .appendingPathComponent(candidate)
                if let found = parseStringsFile(at: url) {
                    result.merge(found) { existing, _ in existing }
                }
            }
        }
        return result
    }

    // MARK: - Internal

    private static func parseStringsFile(at url: URL) -> [String: MenuBarEntry]? {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var result: [String: MenuBarEntry] = [:]
        var lastComment = ""

        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Capture comments: /* ... */
            if trimmed.hasPrefix("/*"), trimmed.hasSuffix("*/") {
                lastComment = String(trimmed.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
                continue
            }

            // Parse key = value; lines
            guard trimmed.contains(" = "),
                  let eqRange = trimmed.range(of: " = ") else { lastComment = ""; continue }

            let key = String(trimmed[..<eqRange.lowerBound])
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                .lowercased()

            if !lastComment.isEmpty,
               let keys = extractShortcutFromComment(lastComment) {
                result[key] = MenuBarEntry(keys: keys, hint: key)
            }
            lastComment = ""
        }
        return result.isEmpty ? nil : result
    }

    /// Extracts a shortcut from comment strings like:
    /// "Keyboard shortcut: cmd+n", "key: ⌘N", "hotkey: CmdOrCtrl+K"
    private static func extractShortcutFromComment(_ comment: String) -> [String]? {
        let lower = comment.lowercased()
        guard lower.contains("shortcut") || lower.contains("hotkey") ||
              lower.contains("key:") || lower.contains("accelerator") else { return nil }

        // Try parsing Unicode modifier symbols first
        if let keys = ShortcutRules.parseShortcut(from: comment) { return keys }

        // Try Electron-style: CmdOrCtrl+K, Ctrl+Shift+F
        let electronPattern = #"(?:CmdOrCtrl|Cmd|Command|Ctrl|Control|Shift|Alt|Option)\+[A-Za-z]"#
        if let regex = try? NSRegularExpression(pattern: electronPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: comment, range: NSRange(comment.startIndex..., in: comment)),
           let range = Range(match.range, in: comment) {
            return parseElectronAccelerator(String(comment[range]))
        }
        return nil
    }

    static func parseElectronAccelerator(_ acc: String) -> [String] {
        let parts = acc.components(separatedBy: "+")
        return parts.compactMap { part in
            switch part.lowercased() {
            case "cmdorctrl", "cmd", "command": return "meta"
            case "ctrl", "control":             return "ctrl"
            case "shift":                       return "shift"
            case "alt", "option":               return "alt"
            default: return part.count == 1 ? part.lowercased() : nil
            }
        }
    }
}
