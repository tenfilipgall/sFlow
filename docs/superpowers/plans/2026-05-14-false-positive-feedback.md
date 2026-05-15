# Session 5: False-Positive Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users ⌘+click a toast to report it as wrong — SFlow disables the shortcut locally after 3 reports, logs every report to disk, and POSTs to backend at count=3 so Claude can regenerate without the bad rule.

**Architecture:** A new `FalsePositiveStore` singleton tracks per-shortcut report counts in memory and rebuilds disabled state from `false_positives.jsonl` on startup. `ToastWindow` adds global NSEvent monitors so ⌘+click always reaches it regardless of `ignoresMouseEvents`. The backend's `/v1/feedback` endpoint stores report counts in the existing FEEDBACK KV; `/v1/discover` applies the filter on-the-fly before returning rules.

**Tech Stack:** Swift/AppKit (NSEvent global monitors, ObservableObject, XCTest), TypeScript/Cloudflare Workers (Zod, KV, Vitest)

---

## File Map

**New files (Swift):**
- `SFlow/KeySymbols.swift` — free function `keySymbol(_:)` extracted from ToastWindow so SettingsWindow can reuse it
- `SFlow/FalsePositiveStore.swift` — ObservableObject singleton, tracks report counts + disabled state, reads/writes `false_positives.jsonl`
- `SFlowTests/FalsePositiveStoreTests.swift` — unit tests for FalsePositiveStore

**New files (backend):**
- `backend/src/handlers/feedback.ts` — `/v1/feedback` route handler

**Modified files (Swift):**
- `SFlow/EventLogger.swift` — add `falsePosLogURL` static URL + `logFalsePositive(event:)` + `logFalsePositive(event:to:)`
- `SFlow/ToastWindow.swift` — add `onFalsePositive` callback, global NSEvent monitors, ✕ badge, use `keySymbol` from KeySymbols.swift
- `SFlow/SettingsWindow.swift` — replace AdvancedTab placeholder with SwiftUI list from FalsePositiveStore
- `SFlow/DiscoveryClient.swift` — add `func feedback(bundleId:keys:reportType:) async`
- `SFlow/AppDelegate.swift` — wire FalsePositiveStore.setClient + check isDisabled + pass onFalsePositive callback
- `SFlow/Analyzer.swift` — add false-positive section to report; update `run()` to read `false_positives.jsonl`
- `SFlowTests/EventLoggerTests.swift` — add 2 false-positive log tests
- `SFlowTests/AnalyzerTests.swift` — add 2 false-positive aggregation tests

**Modified files (backend):**
- `backend/src/types.ts` — simplify `FeedbackSchema` to `{bundleId, keys, reportType}`
- `backend/src/handlers/discover.ts` — load FEEDBACK KV, filter rules with count ≥ 3
- `backend/src/index.ts` — wire `/v1/feedback` route
- `backend/tests/discover.test.ts` — add 2 tests for feedback filtering
- `backend/tests/feedback.test.ts` — new file with 4 handler tests

**Modified files (docs):**
- `docs/audit-phase-1.md` — mark Session 5 done
- `docs/audit-phase-0.md` — update relevant items

---

## Task 1: EventLogger — false-positive logging

**Files:**
- Modify: `SFlow/EventLogger.swift`
- Modify: `SFlowTests/EventLoggerTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `SFlowTests/EventLoggerTests.swift`, inside `final class EventLoggerTests`:

```swift
func test_logFalsePositive_createsFileAndWritesType() throws {
    let event = makeEvent(bundleId: "com.test", shortcutId: "fp-test",
                          keys: ["meta", "k"], hint: "Test")
    EventLogger.logFalsePositive(event: event, to: logFile)
    EventLogger.flush()
    XCTAssertTrue(FileManager.default.fileExists(atPath: logFile.path))
    let content = try String(contentsOf: logFile, encoding: .utf8)
    let line = content.trimmingCharacters(in: .newlines)
    let json = try JSONSerialization.jsonObject(with: line.data(using: .utf8)!) as! [String: Any]
    XCTAssertEqual(json["type"] as? String, "false_positive")
    XCTAssertEqual(json["bundleId"] as? String, "com.test")
    XCTAssertEqual(json["shortcutId"] as? String, "fp-test")
    XCTAssertEqual(json["keys"] as? [String], ["meta", "k"])
    XCTAssertEqual(json["hint"] as? String, "Test")
    XCTAssertNotNil(json["timestamp"])
}

