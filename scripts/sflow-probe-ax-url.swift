#!/usr/bin/env swift
// Pre-flight probe for U-4 (Web-as-app pseudo-bundleId).
// Inspects the AX tree of the frontmost app to verify whether AXWebArea
// nodes expose a usable URL attribute. Run with Comet/Chrome/Safari open
// on Gmail, Slack web, Notion web, Linear web, GitHub, etc.
//
// Usage:
//   1. Otwórz Comet/Chrome z Gmailem (lub inną web apką) — TA APKA musi być
//      frontmost gdy uruchamiasz skrypt.
//   2. W innym oknie Terminala:
//        swift scripts/sflow-probe-ax-url.swift [delay_seconds=3]
//   3. Przełącz z powrotem na przeglądarkę w ciągu `delay_seconds`.
//   4. Skrypt skanuje AX tree i wypisuje wszystkie AXWebArea + ich atrybuty.
//   5. Wklej output Filipowi/AI — interpretacja:
//        - "AXURL = https://..." → ✅ używamy Hipotezy 1 (URL extraction)
//        - "no AXWebArea found" lub pusty AXURL → fallback do Hipotezy 2
//          (parse domain z AXTitle okna)
//
// Wymaga: Terminal musi mieć Accessibility permission
// (System Settings → Privacy & Security → Accessibility → +Terminal).
import ApplicationServices
import AppKit

let delaySeconds = Double(CommandLine.arguments.count > 1
                          ? CommandLine.arguments[1] : "3") ?? 3.0

fputs("sflow-probe-ax-url: waiting \(delaySeconds)s for you to focus the browser…\n", stderr)
Thread.sleep(forTimeInterval: delaySeconds)

guard AXIsProcessTrusted() else {
    fputs("\nERROR: This process lacks Accessibility permission.\n", stderr)
    fputs("Open System Settings → Privacy & Security → Accessibility,\n", stderr)
    fputs("add Terminal (or iTerm/your shell), and re-run.\n", stderr)
    exit(2)
}

guard let app = NSWorkspace.shared.frontmostApplication,
      let bundleId = app.bundleIdentifier else {
    fputs("ERROR: cannot read frontmost app.\n", stderr)
    exit(3)
}

print("=== sflow-probe-ax-url ===")
print("frontmost app: \(app.localizedName ?? "?") [\(bundleId)] pid=\(app.processIdentifier)")
print()

let axApp = AXUIElementCreateApplication(app.processIdentifier)
// Force Chromium/Electron to expose its AX tree. Idempotent.
AXUIElementSetAttributeValue(axApp, "AXManualAccessibility" as CFString, kCFBooleanTrue)
AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)

// 1) Window title — fallback signal for Hypothesis 2 (parse domain from title).
var windowsRef: AnyObject?
AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
let windows = (windowsRef as? [AXUIElement]) ?? []
print("--- window titles (Hypothesis 2 fallback signal) ---")
for (i, w) in windows.enumerated() {
    var titleRef: AnyObject?
    AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &titleRef)
    print("window[\(i)] title: \"\(titleRef as? String ?? "")\"")
}
print()

// 2) Walk for AXWebArea nodes (Hypothesis 1: AXURL exposed natively).
var webAreasFound = 0
func dumpAttributes(_ el: AXUIElement, prefix: String = "  ") {
    var attrs: CFArray?
    AXUIElementCopyAttributeNames(el, &attrs)
    let names = (attrs as? [String]) ?? []
    let interesting: Set<String> = [
        "AXURL", "AXDocument", "AXTitle", "AXValue", "AXSubrole",
        "AXDescription", "AXIdentifier", "AXHelp", "AXRoleDescription"
    ]
    for name in names where interesting.contains(name) {
        var val: AnyObject?
        AXUIElementCopyAttributeValue(el, name as CFString, &val)
        let str: String
        if let s = val as? String {
            str = s
        } else if let url = val as? URL {
            str = url.absoluteString
        } else {
            str = String(describing: val).prefix(120) + ""
        }
        print("\(prefix)\(name) = \(str.prefix(200))")
    }
}

func walk(_ el: AXUIElement, depth: Int) {
    guard depth < 12 else { return }
    var roleRef: AnyObject?
    AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleRef)
    let role = roleRef as? String ?? ""

    if role == "AXWebArea" {
        webAreasFound += 1
        print("--- AXWebArea #\(webAreasFound) (depth=\(depth)) ---")
        dumpAttributes(el)
        print()
    }

    var childrenRef: AnyObject?
    AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &childrenRef)
    for child in (childrenRef as? [AXUIElement]) ?? [] {
        walk(child, depth: depth + 1)
    }
}

walk(axApp, depth: 0)

if webAreasFound == 0 {
    print("--- no AXWebArea found in tree ---")
    print("→ Hypothesis 1 (AXURL native) UNAVAILABLE.")
    print("→ Use Hypothesis 2 (parse domain from window title above).")
} else {
    print("=== summary ===")
    print("\(webAreasFound) AXWebArea node(s) found.")
    print("→ If any printed an AXURL/AXDocument with a real https:// URL,")
    print("   Hypothesis 1 is viable. Use that.")
    print("→ If all AXURL values are empty, use Hypothesis 2.")
}

// 3) Cursor hit-test — what does the click pipeline see right now?
let nsLoc = NSEvent.mouseLocation
let primaryH = NSScreen.screens.first?.frame.height ?? 900
let cursorX = Float(nsLoc.x)
let cursorY = Float(primaryH - nsLoc.y)
print()
print("--- cursor hit-test (AX coords: \(Int(cursorX)),\(Int(cursorY))) ---")
var hitRef: AXUIElement?
let hitRes = AXUIElementCopyElementAtPosition(axApp, cursorX, cursorY, &hitRef)
if hitRes == .success, let hit = hitRef {
    var roleRef: AnyObject?
    AXUIElementCopyAttributeValue(hit, kAXRoleAttribute as CFString, &roleRef)
    print("hit role: \(roleRef as? String ?? "?")")
    dumpAttributes(hit)
} else {
    print("hit-test failed (result code \(hitRes.rawValue))")
}
