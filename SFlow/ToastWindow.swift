import AppKit

final class ToastWindow: NSPanel {
    private static var current: ToastWindow?

    static func show(event: ShortcutEvent, onFalsePositive: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            current?.dismiss()
            current = ToastWindow(event: event, onFalsePositive: onFalsePositive)
            current?.appear()
        }
    }

    var onFalsePositive: (() -> Void)?
    private var reportBadge: NSTextField!
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private var hostScreen: NSScreen?

    private init(event: ShortcutEvent, onFalsePositive: (() -> Void)? = nil) {
        self.onFalsePositive = onFalsePositive
        let content = Self.buildContent(keys: event.keys, hint: event.hint)
        let padding: CGFloat = 10
        let textSize = content.size()
        let w = max(120, textSize.width + padding * 2 + 4)
        let h = max(34, textSize.height + padding * 2)

        // mouseY in AppKit is distance from bottom of primary screen — toast
        // appears above-right of cursor. On a multi-monitor setup the cursor
        // may sit on a secondary screen whose origin is non-zero, so we pick
        // the screen actually containing the cursor and clamp the toast frame
        // into that screen's visible area. Without clamping, a click on the
        // edge of a secondary monitor (Slack, fullscreen apps) can place the
        // toast in a coordinate space that no monitor can render.
        let cursor = NSPoint(x: event.mouseX, y: event.mouseY)
        let resolvedScreen = NSScreen.screens.first(where: { $0.frame.contains(cursor) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let bounds = resolvedScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        var x = cursor.x + 16
        var y = cursor.y + 8
        if x + w > bounds.maxX { x = bounds.maxX - w - 8 }
        if y + h > bounds.maxY { y = bounds.maxY - h - 8 }
        if x < bounds.minX     { x = bounds.minX + 8 }
        if y < bounds.minY     { y = bounds.minY + 8 }
        let frame = NSRect(x: x, y: y, width: w, height: h)

        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        // .screenSaver (1000) + .moveToActiveSpace ensures toast crosses into the
        // active fullscreen Space (e.g. Slack fullscreen on secondary monitor).
        // .popUpMenu (101) proved insufficient for fullscreen-on-secondary.
        // .moveToActiveSpace is required alongside .canJoinAllSpaces — without it
        // the window stays in the Space it was created in, not the visible one.
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        // .canJoinAllSpaces and .moveToActiveSpace are mutually exclusive (AppKit crash).
        // .moveToActiveSpace is what we want: toast migrates to whichever Space is
        // currently active (e.g. Slack fullscreen on secondary), not all Spaces.
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .stationary]
        alphaValue = 0
        hostScreen = resolvedScreen

        let vfx = NSVisualEffectView(frame: NSRect(origin: .zero, size: CGSize(width: w, height: h)))
        vfx.blendingMode = .behindWindow
        vfx.material = .hudWindow
        vfx.state = .active
        vfx.wantsLayer = true
        vfx.layer?.cornerRadius = 8
        vfx.layer?.masksToBounds = true

        let label = NSTextField(frame: NSRect(x: padding, y: padding,
                                               width: w - padding * 2, height: h - padding * 2))
        label.attributedStringValue = content
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        vfx.addSubview(label)

        // Report badge — shown when ⌘ is held so user knows they can cmd-click
        let badge = NSTextField(frame: NSRect(x: w - 22, y: h - 18, width: 18, height: 14))
        badge.stringValue = "✕"
        badge.isEditable = false
        badge.isBordered = false
        badge.drawsBackground = false
        badge.textColor = .systemRed
        badge.font = .systemFont(ofSize: 9, weight: .bold)
        badge.isHidden = true
        vfx.addSubview(badge)
        reportBadge = badge

        contentView = vfx
    }

    private static func buildContent(keys: [String], hint: String) -> NSAttributedString {
        let symbols = keys.map { keySymbol($0) }.joined()
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: symbols, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ]))
        result.append(NSAttributedString(string: "  \(hint)", attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        return result
    }

    func appear() {
        // Set alpha=1 BEFORE orderFrontRegardless so the window is immediately
        // visible when it enters the Space. Setting alpha=0 first and relying on
        // Core Animation to fade in fails in fullscreen Spaces — CA may not fire
        // if SFlow is not the active app, leaving the window permanently invisible.
        alphaValue = 1
        orderFrontRegardless()
        NSLog("SFlow[Toast]: appear frame=\(frame) level=\(level.rawValue) screen=\(hostScreen?.localizedName ?? "?")")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            NSLog("SFlow[Toast]: +200ms isVisible=\(self?.isVisible ?? false) alpha=\(self?.alphaValue ?? -1)")
        }

        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            let cmdDown = event.modifierFlags.contains(.command)
            DispatchQueue.main.async { self.reportBadge.isHidden = !cmdDown }
        }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self else { return }
            guard NSEvent.modifierFlags.contains(.command) else { return }
            guard self.frame.contains(NSEvent.mouseLocation) else { return }
            let handler = self.onFalsePositive
            DispatchQueue.main.async {
                self.dismiss()
                handler?()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.dismiss()
        }
    }

    private func dismiss() {
        guard alphaValue > 0 else { return }
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            if ToastWindow.current === self { ToastWindow.current = nil }
        })
    }
}
