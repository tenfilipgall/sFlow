import AppKit
import ApplicationServices

/// Harvests keyboard shortcuts from a context menu opened by a right-click.
/// Reads `kAXMenuItemCmdChar` / `kAXMenuItemCmdModifiers` / `kAXMenuItemCmdVirtualKey`
/// from each `AXMenuItem` in the focused app's open `AXMenu`, then records each
/// (action, keys, item-rect) into `DiscoveredStore`. Subsequent left-clicks on
/// a menu row dispatch through `ClickWatcher`'s Layer 0.3 lookup and emit a toast.
///
/// One harvest per right-click is enough — macOS only allows one context menu
/// open at a time, and the menu closes on selection/dismissal.
enum RightClickMenuHarvester {

    /// Per-cmdModifier bit, mirroring HIServices AXAttributeConstants.h:
    /// kAXMenuItemModifierShift=1<<0, Option=1<<1, Control=1<<2, NoCommand=1<<3.
    /// Cmd is implied unless the NoCommand bit is set.
    static let modifierShift: Int     = 1 << 0
    static let modifierOption: Int    = 1 << 1
    static let modifierControl: Int   = 1 << 2
    static let modifierNoCommand: Int = 1 << 3

    /// Translates a (cmdChar, cmdModifiers, cmdVirtualKey) triple into SFlow's
    /// key array convention (e.g. ["cmd","shift","c"]). Returns nil when the
    /// menu item has no shortcut (cmdChar empty AND virtualKey unset).
    ///
    /// `cmdChar` arrives as a single character ("c", "/", "+"). When the
    /// shortcut is a special key (F-keys, arrows, return) macOS reports
    /// `cmdChar=""` and `cmdVirtualKey` set instead.
    static func parseShortcut(cmdChar: String, cmdModifiers: Int, cmdVirtualKey: Int? = nil) -> [String]? {
        let trimmedChar = cmdChar.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyToken: String? = {
            if !trimmedChar.isEmpty { return trimmedChar.lowercased() }
            if let vk = cmdVirtualKey, let mapped = virtualKeyName(vk) { return mapped }
            return nil
        }()
        guard let key = keyToken else { return nil }

        var tokens: [String] = []
        if (cmdModifiers & modifierNoCommand) == 0 { tokens.append("cmd") }
        if (cmdModifiers & modifierControl)   != 0 { tokens.append("ctrl") }
        if (cmdModifiers & modifierOption)    != 0 { tokens.append("alt") }
        if (cmdModifiers & modifierShift)     != 0 { tokens.append("shift") }
        tokens.append(key)
        return tokens
    }

    /// Maps macOS virtual key codes (kVK_*) to SFlow's keyword names. Covers
    /// the keys that menu items commonly bind: F-keys, arrows, return, escape,
    /// tab, delete, space. Unrecognized keys return nil — caller drops the entry.
    static func virtualKeyName(_ code: Int) -> String? {
        switch code {
        case 0x24: return "return"
        case 0x30: return "tab"
        case 0x31: return "space"
        case 0x33: return "delete"
        case 0x35: return "escape"
        case 0x7B: return "left"
        case 0x7C: return "right"
        case 0x7D: return "down"
        case 0x7E: return "up"
        case 0x7A: return "f1"
        case 0x78: return "f2"
        case 0x63: return "f3"
        case 0x76: return "f4"
        case 0x60: return "f5"
        case 0x61: return "f6"
        case 0x62: return "f7"
        case 0x64: return "f8"
        case 0x65: return "f9"
        case 0x6D: return "f10"
        case 0x67: return "f11"
        case 0x6F: return "f12"
        default:   return nil
        }
    }

