import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var clickWatcher: ClickWatcher?
    private var ruleCache: RuleCache!
    private var discoveryService: DiscoveryService?
    private var bundledUpdater: BundledUpdater?
    private var statusIndicatorText: String = ""

    private var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "enabled") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Skip full startup when running unit tests
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        checkPermissionsAndStart()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        refreshStatusIcon()

        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: isEnabled ? "✓ Enabled" : "Enabled",
                                    action: #selector(toggleEnabled),
                                    keyEquivalent: "")
        toggleItem.tag = 1
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem(title: "Show Test Toast", action: #selector(showTestToast), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SFlow", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func refreshStatusIcon() {
        guard let button = statusItem.button else { return }
        if let img = NSImage(systemSymbolName: "command", accessibilityDescription: "SFlow") {
            img.isTemplate = true
            button.image = img
            button.title = ""
        } else {
            button.image = nil
            button.title = "⌘"
        }
        button.alphaValue = isEnabled ? 1.0 : 0.4
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        refreshStatusIcon()
        if let item = statusItem.menu?.item(withTag: 1) {
            item.title = isEnabled ? "✓ Enabled" : "Enabled"
        }
        if isEnabled { startWatcher() } else { clickWatcher = nil }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func userDefaultsChanged() {
        ruleCache?.showExperimental = UserDefaults.standard.bool(forKey: "showExperimental")
    }

    @objc private func showTestToast() {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let center = NSPoint(x: frame.midX, y: frame.midY)
        let event = ShortcutEvent(bundleId: "test", shortcutId: "test",
                                  keys: ["meta", "k"], hint: "Test Toast",
                                  mouseX: center.x, mouseY: center.y,
                                  layer: .ruleCache)
        ToastWindow.show(event: event)
    }

    // MARK: - Permissions + Watcher

    private func checkPermissionsAndStart() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            showAlert(
                title: "Accessibility Permission Required",
                message: "SFlow needs Accessibility access to read UI element names.\n\nOpen System Settings → Privacy & Security → Accessibility and enable SFlow.",
                url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
            return
        }
        if #available(macOS 10.15, *) {
            if !CGPreflightListenEventAccess() {
                showAlert(
                    title: "Input Monitoring Permission Required",
                    message: "SFlow needs Input Monitoring access to detect mouse clicks.\n\nOpen System Settings → Privacy & Security → Input Monitoring and enable SFlow.",
                    url: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
                )
                return
            }
        }
        if isEnabled { startWatcher() }
    }

    private func updateStatusItemTitle(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.statusItem?.button else { return }
            self.statusIndicatorText = text
            if text.isEmpty {
                button.title = ""
            } else {
                button.title = " " + text   // small offset from the ⌘ icon
            }
        }
    }

    private func startWatcher() {
        do {
            try RuleStorage.seedBundledIfMissing()
            ruleCache = RuleCache(rootDir: RuleStorage.userRulesDirectory())
            try ruleCache.load()
        } catch {
            NSLog("SFlow: RuleCache load failed: \(error)")
            ruleCache = RuleCache(rootDir: RuleStorage.userRulesDirectory())
        }
        ruleCache.showExperimental = UserDefaults.standard.bool(forKey: "showExperimental")
        NotificationCenter.default.removeObserver(self, name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(userDefaultsChanged),
            name: UserDefaults.didChangeNotification, object: nil
        )

        let client = DiscoveryClient(
            baseURL: DiscoveryClient.productionURL,
            clientVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        )
        MainActor.assumeIsolated { FalsePositiveStore.shared.setClient(client) }

        let updater = BundledUpdater(
            client: client,
            rulesDir: RuleStorage.userRulesDirectory(),
            ruleCache: ruleCache
        )
        bundledUpdater = updater
        updater.checkOnStartup()

        NotificationCenter.default.addObserver(
            forName: .sflowForceReSeed, object: nil, queue: .main
        ) { [weak updater] _ in
            Task { await updater?.forceUpdate() }
        }

        let _attemptStore = DiscoveryAttemptStore(
            fileURL: RuleStorage.userRulesDirectory()
                .deletingLastPathComponent()
                .appendingPathComponent("attempted.json")
        )
        discoveryService = DiscoveryService(
            client: client,
            ruleCache: ruleCache,
            rulesDir: RuleStorage.userRulesDirectory(),
            attemptStore: _attemptStore
        )
        discoveryService?.onStatusChange = { [weak self] status in
            switch status {
            case .idle:
                self?.updateStatusItemTitle("")
            case .running(let name):
                self?.updateStatusItemTitle("✨ Learning \(name)…")
            case .completed:
                self?.updateStatusItemTitle("")
            case .failed:
                self?.updateStatusItemTitle("")
            }
        }
        discoveryService?.observeAppActivation()

        clickWatcher = ClickWatcher(ruleCache: ruleCache) { event in
            Task { @MainActor in
                guard !FalsePositiveStore.shared.isDisabled(shortcutId: event.shortcutId) else { return }
                FalsePositiveStore.shared.toastShown(event: event)
                ToastWindow.show(event: event, onFalsePositive: {
                    FalsePositiveStore.shared.report(
                        shortcutId: event.shortcutId, bundleId: event.bundleId,
                        keys: event.keys, hint: event.hint
                    )
                })
                EventLogger.log(event: event)
            }
        }
    }

    private func showAlert(title: String, message: String, url: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: url)!)
        }
    }
}
