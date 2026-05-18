import Foundation

enum RuleStorage {
    static func userRulesDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("SFlow/rules", isDirectory: true)
    }

    static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Outcome of a seed-or-update attempt. Useful for tests + telemetry.
    enum SeedOutcome {
        case copiedFresh           // First launch — copied shipping into user dir
        case upgradedFromShipping  // SFlow updated — shipping newer than user file → overwrote
        case keptUser              // user file is newer or same → kept as-is
        case noShippingResource    // app bundle has no bundled.json (dev build edge case)
    }

    /// On every app launch: ensure the user's bundled.json reflects the shipping
    /// bundled.json from the .app — but only when SFlow has been upgraded.
    ///
    /// P-19 (audit-phase-0.md): before this fix, `seedBundledIfMissing()` only
    /// copied the file on FIRST launch. After SFlow v1.0 → v1.1 the user kept
    /// the v1.0 rules forever — beta-testers with iterated DMGs would silently
    /// stay on the first DMG's rules.
    ///
    /// Strategy: compare a "max rule count + max title count" fingerprint of
    /// shipping vs user bundled.json. Shipping > user → overwrite. Otherwise
    /// keep what the user has (handles dev who hand-edited bundled.json).
    /// `cache/*.json` and `user_overrides.json` are NEVER touched.
    @discardableResult
    static func seedBundledIfMissing() throws -> SeedOutcome {
        let userDir = userRulesDirectory()
        try ensureDirectory(userDir)
        try ensureDirectory(userDir.appendingPathComponent("cache"))

        let dest = userDir.appendingPathComponent("bundled.json")
        guard let src = Bundle.main.url(forResource: "bundled", withExtension: "json") else {
            return .noShippingResource
        }

        // Fresh install — straight copy
        if !FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.copyItem(at: src, to: dest)
            return .copiedFresh
        }

        // Compare fingerprints. Shipping > user → overwrite.
        let userFp = (try? fingerprint(at: dest)) ?? .zero
        let shippingFp = (try? fingerprint(at: src)) ?? .zero
        if shippingFp > userFp {
            // Overwrite — but DO NOT touch cache/ or user_overrides.json
            try FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: src, to: dest)
            return .upgradedFromShipping
        }
        return .keptUser
    }

    /// Cheap proxy for "bundled.json content version" — sums (apps × 100 +
    /// rules × 10 + titles). Newer bundles always have more apps OR more
    /// rules OR more title variants. No version field required, no risk of
    /// rollback if shipping happens to be older for some reason (kept user
    /// wins).
    ///
    /// Internal; exposed for tests via `fingerprintOfData`.
    struct Fingerprint: Comparable {
        let appCount: Int
        let ruleCount: Int
        let titleCount: Int
        static let zero = Fingerprint(appCount: 0, ruleCount: 0, titleCount: 0)
        var score: Int { appCount * 1_000_000 + ruleCount * 1_000 + titleCount }
        static func < (lhs: Fingerprint, rhs: Fingerprint) -> Bool { lhs.score < rhs.score }
    }

    static func fingerprint(at url: URL) throws -> Fingerprint {
        let data = try Data(contentsOf: url)
        return fingerprintOfData(data)
    }

    static func fingerprintOfData(_ data: Data) -> Fingerprint {
        // bundled.json is an array of StoredRuleSet entries
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return .zero
        }
        var rules = 0
        var titles = 0
        for entry in array {
            if let ruleArray = entry["rules"] as? [[String: Any]] {
                rules += ruleArray.count
                for rule in ruleArray {
                    if let match = rule["match"] as? [String: Any],
                       let titleArray = match["titles"] as? [Any] {
                        titles += titleArray.count
                    }
                }
            }
        }
        return Fingerprint(appCount: array.count, ruleCount: rules, titleCount: titles)
    }
}