    /// Walks `axApp` looking for the first open `AXMenu` (typically appears as
    /// a top-level child after right-click). Returns nil if no menu is open.
    /// Shallow walk (depth ≤ 4) — context menus sit near the app root.
    static func findOpenMenu(in axApp: AXUIElement, depth: Int = 0) -> AXUIElement? {
        if depth > 4 { return nil }
        var roleRef: AnyObject?
        AXUIElementCopyAttributeValue(axApp, kAXRoleAttribute as CFString, &roleRef)
        if (roleRef as? String) == "AXMenu" { return axApp }

        var childrenRef: AnyObject?
        AXUIElementCopyAttributeValue(axApp, kAXChildrenAttribute as CFString, &childrenRef)
        guard let children = childrenRef as? [AXUIElement] else { return nil }
        for c in children {
            if let m = findOpenMenu(in: c, depth: depth + 1) { return m }
        }
        return nil
    }

    /// Reads each `AXMenuItem` child of `menu`, extracts its title + shortcut +
    /// rect, and records to `store`. Returns the number of entries recorded
    /// (useful for tests / diagnostics). Skips menu items without a shortcut.
    @discardableResult
    static func harvest(menu: AXUIElement, bundleId: String,
                         into store: DiscoveredStore = .shared) -> Int {
        var childrenRef: AnyObject?
        AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &childrenRef)
        guard let items = childrenRef as? [AXUIElement] else { return 0 }

        var recorded = 0
        for item in items {
            var roleRef: AnyObject?
            AXUIElementCopyAttributeValue(item, kAXRoleAttribute as CFString, &roleRef)
            guard (roleRef as? String) == "AXMenuItem" else { continue }

            var titleRef: AnyObject?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
            let title = (titleRef as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else { continue }

            var cmdCharRef: AnyObject?; var cmdModRef: AnyObject?; var cmdVKRef: AnyObject?
            AXUIElementCopyAttributeValue(item, "AXMenuItemCmdChar" as CFString, &cmdCharRef)
            AXUIElementCopyAttributeValue(item, "AXMenuItemCmdModifiers" as CFString, &cmdModRef)
            AXUIElementCopyAttributeValue(item, "AXMenuItemCmdVirtualKey" as CFString, &cmdVKRef)
            let cmdChar = cmdCharRef as? String ?? ""
            let cmdMod  = (cmdModRef as? Int) ?? (cmdModRef as? NSNumber)?.intValue ?? 0
            let cmdVK: Int? = (cmdVKRef as? Int) ?? (cmdVKRef as? NSNumber)?.intValue

            guard let keys = parseShortcut(cmdChar: cmdChar, cmdModifiers: cmdMod,
                                            cmdVirtualKey: cmdVK) else { continue }

            guard let rect = menuItemRect(item) else { continue }

            let entry = DiscoveredEntry(
                bundleId: bundleId,
                actionName: title,
                keys: keys,
                identifier: nil,
                rect: DiscoveredEntry.CGRectCodable(rect),
                observedAt: Date(),
                source: "rightclick_menu"
            )
            store.record(entry)
            recorded += 1
        }
        if recorded > 0 {
            NSLog("SFlow[RightClick]: harvested \(recorded) menu items from \(bundleId)")
        }
        return recorded
    }

    private static func menuItemRect(_ item: AXUIElement) -> CGRect? {
        var posRef: AnyObject?; var sizeRef: AnyObject?
        AXUIElementCopyAttributeValue(item, kAXPositionAttribute as CFString, &posRef)
        AXUIElementCopyAttributeValue(item, kAXSizeAttribute as CFString, &sizeRef)
        guard let pos = posRef, let sz = sizeRef,
              CFGetTypeID(pos) == AXValueGetTypeID(),
              CFGetTypeID(sz) == AXValueGetTypeID() else { return nil }
        var p = CGPoint.zero; var s = CGSize.zero
        let posValue = pos as! AXValue
        let szValue = sz as! AXValue
        guard AXValueGetValue(posValue, .cgPoint, &p),
              AXValueGetValue(szValue, .cgSize, &s),
              s.width > 0, s.height > 0 else { return nil }
        return CGRect(origin: p, size: s)
    }
}
