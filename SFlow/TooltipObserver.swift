import AppKit
import ApplicationServices

/// Passively watches for tooltips appearing in the focused app's AX tree when
/// the cursor pauses on a button. React-portal tooltips (Notion Mail, Linear,
/// etc.) render as floating AXGroup nodes containing two AXStaticText children:
/// one with the action name, one with the keyboard shortcut badge. When found,
/// records the (action, shortcut, button-rect) tuple to `DiscoveredStore` so
/// subsequent clicks on that button — even after the tooltip dismisses — can
/// emit a toast via the new Layer 0.3 lookup in `ClickWatcher`.
///
/// Uses cursor polling (250 ms) rather than CGEventTap on `.mouseMoved` — the
/// latter delivers ~60 events/sec and needs a separate Unmanaged dance; polling
/// is simpler and only ticks when cursor is genuinely stable. Scan fires once
/// cursor has been stationary ≥ 350 ms (tooltip render delay) and at most once
/// per 500 ms (rate-limit).
final class TooltipObserver {
    private let store: DiscoveredStore
    private let queue = DispatchQueue(label: "com.sflow.tooltip", qos: .utility)
    private var timer: Timer?
    private var lastCursor: CGPoint = .zero
    private var stableSince: Date = .distantPast
    private var lastScanAt: Date = .distantPast

    init(store: DiscoveredStore = .shared) {
        self.store = store
        NSLog("SFlow[Tooltip]: init — DiscoveredStore at \(DiscoveredStore.defaultDir().path)")
        startPolling()
    }

    private func startPolling() {
        let t = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let nsLoc = NSEvent.mouseLocation
        let primaryH = NSScreen.screens.first?.frame.height ?? 900
        let cursor = CGPoint(x: nsLoc.x, y: primaryH - nsLoc.y)
        let now = Date()
        if abs(cursor.x - lastCursor.x) > 2 || abs(cursor.y - lastCursor.y) > 2 {
            lastCursor = cursor
            stableSince = now
            return
        }
        guard now.timeIntervalSince(stableSince) >= 0.35 else { return }
        guard now.timeIntervalSince(lastScanAt) >= 0.5 else { return }
        lastScanAt = now
        queue.async { [weak self] in
            self?.scanForTooltip(at: cursor)
        }
    }

    /// Set to true via `defaults write com.filip.sflow tooltipDebug -bool true`
    /// to log every AXGroup/AXWindow near cursor, not just shape-matching ones.
    private static var verboseDebug: Bool {
        UserDefaults.standard.bool(forKey: "tooltipDebug")
    }

    /// Set to true via `defaults write com.filip.sflow tooltipDiag -bool true`
    /// to dump a deep diagnostic snapshot per scan: number of app windows,
    /// system-wide hit-test result, and the hit-tested element's parent chain
    /// with siblings + their static-texts. Used to localize tooltip rendering
    /// in Chromium apps where AXGroup rects are not informative.
    private static var diagMode: Bool {
        UserDefaults.standard.bool(forKey: "tooltipDiag")
    }

