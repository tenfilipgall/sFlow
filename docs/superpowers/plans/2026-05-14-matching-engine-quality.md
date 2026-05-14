# Matching Engine Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the four highest-impact false-positive/false-negative sources in the click-recognition engine, and add per-layer telemetry so future quality work is data-driven.

**Architecture:** Surgical changes in three Swift files (`ClickWatcher.swift`, `RuleCache.swift`, `MenuBarIndex.swift`), plus a new tiny `TextMatching.swift` utility, plus a `layer` field threaded through `ShortcutEvent` → `EventLogger`. No new dependencies, no API changes to the backend, no migrations. Every change has a focused XCTest.

**Tech Stack:** Swift 5.9, XCTest, macOS 13+ (existing).

**Background:** This plan implements the top fixes from the 2026-05-14 critical audit of the recognition mode. The four bugs being fixed:

- **BUG #1** — `ClickWatcher.swift:159-184` runs Layer 0.5 (LLM rules) and Layer 1 (hardcoded rules) on **every** element walked up the AX tree, including structural parents (`AXWindow`, `AXScrollArea`, `AXGroup` containers). Result: clicking deep inside a note matches a parent's description ("page with search results") and fires a wrong toast. Fix: gate L0.5 and L1 by `isInteractive` for depth > 0. Depth 0 (the actual hit-tested element) stays ungated to preserve Chromium AXGroup clickables.

- **BUG #2** — `RuleCache.swift:101-109` uses `String.contains` for substring match. "search" matches "research", "Researcher Tools", any title containing those letters. Fix: word-boundary substring (start-aligned). `"search"` matches "search slack" and "searches" but NOT "research".

- **BUG #3** — `MenuBarIndex.swift:72` uses `titleMap.first(where: { $0.key.contains(q) })`. Swift dictionary iteration order is unstable → same click can match different entries across launches. Fix: collect all matches, sort by key length descending (longest = most specific), pick first.

- **BUG B1** — `AXSkeletonExtractor.swift:67-68` drops single-occurrence titles that aren't verb-led. Drops "Quick Switcher", "Preferences", "Mentions", "Settings" before they reach the LLM, so no rules generated for them. Fix: relax the filter — single-occurrence titles are kept if they pass all other filters (length, prefix, regex).

After the four fixes, the plan adds:

- **TELEMETRY** — `ShortcutEvent` gains a `layer` field ("L0", "L0.5", "L1", "L2", "L3", "L4", "menu"); `EventLogger.log` writes it to `events.jsonl`. Future per-layer hit-rate analysis becomes trivial.

**Out of scope (will be separate plans):**
- Score-based "best match wins" replacing first-match-wins (bigger refactor; needs design pass first)
- LLM prompt rework (`backend/src/prompt.ts`) — separate plan once telemetry shows which layers under-fire
- Negative rules in `user_overrides.json`
- Retry/backoff for failed discovery (already in Phase 1.2 roadmap)

---

## File Structure

**Modify:**
- `SFlow/ClickWatcher.swift` — depth-gate L0.5/L1, pass layer into emit()
- `SFlow/RuleCache.swift` — word-boundary match in `match()`
- `SFlow/MenuBarIndex.swift` — deterministic, longest-match-wins in `lookup()`
- `SFlow/AXSkeletonExtractor.swift` — relax single-occurrence drop
- `SFlow/ShortcutEvent.swift` — add `layer: String` field
- `SFlow/EventLogger.swift` — write `layer` to JSONL
- `SFlow/AppDelegate.swift` — none (event flow unchanged at this level)

**Create:**
- `SFlow/TextMatching.swift` — single utility with `wordBoundaryContains(haystack:needle:)`
- `SFlowTests/TextMatchingTests.swift`
- `SFlowTests/ClickWatcherLayerGateTests.swift` — direct unit test of layer gating logic (factored out)

**Test files modified:**
- `SFlowTests/RuleCacheTests.swift` — add word-boundary cases
- `SFlowTests/MenuBarIndexTests.swift` — add determinism + longest-match cases
- `SFlowTests/AXSkeletonFilterTests.swift` — add single-occurrence noun-led cases
- `SFlowTests/EventLoggerTests.swift` — assert layer field appears in output

**Test command (used throughout):**
```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/<ClassName>/<methodName> \
  2>&1 | grep -E "(Test Case|FAIL|PASS|error:)" | head -30
```

For full-suite verification at the end:
```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' 2>&1 | tail -40
```

---

## Task 1: Word-boundary text matching utility

**Files:**
- Create: `SFlow/TextMatching.swift`
- Test: `SFlowTests/TextMatchingTests.swift`

The utility powers Task 2 (RuleCache) and Task 4 (MenuBarIndex). Build + test in isolation first.

**Behavior:**
- `wordBoundaryContains(haystack:needle:)` returns `true` iff `needle` appears in `haystack` aligned to a word boundary on the **left** (start of string or preceded by non-alphanumeric).
- The **right** side is allowed to extend into letters/digits — this lets "bookmark" match "bookmarks" (plurals), which the LLM frequently produces as a short noun.
- Empty `needle` returns `false`.
- Exact equality returns `true`.
- Comparison is **byte-wise** on the input strings — callers lowercase before calling.

- [ ] **Step 1: Write the test file**

Create `SFlowTests/TextMatchingTests.swift`:

```swift
import XCTest
@testable import SFlow

final class TextMatchingTests: XCTestCase {

    func test_exactMatch() {
        XCTAssertTrue(wordBoundaryContains(haystack: "search", needle: "search"))
    }

    func test_atStart_followedBySpace_matches() {
        XCTAssertTrue(wordBoundaryContains(haystack: "search slack", needle: "search"))
    }

    func test_atEnd_precededBySpace_matches() {
        XCTAssertTrue(wordBoundaryContains(haystack: "quick search", needle: "search"))
    }

    func test_inMiddle_surroundedBySpaces_matches() {
        XCTAssertTrue(wordBoundaryContains(haystack: "open search bar", needle: "search"))
    }

    func test_pluralExtension_matches() {
        // "bookmark" appears at start of "bookmarks", right side extends into "s" — allowed
        XCTAssertTrue(wordBoundaryContains(haystack: "bookmarks", needle: "bookmark"))
    }

    func test_insideWord_doesNotMatch() {
        // "search" inside "research" — left side is "e" (word char), not a boundary
        XCTAssertFalse(wordBoundaryContains(haystack: "research", needle: "search"))
    }

    func test_insideMultiwordPhrase_doesNotMatch() {
        XCTAssertFalse(wordBoundaryContains(haystack: "researcher tools", needle: "search"))
    }

    func test_punctuationIsBoundary() {
        XCTAssertTrue(wordBoundaryContains(haystack: "(search)", needle: "search"))
        XCTAssertTrue(wordBoundaryContains(haystack: "search…", needle: "search"))
    }

    func test_emptyNeedle_returnsFalse() {
        XCTAssertFalse(wordBoundaryContains(haystack: "anything", needle: ""))
    }

    func test_emptyHaystack_returnsFalse() {
        XCTAssertFalse(wordBoundaryContains(haystack: "", needle: "search"))
    }

    func test_needleLongerThanHaystack_returnsFalse() {
        XCTAssertFalse(wordBoundaryContains(haystack: "ab", needle: "abc"))
    }

    func test_unicodeBoundaryHandling() {
        // Polish: "wyślij" at start of "wyślij wiadomość" — leading char is at index 0 → boundary
        XCTAssertTrue(wordBoundaryContains(haystack: "wyślij wiadomość", needle: "wyślij"))
        // "ślij" inside "wyślij" — leading "y" is letter → no match
        XCTAssertFalse(wordBoundaryContains(haystack: "wyślij", needle: "ślij"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/TextMatchingTests 2>&1 | grep -E "(error:|FAIL)" | head -10
```

