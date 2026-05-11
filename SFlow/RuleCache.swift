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

    func match(bundleId: String, role: String, title: String, desc: String, help: String) -> MatchResult? {
        guard let rules = rulesByBundle[bundleId] else { return nil }
        let titleLC = title.lowercased()
        let descLC = desc.lowercased()
        let helpLC = help.lowercased()

        for rule in rules {
            if !showExperimental, rule.confidence == .low { continue }
            if rule.match.role != role { continue }
            let titleMatches = rule.match.titles.contains { candidate in
                let c = candidate.lowercased()
                return titleLC == c || descLC == c || helpLC == c
                    || titleLC.contains(c) || descLC.contains(c)
            }
            if titleMatches { return MatchResult(rule: rule) }
        }
        return nil
    }

    func hasRules(bundleId: String) -> Bool {
        rulesByBundle[bundleId]?.isEmpty == false
    }
}