func test_logFalsePositive_appendsMultipleLines() throws {
    EventLogger.logFalsePositive(event: makeEvent(shortcutId: "fp-1"), to: logFile)
    EventLogger.flush()
    EventLogger.logFalsePositive(event: makeEvent(shortcutId: "fp-2"), to: logFile)
    EventLogger.flush()
    let content = try String(contentsOf: logFile, encoding: .utf8)
    let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
    XCTAssertEqual(lines.count, 2)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/EventLoggerTests/test_logFalsePositive_createsFileAndWritesType \
  2>&1 | grep -E "PASS|FAIL|error:"
```

Expected: FAIL with "value of type 'EventLogger.Type' has no member 'logFalsePositive'"

- [ ] **Step 3: Implement in EventLogger.swift**

Open `SFlow/EventLogger.swift`. After the `defaultLogURL` static property, add:

```swift
static let falsePosLogURL: URL = {
    let appSupport = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let dir = appSupport.appendingPathComponent("SFlow")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("false_positives.jsonl")
}()
```

After the `logMiss(event:to:)` method, add:

```swift
static func logFalsePositive(event: ShortcutEvent) {
    logFalsePositive(event: event, to: falsePosLogURL)
}

static func logFalsePositive(event: ShortcutEvent, to url: URL) {
    let formatter = ISO8601DateFormatter()
    let entry: [String: Any] = [
        "type":       "false_positive",
        "timestamp":  formatter.string(from: Date()),
        "bundleId":   event.bundleId,
        "shortcutId": event.shortcutId,
        "keys":       event.keys,
        "hint":       event.hint,
    ]
    write(entry, to: url)
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/EventLoggerTests \
  2>&1 | grep -E "PASS|FAIL|error:"
```

Expected: All EventLoggerTests PASS (7 total).

- [ ] **Step 5: Commit**

```bash
git add SFlow/EventLogger.swift SFlowTests/EventLoggerTests.swift
git commit -m "feat(logger): add logFalsePositive writing to false_positives.jsonl"
```

---

## Task 2: FalsePositiveStore — in-memory + disk-backed state

**Files:**
- Create: `SFlow/FalsePositiveStore.swift`
- Create: `SFlowTests/FalsePositiveStoreTests.swift`

- [ ] **Step 1: Create FalsePositiveStoreTests.swift with failing tests**

Create `SFlowTests/FalsePositiveStoreTests.swift`:

```swift
import XCTest
@testable import SFlow

final class FalsePositiveStoreTests: XCTestCase {
    private var tempDir: URL!
    private var falsePosURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        falsePosURL = tempDir.appendingPathComponent("false_positives.jsonl")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_toastShown_addsToRecentToasts() {
        let store = FalsePositiveStore(falsePosURL: falsePosURL)
        store.toastShown(event: makeEvent(shortcutId: "s1"))
        XCTAssertEqual(store.recentToasts.count, 1)
        XCTAssertEqual(store.recentToasts[0].id, "s1")
        XCTAssertEqual(store.recentToasts[0].keys, ["meta", "k"])
    }

    func test_toastShown_movesExistingToFront() {
        let store = FalsePositiveStore(falsePosURL: falsePosURL)
        store.toastShown(event: makeEvent(shortcutId: "s1"))
        store.toastShown(event: makeEvent(shortcutId: "s2"))
        store.toastShown(event: makeEvent(shortcutId: "s1"))
        XCTAssertEqual(store.recentToasts.count, 2)
        XCTAssertEqual(store.recentToasts[0].id, "s1")
        XCTAssertEqual(store.recentToasts[1].id, "s2")
    }

    func test_toastShown_capsAt50() {
        let store = FalsePositiveStore(falsePosURL: falsePosURL)
        for i in 0..<60 {
            store.toastShown(event: makeEvent(shortcutId: "s\(i)"))
        }
        XCTAssertEqual(store.recentToasts.count, 50)
    }

    func test_report_incrementsCountAndUpdatesRecord() {
        let store = FalsePositiveStore(falsePosURL: falsePosURL)
        store.toastShown(event: makeEvent(shortcutId: "fp1"))
        store.report(shortcutId: "fp1", bundleId: "com.test", keys: ["meta", "k"], hint: "Test")
        store.report(shortcutId: "fp1", bundleId: "com.test", keys: ["meta", "k"], hint: "Test")
        XCTAssertEqual(store.recentToasts[0].reportCount, 2)
        XCTAssertFalse(store.isDisabled(shortcutId: "fp1"))
    }

    func test_report_disablesAtThreshold() {
        let store = FalsePositiveStore(falsePosURL: falsePosURL)
        store.toastShown(event: makeEvent(shortcutId: "fp2"))
        for _ in 0..<3 {
            store.report(shortcutId: "fp2", bundleId: "com.test", keys: ["meta", "k"], hint: "Test")
        }
        XCTAssertTrue(store.isDisabled(shortcutId: "fp2"))
        XCTAssertTrue(store.recentToasts[0].isDisabled)
    }

    func test_isDisabled_persistsAcrossRestarts() {
        let store1 = FalsePositiveStore(falsePosURL: falsePosURL)
        store1.toastShown(event: makeEvent(shortcutId: "fp3"))
        for _ in 0..<3 {
            store1.report(shortcutId: "fp3", bundleId: "com.test", keys: ["meta", "k"], hint: "Test")
        }
        EventLogger.flush()

        let store2 = FalsePositiveStore(falsePosURL: falsePosURL)
        XCTAssertTrue(store2.isDisabled(shortcutId: "fp3"))
    }

    func test_isDisabled_belowThresholdNotDisabledAfterRestart() {
        let store1 = FalsePositiveStore(falsePosURL: falsePosURL)
        store1.toastShown(event: makeEvent(shortcutId: "fp4"))
        store1.report(shortcutId: "fp4", bundleId: "com.test", keys: ["meta", "k"], hint: "Test")
        store1.report(shortcutId: "fp4", bundleId: "com.test", keys: ["meta", "k"], hint: "Test")
        EventLogger.flush()

        let store2 = FalsePositiveStore(falsePosURL: falsePosURL)
        XCTAssertFalse(store2.isDisabled(shortcutId: "fp4"))
    }

    private func makeEvent(shortcutId: String) -> ShortcutEvent {
        ShortcutEvent(bundleId: "com.test", shortcutId: shortcutId,
                      keys: ["meta", "k"], hint: "Test", mouseX: 0, mouseY: 0)
    }
}
```

- [ ] **Step 2: Register the test file in Xcode project**

Add `FalsePositiveStoreTests.swift` to `SFlowTests` target in `SFlow.xcodeproj/project.pbxproj`. Use UUIDs `CAFE0200` (file ref) and `CAFE0201` (build file). Follow the exact same pattern as `CAFE0100`/`CAFE0101` (ClickWatcherParseTests) in project.pbxproj:

In the `/* Begin PBXBuildFile section */`, add:
```
		CAFE0201 /* FalsePositiveStoreTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = CAFE0200 /* FalsePositiveStoreTests.swift */; };
```

In the `/* Begin PBXFileReference section */`, add:
```
		CAFE0200 /* FalsePositiveStoreTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = FalsePositiveStoreTests.swift; sourceTree = "<group>"; };
```

In the SFlowTests group children array, add `CAFE0200`:
```
				CAFE0200 /* FalsePositiveStoreTests.swift */,
```

In the SFlowTests target `Sources` build phase files array, add `CAFE0201`:
```
				CAFE0201 /* FalsePositiveStoreTests.swift in Sources */,
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/FalsePositiveStoreTests \
  2>&1 | grep -E "PASS|FAIL|error:" | head -10
```

Expected: FAIL with "cannot find type 'FalsePositiveStore'"

- [ ] **Step 4: Create FalsePositiveStore.swift**

Create `SFlow/FalsePositiveStore.swift`:

```swift
import Foundation
import Combine

struct ToastRecord: Identifiable {
    let id: String        // == shortcutId
    let bundleId: String
    let keys: [String]
    let hint: String
    var reportCount: Int
    var isDisabled: Bool
}

final class FalsePositiveStore: ObservableObject {
    static let shared = FalsePositiveStore()

    @Published private(set) var recentToasts: [ToastRecord] = []

    private let falsePosURL: URL
    private var disabledIds: Set<String> = []
    private var reportCounts: [String: Int] = [:]
    private weak var client: DiscoveryClient?

    init(falsePosURL: URL = EventLogger.falsePosLogURL) {
        self.falsePosURL = falsePosURL
        loadDisabledFromDisk()
    }

    func setClient(_ client: DiscoveryClient) {
        self.client = client
    }

    func isDisabled(shortcutId: String) -> Bool {
        disabledIds.contains(shortcutId)
    }

    func toastShown(event: ShortcutEvent) {
        if let idx = recentToasts.firstIndex(where: { $0.id == event.shortcutId }) {
            let existing = recentToasts.remove(at: idx)
            recentToasts.insert(existing, at: 0)
        } else {
            let record = ToastRecord(
                id: event.shortcutId, bundleId: event.bundleId,
                keys: event.keys, hint: event.hint,
                reportCount: reportCounts[event.shortcutId] ?? 0,
                isDisabled: disabledIds.contains(event.shortcutId)
            )
            recentToasts.insert(record, at: 0)
            if recentToasts.count > 50 { recentToasts.removeLast() }
        }
    }

    func report(shortcutId: String, bundleId: String, keys: [String], hint: String) {
        reportCounts[shortcutId, default: 0] += 1
        let count = reportCounts[shortcutId]!

        let logEvent = ShortcutEvent(bundleId: bundleId, shortcutId: shortcutId,
                                     keys: keys, hint: hint, mouseX: 0, mouseY: 0)
        EventLogger.logFalsePositive(event: logEvent, to: falsePosURL)

        if let idx = recentToasts.firstIndex(where: { $0.id == shortcutId }) {
            recentToasts[idx].reportCount = count
            if count >= 3 { recentToasts[idx].isDisabled = true }
        }

        if count >= 3 {
            disabledIds.insert(shortcutId)
            if let client = client {
                Task { await client.feedback(bundleId: bundleId, keys: keys) }
            }
        }
    }

    func report(record: ToastRecord) {
        report(shortcutId: record.id, bundleId: record.bundleId,
               keys: record.keys, hint: record.hint)
    }

    private func loadDisabledFromDisk() {
        guard let content = try? String(contentsOf: falsePosURL, encoding: .utf8) else { return }
        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let shortcutId = obj["shortcutId"] as? String else { continue }
            reportCounts[shortcutId, default: 0] += 1
            if reportCounts[shortcutId]! >= 3 {
                disabledIds.insert(shortcutId)
            }
        }
    }
}
```

- [ ] **Step 5: Register FalsePositiveStore.swift in Xcode project**

Add `FalsePositiveStore.swift` to the `SFlow` app target in `project.pbxproj`. Use UUIDs `CAFE0202` (file ref) and `CAFE0203` (build file). Add to the SFlow group and SFlow target Sources build phase. Follow the same pattern as other Swift source files in the project.

- [ ] **Step 6: Run tests to verify they pass**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/FalsePositiveStoreTests \
  2>&1 | grep -E "PASS|FAIL|error:"
```

