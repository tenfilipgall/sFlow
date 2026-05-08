# Confidence Scoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `MatchConfidence` enum to every shortcut-match return value and suppress results below a fixed `.medium` threshold, eliminating false-positive toasts from Layer 4 (universal heuristics).

**Architecture:** New `MatchConfidence` enum (`.low / .medium / .high`) with `Comparable` conformance and a static `threshold = .medium`. `ShortcutRules.match()` and `MenuBarIndex.lookup()` return confidence alongside their result. `ClickWatcher` guards on `confidence >= .threshold` before emitting — suppressed matches produce no toast and no log entry. `ShortcutEvent` is unchanged.

**Tech Stack:** Pure Swift, XCTest. No new dependencies.

---

## File Map

| File | Change | Responsibility |
|------|--------|----------------|
| `SFlow/MatchConfidence.swift` | **Create** | Enum definition + `threshold` constant |
| `SFlowTests/MatchConfidenceTests.swift` | **Create** | Unit tests for ordering, threshold, per-layer confidence |
| `SFlow/ShortcutRules.swift` | Modify | `match()` returns `(rule: ClickRule, confidence: MatchConfidence)?` |
| `SFlow/MenuBarIndex.swift` | Modify | `lookup()` returns `(entry: MenuBarEntry, confidence: MatchConfidence)?` |
| `SFlow/ClickWatcher.swift` | Modify | Guard `confidence >= .threshold` in Layers 1–4 |
| `SFlowTests/MenuBarIndexTests.swift` | Modify | Fix 2 tests broken by new `lookup()` return type |

**Running tests:**
```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "passed|failed|error:"
```

**Running build:**
```bash
xcodebuild -project SFlow.xcodeproj -scheme SFlow -configuration Debug build \
  2>&1 | grep -E "SUCCEEDED|FAILED|error:"
```

---

## Context: Codebase Orientation

**Four detection layers in `ClickWatcher.handleMouseDown()`** (`SFlow/ClickWatcher.swift:60-96`):
- Layer 1: `ShortcutRules.match(element:bundleId:)` — hardcoded per-app rules
- Layer 2: `kAXHelpAttribute` auto-parse via `ShortcutRules.parseShortcut(from:)`
- Layer 3: `menuBarWatcher.currentIndex.lookup(query:)` — AX menu bar + ASAR index
- Layer 4: `ShortcutRules.universalRules` — semantic role heuristics (e.g. "back" → ⌘←)

Confidence assignments: Layer 1 = `.high`, Layer 2 = `.medium`, Layer 3 = `.medium`, Layer 4 = `.low`.
Threshold = `.medium`. Practical effect: Layer 4 is suppressed; Layers 1–3 unchanged.

---

## Task 1: `MatchConfidence` Enum (TDD)

**Files:**
- Create: `SFlowTests/MatchConfidenceTests.swift`
- Create: `SFlow/MatchConfidence.swift`

- [ ] **Step 1: Write failing tests**

Create `SFlowTests/MatchConfidenceTests.swift`:

```swift
import XCTest
@testable import SFlow

final class MatchConfidenceTests: XCTestCase {

    func test_ordering_lowLessThanMedium() {
        XCTAssertLessThan(MatchConfidence.low, .medium)
    }

    func test_ordering_mediumLessThanHigh() {
        XCTAssertLessThan(MatchConfidence.medium, .high)
    }

    func test_threshold_suppressesLow() {
        XCTAssertFalse(MatchConfidence.low >= .threshold)
    }

    func test_threshold_allowsMedium() {
        XCTAssertTrue(MatchConfidence.medium >= .threshold)
    }

    func test_threshold_allowsHigh() {
        XCTAssertTrue(MatchConfidence.high >= .threshold)
    }
}
```

- [ ] **Step 2: Run — expect FAIL (MatchConfidence not defined)**

```bash
xcodegen generate 2>/dev/null && \
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep "error:" | head -3
```

Expected: compile error `cannot find type 'MatchConfidence'`.

- [ ] **Step 3: Create `SFlow/MatchConfidence.swift`**

```swift
import Foundation

enum MatchConfidence: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: MatchConfidence, rhs: MatchConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static let threshold: MatchConfidence = .medium
}
```

- [ ] **Step 4: Run xcodegen + tests — expect PASS**

```bash
xcodegen generate 2>/dev/null && \
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "passed|failed|error:"
```

