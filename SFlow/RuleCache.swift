import Foundation

final class RuleCache {
    struct MatchResult {
        let rule: LoadedRule
        var keys: [String] { rule.keys }
        var hint: String { rule.hint }
    }

    private let rootDir: URL
    private var rulesByBundle: [String: [LoadedRule]] = [:]
    private var featuresByBundle: [String: Features] = [:]
    private var autoDiscoveredBundleIds: Set<String> = []
    var showExperimental: Bool = false

    init(rootDir: URL) {
        self.rootDir = rootDir
    }

    func load() throws {
        rulesByBundle.removeAll()
        featuresByBundle.removeAll()
        autoDiscoveredBundleIds.removeAll()
        // Layer 1: bundled (lowest priority)
        loadFile(rootDir.appendingPathComponent("bundled.json"), isAutoDiscovered: false)
        // Layer 2: cache files (auto-discovered, override bundled)
        let cacheDir = rootDir.appendingPathComponent("cache")
        if let entries = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for entry in entries where entry.pathExtension == "json" {
                loadFile(entry, isAutoDiscovered: true)
            }
        }
        // Layer 3: user overrides (highest, always trusted)
        loadFile(rootDir.appendingPathComponent("user_overrides.json"), isAutoDiscovered: false)
    }

    private func loadFile(_ url: URL, isAutoDiscovered: Bool) {
        guard let data = try? Data(contentsOf: url) else { return }
        // Single-object files (cache/{bundleId}.json, user_overrides.json) OVERWRITE
        // any previously-loaded rules — that's how cache overrides bundled and user
        // overrides cache. Array-format (bundled.json) uses first-write-wins within
        // the file but otherwise behaves like a fresh insert.
        if let set = try? JSONDecoder().decode(StoredRuleSet.self, from: data) {
            registerSet(set, isAutoDiscovered: isAutoDiscovered, overwrite: true)
            return
        }
        if let sets = try? JSONDecoder().decode([StoredRuleSet].self, from: data) {
            for set in sets {
                registerSet(set, isAutoDiscovered: isAutoDiscovered, overwrite: false)
            }
        }
    }

    /// Registers rules and features from a `StoredRuleSet`. When `overwrite` is
    /// false (bundled.json array entries) only fills empty slots — preserves
    /// "cache overrides bundled" semantics by leaving cache-loaded entries
    /// alone if bundled.json reloads. When `overwrite` is true (single-object
    /// cache or user_overrides files) replaces existing rules.
    /// Empty-rules entries with features set register only the features —
    /// allows bundled.json to declare per-bundle features without blocking
    /// cache rules from filling the same bundleId.
    private func registerSet(_ set: StoredRuleSet, isAutoDiscovered: Bool, overwrite: Bool) {
        if !set.rules.isEmpty {
            if overwrite || rulesByBundle[set.bundleId] == nil {
                rulesByBundle[set.bundleId] = set.rules
                if isAutoDiscovered {
                    autoDiscoveredBundleIds.insert(set.bundleId)
                } else {
                    autoDiscoveredBundleIds.remove(set.bundleId)
                }
            }
        }
        if let features = set.features {
            if overwrite || featuresByBundle[set.bundleId] == nil {
                featuresByBundle[set.bundleId] = features
            }
        }
    }

    /// Returns true when `bundleId` is whitelisted as a single-key-shortcut app
    /// (Gmail j/k, Notion Mail C/R/F, Obsidian Vim). ClickWatcher's Layer 2 gate
    /// uses this to accept single-character `kAXHelp` values that would otherwise
    /// be rejected as likely false positives.
    func isSingleKeyApp(bundleId: String) -> Bool {
        featuresByBundle[bundleId]?.singleKeyMode == true
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

    func match(bundleId: String, role: String, title: String, desc: String, help: String,
               identifier: String = "",
               roleDescription: String = "",
               customActions: [String] = []) -> MatchResult? {
        guard let rules = rulesByBundle[bundleId] else { return nil }
        let isAutoDiscovered = autoDiscoveredBundleIds.contains(bundleId)
        let titleLC = title.lowercased()
        let descLC = desc.lowercased()
        let helpLC = help.lowercased()
        let identifierLC = identifier.lowercased()
        let titleStripped = Self.stripHotkeySuffix(title)?.lowercased()
        let roleDescLC = roleDescription.lowercased()
        let customActionsLC = customActions.map { $0.lowercased() }

        for rule in rules {
            if !showExperimental {
                if rule.confidence == .low { continue }
                if isAutoDiscovered && rule.confidence != .high { continue }
                if isAutoDiscovered && rule.source != .menuBar && rule.source != .webDocsOfficial { continue }
            }
            if !roleCompatible(ruleRole: rule.match.role, actualRole: role) { continue }
            // Identifier fast path — exact match, language-agnostic
            if let ids = rule.match.identifiers, !identifierLC.isEmpty {
                if ids.contains(where: { $0.lowercased() == identifierLC }) {
                    return MatchResult(rule: rule)
                }
            }
            // Title match — word-boundary for substring to prevent
            // "search" matching inside "research" (BUG #2 in audit).
            let titleMatches = rule.match.titles.contains { candidate in
                let c = candidate.lowercased()
                if c.isEmpty { return false }
                if titleLC == c || descLC == c || helpLC == c || roleDescLC == c { return true }
                if customActionsLC.contains(c) { return true }
                if wordBoundaryContains(haystack: titleLC, needle: c) { return true }
                if wordBoundaryContains(haystack: descLC,  needle: c) { return true }
                if wordBoundaryContains(haystack: helpLC,  needle: c) { return true }
                if wordBoundaryContains(haystack: roleDescLC, needle: c) { return true }
                if customActionsLC.contains(where: { wordBoundaryContains(haystack: $0, needle: c) }) { return true }
                if let stripped = titleStripped {
                    if stripped == c { return true }
                    if wordBoundaryContains(haystack: stripped, needle: c) { return true }
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