Expected: All 6 FalsePositiveStoreTests PASS.

- [ ] **Step 7: Run full suite to check no regressions**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  2>&1 | grep -E "Test Suite|PASS|FAIL|error:" | tail -20
```

Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add SFlow/FalsePositiveStore.swift SFlowTests/FalsePositiveStoreTests.swift \
        SFlow.xcodeproj/project.pbxproj
git commit -m "feat: add FalsePositiveStore with disk persistence and disable-at-3 logic"
```

---

## Task 3: KeySymbols.swift + ToastWindow cmd-klik

**Files:**
- Create: `SFlow/KeySymbols.swift`
- Modify: `SFlow/ToastWindow.swift`

- [ ] **Step 1: Create KeySymbols.swift**

Create `SFlow/KeySymbols.swift`:

```swift
import Foundation

func keySymbol(_ key: String) -> String {
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
    case "capslock":   return "⇪"
    case "[":          return "["
    case "]":          return "]"
    default:           return key.uppercased()
    }
}
```

Register in project.pbxproj with UUIDs `CAFE0204` (file ref) and `CAFE0205` (build file), added to SFlow app target.

- [ ] **Step 2: Modify ToastWindow.swift**

Replace the entire `ToastWindow.swift` with the version below. Changes:
- Remove the private static `keySymbol(_:)` method (now in KeySymbols.swift)
- Add `var onFalsePositive: (() -> Void)?` instance var
- Add private `reportBadge: NSTextField` instance var for the ✕ hint
- Add private `keyMonitor: Any?` and `clickMonitor: Any?` for global event monitors
- Change `appear()` to install monitors and call new `dismiss()`
- Add private `dismiss()` method that cleans up monitors before fade-out
- Update `show(event:)` to accept optional `onFalsePositive` parameter
- Change `buildContent` call in init to use the free `keySymbol` function

