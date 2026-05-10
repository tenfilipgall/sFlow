import AppKit

final class ToastWindow: NSPanel {
    private static var current: ToastWindow?

    static func show(event: ShortcutEvent) {
        DispatchQueue.main.async {
            current?.orderOut(nil)
            current = ToastWindow(event: event)
            current?.appear()
        }
    }

    private init(event: ShortcutEvent) {
        let content = Self.buildContent(keys: event.keys, hint: event.hint)
        let padding: CGFloat = 10
        let textSize = content.size()
        let w = max(120, textSize.width + padding * 2 + 4)
        let h = max(34, textSize.height + padding * 2)

        // mouseY in AppKit is distance from bottom — toast appears above cursor
        let frame = NSRect(x: event.mouseX + 16, y: event.mouseY + 8, width: w, height: h)

        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        alphaValue = 1

        // Visual effect background
        let vfx = NSVisualEffectView(frame: NSRect(origin: .zero, size: CGSize(width: w, height: h)))
        vfx.blendingMode = .behindWindow
        vfx.material = .hudWindow
        vfx.state = .active
        vfx.wantsLayer = true
        vfx.layer?.cornerRadius = 8
        vfx.layer?.masksToBounds = true

        // Label
        let label = NSTextField(frame: NSRect(x: padding, y: padding,
                                               width: w - padding * 2, height: h - padding * 2))
        label.attributedStringValue = content
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false

        vfx.addSubview(label)
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

    private static func keySymbol(_ key: String) -> String {
        switch key {
        case "meta":       return "⌘"
        case "shift":      return "⇧"
        case "alt":        return "⌥"
        case "ctrl":       return "⌃"
        case "arrowleft":  return "←"
        case "arrowright": return "→"
        case "arrowup":    return "↑"
        case "arrowdown":  return "↓"
        case "enter":      return "↵"
        case "space":      return "␣"
        case "escape":     return "⎋"
        case "delete":     return "⌫"
        case "tab":        return "⇥"
        default:           return key.uppercased()
        }
    }

    func appear() {
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            animator().alphaValue = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                self?.animator().alphaValue = 0
            }, completionHandler: {
                self?.orderOut(nil)
                if ToastWindow.current === self { ToastWindow.current = nil }
            })
        }
    }
}