Expected: build error — `wordBoundaryContains` is not defined.

- [ ] **Step 3: Create the utility file**

Create `SFlow/TextMatching.swift`:

```swift
import Foundation

/// Returns true iff `needle` appears in `haystack` aligned to a word boundary on the LEFT side.
/// "Word boundary" = start of string OR the preceding character is not a letter/digit.
/// The RIGHT side is unconstrained — this lets "bookmark" match "bookmarks" (plurals), which
/// matters for LLM-generated rule titles that often use the singular noun form.
///
/// Callers are expected to lowercase both arguments before calling — comparison is byte-wise
/// on Unicode scalars (handles ASCII and most Latin-extended scripts correctly).
///
/// Performance: O(haystack.count * needle.count) worst case. Strings here are short
/// (AX titles cap at ~80 chars, needles at ~30), so this is fine for hot-path use.
func wordBoundaryContains(haystack: String, needle: String) -> Bool {
    guard !needle.isEmpty, !haystack.isEmpty else { return false }
    if haystack == needle { return true }

    let hay = Array(haystack)
    let need = Array(needle)
    guard need.count <= hay.count else { return false }

    let lastStart = hay.count - need.count
    var i = 0
    while i <= lastStart {
        let leftIsBoundary = (i == 0) || !isWordChar(hay[i - 1])
        if leftIsBoundary {
            var matched = true
            for j in 0..<need.count where hay[i + j] != need[j] {
                matched = false; break
            }
            if matched { return true }
        }
        i += 1
    }
    return false
}

private func isWordChar(_ c: Character) -> Bool {
    c.isLetter || c.isNumber
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/TextMatchingTests 2>&1 | grep -E "(Test Case|PASS|FAIL)" | tail -20
```

Expected: all 12 test cases pass.

- [ ] **Step 5: Commit**

```bash
git add SFlow/TextMatching.swift SFlowTests/TextMatchingTests.swift project.yml
git commit -m "feat(client): word-boundary text matching utility

Adds wordBoundaryContains(haystack:needle:) — used in next commits to
replace String.contains in matching paths. Boundary check is left-side
only; right side allows extension (plurals).

Audit reference: BUG #2 in 2026-05-14-matching-engine-quality.md."
```

Note: `project.yml` is staged in case `xcodegen` was needed to regenerate the project for the new files. If `git status` shows it unchanged, omit it from `git add`.

---

## Task 2: Replace `contains` with word-boundary in RuleCache.match

**Files:**
- Modify: `SFlow/RuleCache.swift:101-109`
- Test: `SFlowTests/RuleCacheTests.swift`

**Current code (RuleCache.swift:101-109):**
```swift
let titleMatches = rule.match.titles.contains { candidate in
    let c = candidate.lowercased()
    if titleLC == c || descLC == c || helpLC == c
        || titleLC.contains(c) || descLC.contains(c) { return true }
    if let stripped = titleStripped {
        if stripped == c || stripped.contains(c) { return true }
    }
    return false
}
```

The bugs: (a) substring `contains` matches inside words; (b) `helpLC` is checked only for equality, not substring — inconsistent. After the fix, all three of `titleLC`/`descLC`/`helpLC` will use word-boundary `wordBoundaryContains`.

- [ ] **Step 1: Write the failing tests**

Add to `SFlowTests/RuleCacheTests.swift` (append before the closing brace of the class):

```swift
    // MARK: - Word-boundary match (BUG #2)

    func testTitleSearch_doesNotMatchInsideResearch() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("search", keys: ["meta", "k"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        // "research papers" should NOT match rule with title "search" (substring match was the bug)
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "research papers", desc: "", help: "")
        XCTAssertNil(result, "title 'search' must not match inside 'research'")
    }

    func testDescSearch_doesNotMatchInsideResearcher() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("search", keys: ["meta", "k"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "", desc: "researcher tools", help: "")
        XCTAssertNil(result, "desc 'researcher tools' must not match title 'search'")
    }

    func testTitleSearch_stillMatchesSearchSlack() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("search", keys: ["meta", "k"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        // "Search Slack" should still match (start of string)
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "Search Slack", desc: "", help: "")
        XCTAssertEqual(result?.keys, ["meta", "k"])
    }

    func testHelpAttribute_substringNowChecked() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("compose", keys: ["meta", "n"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        // help="Compose a new message" should match rule title="compose" via word-boundary
        // (previously help only checked equality, was inconsistent with title/desc)
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "", desc: "", help: "Compose a new message")
        XCTAssertEqual(result?.keys, ["meta", "n"])
    }

    func testPluralStillMatches() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("bookmark", keys: ["meta", "d"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        // Right-side extension is allowed: "bookmarks" should still match "bookmark"
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "bookmarks", desc: "", help: "")
        XCTAssertEqual(result?.keys, ["meta", "d"])
    }
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/RuleCacheTests/testTitleSearch_doesNotMatchInsideResearch \
  -only-testing:SFlowTests/RuleCacheTests/testDescSearch_doesNotMatchInsideResearcher \
  -only-testing:SFlowTests/RuleCacheTests/testTitleSearch_stillMatchesSearchSlack \
  -only-testing:SFlowTests/RuleCacheTests/testHelpAttribute_substringNowChecked \
  -only-testing:SFlowTests/RuleCacheTests/testPluralStillMatches \
  2>&1 | grep -E "(Test Case|FAIL|PASS)" | tail -20
```