```swift
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

    private init(event: ShortcutEvent, onFalsePositive: (() -> Void)? = nil) {
        self.onFalsePositive = onFalsePositive
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

        // Report badge — shown when ⌘ is held
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
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            animator().alphaValue = 1
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
            self.dismiss()
            handler?()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.dismiss()
        }
    }

    private func dismiss() {
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
```

- [ ] **Step 3: Build to verify it compiles**

```bash
xcodebuild build -scheme SFlow -destination 'platform=macOS' \
  2>&1 | grep -E "error:|warning:|BUILD"
```

Expected: BUILD SUCCEEDED, no errors.

- [ ] **Step 4: Run full test suite**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  2>&1 | grep -E "Test Suite.*passed|FAIL|error:" | tail -5
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add SFlow/KeySymbols.swift SFlow/ToastWindow.swift SFlow.xcodeproj/project.pbxproj
git commit -m "feat(toast): cmd-klik reports shortcut as wrong — global NSEvent monitors + dismiss callback"
```

---

## Task 4: SettingsWindow — Recent shortcuts list

**Files:**
- Modify: `SFlow/SettingsWindow.swift`

No unit tests for pure SwiftUI view — visual verification only.

- [ ] **Step 1: Replace AdvancedTab in SettingsWindow.swift**

Replace the entire `private struct AdvancedTab: View` in `SFlow/SettingsWindow.swift` with:

```swift
private struct AdvancedTab: View {
    @AppStorage("showExperimental") private var showExperimental: Bool = false
    @ObservedObject private var store: FalsePositiveStore = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Toggle("Show experimental shortcuts", isOn: $showExperimental)
                    .help("Activates low-confidence auto-discovered rules. May show incorrect shortcuts.")
            }
            .padding([.horizontal, .top])

            Divider().padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                Text("Recent shortcuts")
                    .font(.headline)
                    .padding([.horizontal, .top])

                if store.recentToasts.isEmpty {
                    Text("No shortcuts shown yet.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .padding(.horizontal)
                } else {
                    List(store.recentToasts) { record in
                        HStack(spacing: 8) {
                            Text(record.keys.map { keySymbol($0) }.joined())
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 60, alignment: .leading)
                            Text(record.hint)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Spacer()
                            if record.isDisabled {
                                Text("Disabled")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            } else {
                                Button("Report incorrect") {
                                    store.report(record: record)
                                }
                                .font(.caption)
                            }
                        }
                    }
                    .frame(height: 140)
                }
            }

            Divider().padding(.top, 4)

            Form {
                Button("Force re-seed all rules") {}
                    .disabled(true)
                    .help("Coming in Session 6.")
            }
            .padding([.horizontal, .bottom])
        }
    }
}
```

- [ ] **Step 2: Build and verify it compiles**

```bash
xcodebuild build -scheme SFlow -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SFlow/SettingsWindow.swift
git commit -m "feat(settings): replace Recent shortcuts placeholder with live FalsePositiveStore list"
```

---

## Task 5: Backend — simplified FeedbackSchema + /v1/feedback + discover filtering

**Files:**
- Modify: `backend/src/types.ts`
- Create: `backend/src/handlers/feedback.ts`
- Modify: `backend/src/handlers/discover.ts`
- Modify: `backend/src/index.ts`
- Create: `backend/tests/feedback.test.ts`
- Modify: `backend/tests/discover.test.ts`

- [ ] **Step 1: Write failing tests for /v1/feedback**

Create `backend/tests/feedback.test.ts`:

```typescript
import { env, SELF } from "cloudflare:test";
import { describe, expect, it, beforeEach } from "vitest";

