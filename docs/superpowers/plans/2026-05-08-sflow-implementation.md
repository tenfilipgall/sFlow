# SFlow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone macOS menu bar app (no Dock icon) that detects mouse clicks on UI elements with keyboard shortcuts and shows a 3-second toast near the cursor with the shortcut displayed.

**Architecture:** Pure Swift AppKit app. `CGEventTap` captures global left-mouse-down events. `AXUIElement` identifies the clicked element and walks up 6 ancestors. Three-layer shortcut lookup: (1) hardcoded 18-app rule database in `ShortcutRules`, (2) auto-parse shortcut from `kAXHelpAttribute` tooltip (works for any app with tooltip shortcuts), (3) `MenuBarIndex` — on each app switch, scans the active app's full menu bar and builds a title→shortcut map used as fallback for any unknown app. `ToastWindow` (NSPanel + NSVisualEffectView) renders the toast near the cursor and fades out after 3s. `EventLogger` appends each fired toast as a JSONL line to disk.

**Tech Stack:** Swift 5.9, AppKit, ApplicationServices, CoreGraphics, macOS 13.0+. Build tooling: xcodegen (via brew).

---

## File Map

| File | Responsibility |
|------|----------------|
| `project.yml` | xcodegen config — generates `SFlow.xcodeproj` |
| `SFlow/Info.plist` | LSUIElement, privacy descriptions, bundle metadata |
| `SFlow/main.swift` | NSApplication entry point |
| `SFlow/AppDelegate.swift` | NSStatusItem, toggle menu, permissions check, wires ClickWatcher |
| `SFlow/ShortcutEvent.swift` | Plain data struct passed from ClickWatcher to callers |
| `SFlow/ShortcutRules.swift` | `ClickRule` struct, 18-app rule database, AX Help parser |
| `SFlow/MenuBarIndex.swift` | Scans active app's menu bar on background queue; title→shortcut map for any app |
| `SFlow/MenuBarCache.swift` | Persists menu-index per app to JSON file; cache-busts on app version change |
| `SFlow/BundleStringsScanner.swift` | Reads app bundle .strings files offline; populates index before AX scan |
| `SFlow/ClickWatcher.swift` | CGEventTap, 4-layer AX lookup incl. universal heuristics, rate limiting |
| `SFlow/ToastWindow.swift` | NSPanel + NSVisualEffectView, fade animation, cursor positioning |
| `SFlow/EventLogger.swift` | Appends events to `~/Library/Application Support/SFlow/events.jsonl` |
| `SFlowTests/ShortcutRulesTests.swift` | Unit tests for `ShortcutRules.parseShortcut(from:)` incl. single-key patterns |
| `SFlowTests/EventLoggerTests.swift` | Unit tests for `EventLogger` file writing |
| `SFlowTests/MenuBarIndexTests.swift` | Unit tests for `MenuBarIndex.parseModifiers(_:)` |
| `SFlowTests/MenuBarCacheTests.swift` | Unit tests for cache read/write/invalidation |

---

### Task 1: Project Scaffold

**Files:**
- Create: `project.yml`
- Create: `SFlow/Info.plist`
- Create: `SFlow/main.swift` (stub)
- Create: `SFlowTests/.gitkeep`

- [ ] **Step 1: Install xcodegen**

```bash
brew install xcodegen
```

Expected: `xcodegen 2.x.x` installed.

- [ ] **Step 2: Create directory structure**

Working directory: `/Users/filip/Claude/Projects/Apps/SFlow`

```bash
mkdir -p SFlow SFlowTests
```

- [ ] **Step 3: Create `project.yml`**

```yaml
name: SFlow
options:
  bundleIdPrefix: com.filip
  deploymentTarget:
    macOS: "13.0"
  createIntermediateGroups: true
targets:
  SFlow:
    type: application
    platform: macOS
    sources: [SFlow]
    info:
      path: SFlow/Info.plist
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.filip.sflow
      SWIFT_VERSION: "5.9"
      CODE_SIGN_STYLE: Automatic
      ENABLE_HARDENED_RUNTIME: NO
      ENABLE_TESTABILITY: YES
  SFlowTests:
    type: bundle.unit-test
    platform: macOS
    sources: [SFlowTests]
    dependencies:
      - target: SFlow
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.filip.sflow-tests
      TEST_HOST: $(BUILT_PRODUCTS_DIR)/SFlow.app/Contents/MacOS/SFlow
      BUNDLE_LOADER: $(TEST_HOST)
      SWIFT_VERSION: "5.9"
```

- [ ] **Step 4: Create `SFlow/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.filip.sflow</string>
    <key>CFBundleName</key>
    <string>SFlow</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>SFlow reads UI element names to detect when you click something that has a keyboard shortcut.</string>
    <key>NSInputMonitoringUsageDescription</key>
    <string>SFlow monitors mouse clicks to detect when you click instead of using a keyboard shortcut.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 5: Create stub `SFlow/main.swift`**

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 6: Run xcodegen**

```bash
xcodegen generate
```

Expected output: `✓ Generated: SFlow.xcodeproj`

- [ ] **Step 7: Commit**

```bash
git init
git add project.yml SFlow/Info.plist SFlow/main.swift SFlow.xcodeproj SFlowTests
git commit -m "chore: scaffold SFlow xcode project"
```

---

### Task 2: ShortcutEvent (shared data type)

**Files:**
- Create: `SFlow/ShortcutEvent.swift`

- [ ] **Step 1: Create `SFlow/ShortcutEvent.swift`**

```swift
import Foundation

struct ShortcutEvent {
    let bundleId: String
    let shortcutId: String
    let keys: [String]
    let hint: String
    let mouseX: Double
    let mouseY: Double
}
```

- [ ] **Step 2: Build to verify no errors**

In Xcode: `⌘B`  
Or terminal: `xcodebuild -scheme SFlow -configuration Debug build 2>&1 | tail -5`  
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SFlow/ShortcutEvent.swift
git commit -m "feat: add ShortcutEvent data type"
```

---

### Task 3: EventLogger (TDD)

**Files:**
- Create: `SFlow/EventLogger.swift`
- Create: `SFlowTests/EventLoggerTests.swift`

- [ ] **Step 1: Write failing tests — create `SFlowTests/EventLoggerTests.swift`**

```swift
import XCTest
@testable import SFlow

final class EventLoggerTests: XCTestCase {
    private var tempDir: URL!
    private var logFile: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        logFile = tempDir.appendingPathComponent("events.jsonl")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_log_createsFileOnFirstWrite() {
        EventLogger.log(event: makeEvent(), to: logFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: logFile.path))
    }

    func test_log_writesValidJSONLine() throws {
        let event = makeEvent(bundleId: "com.test.app", shortcutId: "test-id",
                              keys: ["meta", "k"], hint: "Test", mouseX: 100, mouseY: 200)
        EventLogger.log(event: event, to: logFile)
        let content = try String(contentsOf: logFile, encoding: .utf8)
        XCTAssertTrue(content.hasSuffix("\n"))
        let line = content.trimmingCharacters(in: .newlines)
        let data = line.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["bundleId"] as? String, "com.test.app")
        XCTAssertEqual(json["shortcutId"] as? String, "test-id")
        XCTAssertEqual(json["keys"] as? [String], ["meta", "k"])
        XCTAssertEqual(json["hint"] as? String, "Test")
        XCTAssertEqual(json["mouseX"] as? Double, 100)
        XCTAssertEqual(json["mouseY"] as? Double, 200)
        XCTAssertNotNil(json["timestamp"])
    }

    func test_log_appendsMultipleLines() throws {
        EventLogger.log(event: makeEvent(shortcutId: "first"), to: logFile)
        EventLogger.log(event: makeEvent(shortcutId: "second"), to: logFile)
        let content = try String(contentsOf: logFile, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 2)
        let json0 = try JSONSerialization.jsonObject(with: lines[0].data(using: .utf8)!) as! [String: Any]
        let json1 = try JSONSerialization.jsonObject(with: lines[1].data(using: .utf8)!) as! [String: Any]
        XCTAssertEqual(json0["shortcutId"] as? String, "first")
        XCTAssertEqual(json1["shortcutId"] as? String, "second")
    }

    private func makeEvent(bundleId: String = "com.test", shortcutId: String = "test",
                           keys: [String] = ["meta", "k"], hint: String = "Test",
                           mouseX: Double = 0, mouseY: Double = 0) -> ShortcutEvent {
        ShortcutEvent(bundleId: bundleId, shortcutId: shortcutId,
                      keys: keys, hint: hint, mouseX: mouseX, mouseY: mouseY)
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL (EventLogger not implemented)**

In Xcode: `⌘U`  
Expected: build error "Use of unresolved identifier 'EventLogger'"

- [ ] **Step 3: Implement `SFlow/EventLogger.swift`**

```swift
import Foundation

enum EventLogger {
    static let defaultLogURL: URL = {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("SFlow")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("events.jsonl")
    }()

