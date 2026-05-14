import Foundation

final class BundledUpdater {
    private let fetch: () async throws -> BundledResponse
    private let rulesDir: URL
    private weak var ruleCache: RuleCache?
    private static let checkIntervalSeconds: TimeInterval = 7 * 86400

    init(client: DiscoveryClient, rulesDir: URL, ruleCache: RuleCache) {
        self.fetch = { try await client.fetchBundled() }
        self.rulesDir = rulesDir
        self.ruleCache = ruleCache
    }

    init(fetch: @escaping () async throws -> BundledResponse, rulesDir: URL) {
        self.fetch = fetch
        self.rulesDir = rulesDir
    }

    func shouldCheck() -> Bool {
        guard let last = UserDefaults.standard.object(forKey: "bundledLastCheck") as? Date else {
            return true
        }
        return Date().timeIntervalSince(last) > Self.checkIntervalSeconds
    }

    func checkOnStartup() {
        guard shouldCheck() else { return }
        Task { await update(force: false) }
    }

    func forceUpdate() async {
        await update(force: true)
    }

    func update(force: Bool) async {
        UserDefaults.standard.set(Date(), forKey: "bundledLastCheck")
        do {
            let response = try await fetch()
            let storedVersion = UserDefaults.standard.string(forKey: "bundledVersion") ?? ""
            guard force || response.version != storedVersion else { return }
            let data = try JSONEncoder().encode(response.rules)
            let dest = rulesDir.appendingPathComponent("bundled.json")
            try data.write(to: dest)
            UserDefaults.standard.set(response.version, forKey: "bundledVersion")
            try await MainActor.run { try self.ruleCache?.load() }
            NSLog("SFlow: bundled.json updated to version \(response.version)")
        } catch {
            NSLog("SFlow: bundled.json update failed: \(error.localizedDescription)")
        }
    }
}