    private func scanForTooltip(at cursor: CGPoint) {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleId = app.bundleIdentifier else { return }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        // Force Chromium/Electron apps (Slack, Notion, Discord, VSCode, Linear) to
        // expose their accessibility tree. ClickWatcher does this on every click,
        // but the tooltip scanner runs on its own 200 ms timer — without these
        // flags the AX walk hits an empty AXWindow before any click ever fires.
        // Idempotent. No-op on native apps.
        AXUIElementSetAttributeValue(axApp, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)

        if Self.diagMode {
            Self.dumpDiagnostic(axApp: axApp, bundleId: bundleId, cursor: cursor)
        }

        var found: (rect: CGRect, badge: String, name: String)? = nil
        var candidatesSeen = 0
        var groupsSeen = 0
        walk(axApp, depth: 0, cursor: cursor, result: &found,
             candidatesSeen: &candidatesSeen, groupsSeen: &groupsSeen)

        if candidatesSeen > 0 || Self.verboseDebug {
            NSLog("SFlow[Tooltip]: scan in \(bundleId) at (\(Int(cursor.x)),\(Int(cursor.y))) — groups=\(groupsSeen) candidates=\(candidatesSeen) found=\(found?.name ?? "nil")")
        }

        guard let f = found,
              let keys = TooltipShortcutParser.parseBadge(f.badge) else { return }
        if Self.containsSensitiveText(f.name) {
            NSLog("SFlow[Tooltip]: rejected (privacy filter): \(f.name)")
            return
        }
        guard TooltipNameFilter.isAcceptableActionName(f.name) else {
            NSLog("SFlow[Tooltip]: rejected (meta-word filter): \(f.name)")
            return
        }

        // The tooltip rect itself sits above/beside the actual hover-target button
        // (Notion Mail: tooltip at y=-1354 while cursor on button is at y=-1332).
        // Click coords land on the BUTTON, not the tooltip rect — so we hit-test at
        // cursor pos to get the hovered element's own frame. Fall back to a small
        // box around the cursor if AX rejects the hit-test OR if it returns an
        // oversized container (sometimes Chromium returns the entire panel for
        // the hovered position — Reply hit-test returned 810x809 once, causing
        // false-positive Reply toasts for clicks anywhere in that pane).
        let fallbackRect = CGRect(x: cursor.x - 18, y: cursor.y - 18, width: 36, height: 36)
        let rawRect = Self.hitTestRect(in: axApp, at: cursor)
        let buttonRect: CGRect = {
            guard let r = rawRect else { return fallbackRect }
            if r.size.width > 200 || r.size.height > 200 { return fallbackRect }
            return r
        }()
        let buttonId = Self.hitTestIdentifier(in: axApp, at: cursor)

        let entry = DiscoveredEntry(
            bundleId: bundleId,
            actionName: f.name,
            keys: keys,
            identifier: buttonId,
            rect: DiscoveredEntry.CGRectCodable(buttonRect),
            observedAt: Date()
        )
        store.record(entry)
        NSLog("SFlow[Tooltip]: recorded — \(f.name) [\(keys.joined(separator: "+"))] in \(bundleId) buttonRect=\(Int(buttonRect.minX)),\(Int(buttonRect.minY)),\(Int(buttonRect.width))x\(Int(buttonRect.height))")
    }

    /// One-shot diagnostic dump. Logs:
    ///  1. All top-level AXWindows for the app (Chromium often renders tooltips
    ///     as separate floating windows — if we see >1 window with small rects,
    ///     tooltips live outside the main window and we need to scan them too).
    ///  2. System-wide hit-test at cursor (returns whichever element is on
    ///     screen there, regardless of process — catches OS-level tooltip
    ///     overlays that the per-app axApp doesn't see).
    ///  3. The hit-tested element's parent + its siblings (1 hop up + their
    ///     immediate static texts) — shows the AX tree neighborhood we'd need
    ///     to traverse to find a name+badge pair.
    static func dumpDiagnostic(axApp: AXUIElement, bundleId: String, cursor: CGPoint) {
        // 1. App windows.
        var windowsRef: AnyObject?
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
        let windows = (windowsRef as? [AXUIElement]) ?? []
        NSLog("SFlow[Tooltip][diag]: app=\(bundleId) windows=\(windows.count)")
        for (i, w) in windows.enumerated() {
            var roleRef: AnyObject?
            AXUIElementCopyAttributeValue(w, kAXRoleAttribute as CFString, &roleRef)
            var titleRef: AnyObject?
            AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &titleRef)
            var subroleRef: AnyObject?
            AXUIElementCopyAttributeValue(w, kAXSubroleAttribute as CFString, &subroleRef)
            let r = frame(of: w).map { "\(Int($0.minX)),\(Int($0.minY)),\(Int($0.width))x\(Int($0.height))" } ?? "nil"
            NSLog("SFlow[Tooltip][diag]: window[\(i)] role=\(roleRef as? String ?? "?") subrole=\(subroleRef as? String ?? "?") title=\"\(titleRef as? String ?? "")\" rect=\(r)")
        }