Expected: `testTitleSearch_doesNotMatchInsideResearch` FAILS (current `contains` matches), `testDescSearch_doesNotMatchInsideResearcher` FAILS, `testHelpAttribute_substringNowChecked` FAILS (help not substring-checked currently), `testTitleSearch_stillMatchesSearchSlack` PASSES (regression baseline), `testPluralStillMatches` PASSES (current `contains` allows this).

- [ ] **Step 3: Modify RuleCache.match to use word-boundary**

In `SFlow/RuleCache.swift`, replace the inner block of `match(...)` at lines 101-109 (the `let titleMatches = ...` block) with:

```swift
            // Title match — word-boundary for substring to prevent
            // "search" matching inside "research" (BUG #2 in audit).
            let titleMatches = rule.match.titles.contains { candidate in
                let c = candidate.lowercased()
                if c.isEmpty { return false }
                if titleLC == c || descLC == c || helpLC == c { return true }
                if wordBoundaryContains(haystack: titleLC, needle: c) { return true }
                if wordBoundaryContains(haystack: descLC,  needle: c) { return true }
                if wordBoundaryContains(haystack: helpLC,  needle: c) { return true }
                if let stripped = titleStripped {
                    if stripped == c { return true }
                    if wordBoundaryContains(haystack: stripped, needle: c) { return true }
                }
                return false
            }
            if titleMatches { return MatchResult(rule: rule) }
```

- [ ] **Step 4: Run failing tests to verify they now pass**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/RuleCacheTests 2>&1 | grep -E "(Test Case|FAIL|PASS|error:)" | tail -30
```

Expected: all RuleCacheTests pass (including the 5 new ones and all pre-existing).

- [ ] **Step 5: Commit**

```bash
git add SFlow/RuleCache.swift SFlowTests/RuleCacheTests.swift
git commit -m "fix(client): RuleCache uses word-boundary match (BUG #2)

Replaces String.contains in title/desc/help comparison with
wordBoundaryContains. Eliminates false positives like 'search' matching
inside 'research' or 'researcher tools'. Plural extension preserved
(needle 'bookmark' still matches 'bookmarks').

Also: help attribute now uses substring-equivalent check (was only
equality before — inconsistent with title/desc paths)."
```

---

## Task 3: Gate L0.5 and L1 by depth+isInteractive in ClickWatcher

**Files:**
- Modify: `SFlow/ClickWatcher.swift:117-228`
- Test: `SFlowTests/ClickWatcherParseTests.swift` (add a new test class would be cleaner — see below)

**Idea:** at depth 0 (the actual hit-tested element from `AXUIElementCopyElementAtPosition`), try all layers as today — this preserves Chromium AXGroup clickables. At depth > 0 (walking up to parents), only try L0.5 and L1 when the role is in `interactiveRoles`. L0 (AXKeyShortcuts) stays ungated — that attribute is an explicit developer opt-in.

This kills BUG #1 (clicks deep in text matching parent containers) without losing any Chromium support.

The test approach is **factoring out** the per-element match logic into a testable pure function. This is a small refactor but pays for itself immediately (we get a unit test today and future per-layer expansion is easier).

- [ ] **Step 1: Read current handleMouseDown to confirm shape before editing**

```bash
sed -n '90,230p' SFlow/ClickWatcher.swift
```

Confirm lines 117-228 are still the per-element walk loop. (They were at audit time.)

- [ ] **Step 2: Write the failing test**

Create new file `SFlowTests/ClickWatcherLayerGateTests.swift`:

```swift
import XCTest
@testable import SFlow

final class ClickWatcherLayerGateTests: XCTestCase {

    // The exposed function signature we'll add to ClickWatcher in step 3:
    //   ClickWatcher.shouldRunNonInteractiveLayers(role: String, depth: Int) -> Bool
    //
    // Contract:
    //   - depth == 0 → always true (the hit-tested element)
    //   - depth > 0 and role is in interactiveRoles → true
    //   - depth > 0 and role is NOT in interactiveRoles → false
    //
    // L0 (AXKeyShortcuts) ignores this gate — checked separately.
    // L2 (AXHelp) already has its own gate; not touched here.

