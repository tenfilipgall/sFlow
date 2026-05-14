import AppKit
import CoreGraphics
import ApplicationServices

private var sharedWatcher: ClickWatcher?

final class ClickWatcher {
    typealias Handler = (ShortcutEvent) -> Void

    private let onEvent: Handler
    private let menuBarWatcher = MenuBarWatcher()
    private let ruleCache: RuleCache
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastShortcutId: String = ""
    private var lastShortcutTime: Date = .distantPast
    private var emitFiredInCurrentClick: Bool = false

    init(ruleCache: RuleCache, onEvent: @escaping Handler) {
        self.ruleCache = ruleCache
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

    // Roles whose title/description carry semantic UI meaning (vs. arbitrary user content).
    // Used to gate Layers 3 and 4 — structural roles like AXWindow/AXTextArea are excluded.
    private static let interactiveRoles: Set<String> = [
        "AXButton", "AXTextField", "AXSearchField", "AXCell",
        "AXMenuItem", "AXCheckBox", "AXRadioButton",
        "AXLink", "AXPopUpButton", "AXComboBox",
    ]

    static func parseAriaShortcut(_ value: String) -> [String]? {
        guard !value.isEmpty else { return nil }
        let tokens = value.split(separator: "+", omittingEmptySubsequences: true).map(String.init)
        guard !tokens.isEmpty else { return nil }
        var result: [String] = []
        for token in tokens {
            switch token {
            case "Meta":       result.append("meta")
            case "Control":    result.append("ctrl")
            case "Alt":        result.append("alt")
            case "Shift":      result.append("shift")
            case "Enter":      result.append("enter")
            case "Space":      result.append("space")
            case "Escape":     result.append("escape")
            case "Tab":        result.append("tab")
            case "Backspace":  result.append("backspace")
            case "Delete":     result.append("delete")
            case "ArrowUp":    result.append("up")
            case "ArrowDown":  result.append("down")
            case "ArrowLeft":  result.append("left")
            case "ArrowRight": result.append("right")
            default:
                if token.hasPrefix("Key"), token.count == 4, let last = token.last, last.isLetter {
                    result.append(String(last).lowercased())
                } else if token.hasPrefix("Digit"), token.count == 6, let last = token.last, last.isNumber {
                    result.append(String(last))
                } else if token.hasPrefix("F"), let n = Int(token.dropFirst()), (1...12).contains(n) {
                    // F13–F20 are valid ARIA but outside SFlow's supported key range; omit silently
                    result.append(token.lowercased())
                } else {
                    return nil
                }
            }
        }
        return result.isEmpty ? nil : result
    }

    func handleMouseDown() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              let bundleId  = frontmost.bundleIdentifier else { return }

        emitFiredInCurrentClick = false
        var firstInteractiveMiss: MissEvent? = nil

        let nsLoc   = NSEvent.mouseLocation
        // AX uses Quartz coords (origin = top-left of the menu-bar-bearing screen).
        // NSEvent.mouseLocation uses NSScreen coords (origin = bottom-left of the same).
        // Convert using NSScreen.screens[0]'s height (the menu-bar screen) — not the
        // screen under the cursor. Otherwise multi-monitor setups put AX coords on the
        // wrong screen and AXUIElementCopyElementAtPosition falls back to the menu bar.
        let primaryH = NSScreen.screens.first?.frame.height
            ?? (NSScreen.main?.frame.height ?? 900)
        let axX = Float(nsLoc.x)
        let axY = Float(primaryH - nsLoc.y)

        let axApp = AXUIElementCreateApplication(frontmost.processIdentifier)
        // Force Chromium/Electron apps (Slack, Notion, Discord, VSCode) to expose their
        // accessibility tree. Idempotent. No-op on native apps.
        AXUIElementSetAttributeValue(axApp, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        var elemRef: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(axApp, axX, axY, &elemRef)

        if result == .success, let element = elemRef {
            var current = element
            for _ in 0..<6 {
                // Read all AX attributes once per element — shared across all layers.
                var roleRef: AnyObject?; var descRef: AnyObject?; var titleRef: AnyObject?
                var subroleRef: AnyObject?; var placeholderRef: AnyObject?; var helpRef: AnyObject?
                var identRef: AnyObject?
                AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleRef)
                AXUIElementCopyAttributeValue(current, kAXDescriptionAttribute as CFString, &descRef)
                AXUIElementCopyAttributeValue(current, kAXTitleAttribute as CFString, &titleRef)
                AXUIElementCopyAttributeValue(current, kAXSubroleAttribute as CFString, &subroleRef)
                AXUIElementCopyAttributeValue(current, kAXPlaceholderValueAttribute as CFString, &placeholderRef)
                AXUIElementCopyAttributeValue(current, kAXHelpAttribute as CFString, &helpRef)
                AXUIElementCopyAttributeValue(current, kAXIdentifierAttribute as CFString, &identRef)
                var axksRef: AnyObject?
                AXUIElementCopyAttributeValue(current, "AXKeyShortcutsValue" as CFString, &axksRef)
                let currentRole       = roleRef   as? String ?? ""
                let currentDesc       = (descRef   as? String ?? "").lowercased()
                let currentTitle      = (titleRef  as? String ?? "").lowercased()
                let currentHelp       = helpRef   as? String ?? ""
                let currentIdentifier = (identRef  as? String ?? "").lowercased()
                let currentKeyShortcuts = axksRef as? String ?? ""
                let isInteractive     = Self.interactiveRoles.contains(currentRole)

                if isInteractive && firstInteractiveMiss == nil {
                    firstInteractiveMiss = MissEvent(
                        bundleId: bundleId,
                        role:     currentRole,
                        title:    (titleRef as? String) ?? "",
                        desc:     (descRef as? String) ?? "",
                        help:     currentHelp
                    )
                }

                // Layer 0: AXKeyShortcutsValue — Electron/Chromium aria-keyshortcuts attribute
                if !currentKeyShortcuts.isEmpty,
                   let keys = Self.parseAriaShortcut(currentKeyShortcuts) {
                    let hint = (titleRef as? String) ?? (descRef as? String) ?? currentKeyShortcuts
                    let autoId = "axks:\(bundleId):\(keys.joined(separator: "+"))"
                    emit(bundleId: bundleId, shortcutId: autoId, keys: keys, hint: hint, loc: nsLoc)
                    return
                }

                // Layer 0.5: JSON-loaded rules (bundled / LLM cache / user overrides)
                if let result = ruleCache.match(
                    bundleId: bundleId,
                    role: currentRole,
                    title: currentTitle,
                    desc: currentDesc,
                    help: currentHelp.lowercased()
                ) {
                    let autoId = "json:\(bundleId):\(result.keys.joined(separator: "+"))"
                    emit(bundleId: bundleId, shortcutId: autoId,
                         keys: result.keys, hint: result.hint, loc: nsLoc)
                    return
                }

                // Layer 1: hardcoded per-app rules
                if let (rule, confidence) = ShortcutRules.match(element: current, bundleId: bundleId,
                                                                  role: roleRef, desc: descRef,
                                                                  title: titleRef, subrole: subroleRef,
                                                                  placeholder: placeholderRef, help: helpRef,
                                                                  identifier: currentIdentifier),
                   confidence >= .threshold {
                    emit(bundleId: bundleId, shortcutId: rule.shortcutId,
                         keys: rule.keys, hint: rule.hint, loc: nsLoc)
                    return
                }

                // Layer 2: kAXHelpAttribute auto-parse.
                // Single-char safety: only accept raw "e"/"k" on clickable roles.
                if !currentHelp.isEmpty {
                    if (currentHelp.count > 1 || isInteractive),
                       let keys = ShortcutRules.parseShortcut(from: currentHelp) {
                        let autoId = "auto:\(bundleId):\(keys.joined(separator: "+"))"
                        emit(bundleId: bundleId, shortcutId: autoId,
                             keys: keys, hint: currentHelp, loc: nsLoc)
                        return
                    }
                }

                // Layer 3 & 4: only on interactive elements — structural roles (AXWindow,
                // AXTextArea, AXScrollArea, etc.) carry arbitrary user content that causes false matches.
                if isInteractive {
                    // Layer 3: MenuBarIndex fuzzy match
                    let query = elementQuery(current)
                    if !query.isEmpty,
                       let (entry, confidence) = menuBarWatcher.currentIndex.lookup(query: query),
                       confidence >= .threshold {
                        let autoId = "menuindex:\(bundleId):\(entry.keys.joined(separator: "+"))"
                        emit(bundleId: bundleId, shortcutId: autoId,
                             keys: entry.keys, hint: entry.hint, loc: nsLoc)
                        return
                    }

                    // Layer 4: Universal semantic role heuristics
                    if let rule = ShortcutRules.universalRules.first(where: {
                        matchUniversal(role: currentRole, desc: currentDesc, title: currentTitle,
                                       subrole: subroleRef as? String ?? "", rule: $0)
                    }) {
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

        if !emitFiredInCurrentClick, let miss = firstInteractiveMiss {
            EventLogger.logMiss(event: miss)
        }
    }

    private func role(_ element: AXUIElement) -> String {
        var ref: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &ref)
        return ref as? String ?? ""
    }

    private func matchUniversal(role: String, desc: String, title: String, subrole: String, rule: ClickRule) -> Bool {
        if let rr = rule.role,          role    != rr                        { return false }
        if let ss = rule.subroleEquals, subrole != ss                        { return false }
        if let dd = rule.descContains,  !desc.contains(dd.lowercased())      { return false }
        if let tt = rule.titleContains, !title.contains(tt.lowercased())     { return false }
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
            var descRef: AnyObject?; var titleRef2: AnyObject?
            var subroleRef: AnyObject?; var placeholderRef: AnyObject?; var helpRef: AnyObject?
            var identRef2: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef2)
            AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef)
            AXUIElementCopyAttributeValue(element, kAXPlaceholderValueAttribute as CFString, &placeholderRef)
            AXUIElementCopyAttributeValue(element, kAXHelpAttribute as CFString, &helpRef)
            AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identRef2)
            let menuIdentifier = (identRef2 as? String ?? "").lowercased()
            if let (rule, _) = ShortcutRules.match(element: element, bundleId: bundleId,
                                                    role: roleRef, desc: descRef, title: titleRef2,
                                                    subrole: subroleRef, placeholder: placeholderRef,
                                                    help: helpRef, identifier: menuIdentifier) {
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
        emitFiredInCurrentClick = true
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
