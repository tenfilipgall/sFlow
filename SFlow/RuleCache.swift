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
    /// L0.7 — macOS standard shortcuts (Minimize/Close/Save/…). Loaded from
    /// the app bundle's `macosSystemShortcuts.json`. Lives *alongside*
    /// `rulesByBundle` — `matchSystem(...)` is only consulted when the
    /// per-app match misses, so app rules always win.
    private var systemRules: [LoadedRule] = []
    var showExperimental: Bool = false

    init(rootDir: URL) {
        self.rootDir = rootDir
    }

    func load() throws {
        rulesByBundle.removeAll()
        featuresByBundle.removeAll()
        autoDiscoveredBundleIds.removeAll()
        systemRules.removeAll()
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
        // L0.7 — macOS system shortcuts (separate side-car file, parallel layer).
        // Read straight from the app bundle each launch; never written to
        // Application Support, never mixed with rulesByBundle.
        loadSystemRules()
    }

    /// Loads `macosSystemShortcuts.json` from the app bundle into the
    /// `systemRules` array. Silent no-op when the resource is missing
    /// (dev builds without xcodegen sync, unit tests, etc.).
    private func loadSystemRules() {
        guard let url = Bundle.main.url(forResource: "macosSystemShortcuts",
                                        withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rules = try? JSONDecoder().decode([LoadedRule].self, from: data) else {
            return
        }
        systemRules = rules
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
               customActions: [String] = [],
               locale: String = "") -> MatchResult? {
        guard let rules = rulesByBundle[bundleId] else { return nil }
        let isAutoDiscovered = autoDiscoveredBundleIds.contains(bundleId)
        let titleLC = title.lowercased()
        let descLC = desc.lowercased()
        let helpLC = help.lowercased()
        let identifierLC = identifier.lowercased()
        let titleStripped = Self.stripHotkeySuffix(title)?.lowercased()
        let roleDescLC = roleDescription.lowercased()
        let customActionsLC = customActions.map { $0.lowercased() }
        // Sub-cel 1.20: when active locale is non-English, consult
        // localizedTitles[locale] BEFORE the English titles array. English
        // remains the safety-net fallback (mixed apps: PL system + EN Slack UI).
        let useLocalized = !locale.isEmpty && locale != "en"

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
            // Localized title match — tried first when locale is non-EN.
            if useLocalized,
               let localized = rule.match.localizedTitles?[locale],
               !localized.isEmpty,
               Self.titleMatches(
                   candidates: localized,
                   titleLC: titleLC, descLC: descLC, helpLC: helpLC,
                   roleDescLC: roleDescLC, customActionsLC: customActionsLC,
                   titleStripped: titleStripped) {
                return MatchResult(rule: rule)
            }
            // English title match (fallback for non-EN; primary for EN) —
            // word-boundary for substring to prevent "search" matching inside
            // "research" (BUG #2 in audit).
            if Self.titleMatches(
                candidates: rule.match.titles,
                titleLC: titleLC, descLC: descLC, helpLC: helpLC,
                roleDescLC: roleDescLC, customActionsLC: customActionsLC,
                titleStripped: titleStripped) {
                return MatchResult(rule: rule)
            }
        }
        return nil
    }

    /// L0.7 — macOS standard shortcuts. Two backends, both app-agnostic:
    ///
    /// Backend A — AX subrole map (locale-stable): traffic-light buttons
    /// (close/minimize/fullscreen) expose `AXCloseButton`/`AXMinimizeButton`/
    /// `AXFullScreenButton` as `kAXSubrole`. Returned shortcut is hard-coded
    /// since these are AppKit-fixed.
    ///
    /// Backend B — title match against `systemRules` (loaded from
    /// `macosSystemShortcuts.json`). Uses the same `titleMatches` machinery as
    /// per-app `match(...)`; honours `localizedTitles[locale]` when present.
    ///
    /// Called by ClickWatcher only when `match(bundleId: …)` already returned
    /// nil — per-app rules always win, this is a fallback.
    func matchSystem(role: String, subrole: String,
                     title: String, desc: String, help: String,
                     identifier: String = "",
                     roleDescription: String = "",
                     customActions: [String] = [],
                     locale: String = "") -> MatchResult? {

        // Backend A — subrole hit (traffic lights).
        if let hit = SystemShortcuts.matchSubrole(subrole) {
            let match = LoadedMatch(role: role, titles: [hit.hint])
            let rule = LoadedRule(match: match, keys: hit.keys, hint: hit.hint,
                                  confidence: .high, source: .menuBar)
            return MatchResult(rule: rule)
        }

        // Backend B — title match against curated EN+PL list. Empty fast-path
        // avoids per-click work when the JSON failed to load.
        if systemRules.isEmpty { return nil }

        let titleLC = title.lowercased()
        let descLC = desc.lowercased()
        let helpLC = help.lowercased()
        let identifierLC = identifier.lowercased()
        let titleStripped = Self.stripHotkeySuffix(title)?.lowercased()
        let roleDescLC = roleDescription.lowercased()
        let customActionsLC = customActions.map { $0.lowercased() }
        let useLocalized = !locale.isEmpty && locale != "en"

        for rule in systemRules {
            if !showExperimental && rule.confidence == .low { continue }
            if !roleCompatible(ruleRole: rule.match.role, actualRole: role) { continue }
            if let ids = rule.match.identifiers, !identifierLC.isEmpty {
                if ids.contains(where: { $0.lowercased() == identifierLC }) {
                    return MatchResult(rule: rule)
                }
            }
            if useLocalized,
               let localized = rule.match.localizedTitles?[locale],
               !localized.isEmpty,
               Self.titleMatches(
                   candidates: localized,
                   titleLC: titleLC, descLC: descLC, helpLC: helpLC,
                   roleDescLC: roleDescLC, customActionsLC: customActionsLC,
                   titleStripped: titleStripped) {
                return MatchResult(rule: rule)
            }
            if Self.titleMatches(
                candidates: rule.match.titles,
                titleLC: titleLC, descLC: descLC, helpLC: helpLC,
                roleDescLC: roleDescLC, customActionsLC: customActionsLC,
                titleStripped: titleStripped) {
                return MatchResult(rule: rule)
            }
        }
        return nil
    }

    /// Shared title-matching logic used by both the localized and English paths.
    private static func titleMatches(
        candidates: [String],
        titleLC: String, descLC: String, helpLC: String,
        roleDescLC: String, customActionsLC: [String],
        titleStripped: String?
    ) -> Bool {
        candidates.contains { candidate in
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