    static func log(event: ShortcutEvent) {
        log(event: event, to: defaultLogURL)
    }

    static func log(event: ShortcutEvent, to url: URL) {
        let formatter = ISO8601DateFormatter()
        let entry: [String: Any] = [
            "timestamp": formatter.string(from: Date()),
            "bundleId":  event.bundleId,
            "shortcutId": event.shortcutId,
            "keys":      event.keys,
            "hint":      event.hint,
            "mouseX":    event.mouseX,
            "mouseY":    event.mouseY,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: entry, options: .sortedKeys),
              let line = String(data: data, encoding: .utf8) else { return }
        let lineWithNewline = (line + "\n").data(using: .utf8)!

        if FileManager.default.fileExists(atPath: url.path) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            handle.seekToEndOfFile()
            handle.write(lineWithNewline)
            try? handle.close()
        } else {
            try? lineWithNewline.write(to: url)
        }
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

In Xcode: `⌘U`  
Expected: all 3 EventLoggerTests pass.

- [ ] **Step 5: Commit**

```bash
git add SFlow/EventLogger.swift SFlowTests/EventLoggerTests.swift
git commit -m "feat: add EventLogger with JSONL file writing"
```

---

### Task 4: ShortcutRules (TDD + rules database)

**Files:**
- Create: `SFlow/ShortcutRules.swift`
- Create: `SFlowTests/ShortcutRulesTests.swift`

- [ ] **Step 1: Write failing tests — create `SFlowTests/ShortcutRulesTests.swift`**

```swift
import XCTest
@testable import SFlow

final class ShortcutRulesTests: XCTestCase {

    func test_parseShortcut_singleModifierPlusLetter() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "⌘K"), ["meta", "k"])
    }

    func test_parseShortcut_twoModifiers() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "⌘⇧P"), ["meta", "shift", "p"])
    }

    func test_parseShortcut_threeModifiers() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "⌘⌥⇧F"), ["meta", "alt", "shift", "f"])
    }

    func test_parseShortcut_embeddedInText() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "Quick Find ⌘K"), ["meta", "k"])
    }

    func test_parseShortcut_noShortcut_returnsNil() {
        XCTAssertNil(ShortcutRules.parseShortcut(from: "No shortcut here"))
    }

    func test_parseShortcut_modifierAloneNoKey_returnsNil() {
        XCTAssertNil(ShortcutRules.parseShortcut(from: "⌘"))
    }

    func test_parseShortcut_number() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "⌘1"), ["meta", "1"])
    }

    func test_parseShortcut_ctrl() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "⌃`"), nil) // backtick not letter/number
    }

    // Raw single-char kAXHelp (strategy 2)
    func test_parseShortcut_rawSingleLetter() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "e"), ["e"])
    }

    func test_parseShortcut_rawSingleLetterUppercase() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "K"), ["k"])
    }

    func test_parseShortcut_singleDigit_doesNotFire() {
        XCTAssertNil(ShortcutRules.parseShortcut(from: "1"))
    }

    // Single-key patterns (strategy 3)
    func test_parseShortcut_parensSingleKey() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "Archive (E)"), ["e"])
    }

    func test_parseShortcut_bracketsSingleKey() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "Today [T]"), ["t"])
    }

    func test_parseShortcut_dashSingleKey() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "Reply — R"), ["r"])
    }

    func test_parseShortcut_singleKeyPreferModifierMatch() {
        // When both exist, modifier+key wins over single-key pattern
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "Search ⌘F (also F)"), ["meta", "f"])
    }

    func test_parseShortcut_midSentenceLetter_doesNotFire() {
        // "Archive" contains letters but no isolated single-key pattern
        XCTAssertNil(ShortcutRules.parseShortcut(from: "Archive your messages"))
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Expected: build error "Use of unresolved identifier 'ShortcutRules'"

- [ ] **Step 3: Implement `SFlow/ShortcutRules.swift`**

```swift
import ApplicationServices
import Foundation

struct ClickRule {
    let role: String?
    let subroleEquals: String?
    let descContains: String?
    let titleContains: String?
    let placeholderContains: String?
    let helpContains: String?
    let shortcutId: String
    let keys: [String]
    let hint: String

    init(_ role: String? = nil, sub: String? = nil, desc: String? = nil,
         title: String? = nil, ph: String? = nil, help: String? = nil,
         id: String, keys: [String], hint: String) {
        self.role = role; self.subroleEquals = sub
        self.descContains = desc; self.titleContains = title
        self.placeholderContains = ph; self.helpContains = help
        self.shortcutId = id; self.keys = keys; self.hint = hint
    }
}

enum ShortcutRules {

    // MARK: - Public API

    static func match(element: AXUIElement, bundleId: String) -> ClickRule? {
        guard let appRules = rules[bundleId] else { return nil }

        var roleRef: AnyObject?; var descRef: AnyObject?; var titleRef: AnyObject?
        var subroleRef: AnyObject?; var placeholderRef: AnyObject?; var helpRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef)
        AXUIElementCopyAttributeValue(element, kAXPlaceholderValueAttribute as CFString, &placeholderRef)
        AXUIElementCopyAttributeValue(element, kAXHelpAttribute as CFString, &helpRef)

        let role        = roleRef        as? String ?? ""
        let desc        = (descRef        as? String ?? "").lowercased()
        let title       = (titleRef       as? String ?? "").lowercased()
        let subrole     = subroleRef     as? String ?? ""
        let placeholder = (placeholderRef as? String ?? "").lowercased()
        let help        = (helpRef        as? String ?? "").lowercased()

        for rule in appRules {
            if let r = rule.role,               role        != r                          { continue }
            if let s = rule.subroleEquals,       subrole     != s                          { continue }
            if let d = rule.descContains,        !desc.contains(d.lowercased())            { continue }
            if let t = rule.titleContains,       !title.contains(t.lowercased())           { continue }
            if let p = rule.placeholderContains, !placeholder.contains(p.lowercased())     { continue }
            if let h = rule.helpContains,        !help.contains(h.lowercased())            { continue }
            return rule
        }
        return nil
    }

    /// Parses the first shortcut from arbitrary text. Two strategies:
    ///
    /// 1. Modifier + key: "Quick Find ⌘K" → ["meta", "k"]
    ///    Looks for ⌘⇧⌥⌃ symbols followed immediately by a letter/digit.
    ///
    /// 2. Single-key pattern: "Archive (E)" / "Today [T]" / "Reply — R"
    ///    Only triggers when the letter is isolated by parens, brackets, dash, or end-of-string.
    ///    This avoids false positives from normal sentences.
    static func parseShortcut(from text: String) -> [String]? {
        let modMap: [Character: String] = ["⌘": "meta", "⇧": "shift", "⌥": "alt", "⌃": "ctrl"]

        // Strategy 1: modifier symbol(s) + letter/digit
        var i = text.startIndex
        while i < text.endIndex {
            guard modMap[text[i]] != nil else { i = text.index(after: i); continue }
            var mods: [String] = []
            var j = i
            while j < text.endIndex, let m = modMap[text[j]] { mods.append(m); j = text.index(after: j) }
            guard j < text.endIndex else { break }
            let ch = text[j]
            guard ch.isLetter || ch.isNumber else { i = text.index(after: i); continue }
            return mods + [String(ch).lowercased()]
        }

        // Strategy 2: raw single-char help — kAXHelp contains exactly one letter
        // Safe because: (a) no app writes a 1-letter tooltip for non-shortcut purposes,
        // (b) ClickWatcher only calls this after confirming element is a clickable role.
        if text.count == 1, let ch = text.first, ch.isLetter {
            return [String(ch).lowercased()]
        }

        // Strategy 3: single-key patterns — (E), [E], — E, or trailing " E"
        // Pattern: optional whitespace + optional opening bracket/dash + space?
        //          + single uppercase letter + optional closing bracket/end
        let singleKeyPattern = #"[\(\[\-\s]([A-Z])[\)\]\s]?$"#
        if let regex = try? NSRegularExpression(pattern: singleKeyPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges > 1,
           let keyRange = Range(match.range(at: 1), in: text) {
            return [String(text[keyRange]).lowercased()]
        }

        return nil
    }

    // MARK: - Universal role-based rules (#4 — semantic heuristics)

    /// Role-based rules that apply to ANY app, regardless of bundle ID.
    /// Checked as a final fallback after app-specific rules and MenuBarIndex.
    static let universalRules: [ClickRule] = [
        // Search fields — ⌘F in virtually every native macOS app
        .init("AXTextField", sub: "AXSearchField",
              id: "universal-search", keys: ["meta", "f"], hint: "Search / Find"),
        .init(nil, sub: "AXSearchField",
              id: "universal-search", keys: ["meta", "f"], hint: "Search / Find"),
        // Back / Forward navigation buttons
        .init("AXButton", desc: "back",
              id: "universal-back", keys: ["meta", "arrowleft"], hint: "Go Back"),
        .init("AXButton", desc: "forward",
              id: "universal-forward", keys: ["meta", "arrowright"], hint: "Go Forward"),
        .init("AXButton", desc: "go back",
              id: "universal-back", keys: ["meta", "arrowleft"], hint: "Go Back"),
        .init("AXButton", desc: "go forward",
              id: "universal-forward", keys: ["meta", "arrowright"], hint: "Go Forward"),
        // Reload
        .init("AXButton", desc: "reload",
              id: "universal-reload", keys: ["meta", "r"], hint: "Reload"),
        .init("AXButton", desc: "refresh",
              id: "universal-reload", keys: ["meta", "r"], hint: "Reload"),
        // Close (⌘W) — button labelled "close" in any tab-based app
        .init("AXButton", desc: "close tab",
              id: "universal-close-tab", keys: ["meta", "w"], hint: "Close Tab"),
        // New document / window / tab
        .init("AXButton", desc: "new tab",
              id: "universal-new-tab", keys: ["meta", "t"], hint: "New Tab"),
        .init("AXButton", desc: "new window",
              id: "universal-new-window", keys: ["meta", "n"], hint: "New Window"),
        // Print
        .init("AXButton", desc: "print",
              id: "universal-print", keys: ["meta", "p"], hint: "Print"),
        // Share
        .init("AXButton", desc: "share",
              id: "universal-share", keys: ["meta", "shift", "i"], hint: "Share"),
    ]

    // MARK: - Rules Database

    static let rules: [String: [ClickRule]] = [

        // ── Slack ─────────────────────────────────────────────────────────
        "com.tinyspeck.slackmacgap": [
            .init("AXTextField", sub: "AXSearchField",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(ph: "jump to",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(ph: "find a conversation",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(ph: "search slack",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(desc: "search",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(desc: "jump to",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(desc: "find a conversation",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(desc: "quick switcher",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(title: "search",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(title: "jump to",
                  id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher"),
            .init(desc: "direct messages",
                  id: "slack-browse-dms", keys: ["meta","shift","k"], hint: "Browse DMs"),
            .init(title: "direct messages",
                  id: "slack-browse-dms", keys: ["meta","shift","k"], hint: "Browse DMs"),
            .init(desc: "dms",
                  id: "slack-browse-dms", keys: ["meta","shift","k"], hint: "Browse DMs"),
            .init(desc: "compose",
                  id: "slack-compose", keys: ["meta","n"], hint: "New Message"),
            .init(desc: "new message",
                  id: "slack-compose", keys: ["meta","n"], hint: "New Message"),
            .init(title: "compose",
                  id: "slack-compose", keys: ["meta","n"], hint: "New Message"),
            .init(title: "new message",
                  id: "slack-compose", keys: ["meta","n"], hint: "New Message"),
            .init(desc: "all unreads",
                  id: "slack-all-unreads", keys: ["meta","shift","a"], hint: "All Unreads"),
            .init(desc: "unreads",
                  id: "slack-all-unreads", keys: ["meta","shift","a"], hint: "All Unreads"),
            .init(title: "all unreads",
                  id: "slack-all-unreads", keys: ["meta","shift","a"], hint: "All Unreads"),
            .init(desc: "mentions",
                  id: "slack-mentions", keys: ["meta","shift","m"], hint: "Mentions & Reactions"),
            .init(desc: "activity",
                  id: "slack-mentions", keys: ["meta","shift","m"], hint: "Mentions & Reactions"),
            .init(desc: "notifications",
                  id: "slack-mentions", keys: ["meta","shift","m"], hint: "Mentions & Reactions"),
            .init(title: "mentions",
                  id: "slack-mentions", keys: ["meta","shift","m"], hint: "Mentions & Reactions"),
            .init(desc: "set a status",
                  id: "slack-set-status", keys: ["meta","shift","y"], hint: "Set Your Status"),
            .init(desc: "status",
                  id: "slack-set-status", keys: ["meta","shift","y"], hint: "Set Your Status"),
            .init(desc: "conversation details",
                  id: "slack-convo-details", keys: ["meta","shift","i"], hint: "Conversation Details"),
            .init(title: "conversation details",
                  id: "slack-convo-details", keys: ["meta","shift","i"], hint: "Conversation Details"),
            .init(desc: "saved items",
                  id: "slack-saved", keys: ["meta","shift","s"], hint: "Saved Items"),
            .init(title: "saved items",
                  id: "slack-saved", keys: ["meta","shift","s"], hint: "Saved Items"),
            .init(desc: "bookmarks",
                  id: "slack-saved", keys: ["meta","shift","s"], hint: "Saved Items"),
            .init(desc: "browse channels",
                  id: "slack-browse-channels", keys: ["meta","shift","e"], hint: "Browse Channels"),
            .init(title: "browse channels",
                  id: "slack-browse-channels", keys: ["meta","shift","e"], hint: "Browse Channels"),
        ],

        // ── Notion ────────────────────────────────────────────────────────
        "notion.id": [
            .init(desc: "search",
                  id: "notion-quick-find", keys: ["meta","k"], hint: "Quick Find"),
            .init(desc: "quick find",
                  id: "notion-quick-find", keys: ["meta","k"], hint: "Quick Find"),
            .init(title: "new page",
                  id: "notion-new-page", keys: ["meta","n"], hint: "New Page"),
            .init(desc: "sidebar",
                  id: "notion-toggle-sidebar", keys: ["meta","\\"], hint: "Toggle Sidebar"),
            .init(desc: "back",
                  id: "notion-go-back", keys: ["meta","arrowleft"], hint: "Go Back"),
            .init(desc: "forward",
                  id: "notion-go-forward", keys: ["meta","arrowright"], hint: "Go Forward"),
            .init(desc: "dark mode",
                  id: "notion-dark-mode", keys: ["meta","shift","l"], hint: "Toggle Dark/Light Mode"),
            .init(desc: "light mode",
                  id: "notion-dark-mode", keys: ["meta","shift","l"], hint: "Toggle Dark/Light Mode"),
        ],

        // ── Figma ─────────────────────────────────────────────────────────
        "com.figma.Desktop": [
            .init(desc: "search",
                  id: "figma-quick-actions", keys: ["meta","/"], hint: "Quick Actions"),
            .init(desc: "quick actions",
                  id: "figma-quick-actions", keys: ["meta","/"], hint: "Quick Actions"),
            .init(desc: "components",
                  id: "figma-quick-actions", keys: ["meta","/"], hint: "Quick Actions"),
            .init(desc: "layers",
                  id: "figma-layers-panel", keys: ["meta","alt","1"], hint: "Layers Panel"),
            .init(desc: "assets",
                  id: "figma-assets-panel", keys: ["meta","alt","2"], hint: "Assets Panel"),
        ],

        // ── VS Code ───────────────────────────────────────────────────────
        "com.microsoft.VSCode": [
            .init(desc: "command palette",
                  id: "vsc-palette", keys: ["meta","shift","p"], hint: "Command Palette"),
            .init(desc: "quick open",
                  id: "vsc-quick-open", keys: ["meta","p"], hint: "Quick Open File"),
            .init(desc: "explorer",
                  id: "vsc-explorer", keys: ["meta","shift","e"], hint: "Explorer Panel"),
            .init(desc: "search",
                  id: "vsc-find-in-files", keys: ["meta","shift","f"], hint: "Find in Files"),
            .init(desc: "source control",
                  id: "vsc-source-control", keys: ["meta","shift","g"], hint: "Source Control"),
            .init(desc: "terminal",
                  id: "vsc-terminal", keys: ["ctrl","`"], hint: "Toggle Terminal"),
            .init(desc: "extensions",
                  id: "vsc-extensions", keys: ["meta","shift","x"], hint: "Extensions"),
            .init(desc: "sidebar",
                  id: "vsc-sidebar", keys: ["meta","b"], hint: "Toggle Sidebar"),
        ],

        // ── Linear ────────────────────────────────────────────────────────
        "com.linear": [
            .init(desc: "search",
                  id: "linear-command-palette", keys: ["meta","k"], hint: "Command Palette"),
            .init(desc: "new issue",
                  id: "linear-new-issue", keys: ["meta","i"], hint: "New Issue"),
            .init(desc: "create issue",
                  id: "linear-new-issue", keys: ["meta","i"], hint: "New Issue"),
        ],

        // ── Claude ────────────────────────────────────────────────────────
        "com.anthropic.claudefordesktop": [
            .init("AXButton", desc: "send",
                  id: "claude-send", keys: ["meta","enter"], hint: "Send Message"),
            .init(title: "send",
                  id: "claude-send", keys: ["meta","enter"], hint: "Send Message"),
            .init("AXButton", desc: "new conversation",
                  id: "claude-new-chat", keys: ["meta","shift","o"], hint: "New Conversation"),
            .init("AXButton", desc: "new chat",
                  id: "claude-new-chat", keys: ["meta","shift","o"], hint: "New Conversation"),
            .init(title: "new conversation",
                  id: "claude-new-chat", keys: ["meta","shift","o"], hint: "New Conversation"),
            .init("AXButton", desc: "collapse sidebar",
                  id: "claude-toggle-sidebar", keys: ["meta","b"], hint: "Toggle Sidebar"),
            .init("AXButton", desc: "expand sidebar",
                  id: "claude-toggle-sidebar", keys: ["meta","b"], hint: "Toggle Sidebar"),
            .init("AXButton", desc: "toggle sidebar",
                  id: "claude-toggle-sidebar", keys: ["meta","b"], hint: "Toggle Sidebar"),
            .init("AXButton", desc: "settings",
                  id: "claude-settings", keys: ["meta",","], hint: "Settings"),
            .init(title: "settings",
                  id: "claude-settings", keys: ["meta",","], hint: "Settings"),
        ],

        // ── WhatsApp ──────────────────────────────────────────────────────
        "net.whatsapp.WhatsApp": [
            .init("AXButton", desc: "send",
                  id: "wa-send", keys: ["meta","enter"], hint: "Send Message"),
            .init(title: "send",
                  id: "wa-send", keys: ["meta","enter"], hint: "Send Message"),
            .init("AXButton", desc: "new chat",
                  id: "wa-new-chat", keys: ["meta","n"], hint: "New Message"),
            .init("AXButton", desc: "new message",
                  id: "wa-new-chat", keys: ["meta","n"], hint: "New Message"),
            .init(desc: "search",
                  id: "wa-search", keys: ["meta","f"], hint: "Search"),
            .init(desc: "mute",
                  id: "wa-mute", keys: ["meta","shift","m"], hint: "Mute Chat"),
            .init(title: "mute",
                  id: "wa-mute", keys: ["meta","shift","m"], hint: "Mute Chat"),
            .init(desc: "archive",
                  id: "wa-archive", keys: ["meta","shift","e"], hint: "Archive Chat"),
            .init(title: "archive",
                  id: "wa-archive", keys: ["meta","shift","e"], hint: "Archive Chat"),
            .init(desc: "new group",
                  id: "wa-new-group", keys: ["meta","shift","n"], hint: "New Group"),
            .init(title: "new group",
                  id: "wa-new-group", keys: ["meta","shift","n"], hint: "New Group"),
            .init(desc: "settings",
                  id: "wa-settings", keys: ["meta",","], hint: "Settings"),
        ],

        // ── Comet (Perplexity) ────────────────────────────────────────────
        "ai.perplexity.comet": [
            .init("AXTextField", desc: "address",
                  id: "comet-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init("AXTextField", desc: "search",
                  id: "comet-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init("AXButton", desc: "new tab",
                  id: "comet-new-tab", keys: ["meta","t"], hint: "New Tab"),
            .init(title: "new tab",
                  id: "comet-new-tab", keys: ["meta","t"], hint: "New Tab"),
            .init("AXButton", desc: "reload",
                  id: "comet-reload", keys: ["meta","r"], hint: "Reload"),
            .init("AXButton", desc: "back",
                  id: "comet-back", keys: ["meta","arrowleft"], hint: "Go Back"),
            .init("AXButton", desc: "forward",
                  id: "comet-forward", keys: ["meta","arrowright"], hint: "Go Forward"),
            .init("AXButton", desc: "close tab",
                  id: "comet-close-tab", keys: ["meta","w"], hint: "Close Tab"),
            .init(desc: "command bar",
                  id: "comet-command-bar", keys: ["meta","shift","a"], hint: "Command Bar"),
            .init(desc: "ai search",
                  id: "comet-command-bar", keys: ["meta","shift","a"], hint: "Command Bar"),
            .init(desc: "bookmark",
                  id: "comet-bookmark", keys: ["meta","d"], hint: "Bookmark Page"),
            .init(desc: "bookmarks bar",
                  id: "comet-bookmarks-bar", keys: ["meta","shift","b"], hint: "Toggle Bookmarks Bar"),
        ],

        // ── Chrome ────────────────────────────────────────────────────────
        "com.google.Chrome": [
            .init("AXTextField", desc: "address",
                  id: "chrome-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init("AXTextField", desc: "search",
                  id: "chrome-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init("AXButton", desc: "new tab",
                  id: "chrome-new-tab", keys: ["meta","t"], hint: "New Tab"),
        ],

        // ── Arc ───────────────────────────────────────────────────────────
        "company.thebrowser.Browser": [
            .init("AXTextField", desc: "address",
                  id: "arc-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init(desc: "search",
                  id: "arc-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init(desc: "new tab",
                  id: "arc-new-tab", keys: ["meta","t"], hint: "New Tab"),
        ],

        // ── Mail ──────────────────────────────────────────────────────────
        "com.apple.mail": [
            .init(desc: "compose",
                  id: "mail-compose", keys: ["meta","n"], hint: "New Message"),
            .init(desc: "new message",
                  id: "mail-compose", keys: ["meta","n"], hint: "New Message"),
            .init(title: "compose",
                  id: "mail-compose", keys: ["meta","n"], hint: "New Message"),
            .init(desc: "reply",
                  id: "mail-reply", keys: ["meta","r"], hint: "Reply"),
            .init(title: "reply",
                  id: "mail-reply", keys: ["meta","r"], hint: "Reply"),
            .init(desc: "reply all",
                  id: "mail-reply-all", keys: ["meta","shift","r"], hint: "Reply All"),
            .init(desc: "forward",
                  id: "mail-forward", keys: ["meta","shift","f"], hint: "Forward"),
            .init(desc: "archive",
                  id: "mail-archive", keys: ["ctrl","meta","a"], hint: "Archive"),
            .init("AXTextField", desc: "search",
                  id: "mail-search", keys: ["meta","alt","f"], hint: "Search Mailbox"),
        ],

        // ── Safari ────────────────────────────────────────────────────────
        "com.apple.Safari": [
            .init("AXTextField", desc: "address",
                  id: "safari-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init("AXTextField", desc: "search",
                  id: "safari-address-bar", keys: ["meta","l"], hint: "Focus Address Bar"),
            .init(desc: "new tab",
                  id: "safari-new-tab", keys: ["meta","t"], hint: "New Tab"),
            .init(title: "new tab",
                  id: "safari-new-tab", keys: ["meta","t"], hint: "New Tab"),
            .init(desc: "reload",
                  id: "safari-reload", keys: ["meta","r"], hint: "Reload Page"),
            .init(desc: "back",
                  id: "safari-back", keys: ["meta","arrowleft"], hint: "Go Back"),
            .init(desc: "forward",
                  id: "safari-forward", keys: ["meta","arrowright"], hint: "Go Forward"),
            .init(desc: "show sidebar",
                  id: "safari-sidebar", keys: ["meta","shift","l"], hint: "Toggle Sidebar"),
        ],

        // ── Xcode ─────────────────────────────────────────────────────────
        "com.apple.dt.Xcode": [
            .init(desc: "search",
                  id: "xcode-find", keys: ["meta","f"], hint: "Find in File"),
            .init(desc: "navigator",
                  id: "xcode-navigator", keys: ["meta","1"], hint: "Show Navigator"),
            .init(desc: "debug area",
                  id: "xcode-debug-area", keys: ["meta","shift","y"], hint: "Toggle Debug Area"),
            .init(desc: "inspector",
                  id: "xcode-inspector", keys: ["meta","alt","0"], hint: "Hide/Show Inspector"),
        ],

        // ── Terminal ──────────────────────────────────────────────────────
        "com.apple.Terminal": [
            .init("AXTextField", sub: "AXSearchField", ph: "search",
                  id: "terminal-find", keys: ["meta","f"], hint: "Find in Output"),
            .init(desc: "find",
                  id: "terminal-find", keys: ["meta","f"], hint: "Find in Output"),
            .init("AXButton", desc: "new tab",
                  id: "terminal-new-tab", keys: ["meta","t"], hint: "New Tab"),
            .init(title: "new tab",
                  id: "terminal-new-tab", keys: ["meta","t"], hint: "New Tab"),
            .init("AXButton", desc: "new window",
                  id: "terminal-new-window", keys: ["meta","n"], hint: "New Window"),
            .init(desc: "clear",
                  id: "terminal-clear", keys: ["meta","k"], hint: "Clear Screen"),
        ],

        // ── Finder ────────────────────────────────────────────────────────
        "com.apple.finder": [
            .init("AXTextField", sub: "AXSearchField",
                  id: "finder-search", keys: ["meta","f"], hint: "Search"),
            .init(desc: "search",
                  id: "finder-search", keys: ["meta","f"], hint: "Search"),
            .init("AXButton", desc: "back",
                  id: "finder-back", keys: ["meta","["], hint: "Go Back"),
            .init(title: "back",
                  id: "finder-back", keys: ["meta","["], hint: "Go Back"),
            .init("AXButton", desc: "forward",
                  id: "finder-forward", keys: ["meta","]"], hint: "Go Forward"),
            .init(title: "forward",
                  id: "finder-forward", keys: ["meta","]"], hint: "Go Forward"),
            .init("AXButton", desc: "new folder",
                  id: "finder-new-folder", keys: ["meta","shift","n"], hint: "New Folder"),
            .init(title: "new folder",
                  id: "finder-new-folder", keys: ["meta","shift","n"], hint: "New Folder"),
            .init(desc: "as icons",
                  id: "finder-icon-view", keys: ["meta","1"], hint: "Icon View"),
            .init(desc: "as list",
                  id: "finder-list-view", keys: ["meta","2"], hint: "List View"),
            .init(desc: "as columns",
                  id: "finder-column-view", keys: ["meta","3"], hint: "Column View"),
            .init(desc: "as gallery",
                  id: "finder-gallery-view", keys: ["meta","4"], hint: "Gallery View"),
        ],

        // ── Notion Calendar ───────────────────────────────────────────────
        "com.cron.electron": [
            .init("AXTextField", sub: "AXSearchField",
                  id: "notion-cal-command-bar", keys: ["meta","k"], hint: "Command Bar"),
            .init(desc: "search",
                  id: "notion-cal-command-bar", keys: ["meta","k"], hint: "Command Bar"),
            .init(desc: "command bar",
                  id: "notion-cal-command-bar", keys: ["meta","k"], hint: "Command Bar"),
            .init(desc: "today",
                  id: "notion-cal-today", keys: ["t"], hint: "Go to Today"),
            .init(title: "today",
                  id: "notion-cal-today", keys: ["t"], hint: "Go to Today"),
            .init(desc: "new event",
                  id: "notion-cal-new-event", keys: ["c"], hint: "New Event"),
            .init(title: "new event",
                  id: "notion-cal-new-event", keys: ["c"], hint: "New Event"),
            .init(desc: "create event",
                  id: "notion-cal-new-event", keys: ["c"], hint: "New Event"),
        ],

        // ── Notion Mail ───────────────────────────────────────────────────
        "notion.mail.id": [
            .init(desc: "compose",
                  id: "notion-mail-compose", keys: ["c"], hint: "Compose"),
            .init(title: "compose",
                  id: "notion-mail-compose", keys: ["c"], hint: "Compose"),
            .init(desc: "new email",
                  id: "notion-mail-compose", keys: ["c"], hint: "Compose"),
            .init("AXButton", desc: "send",
                  id: "notion-mail-send", keys: ["meta","enter"], hint: "Send"),
            .init(title: "send",
                  id: "notion-mail-send", keys: ["meta","enter"], hint: "Send"),
            .init(desc: "archive",
                  id: "notion-mail-archive", keys: ["e"], hint: "Archive"),
            .init(title: "archive",
                  id: "notion-mail-archive", keys: ["e"], hint: "Archive"),
            .init(desc: "search",
                  id: "notion-mail-search", keys: ["meta","k"], hint: "Command Palette"),
            .init(desc: "command palette",
                  id: "notion-mail-search", keys: ["meta","k"], hint: "Command Palette"),
            .init(desc: "sidebar",
                  id: "notion-mail-sidebar", keys: ["meta","\\"], hint: "Toggle Sidebar"),
            .init(title: "sidebar",
                  id: "notion-mail-sidebar", keys: ["meta","\\"], hint: "Toggle Sidebar"),
        ],

        // ── Spotify ───────────────────────────────────────────────────────
        "com.spotify.client": [
            .init("AXTextField", sub: "AXSearchField", ph: "search",
                  id: "spotify-search", keys: ["meta","l"], hint: "Search"),
            .init(desc: "search",
                  id: "spotify-search", keys: ["meta","l"], hint: "Search"),
            .init(desc: "play",
                  id: "spotify-play-pause", keys: ["space"], hint: "Play / Pause"),
            .init(desc: "pause",
                  id: "spotify-play-pause", keys: ["space"], hint: "Play / Pause"),
            .init(desc: "next",
                  id: "spotify-next", keys: ["meta","arrowright"], hint: "Next Track"),
            .init(desc: "skip to next",
                  id: "spotify-next", keys: ["meta","arrowright"], hint: "Next Track"),
            .init(desc: "previous",
                  id: "spotify-prev", keys: ["meta","arrowleft"], hint: "Previous Track"),
            .init(desc: "skip to previous",
                  id: "spotify-prev", keys: ["meta","arrowleft"], hint: "Previous Track"),
        ],
    ]
}
```

- [ ] **Step 4: Run tests — expect PASS**

In Xcode: `⌘U`  
Expected: all 8 ShortcutRulesTests pass.

- [ ] **Step 5: Commit**

```bash
git add SFlow/ShortcutRules.swift SFlowTests/ShortcutRulesTests.swift
git commit -m "feat: add ShortcutRules with 18-app database, AX Help parser, and universal role heuristics"
```

---

### Task 4b: BundleStringsScanner (#3 — offline bundle scan)

**Files:**
- Create: `SFlow/BundleStringsScanner.swift`

**Co robi:** Czyta `Contents/Resources/en.lproj/MainMenu.strings` z bundla aktywnej apki — zwykły plik tekstowy na dysku, zero IPC. Parsuje pary klucz=wartość i wyciąga skróty z komentarzy/metadanych. Wywoływany przez `MenuBarWatcher` przy każdym app-switch, *zanim* zacznie się AX skan — daje natychmiastowy wstępny cache.

Format pliku `.strings`:
```
/* Menu item title */
"New Message" = "New Message";
/* Keyboard shortcut: cmd+n */
```

Niestety `.strings` rzadko zawierają same skróty wprost — częściej ich wartość to po prostu przetłumaczona nazwa. Dlatego `BundleStringsScanner` robi dwie rzeczy:
1. Wyciąga nazwy menu itemów (do fuzzy match z MenuBarIndex)
2. Szuka komentarzy zawierających "shortcut", "key", "hotkey" i parsuje je

- [ ] **Step 1: Create `SFlow/BundleStringsScanner.swift`**

```swift
import Foundation
import AppKit