        // 2. System-wide hit-test.
        let sysWide = AXUIElementCreateSystemWide()
        var sysElemRef: AXUIElement?
        let sysRes = AXUIElementCopyElementAtPosition(sysWide, Float(cursor.x), Float(cursor.y), &sysElemRef)
        if sysRes == .success, let sysElem = sysElemRef {
            var roleRef: AnyObject?; var titleRef: AnyObject?; var descRef: AnyObject?; var valueRef: AnyObject?
            AXUIElementCopyAttributeValue(sysElem, kAXRoleAttribute as CFString, &roleRef)
            AXUIElementCopyAttributeValue(sysElem, kAXTitleAttribute as CFString, &titleRef)
            AXUIElementCopyAttributeValue(sysElem, kAXDescriptionAttribute as CFString, &descRef)
            AXUIElementCopyAttributeValue(sysElem, kAXValueAttribute as CFString, &valueRef)
            var pid: pid_t = 0
            AXUIElementGetPid(sysElem, &pid)
            let r = frame(of: sysElem).map { "\(Int($0.minX)),\(Int($0.minY)),\(Int($0.width))x\(Int($0.height))" } ?? "nil"
            NSLog("SFlow[Tooltip][diag]: sysHit pid=\(pid) role=\(roleRef as? String ?? "?") title=\"\(titleRef as? String ?? "")\" desc=\"\(descRef as? String ?? "")\" value=\"\((valueRef as? String ?? "").prefix(40))\" rect=\(r)")
        } else {
            NSLog("SFlow[Tooltip][diag]: sysHit FAILED res=\(sysRes.rawValue)")
        }

        // 3. App hit-test + parent + siblings.
        var appElemRef: AXUIElement?
        let appRes = AXUIElementCopyElementAtPosition(axApp, Float(cursor.x), Float(cursor.y), &appElemRef)
        guard appRes == .success, let appElem = appElemRef else {
            NSLog("SFlow[Tooltip][diag]: appHit FAILED res=\(appRes.rawValue)")
            return
        }
        var hitRoleRef: AnyObject?; var hitTitleRef: AnyObject?
        AXUIElementCopyAttributeValue(appElem, kAXRoleAttribute as CFString, &hitRoleRef)
        AXUIElementCopyAttributeValue(appElem, kAXTitleAttribute as CFString, &hitTitleRef)
        NSLog("SFlow[Tooltip][diag]: appHit role=\(hitRoleRef as? String ?? "?") title=\"\(hitTitleRef as? String ?? "")\"")

        var parentRef: AnyObject?
        AXUIElementCopyAttributeValue(appElem, kAXParentAttribute as CFString, &parentRef)
        guard let parent = parentRef as! AXUIElement? else { return }
        var pRoleRef: AnyObject?
        AXUIElementCopyAttributeValue(parent, kAXRoleAttribute as CFString, &pRoleRef)
        NSLog("SFlow[Tooltip][diag]: parent role=\(pRoleRef as? String ?? "?") texts=\(collectStaticTexts(parent, depth: 0, limit: 8))")

