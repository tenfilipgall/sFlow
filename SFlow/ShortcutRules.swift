import ApplicationServices
import Foundation

struct ClickRule {
    let role: String?
    let subroleEquals: String?
    let descContains: String?
    let titleContains: String?
    let placeholderContains: String?
    let helpContains: String?
    let identifierContains: String?
    let shortcutId: String
    let keys: [String]
    let hint: String

    init(_ role: String? = nil, sub: String? = nil, desc: String? = nil,
         title: String? = nil, ph: String? = nil, help: String? = nil,
         identifier: String? = nil,
         id: String, keys: [String], hint: String) {
        self.role = role; self.subroleEquals = sub
        self.descContains = desc; self.titleContains = title
        self.placeholderContains = ph; self.helpContains = help
        self.identifierContains = identifier
        self.shortcutId = id; self.keys = keys; self.hint = hint
    }
}

enum ShortcutRules {

    // MARK: - Public API

    static func match(element: AXUIElement, bundleId: String,
                      role roleRef: AnyObject?, desc descRef: AnyObject?,
                      title titleRef: AnyObject?, subrole subroleRef: AnyObject?,
                      placeholder placeholderRef: AnyObject?, help helpRef: AnyObject?,
                      identifier: String = ""
    ) -> (rule: ClickRule, confidence: MatchConfidence)? {
        guard let appRules = rules[bundleId] else { return nil }

        let role        = roleRef        as? String ?? ""
        let desc        = (descRef        as? String ?? "").lowercased()
        let title       = (titleRef       as? String ?? "").lowercased()
        let subrole     = subroleRef     as? String ?? ""
        let placeholder = (placeholderRef as? String ?? "").lowercased()
        let help        = (helpRef        as? String ?? "").lowercased()

        for rule in appRules {
            if let r = rule.role,               role        != r                          { continue }
            if let s = rule.subroleEquals,       subrole     != s                          { continue }
            if let d = rule.descContains,        !desc.contains(d.lowercased())            { continue }
            if let t = rule.titleContains,       !title.contains(t.lowercased())           { continue }
            if let p = rule.placeholderContains, !placeholder.contains(p.lowercased())     { continue }
            if let h = rule.helpContains,        !help.contains(h.lowercased())            { continue }
            if let i = rule.identifierContains,  !identifier.contains(i.lowercased())      { continue }
            return (rule: rule, confidence: .high)
        }
        return nil
    }

