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

    private func scanForTooltip(at cursor: CGPoint) {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleId = app.bundleIdentifier else { return }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

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

    /// Collects up to `limit` AXStaticText texts from element's subtree
    /// (looking at both kAXValue and kAXTitle since Chromium uses both).
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
                result.append(contentsOf: Self.collectStaticTexts(c, depth: depth + 1,
                                                                   limit: limit - result.count))
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