enum BundleStringsScanner {

    /// Scans the app bundle's MainMenu.strings and extracts any shortcut hints found in comments.
    /// Returns a dict of lowercased title → MenuBarEntry, to be merged into MenuBarCache.
    static func scan(app: NSRunningApplication) -> [String: MenuBarEntry] {
        guard let bundleURL = app.bundleURL else { return [:] }

        // Try multiple localization directories
        let lprojs = ["en.lproj", "Base.lproj", "English.lproj"]
        let candidates = ["MainMenu.strings", "Localizable.strings", "Actions.strings"]

        var result: [String: MenuBarEntry] = [:]
        for lproj in lprojs {
            for candidate in candidates {
                let url = bundleURL
                    .appendingPathComponent("Contents/Resources")
                    .appendingPathComponent(lproj)
                    .appendingPathComponent(candidate)
                if let found = parseStringsFile(at: url) {
                    result.merge(found) { existing, _ in existing }
                }
            }
        }
        return result
    }

    // MARK: - Internal

    private static func parseStringsFile(at url: URL) -> [String: MenuBarEntry]? {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var result: [String: MenuBarEntry] = [:]
        var lastComment = ""

        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Capture comments: /* ... */
            if trimmed.hasPrefix("/*"), trimmed.hasSuffix("*/") {
                lastComment = String(trimmed.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
                continue
            }

            // Parse key = value; lines
            guard trimmed.contains(" = "),
                  let eqRange = trimmed.range(of: " = ") else { lastComment = ""; continue }

            let key = String(trimmed[..<eqRange.lowerBound])
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                .lowercased()

            // Look for shortcut info in the comment above this line
            if !lastComment.isEmpty,
               let keys = extractShortcutFromComment(lastComment) {
                result[key] = MenuBarEntry(keys: keys, hint: key)
            }
            lastComment = ""
        }
        return result.isEmpty ? nil : result
    }