describe("POST /v1/feedback", () => {
  beforeEach(async () => {
    const list = await env.FEEDBACK.list();
    for (const k of list.keys) await env.FEEDBACK.delete(k.name);
  });

  it("returns 405 on GET", async () => {
    const r = await SELF.fetch("https://example.com/v1/feedback");
    expect(r.status).toBe(405);
  });

  it("returns 400 on missing fields", async () => {
    const r = await SELF.fetch("https://example.com/v1/feedback", {
      method: "POST",
      body: JSON.stringify({ bundleId: "com.x" }),
    });
    expect(r.status).toBe(400);
  });

  it("returns 200 and stores count in FEEDBACK KV", async () => {
    const r = await SELF.fetch("https://example.com/v1/feedback", {
      method: "POST",
      body: JSON.stringify({
        bundleId: "com.x",
        keys: ["meta", "k"],
        reportType: "wrong_shortcut",
      }),
    });
    expect(r.status).toBe(200);

    const raw = await env.FEEDBACK.get("feedback:com.x");
    expect(raw).not.toBeNull();
    const counts = JSON.parse(raw!);
    expect(counts["k+meta"]).toBe(1);
  });

  it("increments count on repeated reports", async () => {
    const body = JSON.stringify({
      bundleId: "com.x",
      keys: ["meta", "k"],
      reportType: "wrong_shortcut",
    });
    await SELF.fetch("https://example.com/v1/feedback", { method: "POST", body });
    await SELF.fetch("https://example.com/v1/feedback", { method: "POST", body });
    await SELF.fetch("https://example.com/v1/feedback", { method: "POST", body });

    const raw = await env.FEEDBACK.get("feedback:com.x");
    const counts = JSON.parse(raw!);
    expect(counts["k+meta"]).toBe(3);
  });
});
```

- [ ] **Step 2: Write failing tests for discover filtering in discover.test.ts**

In `backend/tests/discover.test.ts`, after the existing tests, add:

```typescript
  it("filters out rules flagged with count >= 3 from cached response", async () => {
    await env.RULES_CACHE.put(
      "rules:com.x:1.0",
      JSON.stringify({
        bundleId: "com.x",
        rulesVersion: "2026-05-14T00:00:00Z",
        rules: [
          {
            match: { role: "AXButton", titles: ["Send"] },
            keys: ["meta", "enter"],
            hint: "Send",
            confidence: "high",
            source: "menu_bar",
          },
          {
            match: { role: "AXButton", titles: ["New Issue"] },
            keys: ["meta", "k"],
            hint: "New Issue",
            confidence: "high",
            source: "menu_bar",
          },
        ],
      }),
    );
    // flag meta+k with count >= 3
    await env.FEEDBACK.put(
      "feedback:com.x",
      JSON.stringify({ "k+meta": 3 }),
    );

    const r = await SELF.fetch("https://example.com/v1/discover", {
      method: "POST",
      body: JSON.stringify({
        bundleId: "com.x",
        appName: "X",
        appVersion: "1.0.7",
        menuBar: [],
        uiSkeleton: [],
        clientVersion: "1.0",
      }),
    });
    expect(r.status).toBe(200);
    const body = await r.json() as any;
    expect(body.rules).toHaveLength(1);
    expect(body.rules[0].keys).toEqual(["meta", "enter"]);
  });

  it("does not filter rules with count < 3", async () => {
    await env.RULES_CACHE.put(
      "rules:com.y:1.0",
      JSON.stringify({
        bundleId: "com.y",
        rulesVersion: "2026-05-14T00:00:00Z",
        rules: [
          {
            match: { role: "AXButton", titles: ["Save"] },
            keys: ["meta", "s"],
            hint: "Save",
            confidence: "high",
            source: "menu_bar",
          },
        ],
      }),
    );
    await env.FEEDBACK.put(
      "feedback:com.y",
      JSON.stringify({ "meta+s": 2 }),
    );

    const r = await SELF.fetch("https://example.com/v1/discover", {
      method: "POST",
      body: JSON.stringify({
        bundleId: "com.y",
        appName: "Y",
        appVersion: "1.0.7",
        menuBar: [],
        uiSkeleton: [],
        clientVersion: "1.0",
      }),
    });
    const body = await r.json() as any;
    expect(body.rules).toHaveLength(1);
  });
```

- [ ] **Step 3: Run backend tests to verify they fail**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow/backend && npm test 2>&1 | grep -E "PASS|FAIL|✓|✗|×" | head -20
```

Expected: feedback tests FAIL (route not found), discover filter tests FAIL.

- [ ] **Step 4: Simplify FeedbackSchema in types.ts**

In `backend/src/types.ts`, replace the `FeedbackSchema` and `Feedback` type:

```typescript
export const FeedbackSchema = z.object({
  bundleId: z.string().min(1).max(200),
  keys: z.array(z.string().min(1).max(20)).min(1).max(10),
  reportType: z.enum(["wrong_shortcut"]),
});

export type Feedback = z.infer<typeof FeedbackSchema>;
```

- [ ] **Step 5: Create backend/src/handlers/feedback.ts**

```typescript
import { FeedbackSchema } from "../types";
import type { Env } from "../index";

export async function handleFeedback(
  request: Request,
  env: Env,
): Promise<Response> {
  if (request.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonError(400, "Invalid JSON");
  }

  const parsed = FeedbackSchema.safeParse(body);
  if (!parsed.success) {
    return jsonError(400, `Invalid request: ${parsed.error.message}`);
  }
  const { bundleId, keys, reportType } = parsed.data;

  const feedbackKey = `feedback:${bundleId}`;
  const keysJoined = [...keys].sort().join("+");

  const raw = await env.FEEDBACK.get(feedbackKey);
  const counts: Record<string, number> = raw ? JSON.parse(raw) : {};
  counts[keysJoined] = (counts[keysJoined] ?? 0) + 1;
  await env.FEEDBACK.put(feedbackKey, JSON.stringify(counts));

  console.log(
    JSON.stringify({ type: "feedback", bundleId, keys, reportType, count: counts[keysJoined] }),
  );
  return new Response("OK", { status: 200 });
}

function jsonError(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
```

- [ ] **Step 6: Wire /v1/feedback route in index.ts**

In `backend/src/index.ts`, add the import and route. Replace the file content:

```typescript
import { handleDiscover } from "./handlers/discover";
import { handleFeedback } from "./handlers/feedback";

export interface Env {
  RULES_CACHE: KVNamespace;
  FEEDBACK: KVNamespace;
  RATE_LIMIT: KVNamespace;
  ANTHROPIC_API_KEY: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/v1/discover") {
      return handleDiscover(request, env);
    }

    if (url.pathname === "/v1/feedback") {
      return handleFeedback(request, env);
    }

    if (url.pathname === "/" || url.pathname === "/health") {
      return new Response("SFlow Rules Worker", { status: 200 });
    }

    return new Response("Not Found", { status: 404 });
  },
};
```

