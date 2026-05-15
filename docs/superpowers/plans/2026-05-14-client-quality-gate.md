# Client Quality Gate (Session 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `RuleCache.match()` hides unreliable auto-discovered rules by default — only `high + (menu_bar OR web_docs_official)` from `cache/*.json` is shown; bundled rules stay unchanged; `showExperimental=true` unlocks everything.

**Architecture:** `RuleCache` gets a private `Set<String>` tracking which bundleIds were loaded from `cache/` (auto-discovered). `load()` populates the set. `match()` checks it per call and applies the quality filter. No changes to `LoadedRule` or JSON formats — purely runtime filtering.

**Tech Stack:** Swift, UserDefaults (already wired from Session 3), XCTest

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Modify | `SFlow/RuleCache.swift` | Add `autoDiscoveredBundleIds` tracking + filter logic in `match()` |
| Modify | `SFlowTests/RuleCacheTests.swift` | 4 new tests for quality gate behavior |

---

## Current RuleCache.swift state (relevant parts)

```swift
final class RuleCache {
    private let rootDir: URL
    private var rulesByBundle: [String: [LoadedRule]] = [:]
    var showExperimental: Bool = false

    func load() throws {
        rulesByBundle.removeAll()
        loadFile(rootDir.appendingPathComponent("bundled.json"))
        let cacheDir = rootDir.appendingPathComponent("cache")
        if let entries = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for entry in entries where entry.pathExtension == "json" {
                loadFile(entry)
            }
        }
        loadFile(rootDir.appendingPathComponent("user_overrides.json"))
    }

    private func loadFile(_ url: URL) { ... }

    func match(bundleId: String, role: String, title: String, desc: String, help: String) -> MatchResult? {
        guard let rules = rulesByBundle[bundleId] else { return nil }
        for rule in rules {
            if !showExperimental, rule.confidence == .low { continue }
            // ... title matching
        }
    }
}
```

---

## Task 1: Write 4 failing tests

**Files:**
- Modify: `SFlowTests/RuleCacheTests.swift`

- [ ] **Step 1: Add 4 new test methods at end of RuleCacheTests class (before closing `}`)**

```swift
func testAutoDiscoveredMediumRuleHiddenByDefault() throws {
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
    let mediumRule = LoadedRule(
        match: LoadedMatch(role: "AXButton", titles: ["Maybe"]),
        keys: ["m"], hint: "Maybe",
        confidence: .medium, source: .inferredPattern
    )
    let set = StoredRuleSet(bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-14T00:00:00Z",
                            source: .cloud, rulesVersion: nil, rules: [mediumRule])
    try JSONEncoder().encode(set).write(to: tempDir.appendingPathComponent("cache/com.x.json"))
    let cache = RuleCache(rootDir: tempDir)
    try cache.load()
    XCTAssertNil(cache.match(bundleId: "com.x", role: "AXButton", title: "Maybe", desc: "", help: ""),
                 "auto-discovered medium+inferred_pattern must be hidden by default")
}

func testAutoDiscoveredHighMenuBarActiveByDefault() throws {
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
    let highRule = LoadedRule(
        match: LoadedMatch(role: "AXButton", titles: ["Send"]),
        keys: ["meta", "enter"], hint: "Send",
        confidence: .high, source: .menuBar
    )
    let set = StoredRuleSet(bundleId: "com.y", appVersion: "1.0", fetchedAt: "2026-05-14T00:00:00Z",
                            source: .cloud, rulesVersion: nil, rules: [highRule])
    try JSONEncoder().encode(set).write(to: tempDir.appendingPathComponent("cache/com.y.json"))
    let cache = RuleCache(rootDir: tempDir)
    try cache.load()
    XCTAssertNotNil(cache.match(bundleId: "com.y", role: "AXButton", title: "Send", desc: "", help: ""),
                    "auto-discovered high+menu_bar must be active by default")
}

func testExperimentalToggleUnlocksMediumAutoDiscovered() throws {
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
    let mediumRule = LoadedRule(
        match: LoadedMatch(role: "AXButton", titles: ["Maybe"]),
        keys: ["m"], hint: "Maybe",
        confidence: .medium, source: .inferredPattern
    )
    let set = StoredRuleSet(bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-14T00:00:00Z",
                            source: .cloud, rulesVersion: nil, rules: [mediumRule])
    try JSONEncoder().encode(set).write(to: tempDir.appendingPathComponent("cache/com.x.json"))
    let cache = RuleCache(rootDir: tempDir)
    try cache.load()
    cache.showExperimental = true
    XCTAssertNotNil(cache.match(bundleId: "com.x", role: "AXButton", title: "Maybe", desc: "", help: ""),
                    "showExperimental=true must unlock medium auto-discovered rules")
}

func testBundledMediumRuleActiveByDefault() throws {
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
    let mediumRule = LoadedRule(
        match: LoadedMatch(role: "AXButton", titles: ["Search"]),
        keys: ["meta", "k"], hint: "Search",
        confidence: .medium, source: .webDocsThirdParty
    )
    let set = StoredRuleSet(bundleId: "com.z", appVersion: "1.0", fetchedAt: "2026-05-14T00:00:00Z",
                            source: .bundled, rulesVersion: nil, rules: [mediumRule])
    try JSONEncoder().encode(set).write(to: tempDir.appendingPathComponent("bundled.json"))
    let cache = RuleCache(rootDir: tempDir)
    try cache.load()
    XCTAssertNotNil(cache.match(bundleId: "com.z", role: "AXButton", title: "Search", desc: "", help: ""),
                    "bundled medium+web_docs_third_party must be active by default")
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && xcodebuild test -project SFlow.xcodeproj -scheme SFlow -destination 'platform=macOS' -only-testing:SFlowTests/RuleCacheTests 2>&1 | grep -E "(PASS|FAIL|error:)" | head -20
```

