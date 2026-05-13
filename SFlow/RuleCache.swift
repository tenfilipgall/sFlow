import Foundation

final class RuleCache {
    struct MatchResult {
        let rule: LoadedRule
        var keys: [String] { rule.keys }
        var hint: String { rule.hint }
    }

    private let rootDir: URL
    private var rulesByBundle: [String: [LoadedRule]] = [:]
    var showExperimental: Bool = false

    init(rootDir: URL) {
        self.rootDir = rootDir
    }

    func load() throws {
        rulesByBundle.removeAll()
        // Layer 1: bundled (lowest priority)
        loadFile(rootDir.appendingPathComponent("bundled.json"))
        // Layer 2: cache files (override bundled)
        let cacheDir = rootDir.appendingPathComponent("cache")
        if let entries = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for entry in entries where entry.pathExtension == "json" {
                loadFile(entry)
            }
        }
        // Layer 3: user overrides (highest)
        loadFile(rootDir.appendingPathComponent("user_overrides.json"))
    }

    private func loadFile(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        if let set = try? JSONDecoder().decode(StoredRuleSet.self, from: data) {
            rulesByBundle[set.bundleId] = set.rules
            return
        }
        // bundled.json may contain multiple apps wrapped in an array
        if let sets = try? JSONDecoder().decode([StoredRuleSet].self, from: data) {
            for set in sets {
                if rulesByBundle[set.bundleId] == nil {
                    rulesByBundle[set.bundleId] = set.rules
                }
            }
        }
    }

    /// Roles compatible with a rule that asks for AXButton. Chromium/Electron apps wrap
    /// aria-label'd clickables in AXGroup; menu items show up as AXMenuItem/AXMenuBarItem;
    /// some lists use AXCell. All of these are semantically "buttons" for our purposes.
    private static let clickableRoles: Set<String> = [
        "AXButton", "AXLink", "AXMenuItem", "AXMenuBarItem",
        "AXCheckBox", "AXRadioButton", "AXPopUpButton",
        "AXGroup", "AXCell", "AXImage",
    ]

    /// Strips a trailing " X" (space + single letter) from a title — handles Slack/Discord
    /// menu items that render the access-key letter in the AX title (e.g. "Edit message E").
    /// Returns nil if the title doesn't have that shape OR stripping would leave fewer
    /// than 2 characters (too aggressive).
    static func stripHotkeySuffix(_ s: String) -> String? {
        guard s.count >= 4 else { return nil }
        let chars = Array(s)
        let last = chars[chars.count - 1]
        let prev = chars[chars.count - 2]
        guard prev == " ", last.isLetter else { return nil }
        let stripped = String(chars.dropLast(2))
        guard stripped.count >= 2 else { return nil }
        return stripped
    }

    func match(bundleId: String, role: String, title: String, desc: String, help: String) -> MatchResult? {
        guard let rules = rulesByBundle[bundleId] else { return nil }
        let titleLC = title.lowercased()
        let descLC = desc.lowercased()
        let helpLC = help.lowercased()
        let titleStripped = Self.stripHotkeySuffix(title)?.lowercased()

        for rule in rules {
            if !showExperimental, rule.confidence == .low { continue }
            if !roleCompatible(ruleRole: rule.match.role, actualRole: role) { continue }
            let titleMatches = rule.match.titles.contains { candidate in
                let c = candidate.lowercased()
                if titleLC == c || descLC == c || helpLC == c
                    || titleLC.contains(c) || descLC.contains(c) { return true }
                if let stripped = titleStripped {
                    if stripped == c || stripped.contains(c) { return true }
                }
                return false
            }
            if titleMatches { return MatchResult(rule: rule) }
        }
        return nil
    }

    private func roleCompatible(ruleRole: String, actualRole: String) -> Bool {
        if ruleRole == actualRole { return true }
        // AXButton in a rule = "anything clickable" — be permissive (covers Chromium quirks).
        if ruleRole == "AXButton" {
            return Self.clickableRoles.contains(actualRole)
        }
        return false
    }

    func hasRules(bundleId: String) -> Bool {
        rulesByBundle[bundleId]?.isEmpty == false
    }
}
