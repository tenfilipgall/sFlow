import Foundation

/// Parses the "badge" portion of a Notion-style tooltip — the short hint
/// containing the keyboard shortcut for the action being hovered.
///
/// Examples:
///   "C"   → ["c"]
///   "⌘\\" → ["meta", "\\"]
///   "⇧R"  → ["shift", "r"]
///   "⌘⇧K" → ["meta", "shift", "k"]
///   ""    → nil
///   "Compose" → nil (too long to be a badge)
///
/// Rejects strings longer than 6 chars (real badges are tight) and strings
/// containing only modifier symbols (no actual key produced).
enum TooltipShortcutParser {

    private static let modifierSymbols: [Character: String] = [
        "⌘": "meta", "⇧": "shift", "⌥": "alt", "⌃": "ctrl"
    ]

    private static let punctuationKeys: Set<Character> = ["\\", ",", ".", ";", "'", "/", "[", "]", "`", "-", "="]

    /// Characters used as visual separators between modifier and key — silently skipped.
    /// Notion Mail writes "⌘+\\" or "⌘ +\\"; some apps use middle dot " · " or spaces.
    private static let separatorChars: Set<Character> = ["+", " ", "·", "‧"]

    static func parseBadge(_ text: String) -> [String]? {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, s.count <= 8 else { return nil }

        var keys: [String] = []
        var keyCount = 0
        for ch in s {
            if separatorChars.contains(ch) {
                continue
            } else if let mod = modifierSymbols[ch] {
                if keyCount > 0 { return nil }
                keys.append(mod)
            } else if ch.isLetter {
                if keyCount > 0 { return nil }
                keys.append(String(ch).lowercased())
                keyCount += 1
            } else if ch.isNumber {
                if keyCount > 0 { return nil }
                keys.append(String(ch))
                keyCount += 1
            } else if punctuationKeys.contains(ch) {
                if keyCount > 0 { return nil }
                keys.append(String(ch))
                keyCount += 1
            } else {
                return nil
            }
        }
        guard keyCount == 1 else { return nil }
        return keys
    }
}
