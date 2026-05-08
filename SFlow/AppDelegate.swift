import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var clickWatcher: ClickWatcher?

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
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SFlow", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func refreshStatusIcon() {
        guard let button = statusItem.button else { return }
        let img = NSImage(systemSymbolName: "command", accessibilityDescription: "SFlow")
        img?.isTemplate = true
        button.image = img
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
        if isEnabled { startWatcher() }
    }

    private func startWatcher() {
        clickWatcher = ClickWatcher { event in
            ToastWindow.show(event: event)
            EventLogger.log(event: event)
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
