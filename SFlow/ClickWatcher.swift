import AppKit
import CoreGraphics
import ApplicationServices

private var sharedWatcher: ClickWatcher?

final class ClickWatcher {
    typealias Handler = (ShortcutEvent) -> Void

    private let onEvent: Handler
    private let menuBarWatcher = MenuBarWatcher()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastShortcutId: String = ""
    private var lastShortcutTime: Date = .distantPast

    init(onEvent: @escaping Handler) {
        self.onEvent = onEvent
        sharedWatcher = self
        setup()
    }

    private func setup() {
        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: nil
        )
        guard let tap else {
            NSLog("SFlow: CGEventTap creation FAILED — check Input Monitoring permission")
            return
        }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func handleMouseDown() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              let bundleId  = frontmost.bundleIdentifier else { return }

        let nsLoc   = NSEvent.mouseLocation
        let screenH = NSScreen.screens
            .first(where: { NSMouseInRect(nsLoc, $0.frame, false) })?
            .frame.maxY ?? (NSScreen.main?.frame.height ?? 900)
        let axX = Float(nsLoc.x)
        let axY = Float(screenH - nsLoc.y)

        let axApp = AXUIElementCreateApplication(frontmost.processIdentifier)
        var elemRef: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(axApp, axX, axY, &elemRef)