    func test_depthZero_alwaysAllowsLayers() {
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXGroup", depth: 0))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXWindow", depth: 0))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXScrollArea", depth: 0))
    }

    func test_deeperDepth_allowsInteractiveRolesOnly() {
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXButton", depth: 1))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXMenuItem", depth: 2))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXTextField", depth: 3))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXSearchField", depth: 4))
    }

    func test_deeperDepth_blocksStructuralRoles() {
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXGroup", depth: 1))
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXWindow", depth: 2))
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXScrollArea", depth: 3))
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXImage", depth: 1))
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXStaticText", depth: 2))
    }

    func test_unknownRole_atDepthZero_allowed() {
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXSomeNewRole", depth: 0))
    }

    func test_unknownRole_atDepthOnePlus_blocked() {
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXSomeNewRole", depth: 1))
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/ClickWatcherLayerGateTests 2>&1 | grep -E "(error:|FAIL)" | head -10
```

Expected: build error — `shouldRunNonInteractiveLayers` is not a member of `ClickWatcher`.

- [ ] **Step 4: Add the static gate function to ClickWatcher**

In `SFlow/ClickWatcher.swift`, immediately after the `interactiveRoles` static declaration (currently around line 51), insert:

```swift
    /// Returns true if at this depth in the AX walk, non-L0 layers (RuleCache, ShortcutRules,
    /// MenuBarIndex, universal heuristics) are allowed to attempt a match.
    ///
    /// Depth 0 is the hit-tested element returned by AXUIElementCopyElementAtPosition —
    /// always allowed (preserves Chromium AXGroup clickables, AXImage buttons, etc.).
    /// Depth > 0 is a parent walked via kAXParentAttribute — allowed only for roles in
    /// `interactiveRoles`. This stops rules from matching structural containers
    /// (AXWindow, AXScrollArea, AXGroup wrappers, AXStaticText leaves of a click target).
    ///
    /// Audit reference: BUG #1 — rules matched on parents caused false-positive toasts
    /// when clicking inside notes / chat windows whose ancestor had a semantic description.
    static func shouldRunNonInteractiveLayers(role: String, depth: Int) -> Bool {
        if depth == 0 { return true }
        return interactiveRoles.contains(role)
    }
```

- [ ] **Step 5: Run the new test to verify it now passes**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/ClickWatcherLayerGateTests 2>&1 | grep -E "(Test Case|FAIL|PASS)" | tail -15
```

Expected: all 5 cases pass.

- [ ] **Step 6: Wire the gate into the walk loop**

In `SFlow/ClickWatcher.swift`, find the walk loop starting at `for _ in 0..<6 {` (currently around line 118). We need a counter; change the loop header to:

```swift
            for depth in 0..<6 {
```

Then, **just before** the Layer 0.5 block (currently at line 159, comment `// Layer 0.5: JSON-loaded rules (bundled / LLM cache / user overrides)`), insert this gate so L0.5 and L1 are wrapped:

```swift
                let runNonInteractive = Self.shouldRunNonInteractiveLayers(role: currentRole, depth: depth)

                // Layer 0.5: JSON-loaded rules (bundled / LLM cache / user overrides)
                if runNonInteractive,
                   let result = ruleCache.match(
                    bundleId: bundleId,
                    role: currentRole,
                    title: currentTitle,
                    desc: currentDesc,
                    help: currentHelp.lowercased(),
                    identifier: currentIdentifier
                ) {
                    let autoId = "json:\(bundleId):\(result.keys.joined(separator: "+"))"
                    emit(bundleId: bundleId, shortcutId: autoId,
                         keys: result.keys, hint: result.hint, loc: nsLoc)
                    return
                }

                // Layer 1: hardcoded per-app rules
                if runNonInteractive,
                   let (rule, confidence) = ShortcutRules.match(element: current, bundleId: bundleId,
                                                                  role: roleRef, desc: descRef,
                                                                  title: titleRef, subrole: subroleRef,
                                                                  placeholder: placeholderRef, help: helpRef,
                                                                  identifier: currentIdentifier),
                   confidence >= .threshold {
                    emit(bundleId: bundleId, shortcutId: rule.shortcutId,
                         keys: rule.keys, hint: rule.hint, loc: nsLoc)
                    return
                }
```

**Important:** delete the now-duplicate original L0.5 and L1 blocks (the ones at lines 159-184 before this edit). The replacement above includes them — keep only the gated versions.

Notes about what stays unchanged:
- Layer 0 (AXKeyShortcuts) at lines 150-157 remains ungated.
- Layer 2 (AXHelp) at lines 187-196 already has the `currentHelp.count > 1 || isInteractive` gate; unchanged.
- Layers 3 & 4 already inside `if isInteractive { ... }` block; unchanged.

- [ ] **Step 7: Build and run the full ClickWatcher-relevant test suite**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/ClickWatcherLayerGateTests \
  -only-testing:SFlowTests/ClickWatcherParseTests \
  -only-testing:SFlowTests/RuleCacheTests \
  2>&1 | grep -E "(Test Case|FAIL|PASS|error:)" | tail -30
```

Expected: all pass. The integration of the gate doesn't have a runtime test here (no AX mock infrastructure) — coverage comes from the pure unit test in step 2 plus manual verification.

- [ ] **Step 8: Manual smoke verification**

```bash
xcodebuild -scheme SFlow -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED. Then quit the running SFlow.app if any (Status bar → Quit), launch the freshly built one, and click a button in Slack (e.g. compose). Toast should still appear. Click in the middle of a chat message (NOT a button). Toast should NOT appear — this is the BUG #1 fix in action.

If a smoke regression appears (toast missing for Slack/Notion buttons), revert the loop-header change and re-check the L0.5 block edit — the issue is likely a copy-paste of `runNonInteractive` placement.

- [ ] **Step 9: Commit**

```bash
git add SFlow/ClickWatcher.swift SFlowTests/ClickWatcherLayerGateTests.swift
git commit -m "fix(client): gate L0.5/L1 by depth+isInteractive (BUG #1)

At depth 0 (hit-tested element), all layers run as before — preserves
Chromium AXGroup clickables. At depth > 0 (parents walked via
kAXParentAttribute), L0.5 (RuleCache) and L1 (ShortcutRules) only fire
when the role is in interactiveRoles. Stops false positives when
clicking inside notes/chats matched a parent container's description.

L0 (AXKeyShortcutsValue) stays ungated — explicit developer opt-in.
L2 (AXHelp) and L3/L4 already had their own gates."
```

---

## Task 4: Deterministic, longest-match-wins in MenuBarIndex.lookup

**Files:**
- Modify: `SFlow/MenuBarIndex.swift:68-76`
- Test: `SFlowTests/MenuBarIndexTests.swift`

**Current code (MenuBarIndex.swift:68-76):**
```swift
func lookup(query: String) -> (entry: MenuBarEntry, confidence: MatchConfidence)? {
    guard query.count >= 3 else { return nil }
    let q = query.lowercased()
    if let entry = titleMap[q] { return (entry: entry, confidence: .high) }
    if q.count >= 5, let pair = titleMap.first(where: { $0.key.contains(q) }) {
        return (entry: pair.value, confidence: .medium)
    }
    return nil
}
```

Bugs: (a) `titleMap.first(where:)` iterates a dictionary — order unstable across launches, **same click can match different entries**; (b) `contains` is substring (matches inside words). The fix: collect all candidate keys, filter to word-boundary matches, sort by key length descending (longest = most specific), pick first.

- [ ] **Step 1: Write the failing tests**

Append to `SFlowTests/MenuBarIndexTests.swift`:

```swift
    // MARK: - Determinism + longest-match-wins (BUG #3)

    func test_lookup_longestMatchWins() {
        var index = MenuBarIndex()
        index.insert(title: "Find", keys: ["meta", "f"])
        index.insert(title: "Find in Files", keys: ["meta", "shift", "f"])
        index.insert(title: "Find Next", keys: ["meta", "g"])
        // Query "find in files" should pick the longest containing key
        let r = index.lookup(query: "find in files")
        XCTAssertEqual(r?.entry.keys, ["meta", "shift", "f"], "longest matching key wins")
    }

    func test_lookup_deterministic_acrossManyInserts() {
        // BUG #3 root cause: titleMap.first(where:) iterated a dict — order unstable.
        // After fix, repeated lookups must return the same value.
        var index = MenuBarIndex()
        for i in 1...50 {
            index.insert(title: "Find variant \(i) text", keys: ["meta", "f"])
        }
        index.insert(title: "Find in Files", keys: ["meta", "shift", "f"])
        let first = index.lookup(query: "find in files")
        for _ in 0..<20 {
            let r = index.lookup(query: "find in files")
            XCTAssertEqual(r?.entry.keys, first?.entry.keys, "lookup must be deterministic")
        }
    }

    func test_lookup_wordBoundary_doesNotMatchInsideWord() {
        var index = MenuBarIndex()
        index.insert(title: "Researcher Mode", keys: ["meta", "alt", "r"])
        // Query "search" (6 chars, ≥ 5 threshold) appears inside "researcher" — must NOT match
        XCTAssertNil(index.lookup(query: "search"))
    }

    func test_lookup_wordBoundary_matchesAtStart() {
        var index = MenuBarIndex()
        index.insert(title: "Search Slack", keys: ["meta", "k"])
        let r = index.lookup(query: "search")
        XCTAssertEqual(r?.entry.keys, ["meta", "k"])
        XCTAssertEqual(r?.confidence, .medium)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/MenuBarIndexTests/test_lookup_longestMatchWins \
  -only-testing:SFlowTests/MenuBarIndexTests/test_lookup_wordBoundary_doesNotMatchInsideWord \
  2>&1 | grep -E "(Test Case|FAIL|PASS)" | tail -10
```

Expected: both FAIL. `test_lookup_longestMatchWins` fails because current code picks first dict order, not longest. `test_lookup_wordBoundary_doesNotMatchInsideWord` fails because current `contains` matches inside "researcher".

- [ ] **Step 3: Rewrite MenuBarIndex.lookup**

In `SFlow/MenuBarIndex.swift`, replace the entire `func lookup(query:)` (lines 68-76) with:

```swift
    func lookup(query: String) -> (entry: MenuBarEntry, confidence: MatchConfidence)? {
        guard query.count >= 3 else { return nil }
        let q = query.lowercased()
        if let entry = titleMap[q] { return (entry: entry, confidence: .high) }
        guard q.count >= 5 else { return nil }

        // Collect all keys whose query word-boundary-contains the lookup query.
        // BUG #3: previously used titleMap.first(where:) — dict iteration is unstable.
        // Sort by key length DESC so the most specific (longest) match wins deterministically.
        let candidates = titleMap.keys
            .filter { wordBoundaryContains(haystack: $0, needle: q) }
            .sorted { $0.count > $1.count }
        if let best = candidates.first, let entry = titleMap[best] {
            return (entry: entry, confidence: .medium)
        }
        return nil
    }
```

Note: the **direction** of the word-boundary check matches the original semantic — find keys that contain the query. This is unchanged from the original `$0.key.contains(q)` direction; only the matcher and the sort are new.

- [ ] **Step 4: Run all MenuBarIndex tests to verify they pass**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/MenuBarIndexTests 2>&1 | grep -E "(Test Case|FAIL|PASS|error:)" | tail -30
```

Expected: all pre-existing tests + 4 new tests pass. If `test_lookup_partialTitle` fails (it tests "files" matching "find in files"), verify the test still expects `.medium` — should still pass since "files" is word-boundary-aligned inside "find in files" (preceded by space).

- [ ] **Step 5: Commit**

```bash
git add SFlow/MenuBarIndex.swift SFlowTests/MenuBarIndexTests.swift
git commit -m "fix(client): MenuBarIndex.lookup deterministic, longest-match wins

Replaces titleMap.first(where:) — which iterated a Swift dictionary in
undefined order — with: collect all word-boundary-matching keys, sort
by length descending, pick the longest. Same input now always returns
same output, and 'Find in Files' beats 'Find' when both contain the
query.

Also switches the substring check from String.contains to
wordBoundaryContains, blocking 'search' from matching inside
'researcher'.

Audit reference: BUG #3."
```

---

## Task 5: Add `layer` field to ShortcutEvent

**Files:**
- Modify: `SFlow/ShortcutEvent.swift`
- Test: indirect via Task 7 EventLogger test (no test for the struct itself; trivial)

This is a pure data-shape change. Task 6 wires emitters; Task 7 wires the writer.

- [ ] **Step 1: Modify ShortcutEvent**

Replace the entire `SFlow/ShortcutEvent.swift` with:

```swift
import Foundation

/// Identifies which recognition layer produced a shortcut event.
/// Used for per-layer hit-rate telemetry (Phase 1.5 of roadmap).
enum RecognitionLayer: String {
    case axKeyShortcuts = "L0"     // AXKeyShortcutsValue attribute
    case ruleCache      = "L0.5"   // bundled.json / cache / user overrides
    case shortcutRules  = "L1"     // hardcoded ShortcutRules.rules
    case axHelp         = "L2"     // kAXHelpAttribute auto-parse
    case menuBarIndex   = "L3"     // MenuBarIndex fuzzy lookup
    case universal      = "L4"     // ShortcutRules.universalRules
    case menuItem       = "menu"   // direct menu bar item click
    case menuItemFallback = "menu-fallback" // checkMenuBar non-AXMenuItem path
}

struct ShortcutEvent {
    let bundleId: String
    let shortcutId: String
    let keys: [String]
    let hint: String
    let mouseX: Double
    let mouseY: Double
    let layer: RecognitionLayer
}
```

- [ ] **Step 2: Build to surface compile errors**

```bash
xcodebuild -scheme SFlow -destination 'platform=macOS' build 2>&1 | grep -E "error:" | head -20
```

Expected: compile errors at every `ShortcutEvent(...)` call site — they don't pass `layer`. Note the call sites; they're handled in Task 6.

Known call sites that will need updating (verify with grep):
```bash
grep -rn "ShortcutEvent(" SFlow/ SFlowTests/
```

Expected hits in:
- `SFlow/ClickWatcher.swift` — inside `emit(...)` constructor (line ~342)
- `SFlow/AppDelegate.swift:80` — `showTestToast()`
- `SFlowTests/EventLoggerTests.swift` — fixture(s)
- Any other test fixtures using `ShortcutEvent`

Do not fix them in this task — they're handled in Tasks 6 and 7.

- [ ] **Step 3: Do not commit yet**

This task leaves the build broken on purpose. Task 6 fixes the producer, Task 7 fixes the writer, both required before the build is green again. Commit happens at the end of Task 7. If you must stop here, run `git stash` to preserve.

---

## Task 6: Pass `layer` from ClickWatcher.emit()

**Files:**
- Modify: `SFlow/ClickWatcher.swift` (multiple call sites of `emit(...)` and the `emit` function signature itself)

The `emit(...)` private helper is called from 7 places in ClickWatcher (L0, L0.5, L1, L2, L3, L4, and the two menu-bar paths inside `checkMenuBar`). Each needs to declare which layer it represents.

- [ ] **Step 1: Update the emit signature**

In `SFlow/ClickWatcher.swift`, find the `private func emit(...)` near the bottom (currently around line 336). Replace it with:

```swift
    private func emit(bundleId: String, shortcutId: String, keys: [String],
                      hint: String, loc: NSPoint, layer: RecognitionLayer) {
        let now = Date()
        guard shortcutId != lastShortcutId || now.timeIntervalSince(lastShortcutTime) >= 2.0 else { return }
        lastShortcutId = shortcutId
        lastShortcutTime = now
        let event = ShortcutEvent(bundleId: bundleId, shortcutId: shortcutId,
                                  keys: keys, hint: hint,
                                  mouseX: loc.x, mouseY: loc.y,
                                  layer: layer)
        onEvent(event)
        emitFiredInCurrentClick = true
    }
```

- [ ] **Step 2: Update each call site with the appropriate layer tag**

In `SFlow/ClickWatcher.swift`, locate each `emit(bundleId: ...)` call inside `handleMouseDown` and `checkMenuBar`. Apply these layer tags (search for each `emit(` and add `layer:` as the last argument):

| Location | Layer |
|---|---|
| Line ~155 (Layer 0 — `if !currentKeyShortcuts.isEmpty...`) | `.axKeyShortcuts` |
| Line ~168 (Layer 0.5 — `if let result = ruleCache.match(...)`) | `.ruleCache` |
| Line ~181 (Layer 1 — `if let (rule, confidence) = ShortcutRules.match(...)`) | `.shortcutRules` |
| Line ~191 (Layer 2 — `if !currentHelp.isEmpty...`) | `.axHelp` |
| Line ~207 (Layer 3 — `if !query.isEmpty, let (entry, ...)`) | `.menuBarIndex` |
| Line ~217 (Layer 4 — `if let rule = ShortcutRules.universalRules.first(...)`) | `.universal` |
| Inside `checkMenuBar`, line ~313 (non-AXMenuItem `if let (rule, _) = ShortcutRules.match`) | `.menuItemFallback` |
| Inside `checkMenuBar`, line ~333 (AXMenuItem branch — `emit(...)` at end) | `.menuItem` |

Each call changes from:
```swift
emit(bundleId: bundleId, shortcutId: ..., keys: ..., hint: ..., loc: nsLoc)
```
to:
```swift
emit(bundleId: bundleId, shortcutId: ..., keys: ..., hint: ..., loc: nsLoc, layer: .ruleCache)
```
(or whichever layer applies per the table).

- [ ] **Step 3: Build to verify ClickWatcher compiles**

```bash
xcodebuild -scheme SFlow -destination 'platform=macOS' build 2>&1 | grep -E "error:" | head -20
```

Expected: errors remaining only in `AppDelegate.swift:80` and test fixtures — those are fixed in Task 7. ClickWatcher.swift should be clean.

If errors still show in ClickWatcher (likely "missing argument 'layer'"), you missed a call site; grep for `emit(bundleId:` inside `ClickWatcher.swift` and fix the missed one.

- [ ] **Step 4: Do not commit yet** — continues in Task 7.

---

## Task 7: Write `layer` to events.jsonl + fix remaining call sites

**Files:**
- Modify: `SFlow/EventLogger.swift`
- Modify: `SFlow/AppDelegate.swift:80` — `showTestToast()`
- Modify: `SFlowTests/EventLoggerTests.swift` — assertion that `layer` is in output + fixture updates

- [ ] **Step 1: Update EventLogger.log to write the layer field**

In `SFlow/EventLogger.swift`, replace the `log(event:to:)` method (currently lines 38-51) with:

```swift
    static func log(event: ShortcutEvent, to url: URL) {
        let formatter = ISO8601DateFormatter()
        let entry: [String: Any] = [
            "type":       "toast",
            "timestamp":  formatter.string(from: Date()),
            "bundleId":   event.bundleId,
            "shortcutId": event.shortcutId,
            "keys":       event.keys,
            "hint":       event.hint,
            "mouseX":     event.mouseX,
            "mouseY":     event.mouseY,
            "layer":      event.layer.rawValue,
        ]
        write(entry, to: url)
    }
```

Also update `logFalsePositive(event:to:)` (currently lines 76-87) to include `layer` (a false-positive about which layer fired is the most valuable kind):

```swift
    static func logFalsePositive(event: ShortcutEvent, to url: URL) {
        let formatter = ISO8601DateFormatter()
        let entry: [String: Any] = [
            "type":       "false_positive",
            "timestamp":  formatter.string(from: Date()),
            "bundleId":   event.bundleId,
            "shortcutId": event.shortcutId,
            "keys":       event.keys,
            "hint":       event.hint,
            "layer":      event.layer.rawValue,
        ]
        write(entry, to: url)
    }
```

- [ ] **Step 2: Fix the AppDelegate test-toast call site**

In `SFlow/AppDelegate.swift`, find `showTestToast()` (line ~77). The `ShortcutEvent(...)` constructor on line 80 is missing `layer`. Replace the `let event = ShortcutEvent(...)` line with:

```swift
        let event = ShortcutEvent(bundleId: "test", shortcutId: "test",
                                  keys: ["meta", "k"], hint: "Test Toast",
                                  mouseX: center.x, mouseY: center.y,
                                  layer: .ruleCache)
```

The `.ruleCache` choice is arbitrary — it's a manual test toast.

- [ ] **Step 3: Write the failing test for the layer field in JSONL**

Open `SFlowTests/EventLoggerTests.swift`. First check the existing test fixture shape:

```bash
sed -n '1,60p' SFlowTests/EventLoggerTests.swift
```

Locate an existing test that constructs a `ShortcutEvent` and add this new test after it (inside the same `XCTestCase` class):

```swift
    func test_log_includesLayerField() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sflow-test-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let event = ShortcutEvent(
            bundleId: "com.test", shortcutId: "x", keys: ["meta","k"], hint: "Test",
            mouseX: 0, mouseY: 0, layer: .ruleCache
        )
        EventLogger.log(event: event, to: tempURL)
        EventLogger.flush()

        let content = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertTrue(content.contains("\"layer\":\"L0.5\""),
                      "events.jsonl line must contain layer field; got: \(content)")
    }

    func test_log_includesCorrectLayerForEachVariant() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sflow-test-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let cases: [(RecognitionLayer, String)] = [
            (.axKeyShortcuts, "L0"),
            (.ruleCache, "L0.5"),
            (.shortcutRules, "L1"),
            (.axHelp, "L2"),
            (.menuBarIndex, "L3"),
            (.universal, "L4"),
            (.menuItem, "menu"),
        ]
        for (layer, expected) in cases {
            let event = ShortcutEvent(
                bundleId: "com.test", shortcutId: "x", keys: ["k"], hint: "h",
                mouseX: 0, mouseY: 0, layer: layer
            )
            EventLogger.log(event: event, to: tempURL)
        }
        EventLogger.flush()

        let content = try String(contentsOf: tempURL, encoding: .utf8)
        for (_, expected) in cases {
            XCTAssertTrue(content.contains("\"layer\":\"\(expected)\""),
                          "missing layer=\(expected) in output: \(content)")
        }
    }
```

- [ ] **Step 4: Fix any pre-existing test fixtures that construct ShortcutEvent**

```bash
grep -rn "ShortcutEvent(" SFlowTests/ | grep -v "layer:"
```

For each match, add `, layer: .ruleCache` (any layer works — these are fixtures) before the closing `)`. Examples to look for: existing `EventLoggerTests` cases that construct events, any other fixture file.

- [ ] **Step 5: Run the full test suite**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' 2>&1 | tail -50
```

