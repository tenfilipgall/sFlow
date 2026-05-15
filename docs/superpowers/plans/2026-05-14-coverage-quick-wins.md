# Coverage Quick Wins Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the **detection surface** — i.e. "how many clickable elements SFlow sees" — via 3 additive fixes that don't require usage-data analysis. Each fix is independent; each commits separately. Together expected ~30-50% coverage boost.

**Architecture:** All client-side, additive. No backend changes. No new files. Each fix is a small modification in `ClickWatcher.swift` + (for Fix 3) `RuleCache.swift`. TDD where pure logic is testable; manual smoke where AX-API-dependent.

**Background:**
- **Fix 1 — AXPress probe:** `AXUIElementCopyActionNames` returns the list of actions an AX element supports. If it contains `AXPress`, the element is clickable **regardless of role**. Catches Chromium widgets that wrap clickable image/text nodes as AXGroup/AXImage but register AXPress on them.
- **Fix 2 — Walk-down:** when walking-up finds a clickable ancestor with empty title/desc, scan direct children for the first non-empty label. Common Chromium pattern: AXButton wraps AXImage where the icon's `desc` has the action name.
- **Fix 3 — AXRoleDescription + AXCustomActions:** two AX attributes we don't read. RoleDescription often holds language-independent action label ("compose button"). CustomActions is an array of named actions (modern Mac apps). Both become additional title candidates in `RuleCache.match`.

**Out of scope:** AppleScript sdef parser, GitHub code-search, Help→Shortcuts auto-scrape, keystroke monitoring, sesja 7 data-driven analysis (those are bigger; come after this).

---

## File Structure
**Modify:**
- `SFlow/ClickWatcher.swift` — new helpers `elementHasAXPress`, `extractFallbackTitleFromChildren`, `extractCustomActionNames`; reads AXRoleDescription + AXCustomActions; passes to RuleCache.match; gate signature extended
- `SFlow/RuleCache.swift` — `match` gains `roleDescription:` and `customActions:` parameters; word-boundary checks extended
- `SFlowTests/ClickWatcherLayerGateTests.swift` — add AXPress-aware gate tests; update existing 5 calls
- `SFlowTests/RuleCacheTests.swift` — add 3 new match tests for roleDescription/customActions

**Test command throughout:**
```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" \
  -only-testing:SFlowTests/<ClassName>/<methodName>
```

---

## Task 1: AXPress probe

**Files:**
- Modify: `SFlow/ClickWatcher.swift`
- Modify: `SFlowTests/ClickWatcherLayerGateTests.swift`

**Idea:** Extend `shouldRunNonInteractiveLayers(role:depth:)` to also take `hasAXPress: Bool`. Pure logic stays simple. Real `AXUIElementCopyActionNames` call lives in a separate helper.

### Steps

- [ ] **Step 1: Update existing 5 gate tests + add 3 new**

In `SFlowTests/ClickWatcherLayerGateTests.swift`, every existing call to `ClickWatcher.shouldRunNonInteractiveLayers(role:depth:)` must be updated to add `hasAXPress: false` so it still compiles. There are 5 pre-existing calls inside the test methods — add `, hasAXPress: false` before the closing `)`.

Then append the new test section:

```swift
    // MARK: - AXPress probe (Coverage QW Fix 1)

    func test_axPress_overridesNonInteractiveRoleAtDepthZero() {
        // Depth 0 always allowed regardless — but verify hasAXPress flag doesn't break
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXImage", depth: 0, hasAXPress: true))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXImage", depth: 0, hasAXPress: false))
    }

    func test_axPress_allowsStructuralRoleAtDeeperDepth() {
        // AXImage/AXGroup/AXStaticText with AXPress should be treated as interactive
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXImage", depth: 1, hasAXPress: true))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXGroup", depth: 2, hasAXPress: true))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXStaticText", depth: 3, hasAXPress: true))
    }

    func test_noAxPress_stillBlocksStructuralAtDepth() {
        // Sanity: without AXPress, structural roles at depth>0 stay blocked
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXImage", depth: 1, hasAXPress: false))
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXGroup", depth: 1, hasAXPress: false))
    }
```

- [ ] **Step 2: Run gate tests to confirm build failure (signature mismatch)**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" \
  -only-testing:SFlowTests/ClickWatcherLayerGateTests 2>&1 | grep -E "(error:|FAIL)" | head -10
