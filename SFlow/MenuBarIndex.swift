import AppKit
import ApplicationServices

struct MenuBarEntry {
    let keys: [String]
    let hint: String
}

struct MenuBarIndex {
    private(set) var titleMap: [String: MenuBarEntry] = [:]

    var allEntries: [String: MenuBarEntry] { titleMap }

    init() {}

    init(from entries: [String: MenuBarEntry]) {
        self.titleMap = entries
    }

    // MARK: - Build index for a running app

    mutating func build(for app: NSRunningApplication) {
        titleMap.removeAll()
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var menuBarRef: AnyObject?
        guard AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString,
                                            &menuBarRef) == .success,
              let menuBar = menuBarRef else { return }
        scanMenu(menuBar as! AXUIElement, depth: 0)
    }

    private mutating func scanMenu(_ element: AXUIElement, depth: Int) {
        guard depth < 4 else { return }
        var childrenRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString,
                                            &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return }

        for child in children {
            var roleRef: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            let role = roleRef as? String ?? ""

            if role == "AXMenuItem" {
                var titleRef: AnyObject?
                var cmdCharRef: AnyObject?
                var cmdModsRef: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef)
                AXUIElementCopyAttributeValue(child, kAXMenuItemCmdCharAttribute as CFString, &cmdCharRef)
                AXUIElementCopyAttributeValue(child, kAXMenuItemCmdModifiersAttribute as CFString, &cmdModsRef)

                if let title = titleRef as? String, !title.isEmpty,
                   let cmdChar = (cmdCharRef as? String)?.lowercased(), !cmdChar.isEmpty {
                    let rawMods = (cmdModsRef as? Int) ?? 0
                    let mods = Self.parseModifiers(rawMods: rawMods)
                    let keys = mods + [cmdChar]
                    if titleMap[title.lowercased()] == nil {
                        insert(title: title, keys: keys)
                    }
                }
            }
            scanMenu(child, depth: depth + 1)
        }
    }

    // MARK: - Lookup

    func lookup(query: String) -> (entry: MenuBarEntry, confidence: MatchConfidence)? {
        guard query.count >= 3 else { return nil }
        let q = query.lowercased()
        if let entry = titleMap[q] { return (entry: entry, confidence: .medium) }
        if let pair = titleMap.first(where: { q.contains($0.key) }) {
            return (entry: pair.value, confidence: .medium)
        }
        return nil
    }

    // MARK: - Mutation helpers

    mutating func insert(title: String, keys: [String]) {
        titleMap[title.lowercased()] = MenuBarEntry(keys: keys, hint: title)
    }

    mutating func merge(_ other: [String: MenuBarEntry]) {
        for (k, v) in other where titleMap[k] == nil {
            titleMap[k] = v
        }
    }

    // MARK: - Modifier parsing

    /// Converts raw AXMenuItemCmdModifiers bitmask to modifier key array.
    /// Bit 3 (0x08) NOT set → cmd included. Bit 0 = shift, bit 1 = alt, bit 2 = ctrl.
    static func parseModifiers(rawMods: Int) -> [String] {
        var mods: [String] = []
        if rawMods & 0x08 == 0 { mods.append("meta") }
        if rawMods & 0x01 != 0 { mods.append("shift") }
        if rawMods & 0x02 != 0 { mods.append("alt") }
        if rawMods & 0x04 != 0 { mods.append("ctrl") }
        return mods
    }
}

// MARK: - App-switch watcher

final class MenuBarWatcher {
    private(set) var currentIndex = MenuBarIndex()
    private var observer: Any?
    private let queue = DispatchQueue(label: "com.filip.sflow.menubar", qos: .utility)

    init() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication else { return }
            self?.loadOrScan(app: app)
        }
        if let current = NSWorkspace.shared.frontmostApplication {
            loadOrScan(app: current)
        }
        for app in NSWorkspace.shared.runningApplications
            where app.activationPolicy == .regular && app.bundleIdentifier != nil {
            loadOrScan(app: app)
        }
    }

    private func loadOrScan(app: NSRunningApplication) {
        guard let bundleId = app.bundleIdentifier else { return }
        let version = appVersion(app) ?? "unknown"

        if let cached = MenuBarCache.load(bundleId: bundleId, version: version) {
            DispatchQueue.main.async { [weak self] in
                self?.currentIndex = MenuBarIndex(from: cached)
            }
            return
        }

        queue.async { [weak self] in
            var index = MenuBarIndex()
            index.build(for: app)
            if ElectronShortcutScanner.isElectronApp(app) {
                let asarEntries = ElectronShortcutScanner.scan(app: app)
                index.merge(asarEntries)
            }
            MenuBarCache.save(bundleId: bundleId, version: version, entries: index.allEntries)
            DispatchQueue.main.async { [weak self] in
                self?.currentIndex = index
            }
        }
    }

    private func appVersion(_ app: NSRunningApplication) -> String? {
        guard let url = app.bundleURL else { return nil }
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        return (NSDictionary(contentsOf: plistURL))?["CFBundleVersion"] as? String
    }

    deinit {
        if let obs = observer { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
    }
}