Expected: all tests pass. Common failures and fixes:
- `error: missing argument for parameter 'layer'` → grep missed a constructor; add `layer: .ruleCache`.
- A test reading old-shape JSON breaks → that's expected if a test parsed events.jsonl with strict schema; update the test to accept the new field.

- [ ] **Step 6: Commit the whole telemetry chain (Tasks 5 + 6 + 7)**

```bash
git add SFlow/ShortcutEvent.swift SFlow/ClickWatcher.swift SFlow/EventLogger.swift SFlow/AppDelegate.swift SFlowTests/EventLoggerTests.swift
git commit -m "feat(client): per-layer telemetry in ShortcutEvent

Adds RecognitionLayer enum (L0/L0.5/L1/L2/L3/L4/menu) to ShortcutEvent.
Every emit() call in ClickWatcher tags the layer that produced it.
EventLogger writes 'layer' field into events.jsonl for both 'toast' and
'false_positive' entries.

Unlocks per-layer hit-rate analysis without a backend roundtrip: a
simple jq query on events.jsonl now answers 'which layer fires most for
each app' and 'which layer dominates false positives'."
```

---

## Task 8: AXSkeletonExtractor — keep single-occurrence noun-led titles

**Files:**
- Modify: `SFlow/AXSkeletonExtractor.swift:67-68`
- Test: `SFlowTests/AXSkeletonFilterTests.swift`