```

Expected: errors about missing `hasAXPress` parameter.

- [ ] **Step 3: Modify `shouldRunNonInteractiveLayers` signature**

In `SFlow/ClickWatcher.swift`, change:
```swift
static func shouldRunNonInteractiveLayers(role: String, depth: Int) -> Bool {
    if depth == 0 { return true }
    return interactiveRoles.contains(role)
}
```
to:
```swift
static func shouldRunNonInteractiveLayers(role: String, depth: Int, hasAXPress: Bool) -> Bool {
    if depth == 0 { return true }
    return interactiveRoles.contains(role) || hasAXPress
}
```

Update the doc comment above to mention `hasAXPress` as the dynamic override.

- [ ] **Step 4: Add `elementHasAXPress` helper**

Inside the `ClickWatcher` class, near other helpers:
```swift
    /// Returns true if the AX element registers "AXPress" as a supported action.
    /// AXUIElementCopyActionNames returns actions the element can perform regardless
    /// of its AXRole. AXPress means "this element responds to being clicked" — catches
    /// Chromium widgets that wrap clickables as AXGroup/AXImage but register AXPress.
    static func elementHasAXPress(_ element: AXUIElement) -> Bool {
        var names: CFArray?
        let result = AXUIElementCopyActionNames(element, &names)
        guard result == .success, let arr = names as? [String] else { return false }
        return arr.contains("AXPress")
    }
```

- [ ] **Step 5: Wire into walk loop**

In `handleMouseDown`, find:
```swift
let runNonInteractive = Self.shouldRunNonInteractiveLayers(role: currentRole, depth: depth)
```
Replace with:
```swift
let hasAXPress = Self.elementHasAXPress(current)
let runNonInteractive = Self.shouldRunNonInteractiveLayers(role: currentRole, depth: depth, hasAXPress: hasAXPress)
```

- [ ] **Step 6: Run tests + build**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" \
  -only-testing:SFlowTests/ClickWatcherLayerGateTests 2>&1 | grep -E "(Test Case|FAIL|PASS)" | tail -15
```

Expected: 8 cases pass (5 updated + 3 new).

```bash
xcodebuild -scheme SFlow -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" \
  build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add SFlow/ClickWatcher.swift SFlowTests/ClickWatcherLayerGateTests.swift
git commit -m "feat(client): AXPress probe expands detection surface

shouldRunNonInteractiveLayers now accepts hasAXPress. If element exposes
AXPress as an accessibility action, it's treated as interactive at any
depth — catches Chromium widgets (AXImage/AXGroup/AXStaticText) that
register press actions but don't have interactive roles.

Coverage QW Fix 1 of 3."
```

---

## Task 2: Walk-down for empty-titled clickable

**Files:** `SFlow/ClickWatcher.swift` (helper + integration). No unit test (AX-dependent — manual smoke).

**Idea:** When walking-up finds a clickable element (interactive role or AXPress) BUT its `title` AND `desc` are both empty, scan its direct children (max 5, no recursion) for the first non-empty title or desc. Use those values for matching.

### Steps

- [ ] **Step 1: Add helper**

In `ClickWatcher.swift` private static area:
```swift
    /// When a clickable ancestor has empty title/desc, scan its direct children
    /// for the first non-empty label. Common Chromium pattern: AXButton wraps
    /// AXImage where the icon's desc has the actual action name.
    /// Limited to 5 children, no recursion — fast hot-path read.
    static func extractFallbackTitleFromChildren(_ element: AXUIElement) -> (title: String, desc: String) {
        var childrenRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        guard let children = childrenRef as? [AXUIElement] else { return ("", "") }

        for child in children.prefix(5) {
            var titleRef: AnyObject?
            var descRef: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef)
            AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &descRef)
            let title = titleRef as? String ?? ""
            let desc = descRef as? String ?? ""
            if !title.isEmpty || !desc.isEmpty {
                return (title, desc)
            }
        }
        return ("", "")
    }
```

- [ ] **Step 2: Wire into walk loop**

In `handleMouseDown`, after the attribute-reading block AND after the `runNonInteractive`/`hasAXPress` computation, BEFORE the Layer 0.5 block, add:

