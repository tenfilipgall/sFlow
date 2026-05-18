import AppKit
import ApplicationServices
import CoreGraphics
import Carbon.HIToolbox

/// Records the keyboard shortcuts the user actually presses, so SFlow can
/// learn what works without showing toasts the user didn't need. Provides
/// the data layer for future "practice drills" — assessing whether a user
/// hit the right shortcut on a target element.
///
/// **Privacy gate is enforced before any AX read.** A `keydown` without a
/// `Cmd` / `Ctrl` / `Option` modifier (i.e. plain typing) is dropped at
/// step 1 of the callback. Passwords, message bodies and document text
/// never reach this watcher.
///
/// One `CGEventTap` lives here, separate from `ClickWatcher`'s mouse tap,
/// so a slow AX call on one path can't disable the other. Both taps share
/// the same Input Monitoring grant — no extra permission prompt.
private var sharedKeystrokeWatcher: KeystrokeWatcher?

final class KeystrokeWatcher {
    typealias Handler = (KeystrokeEvent) -> Void

    private let onEvent: Handler
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?
    private var lastKeysId: String = ""
    private var lastKeysTime: Date = .distantPast

    init(onEvent: @escaping Handler) {
        self.onEvent = onEvent
        sharedKeystrokeWatcher = self
        setup()
    }

    deinit {
        healthCheckTimer?.invalidate()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        sharedKeystrokeWatcher = nil
    }