    /// Extracts a shortcut from comment strings like:
    /// "Keyboard shortcut: cmd+n", "key: ⌘N", "hotkey: CmdOrCtrl+K"
    private static func extractShortcutFromComment(_ comment: String) -> [String]? {
        let lower = comment.lowercased()
        guard lower.contains("shortcut") || lower.contains("hotkey") ||
              lower.contains("key:") || lower.contains("accelerator") else { return nil }

        // Try parsing Unicode modifier symbols first
        if let keys = ShortcutRules.parseShortcut(from: comment) { return keys }

        // Try Electron-style: CmdOrCtrl+K, Ctrl+Shift+F
        let electronPattern = #"(?:CmdOrCtrl|Cmd|Command|Ctrl|Control|Shift|Alt|Option)\+[A-Za-z]"#
        if let regex = try? NSRegularExpression(pattern: electronPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: comment, range: NSRange(comment.startIndex..., in: comment)),
           let range = Range(match.range, in: comment) {
            return parseElectronAccelerator(String(comment[range]))
        }
        return nil
    }

    private static func parseElectronAccelerator(_ acc: String) -> [String] {
        let parts = acc.components(separatedBy: "+")
        return parts.compactMap { part in
            switch part.lowercased() {
            case "cmdorctrl", "cmd", "command": return "meta"
            case "ctrl", "control":             return "ctrl"
            case "shift":                       return "shift"
            case "alt", "option":               return "alt"
            default: return part.count == 1 ? part.lowercased() : nil
            }
        }
    }
}
```

- [ ] **Step 2: Wire into `MenuBarWatcher.loadOrScan`**

In `MenuBarIndex.swift`, update the `loadOrScan` method to run `BundleStringsScanner` first:

```swift
private func loadOrScan(app: NSRunningApplication) {
    guard let bundleId = app.bundleIdentifier else { return }
    let version = appVersion(app) ?? "unknown"

    // 1. Cache hit — instant
    if let cached = MenuBarCache.load(bundleId: bundleId, version: version) {
        DispatchQueue.main.async { [weak self] in
            self?.currentIndex = MenuBarIndex(from: cached)
        }
        return
    }

    // 2. Cache miss — run bundle scan + AX scan on background queue
    queue.async { [weak self] in
        // Fast: read .strings files from disk (no IPC)
        let bundleEntries = BundleStringsScanner.scan(app: app)

        // Set partial index immediately so early clicks benefit
        if !bundleEntries.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.currentIndex = MenuBarIndex(from: bundleEntries)
            }
        }

        // Slow: full AX menu scan
        var index = MenuBarIndex(from: bundleEntries)
        index.build(for: app)  // merges on top of bundle entries
        MenuBarCache.save(bundleId: bundleId, version: version, entries: index.allEntries)
        DispatchQueue.main.async { [weak self] in
            self?.currentIndex = index
        }
    }
}
```

- [ ] **Step 3: Add `merge` to `MenuBarIndex`**

Add to `MenuBarIndex` struct:

```swift
mutating func merge(_ other: [String: MenuBarEntry]) {
    for (k, v) in other where titleMap[k] == nil {
        titleMap[k] = v  // don't overwrite AX results with bundle guesses
    }
}
```

Update `build(for:)` to use `merge` so bundle entries aren't overwritten:

```swift
// Inside scanMenu, replace direct insert with merge-aware insert:
if titleMap[title.lowercased()] == nil {  // don't overwrite existing
    insert(title: title, keys: keys)
}
```

- [ ] **Step 4: Build to verify no errors**

`⌘B` — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add SFlow/BundleStringsScanner.swift SFlow/MenuBarIndex.swift
git commit -m "feat: add BundleStringsScanner for offline shortcut extraction from app bundle"
```