        if result == .success, let element = elemRef {
            var current = element
            for _ in 0..<6 {
                // Layer 1: hardcoded rules
                if let (rule, confidence) = ShortcutRules.match(element: current, bundleId: bundleId),
                   confidence >= .threshold {
                    emit(bundleId: bundleId, shortcutId: rule.shortcutId,
                         keys: rule.keys, hint: rule.hint, loc: nsLoc)
                    return
                }
                // Layer 2: kAXHelpAttribute auto-parse
                // Single-char safety: only accept raw "e"/"k" etc. on clickable roles.
                var helpRef: AnyObject?
                AXUIElementCopyAttributeValue(current, kAXHelpAttribute as CFString, &helpRef)
                if let help = helpRef as? String, !help.isEmpty {
                    let isClickable = ["AXButton","AXMenuItem","AXCell","AXTextField",
                                       "AXCheckBox","AXRadioButton"].contains(role(current))
                    NSLog("SFlow[L2] role=\(self.role(current)) help=\(help.prefix(80))")
                    if help.count > 1 || isClickable,
                       let keys = ShortcutRules.parseShortcut(from: help),
                       MatchConfidence.medium >= .threshold {
                        NSLog("SFlow[L2 MATCH] keys=\(keys) hint=\(help.prefix(80))")
                        let autoId = "auto:\(bundleId):\(keys.joined(separator: "+"))"
                        emit(bundleId: bundleId, shortcutId: autoId,
                             keys: keys, hint: help, loc: nsLoc)
                        return
                    }
                }
                // Layer 3: MenuBarIndex fuzzy match on desc/title/placeholder/identifier
                let query = elementQuery(current)
                NSLog("SFlow[L3] role=\(self.role(current)) query='\(query.prefix(80))'")
                if !query.isEmpty,
                   let (entry, confidence) = menuBarWatcher.currentIndex.lookup(query: query),
                   confidence >= .threshold {
                    NSLog("SFlow[L3 MATCH] query='\(query.prefix(80))' → hint=\(entry.hint) keys=\(entry.keys)")
                    let autoId = "menuindex:\(bundleId):\(entry.keys.joined(separator: "+"))"
                    emit(bundleId: bundleId, shortcutId: autoId,
                         keys: entry.keys, hint: entry.hint, loc: nsLoc)
                    return
                }
                // Layer 4: Universal semantic role heuristics
                if let rule = ShortcutRules.universalRules.first(where: {
                    matchUniversal(current, rule: $0)
                }) {
                    let confidence = MatchConfidence.low
                    if confidence >= .threshold {
                        emit(bundleId: bundleId, shortcutId: rule.shortcutId,
                             keys: rule.keys, hint: rule.hint, loc: nsLoc)
                        return
                    }
                }

                var parentRef: AnyObject?
                guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString,
                                                    &parentRef) == .success,
                      let parent = parentRef else { break }
                current = parent as! AXUIElement
            }
        }

        checkMenuBar(bundleId: bundleId, pid: frontmost.processIdentifier, nsLoc: nsLoc, axX: axX, axY: axY)
    }

    private func role(_ element: AXUIElement) -> String {
        var ref: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &ref)
        return ref as? String ?? ""
    }

    private func matchUniversal(_ element: AXUIElement, rule: ClickRule) -> Bool {
        var roleRef: AnyObject?; var descRef: AnyObject?; var subRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subRef)
        let r = roleRef as? String ?? ""
        let d = (descRef as? String ?? "").lowercased()
        let s = subRef as? String ?? ""
        if let rr = rule.role, r != rr { return false }
        if let ss = rule.subroleEquals, s != ss { return false }
        if let dd = rule.descContains, !d.contains(dd.lowercased()) { return false }
        return true
    }

    /// Returns the best query string from an AX element's visible and programmatic attributes.
    /// Priority: description > title > placeholder > normalized kAXIdentifier.
    private func elementQuery(_ element: AXUIElement) -> String {
        let visibleAttrs = [kAXDescriptionAttribute, kAXTitleAttribute,
                            kAXPlaceholderValueAttribute]
        for attr in visibleAttrs {
            var ref: AnyObject?
            AXUIElementCopyAttributeValue(element, attr as CFString, &ref)
            if let s = ref as? String, s.count >= 3 { return s }
        }
        // Fallback: normalize AX identifier
        var idRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &idRef)
        if let id = idRef as? String, !id.isEmpty {
            return normalizeIdentifier(id)
        }
        return ""
    }

    /// "searchButton" → "search", "composeTextField" → "compose", "replyAllButton" → "reply all"
    private func normalizeIdentifier(_ id: String) -> String {
        let suffixes = ["Button", "TextField", "Field", "View", "Item", "Bar", "Control"]
        var s = id
        for suffix in suffixes { if s.hasSuffix(suffix) { s = String(s.dropLast(suffix.count)); break } }
        // camelCase → words: "replyAll" → "reply all"
        var result = ""
        for ch in s {
            if ch.isUppercase, !result.isEmpty { result += " " }
            result += ch.lowercased()
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private func checkMenuBar(bundleId: String, pid: pid_t, nsLoc: NSPoint, axX: Float, axY: Float) {
        let sysWide = AXUIElementCreateSystemWide()
        var elemRef: AXUIElement?
        guard AXUIElementCopyElementAtPosition(sysWide, axX, axY, &elemRef) == .success,
              let element = elemRef else { return }

        var elemPid: pid_t = 0
        guard AXUIElementGetPid(element, &elemPid) == .success, elemPid == pid else { return }

        var roleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""

        if role != "AXMenuItem" {
            if let (rule, _) = ShortcutRules.match(element: element, bundleId: bundleId) {
                emit(bundleId: bundleId, shortcutId: rule.shortcutId,
                     keys: rule.keys, hint: rule.hint, loc: nsLoc)
            }
            return
        }

        var cmdCharRef: AnyObject?
        var cmdModsRef: AnyObject?
        var titleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXMenuItemCmdCharAttribute as CFString, &cmdCharRef)
        AXUIElementCopyAttributeValue(element, kAXMenuItemCmdModifiersAttribute as CFString, &cmdModsRef)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)

        guard let cmdKey = (cmdCharRef as? String)?.lowercased(), !cmdKey.isEmpty else { return }

        let rawMods = (cmdModsRef as? Int) ?? 0
        let mods = MenuBarIndex.parseModifiers(rawMods: rawMods)
        let keys      = mods + [cmdKey]
        let hint      = (titleRef as? String) ?? cmdKey.uppercased()
        let shortcutId = "menu:\(bundleId):\(keys.joined(separator: "+"))"
        emit(bundleId: bundleId, shortcutId: shortcutId, keys: keys, hint: hint, loc: nsLoc)
    }

    private func emit(bundleId: String, shortcutId: String, keys: [String],
                      hint: String, loc: NSPoint) {
        let now = Date()
        guard shortcutId != lastShortcutId || now.timeIntervalSince(lastShortcutTime) >= 2.0 else { return }
        lastShortcutId = shortcutId
        lastShortcutTime = now
        let event = ShortcutEvent(bundleId: bundleId, shortcutId: shortcutId,
                                  keys: keys, hint: hint,
                                  mouseX: loc.x, mouseY: loc.y)
        onEvent(event)
    }

    deinit {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        sharedWatcher = nil
    }
}

private let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .leftMouseDown {
        sharedWatcher?.handleMouseDown()
    }
    return Unmanaged.passUnretained(event)
}
