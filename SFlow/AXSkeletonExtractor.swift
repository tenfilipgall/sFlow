import AppKit
import ApplicationServices
import Foundation

struct RawAXItem: Hashable {
    let role: String
    let title: String
    let identifier: String?

    init(role: String, title: String, identifier: String? = nil) {
        self.role = role
        self.title = title
        self.identifier = identifier
    }
}

struct SkeletonItem: Codable, Hashable {
    let role: String
    let title: String
    let identifier: String?

    init(role: String, title: String, identifier: String? = nil) {
        self.role = role
        self.title = title
        self.identifier = identifier
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(role, forKey: .role)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(identifier, forKey: .identifier)
    }
}

enum AXSkeletonExtractor {
    private static let allowedRoles: Set<String> = [
        "AXButton", "AXLink", "AXMenuItem",
        "AXCheckBox", "AXRadioButton", "AXPopUpButton",
    ]
    private static let maxTitleLen = 50
    private static let maxItems = 500

    static func filter(rawItems: [RawAXItem]) -> [SkeletonItem] {
        // Count occurrences before filtering
        var counts: [RawAXItem: Int] = [:]
        for item in rawItems where allowedRoles.contains(item.role) {
            counts[item, default: 0] += 1
        }

        var result: [SkeletonItem] = []
        var seen: Set<RawAXItem> = []

        for item in rawItems {
            if !allowedRoles.contains(item.role) { continue }
            if seen.contains(item) { continue }
            seen.insert(item)

            let title = item.title.trimmingCharacters(in: .whitespaces)
            if title.isEmpty || title.count > maxTitleLen { continue }
            if startsWithSensitivePrefix(title) { continue }
            if looksLikeEmail(title) { continue }
            if looksLikeISODate(title) { continue }
            if looksLikePureDigits(title) { continue }
            if looksLikeHumanName(title) { continue }

            let count = counts[item] ?? 1
            if count < 2 && !looksVerbLed(title) { continue }

            result.append(SkeletonItem(role: item.role, title: title, identifier: item.identifier))
            if result.count >= maxItems { break }
        }

        return result
    }

    private static let sensitivePrefixes: [Character] = ["#", "@"]
    private static func startsWithSensitivePrefix(_ s: String) -> Bool {
        guard let first = s.first else { return false }
        if sensitivePrefixes.contains(first) { return true }
        return s.hasPrefix("https://") || s.hasPrefix("http://")
    }

    private static let emailRegex = try! NSRegularExpression(pattern: #"^[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}$"#)
    private static func looksLikeEmail(_ s: String) -> Bool {
        emailRegex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    private static let isoDateRegex = try! NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}"#)
    private static func looksLikeISODate(_ s: String) -> Bool {
        isoDateRegex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    private static func looksLikePureDigits(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { $0.isNumber || $0.isPunctuation || $0.isWhitespace }
    }

    /// Approximate "First Last" pattern: exactly 2 words, each capitalized, each with lowercase tail.
    /// Excludes strings where the first word is a verb (e.g. "Send Message", "New Channel").
    private static let humanNameRegex = try! NSRegularExpression(pattern: #"^[A-ZŁŚŻŹĆŃÓ][a-ząęłśżźćń]+ [A-ZŁŚŻŹĆŃÓ][a-ząęłśżźćń]+$"#)
    private static func looksLikeHumanName(_ s: String) -> Bool {
        guard humanNameRegex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil else {
            return false
        }
        // If the first word is a verb/action word, it's UI text not a name
        if looksVerbLed(s) { return false }
        // Common non-name first words that match the pattern
        let commonWords: Set<String> = [
            "new", "main", "light", "dark", "use", "choose", "show", "hide",
        ]
        if let first = s.lowercased().split(separator: " ").first,
           commonWords.contains(String(first)) { return false }
        return true
    }

    private static let verbs: Set<String> = [
        "new", "add", "create", "delete", "remove", "edit", "save", "open", "close",
        "send", "reply", "forward", "archive", "star", "pin", "mute", "unmute",
        "search", "find", "go", "show", "hide", "toggle", "switch", "select",
        "copy", "paste", "cut", "undo", "redo", "view", "share", "export", "import",
        "download", "upload", "refresh", "reload", "sign", "log", "join", "leave",
        "use", "choose", "set", "enable", "disable", "manage", "configure", "connect",
        "disconnect", "move", "rename", "duplicate", "invite", "mark", "filter", "sort",
    ]
    private static func looksVerbLed(_ s: String) -> Bool {
        guard let first = s.lowercased().split(separator: " ").first else { return false }
        return verbs.contains(String(first))
    }

    // MARK: - Live AX walk (used at runtime, not in tests)

    static func extract(for app: NSRunningApplication, maxNodes: Int = 5000) -> [SkeletonItem] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var raw: [RawAXItem] = []
        walk(axApp, depth: 0, maxDepth: 6, count: &raw, max: maxNodes)
        return filter(rawItems: raw)
    }

    private static func walk(_ element: AXUIElement, depth: Int, maxDepth: Int,
                              count raw: inout [RawAXItem], max: Int) {
        if raw.count >= max { return }
        if depth > maxDepth { return }

        var roleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""

        if allowedRoles.contains(role) {
            var titleRef: AnyObject?
            var descRef: AnyObject?
            var identRef: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
            AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
            AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identRef)
            let title = (titleRef as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? (descRef as? String) ?? ""
            if !title.isEmpty {
                let ident = identRef as? String
                raw.append(RawAXItem(role: role, title: title,
                                     identifier: ident?.isEmpty == false ? ident : nil))
            }
        }

        var childrenRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        if let children = childrenRef as? [AXUIElement] {
            for child in children {
                walk(child, depth: depth + 1, maxDepth: maxDepth, count: &raw, max: max)
            }
        }
    }
}