---

### Task 5: MenuBarIndex (auto-discovery for any app)

**Files:**
- Create: `SFlow/MenuBarIndex.swift`
- Create: `SFlowTests/MenuBarIndexTests.swift`

**Co robi:** Kiedy użytkownik przełącza się do dowolnej apki, `MenuBarIndex` skanuje jej pasek menu przez AX API i buduje słownik `słowo_kluczowe → (keys, hint)`. Gdy `ClickWatcher` nie znajdzie skrótu przez hardcoded rules ani kAXHelpAttribute, pyta `MenuBarIndex` czy element opisem/tytułem pasuje do któregoś menu item. Działa dla **wszystkich natywnych apek macOS** automatycznie.

- [ ] **Step 1: Write failing tests — create `SFlowTests/MenuBarIndexTests.swift`**

```swift
import XCTest
@testable import SFlow

final class MenuBarIndexTests: XCTestCase {

    func test_parseModifiers_commandOnly() {
        XCTAssertEqual(MenuBarIndex.parseModifiers(rawMods: 8), ["meta"])
    }

    func test_parseModifiers_commandShift() {
        // rawMods: bit 3 (0x08) absent = cmd, bit 0 (0x01) set = shift
        // cmd is present when bit 3 is NOT set: rawMods & 0x08 == 0
        // shift: rawMods & 0x01 != 0 → rawMods = 1 (shift only, no cmd)
        // cmd+shift: rawMods = 1 (shift bit set, cmd bit NOT set → cmd included)
        let mods = MenuBarIndex.parseModifiers(rawMods: 1)
        XCTAssertTrue(mods.contains("meta"))
        XCTAssertTrue(mods.contains("shift"))
    }

    func test_parseModifiers_alt() {
        // alt: bit 1 (0x02) set; cmd still included (bit 3 not set unless rawMods >= 8)
        let mods = MenuBarIndex.parseModifiers(rawMods: 2)
        XCTAssertTrue(mods.contains("alt"))
        XCTAssertTrue(mods.contains("meta"))
    }

    func test_parseModifiers_ctrl() {
        // ctrl: bit 2 (0x04); cmd included
        let mods = MenuBarIndex.parseModifiers(rawMods: 4)
        XCTAssertTrue(mods.contains("ctrl"))
        XCTAssertTrue(mods.contains("meta"))
    }

    func test_lookup_exactTitle() {
        var index = MenuBarIndex()
        index.insert(title: "New Message", keys: ["meta", "n"])
        let result = index.lookup(query: "new message")
        XCTAssertEqual(result?.keys, ["meta", "n"])
    }

    func test_lookup_partialTitle() {
        var index = MenuBarIndex()
        index.insert(title: "Find in Files", keys: ["meta", "shift", "f"])
        let result = index.lookup(query: "find")
        XCTAssertEqual(result?.keys, ["meta", "shift", "f"])
    }

    func test_lookup_noMatch_returnsNil() {
        var index = MenuBarIndex()
        index.insert(title: "New Message", keys: ["meta", "n"])
        XCTAssertNil(index.lookup(query: "archive"))
    }

    func test_lookup_emptyQuery_returnsNil() {
        var index = MenuBarIndex()
        index.insert(title: "New", keys: ["meta", "n"])
        XCTAssertNil(index.lookup(query: ""))
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Expected: build error "Use of unresolved identifier 'MenuBarIndex'"

- [ ] **Step 3: Implement `SFlow/MenuBarIndex.swift`**

```swift
import AppKit
import ApplicationServices

