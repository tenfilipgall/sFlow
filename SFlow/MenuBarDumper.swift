import AppKit
import ApplicationServices

struct MenuBarDumpEntry: Codable {
    let path: [String]
    let shortcut: String?
}

enum MenuBarDumper {
    static func dump(for app: NSRunningApplication) -> [MenuBarDumpEntry] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var menuBarRef: AnyObject?
        guard AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString,
                                            &menuBarRef) == .success,
              let menuBar = menuBarRef else { return [] }
        var out: [MenuBarDumpEntry] = []
        walk(menuBar as! AXUIElement, path: [], out: &out, depth: 0)
        return out
    }

    private static func walk(_ element: AXUIElement, path: [String],
                              out: inout [MenuBarDumpEntry], depth: Int) {
        guard depth < 5 else { return }
        var childrenRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        guard let children = childrenRef as? [AXUIElement] else { return }

        for child in children {
            var roleRef: AnyObject?
            var titleRef: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef)
            let role = roleRef as? String ?? ""
            let title = titleRef as? String ?? ""

            if role == "AXMenuItem" {
                var cmdCharRef: AnyObject?
                var cmdModsRef: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXMenuItemCmdCharAttribute as CFString, &cmdCharRef)
                AXUIElementCopyAttributeValue(child, kAXMenuItemCmdModifiersAttribute as CFString, &cmdModsRef)
                let cmdChar = (cmdCharRef as? String) ?? ""
                let rawMods = (cmdModsRef as? Int) ?? 0
                let shortcut = formatShortcut(cmdChar: cmdChar, rawMods: rawMods)

                if !title.isEmpty {
                    out.append(MenuBarDumpEntry(path: path + [title], shortcut: shortcut))
                }
            }

            let newPath = title.isEmpty ? path : (depth == 0 ? [title] : path + [title])
            walk(child, path: newPath, out: &out, depth: depth + 1)
        }
    }

    /// Returns "cmd+shift+k" form. nil if no shortcut character.
    static func formatShortcut(cmdChar: String, rawMods: Int) -> String? {
        let key = cmdChar.lowercased()
        guard !key.isEmpty else { return nil }
        var parts: [String] = []
        if rawMods & 0x08 == 0 { parts.append("cmd") }
        if rawMods & 0x01 != 0 { parts.append("shift") }
        if rawMods & 0x02 != 0 { parts.append("alt") }
        if rawMods & 0x04 != 0 { parts.append("ctrl") }
        parts.append(key)
        return parts.joined(separator: "+")
    }
}