- [ ] **Step 7: Add feedback filtering to discover.ts**

In `backend/src/handlers/discover.ts`, add a helper function and apply it. Add after the imports:

```typescript
async function loadFlaggedKeys(
  feedback: KVNamespace,
  bundleId: string,
): Promise<Set<string>> {
  const raw = await feedback.get(`feedback:${bundleId}`);
  if (!raw) return new Set();
  const counts: Record<string, number> = JSON.parse(raw);
  return new Set(
    Object.entries(counts)
      .filter(([, count]) => count >= 3)
      .map(([key]) => key),
  );
}

function applyFeedbackFilter(
  ruleSet: { bundleId: string; rulesVersion: string; rules: Array<{ keys: string[]; [key: string]: unknown }> },
  flaggedKeys: Set<string>,
): typeof ruleSet {
  if (flaggedKeys.size === 0) return ruleSet;
  return {
    ...ruleSet,
    rules: ruleSet.rules.filter(
      (rule) => !flaggedKeys.has([...rule.keys].sort().join("+")),
    ),
  };
}
```

Then in the `handleDiscover` function body, replace the cache-hit return block:

Old:
```typescript
    if (cached) {
      const c = cached as { rules?: unknown[] };
      console.log(JSON.stringify({
        type: "discover", bundleId: req.bundleId, appVersion: req.appVersion,
        cacheHit: true, fresh: false, rulesGenerated: c.rules?.length ?? 0,
        durationMs: Date.now() - start,
      }));
      return jsonResponse(cached);
    }
```

New:
```typescript
    if (cached) {
      const flaggedKeys = await loadFlaggedKeys(env.FEEDBACK, req.bundleId);
      const filtered = applyFeedbackFilter(cached as any, flaggedKeys);
      const c = filtered as { rules?: unknown[] };
      console.log(JSON.stringify({
        type: "discover", bundleId: req.bundleId, appVersion: req.appVersion,
        cacheHit: true, fresh: false, rulesGenerated: c.rules?.length ?? 0,
        flaggedFiltered: flaggedKeys.size,
        durationMs: Date.now() - start,
      }));
      return jsonResponse(filtered);
    }
```

And replace the final `return jsonResponse(rules)`:

Old:
```typescript
  return jsonResponse(rules);
```

New:
```typescript
  const flaggedKeys = await loadFlaggedKeys(env.FEEDBACK, req.bundleId);
  const filtered = applyFeedbackFilter(rules as any, flaggedKeys);
  return jsonResponse(filtered);
```

- [ ] **Step 8: Run backend tests**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow/backend && npm test 2>&1 | grep -E "PASS|FAIL|✓|✗|×|Tests" | head -30
```

Expected: All tests pass (41 existing + 4 feedback + 2 discover filter = 47 total).

- [ ] **Step 9: Run TypeScript type check**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow/backend && npx tsc --noEmit 2>&1 | grep -v "claude.ts"
```

Expected: No new errors (pre-existing errors in claude.ts are ignored).

- [ ] **Step 10: Commit**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow
git add backend/src/types.ts backend/src/handlers/feedback.ts \
        backend/src/handlers/discover.ts backend/src/index.ts \
        backend/tests/feedback.test.ts backend/tests/discover.test.ts
git commit -m "feat(backend): /v1/feedback endpoint + filter flagged rules from discover"
```

---

## Task 6: DiscoveryClient.feedback() + AppDelegate wiring

**Files:**
- Modify: `SFlow/DiscoveryClient.swift`
- Modify: `SFlow/AppDelegate.swift`

- [ ] **Step 1: Add feedback() to DiscoveryClient.swift**

In `SFlow/DiscoveryClient.swift`, add this method after `parseResponse(_:)`:

```swift
func feedback(bundleId: String, keys: [String], reportType: String = "wrong_shortcut") async {
    let url = baseURL.appendingPathComponent("v1/feedback")
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any] = ["bundleId": bundleId, "keys": keys, "reportType": reportType]
    req.httpBody = try? JSONSerialization.data(withJSONObject: body)
    req.timeoutInterval = 10
    do {
        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse {
            NSLog("SFlow: feedback POST \(http.statusCode) for \(bundleId)")
        }
    } catch {
        NSLog("SFlow: feedback POST failed: \(error.localizedDescription)")
    }
}
```

- [ ] **Step 2: Wire FalsePositiveStore in AppDelegate.swift**

In `SFlow/AppDelegate.swift`, in the `startWatcher()` method, after creating `client`:

Old:
```swift
        let client = DiscoveryClient(
            baseURL: DiscoveryClient.productionURL,
            clientVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        )
```

New:
```swift
        let client = DiscoveryClient(
            baseURL: DiscoveryClient.productionURL,
            clientVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        )
        FalsePositiveStore.shared.setClient(client)
```

Then replace the `clickWatcher = ClickWatcher(...)` block:

Old:
```swift
        clickWatcher = ClickWatcher(ruleCache: ruleCache) { event in
            ToastWindow.show(event: event)
            EventLogger.log(event: event)
        }
```

New:
```swift
        clickWatcher = ClickWatcher(ruleCache: ruleCache) { event in
            guard !FalsePositiveStore.shared.isDisabled(shortcutId: event.shortcutId) else { return }
            FalsePositiveStore.shared.toastShown(event: event)
            ToastWindow.show(event: event, onFalsePositive: {
                FalsePositiveStore.shared.report(
                    shortcutId: event.shortcutId, bundleId: event.bundleId,
                    keys: event.keys, hint: event.hint
                )
            })
            EventLogger.log(event: event)
        }