**Current code (AXSkeletonExtractor.swift:65-72):**
```swift
let title = item.title.trimmingCharacters(in: .whitespaces)
if title.isEmpty || title.count > maxTitleLen { continue }
if startsWithSensitivePrefix(title) { continue }
if looksLikeEmail(title) { continue }
if looksLikeISODate(title) { continue }
if looksLikePureDigits(title) { continue }
if looksLikeHumanName(title) { continue }

let count = counts[item] ?? 1
if count < 2 && !looksVerbLed(title) { continue }     // ← the over-aggressive filter
```

The filter drops every single-occurrence title whose first word isn't a verb. This kills useful UI labels like "Quick Switcher", "Preferences", "Mentions", "Settings", "Inbox", "Saved Items" before they reach the LLM prompt. Without them, no rules get generated and toast doesn't fire.

**Fix:** keep single-occurrence titles. The other regex filters (email/date/digits/human-name) already remove the noisy long-tail (search results, user names, etc.). The `count < 2` filter was over-applying.

- [ ] **Step 1: Confirm current test expectations**

```bash
sed -n '1,80p' SFlowTests/AXSkeletonFilterTests.swift
```

Locate any test that asserts a single-occurrence noun-led title is dropped (e.g. expects an empty `filter` output for `[RawAXItem(role: "AXButton", title: "Quick Switcher")]`). That test, if it exists, codifies the buggy behavior — it'll need updating in Step 3.