struct MenuBarEntry {
    let keys: [String]
    let hint: String
}

struct MenuBarIndex {
    private var titleMap: [String: MenuBarEntry] = [:]

    // MARK: - Build index for a running app

    /// Scans the full menu bar of the given app and populates the index.
    mutating func build(for app: NSRunningApplication) {
        titleMap.removeAll()
        guard let pid = app.processIdentifier as pid_t? else { return }
        let axApp = AXUIElementCreateApplication(pid)
        var menuBarRef: AnyObject?
        guard AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString,
                                            &menuBarRef) == .success,
              let menuBar = menuBarRef else { return }
        scanMenu(menuBar as! AXUIElement, depth: 0)
    }

    private mutating func scanMenu(_ element: AXUIElement, depth: Int) {
        guard depth < 4 else { return }
        var childrenRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString,
                                            &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return }

        for child in children {
            var roleRef: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            let role = roleRef as? String ?? ""

            if role == "AXMenuItem" {
                var titleRef: AnyObject?
                var cmdCharRef: AnyObject?
                var cmdModsRef: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef)
                AXUIElementCopyAttributeValue(child, kAXMenuItemCmdCharAttribute as CFString, &cmdCharRef)
                AXUIElementCopyAttributeValue(child, kAXMenuItemCmdModifiersAttribute as CFString, &cmdModsRef)

                if let title = titleRef as? String, !title.isEmpty,
                   let cmdChar = (cmdCharRef as? String)?.lowercased(), !cmdChar.isEmpty {
                    let rawMods = (cmdModsRef as? Int) ?? 0
                    let mods = Self.parseModifiers(rawMods: rawMods)
                    let keys = mods + [cmdChar]
                    insert(title: title, keys: keys)
                }
            }
            // Recurse into menus and menu items that have submenus
            scanMenu(child, depth: depth + 1)
        }
    }

    // MARK: - Lookup

    /// Returns the shortcut entry whose title contains `query` (case-insensitive).
    /// Query must be at least 3 characters to avoid false positives.
    func lookup(query: String) -> MenuBarEntry? {
        guard query.count >= 3 else { return nil }
        let q = query.lowercased()
        // Exact match first
        if let entry = titleMap[q] { return entry }
        // Partial match: find a title that contains the query
        return titleMap.first(where: { $0.key.contains(q) })?.value
    }

    // MARK: - Internal helpers

    mutating func insert(title: String, keys: [String]) {
        titleMap[title.lowercased()] = MenuBarEntry(keys: keys, hint: title)
    }

    /// Converts raw AXMenuItemCmdModifiers bitmask to modifier key array.
    /// Bit 3 (0x08) NOT set → cmd included. Bit 0 = shift, bit 1 = alt, bit 2 = ctrl.
    static func parseModifiers(rawMods: Int) -> [String] {
        var mods: [String] = []
        if rawMods & 0x08 == 0 { mods.append("meta") }
        if rawMods & 0x01 != 0 { mods.append("shift") }
        if rawMods & 0x02 != 0 { mods.append("alt") }
        if rawMods & 0x04 != 0 { mods.append("ctrl") }
        return mods
    }
}