```

- [ ] **Step 3: Build to verify compilation**

```bash
xcodebuild build -scheme SFlow -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run full test suite**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  2>&1 | grep -E "Test Suite.*passed|FAIL|error:" | tail -5
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add SFlow/DiscoveryClient.swift SFlow/AppDelegate.swift
git commit -m "feat: wire FalsePositiveStore + DiscoveryClient.feedback() into AppDelegate"
```

---

## Task 7: Analyzer — false-positive section in sflow-analyze output

**Files:**
- Modify: `SFlow/Analyzer.swift`
- Modify: `SFlowTests/AnalyzerTests.swift`

- [ ] **Step 1: Write failing tests in AnalyzerTests.swift**

Add to `SFlowTests/AnalyzerTests.swift` inside `final class AnalyzerTests`:

```swift
func test_aggregateFalsePositives_groupsByAppAndKeys() {
    let lines = [
        #"{"type":"false_positive","bundleId":"com.x","shortcutId":"s1","keys":["meta","k"],"hint":"New","timestamp":"2026-05-14T00:00:00Z"}"#,
        #"{"type":"false_positive","bundleId":"com.x","shortcutId":"s1","keys":["meta","k"],"hint":"New","timestamp":"2026-05-14T00:00:01Z"}"#,
        #"{"type":"false_positive","bundleId":"com.x","shortcutId":"s2","keys":["meta","enter"],"hint":"Send","timestamp":"2026-05-14T00:00:02Z"}"#,
        #"{"type":"false_positive","bundleId":"com.y","shortcutId":"s3","keys":["ctrl","w"],"hint":"Close","timestamp":"2026-05-14T00:00:03Z"}"#,
    ]
    let fp = Analyzer.aggregateFalsePositives(lines: lines)
    XCTAssertEqual(fp.count, 2)
    let comX = fp.first { $0.bundleId == "com.x" }
    XCTAssertNotNil(comX)
    XCTAssertEqual(comX?.totalReports, 3)
    XCTAssertEqual(comX?.topEntries[0].count, 2)
    XCTAssertEqual(comX?.topEntries[0].keys, ["meta", "k"])
}