- [ ] **Step 2: Write the failing test**

Append to `SFlowTests/AXSkeletonFilterTests.swift`:

```swift
    // MARK: - Single-occurrence noun-led titles must survive (BUG B1)

    func test_filter_keepsSingleOccurrenceNounLedTitle_QuickSwitcher() {
        let items = [RawAXItem(role: "AXButton", title: "Quick Switcher")]
        let result = AXSkeletonExtractor.filter(rawItems: items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Quick Switcher")
    }

    func test_filter_keepsSingleOccurrencePreferences() {
        let items = [RawAXItem(role: "AXMenuItem", title: "Preferences")]
        let result = AXSkeletonExtractor.filter(rawItems: items)
        XCTAssertEqual(result.count, 1)
    }

    func test_filter_keepsSingleOccurrenceMentions() {
        let items = [RawAXItem(role: "AXButton", title: "Mentions & Reactions")]
        let result = AXSkeletonExtractor.filter(rawItems: items)
        XCTAssertEqual(result.count, 1)
    }

    func test_filter_stillDropsEmail() {
        // Sanity: other filters not affected
        let items = [RawAXItem(role: "AXButton", title: "user@example.com")]
        XCTAssertEqual(AXSkeletonExtractor.filter(rawItems: items).count, 0)
    }

    func test_filter_stillDropsHumanName() {
        let items = [RawAXItem(role: "AXButton", title: "John Smith")]
        XCTAssertEqual(AXSkeletonExtractor.filter(rawItems: items).count, 0)
    }
```

- [ ] **Step 3: Run tests to verify failure**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/AXSkeletonFilterTests 2>&1 | grep -E "(Test Case|FAIL|PASS)" | tail -15
```

Expected: the three "keepsSingleOccurrence..." tests FAIL (current filter drops them); the two "stillDrops..." tests PASS (regression sanity).

If a pre-existing test like `test_filter_dropsSingleOccurrenceNounLed` exists and currently passes (codifying the buggy behavior), delete it — its premise is wrong. Mention this deletion in the commit message.

- [ ] **Step 4: Modify the filter**

In `SFlow/AXSkeletonExtractor.swift`, locate lines 67-68 (the `let count = counts[item] ...; if count < 2 && !looksVerbLed(title) { continue }` block). Replace those two lines with: delete them entirely. The filter cascade above (sensitive prefix, email, date, digits, human name) is enough; the `count < 2` filter was over-applying.

The block now reads:
```swift
            let title = item.title.trimmingCharacters(in: .whitespaces)
            if title.isEmpty || title.count > maxTitleLen { continue }
            if startsWithSensitivePrefix(title) { continue }
            if looksLikeEmail(title) { continue }
            if looksLikeISODate(title) { continue }
            if looksLikePureDigits(title) { continue }
            if looksLikeHumanName(title) { continue }

            result.append(SkeletonItem(role: item.role, title: title, identifier: item.identifier))
            if result.count >= maxItems { break }
        }