    private func setup() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: keystrokeTapCallback,
            userInfo: nil
        )
        guard let tap else {
            NSLog("SFlow: KeystrokeWatcher tap creation FAILED — Input Monitoring?")
            return
        }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        // Mirror ClickWatcher's silent-disable heartbeat.
        let t = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self, let tap = self.tap else { return }
            if !CGEvent.tapIsEnabled(tap: tap) {
                NSLog("SFlow: KeystrokeWatcher tap silent-disabled — re-enabling")
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        healthCheckTimer = t
    }

    func reenableTap() {
        guard let tap else { return }
        NSLog("SFlow: KeystrokeWatcher tap disabled by system — re-enabling")
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: - Per-event handling

    fileprivate func handle(_ cgEvent: CGEvent) {
        // ----------------------------------------------------------------
        // STEP 1 — HARD PRIVACY GATE. Nothing past here without Cmd/Ctrl/Opt.
        // ----------------------------------------------------------------
        let flags = cgEvent.flags
        let hasMeta = flags.contains(.maskCommand)
        let hasCtrl = flags.contains(.maskControl)
        let hasAlt  = flags.contains(.maskAlternate)
        guard hasMeta || hasCtrl || hasAlt else { return }

        // Drop auto-repeats (held key). Without this, holding ⌘V floods.
        if cgEvent.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return }

        // ----------------------------------------------------------------
        // STEP 2 — Resolve key string.
        // ----------------------------------------------------------------
        let keycode = Int(cgEvent.getIntegerValueField(.keyboardEventKeycode))
        guard let keyName = Self.keyName(forKeycode: keycode, event: cgEvent) else {
            return // unmapped — skip rather than log garbage
        }

        var keys: [String] = []
        if hasCtrl { keys.append("ctrl") }
        if hasAlt  { keys.append("alt") }
        if flags.contains(.maskShift) { keys.append("shift") }
        if hasMeta { keys.append("meta") }
        keys.append(keyName)

        // Dedup: same combo within 250ms = double-fire, ignore.
        let combo = keys.joined(separator: "+")
        let now = Date()
        if combo == lastKeysId && now.timeIntervalSince(lastKeysTime) < 0.25 {
            return
        }
        lastKeysId = combo
        lastKeysTime = now

        // ----------------------------------------------------------------
        // STEP 3 — AX focused-element read (best-effort, redacted).
        // ----------------------------------------------------------------
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontmost.bundleIdentifier else { return }

        var focusedRole = ""
        var focusedTitle = ""
        var focusedRoleDesc = ""
        var focusedIdentifier = ""
        var windowTitle = ""

        let axApp = AXUIElementCreateApplication(frontmost.processIdentifier)
        var focusedRef: AnyObject?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString,
                                          &focusedRef) == .success,
           let focused = focusedRef {
            // swiftlint:disable force_cast
            let focusedEl = focused as! AXUIElement
            // swiftlint:enable force_cast
            var roleRef: AnyObject?; var titleRef: AnyObject?
            var roleDescRef: AnyObject?; var identRef: AnyObject?
            AXUIElementCopyAttributeValue(focusedEl, kAXRoleAttribute as CFString, &roleRef)
            AXUIElementCopyAttributeValue(focusedEl, kAXTitleAttribute as CFString, &titleRef)
            AXUIElementCopyAttributeValue(focusedEl, kAXRoleDescriptionAttribute as CFString, &roleDescRef)
            AXUIElementCopyAttributeValue(focusedEl, kAXIdentifierAttribute as CFString, &identRef)
            focusedRole = (roleRef as? String) ?? ""
            focusedTitle = PrivacyFilter.redact((titleRef as? String) ?? "")
            focusedRoleDesc = (roleDescRef as? String) ?? ""
            focusedIdentifier = (identRef as? String) ?? ""
        }

        var windowRef: AnyObject?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString,
                                          &windowRef) == .success,
           let window = windowRef {
            // swiftlint:disable force_cast
            let windowEl = window as! AXUIElement
            // swiftlint:enable force_cast
            var winTitleRef: AnyObject?
            AXUIElementCopyAttributeValue(windowEl, kAXTitleAttribute as CFString, &winTitleRef)
            windowTitle = PrivacyFilter.redact((winTitleRef as? String) ?? "")
        }

        let evt = KeystrokeEvent(
            bundleId: bundleId,
            keys: keys,
            focusedRole: focusedRole,
            focusedTitle: focusedTitle,
            focusedRoleDesc: focusedRoleDesc,
            focusedIdentifier: focusedIdentifier,
            windowTitle: windowTitle
        )
        onEvent(evt)
    }

    // MARK: - Keycode → name

    /// Maps the macOS HIToolbox virtual keycode to the canonical key name
    /// used everywhere else in SFlow ("a", "tab", "arrowleft", "f5", …).
    /// Mirrors `KeySymbols.swift` vocabulary so toasts and logs match.
    ///
    /// For letter/digit/punctuation keys we ask CG for the unmodified
    /// Unicode char so non-Latin keyboards (PL/DE/JP) still report the
    /// expected glyph. For arrow/function/whitespace keys we hard-map by
    /// keycode because their "character" is non-printable.
    static func keyName(forKeycode keycode: Int, event: CGEvent) -> String? {
        // Hard-mapped special keys (codes match Carbon.HIToolbox kVK_*).
        switch keycode {
        case kVK_Return, kVK_ANSI_KeypadEnter: return "enter"
        case kVK_Tab:                          return "tab"
        case kVK_Space:                        return "space"
        case kVK_Delete:                       return "delete"
        case kVK_ForwardDelete:                return "forwarddelete"
        case kVK_Escape:                       return "escape"
        case kVK_CapsLock:                     return "capslock"
        case kVK_Home:                         return "home"
        case kVK_End:                          return "end"
        case kVK_PageUp:                       return "pageup"
        case kVK_PageDown:                     return "pagedown"
        case kVK_LeftArrow:                    return "arrowleft"
        case kVK_RightArrow:                   return "arrowright"
        case kVK_UpArrow:                      return "arrowup"
        case kVK_DownArrow:                    return "arrowdown"
        case kVK_F1:  return "f1";  case kVK_F2:  return "f2"
        case kVK_F3:  return "f3";  case kVK_F4:  return "f4"
        case kVK_F5:  return "f5";  case kVK_F6:  return "f6"
        case kVK_F7:  return "f7";  case kVK_F8:  return "f8"
        case kVK_F9:  return "f9";  case kVK_F10: return "f10"
        case kVK_F11: return "f11"; case kVK_F12: return "f12"
        default: break
        }

        // Ask CG for the unmodified character (ignores Shift/Cmd state).
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return nil }
        let raw = String(utf16CodeUnits: chars, count: length).lowercased()
        // Reject control / non-printable scalars
        if raw.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) {
            return nil
        }
        return raw
    }
}

private let keystrokeTapCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        sharedKeystrokeWatcher?.reenableTap()
        return Unmanaged.passUnretained(event)
    }
    if type == .keyDown {
        sharedKeystrokeWatcher?.handle(event)
    }
    return Unmanaged.passUnretained(event)
}
