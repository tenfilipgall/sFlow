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
    private var healthCheckTimer: Timer?
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
        let mask = CGEventMask((1 << CGEventType.leftMouseDown.rawValue) |
                               (1 << CGEventType.rightMouseDown.rawValue))
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

        // Active heartbeat: re-enable the tap if macOS disabled it silently
        // (no tapDisabledByTimeout callback fired). Necessary because the
        // callback-based re-enable only works when the system still bothers
        // to call us — on heavy AX-IPC workloads it sometimes doesn't.
        let t = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self, let tap = self.tap else { return }
            if !CGEvent.tapIsEnabled(tap: tap) {
                NSLog("SFlow: CGEventTap silent-disabled detected — re-enabling")
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        healthCheckTimer = t
    }

    // Roles whose title/description carry semantic UI meaning (vs. arbitrary user content).
    // Used to gate Layers 3 and 4 — structural roles like AXWindow/AXTextArea are excluded.
    private static let interactiveRoles: Set<String> = [
        "AXButton", "AXTextField", "AXSearchField", "AXCell",
        "AXMenuItem", "AXCheckBox", "AXRadioButton",
        "AXLink", "AXPopUpButton", "AXComboBox",
    ]

    /// Returns true if at this depth in the AX walk, non-L0 layers (RuleCache, ShortcutRules,
    /// MenuBarIndex, universal heuristics) are allowed to attempt a match.
    ///
    /// Depth 0 is the hit-tested element returned by AXUIElementCopyElementAtPosition —
    /// always allowed (preserves Chromium AXGroup clickables, AXImage buttons, etc.).
    /// Depth > 0 is a parent walked via kAXParentAttribute — allowed when the role is in
    /// `interactiveRoles` OR the element exposes `AXPress` as an accessibility action.
    /// AXPress override catches Chromium widgets (AXImage/AXGroup/AXStaticText) that
    /// register press actions but don't have interactive roles.
    ///
    /// Audit reference: BUG #1 (sesja 6) + Coverage QW Fix 1 (sesja 7).
    static func shouldRunNonInteractiveLayers(role: String, depth: Int, hasAXPress: Bool) -> Bool {
        if depth == 0 { return true }
        return interactiveRoles.contains(role) || hasAXPress
    }

    /// Returns true if the AX element registers "AXPress" as a supported action.
    /// AXUIElementCopyActionNames returns actions the element can perform regardless
    /// of its AXRole. AXPress means "this element responds to being clicked" — catches
    /// Chromium widgets that wrap clickables as AXGroup/AXImage but register AXPress.
    static func elementHasAXPress(_ element: AXUIElement) -> Bool {
        var names: CFArray?
        let result = AXUIElementCopyActionNames(element, &names)
        guard result == .success, let arr = names as? [String] else { return false }
        return arr.contains("AXPress")
    }

    /// When a clickable element has empty title/desc, scan its descendants
    /// for the first non-empty label. Common Chromium pattern in Electron apps
    /// (Notion Mail, Linear, etc.): icon-only AXButton without aria-label →
    /// no accessible name on the button itself, but visible text sits in
    /// kAXValue of a nested AXStaticText (often 1–2 levels deep).
    ///
    /// Reads kAXTitle, kAXDescription, and kAXValue from each child.
    /// kAXValue is only treated as a label for static-text-like roles
    /// (AXStaticText / AXLink / AXImage) — for AXButton/AXCheckBox kAXValue
    /// is the pressed-state (0/1), not text.
    ///
    /// One level of recursion into container-like roles (AXGroup / AXImage /
    /// AXButton) — covers AXButton→AXGroup→AXStaticText nesting common in
    /// React + Chromium-rendered DOMs.
    ///
    /// Limited to 5 children per level. Values >100 chars rejected
    /// (textareas / long content, not labels).
    static func extractFallbackTitleFromChildren(_ element: AXUIElement,
                                                  recursionDepthLeft: Int = 1) -> (title: String, desc: String) {
        var childrenRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        guard let children = childrenRef as? [AXUIElement] else { return ("", "") }

        for child in children.prefix(5) {
            var titleRef: AnyObject?; var descRef: AnyObject?
            var valueRef: AnyObject?; var roleRef: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef)
            AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &descRef)
            AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &valueRef)
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            let kt = titleRef as? String ?? ""
            let kd = descRef as? String ?? ""
            let krole = roleRef as? String ?? ""
            let rawValue = valueRef as? String ?? ""
            let kv: String = (!rawValue.isEmpty && rawValue.count <= 100
                              && (krole == "AXStaticText" || krole == "AXLink" || krole == "AXImage"))
                ? rawValue : ""

            let inferredTitle = !kt.isEmpty ? kt : kv
            if !inferredTitle.isEmpty || !kd.isEmpty {
                return (inferredTitle, kd)
            }

            if recursionDepthLeft > 0,
               krole == "AXGroup" || krole == "AXImage" || krole == "AXButton" {
                let nested = extractFallbackTitleFromChildren(child,
                                                              recursionDepthLeft: recursionDepthLeft - 1)
                if !nested.title.isEmpty || !nested.desc.isEmpty {
                    return nested
                }
            }
        }
        return ("", "")
    }

    /// AXCustomActions attribute returns an array whose element shape varies by
    /// macOS version: sometimes [String], sometimes [NSAccessibilityCustomAction]
    /// (which has a `.name` property), sometimes a dictionary with "AXName" or "name".
    /// Try each shape defensively.
    static func extractCustomActionNames(from raw: AnyObject?) -> [String] {
        guard let arr = raw as? [Any] else { return [] }
        var result: [String] = []
        for item in arr {
            if let s = item as? String {
                result.append(s)
            } else if let d = item as? [String: Any],
                      let name = (d["AXName"] as? String) ?? (d["name"] as? String) {
                result.append(name)
            } else if let obj = item as? NSObject,
                      let name = obj.value(forKey: "name") as? String {
                result.append(name)
            }
        }
        return result
    }

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

        // Layer 0.3: tooltip-observed entry. If the user hovered over this
        // button within the last minute and we captured a Notion-style
        // tooltip with name + shortcut badge, emit directly — strongest
        // available signal for Chromium icon-only buttons that expose no AX
        // label of their own.
        let cursorAX = CGPoint(x: CGFloat(axX), y: CGFloat(axY))
        if let entry = DiscoveredStore.shared.lookup(near: cursorAX, bundleId: bundleId) {
            NSLog("SFlow[Tooltip]: L0.3 HIT — \(entry.actionName) [\(entry.keys.joined(separator: "+"))]")
            let autoId = "tooltip:\(bundleId):\(entry.keys.joined(separator: "+"))"
            emit(bundleId: bundleId, shortcutId: autoId,
                 keys: entry.keys, hint: entry.actionName,
                 loc: nsLoc, layer: .tooltipObserver)
            return
        }

        let axApp = AXUIElementCreateApplication(frontmost.processIdentifier)
        // Force Chromium/Electron apps (Slack, Notion, Discord, VSCode) to expose their
        // accessibility tree. Idempotent. No-op on native apps.
        AXUIElementSetAttributeValue(axApp, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        var elemRef: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(axApp, axX, axY, &elemRef)
        if result == .success, let element = elemRef {
            var current = element
            for depth in 0..<6 {
                // Read all AX attributes once per element — shared across all layers.
                var roleRef: AnyObject?; var descRef: AnyObject?; var titleRef: AnyObject?
                var subroleRef: AnyObject?; var placeholderRef: AnyObject?; var helpRef: AnyObject?
                var identRef: AnyObject?; var valueRef: AnyObject?
                AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleRef)
                AXUIElementCopyAttributeValue(current, kAXDescriptionAttribute as CFString, &descRef)
                AXUIElementCopyAttributeValue(current, kAXTitleAttribute as CFString, &titleRef)
                AXUIElementCopyAttributeValue(current, kAXSubroleAttribute as CFString, &subroleRef)
                AXUIElementCopyAttributeValue(current, kAXPlaceholderValueAttribute as CFString, &placeholderRef)
                AXUIElementCopyAttributeValue(current, kAXHelpAttribute as CFString, &helpRef)
                AXUIElementCopyAttributeValue(current, kAXIdentifierAttribute as CFString, &identRef)
                AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &valueRef)
                var axksRef: AnyObject?
                AXUIElementCopyAttributeValue(current, "AXKeyShortcutsValue" as CFString, &axksRef)
                var roleDescRef: AnyObject?
                var customActionsRef: AnyObject?
                AXUIElementCopyAttributeValue(current, kAXRoleDescriptionAttribute as CFString, &roleDescRef)
                AXUIElementCopyAttributeValue(current, "AXCustomActions" as CFString, &customActionsRef)
                let currentRole       = roleRef   as? String ?? ""
                let currentDesc       = (descRef   as? String ?? "").lowercased()
                let currentTitle      = (titleRef  as? String ?? "").lowercased()
                let currentHelp       = helpRef   as? String ?? ""
                let currentIdentifier = (identRef  as? String ?? "").lowercased()
                let currentKeyShortcuts = axksRef as? String ?? ""
                let currentRoleDescription = (roleDescRef as? String ?? "").lowercased()
                let currentCustomActions = Self.extractCustomActionNames(from: customActionsRef)
                // kAXValue is label-like only for static-text-like roles; for AXButton/
                // AXCheckBox it's the pressed-state. Cap at 100 chars to avoid pulling
                // entire textarea contents.
                let rawCurrentValue = (valueRef as? String) ?? ""
                let currentValueAsLabel: String = (!rawCurrentValue.isEmpty
                                                    && rawCurrentValue.count <= 100
                                                    && (currentRole == "AXStaticText"
                                                        || currentRole == "AXLink"
                                                        || currentRole == "AXImage"))
                    ? rawCurrentValue.lowercased() : ""
                let isInteractive     = Self.interactiveRoles.contains(currentRole)

                if isInteractive && firstInteractiveMiss == nil {
                    let subtreeScan = Self.extractFallbackTitleFromChildren(current)
                    let subtreeJoined = [subtreeScan.title, subtreeScan.desc]
                        .filter { !$0.isEmpty }
                        .joined(separator: " / ")
                    firstInteractiveMiss = MissEvent(
                        bundleId: bundleId,
                        role:     currentRole,
                        title:    (titleRef as? String) ?? "",
                        desc:     (descRef as? String) ?? "",
                        help:     currentHelp,
                        identifier: (identRef as? String) ?? "",
                        value:    rawCurrentValue,
                        roleDescription: (roleDescRef as? String) ?? "",
                        customActions: currentCustomActions,
                        subtreeLabel: subtreeJoined
                    )
                }

                // Layer 0: AXKeyShortcutsValue — Electron/Chromium aria-keyshortcuts attribute
                if !currentKeyShortcuts.isEmpty,
                   let keys = Self.parseAriaShortcut(currentKeyShortcuts) {
                    let hint = (titleRef as? String) ?? (descRef as? String) ?? currentKeyShortcuts
                    let autoId = "axks:\(bundleId):\(keys.joined(separator: "+"))"
                    emit(bundleId: bundleId, shortcutId: autoId, keys: keys, hint: hint, loc: nsLoc, layer: .axKeyShortcuts)
                    return
                }

                let hasAXPress = Self.elementHasAXPress(current)
                let runNonInteractive = Self.shouldRunNonInteractiveLayers(role: currentRole, depth: depth, hasAXPress: hasAXPress)

                var effectiveTitle = currentTitle
                var effectiveDesc = currentDesc
                // Fall back to nested children when the current element has no label.
                // Fires at every depth (including depth=0, the hit-tested element) —
                // Chromium/Electron apps often expose AXButton with empty title/desc
                // but the visible label sits in a nested AXStaticText.kAXValue.
                if effectiveTitle.isEmpty, effectiveDesc.isEmpty, runNonInteractive {
                    let fallback = Self.extractFallbackTitleFromChildren(current)
                    if !fallback.title.isEmpty || !fallback.desc.isEmpty {
                        effectiveTitle = fallback.title.lowercased()
                        effectiveDesc = fallback.desc.lowercased()
                    } else if !currentValueAsLabel.isEmpty {
                        // Element is itself a static-text-like node whose visible text
                        // sits in kAXValue rather than kAXTitle.
                        effectiveTitle = currentValueAsLabel
                    }
                }

                // Layer 0.5: JSON-loaded rules (bundled / LLM cache / user overrides)
                if runNonInteractive,
                   let result = ruleCache.match(
                    bundleId: bundleId,
                    role: currentRole,
                    title: effectiveTitle,
                    desc: effectiveDesc,
                    help: currentHelp.lowercased(),
                    identifier: currentIdentifier,
                    roleDescription: currentRoleDescription,
                    customActions: currentCustomActions
                ) {
                    let autoId = "json:\(bundleId):\(result.keys.joined(separator: "+"))"
                    emit(bundleId: bundleId, shortcutId: autoId,
                         keys: result.keys, hint: result.hint, loc: nsLoc, layer: .ruleCache)
                    return
                }

                // Layer 0.6: inline shortcut hint visible on the clicked element.
                // Two sources observed in Notion:
                //
                //  Path A (children pair) — Notion sidebar "New chat ⌘O":
                //   button has 2 AXStaticText children with name + badge.
                //
                //  Path B (own value/title suffix) — Notion context menu items:
                //   AXMenuItem.value = "Move to ⌘⇧P" or "Duplicate ⌘D" — name and
                //   shortcut concatenated in a single attribute. Reuses
                //   RightClickMenuHarvester.parseShortcutFromTitle (handles
                //   macOS-symbol suffix + slack-style trailing letter, skips
                //   mouse modifiers like "⌘Click").
                //
                // PrivacyFilter + TooltipNameFilter applied on both paths to
                // guard against false-positive shortcuts emitted from arbitrary
                // visible text.
                if runNonInteractive {
                    // Path A
                    let inlineTexts = TooltipObserver.collectStaticTexts(
                        current, depth: 0, limit: 4
                    )
                    if let parsed = TooltipObserver.parseTooltipTexts(inlineTexts),
                       let keys = TooltipShortcutParser.parseBadge(parsed.badge),
                       TooltipNameFilter.isAcceptableActionName(parsed.name),
                       !TooltipObserver.containsSensitiveText(parsed.name) {
                        let autoId = "inline:\(bundleId):\(keys.joined(separator: "+"))"
                        emit(bundleId: bundleId, shortcutId: autoId,
                             keys: keys, hint: parsed.name, loc: nsLoc,
                             layer: .inlineShortcut)
                        return
                    }
                    // Path B
                    let rawValue = (valueRef as? String) ?? ""
                    let rawTitle = (titleRef as? String) ?? ""
                    let candidate = !rawValue.isEmpty ? rawValue : rawTitle
                    if !candidate.isEmpty, !candidate.contains("\n"),
                       let pb = RightClickMenuHarvester.parseShortcutFromTitle(candidate),
                       TooltipNameFilter.isAcceptableActionName(pb.cleanTitle),
                       !TooltipObserver.containsSensitiveText(pb.cleanTitle) {
                        let autoId = "inline:\(bundleId):\(pb.keys.joined(separator: "+"))"
                        emit(bundleId: bundleId, shortcutId: autoId,
                             keys: pb.keys, hint: pb.cleanTitle, loc: nsLoc,
                             layer: .inlineShortcut)
                        return
                    }
                }

                // Layer 1: hardcoded per-app rules
                if runNonInteractive,
                   let (rule, confidence) = ShortcutRules.match(element: current, bundleId: bundleId,
                                                                  role: roleRef, desc: descRef,
                                                                  title: titleRef, subrole: subroleRef,
                                                                  placeholder: placeholderRef, help: helpRef,
                                                                  identifier: currentIdentifier),
                   confidence >= .threshold {
                    emit(bundleId: bundleId, shortcutId: rule.shortcutId,
                         keys: rule.keys, hint: rule.hint, loc: nsLoc, layer: .shortcutRules)
                    return
                }

                // Layer 2: kAXHelpAttribute auto-parse.
                // Single-char safety: only accept raw "e"/"k" on clickable roles,
                // or when the app is whitelisted as single-key (Gmail j/k, Notion
                // Mail C/R/F, Obsidian Vim). Whitelist comes from bundled.json
                // `features.singleKeyMode: true`. Sub-cel 1.21 / U-3.
                if !currentHelp.isEmpty {
                    let allowSingleChar = isInteractive
                        || ruleCache.isSingleKeyApp(bundleId: bundleId)
                    if (currentHelp.count > 1 || allowSingleChar),
                       let keys = ShortcutRules.parseShortcut(from: currentHelp) {
                        let autoId = "auto:\(bundleId):\(keys.joined(separator: "+"))"
                        emit(bundleId: bundleId, shortcutId: autoId,
                             keys: keys, hint: currentHelp, loc: nsLoc, layer: .axHelp)
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
                             keys: entry.keys, hint: entry.hint, loc: nsLoc, layer: .menuBarIndex)
                        return
                    }

                    // Layer 4: Universal semantic role heuristics
                    if let rule = ShortcutRules.universalRules.first(where: {
                        matchUniversal(role: currentRole, desc: currentDesc, title: currentTitle,
                                       subrole: subroleRef as? String ?? "", rule: $0)
                    }) {
                        emit(bundleId: bundleId, shortcutId: rule.shortcutId,
                             keys: rule.keys, hint: rule.hint, loc: nsLoc, layer: .universal)
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

    /// Right-click → schedule a context-menu harvest 300 ms later (typical
    /// AppKit context-menu render delay). Harvest reads `kAXMenuItemCmdChar`
    /// from every visible menu item and stores (action, keys, rect) entries
    /// in `DiscoveredStore`. When the user then left-clicks a menu row, the
    /// existing L0.3 lookup matches by rect and emits a toast — no per-app
    /// rules needed. One handler per right-click; macOS allows only one
    /// context menu open at a time.
    func handleRightMouseDown() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              let bundleId  = frontmost.bundleIdentifier else { return }
        let pid = frontmost.processIdentifier
        NSLog("SFlow[RightClick]: detected in \(bundleId), scheduling harvest in 300ms")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let axApp = AXUIElementCreateApplication(pid)
            AXUIElementSetAttributeValue(axApp, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            guard let menu = RightClickMenuHarvester.findOpenMenu(in: axApp) else {
                NSLog("SFlow[RightClick]: NO AXMenu found in \(bundleId) tree (depth ≤4). Menu may render slower or be deeper.")
                // Retry once after another 300ms — Chromium apps render menus
                // slower than native macOS apps.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    guard let menu2 = RightClickMenuHarvester.findOpenMenu(in: axApp, depth: 0, maxDepth: 8) else {
                        NSLog("SFlow[RightClick]: still NO AXMenu after retry+deeper walk (depth ≤8). Giving up.")
                        return
                    }
                    NSLog("SFlow[RightClick]: AXMenu found on retry (deep walk), harvesting")
                    RightClickMenuHarvester.harvest(menu: menu2, bundleId: bundleId)
                }
                return
            }
            RightClickMenuHarvester.harvest(menu: menu, bundleId: bundleId)
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
                     keys: rule.keys, hint: rule.hint, loc: nsLoc, layer: .menuItemFallback)
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
        emit(bundleId: bundleId, shortcutId: shortcutId, keys: keys, hint: hint, loc: nsLoc, layer: .menuItem)
    }

    private func emit(bundleId: String, shortcutId: String, keys: [String],
                      hint: String, loc: NSPoint, layer: RecognitionLayer) {
        let now = Date()
        guard shortcutId != lastShortcutId || now.timeIntervalSince(lastShortcutTime) >= 2.0 else { return }
        lastShortcutId = shortcutId
        lastShortcutTime = now
        let event = ShortcutEvent(bundleId: bundleId, shortcutId: shortcutId,
                                  keys: keys, hint: hint,
                                  mouseX: loc.x, mouseY: loc.y,
                                  layer: layer)
        onEvent(event)
        emitFiredInCurrentClick = true
    }

    /// Called from the tap callback when macOS notifies us that the event tap
    /// was disabled (timeout or user input). Re-enabling is required —
    /// otherwise the tap stays dead until the process restarts.
    func reenableTap() {
        guard let tap else { return }
        NSLog("SFlow: CGEventTap disabled by system — re-enabling")
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    deinit {
        healthCheckTimer?.invalidate()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        sharedWatcher = nil
    }
}

private let tapCallback: CGEventTapCallBack = { proxy, type, event, _ in
    // macOS disables our tap when the callback exceeds the system timeout
    // (~1s by default) or after certain user-input events. Without re-enabling
    // here, the tap stays dead permanently — manifesting as "first click works,
    // every subsequent click is silently dropped". AX queries inside
    // handleMouseDown are synchronous IPC and can easily blow past the timeout
    // for Electron apps with deep trees (Slack on a second monitor).
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        sharedWatcher?.reenableTap()
        return Unmanaged.passUnretained(event)
    }
    if type == .leftMouseDown {
        sharedWatcher?.handleMouseDown()
    } else if type == .rightMouseDown {
        sharedWatcher?.handleRightMouseDown()
    }
    return Unmanaged.passUnretained(event)
}
