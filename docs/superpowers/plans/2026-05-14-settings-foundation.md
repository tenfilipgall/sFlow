# Settings Foundation (Session 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Settings window (SwiftUI, 3 tabs) — foundation required for Session 4 (quality gate toggle), Session 5 (false-positive feedback list), Session 7 (self-healing controls). Wire `logMisses` to EventLogger and `showExperimental` to RuleCache via UserDefaults.

**Architecture:** `NSWindowController` singleton hosts `NSHostingView<SettingsView>`. SwiftUI `TabView` with three tabs. `@AppStorage` bindings write to `UserDefaults.standard`. AppDelegate observes `UserDefaults.didChangeNotification` to push `showExperimental` into the live `RuleCache` instance. `EventLogger.logMiss(event:)` guards on `logMisses` key before writing.

**Tech Stack:** Swift, SwiftUI (`NSHostingView`, `@AppStorage`), `NSWindowController`, `UserDefaults`, `NotificationCenter`

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Create | `SFlow/SettingsWindow.swift` | Window controller + SwiftUI view with 3 tabs |
| Modify | `SFlow/AppDelegate.swift` | "Settings…" ⌘, menu item + UserDefaults → RuleCache wiring |
| Modify | `SFlow/EventLogger.swift` | Guard `logMisses` in `logMiss(event:)` |
| Modify | `SFlowTests/EventLoggerTests.swift` | New test: logMisses=false skips write |

---

## Task 1: Failing test — EventLogger respects logMisses

**Files:**
- Modify: `SFlowTests/EventLoggerTests.swift`

- [ ] **Step 1: Add failing test at end of EventLoggerTests class (before closing `}`)**

Add this after `test_log_toastEventIncludesTypeField`:

```swift
func test_logMiss_skipsWriteWhenLogMissesDisabled() throws {
    try? FileManager.default.removeItem(at: EventLogger.defaultLogURL)
    UserDefaults.standard.set(false, forKey: "logMisses")
    defer { UserDefaults.standard.removeObject(forKey: "logMisses") }

    EventLogger.logMiss(event: MissEvent(bundleId: "test", role: "AXButton",
                                          title: "Foo", desc: "", help: ""))
    EventLogger.flush()
    XCTAssertFalse(FileManager.default.fileExists(atPath: EventLogger.defaultLogURL.path),
                   "logMiss must not write when logMisses is disabled")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project SFlow.xcodeproj -scheme SFlow -destination 'platform=macOS' -only-testing:SFlowTests/EventLoggerTests/test_logMiss_skipsWriteWhenLogMissesDisabled 2>&1 | tail -20`

Expected: FAIL — test sees the file was written (current code always writes).

---

## Task 2: Fix EventLogger to pass the test

**Files:**
- Modify: `SFlow/EventLogger.swift:45-48`

- [ ] **Step 3: Replace `logMiss(event:)` (no-URL overload) with guarded version**

Current code at line 45:
```swift
static func logMiss(event: MissEvent) {
    logMiss(event: event, to: defaultLogURL)
}
```

Replace with:
```swift
static func logMiss(event: MissEvent) {
    guard UserDefaults.standard.object(forKey: "logMisses") as? Bool ?? true else { return }
    logMiss(event: event, to: defaultLogURL)
}
```

Note: `object(forKey:) as? Bool ?? true` gives `true` when key is absent (desired default = ON).
`bool(forKey:)` would return `false` for absent key — wrong default.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project SFlow.xcodeproj -scheme SFlow -destination 'platform=macOS' -only-testing:SFlowTests/EventLoggerTests 2>&1 | tail -20`

Expected: All 5 EventLoggerTests pass.

- [ ] **Step 5: Commit EventLogger change**

```bash
git add SFlow/EventLogger.swift SFlowTests/EventLoggerTests.swift
git commit -m "feat(client): EventLogger.logMiss respects logMisses UserDefaults toggle"
```

---

## Task 3: Create SettingsWindow.swift

**Files:**
- Create: `SFlow/SettingsWindow.swift`

- [ ] **Step 6: Create the file**

Full content of `SFlow/SettingsWindow.swift`:

```swift
import SwiftUI
import AppKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private init() {
        let hosting = NSHostingView(rootView: SettingsView())
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 340)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SFlow Settings"
        window.contentView = hosting
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            PrivacyTab()
                .tabItem { Label("Privacy", systemImage: "eye.slash") }
            AdvancedTab()
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 480, height: 300)
        .padding([.horizontal, .bottom])
    }
}

private struct GeneralTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General preferences will appear here.")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

private struct PrivacyTab: View {
    @AppStorage("logMisses") private var logMisses: Bool = true
    @AppStorage("telemetry") private var telemetry: Bool = false

    var body: some View {
        Form {
            Toggle("Log miss events", isOn: $logMisses)
                .help("Records unrecognised clicks for sflow-analyze. Stored locally only.")
            Toggle("Share aggregated data with backend", isOn: $telemetry)
                .help("Not implemented yet — no data is sent.")
            Divider()
            HStack(spacing: 12) {
                Button("Open events.jsonl in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([EventLogger.defaultLogURL])
                }
                Button("Clear local data") {
                    try? FileManager.default.removeItem(at: EventLogger.defaultLogURL)
                }
            }
        }
        .padding()
    }
}

private struct AdvancedTab: View {
    @AppStorage("showExperimental") private var showExperimental: Bool = false

