import AppKit
import Foundation

extension Notification.Name {
    static let sflowDiscoveryStateChanged =
        Notification.Name("com.sflow.discoveryStateChanged")
}

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
    private let attemptStore: DiscoveryAttemptStore
    private var inFlight: Set<String> = []
    private let queue = DispatchQueue(label: "com.filip.sflow.discovery", qos: .utility)
    var onStatusChange: ((DiscoveryStatus) -> Void)?

    init(client: DiscoveryClient,
         ruleCache: RuleCache,
         rulesDir: URL,
         attemptStore: DiscoveryAttemptStore) {
        self.client = client
        self.ruleCache = ruleCache
        self.rulesDir = rulesDir
        self.attemptStore = attemptStore
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
        if inFlight.contains(bundleId) { return }
        if !attemptStore.canAttempt(bundleId: bundleId) { return }

        inFlight.insert(bundleId)

        let appName = app.localizedName ?? bundleId
        let appVersion = readAppVersion(app) ?? "unknown"
        onStatusChange?(.running(appName: appName))

        queue.async { [weak self] in
            self?.runDiscovery(app: app, bundleId: bundleId,
                               appName: appName, appVersion: appVersion)
        }
    }

    private func runDiscovery(app: NSRunningApplication,
                              bundleId: String,
                              appName: String,
                              appVersion: String) {
        var menuBar = MenuBarDumper.dump(for: app)
        var skeleton = AXSkeletonExtractor.extract(for: app)
        NSLog("SFlow discovery [\(bundleId)] runDiscovery start: skeleton.count=\(skeleton.count), menuBar.count=\(menuBar.count)")

        // Backend has a hard cap of 500 items per array. Big IDE apps
        // (Android Studio = ~575 menu items) overflow the Zod max(500) constraint
        // and get rejected with HTTP 400. Cap on the client so we always send a
        // valid payload. NSLog only fires when truncation actually happens.
        let maxItems = 500
        if menuBar.count > maxItems {
            NSLog("SFlow discovery [\(bundleId)] menuBar truncated: \(menuBar.count) → \(maxItems)")
            menuBar = Array(menuBar.prefix(maxItems))
        }
        if skeleton.count > maxItems {
            NSLog("SFlow discovery [\(bundleId)] skeleton truncated: \(skeleton.count) → \(maxItems)")
            skeleton = Array(skeleton.prefix(maxItems))
        }

        if skeleton.count < 3 && menuBar.isEmpty {
            // App likely still loading AX tree — wait 15s and retry once
            NSLog("SFlow: empty AX for \(bundleId), waiting 15s for app to settle")
            Thread.sleep(forTimeInterval: 15)
            menuBar = MenuBarDumper.dump(for: app)
            skeleton = AXSkeletonExtractor.extract(for: app)
            NSLog("SFlow discovery [\(bundleId)] after pre-check wait: skeleton.count=\(skeleton.count), menuBar.count=\(menuBar.count)")
        }

        if skeleton.count < 3 && menuBar.isEmpty {
            self.attemptStore.recordFailure(bundleId: bundleId, reason: .emptySkeleton)
            DispatchQueue.main.async {
                self.onStatusChange?(.failed(
                    appName: appName,
                    message: DiscoveryFailureReason.emptySkeleton.displayString
                ))
                NotificationCenter.default.post(
                    name: .sflowDiscoveryStateChanged, object: nil
                )
            }
            self.inFlight.remove(bundleId)
            return
        }

        // Sub-cel 1.20: best-effort per-app locale. AXLanguage is rarely set
        // by apps, so we usually fall back to system locale — fine for the
        // typical case (PL system = PL Slack UI).
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appLocale = LocaleDetector.detect(for: axApp)
        Task { [weak self] in
            await self?.callBackendAndStore(
                bundleId: bundleId, appName: appName, appVersion: appVersion,
                menuBar: menuBar, skeleton: skeleton, appLocale: appLocale
            )
        }
    }

    private func callBackendAndStore(
        bundleId: String, appName: String, appVersion: String,
        menuBar: [MenuBarDumpEntry], skeleton: [SkeletonItem],
        appLocale: String
    ) async {
        defer {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .sflowDiscoveryStateChanged, object: nil
                )
            }
            self.inFlight.remove(bundleId)
        }
        NSLog("SFlow discovery [\(bundleId)] callBackendAndStore: starting backend call, payload skeleton=\(skeleton.count) menuBar=\(menuBar.count)")

        let result: BackendRuleSet
        do {
            result = try await self.client.discover(
                bundleId: bundleId, appName: appName, appVersion: appVersion,
                menuBar: menuBar, skeleton: skeleton, appLocale: appLocale
            )
        } catch {
            let reason = DiscoveryFailureReason.from(error: error)
            NSLog("SFlow discovery [\(bundleId)] backend call FAILED: \(error) → reason=\(reason.rawValue)")
            self.attemptStore.recordFailure(bundleId: bundleId, reason: reason)
            await MainActor.run {
                self.onStatusChange?(.failed(
                    appName: appName, message: reason.displayString
                ))
            }
            return
        }

        if result.rules.isEmpty {
            NSLog("SFlow discovery [\(bundleId)] backend returned 0 rules — recording .noRulesGenerated")
            self.attemptStore.recordFailure(bundleId: bundleId, reason: .noRulesGenerated)
            await MainActor.run {
                self.onStatusChange?(.failed(
                    appName: appName,
                    message: DiscoveryFailureReason.noRulesGenerated.displayString
                ))
            }
            return
        }

        do {
            NSLog("SFlow discovery [\(bundleId)] backend success: \(result.rules.count) rules — writing to cache")
            try self.writeToCache(bundleId: bundleId, appVersion: appVersion, result: result)
            try self.ruleCache.load()
            self.attemptStore.recordSuccess(bundleId: bundleId)
            await MainActor.run {
                self.onStatusChange?(.completed(appName: appName))
            }
        } catch {
            // Local I/O failure — classify as parseError (closest match) so
            // the entry persists and backoff applies. Treat as transient.
            NSLog("SFlow discovery [\(bundleId)] write/load FAILED: \(error)")
            self.attemptStore.recordFailure(bundleId: bundleId, reason: .parseError)
            await MainActor.run {
                self.onStatusChange?(.failed(
                    appName: appName, message: "Failed to write rule cache"
                ))
            }
        }
    }

    /// User-initiated retry triggered from Apps tab.
    /// Resets the backoff entry and runs the discovery pipeline immediately.
    /// If the app is not currently running, emits a `.failed` status with
    /// guidance to launch the app first.
    func forceRetry(bundleId: String) {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleId
        ).first else {
            // App not running — leave the store entry intact so the user
            // can find the failed app again. Surface a clear message.
            NSLog("SFlow: forceRetry(\(bundleId)) — app not running, asking user to launch first")
            DispatchQueue.main.async {
                self.onStatusChange?(.failed(
                    appName: bundleId,
                    message: "Launch the app first, then try again"
                ))
                // Don't post sflowDiscoveryStateChanged — nothing changed in the
                // store, so the AppsTab list should NOT refresh (entry stays).
            }
            return
        }

        // App is running — safe to clear the backoff entry and proceed.
        attemptStore.forceRetry(bundleId: bundleId)

        if inFlight.contains(bundleId) {
            NSLog("SFlow: forceRetry(\(bundleId)) — already inFlight, skipping")
            return
        }
        inFlight.insert(bundleId)

        let appName = app.localizedName ?? bundleId
        let appVersion = readAppVersion(app) ?? "unknown"
        NSLog("SFlow: forceRetry(\(bundleId)) — starting discovery for \(appName) v\(appVersion)")
        DispatchQueue.main.async {
            self.onStatusChange?(.running(appName: appName))
            // Post notification so AppsTab refresh removes entry from failed list
            // and shows the running state in menu bar correctly.
            NotificationCenter.default.post(
                name: .sflowDiscoveryStateChanged, object: nil
            )
        }

        queue.async { [weak self] in
            self?.runDiscovery(app: app, bundleId: bundleId,
                               appName: appName, appVersion: appVersion)
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