```swift
                var effectiveTitle = currentTitle
                var effectiveDesc = currentDesc
                if effectiveTitle.isEmpty, effectiveDesc.isEmpty, runNonInteractive, depth > 0 {
                    let fallback = Self.extractFallbackTitleFromChildren(current)
                    if !fallback.title.isEmpty || !fallback.desc.isEmpty {
                        effectiveTitle = fallback.title.lowercased()
                        effectiveDesc = fallback.desc.lowercased()
                    }
                }
```

Then in the L0.5 ruleCache.match call, replace `title: currentTitle` with `title: effectiveTitle` and `desc: currentDesc` with `desc: effectiveDesc`.

L1 (ShortcutRules.match) takes AnyObject refs directly — leave unchanged (it would require deeper refactor; not in scope).

- [ ] **Step 3: Build + manual smoke**

```bash
xcodebuild -scheme SFlow -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" \
  build 2>&1 | tail -5
```

Build must succeed. Note in report: walk-down code path activates only when (effectiveTitle empty AND effectiveDesc empty AND runNonInteractive AND depth > 0). Most clicks don't hit this — performance impact minimal.

- [ ] **Step 4: Run existing tests still pass**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" \
  2>&1 | grep -E "Test Suite '.*' (passed|failed)" | tail -5
```

Expected: zero failures. No new tests added (AX-dependent — covered by manual usage).

- [ ] **Step 5: Commit**

```bash
git add SFlow/ClickWatcher.swift
git commit -m "feat(client): walk-down extracts fallback title from clickable's children

When walking up the AX tree finds an interactive ancestor (or AXPress
element) with empty title AND desc, scan its direct children (max 5,
no recursion) for the first non-empty label. Catches Chromium pattern:
AXButton wraps AXImage where the icon's desc has the action name.

Only activates at depth>0 when both title and desc are empty AND the
gate already approved the layer for non-interactive match — so the
extra walk happens rarely and stays off the hot path.

