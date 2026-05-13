import AppKit
import Foundation

/// Status changes emitted to the UI indicator.
enum DiscoveryStatus {
    case idle
    case running(appName: String)
    case completed(appName: String)
    case failed(appName: String, message: String)
}

final class DiscoveryService {
    private let client: DiscoveryClient
    private let ruleCache: RuleCache
    private let rulesDir: URL
    private var inFlight: Set<String> = []
    private var attempted: Set<String> = []
    private let queue = DispatchQueue(label: "com.filip.sflow.discovery", qos: .utility)
    var onStatusChange: ((DiscoveryStatus) -> Void)?

    init(client: DiscoveryClient, ruleCache: RuleCache, rulesDir: URL) {
        self.client = client
        self.ruleCache = ruleCache
        self.rulesDir = rulesDir
    }

    func observeAppActivation() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
        guard let bundleId = app.bundleIdentifier else { return }
        if ruleCache.hasRules(bundleId: bundleId) { return }
        if attempted.contains(bundleId) { return }
        if inFlight.contains(bundleId) { return }
        attempted.insert(bundleId)
        inFlight.insert(bundleId)

        let appName = app.localizedName ?? bundleId
        let appVersion = readAppVersion(app) ?? "unknown"
        onStatusChange?(.running(appName: appName))

        queue.async { [weak self] in
            guard let self else { return }
            let menuBar = MenuBarDumper.dump(for: app)
            let skeleton = AXSkeletonExtractor.extract(for: app)
            Task { [weak self] in
                guard let self else { return }
                do {
                    let result = try await self.client.discover(
                        bundleId: bundleId, appName: appName, appVersion: appVersion,
                        menuBar: menuBar, skeleton: skeleton
                    )
                    try self.writeToCache(bundleId: bundleId, appVersion: appVersion, result: result)
                    try self.ruleCache.load()
                    await MainActor.run { self.onStatusChange?(.completed(appName: appName)) }
                } catch {
                    await MainActor.run {
                        self.onStatusChange?(.failed(appName: appName, message: "\(error)"))
                    }
                }
                self.inFlight.remove(bundleId)
            }
        }
    }

    private func writeToCache(bundleId: String, appVersion: String, result: BackendRuleSet) throws {
        let cacheDir = rulesDir.appendingPathComponent("cache")
        try RuleStorage.ensureDirectory(cacheDir)
        let stored = StoredRuleSet(
            bundleId: bundleId,
            appVersion: appVersion,
            fetchedAt: ISO8601DateFormatter().string(from: Date()),
            source: .cloud,
            rulesVersion: result.rulesVersion,
            rules: result.rules
        )
        let data = try JSONEncoder().encode(stored)
        try data.write(to: cacheDir.appendingPathComponent("\(bundleId).json"))
    }

    private func readAppVersion(_ app: NSRunningApplication) -> String? {
        guard let url = app.bundleURL else { return nil }
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: plistURL) else { return nil }
        return (dict["CFBundleShortVersionString"] as? String) ?? (dict["CFBundleVersion"] as? String)
    }
}
