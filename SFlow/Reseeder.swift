import AppKit
import ApplicationServices
import Foundation

enum Reseeder {

    static let verifiedApps = [
        "com.tinyspeck.slackmacgap",       // Slack
        "md.obsidian",                      // Obsidian
        "com.linear",                       // Linear
        "com.todesktop.230313mzl4w4u92",    // Cursor
    ]

    enum Mode {
        case all
        case single(String)
    }

    static func run(arguments: [String]) {
        let mode = parseMode(arguments)
        guard preflight() else { exit(1) }

        backupBundledJsonIfPresent()

        switch mode {
        case .all:
            for bundleId in verifiedApps {
                reseedOne(bundleId)
            }
        case .single(let bundleId):
            reseedOne(bundleId)
        }
    }

    private static func backupBundledJsonIfPresent() {
        let root = RuleStorage.userRulesDirectory()
        let bundled = root.appendingPathComponent("bundled.json")
        guard FileManager.default.fileExists(atPath: bundled.path) else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backup = root.appendingPathComponent("bundled.json.bak.\(stamp)")
        do {
            try FileManager.default.copyItem(at: bundled, to: backup)
            print("Reseeder: backed up bundled.json → \(backup.lastPathComponent)")
        } catch {
            fputs("Reseeder: backup failed (\(error)) — aborting to avoid data loss.\n", stderr)
            exit(2)
        }
    }

    private static func parseMode(_ arguments: [String]) -> Mode {
        if let idx = arguments.firstIndex(of: "--reseed"),
           idx + 1 < arguments.count {
            return .single(arguments[idx + 1])
        }
        return .all
    }

    private static func preflight() -> Bool {
        let bundle = Bundle.main.bundleIdentifier ?? "com.gocamping.SFlow"
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundle)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if !others.isEmpty {
            let pids = others.map { String($0.processIdentifier) }.joined(separator: ",")
            fputs("Reseeder: another SFlow is running (pid \(pids)). Quit it first.\n", stderr)
            return false
        }
        if !AXIsProcessTrusted() {
            fputs("Reseeder: Accessibility permission not granted. Grant it in System Settings > Privacy & Security > Accessibility.\n", stderr)
            return false
        }
        return true
    }

    private static func reseedOne(_ bundleId: String) {
        // 1. Is the app installed?
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            print("Reseeder: \(bundleId) — not installed, skipping")
            return
        }

        // 2. Launch + activate (synchronously wait for NSRunningApplication).
        guard let runningApp = launchAndWait(at: appURL, bundleId: bundleId) else {
            print("Reseeder: \(bundleId) — launch failed or timed out, skipping")
            return
        }

        // 3. Wait for AX readiness.
        guard waitForAXReady(app: runningApp) else {
            print("Reseeder: \(bundleId) — AX not ready within 10s, skipping")
            return
        }

        // 4. Capture skeleton + menu bar.
        let menuBar = MenuBarDumper.dump(for: runningApp)
        let skeleton = AXSkeletonExtractor.extract(for: runningApp)

        // 5. POST to backend (block on the async call).
        let appName = runningApp.localizedName ?? bundleId
        let appVersion = readAppVersion(runningApp) ?? "unknown"
        let clientVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "reseed"
        let client = DiscoveryClient(baseURL: DiscoveryClient.productionURL, clientVersion: clientVersion)

        let (result, rawError) = discoverBlocking(
            client: client, bundleId: bundleId, appName: appName, appVersion: appVersion,
            menuBar: menuBar, skeleton: skeleton
        )

        guard let result else {
            if let rawError {
                let errPath = "/tmp/sflow-reseed-error-\(bundleId).txt"
                try? rawError.write(toFile: errPath, atomically: true, encoding: .utf8)
                print("Reseeder: \(bundleId) — discover failed, raw → \(errPath)")
            } else {
                print("Reseeder: \(bundleId) — discover failed (no response)")
            }
            return
        }

        // 6. Write to cache/<bundleId>.json.
        do {
            let cacheDir = RuleStorage.userRulesDirectory().appendingPathComponent("cache", isDirectory: true)
            try RuleStorage.ensureDirectory(cacheDir)
            let stored = StoredRuleSet(
                bundleId: bundleId,
                appVersion: appVersion,
                fetchedAt: ISO8601DateFormatter().string(from: Date()),
                source: .cloud,
                rulesVersion: result.rulesVersion,
                rules: result.rules
            )
            let cachePath = cacheDir.appendingPathComponent("\(bundleId).json")
            let data = try JSONEncoder().encode(stored)
            try data.write(to: cachePath)
            print("Reseeder: ✓ \(bundleId): \(result.rules.count) rules → \(cachePath.path)")
        } catch {
            print("Reseeder: \(bundleId) — failed to write cache: \(error)")
        }

        // 7. Do NOT quit the target app — user may have unsaved work.
    }

    // MARK: - Launch

    private static func launchAndWait(at appURL: URL, bundleId: String) -> NSRunningApplication? {
        // Short-circuit if already running.
        if let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            existing.activate(options: [])
            return existing
        }

        let sem = DispatchSemaphore(value: 0)
        var captured: NSRunningApplication?
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, _ in
            captured = app
            sem.signal()
        }

        if sem.wait(timeout: .now() + 15) == .timedOut {
            return nil
        }
        // Give the app a brief moment to register as running.
        Thread.sleep(forTimeInterval: 0.5)
        captured?.activate(options: [])
        return captured
    }

    // MARK: - AX readiness

    private static func waitForAXReady(app: NSRunningApplication) -> Bool {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        // Enable enhanced AX surface where supported (best-effort; ignore failures).
        AXUIElementSetAttributeValue(axApp, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)

        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            var roleRef: AnyObject?
            let err = AXUIElementCopyAttributeValue(axApp, kAXRoleAttribute as CFString, &roleRef)
            if err == .success, (roleRef as? String) == "AXApplication" {
                // Brief settle so the menu bar populates.
                Thread.sleep(forTimeInterval: 0.5)
                return true
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    // MARK: - Sync wrapper around async discover

    private static func discoverBlocking(
        client: DiscoveryClient,
        bundleId: String, appName: String, appVersion: String,
        menuBar: [MenuBarDumpEntry], skeleton: [SkeletonItem]
    ) -> (BackendRuleSet?, String?) {
        let sem = DispatchSemaphore(value: 0)
        var result: BackendRuleSet?
        var rawError: String?

        Task {
            do {
                result = try await client.discover(
                    bundleId: bundleId, appName: appName, appVersion: appVersion,
                    menuBar: menuBar, skeleton: skeleton
                )
            } catch let DiscoveryClientError.http(code, body) {
                rawError = "HTTP \(code)\n\(body)"
            } catch let DiscoveryClientError.malformedResponse(msg) {
                rawError = "malformed response: \(msg)"
            } catch let DiscoveryClientError.rateLimited(retry) {
                rawError = "rate limited; retry after \(retry)s"
            } catch {
                rawError = "\(error)"
            }
            sem.signal()
        }

        // Backend may spend up to ~45s; client timeout is 90s. Give it 120s.
        if sem.wait(timeout: .now() + 120) == .timedOut {
            return (nil, "timed out waiting for backend")
        }
        return (result, rawError)
    }

    private static func readAppVersion(_ app: NSRunningApplication) -> String? {
        guard let url = app.bundleURL else { return nil }
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: plistURL) else { return nil }
        return (dict["CFBundleShortVersionString"] as? String) ?? (dict["CFBundleVersion"] as? String)
    }
}