Expected: `testAutoDiscoveredMediumRuleHiddenByDefault` FAILS (returns non-nil today), `testExperimentalToggleUnlocksMediumAutoDiscovered` FAILS (returns nil even with showExperimental=true), others may pass already.

---

## Task 2: Implement quality gate in RuleCache

**Files:**
- Modify: `SFlow/RuleCache.swift`

- [ ] **Step 3: Add `autoDiscoveredBundleIds` property after `rulesByBundle`**

Current line ~10 in RuleCache.swift:
```swift
private var rulesByBundle: [String: [LoadedRule]] = [:]
var showExperimental: Bool = false
```

Replace with:
```swift
private var rulesByBundle: [String: [LoadedRule]] = [:]
private var autoDiscoveredBundleIds: Set<String> = []
var showExperimental: Bool = false
```

- [ ] **Step 4: Update `load()` to reset set and pass `isAutoDiscovered` flag**

Current `load()` (lines ~18-31):
```swift
func load() throws {
    rulesByBundle.removeAll()
    // Layer 1: bundled (lowest priority)
    loadFile(rootDir.appendingPathComponent("bundled.json"))
    // Layer 2: cache files (override bundled)
    let cacheDir = rootDir.appendingPathComponent("cache")
    if let entries = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
        for entry in entries where entry.pathExtension == "json" {
            loadFile(entry)
        }
    }
    // Layer 3: user overrides (highest)
    loadFile(rootDir.appendingPathComponent("user_overrides.json"))
}
```

Replace with:
```swift
func load() throws {
    rulesByBundle.removeAll()
    autoDiscoveredBundleIds.removeAll()
    // Layer 1: bundled (lowest priority)
    loadFile(rootDir.appendingPathComponent("bundled.json"), isAutoDiscovered: false)
    // Layer 2: cache files (auto-discovered, override bundled)
    let cacheDir = rootDir.appendingPathComponent("cache")
    if let entries = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
        for entry in entries where entry.pathExtension == "json" {
            loadFile(entry, isAutoDiscovered: true)
        }
    }
    // Layer 3: user overrides (highest, always trusted)
    loadFile(rootDir.appendingPathComponent("user_overrides.json"), isAutoDiscovered: false)
}
```

- [ ] **Step 5: Update `loadFile()` signature and body**

Current `loadFile`:
```swift
private func loadFile(_ url: URL) {
    guard let data = try? Data(contentsOf: url) else { return }
    if let set = try? JSONDecoder().decode(StoredRuleSet.self, from: data) {
        rulesByBundle[set.bundleId] = set.rules
        return
    }
    // bundled.json may contain multiple apps wrapped in an array
    if let sets = try? JSONDecoder().decode([StoredRuleSet].self, from: data) {
        for set in sets {
            if rulesByBundle[set.bundleId] == nil {
                rulesByBundle[set.bundleId] = set.rules
            }
        }
    }
}
```

Replace with:
```swift
private func loadFile(_ url: URL, isAutoDiscovered: Bool) {
    guard let data = try? Data(contentsOf: url) else { return }
    if let set = try? JSONDecoder().decode(StoredRuleSet.self, from: data) {
        rulesByBundle[set.bundleId] = set.rules
        if isAutoDiscovered { autoDiscoveredBundleIds.insert(set.bundleId) }
        return
    }
    // bundled.json may contain multiple apps wrapped in an array
    if let sets = try? JSONDecoder().decode([StoredRuleSet].self, from: data) {
        for set in sets {
            if rulesByBundle[set.bundleId] == nil {
                rulesByBundle[set.bundleId] = set.rules
                if isAutoDiscovered { autoDiscoveredBundleIds.insert(set.bundleId) }
            }
        }
    }
}
```

- [ ] **Step 6: Update `match()` filter logic**