Coverage QW Fix 2 of 3."
```

---

## Task 3: AXRoleDescription + AXCustomActions matching

**Files:** `SFlow/ClickWatcher.swift`, `SFlow/RuleCache.swift`, `SFlowTests/RuleCacheTests.swift`.

**Idea:** Read two more AX attributes per element. Pass to `RuleCache.match` as additional title candidates checked via `wordBoundaryContains`.

### Steps

- [ ] **Step 1: Add failing tests**

Append to `SFlowTests/RuleCacheTests.swift` before closing brace:

```swift
    // MARK: - RoleDescription + CustomActions match (Coverage QW Fix 3)

    func testRoleDescriptionMatches() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("compose", keys: ["meta", "n"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        // Empty title/desc, but AXRoleDescription says "compose button"
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "", desc: "", help: "",
                                 roleDescription: "compose button")
        XCTAssertEqual(result?.keys, ["meta", "n"])
    }

    func testCustomActionsMatches() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("send message", keys: ["meta", "enter"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        // Empty title, but registers "Send message" as a custom action name
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "", desc: "", help: "",
                                 customActions: ["Send message", "Save draft"])
        XCTAssertEqual(result?.keys, ["meta", "enter"])
    }

    func testRoleDescriptionWordBoundaryRespected() throws {
        // Word-boundary still respected for roleDescription — no "search" in "researcher"
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("search", keys: ["meta", "k"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "", desc: "", help: "",
                                 roleDescription: "researcher tools")
        XCTAssertNil(result)
    }
```

- [ ] **Step 2: Run failing tests**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" \
  -only-testing:SFlowTests/RuleCacheTests/testRoleDescriptionMatches \
  -only-testing:SFlowTests/RuleCacheTests/testCustomActionsMatches \
  -only-testing:SFlowTests/RuleCacheTests/testRoleDescriptionWordBoundaryRespected \
  2>&1 | grep -E "(Test Case|FAIL|PASS|error:)" | tail -10
```

Expected: 3 build errors — RuleCache.match doesn't accept `roleDescription` or `customActions` yet.

- [ ] **Step 3: Extend RuleCache.match signature**

In `SFlow/RuleCache.swift`, change `match` signature from:
```swift
func match(bundleId: String, role: String, title: String, desc: String, help: String,
           identifier: String = "") -> MatchResult? {
```
to:
```swift
func match(bundleId: String, role: String, title: String, desc: String, help: String,
           identifier: String = "",
           roleDescription: String = "",
           customActions: [String] = []) -> MatchResult? {
```

Add local lowercase versions at the top of the function (near `titleLC`/`descLC`/`helpLC`):
```swift
        let roleDescLC = roleDescription.lowercased()
        let customActionsLC = customActions.map { $0.lowercased() }
```

In the title-matching closure (the `let titleMatches = rule.match.titles.contains { candidate in ... }` block), extend the equality and word-boundary checks. After the existing `if titleLC == c || descLC == c || helpLC == c { return true }` line, add `|| roleDescLC == c`. After the existing wordBoundaryContains chain for title/desc/help, add:

```swift
                if wordBoundaryContains(haystack: roleDescLC, needle: c) { return true }
                if customActionsLC.contains(c) { return true }
                if customActionsLC.contains(where: { wordBoundaryContains(haystack: $0, needle: c) }) { return true }
```

Final shape of the closure:
```swift
            let titleMatches = rule.match.titles.contains { candidate in
                let c = candidate.lowercased()
                if c.isEmpty { return false }
                if titleLC == c || descLC == c || helpLC == c || roleDescLC == c { return true }
                if customActionsLC.contains(c) { return true }
                if wordBoundaryContains(haystack: titleLC, needle: c) { return true }
                if wordBoundaryContains(haystack: descLC,  needle: c) { return true }
                if wordBoundaryContains(haystack: helpLC,  needle: c) { return true }
                if wordBoundaryContains(haystack: roleDescLC, needle: c) { return true }
                if customActionsLC.contains(where: { wordBoundaryContains(haystack: $0, needle: c) }) { return true }
                if let stripped = titleStripped {
                    if stripped == c { return true }
                    if wordBoundaryContains(haystack: stripped, needle: c) { return true }
                }
                return false
            }
```

- [ ] **Step 4: Read attributes in ClickWatcher**

In `handleMouseDown`, in the AX attribute-reading block (near other `AXUIElementCopyAttributeValue` calls), add:

```swift
                var roleDescRef: AnyObject?
                var customActionsRef: AnyObject?
                AXUIElementCopyAttributeValue(current, kAXRoleDescriptionAttribute as CFString, &roleDescRef)
                AXUIElementCopyAttributeValue(current, "AXCustomActions" as CFString, &customActionsRef)
                let currentRoleDescription = (roleDescRef as? String ?? "").lowercased()
                let currentCustomActions = Self.extractCustomActionNames(from: customActionsRef)
```

Then add the helper static function on ClickWatcher class. AXCustomActions can come in several shapes depending on macOS version; be defensive:

```swift
    /// AXCustomActions attribute returns an array whose element shape varies by
    /// macOS version: sometimes [String], sometimes [NSAccessibilityCustomAction]
    /// (which has a `.name` property), sometimes a dictionary. Try each shape.
    static func extractCustomActionNames(from raw: AnyObject?) -> [String] {
        guard let arr = raw as? [Any] else { return [] }
        var result: [String] = []
        for item in arr {
            if let s = item as? String {
                result.append(s)
            } else if let d = item as? [String: Any],
                      let name = (d["AXName"] as? String) ?? (d["name"] as? String) {
                result.append(name)
            } else if let obj = item as? NSObject,
                      let name = obj.value(forKey: "name") as? String {
                result.append(name)
            }
        }
        return result
    }
```

- [ ] **Step 5: Pass to RuleCache.match call**

In the L0.5 block, update the call:
```swift
if runNonInteractive,
   let result = ruleCache.match(
    bundleId: bundleId,
    role: currentRole,
    title: effectiveTitle,
    desc: effectiveDesc,
    help: currentHelp.lowercased(),
    identifier: currentIdentifier,
    roleDescription: currentRoleDescription,
    customActions: currentCustomActions
) {
    ...
}
```

(Note: Task 2 introduced `effectiveTitle`/`effectiveDesc`. Task 3 uses them.)

- [ ] **Step 6: Run tests**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" \
  -only-testing:SFlowTests/RuleCacheTests 2>&1 | grep -E "(Test Case|FAIL|PASS|passed|failed)" | tail -30
```

Expected: all RuleCacheTests pass (including 3 new + all pre-existing). Build clean.

Run full suite:
```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" \
  2>&1 | grep -E "Test Suite '.*' (passed|failed)" | tail -5
```

Expected: ~195 tests pass (192 + 3 new), zero failures.

- [ ] **Step 7: Commit**

```bash
git add SFlow/ClickWatcher.swift SFlow/RuleCache.swift SFlowTests/RuleCacheTests.swift
git commit -m "feat(client): RuleCache matches against AXRoleDescription + AXCustomActions

Two AX attributes previously ignored:
- kAXRoleDescriptionAttribute — language-independent action label
  ('compose button', 'search field'). Sometimes set when title/desc
  are localized or empty.
- AXCustomActions — array of named actions registered on the element.
  Common in modern Mac apps; format varies by macOS version so the
  parser is defensive (String / dict / NSAccessibilityCustomAction).

Both feed into RuleCache.match as additional title candidates, checked
via wordBoundaryContains (same semantics as title/desc/help).

Coverage QW Fix 3 of 3."
```

---

## Task 4: Verification + session log

- [ ] **Step 1: Full test suite + build sanity**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" \
  2>&1 | grep -E "Test Suite '.*' (passed|failed)" | tail -5
```

Expected: zero failures.

- [ ] **Step 2: Manual smoke**

Quit running SFlow. Build, launch new. Click in Slack/Notion:
- Compose icon (typical AXImage child of AXButton) — toast should still fire after walk-down
- Sidebar navigation items — toast should fire where it didn't before (AXPress probe captures non-AXButton roles)

If regression — debug; otherwise proceed.

- [ ] **Step 3: Update docs**

Add session log entry to `docs/roadmap.md` (top of Session log section, before existing "Sesja 6" entry):

```markdown
### 2026-05-14 — Sesja 7: Coverage Quick Wins (P-31 part 1)

**Co:** 3 niezależne fixy rozszerzające detection surface (bez czekania na dane z events.jsonl).
(1) `AXUIElementCopyActionNames` probe — element z akcją AXPress traktowany jako klikalny niezależnie od role (Task 1).
(2) Walk-down z klikalnego rodzica — gdy ancestor ma puste title/desc, szukamy w dzieciach (Task 2).
(3) AXRoleDescription + AXCustomActions reading — 2 nowe atrybuty czytane i przekazane do RuleCache.match (Task 3).

**Dlaczego:** sesja 7 z planu (analiza events.jsonl) wymaga 1-2 dni użycia. W międzyczasie te 3 additive fixe rozszerzają zbiór "widocznych klikalnych elementów" — odpowiada bezpośrednio na troskę "klikam i toast się nie pokazuje".

**Wpływ:** ~30-50% wzrost coverage szacunkowo. Po tym sesja analizy będzie miała bogatsze dane do diagnozy "co JESZCZE dodać".

**Commits:** patrz `git log` zakres po sesji 6.

**Następny krok:** używanie SFlow 1-2 dni → analiza events.jsonl → sesja 8 (targeted coverage based on data).
```

Update `docs/audit-phase-0.md` row for P-31: status 🟡 in-progress, comment append "Sesja 7 quick wins (AXPress probe + walk-down + RoleDescription/CustomActions) — DONE. Pełna iteracja po analizie events.jsonl."

Update `docs/audit-phase-1.md` Sub-cel 1.11: status 🔵 partial, comment append "Quick wins (sesja 7) ✅. Full data-driven iteration pending events.jsonl analysis (sesja 8)."

Update Execution sequence table row for Sesja 7: status 🟢 done.

- [ ] **Step 4: Commit docs**

```bash
git add docs/roadmap.md docs/audit-phase-0.md docs/audit-phase-1.md
git commit -m "docs: session 7 complete — Coverage Quick Wins

P-31 status now 🟡 (partial — quick wins done, full iteration pending
events.jsonl analysis in sesja 8). Sub-cel 1.11 🔵."
```

## Self-review checklist

- 3 fix commits + 1 docs commit = 4 commits expected
- Test count: 192 → ~200 (8 new: 3 gate + 3 RuleCache + ... let me recount: 3 new gate tests + updates to 5 existing + 3 new RuleCache = +6 net new test methods)
- No new files created (all modifications)
- Files touched: ClickWatcher.swift, RuleCache.swift, 2 test files, 3 docs
- All fixes additive — no behavior changes to existing match paths