// MARK: - App-switch watcher

final class MenuBarWatcher {
    private(set) var currentIndex = MenuBarIndex()
    private var observer: Any?

    init() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication else { return }
            self?.currentIndex.build(for: app)
        }
        // Scan the currently active app immediately
        if let current = NSWorkspace.shared.frontmostApplication {
            currentIndex.build(for: current)
        }
    }

    deinit {
        if let obs = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

In Xcode: `⌘U`  
Expected: all 8 MenuBarIndexTests pass.

- [ ] **Step 5: Commit**

```bash
git add SFlow/MenuBarIndex.swift SFlowTests/MenuBarIndexTests.swift
git commit -m "feat: add MenuBarIndex for automatic shortcut discovery in any app"
```

---

### Task 5b: MenuBarCache (persistent JSON cache)

**Files:**
- Create: `SFlow/MenuBarCache.swift`
- Create: `SFlowTests/MenuBarCacheTests.swift`

**Co robi:** Przy pierwszym wejściu do danej apki skanuje jej menu i zapisuje wynik do `menu-cache.json`. Przy kolejnych wejściach do tej samej apki (ta sama wersja) ładuje z pliku — zero lagu. Jeśli apka się zaktualizowała, re-skanuje i nadpisuje cache.

- [ ] **Step 1: Write failing tests — create `SFlowTests/MenuBarCacheTests.swift`**

```swift
import XCTest
@testable import SFlow

final class MenuBarCacheTests: XCTestCase {
    private var tempFile: URL!

    override func setUp() {
        super.setUp()
        tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFile)
        super.tearDown()
    }

    func test_saveAndLoad_roundTrip() throws {
        let entries = ["new message": MenuBarEntry(keys: ["meta","n"], hint: "New Message"),
                       "reply":       MenuBarEntry(keys: ["meta","r"], hint: "Reply")]
        MenuBarCache.save(bundleId: "com.test.app", version: "1.0",
                          entries: entries, to: tempFile)
        let loaded = MenuBarCache.load(bundleId: "com.test.app", version: "1.0", from: tempFile)
        XCTAssertEqual(loaded?["new message"]?.keys, ["meta","n"])
        XCTAssertEqual(loaded?["reply"]?.hint, "Reply")
    }

    func test_load_wrongVersion_returnsNil() {
        let entries = ["new message": MenuBarEntry(keys: ["meta","n"], hint: "New Message")]
        MenuBarCache.save(bundleId: "com.test.app", version: "1.0",
                          entries: entries, to: tempFile)
        let loaded = MenuBarCache.load(bundleId: "com.test.app", version: "2.0", from: tempFile)
        XCTAssertNil(loaded)
    }

    func test_load_missingFile_returnsNil() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist.json")
        XCTAssertNil(MenuBarCache.load(bundleId: "com.test.app", version: "1.0", from: url))
    }

    func test_load_differentBundleId_returnsNil() {
        let entries = ["search": MenuBarEntry(keys: ["meta","f"], hint: "Find")]
        MenuBarCache.save(bundleId: "com.app.one", version: "1.0",
                          entries: entries, to: tempFile)
        let loaded = MenuBarCache.load(bundleId: "com.app.two", version: "1.0", from: tempFile)
        XCTAssertNil(loaded)
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Expected: build error "Use of unresolved identifier 'MenuBarCache'"

- [ ] **Step 3: Implement `SFlow/MenuBarCache.swift`**

```swift
import Foundation

enum MenuBarCache {
    static let defaultCacheURL: URL = {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("SFlow")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("menu-cache.json")
    }()

    static func load(bundleId: String, version: String) -> [String: MenuBarEntry]? {
        load(bundleId: bundleId, version: version, from: defaultCacheURL)
    }

    static func save(bundleId: String, version: String, entries: [String: MenuBarEntry]) {
        save(bundleId: bundleId, version: version, entries: entries, to: defaultCacheURL)
    }

    static func load(bundleId: String, version: String, from url: URL) -> [String: MenuBarEntry]? {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let appData = root[bundleId] as? [String: Any],
              let cachedVersion = appData["version"] as? String,
              cachedVersion == version,
              let entriesRaw = appData["entries"] as? [String: [String: Any]] else { return nil }

        var result: [String: MenuBarEntry] = [:]
        for (title, raw) in entriesRaw {
            guard let keys = raw["keys"] as? [String],
                  let hint = raw["hint"] as? String else { continue }
            result[title] = MenuBarEntry(keys: keys, hint: hint)
        }
        return result
    }

    static func save(bundleId: String, version: String,
                     entries: [String: MenuBarEntry], to url: URL) {
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = existing
        }
        var entriesRaw: [String: [String: Any]] = [:]
        for (title, entry) in entries {
            entriesRaw[title] = ["keys": entry.keys, "hint": entry.hint]
        }
        root[bundleId] = ["version": version, "entries": entriesRaw]
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: .prettyPrinted) else { return }
        try? data.write(to: url)
    }
}
```

- [ ] **Step 4: Update `MenuBarIndex.swift` — add `allEntries`, `init(from:)`, background scan with cache**

Add to `MenuBarIndex` struct (after existing `insert` method):

```swift
var allEntries: [String: MenuBarEntry] { titleMap }

init(from entries: [String: MenuBarEntry]) {
    self.titleMap = entries
}
```

Replace the `MenuBarWatcher` class body with this version:

```swift
final class MenuBarWatcher {
    private(set) var currentIndex = MenuBarIndex()
    private var observer: Any?
    private let queue = DispatchQueue(label: "com.filip.sflow.menubar", qos: .utility)