Current filter in `match()` (line ~81):
```swift
for rule in rules {
    if !showExperimental, rule.confidence == .low { continue }
```

Replace with:
```swift
for rule in rules {
    if !showExperimental {
        let isAutoDiscovered = autoDiscoveredBundleIds.contains(bundleId)
        if rule.confidence == .low { continue }
        if isAutoDiscovered && rule.confidence != .high { continue }
        if isAutoDiscovered && rule.source != .menuBar && rule.source != .webDocsOfficial { continue }
    }
```

Note: move `let isAutoDiscovered` outside the loop for efficiency — compute once per `match()` call, not per rule:

```swift
func match(bundleId: String, role: String, title: String, desc: String, help: String) -> MatchResult? {
    guard let rules = rulesByBundle[bundleId] else { return nil }
    let isAutoDiscovered = autoDiscoveredBundleIds.contains(bundleId)
    let titleLC = title.lowercased()
    let descLC = desc.lowercased()
    let helpLC = help.lowercased()
    let titleStripped = Self.stripHotkeySuffix(title)?.lowercased()

    for rule in rules {
        if !showExperimental {
            if rule.confidence == .low { continue }
            if isAutoDiscovered && rule.confidence != .high { continue }
            if isAutoDiscovered && rule.source != .menuBar && rule.source != .webDocsOfficial { continue }
        }
        if !roleCompatible(ruleRole: rule.match.role, actualRole: role) { continue }
        let titleMatches = rule.match.titles.contains { candidate in
            let c = candidate.lowercased()
            if titleLC == c || descLC == c || helpLC == c
                || titleLC.contains(c) || descLC.contains(c) { return true }
            if let stripped = titleStripped {
                if stripped == c || stripped.contains(c) { return true }
            }
            return false
        }
        if titleMatches { return MatchResult(rule: rule) }
    }
    return nil
}
```

---

## Task 3: Verify all tests pass + commit + update docs

**Files:**
- Run tests
- `SFlow/RuleCache.swift` + `SFlowTests/RuleCacheTests.swift` → commit
- `docs/audit-phase-1.md` + `docs/audit-phase-0.md` → update statuses → commit

- [ ] **Step 7: Run full test suite**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && xcodebuild test -project SFlow.xcodeproj -scheme SFlow -destination 'platform=macOS' 2>&1 | grep -E "(TEST SUCCEEDED|TEST FAILED|FAIL)"
```

Expected: `TEST SUCCEEDED`

- [ ] **Step 8: Commit implementation**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && git add SFlow/RuleCache.swift SFlowTests/RuleCacheTests.swift
git commit -m "feat(client): RuleCache filters auto-discovered rules by confidence+source"
```

- [ ] **Step 9: Update audit-phase-1.md**

In `docs/audit-phase-1.md`:
- Sub-cel 1.1: `🟡 in-progress` → `🟢 done` with comment "client-side filtr po confidence/source ✅ (sesja 2026-05-14)"
- Sesja 4 Status: `⬜` → `🟢 done`

- [ ] **Step 10: Update audit-phase-0.md**

In `docs/audit-phase-0.md`, problem table:
- P-1: `🔵 częściowo` → `🟢 zamknięte` with comment "quality gate kompletny: backend dedup + client filtr confidence/source (sesja 2026-05-14)"

- [ ] **Step 11: Commit docs**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && git add docs/audit-phase-1.md docs/audit-phase-0.md
git commit -m "docs: session 4 complete — client quality gate"
```

---

## Self-Review

**Spec coverage:**
- ✅ Auto-discovered medium rules hidden by default (Task 1 test 1 + Task 2)
- ✅ Auto-discovered high+menu_bar active by default (Task 1 test 2)
- ✅ `showExperimental=true` unlocks all medium (Task 1 test 3 + Task 2)
- ✅ Bundled medium rules unaffected (Task 1 test 4)
- ✅ Existing tests still pass (no breaking changes to public API)
- ✅ Docs updated (P-1 → 🟢, Sub-cel 1.1 → 🟢, Sesja 4 → 🟢)

**No placeholders:** All code is complete.

**Type consistency:**
- `autoDiscoveredBundleIds: Set<String>` — used in `load()`, `loadFile()`, `match()` consistently
- `loadFile(_ url: URL, isAutoDiscovered: Bool)` — called 3× in `load()` with explicit Bool
- `rule.source`: `.menuBar`, `.webDocsOfficial` — matches `LoadedSource` enum cases in `LoadedRule.swift`

**Acceptance criteria:**
- [ ] Auto-discovery dla NIEzweryfikowanej apki nie pokazuje `medium + inferred_pattern`
- [ ] `showExperimental=true` w Settings aktywuje wszystkie medium
- [ ] Bundled.json bez zmian (wszystkie reguły aktywne jak dziś)
- [ ] Pełen test suite green (+ 4 nowe testy = 17 total w RuleCacheTests)