```

Note: the `counts` dictionary and `looksVerbLed` helper become unused by this code path. **Keep them** — `looksVerbLed` is still referenced from inside `looksLikeHumanName` (to distinguish "Send Message" from "John Smith"). Leave `counts` declaration too if it's referenced elsewhere; otherwise delete it. Quick check:

```bash
grep -n "counts\b" SFlow/AXSkeletonExtractor.swift
```

If `counts` is only set up at line 46-49 (`var counts: [RawAXItem: Int] = [:]; for item in rawItems where allowedRoles.contains(item.role) { counts[item, default: 0] += 1 }`) and not referenced anywhere else, delete those 4 lines.

- [ ] **Step 5: Run all skeleton tests**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/AXSkeletonFilterTests 2>&1 | grep -E "(Test Case|FAIL|PASS)" | tail -20
```

Expected: all tests pass — the 5 new ones plus pre-existing.

- [ ] **Step 6: Commit**

```bash
git add SFlow/AXSkeletonExtractor.swift SFlowTests/AXSkeletonFilterTests.swift
git commit -m "fix(client): keep single-occurrence noun-led skeleton titles (BUG B1)

Drops the count<2 && !looksVerbLed filter that was silently removing
useful UI labels like 'Quick Switcher', 'Preferences', 'Mentions',
'Settings' before they reached the LLM. Email/date/digits/human-name
filters above are enough.

Next /v1/discover call for any app will see ~30-50% more candidate
elements; LLM produces broader rule coverage."
```

---

## Task 9: Full-suite verification + roadmap update

**Files:**
- Modify: `docs/roadmap.md` — add session log entry
- Modify: `docs/audit-phase-0.md` — update statuses of BUG #1, #2, #3, B1 (if listed)

- [ ] **Step 1: Run the full test suite**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' 2>&1 | tail -30
```

Expected: zero failures, zero errors. Note the total test count for the commit message.

- [ ] **Step 2: Manual smoke test (10 min)**

Quit any running SFlow, build the new app:
```bash
xcodebuild -scheme SFlow -destination 'platform=macOS' build 2>&1 | tail -5
```

Then launch the freshly built binary (from DerivedData or the project dir). For each:

1. **Slack** — click compose button → toast appears with the right shortcut. Click inside a chat message (text) → NO toast. Click "Search Slack" field → toast for ⌘K.
2. **Notion** — click "Home" in sidebar → toast for ⌘⌥G. Click inside a page (paragraph text) → NO toast.
3. **Open `~/Library/Application Support/SFlow/events.jsonl`** in any text editor → confirm every "toast" line has a `"layer":` field with one of the expected values (L0, L0.5, L1, L2, L3, L4, menu).

If any of the three checks regress, the relevant task's manual step (3.8, 4.4, etc.) was missed. Re-read the diff for that task and verify it lines up with the plan.

- [ ] **Step 3: Add session log entry to roadmap.md**

Open `docs/roadmap.md`. Find the **Session log** section (around line 102). Insert a new entry at the top of the log (after the "Reverse-chronological" note, before the existing 2026-05-14 entry):

```markdown
### 2026-05-14 — Sesja 5: Matching engine quality

**Co:** 4 fixy w trybie rozpoznawania klikniec + telemetria per-layer.
(1) `wordBoundaryContains` utility + użyte w RuleCache i MenuBarIndex — "search" nie matchuje już wewnątrz "research" (BUG #2).
(2) `ClickWatcher.shouldRunNonInteractiveLayers` — L0.5 i L1 nie strzelają na rodziców powyżej depth 0 chyba że role jest interaktywna (BUG #1).
(3) `MenuBarIndex.lookup` deterministyczny — sortuje po długości klucza desc, najdłuższy match wygrywa (BUG #3).
(4) `AXSkeletonExtractor.filter` przestaje zrzucać single-occurrence noun-led titles ("Quick Switcher", "Preferences") (BUG B1).
(5) `RecognitionLayer` enum + `layer` field w `ShortcutEvent` i `events.jsonl` — telemetria per-layer.

**Dlaczego:** audyt 2026-05-14 wskazał te 4 bugi jako fundamentalne dla "wrażenia że niektóre elementy są pomijane / źle przypisywane". Bez nich Faza 2-6 buduje na piasku.

**Wpływ:** Substring false-positives wyeliminowane. Strukturalne rodzice (AXWindow, AXScrollArea, AXGroup-bez-interactive-roli) nie odpalają toastów. Deterministyczne matche w MenuBarIndex. Skeletony obejmują ~30-50% więcej elementów (impact widoczny po następnym discoverze). Per-layer telemetry otwiera drogę do data-driven iteracji prompta.

**Commits:** *(uzupełnij SHA przy commit'cie)*
```

- [ ] **Step 4: Run the full suite one last time + ensure git status is clean**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' 2>&1 | grep -E "Test Suite '.*' (passed|failed)" | tail -5
git status
```

Expected: all test suites passed; `git status` shows only the staged docs/roadmap.md change.

- [ ] **Step 5: Commit the docs**

```bash
git add docs/roadmap.md
git commit -m "docs: session 5 — matching engine quality (BUG #1, #2, #3, B1 + telemetry)"
```

---

## Self-review (run after writing the plan, before handoff)

**Spec coverage** — each audit finding ↔ task:
- BUG #1 (parent matching) → Task 3
- BUG #2 (substring contains) → Tasks 1 + 2
- BUG #3 (non-deterministic lookup) → Tasks 1 + 4
- BUG #4 (AXGroup permissive) → Task 3 makes this irrelevant (depth gate prevents the bad path; AXGroup at depth 0 is a legitimate Chromium clickable)
- BUG B1 (skeleton over-filter) → Task 8
- Telemetry → Tasks 5 + 6 + 7

**Out of scope (explicitly):** prompt rework, score-based matcher, retry/backoff, negative rules. These belong in separate plans once telemetry is collecting.

**Type consistency check:**
- `wordBoundaryContains(haystack:needle:)` signature identical across Tasks 1, 2, 4.
- `RecognitionLayer` cases used in Task 5 referenced in Task 6 (.axKeyShortcuts, .ruleCache, .shortcutRules, .axHelp, .menuBarIndex, .universal, .menuItem, .menuItemFallback) and Task 7 ("L0.5" rawValue assertion). All present in Task 5 enum.
- `ShortcutEvent` constructor signature gains `layer:` in Task 5; updated at every call site in Tasks 6 and 7.

**Placeholder scan:** no "TBD", "TODO", "implement later". Every code block contains the actual code. Every command is runnable.
