import Foundation

/// Pure filter deciding whether a candidate tooltip name is a real UI action
/// label (e.g. "Compose", "Mark unread") versus generic meta-text that
/// `TooltipObserver` picked up by accident (e.g. "shortcut", "hotkey",
/// "press 2 to continue").
///
/// Background: empirical analysis of `events.jsonl` 2026-05-16 showed 4
/// false-positive L0.3 toasts in Perplexity Comet with `hint="shortcut"
/// keys=["2"]` — the observer matched a help-overlay element where one
/// AXStaticText said "shortcut" and another said "2". This filter rejects
/// such candidates before they reach `DiscoveredStore`.
///
/// Strategy:
///   1. Reject names that are meta-words ("shortcut", "hotkey", ...).
///   2. Single-word names must be on a whitelist of known UI verbs. Multi-word
///      names are accepted on the assumption they describe an action ("Mark
///      unread", "Reply to thread", "Save for later").
///
/// Integration point: call `isAcceptableActionName(_:)` from `TooltipObserver`
/// before recording a candidate into `DiscoveredStore`. Returns `false` →
/// drop the candidate silently.
enum TooltipNameFilter {

    /// Words that almost always indicate help/diagnostic UI rather than an
    /// actionable button label. Case-insensitive match against the full
    /// trimmed name (single word).
    static let bannedNames: Set<String> = [
        "shortcut", "shortcuts",
        "hotkey", "hotkeys",
        "key", "keys", "keyboard", "kb",
        "press", "click", "tap",
        "hint", "tip", "info",
        "help",
    ]

    /// Single-word action labels that legitimately appear as tooltip names
    /// in real apps. Used to reject one-off single words that aren't on the
    /// list (which are more likely noise than a real action).
    static let whitelistedSingleWords: Set<String> = [
        "reply", "forward", "compose", "archive", "delete", "remove",
        "save", "search", "find", "send", "edit", "share",
        "open", "close", "new", "copy", "paste", "cut",
        "undo", "redo", "back", "next", "previous", "refresh", "reload",
        "settings", "preferences",
        "play", "pause", "stop", "record",
        "expand", "collapse", "minimize", "maximize",
        "favorite", "favourite", "star", "pin", "unpin",
        "duplicate", "rename", "move",
        "comment", "react", "mention",
        "download", "upload", "import", "export",
        "today", "yesterday", "tomorrow",
    ]

    /// Returns true if `name` is a plausible UI action label suitable for
    /// recording as a discovered shortcut name.
    static func isAcceptableActionName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        if trimmed.count > 60 { return false }

        let lc = trimmed.lowercased()
        if bannedNames.contains(lc) { return false }

        let hasSpace = trimmed.contains(" ")
        if hasSpace {
            return true
        }

        return whitelistedSingleWords.contains(lc)
    }
}