    /// Parses the first shortcut from arbitrary text using three strategies:
    ///
    /// 1. Modifier + key: "Quick Find ⌘K" → ["meta", "k"]
    /// 2. Single-char help: "e" → ["e"] (only exact single letter)
    /// 3. Single-key pattern: "Archive (E)" / "Today [T]" / "Reply — R"
    static func parseShortcut(from text: String) -> [String]? {
        let modMap: [Character: String] = ["⌘": "meta", "⇧": "shift", "⌥": "alt", "⌃": "ctrl"]

        // Strategy 1: modifier symbol(s) + letter/digit
        var i = text.startIndex
        while i < text.endIndex {
            guard modMap[text[i]] != nil else { i = text.index(after: i); continue }
            var mods: [String] = []
            var j = i
            while j < text.endIndex, let m = modMap[text[j]] { mods.append(m); j = text.index(after: j) }
            guard j < text.endIndex else { break }
            let ch = text[j]
            guard ch.isLetter || ch.isNumber else { i = text.index(after: i); continue }
            return mods + [String(ch).lowercased()]
        }

        // Strategy 2: raw single-char help — kAXHelp contains exactly one letter
        if text.count == 1, let ch = text.first, ch.isLetter {
            return [String(ch).lowercased()]
        }

        // Strategy 3: single-key patterns — (E), [E], — E, or trailing " E"
        let singleKeyPattern = #"[\(\[\-\s]([A-Z])[\)\]\s]?$"#
        if let regex = try? NSRegularExpression(pattern: singleKeyPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges > 1,
           let keyRange = Range(match.range(at: 1), in: text) {
            return [String(text[keyRange]).lowercased()]
        }

        return nil
    }

    // MARK: - Universal role-based rules (#4 — semantic heuristics)

    static let universalRules: [ClickRule] = [
        // Search fields — ⌘F is the macOS standard
        .init("AXTextField", sub: "AXSearchField",
              id: "universal-search", keys: ["meta", "f"], hint: "Search / Find"),
        .init(nil, sub: "AXSearchField",
              id: "universal-search", keys: ["meta", "f"], hint: "Search / Find"),

        // Navigation
        .init("AXButton", desc: "back",
              id: "universal-back", keys: ["meta", "arrowleft"], hint: "Go Back"),
        .init("AXButton", desc: "forward",
              id: "universal-forward", keys: ["meta", "arrowright"], hint: "Go Forward"),
        .init("AXButton", desc: "go back",
              id: "universal-back", keys: ["meta", "arrowleft"], hint: "Go Back"),
        .init("AXButton", desc: "go forward",
              id: "universal-forward", keys: ["meta", "arrowright"], hint: "Go Forward"),
        .init("AXButton", desc: "reload",
              id: "universal-reload", keys: ["meta", "r"], hint: "Reload"),
        .init("AXButton", desc: "refresh",
              id: "universal-reload", keys: ["meta", "r"], hint: "Reload"),

        // Tabs & windows
        .init("AXButton", desc: "close tab",
              id: "universal-close-tab", keys: ["meta", "w"], hint: "Close Tab"),
        .init("AXButton", desc: "new tab",
              id: "universal-new-tab", keys: ["meta", "t"], hint: "New Tab"),
        .init("AXButton", desc: "new window",
              id: "universal-new-window", keys: ["meta", "n"], hint: "New Window"),
        .init("AXButton", desc: "print",
              id: "universal-print", keys: ["meta", "p"], hint: "Print"),
        .init("AXButton", desc: "share",
              id: "universal-share", keys: ["meta", "shift", "i"], hint: "Share"),

        // Settings — ⌘, is the macOS HIG standard for every app
        .init("AXButton", desc: "settings",
              id: "universal-settings", keys: ["meta", ","], hint: "Settings"),
        .init("AXButton", desc: "preferences",
              id: "universal-settings", keys: ["meta", ","], hint: "Preferences"),
        .init(title: "settings",
              id: "universal-settings", keys: ["meta", ","], hint: "Settings"),
        .init(title: "preferences",
              id: "universal-settings", keys: ["meta", ","], hint: "Preferences"),

        // Messaging / chat — send button pattern across apps
        .init("AXButton", desc: "send",
              id: "universal-send", keys: ["meta", "enter"], hint: "Send"),
        .init(title: "send",
              id: "universal-send", keys: ["meta", "enter"], hint: "Send"),

        // Compose / new conversation — ⌘N is the macOS standard for "new thing"
        .init("AXButton", desc: "compose",
              id: "universal-compose", keys: ["meta", "n"], hint: "New Message"),
        .init("AXButton", desc: "new message",
              id: "universal-compose", keys: ["meta", "n"], hint: "New Message"),
        .init("AXButton", desc: "new conversation",
              id: "universal-compose", keys: ["meta", "n"], hint: "New Conversation"),
        .init(title: "compose",
              id: "universal-compose", keys: ["meta", "n"], hint: "New Message"),

        // Email reply patterns
        .init("AXButton", desc: "reply",
              id: "universal-reply", keys: ["meta", "r"], hint: "Reply"),
        .init(title: "reply",
              id: "universal-reply", keys: ["meta", "r"], hint: "Reply"),
        .init("AXButton", desc: "reply all",
              id: "universal-reply-all", keys: ["meta", "shift", "r"], hint: "Reply All"),
        .init(title: "reply all",
              id: "universal-reply-all", keys: ["meta", "shift", "r"], hint: "Reply All"),
    ]

    // MARK: - Rules Database

    static let rules: [String: [ClickRule]] = [

        // ── Slack ─────────────────────────────────────────────────────────
        "com.tinyspeck.slackmacgap": [
            .init("AXTextField", sub: "AXSearchField",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(ph: "jump to",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(ph: "find a conversation",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(ph: "search slack",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(desc: "search",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(desc: "jump to",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(desc: "find a conversation",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(desc: "quick switcher",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(title: "search",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(title: "jump to",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(desc: "direct messages",
                  id: "slack-browse-dms", keys: ["meta","shift","k"], hint: "Browse DMs"),
            .init(title: "direct messages",
                  id: "slack-browse-dms", keys: ["meta","shift","k"], hint: "Browse DMs"),
            .init(desc: "dms",
                  id: "slack-browse-dms", keys: ["meta","shift","k"], hint: "Browse DMs"),
            .init(desc: "compose",
                  id: "slack-compose", keys: ["meta","n"], hint: "New Message"),
            .init(desc: "new message",
                  id: "slack-compose", keys: ["meta","n"], hint: "New Message"),
            .init(title: "compose",
                  id: "slack-compose", keys: ["meta","n"], hint: "New Message"),
            .init(title: "new message",
                  id: "slack-compose", keys: ["meta","n"], hint: "New Message"),
            .init(desc: "all unreads",
                  id: "slack-all-unreads", keys: ["meta","shift","a"], hint: "All Unreads"),
            .init(desc: "unreads",
                  id: "slack-all-unreads", keys: ["meta","shift","a"], hint: "All Unreads"),
            .init(title: "all unreads",
                  id: "slack-all-unreads", keys: ["meta","shift","a"], hint: "All Unreads"),
            .init(desc: "mentions",
                  id: "slack-mentions", keys: ["meta","shift","m"], hint: "Mentions & Reactions"),
            .init(desc: "activity",
                  id: "slack-mentions", keys: ["meta","shift","m"], hint: "Mentions & Reactions"),
            .init(desc: "notifications",
                  id: "slack-mentions", keys: ["meta","shift","m"], hint: "Mentions & Reactions"),
            .init(title: "mentions",
                  id: "slack-mentions", keys: ["meta","shift","m"], hint: "Mentions & Reactions"),
            .init(desc: "set a status",
                  id: "slack-set-status", keys: ["meta","shift","y"], hint: "Set Your Status"),
            .init(desc: "status",
                  id: "slack-set-status", keys: ["meta","shift","y"], hint: "Set Your Status"),
            .init(desc: "conversation details",
                  id: "slack-convo-details", keys: ["meta","shift","i"], hint: "Conversation Details"),
            .init(title: "conversation details",
                  id: "slack-convo-details", keys: ["meta","shift","i"], hint: "Conversation Details"),
            .init(desc: "saved items",
                  id: "slack-saved", keys: ["meta","shift","s"], hint: "Saved Items"),
            .init(title: "saved items",
                  id: "slack-saved", keys: ["meta","shift","s"], hint: "Saved Items"),
            .init(desc: "bookmarks",
                  id: "slack-saved", keys: ["meta","shift","s"], hint: "Saved Items"),
            .init(desc: "browse channels",
                  id: "slack-browse-channels", keys: ["meta","shift","e"], hint: "Browse Channels"),
            .init(title: "browse channels",
                  id: "slack-browse-channels", keys: ["meta","shift","e"], hint: "Browse Channels"),
        ],

        // ── Notion ────────────────────────────────────────────────────────
        "notion.id": [
            // Sidebar nav items — placed first so they fire at depth 0 before any
            // ancestor container with "sidebar" in its description triggers the
            // generic toggle rule (openSlipperySlopeHomeTab / ChatsTab / MeetingsTab).
            .init(desc: "home",
                  id: "notion-home-tab", keys: ["meta","alt","g"], hint: "Home"),
            .init(title: "home",
                  id: "notion-home-tab", keys: ["meta","alt","g"], hint: "Home"),
            .init(desc: "chats with notion ai",
                  id: "notion-chats-tab", keys: ["meta","alt","k"], hint: "Chats with AI"),
            .init(desc: "chats",
                  id: "notion-chats-tab", keys: ["meta","alt","k"], hint: "Chats with AI"),
            .init(desc: "chat",
                  id: "notion-chats-tab", keys: ["meta","alt","k"], hint: "Chats with AI"),
            .init(title: "chats",
                  id: "notion-chats-tab", keys: ["meta","alt","k"], hint: "Chats with AI"),
            .init(desc: "meetings",
                  id: "notion-meetings-tab", keys: ["meta","alt","y"], hint: "Meetings"),
            .init(title: "meetings",
                  id: "notion-meetings-tab", keys: ["meta","alt","y"], hint: "Meetings"),
            .init(desc: "inbox",
                  id: "notion-inbox", keys: ["meta","alt","u"], hint: "Inbox"),
            .init(title: "inbox",
                  id: "notion-inbox", keys: ["meta","alt","u"], hint: "Inbox"),
            // Other actions
            .init(desc: "search",
                  id: "notion-quick-find", keys: ["meta","k"], hint: "Quick Find"),
            .init(desc: "quick find",
                  id: "notion-quick-find", keys: ["meta","k"], hint: "Quick Find"),
            .init(title: "new page",
                  id: "notion-new-page", keys: ["meta","n"], hint: "New Page"),
            // Toggle sidebar — specific text only, not the generic "sidebar" container desc
            .init(desc: "toggle sidebar",
                  id: "notion-toggle-sidebar", keys: ["meta","\\"], hint: "Toggle Sidebar"),
            .init(desc: "close sidebar",
                  id: "notion-toggle-sidebar", keys: ["meta","\\"], hint: "Toggle Sidebar"),
            .init(desc: "open sidebar",
                  id: "notion-toggle-sidebar", keys: ["meta","\\"], hint: "Toggle Sidebar"),
            // Navigation — Notion uses ⌘[ / ⌘] (browser-style), not ⌘←/⌘→
            .init(desc: "back",
                  id: "notion-go-back", keys: ["meta","["], hint: "Go Back"),
            .init(title: "back",
                  id: "notion-go-back", keys: ["meta","["], hint: "Go Back"),
            .init(desc: "forward",
                  id: "notion-go-forward", keys: ["meta","]"], hint: "Go Forward"),
            .init(title: "forward",
                  id: "notion-go-forward", keys: ["meta","]"], hint: "Go Forward"),
            .init(desc: "parent page",
                  id: "notion-go-up", keys: ["meta","shift","u"], hint: "Go Up"),
            .init(desc: "go up",
                  id: "notion-go-up", keys: ["meta","shift","u"], hint: "Go Up"),
            .init(title: "new tab",
                  id: "notion-new-tab", keys: ["meta","t"], hint: "New Tab"),
            .init(title: "new window",
                  id: "notion-new-window", keys: ["meta","shift","n"], hint: "New Window"),
            // Content actions
            .init(desc: "comment",
                  id: "notion-comment", keys: ["meta","shift","m"], hint: "Comment"),
            .init(title: "comment",
                  id: "notion-comment", keys: ["meta","shift","m"], hint: "Comment"),
            .init(desc: "edit block",
                  id: "notion-edit-block", keys: ["meta","/"], hint: "Edit Block"),
            .init(desc: "change block",
                  id: "notion-edit-block", keys: ["meta","/"], hint: "Edit Block"),
            .init(desc: "expand toggle",
                  id: "notion-toggle-expand", keys: ["meta","alt","t"], hint: "Expand/Close Toggles"),
            .init(desc: "collapse toggle",
                  id: "notion-toggle-expand", keys: ["meta","alt","t"], hint: "Expand/Close Toggles"),
            // Appearance
            .init(desc: "dark mode",
                  id: "notion-dark-mode", keys: ["meta","shift","l"], hint: "Toggle Dark/Light Mode"),
            .init(desc: "light mode",
                  id: "notion-dark-mode", keys: ["meta","shift","l"], hint: "Toggle Dark/Light Mode"),
        ],

        // ── Figma ─────────────────────────────────────────────────────────
        "com.figma.Desktop": [
            .init(desc: "search",
                  id: "figma-quick-actions", keys: ["meta","/"], hint: "Quick Actions"),
            .init(desc: "quick actions",
                  id: "figma-quick-actions", keys: ["meta","/"], hint: "Quick Actions"),
            .init(desc: "components",
                  id: "figma-quick-actions", keys: ["meta","/"], hint: "Quick Actions"),
            .init(desc: "layers",
                  id: "figma-layers-panel", keys: ["meta","alt","1"], hint: "Layers Panel"),
            .init(desc: "assets",
                  id: "figma-assets-panel", keys: ["meta","alt","2"], hint: "Assets Panel"),
        ],

        // ── VS Code ───────────────────────────────────────────────────────
        "com.microsoft.VSCode": [
            .init(desc: "command palette",
                  id: "vsc-palette", keys: ["meta","shift","p"], hint: "Command Palette"),
            .init(desc: "quick open",
                  id: "vsc-quick-open", keys: ["meta","p"], hint: "Quick Open File"),
            .init(desc: "explorer",
                  id: "vsc-explorer", keys: ["meta","shift","e"], hint: "Explorer Panel"),
            .init(desc: "search",
                  id: "vsc-find-in-files", keys: ["meta","shift","f"], hint: "Find in Files"),
            .init(desc: "source control",
                  id: "vsc-source-control", keys: ["meta","shift","g"], hint: "Source Control"),
            .init(desc: "terminal",
                  id: "vsc-terminal", keys: ["ctrl","`"], hint: "Toggle Terminal"),
            .init(desc: "extensions",
                  id: "vsc-extensions", keys: ["meta","shift","x"], hint: "Extensions"),
            .init(desc: "sidebar",
                  id: "vsc-sidebar", keys: ["meta","b"], hint: "Toggle Sidebar"),
        ],

        // ── Linear ────────────────────────────────────────────────────────
        "com.linear": [
            .init(desc: "search",
                  id: "linear-command-palette", keys: ["meta","k"], hint: "Command Palette"),
            .init(desc: "new issue",
                  id: "linear-new-issue", keys: ["meta","i"], hint: "New Issue"),
            .init(desc: "create issue",
                  id: "linear-new-issue", keys: ["meta","i"], hint: "New Issue"),
        ],

        // ── Claude ────────────────────────────────────────────────────────
        "com.anthropic.claudefordesktop": [
            // Send message — plain Enter (⇧↩ adds new line)
            .init("AXButton", desc: "send",
                  id: "claude-send", keys: ["enter"], hint: "Send Message"),
            .init(title: "send",
                  id: "claude-send", keys: ["enter"], hint: "Send Message"),
            // Stop response — Esc
            .init("AXButton", desc: "stop",
                  id: "claude-stop", keys: ["escape"], hint: "Stop Response"),
            .init("AXButton", desc: "stop generating",
                  id: "claude-stop", keys: ["escape"], hint: "Stop Response"),
            .init("AXButton", desc: "stop response",
                  id: "claude-stop", keys: ["escape"], hint: "Stop Response"),
            .init("AXButton", desc: "cancel",
                  id: "claude-stop", keys: ["escape"], hint: "Stop Response"),
            // New conversation — ⌘N
            .init("AXButton", desc: "new conversation",
                  id: "claude-new-chat", keys: ["meta","n"], hint: "New Conversation"),
            .init("AXButton", desc: "new chat",
                  id: "claude-new-chat", keys: ["meta","n"], hint: "New Conversation"),
            .init("AXButton", desc: "compose",
                  id: "claude-new-chat", keys: ["meta","n"], hint: "New Conversation"),
            .init(title: "new conversation",
                  id: "claude-new-chat", keys: ["meta","n"], hint: "New Conversation"),
            // Incognito chat — ⇧⌘I
            .init("AXButton", desc: "incognito",
                  id: "claude-incognito", keys: ["meta","shift","i"], hint: "Incognito Chat"),
            .init("AXButton", desc: "incognito chat",
                  id: "claude-incognito", keys: ["meta","shift","i"], hint: "Incognito Chat"),
            .init(title: "incognito",
                  id: "claude-incognito", keys: ["meta","shift","i"], hint: "Incognito Chat"),
            // Toggle sidebar — ⌘B
            .init("AXButton", desc: "collapse sidebar",
                  id: "claude-toggle-sidebar", keys: ["meta","b"], hint: "Toggle Sidebar"),
            .init("AXButton", desc: "expand sidebar",
                  id: "claude-toggle-sidebar", keys: ["meta","b"], hint: "Toggle Sidebar"),
            .init("AXButton", desc: "toggle sidebar",
                  id: "claude-toggle-sidebar", keys: ["meta","b"], hint: "Toggle Sidebar"),
            .init("AXButton", desc: "sidebar",
                  id: "claude-toggle-sidebar", keys: ["meta","b"], hint: "Toggle Sidebar"),
            // Keyboard shortcuts help — ⌘/
            .init("AXButton", desc: "keyboard shortcuts",
                  id: "claude-shortcuts-help", keys: ["meta","/"], hint: "Keyboard Shortcuts"),
            .init("AXButton", desc: "shortcuts",
                  id: "claude-shortcuts-help", keys: ["meta","/"], hint: "Keyboard Shortcuts"),
            .init("AXButton", desc: "help",
                  id: "claude-shortcuts-help", keys: ["meta","/"], hint: "Keyboard Shortcuts"),
            // Settings — ⇧⌘, (not plain ⌘,)
            .init("AXButton", desc: "settings",
                  id: "claude-settings", keys: ["meta","shift",","], hint: "Settings"),
            .init(title: "settings",
                  id: "claude-settings", keys: ["meta","shift",","], hint: "Settings"),
            // Mode switching tabs — ⌘1/2/3
            .init("AXButton", desc: "chat",
                  id: "claude-chat-mode", keys: ["meta","1"], hint: "Chat"),
            .init("AXButton", desc: "cowork",
                  id: "claude-cowork-mode", keys: ["meta","2"], hint: "Cowork"),
            .init("AXButton", desc: "code",
                  id: "claude-code-mode", keys: ["meta","3"], hint: "Code"),
            // Quick chat or search — ⌘K
            .init("AXTextField", sub: "AXSearchField",
                  id: "claude-search", keys: ["meta","k"], hint: "Quick Chat or Search"),
            .init("AXButton", desc: "search",
                  id: "claude-search", keys: ["meta","k"], hint: "Quick Chat or Search"),
            .init(desc: "search conversations",
                  id: "claude-search", keys: ["meta","k"], hint: "Quick Chat or Search"),
            .init(ph: "search",
                  id: "claude-search", keys: ["meta","k"], hint: "Quick Chat or Search"),
            // Toggle extended thinking — ⇧⌘E
            .init("AXButton", desc: "extended thinking",
                  id: "claude-extended-thinking", keys: ["meta","shift","e"], hint: "Extended Thinking"),
            .init("AXButton", desc: "thinking",
                  id: "claude-extended-thinking", keys: ["meta","shift","e"], hint: "Extended Thinking"),
            .init("AXButton", desc: "toggle thinking",
                  id: "claude-extended-thinking", keys: ["meta","shift","e"], hint: "Extended Thinking"),
            // Upload file — ⌘U
            .init("AXButton", desc: "upload",
                  id: "claude-upload", keys: ["meta","u"], hint: "Upload File"),
            .init("AXButton", desc: "attach",
                  id: "claude-upload", keys: ["meta","u"], hint: "Upload File"),
            .init("AXButton", desc: "upload file",
                  id: "claude-upload", keys: ["meta","u"], hint: "Upload File"),
            .init("AXButton", desc: "attach file",
                  id: "claude-upload", keys: ["meta","u"], hint: "Upload File"),
            // Voice dictation — Caps Lock (toggle)
            .init("AXButton", desc: "dictate",
                  id: "claude-voice", keys: ["capslock"], hint: "Voice Dictation"),
            .init("AXButton", desc: "voice",
                  id: "claude-voice", keys: ["capslock"], hint: "Voice Dictation"),
            .init("AXButton", desc: "microphone",
                  id: "claude-voice", keys: ["capslock"], hint: "Voice Dictation"),
            .init("AXButton", desc: "record",
                  id: "claude-voice", keys: ["capslock"], hint: "Voice Dictation"),
        ],

        // ── WhatsApp ──────────────────────────────────────────────────────
        "net.whatsapp.WhatsApp": [
            .init("AXButton", desc: "send",
                  id: "wa-send", keys: ["meta","enter"], hint: "Send Message"),
            .init(title: "send",
                  id: "wa-send", keys: ["meta","enter"], hint: "Send Message"),
            .init("AXButton", desc: "new chat",
                  id: "wa-new-chat", keys: ["meta","n"], hint: "New Message"),
            .init("AXButton", desc: "new message",
                  id: "wa-new-chat", keys: ["meta","n"], hint: "New Message"),
            .init(desc: "search",
                  id: "wa-search", keys: ["meta","f"], hint: "Search"),
            .init(desc: "mute",
                  id: "wa-mute", keys: ["meta","shift","m"], hint: "Mute Chat"),
            .init(title: "mute",
                  id: "wa-mute", keys: ["meta","shift","m"], hint: "Mute Chat"),
            .init(desc: "archive",
                  id: "wa-archive", keys: ["meta","shift","e"], hint: "Archive Chat"),
            .init(title: "archive",
                  id: "wa-archive", keys: ["meta","shift","e"], hint: "Archive Chat"),
            .init(desc: "new group",
                  id: "wa-new-group", keys: ["meta","shift","n"], hint: "New Group"),
            .init(title: "new group",
                  id: "wa-new-group", keys: ["meta","shift","n"], hint: "New Group"),
            .init(desc: "settings",
                  id: "wa-settings", keys: ["meta",","], hint: "Settings"),
            .init(desc: "next conversation",
                  id: "wa-next-chat", keys: ["meta","shift","]"], hint: "Next Conversation"),
            .init(title: "next conversation",
                  id: "wa-next-chat", keys: ["meta","shift","]"], hint: "Next Conversation"),
            .init(desc: "previous conversation",
                  id: "wa-prev-chat", keys: ["meta","shift","["], hint: "Previous Conversation"),
            .init(title: "previous conversation",
                  id: "wa-prev-chat", keys: ["meta","shift","["], hint: "Previous Conversation"),
            .init(desc: "mark as unread",
                  id: "wa-mark-unread", keys: ["meta","shift","u"], hint: "Mark as Unread"),
            .init(title: "mark as unread",
                  id: "wa-mark-unread", keys: ["meta","shift","u"], hint: "Mark as Unread"),
            .init(desc: "profile",
                  id: "wa-profile", keys: ["meta","p"], hint: "Show Profile"),
            .init(title: "profile",
                  id: "wa-profile", keys: ["meta","p"], hint: "Show Profile"),
        ],

        // ── Comet (Perplexity) ────────────────────────────────────────────
        "ai.perplexity.comet": [
            .init("AXTextField", desc: "address",
                  id: "comet-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init("AXTextField", desc: "search",
                  id: "comet-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init("AXButton", desc: "new tab",
                  id: "comet-new-tab", keys: ["meta","t"], hint: "New Tab"),
            .init(title: "new tab",
                  id: "comet-new-tab", keys: ["meta","t"], hint: "New Tab"),
            .init("AXButton", desc: "reload",
                  id: "comet-reload", keys: ["meta","r"], hint: "Reload"),
            .init("AXButton", desc: "back",
                  id: "comet-back", keys: ["meta","arrowleft"], hint: "Go Back"),
            .init("AXButton", desc: "forward",
                  id: "comet-forward", keys: ["meta","arrowright"], hint: "Go Forward"),
            .init("AXButton", desc: "close tab",
                  id: "comet-close-tab", keys: ["meta","w"], hint: "Close Tab"),
            .init(desc: "command bar",
                  id: "comet-command-bar", keys: ["meta","shift","a"], hint: "Command Bar"),
            .init(desc: "ai search",
                  id: "comet-command-bar", keys: ["meta","shift","a"], hint: "Command Bar"),
            .init(desc: "bookmark",
                  id: "comet-bookmark", keys: ["meta","d"], hint: "Bookmark Page"),
            .init(desc: "bookmarks bar",
                  id: "comet-bookmarks-bar", keys: ["meta","shift","b"], hint: "Toggle Bookmarks Bar"),
        ],

        // ── Chrome ────────────────────────────────────────────────────────
        "com.google.Chrome": [
            .init("AXTextField", desc: "address",
                  id: "chrome-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init("AXTextField", desc: "search",
                  id: "chrome-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init("AXButton", desc: "new tab",
                  id: "chrome-new-tab", keys: ["meta","t"], hint: "New Tab"),
        ],

        // ── Arc ───────────────────────────────────────────────────────────
        "company.thebrowser.Browser": [
            .init("AXTextField", desc: "address",
                  id: "arc-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init(desc: "search",
                  id: "arc-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init(desc: "new tab",
                  id: "arc-new-tab", keys: ["meta","t"], hint: "New Tab"),
        ],

        // ── Mail ──────────────────────────────────────────────────────────
        "com.apple.mail": [
            .init(desc: "compose",
                  id: "mail-compose", keys: ["meta","n"], hint: "New Message"),
            .init(desc: "new message",
                  id: "mail-compose", keys: ["meta","n"], hint: "New Message"),
            .init(title: "compose",
                  id: "mail-compose", keys: ["meta","n"], hint: "New Message"),
            .init(desc: "reply",
                  id: "mail-reply", keys: ["meta","r"], hint: "Reply"),
            .init(title: "reply",
                  id: "mail-reply", keys: ["meta","r"], hint: "Reply"),
            .init(desc: "reply all",
                  id: "mail-reply-all", keys: ["meta","shift","r"], hint: "Reply All"),
            .init(desc: "forward",
                  id: "mail-forward", keys: ["meta","shift","f"], hint: "Forward"),
            .init(desc: "archive",
                  id: "mail-archive", keys: ["ctrl","meta","a"], hint: "Archive"),
            .init("AXTextField", desc: "search",
                  id: "mail-search", keys: ["meta","alt","f"], hint: "Search Mailbox"),
        ],

        // ── Safari ────────────────────────────────────────────────────────
        "com.apple.Safari": [
            .init("AXTextField", desc: "address",
                  id: "safari-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init("AXTextField", desc: "search",
                  id: "safari-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init(desc: "new tab",
                  id: "safari-new-tab", keys: ["meta","t"], hint: "New Tab"),
            .init(title: "new tab",
                  id: "safari-new-tab", keys: ["meta","t"], hint: "New Tab"),
            .init(desc: "reload",
                  id: "safari-reload", keys: ["meta","r"], hint: "Reload Page"),
            .init(desc: "back",
                  id: "safari-back", keys: ["meta","arrowleft"], hint: "Go Back"),
            .init(desc: "forward",
                  id: "safari-forward", keys: ["meta","arrowright"], hint: "Go Forward"),
            .init(desc: "show sidebar",
                  id: "safari-sidebar", keys: ["meta","shift","l"], hint: "Toggle Sidebar"),
        ],

        // ── Xcode ─────────────────────────────────────────────────────────
        "com.apple.dt.Xcode": [
            .init(desc: "search",
                  id: "xcode-find", keys: ["meta","f"], hint: "Find in File"),
            .init(desc: "navigator",
                  id: "xcode-navigator", keys: ["meta","1"], hint: "Show Navigator"),
            .init(desc: "debug area",
                  id: "xcode-debug-area", keys: ["meta","shift","y"], hint: "Toggle Debug Area"),
            .init(desc: "inspector",
                  id: "xcode-inspector", keys: ["meta","alt","0"], hint: "Hide/Show Inspector"),
        ],

        // ── Terminal ──────────────────────────────────────────────────────
        "com.apple.Terminal": [
            .init("AXTextField", sub: "AXSearchField", ph: "search",
                  id: "terminal-find", keys: ["meta","f"], hint: "Find in Output"),
            .init(desc: "find",
                  id: "terminal-find", keys: ["meta","f"], hint: "Find in Output"),
            .init("AXButton", desc: "new tab",
                  id: "terminal-new-tab", keys: ["meta","t"], hint: "New Tab"),
            .init(title: "new tab",
                  id: "terminal-new-tab", keys: ["meta","t"], hint: "New Tab"),
            .init("AXButton", desc: "new window",
                  id: "terminal-new-window", keys: ["meta","n"], hint: "New Window"),
            .init(desc: "clear",
                  id: "terminal-clear", keys: ["meta","k"], hint: "Clear Screen"),
        ],

        // ── Finder ────────────────────────────────────────────────────────
        "com.apple.finder": [
            .init("AXTextField", sub: "AXSearchField",
                  id: "finder-search", keys: ["meta","f"], hint: "Search"),
            .init(desc: "search",
                  id: "finder-search", keys: ["meta","f"], hint: "Search"),
            .init("AXButton", desc: "back",
                  id: "finder-back", keys: ["meta","["], hint: "Go Back"),
            .init(title: "back",
                  id: "finder-back", keys: ["meta","["], hint: "Go Back"),
            .init("AXButton", desc: "forward",
                  id: "finder-forward", keys: ["meta","]"], hint: "Go Forward"),
            .init(title: "forward",
                  id: "finder-forward", keys: ["meta","]"], hint: "Go Forward"),
            .init("AXButton", desc: "new folder",
                  id: "finder-new-folder", keys: ["meta","shift","n"], hint: "New Folder"),
            .init(title: "new folder",
                  id: "finder-new-folder", keys: ["meta","shift","n"], hint: "New Folder"),
            .init(desc: "as icons",
                  id: "finder-icon-view", keys: ["meta","1"], hint: "Icon View"),
            .init(desc: "as list",
                  id: "finder-list-view", keys: ["meta","2"], hint: "List View"),
            .init(desc: "as columns",
                  id: "finder-column-view", keys: ["meta","3"], hint: "Column View"),
            .init(desc: "as gallery",
                  id: "finder-gallery-view", keys: ["meta","4"], hint: "Gallery View"),
        ],

        // ── Notion Calendar ───────────────────────────────────────────────
        "com.cron.electron": [
            .init("AXTextField", sub: "AXSearchField",
                  id: "notion-cal-command-bar", keys: ["meta","k"], hint: "Command Bar"),
            .init(desc: "search",
                  id: "notion-cal-command-bar", keys: ["meta","k"], hint: "Command Bar"),
            .init(desc: "command bar",
                  id: "notion-cal-command-bar", keys: ["meta","k"], hint: "Command Bar"),
            .init(desc: "today",
                  id: "notion-cal-today", keys: ["t"], hint: "Go to Today"),
            .init(title: "today",
                  id: "notion-cal-today", keys: ["t"], hint: "Go to Today"),
            .init(desc: "new event",
                  id: "notion-cal-new-event", keys: ["c"], hint: "New Event"),
            .init(title: "new event",
                  id: "notion-cal-new-event", keys: ["c"], hint: "New Event"),
            .init(desc: "create event",
                  id: "notion-cal-new-event", keys: ["c"], hint: "New Event"),
        ],

        // ── Notion Mail ───────────────────────────────────────────────────
        "notion.mail.id": [
            .init(desc: "compose",
                  id: "notion-mail-compose", keys: ["c"], hint: "Compose"),
            .init(title: "compose",
                  id: "notion-mail-compose", keys: ["c"], hint: "Compose"),
            .init(desc: "new email",
                  id: "notion-mail-compose", keys: ["c"], hint: "Compose"),
            .init("AXButton", desc: "send",
                  id: "notion-mail-send", keys: ["meta","enter"], hint: "Send"),
            .init(title: "send",
                  id: "notion-mail-send", keys: ["meta","enter"], hint: "Send"),
            .init(desc: "archive",
                  id: "notion-mail-archive", keys: ["e"], hint: "Archive"),
            .init(title: "archive",
                  id: "notion-mail-archive", keys: ["e"], hint: "Archive"),
            .init(desc: "search",
                  id: "notion-mail-search", keys: ["meta","k"], hint: "Command Palette"),
            .init(desc: "command palette",
                  id: "notion-mail-search", keys: ["meta","k"], hint: "Command Palette"),
            .init(desc: "sidebar",
                  id: "notion-mail-sidebar", keys: ["meta","\\"], hint: "Toggle Sidebar"),
            .init(title: "sidebar",
                  id: "notion-mail-sidebar", keys: ["meta","\\"], hint: "Toggle Sidebar"),
        ],

        // ── Spotify ───────────────────────────────────────────────────────
        "com.spotify.client": [
            .init("AXTextField", sub: "AXSearchField", ph: "search",
                  id: "spotify-search", keys: ["meta","l"], hint: "Search"),
            .init(desc: "search",
                  id: "spotify-search", keys: ["meta","l"], hint: "Search"),
            .init(desc: "play",
                  id: "spotify-play-pause", keys: ["space"], hint: "Play / Pause"),
            .init(desc: "pause",
                  id: "spotify-play-pause", keys: ["space"], hint: "Play / Pause"),
            .init(desc: "next",
                  id: "spotify-next", keys: ["meta","arrowright"], hint: "Next Track"),
            .init(desc: "skip to next",
                  id: "spotify-next", keys: ["meta","arrowright"], hint: "Next Track"),
            .init(desc: "previous",
                  id: "spotify-prev", keys: ["meta","arrowleft"], hint: "Previous Track"),
            .init(desc: "skip to previous",
                  id: "spotify-prev", keys: ["meta","arrowleft"], hint: "Previous Track"),
        ],
    ]
}