    init() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication else { return }
            self?.loadOrScan(app: app)
        }
        if let current = NSWorkspace.shared.frontmostApplication {
            loadOrScan(app: current)
        }
    }

    private func loadOrScan(app: NSRunningApplication) {
        guard let bundleId = app.bundleIdentifier else { return }
        let version = appVersion(app) ?? "unknown"

        if let cached = MenuBarCache.load(bundleId: bundleId, version: version) {
            DispatchQueue.main.async { [weak self] in
                self?.currentIndex = MenuBarIndex(from: cached)
            }
            return
        }

        queue.async { [weak self] in
            var index = MenuBarIndex()
            index.build(for: app)
            MenuBarCache.save(bundleId: bundleId, version: version, entries: index.allEntries)
            DispatchQueue.main.async { [weak self] in
                self?.currentIndex = index
            }
        }
    }

    private func appVersion(_ app: NSRunningApplication) -> String? {
        guard let url = app.bundleURL else { return nil }
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        return (NSDictionary(contentsOf: plistURL))?["CFBundleVersion"] as? String
    }

    deinit {
        if let obs = observer { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
    }
}
```

- [ ] **Step 5: Run all tests — expect PASS**

`⌘U` — Expected: all tests pass including MenuBarCacheTests.

- [ ] **Step 6: Commit**

```bash
git add SFlow/MenuBarCache.swift SFlowTests/MenuBarCacheTests.swift SFlow/MenuBarIndex.swift
git commit -m "feat: add MenuBarCache — persistent per-app shortcut index with version invalidation"
```

---

### Task 6: ToastWindow

**Files:**
- Create: `SFlow/ToastWindow.swift`

- [ ] **Step 1: Create `SFlow/ToastWindow.swift`**

```swift
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

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        alphaValue = 0

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
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            animator().alphaValue = 1.0
        } completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) { [weak self] in
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.15
                    self?.animator().alphaValue = 0
                } completionHandler: {
                    self?.orderOut(nil)
                    if ToastWindow.current === self { ToastWindow.current = nil }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify no errors**

`⌘B` — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SFlow/ToastWindow.swift
git commit -m "feat: add ToastWindow with NSVisualEffectView and fade animation"
```

---

### Task 7: ClickWatcher

**Files:**
- Create: `SFlow/ClickWatcher.swift`

**Trzy warstwy lookup:**
1. Hardcoded rules (`ShortcutRules.match`) — 18 apek
2. kAXHelpAttribute auto-parse — dowolna apka z tooltipem ze skrótem
3. `MenuBarWatcher.currentIndex.lookup` — dowolna natywna apka macOS (fuzzy match tytułu elementu do tytułu menu item)

- [ ] **Step 1: Create `SFlow/ClickWatcher.swift`**

```swift
import AppKit
import CoreGraphics
import ApplicationServices

private var sharedWatcher: ClickWatcher?

final class ClickWatcher {
    typealias Handler = (ShortcutEvent) -> Void

    private let onEvent: Handler
    private let menuBarWatcher = MenuBarWatcher()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastShortcutId: String = ""
    private var lastShortcutTime: Date = .distantPast

    init(onEvent: @escaping Handler) {
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
        guard let tap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func handleMouseDown() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              let bundleId  = frontmost.bundleIdentifier else { return }

        let nsLoc   = NSEvent.mouseLocation
        let screenH = NSScreen.screens
            .first(where: { NSMouseInRect(nsLoc, $0.frame, false) })?
            .frame.maxY ?? (NSScreen.main?.frame.height ?? 900)
        let axX = Float(nsLoc.x)
        let axY = Float(screenH - nsLoc.y)

        let axApp = AXUIElementCreateApplication(frontmost.processIdentifier)
        var elemRef: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(axApp, axX, axY, &elemRef)

        if result == .success, let element = elemRef {
            var current = element
            for _ in 0..<6 {
                // Layer 1: hardcoded rules
                if let rule = ShortcutRules.match(element: current, bundleId: bundleId) {
                    emit(bundleId: bundleId, shortcutId: rule.shortcutId,
                         keys: rule.keys, hint: rule.hint, loc: nsLoc)
                    return
                }
                // Layer 2: kAXHelpAttribute auto-parse
                // Single-char safety: only accept raw "e"/"k" etc. on clickable roles.
                var helpRef: AnyObject?
                AXUIElementCopyAttributeValue(current, kAXHelpAttribute as CFString, &helpRef)
                if let help = helpRef as? String, !help.isEmpty {
                    let isClickable = ["AXButton","AXMenuItem","AXCell","AXTextField",
                                       "AXCheckBox","AXRadioButton"].contains(role(current))
                    if help.count > 1 || isClickable,
                       let keys = ShortcutRules.parseShortcut(from: help) {
                        let autoId = "auto:\(bundleId):\(keys.joined(separator: "+"))"
                        emit(bundleId: bundleId, shortcutId: autoId,
                             keys: keys, hint: help, loc: nsLoc)
                        return
                    }
                }
                // Layer 3: MenuBarIndex fuzzy match on desc/title/placeholder/identifier
                let query = elementQuery(current)
                if !query.isEmpty, let entry = menuBarWatcher.currentIndex.lookup(query: query) {
                    let autoId = "menuindex:\(bundleId):\(entry.keys.joined(separator: "+"))"
                    emit(bundleId: bundleId, shortcutId: autoId,
                         keys: entry.keys, hint: entry.hint, loc: nsLoc)
                    return
                }
                // Layer 4: Universal semantic role heuristics (#4)
                if let rule = ShortcutRules.universalRules.first(where: {
                    matchUniversal(current, rule: $0)
                }) {
                    emit(bundleId: bundleId, shortcutId: rule.shortcutId,
                         keys: rule.keys, hint: rule.hint, loc: nsLoc)
                    return
                }

                var parentRef: AnyObject?
                guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString,
                                                    &parentRef) == .success,
                      let parent = parentRef else { break }
                current = parent as! AXUIElement
            }
        }

        checkMenuBar(bundleId: bundleId, nsLoc: nsLoc, axX: axX, axY: axY)
    }

    private func role(_ element: AXUIElement) -> String {
        var ref: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &ref)
        return ref as? String ?? ""
    }

    private func matchUniversal(_ element: AXUIElement, rule: ClickRule) -> Bool {
        var roleRef: AnyObject?; var descRef: AnyObject?; var subRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subRef)
        let r = roleRef as? String ?? ""
        let d = (descRef as? String ?? "").lowercased()
        let s = subRef as? String ?? ""
        if let rr = rule.role, r != rr { return false }
        if let ss = rule.subroleEquals, s != ss { return false }
        if let dd = rule.descContains, !d.contains(dd.lowercased()) { return false }
        return true
    }

    /// Returns the best query string from an AX element's visible and programmatic attributes.
    /// Priority: description > title > placeholder > normalized kAXIdentifier.
    /// kAXIdentifier is a programmer-facing name (e.g. "searchButton", "composeTextField") —
    /// we normalize camelCase to words and strip common suffixes so "searchButton" → "search".
    private func elementQuery(_ element: AXUIElement) -> String {
        let visibleAttrs = [kAXDescriptionAttribute, kAXTitleAttribute,
                            kAXPlaceholderValueAttribute, kAXValueAttribute]
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

    private func checkMenuBar(bundleId: String, nsLoc: NSPoint, axX: Float, axY: Float) {
        let sysWide = AXUIElementCreateSystemWide()
        var elemRef: AXUIElement?
        guard AXUIElementCopyElementAtPosition(sysWide, axX, axY, &elemRef) == .success,
              let element = elemRef else { return }

        var roleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""

        if role != "AXMenuItem" {
            if let rule = ShortcutRules.match(element: element, bundleId: bundleId) {
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
    }

    deinit {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        sharedWatcher = nil
    }
}

private let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .leftMouseDown { sharedWatcher?.handleMouseDown() }
    return Unmanaged.passUnretained(event)
}
```

- [ ] **Step 2: Build to verify no errors**

`⌘B` — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SFlow/ClickWatcher.swift
git commit -m "feat: add ClickWatcher with CGEventTap and AX element detection"
```

---

### Task 8: AppDelegate

**Files:**
- Modify: `SFlow/main.swift` (already exists — no changes needed)
- Create: `SFlow/AppDelegate.swift`

- [ ] **Step 1: Create `SFlow/AppDelegate.swift`**

```swift
import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var clickWatcher: ClickWatcher?

    private var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "enabled") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Skip full startup when running unit tests
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        checkPermissionsAndStart()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        refreshStatusIcon()

        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: isEnabled ? "✓ Enabled" : "Enabled",
                                    action: #selector(toggleEnabled),
                                    keyEquivalent: "")
        toggleItem.tag = 1
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SFlow", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func refreshStatusIcon() {
        guard let button = statusItem.button else { return }
        let img = NSImage(systemSymbolName: "command", accessibilityDescription: "SFlow")
        img?.isTemplate = true
        button.image = img
        button.alphaValue = isEnabled ? 1.0 : 0.4
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        refreshStatusIcon()
        if let item = statusItem.menu?.item(withTag: 1) {
            item.title = isEnabled ? "✓ Enabled" : "Enabled"
        }
        if isEnabled { startWatcher() } else { clickWatcher = nil }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Permissions + Watcher

    private func checkPermissionsAndStart() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt: false] as CFDictionary
        )
        if !trusted {
            showAlert(
                title: "Accessibility Permission Required",
                message: "SFlow needs Accessibility access to read UI element names.\n\nOpen System Settings → Privacy & Security → Accessibility and enable SFlow.",
                url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
            return
        }
        if isEnabled { startWatcher() }
    }

    private func startWatcher() {
        clickWatcher = ClickWatcher { event in
            ToastWindow.show(event: event)
            EventLogger.log(event: event)
        }
    }

    private func showAlert(title: String, message: String, url: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: url)!)
        }
    }
}
```

- [ ] **Step 2: Build to verify no errors**

`⌘B` — Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SFlow/AppDelegate.swift
git commit -m "feat: add AppDelegate with status item, permissions check, and watcher wiring"
```

---

### Task 9: Build Release + Manual Integration Test

- [ ] **Step 1: Build release binary**

In Xcode: select scheme `SFlow` → Product → Archive  
Or: `xcodebuild -scheme SFlow -configuration Release archive -archivePath build/SFlow.xcarchive`

- [ ] **Step 2: Copy app to /Applications (optional)**

Drag `SFlow.app` from the archive (or `build/` folder) to `/Applications`.

- [ ] **Step 3: First launch — grant Accessibility**

Launch SFlow. It will show an alert asking for Accessibility permission.  
→ Click "Open System Settings"  
→ System Settings → Privacy & Security → Accessibility → enable SFlow  
→ Relaunch SFlow

- [ ] **Step 4: Grant Input Monitoring (if tap fails)**

If no toasts appear, check:  
System Settings → Privacy & Security → Input Monitoring → enable SFlow

- [ ] **Step 5: Test in Slack**

1. Open Slack
2. Click the search bar / quick switcher field at the top
3. Expected: toast appears near cursor showing `⌘K  Quick Switcher` for ~3 seconds

- [ ] **Step 6: Test in Finder**

1. Open Finder
2. Click the search icon / search field
3. Expected: toast `⌘F  Search`

4. Click the Back button in the toolbar
5. Expected: toast `⌘[  Go Back`

- [ ] **Step 7: Test menu bar auto-detection**

1. Open any app (e.g. TextEdit)
2. Click File menu → click "New" menu item
3. Expected: toast `⌘N  New` (reads shortcut from AXMenuItem attributes)

- [ ] **Step 8: Verify event log**

```bash
cat ~/Library/Application\ Support/SFlow/events.jsonl
```

Expected: one JSONL line per fired toast.

- [ ] **Step 9: Test toggle**

1. Click SFlow menu bar icon
2. Click "✓ Enabled" → becomes "Enabled", icon fades
3. Click in Slack search — no toast appears
4. Re-enable → toasts return

- [ ] **Step 10: Final commit**

```bash
git add .
git commit -m "feat: SFlow v1.0 — keyboard shortcut toast detector"
```