func test_format_includesFalsePositiveSection() {
    let report = Analyzer.Report(totalToasts: 10, totalMisses: 2, appsRanked: [])
    let fpReport: [Analyzer.FalsePosAppReport] = [
        Analyzer.FalsePosAppReport(
            bundleId: "com.x",
            totalReports: 5,
            topEntries: [Analyzer.FalsePosEntry(keys: ["meta", "k"], hint: "Test", count: 5)]
        )
    ]
    let output = Analyzer.format(report: report, falsePositives: fpReport)
    XCTAssertTrue(output.contains("False Positive"))
    XCTAssertTrue(output.contains("com.x"))
    XCTAssertTrue(output.contains("meta"))
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/AnalyzerTests/test_aggregateFalsePositives_groupsByAppAndKeys \
  2>&1 | grep -E "PASS|FAIL|error:"
```

Expected: FAIL with "type 'Analyzer.Type' has no member 'aggregateFalsePositives'"

- [ ] **Step 3: Implement in Analyzer.swift**

Add new types after `AppReport`, before `private struct MissKey`:

```swift
struct FalsePosEntry: Equatable {
    let keys: [String]
    let hint: String
    let count: Int
}

struct FalsePosAppReport: Equatable {
    let bundleId: String
    let totalReports: Int
    let topEntries: [FalsePosEntry]
}
```

Add new static method after `aggregate(lines:)`:

```swift
static func aggregateFalsePositives(lines: [String]) -> [FalsePosAppReport] {
    struct EntryKey: Hashable { let bundleId: String; let shortcutId: String }
    var byApp: [String: [String: (keys: [String], hint: String, count: Int)]] = [:]

    for line in lines {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["type"] as? String == "false_positive",
              let bundleId = obj["bundleId"] as? String,
              let shortcutId = obj["shortcutId"] as? String,
              let keys = obj["keys"] as? [String] else { continue }
        let hint = obj["hint"] as? String ?? ""
        if byApp[bundleId] == nil { byApp[bundleId] = [:] }
        let prev = byApp[bundleId]![shortcutId]
        byApp[bundleId]![shortcutId] = (keys: keys, hint: hint, count: (prev?.count ?? 0) + 1)
    }

    return byApp.map { (bundleId, entries) in
        let total = entries.values.reduce(0) { $0 + $1.count }
        let top = entries.values
            .map { FalsePosEntry(keys: $0.keys, hint: $0.hint, count: $0.count) }
            .sorted { $0.count > $1.count }
            .prefix(10)
        return FalsePosAppReport(bundleId: bundleId, totalReports: total, topEntries: Array(top))
    }.sorted { $0.totalReports > $1.totalReports }
}
```

Add a new `format(report:falsePositives:)` method and update `run()`. Replace the existing `format(report:)` and `run()`:

```swift
static func format(report: Report, falsePositives: [FalsePosAppReport] = []) -> String {
    var out = "SFlow Miss Analysis\n===================\n\n"
    if report.appsRanked.isEmpty {
        out += "No miss events logged yet. Use SFlow normally and try again.\n"
    } else {
        for app in report.appsRanked {
            out += "\(app.bundleId) \u{2014} \(app.missCount) misses\n"
            for entry in app.topMisses {
                let titleDisplay = entry.title.isEmpty ? "(no title)" : entry.title
                let rolePadded = entry.role.padding(toLength: 12, withPad: " ", startingAt: 0)
                out += String(format: "  %3dx  %@  \"%@\"\n",
                              entry.count,
                              rolePadded,
                              titleDisplay)
            }
            out += "\n"
        }
    }
    out += "Total: \(report.totalMisses) misses, \(report.totalToasts) toasts.\n"

    if !falsePositives.isEmpty {
        out += "\nFalse Positive Reports\n======================\n\n"
        for app in falsePositives {
            out += "\(app.bundleId) \u{2014} \(app.totalReports) reports\n"
            for entry in app.topEntries {
                out += String(format: "  %3dx  %-20s  \"%@\"\n",
                              entry.count,
                              entry.keys.joined(separator: "+"),
                              entry.hint)
            }
            out += "\n"
        }
    }
    return out
}

static func run(logURL: URL = EventLogger.defaultLogURL,
                falsePosURL: URL = EventLogger.falsePosLogURL) {
    let eventsContent = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
    let fpContent = (try? String(contentsOf: falsePosURL, encoding: .utf8)) ?? ""
    let eventLines = eventsContent.components(separatedBy: "\n").filter { !$0.isEmpty }
    let fpLines = fpContent.components(separatedBy: "\n").filter { !$0.isEmpty }

    if eventLines.isEmpty && fpLines.isEmpty {
        print("SFlow: no events file at \(logURL.path) — nothing to analyze yet.")
        return
    }

    let report = aggregate(lines: eventLines)
    let fpReport = aggregateFalsePositives(lines: fpLines)
    print(format(report: report, falsePositives: fpReport))
}
```

- [ ] **Step 4: Fix existing test that called the old format(report:) signature**

The existing `test_format_...` tests in AnalyzerTests.swift call `Analyzer.format(report:)`. Since we changed the signature to `format(report:falsePositives:)` with a default parameter, existing calls still compile unchanged. No edits needed.

- [ ] **Step 5: Run all analyzer tests**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/AnalyzerTests \
  2>&1 | grep -E "PASS|FAIL|error:"
```

Expected: All AnalyzerTests PASS.

- [ ] **Step 6: Run full test suite**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  2>&1 | grep -E "Test Suite.*passed|FAIL|error:" | tail -5
```

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add SFlow/Analyzer.swift SFlowTests/AnalyzerTests.swift
git commit -m "feat(analyze): add false-positive section to sflow-analyze report"
```

---

## Task 8: Audit docs update

**Files:**
- Modify: `docs/audit-phase-1.md`
- Modify: `docs/audit-phase-0.md`

- [ ] **Step 1: Update audit-phase-1.md**

In `docs/audit-phase-1.md`, find the Session 5 row and mark it done. Change:
```
| Sesja 5 | false-positive feedback | ⬜ |
```
To:
```
| Sesja 5 | false-positive feedback | 🟢 done |
```

Also update Sub-cel 1.11 (false-positive reporting) if present, from `⬜ pending` to `🟢 done`.

- [ ] **Step 2: Update audit-phase-0.md**

In `docs/audit-phase-0.md`, find and update:
- P-22 or equivalent (cmd-klik to report wrong toast): `⬜ otwarte` → `🟢 zamknięte`
- Any item about false-positive logging or backend feedback loop: mark accordingly

- [ ] **Step 3: Commit**

```bash
git add docs/audit-phase-1.md docs/audit-phase-0.md
git commit -m "docs: mark Session 5 complete in audit docs"
```

---

## Self-Review

### Spec coverage check

| Requirement | Task |
|---|---|
| Log false positives to `false_positives.jsonl` | Task 1 |
| `FalsePositiveStore` with count tracking | Task 2 |
| Disable locally after 3 reports | Task 2 |
| Disk persistence across restarts | Task 2 |
| `@Published recentToasts` for SwiftUI | Task 2 |
| cmd-klik on toast triggers report | Task 3 |
| Visual hint (✕ badge) when ⌘ held | Task 3 |
| Recent shortcuts list in Settings | Task 4 |
| Report button + Disabled badge | Task 4 |
| Simplified `FeedbackSchema` `{bundleId, keys, reportType}` | Task 5 |
| `/v1/feedback` stores count in KV | Task 5 |
| `/v1/discover` filters rules with count ≥ 3 | Task 5 |
| `DiscoveryClient.feedback()` method | Task 6 |
| `setClient()` injection + AppDelegate wiring | Task 6 |
| `isDisabled` check before showing toast | Task 6 |
| `sflow-analyze` surfaces false positives | Task 7 |
| Audit docs updated | Task 8 |

### Placeholder scan

No TBD, TODO, or "implement later" present. All code is complete.

### Type consistency

- `ToastRecord.id` (String) = shortcutId — consistent across Tasks 2, 4, 6
- `FalsePositiveStore.report(shortcutId:bundleId:keys:hint:)` — consistent across Tasks 2, 3, 6
- `FalsePositiveStore.report(record:)` convenience — consistent in Tasks 2, 4
- `EventLogger.logFalsePositive(event:to:)` — consistent across Tasks 1, 2
- `EventLogger.falsePosLogURL` — referenced in Tasks 1, 2, 7
- `DiscoveryClient.feedback(bundleId:keys:reportType:)` — consistent in Tasks 2, 6
- Backend: `feedback:{bundleId}` KV key, sorted `keys.join("+")` — consistent between Task 5 handler and discover filter
- `Analyzer.FalsePosAppReport` / `Analyzer.FalsePosEntry` — consistent across Task 7 impl and tests
- `keySymbol(_:)` free function — defined in KeySymbols.swift (Task 3), used in ToastWindow.swift (Task 3) and SettingsWindow.swift (Task 4)

All consistent. ✓