        var siblingsRef: AnyObject?
        AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &siblingsRef)
        let siblings = (siblingsRef as? [AXUIElement]) ?? []
        NSLog("SFlow[Tooltip][diag]: siblings=\(siblings.count)")
        for (i, sib) in siblings.prefix(8).enumerated() {
            var sRoleRef: AnyObject?
            AXUIElementCopyAttributeValue(sib, kAXRoleAttribute as CFString, &sRoleRef)
            let texts = collectStaticTexts(sib, depth: 0, limit: 4)
            let r = frame(of: sib).map { "\(Int($0.width))x\(Int($0.height))" } ?? "nil"
            NSLog("SFlow[Tooltip][diag]:   sib[\(i)] role=\(sRoleRef as? String ?? "?") size=\(r) texts=\(texts)")
        }
    }

    /// Hit-tests at `cursor` in `axApp` and returns the hovered element's frame.
    /// Used to find the *button* a tooltip is describing (the tooltip itself
    /// floats nearby, not at cursor).
    static func hitTestRect(in axApp: AXUIElement, at cursor: CGPoint) -> CGRect? {
        var elemRef: AXUIElement?
        let res = AXUIElementCopyElementAtPosition(axApp, Float(cursor.x), Float(cursor.y), &elemRef)
        guard res == .success, let elem = elemRef else { return nil }
        return frame(of: elem)
    }

    static func hitTestIdentifier(in axApp: AXUIElement, at cursor: CGPoint) -> String? {
        var elemRef: AXUIElement?
        let res = AXUIElementCopyElementAtPosition(axApp, Float(cursor.x), Float(cursor.y), &elemRef)
        guard res == .success, let elem = elemRef else { return nil }
        var idRef: AnyObject?
        AXUIElementCopyAttributeValue(elem, kAXIdentifierAttribute as CFString, &idRef)
        let id = idRef as? String ?? ""
        return id.isEmpty ? nil : id
    }

    private func walk(_ element: AXUIElement, depth: Int, cursor: CGPoint,
                       result: inout (rect: CGRect, badge: String, name: String)?,
                       candidatesSeen: inout Int, groupsSeen: inout Int) {
        if depth > 10 || result != nil { return }
        var roleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""

        let containerRoles: Set<String> = [
            "AXGroup", "AXWindow", "AXSheet", "AXSystemDialog",
            "AXHelpTag", "AXPopover", "AXLayoutItem", "AXUnknown"
        ]
        if containerRoles.contains(role) {
            groupsSeen += 1
            if let f = Self.frame(of: element) {
                let dx = f.midX - cursor.x; let dy = f.midY - cursor.y
                let dist = sqrt(dx*dx + dy*dy)
                if Self.isTooltipShape(f, cursor: cursor) {
                    candidatesSeen += 1
                    let texts = Self.collectStaticTexts(element, depth: 0, limit: 8)
                    NSLog("SFlow[Tooltip]: candidate [\(role)] rect=\(Int(f.minX)),\(Int(f.minY)),\(Int(f.width))x\(Int(f.height)) texts=\(texts)")
                    if let parsed = Self.parseTooltipTexts(texts) {
                        result = (rect: f, badge: parsed.badge, name: parsed.name)
                        return
                    }
                } else if Self.verboseDebug, dist < 500 {
                    let texts = Self.collectStaticTexts(element, depth: 0, limit: 8)
                    NSLog("SFlow[Tooltip][verbose]: nearby [\(role)] rect=\(Int(f.minX)),\(Int(f.minY)),\(Int(f.width))x\(Int(f.height)) dist=\(Int(dist)) texts=\(texts)")
                }
            }
        }

        var childrenRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        if let children = childrenRef as? [AXUIElement] {
            for c in children {
                walk(c, depth: depth + 1, cursor: cursor, result: &result,
                     candidatesSeen: &candidatesSeen, groupsSeen: &groupsSeen)
                if result != nil { return }
            }
        }
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        var posRef: AnyObject?; var sizeRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        guard let pos = posRef, let sz = sizeRef else { return nil }
        guard CFGetTypeID(pos) == AXValueGetTypeID(),
              CFGetTypeID(sz) == AXValueGetTypeID() else { return nil }
        var p = CGPoint.zero; var s = CGSize.zero
        let posValue = pos as! AXValue
        let szValue = sz as! AXValue
        guard AXValueGetValue(posValue, .cgPoint, &p),
              AXValueGetValue(szValue, .cgSize, &s) else { return nil }
        guard s.width > 0, s.height > 0 else { return nil }
        return CGRect(origin: p, size: s)
    }

    /// Tooltip shape heuristic — small floating box near cursor.
    /// 40-500 wide × 16-100 tall, center within 350 px of cursor.
    static func isTooltipShape(_ rect: CGRect, cursor: CGPoint) -> Bool {
        let w = rect.size.width, h = rect.size.height
        guard w >= 40, w <= 500, h >= 16, h <= 100 else { return false }
        let dx = rect.midX - cursor.x
        let dy = rect.midY - cursor.y
        return (dx * dx + dy * dy) < (350 * 350)
    }

    /// Collects up to `limit` texts from element's subtree.
    /// Primary source: `AXStaticText` children with `kAXValue`/`kAXTitle`.
    /// Fallback (Chromium pattern observed in Notion main, U-2.2):
    /// container roles (AXGroup, AXLink, AXImage, AXButton, AXUnknown) can
    /// expose tooltip text directly via their own `kAXValue` or `kAXTitle`
    /// without an AXStaticText child. Skips multi-line strings (those are
    /// page content, not tooltips) and strings > 100 chars.
    static func collectStaticTexts(_ element: AXUIElement, depth: Int, limit: Int) -> [String] {
        if depth > 4 || limit <= 0 { return [] }
        var result: [String] = []
        var childrenRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        guard let children = childrenRef as? [AXUIElement] else { return [] }
        for c in children {
            if result.count >= limit { break }
            var roleRef: AnyObject?
            AXUIElementCopyAttributeValue(c, kAXRoleAttribute as CFString, &roleRef)
            let r = roleRef as? String ?? ""
            if r == "AXStaticText" {
                var valueRef: AnyObject?; var titleRef: AnyObject?
                AXUIElementCopyAttributeValue(c, kAXValueAttribute as CFString, &valueRef)
                AXUIElementCopyAttributeValue(c, kAXTitleAttribute as CFString, &titleRef)
                let t = (valueRef as? String) ?? (titleRef as? String) ?? ""
                if !t.isEmpty, t.count <= 100 { result.append(t) }
            } else {
                // Chromium fallback: read own value/title before recursing.
                // Notion main tooltips put the action name directly on AXGroup.
                let containerRoles: Set<String> = [
                    "AXGroup", "AXLink", "AXImage", "AXButton", "AXUnknown"
                ]
                if containerRoles.contains(r) {
                    var valueRef: AnyObject?; var titleRef: AnyObject?
                    AXUIElementCopyAttributeValue(c, kAXValueAttribute as CFString, &valueRef)
                    AXUIElementCopyAttributeValue(c, kAXTitleAttribute as CFString, &titleRef)
                    let t = (valueRef as? String) ?? (titleRef as? String) ?? ""
                    if !t.isEmpty, t.count <= 100,
                       !t.contains("\n") {
                        result.append(t)
                    }
                }
                if result.count < limit {
                    result.append(contentsOf: Self.collectStaticTexts(c, depth: depth + 1,
                                                                       limit: limit - result.count))
                }
            }
        }
        return result
    }

    /// Identifies which text is the badge (short, parseable as shortcut) and
    /// which is the action name (3-80 chars). Returns (badge, name) or nil.
    ///
    /// Notion Mail packs badge as one AXStaticText `"⌘+\\"`. Notion Calendar
    /// splits it across multiple AXStaticText nodes — one per modifier and
    /// key — e.g. `["⌘", "\\"]`. We try the joined fragments first so split
    /// badges still parse correctly; falling back to per-fragment parsing
    /// catches the packed case.
    static func parseTooltipTexts(_ texts: [String]) -> (badge: String, name: String)? {
        var name: String? = nil
        var badgeFragments: [String] = []
        for raw in texts {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { continue }
            if t.count >= 3, t.count <= 80, name == nil {
                name = t
            } else if t.count <= 5 {
                badgeFragments.append(t)
            }
        }
        guard let n = name, !badgeFragments.isEmpty else { return nil }

        let combined = badgeFragments.joined()
        if TooltipShortcutParser.parseBadge(combined) != nil {
            return (combined, n)
        }
        for frag in badgeFragments {
            if TooltipShortcutParser.parseBadge(frag) != nil {
                return (frag, n)
            }
        }
        return nil
    }

    /// Privacy filter — reject text that looks like user data (emails, URLs,
    /// dates, very long strings, names of senders).
    static func containsSensitiveText(_ s: String) -> Bool {
        if s.contains("@") { return true }
        if s.hasPrefix("http://") || s.hasPrefix("https://") { return true }
        if s.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil { return true }
        if s.count > 80 { return true }
        return false
    }

    deinit {
        timer?.invalidate()
    }
}
