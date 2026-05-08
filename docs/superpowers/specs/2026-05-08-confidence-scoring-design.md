# Confidence Scoring — Implementation Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent false-positive toasts by assigning a confidence level to every shortcut match and suppressing results below a fixed threshold.

**Architecture:** New `MatchConfidence` enum (.low / .medium / .high) with a hardcoded threshold of `.medium`. `ShortcutRules.match()` and `MenuBarIndex.lookup()` return confidence alongside their result. `ClickWatcher` guards on `confidence >= .threshold` before emitting. `ShortcutEvent` is unchanged — confidence is an internal detail of `ClickWatcher`.

**Tech Stack:** Pure Swift. No new dependencies. Changes interfaces of `ShortcutRules.match` and `MenuBarIndex.lookup`.

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `SFlow/MatchConfidence.swift` | Create | Enum definition + threshold constant |
| `SFlow/ShortcutRules.swift` | Modify | `match()` returns `(ClickRule, MatchConfidence)?` |
| `SFlow/MenuBarIndex.swift` | Modify | `lookup()` returns `(MenuBarEntry, MatchConfidence)?` |
| `SFlow/ClickWatcher.swift` | Modify | Guard on `confidence >= .threshold` in all 4 layers |
| `SFlowTests/MatchConfidenceTests.swift` | Create | Unit tests for ordering, threshold, and layer confidence |
| `SFlowTests/MenuBarIndexTests.swift` | Modify | Update 2 tests broken by new `lookup()` return type |

---

## Section 1: `MatchConfidence` Type

```swift
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

`Comparable` conformance allows `confidence >= .threshold` without a switch statement. The threshold constant is the single place to change suppression behaviour in future.

---

## Section 2: Confidence Assignments Per Layer

| Layer | Source | Confidence |
|-------|--------|------------|
| 1 | `ShortcutRules.match()` — hardcoded per-app rules | `.high` |
| 2 | `kAXHelpAttribute` auto-parse | `.medium` |
| 3 | `MenuBarIndex.lookup()` — AX menu bar scan + ASAR | `.medium` |
| 4 | Universal semantic role heuristics | `.low` |

**Practical effect at threshold `.medium`:** Layer 4 results are suppressed entirely. Layers 1–3 behave identically to today.

**`checkMenuBar()` (direct menu bar click):** Always emits — menu bar AX matches are inherently `.high`, no change needed.

---

## Section 3: Changed Interfaces

### `ShortcutRules.match()`

```swift
// Before:
static func match(element: AXUIElement, bundleId: String) -> ClickRule?

// After:
static func match(element: AXUIElement, bundleId: String) -> (rule: ClickRule, confidence: MatchConfidence)?
```

All existing hardcoded rules return `.high`.

### `MenuBarIndex.lookup()`

```swift
// Before:
func lookup(query: String) -> MenuBarEntry?

// After:
func lookup(query: String) -> (entry: MenuBarEntry, confidence: MatchConfidence)?
```

Both exact and partial matches return `.medium`.

---

## Section 4: `ClickWatcher` Changes

Each layer gets a `guard confidence >= .threshold` before emitting. Results below threshold are silently skipped — no toast, no log entry.

```swift
// Layer 1
if let (rule, confidence) = ShortcutRules.match(element: current, bundleId: bundleId) {
    guard confidence >= .threshold else { break }
    emit(bundleId: bundleId, shortcutId: rule.shortcutId,
         keys: rule.keys, hint: rule.hint, loc: nsLoc)
    return
}

// Layer 2 — confidence always .medium (already behind isClickable guard)
var helpRef: AnyObject?
AXUIElementCopyAttributeValue(current, kAXHelpAttribute as CFString, &helpRef)
if let help = helpRef as? String, !help.isEmpty {
    let isClickable = ["AXButton","AXMenuItem","AXCell","AXTextField",
                       "AXCheckBox","AXRadioButton"].contains(role(current))
    if help.count > 1 || isClickable,
       let keys = ShortcutRules.parseShortcut(from: help) {
        let confidence = MatchConfidence.medium
        guard confidence >= .threshold else { break }
        let autoId = "auto:\(bundleId):\(keys.joined(separator: "+"))"
        emit(bundleId: bundleId, shortcutId: autoId,
             keys: keys, hint: help, loc: nsLoc)
        return
    }
}

// Layer 3
let query = elementQuery(current)
if !query.isEmpty, let (entry, confidence) = menuBarWatcher.currentIndex.lookup(query: query) {
    guard confidence >= .threshold else { break }
    let autoId = "menuindex:\(bundleId):\(entry.keys.joined(separator: "+"))"
    emit(bundleId: bundleId, shortcutId: autoId,
         keys: entry.keys, hint: entry.hint, loc: nsLoc)
    return
}

// Layer 4 — .low < .threshold → guard fails, continue to next AX ancestor
if let rule = ShortcutRules.universalRules.first(where: {
    matchUniversal(current, rule: $0)
}) {
    let confidence = MatchConfidence.low
    guard confidence >= .threshold else { continue }
    emit(bundleId: bundleId, shortcutId: rule.shortcutId,
         keys: rule.keys, hint: rule.hint, loc: nsLoc)
    return
}
```

---

## Section 5: Tests

### `SFlowTests/MatchConfidenceTests.swift` (new)

```swift
func test_ordering_lowLessThanMedium()
func test_ordering_mediumLessThanHigh()
func test_threshold_suppressesLow()      // .low >= .threshold == false
func test_threshold_allowsMedium()       // .medium >= .threshold == true
func test_threshold_allowsHigh()         // .high >= .threshold == true
func test_lookup_exactMatch_returnsMedium()
func test_lookup_partialMatch_returnsMedium()
func test_match_returnsHighConfidence()  // ShortcutRules.match() → .high
```

### `SFlowTests/MenuBarIndexTests.swift` (modified)

Two existing tests use `lookup()?.keys` — update to `lookup()?.entry.keys`:

```swift
// Before:
XCTAssertEqual(index.lookup(query: "quick find")?.keys, ["meta", "k"])

// After:
XCTAssertEqual(index.lookup(query: "quick find")?.entry.keys, ["meta", "k"])
```

### Manual verification

Click a "Back" button in any app that has no hardcoded rule (e.g. Chrome's back button via universal heuristics). Toast must **not** appear. Check `events.jsonl` confirms no entry was logged.

---

## Error Handling

- Suppressed matches are silent — no log, no toast, no error.
- `checkMenuBar()` path is unaffected (does not use `lookup()` or `match()`).
- No changes to `ShortcutEvent`, `ToastWindow`, `EventLogger`, or `MenuBarCache`.