Expected: all tests pass, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add SFlow/MatchConfidence.swift SFlowTests/MatchConfidenceTests.swift
git commit -m "feat: add MatchConfidence enum with threshold"
```

---

## Task 2: `ShortcutRules.match()` Return Type + ClickWatcher Layer 1

**Files:**
- Modify: `SFlow/ShortcutRules.swift:29,55`
- Modify: `SFlow/ClickWatcher.swift:61-65`

- [ ] **Step 1: Update `ShortcutRules.match()` signature and return**

In `SFlow/ShortcutRules.swift`, change line 29:

```swift
// Before:
static func match(element: AXUIElement, bundleId: String) -> ClickRule? {

// After:
static func match(element: AXUIElement, bundleId: String) -> (rule: ClickRule, confidence: MatchConfidence)? {
```

Change line 55 (the `return rule` inside the `for rule in appRules` loop):

```swift
// Before:
            return rule

// After:
            return (rule: rule, confidence: .high)
```

- [ ] **Step 2: Fix ClickWatcher Layer 1 call site**

In `SFlow/ClickWatcher.swift`, replace lines 61–65:

```swift
// Before:
                if let rule = ShortcutRules.match(element: current, bundleId: bundleId) {
                    emit(bundleId: bundleId, shortcutId: rule.shortcutId,
                         keys: rule.keys, hint: rule.hint, loc: nsLoc)
                    return
                }

// After:
                if let (rule, confidence) = ShortcutRules.match(element: current, bundleId: bundleId),
                   confidence >= .threshold {
                    emit(bundleId: bundleId, shortcutId: rule.shortcutId,
                         keys: rule.keys, hint: rule.hint, loc: nsLoc)
                    return
                }
```

- [ ] **Step 3: Build — expect SUCCEEDED**

```bash
xcodebuild -project SFlow.xcodeproj -scheme SFlow -configuration Debug build \
  2>&1 | grep -E "SUCCEEDED|FAILED|error:"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run all tests — expect PASS**

```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "passed|failed|error:"
```

Expected: all tests pass, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add SFlow/ShortcutRules.swift SFlow/ClickWatcher.swift
git commit -m "feat: ShortcutRules.match returns .high confidence; guard in Layer 1"
```

---

## Task 3: `MenuBarIndex.lookup()` Return Type + Fix Callers + Update Tests

**Files:**
- Modify: `SFlow/MenuBarIndex.swift:68-73`
- Modify: `SFlow/ClickWatcher.swift:82-88`
- Modify: `SFlowTests/MenuBarIndexTests.swift:32,39`

- [ ] **Step 1: Update `MenuBarIndexTests` — fix the 2 broken tests and add confidence tests**

In `SFlowTests/MenuBarIndexTests.swift`, replace lines 28–46 (`test_lookup_exactTitle` and `test_lookup_partialTitle`):

```swift
    func test_lookup_exactTitle() {
        var index = MenuBarIndex()
        index.insert(title: "New Message", keys: ["meta", "n"])
        let result = index.lookup(query: "new message")
        XCTAssertEqual(result?.entry.keys, ["meta", "n"])
        XCTAssertEqual(result?.confidence, .medium)
    }

    func test_lookup_partialTitle() {
        var index = MenuBarIndex()
        index.insert(title: "Find in Files", keys: ["meta", "shift", "f"])
        let result = index.lookup(query: "find")
        XCTAssertEqual(result?.entry.keys, ["meta", "shift", "f"])
        XCTAssertEqual(result?.confidence, .medium)
    }
```

- [ ] **Step 2: Run — expect FAIL (return type mismatch)**

```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep "error:" | head -5
```

Expected: compile error about `?.keys` / `?.entry` on the old return type — tests reference `.entry` but implementation still returns `MenuBarEntry?` directly.

- [ ] **Step 3: Update `MenuBarIndex.lookup()` return type**

In `SFlow/MenuBarIndex.swift`, replace lines 68–73:

```swift
// Before:
    func lookup(query: String) -> MenuBarEntry? {
        guard query.count >= 3 else { return nil }
        let q = query.lowercased()
        if let entry = titleMap[q] { return entry }
        return titleMap.first(where: { $0.key.contains(q) })?.value
    }

// After:
    func lookup(query: String) -> (entry: MenuBarEntry, confidence: MatchConfidence)? {
        guard query.count >= 3 else { return nil }
        let q = query.lowercased()
        if let entry = titleMap[q] { return (entry: entry, confidence: .medium) }
        if let pair = titleMap.first(where: { $0.key.contains(q) }) {
            return (entry: pair.value, confidence: .medium)
        }
        return nil
    }
```

- [ ] **Step 4: Fix ClickWatcher Layer 3 call site**

In `SFlow/ClickWatcher.swift`, replace lines 82–88:

```swift
// Before:
                let query = elementQuery(current)
                if !query.isEmpty, let entry = menuBarWatcher.currentIndex.lookup(query: query) {
                    let autoId = "menuindex:\(bundleId):\(entry.keys.joined(separator: "+"))"
                    emit(bundleId: bundleId, shortcutId: autoId,
                         keys: entry.keys, hint: entry.hint, loc: nsLoc)
                    return
                }

// After:
                let query = elementQuery(current)
                if !query.isEmpty,
                   let (entry, confidence) = menuBarWatcher.currentIndex.lookup(query: query),
                   confidence >= .threshold {
                    let autoId = "menuindex:\(bundleId):\(entry.keys.joined(separator: "+"))"
                    emit(bundleId: bundleId, shortcutId: autoId,
                         keys: entry.keys, hint: entry.hint, loc: nsLoc)
                    return
                }
```

- [ ] **Step 5: Build — expect SUCCEEDED**

```bash
xcodebuild -project SFlow.xcodeproj -scheme SFlow -configuration Debug build \
  2>&1 | grep -E "SUCCEEDED|FAILED|error:"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Run all tests — expect PASS**

```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "passed|failed|error:"
```

Expected: all tests pass, 0 failures (including the updated MenuBarIndexTests).

- [ ] **Step 7: Commit**

```bash
git add SFlow/MenuBarIndex.swift SFlow/ClickWatcher.swift SFlowTests/MenuBarIndexTests.swift
git commit -m "feat: MenuBarIndex.lookup returns .medium confidence; guard in Layer 3"
```

---

## Task 4: ClickWatcher Layers 2 and 4 — Add Confidence Guards

**Files:**
- Modify: `SFlow/ClickWatcher.swift:66-80,89-96`

Layer 2 gets `confidence = .medium` (no behavioral change — `.medium >= .threshold`).
Layer 4 gets `confidence = .low` — guard fails, suppressing all universal heuristic toasts.

- [ ] **Step 1: Update Layer 2 in `SFlow/ClickWatcher.swift`**

Replace lines 66–80 (the Layer 2 block):

```swift
                // Layer 2: kAXHelpAttribute auto-parse
                // Single-char safety: only accept raw "e"/"k" etc. on clickable roles.
                var helpRef: AnyObject?
                AXUIElementCopyAttributeValue(current, kAXHelpAttribute as CFString, &helpRef)
                if let help = helpRef as? String, !help.isEmpty {
                    let isClickable = ["AXButton","AXMenuItem","AXCell","AXTextField",
                                       "AXCheckBox","AXRadioButton"].contains(role(current))
                    if help.count > 1 || isClickable,
                       let keys = ShortcutRules.parseShortcut(from: help),
                       MatchConfidence.medium >= .threshold {
                        let autoId = "auto:\(bundleId):\(keys.joined(separator: "+"))"
                        emit(bundleId: bundleId, shortcutId: autoId,
                             keys: keys, hint: help, loc: nsLoc)
                        return
                    }
                }
```

- [ ] **Step 2: Update Layer 4 in `SFlow/ClickWatcher.swift`**

Replace lines 89–96 (the Layer 4 block):

```swift
                // Layer 4: Universal semantic role heuristics
                if let rule = ShortcutRules.universalRules.first(where: {
                    matchUniversal(current, rule: $0)
                }) {
                    let confidence = MatchConfidence.low
                    if confidence >= .threshold {
                        emit(bundleId: bundleId, shortcutId: rule.shortcutId,
                             keys: rule.keys, hint: rule.hint, loc: nsLoc)
                        return
                    }
                }
```

- [ ] **Step 3: Build — expect SUCCEEDED**

```bash
xcodebuild -project SFlow.xcodeproj -scheme SFlow -configuration Debug build \
  2>&1 | grep -E "SUCCEEDED|FAILED|error:"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run all tests — expect PASS**

```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "passed|failed|error:"
```

Expected: all tests pass, 0 failures.

- [ ] **Step 5: Manual verification**

```bash
pkill -x SFlow 2>/dev/null; sleep 1
open /Users/filip/Library/Developer/Xcode/DerivedData/SFlow-*/Build/Products/Debug/SFlow.app
```

1. Open any app that has NO hardcoded rules in `ShortcutRules.rules` (e.g. Calendar, Notes).
2. Click a "back" or "forward" navigation button. Toast must **not** appear (Layer 4 suppressed).
3. Switch to Slack, click the Quick Switcher — toast **must** appear (Layer 1 hardcoded, `.high`).
4. Check no spurious entries in events.jsonl:
   ```bash
   tail -5 ~/Library/Application\ Support/SFlow/events.jsonl
   ```

- [ ] **Step 6: Commit**

```bash
git add SFlow/ClickWatcher.swift
git commit -m "feat: add confidence guards to ClickWatcher Layers 2 and 4; suppress Layer 4"
```