    var body: some View {
        Form {
            Toggle("Show experimental shortcuts", isOn: $showExperimental)
                .help("Activates low-confidence auto-discovered rules. May show incorrect shortcuts.")
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent shortcuts")
                    .font(.headline)
                Text("Last 50 toasts with disable option. Coming in Session 5.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            Divider()
            Button("Force re-seed all rules") {}
                .disabled(true)
                .help("Coming in Session 6.")
        }
        .padding()
    }
}
```

---

## Task 4: Modify AppDelegate — menu item + UserDefaults wiring

**Files:**
- Modify: `SFlow/AppDelegate.swift`

- [ ] **Step 7: Add "Settings…" menu item and UserDefaults observer**

In `setupStatusItem()`, insert Settings item before the separator. Change lines 31–40:

```swift
private func setupStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    refreshStatusIcon()

    let menu = NSMenu()
    let toggleItem = NSMenuItem(title: isEnabled ? "✓ Enabled" : "Enabled",
                                action: #selector(toggleEnabled),
                                keyEquivalent: "")
    toggleItem.tag = 1
    menu.addItem(toggleItem)
    menu.addItem(NSMenuItem(title: "Show Test Toast", action: #selector(showTestToast), keyEquivalent: ""))
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "Quit SFlow", action: #selector(quit), keyEquivalent: "q"))
    statusItem.menu = menu
}
```

- [ ] **Step 8: Add `openSettings` action and UserDefaults observer method**

Add after `quit()` method (around line 65):

```swift
@objc private func openSettings() {
    SettingsWindowController.shared.show()
}

@objc private func userDefaultsChanged() {
    ruleCache?.showExperimental = UserDefaults.standard.bool(forKey: "showExperimental")
}
```

- [ ] **Step 9: Wire UserDefaults in startWatcher()**

In `startWatcher()`, after `try ruleCache.load()` (around line 121), add:

```swift
ruleCache.showExperimental = UserDefaults.standard.bool(forKey: "showExperimental")
NotificationCenter.default.addObserver(
    self, selector: #selector(userDefaultsChanged),
    name: UserDefaults.didChangeNotification, object: nil
)
```

---

## Task 5: Build + manual test

- [ ] **Step 10: Build**

```bash
xcodebuild build -project SFlow.xcodeproj -scheme SFlow -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 11: Run full test suite**

```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlow -destination 'platform=macOS' 2>&1 | grep -E "(PASS|FAIL|error:|Build)"
```

Expected: All tests pass, zero errors.

- [ ] **Step 12: Manual verification checklist**

Build and run SFlow. Verify:
- [ ] Menu bar ⌘ icon → menu has "Settings…" item with ⌘, shortcut
- [ ] Click "Settings…" → window opens with 3 tabs (General, Privacy, Advanced)
- [ ] Privacy tab: "Log miss events" toggle ON by default
- [ ] Privacy tab: "Open events.jsonl in Finder" button works (opens Finder)
- [ ] Advanced tab: "Show experimental shortcuts" toggle OFF by default
- [ ] Toggle "Show experimental shortcuts" → close app → reopen → toggle still shows correct state (UserDefaults persists)
- [ ] Toggle "Log miss events" OFF → click in any app → check `~/Library/Application Support/SFlow/events.jsonl` is NOT appended to

---

## Task 6: Commit + update docs

- [ ] **Step 13: Commit Settings window**

```bash
git add SFlow/SettingsWindow.swift SFlow/AppDelegate.swift
git commit -m "feat(client): Settings window with Privacy + Advanced tabs"
```

- [ ] **Step 14: Update audit docs**

In `docs/audit-phase-1.md`, update execution sequence table:
- Sesja 3 Status: `⬜` → `🟢 done`
- Sub-cel 1.1 Status: `🔵 partial` → `🟡 in-progress` (fundament gotowy, filtr jeszcze nie)

```bash
git add docs/audit-phase-1.md docs/audit-phase-0.md
git commit -m "docs: session 3 complete — settings foundation"
```

---

## Self-Review Checklist

**Spec coverage:**
- ✅ SettingsWindow.swift with TabView + 3 tabs
- ✅ "Settings…" ⌘, in menu bar
- ✅ Privacy: logMisses + telemetry toggles + data buttons
- ✅ Advanced: showExperimental toggle + placeholder for Recent shortcuts
- ✅ EventLogger.logMiss respects logMisses
- ✅ RuleCache.showExperimental wired from UserDefaults at startup + live via NotificationCenter
- ✅ Persistencja przez restart

**No placeholders:** All code is complete and runnable.

**Type consistency:** 
- `EventLogger.defaultLogURL` used in PrivacyTab — it's `static let` in `EventLogger.swift`, accessible from SwiftUI.
- `RuleCache.showExperimental` is `var showExperimental: Bool` — AppDelegate accesses via `ruleCache?.showExperimental`.
- `SettingsWindowController.shared.show()` called from AppDelegate.

**Acceptance criteria:**
- [ ] Settings okno otwiera się z menu bar + skrótem ⌘,
- [ ] 3 tabs widoczne, navigation działa
- [ ] Privacy.logMisses toggle wpływa na EventLogger (test przechodzi)
- [ ] Advanced.showExperimental wpływa na RuleCache (live via NotificationCenter)
- [ ] Persistencja przez restart aplikacji
- [ ] Zero regresji w istniejących testach
