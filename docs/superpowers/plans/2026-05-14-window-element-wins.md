# Window Element Wins (Session 4.5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two complementary improvements to element-level detection: (A) `AXKeyShortcutsValue` as a new Layer 0 that reads the shortcut directly from Electron/Chromium elements (zero-ambiguity, language-agnostic), and (B) `AXIdentifier` propagation through the entire stack — skeleton extractor → JSON rules → runtime match — so identifiers like `"compose-button"` become a fast, stable matching key that supplements title matching.

**Architecture:** Task A is self-contained in `ClickWatcher` — read the Chromium AX attribute, parse it, emit before Layer 0.5. Task B is a vertical slice: `AXSkeletonExtractor` gains an `identifier` field, `LoadedMatch` gains `identifiers: [String]?`, `RuleCache.match()` gains an `identifier:` parameter that short-circuits title matching, `ClickWatcher` passes `currentIdentifier` (already captured) to `match()`, and the backend schemas + prompt get matching updates.

**Tech Stack:** Swift, XCTest, TypeScript, Zod, Vitest

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Modify | `SFlow/ClickWatcher.swift` | Add `parseAriaShortcut()` static method + Layer 0 check + pass `identifier` to `ruleCache.match()` |
| Modify | `SFlow/AXSkeletonExtractor.swift` | `RawAXItem` + `SkeletonItem` get `identifier: String?`; `walk()` reads `kAXIdentifierAttribute`; `filter()` passes it through |
| Modify | `SFlow/LoadedRule.swift` | `LoadedMatch` gains `identifiers: [String]?` with default-nil memberwise init |
| Modify | `SFlow/RuleCache.swift` | `match()` gains `identifier: String = ""` param; identifier fast-path before title loop |
| Create | `SFlowTests/ClickWatcherParseTests.swift` | 9 unit tests for `parseAriaShortcut` |
| Modify | `SFlowTests/RuleCacheTests.swift` | 3 tests for identifier matching |
| Modify | `SFlowTests/AXSkeletonFilterTests.swift` | 2 tests: identifier pass-through + JSON omits nil |
| Modify | `backend/src/types.ts` | `UISkeletonItemSchema` + `RuleSchema.match` get optional `identifier`/`identifiers` |
| Modify | `backend/src/prompt.ts` | Skeleton lines include `[id=…]`; system prompt explains `identifiers` field |
| Modify | `backend/tests/validate.test.ts` | 2 tests: skeleton item with identifier accepted; rule with identifiers accepted |
| Modify | `backend/tests/prompt.test.ts` | 1 test: skeleton item with identifier renders `[id=…]` tag |

---

## Current state (relevant excerpts)

**`ClickWatcher.swift` line 83–122** — attribute reads + layers:
```swift
// lines 83–97: read 7 AX attributes
var shortcutsValueRef: AnyObject?  // NOT YET — add this
// ...
let currentIdentifier = (identRef as? String ?? "").lowercased()  // already exists line 97

// line 110: Layer 0.5 — no Layer 0 yet
if let result = ruleCache.match(bundleId: bundleId, role: currentRole,
    title: currentTitle, desc: currentDesc, help: currentHelp.lowercased()) { ...
```

**`AXSkeletonExtractor.swift`**:
```swift
struct RawAXItem: Hashable { let role: String; let title: String }
struct SkeletonItem: Codable, Hashable { let role: String; let title: String }
// walk() reads kAXRoleAttribute + kAXTitleAttribute + kAXDescriptionAttribute — not kAXIdentifierAttribute
```

**`LoadedRule.swift`**:
```swift
struct LoadedMatch: Codable { let role: String; let titles: [String] }
```

**`RuleCache.swift` line 77**:
```swift
func match(bundleId: String, role: String, title: String, desc: String, help: String) -> MatchResult?
```

**`backend/src/types.ts`**:
```typescript
export const UISkeletonItemSchema = z.object({
  role: z.string().min(1).max(50),
  title: z.string().min(1).max(80),
  // no identifier yet
});
export const RuleSchema = z.object({
  match: z.object({ role: z.string(), titles: z.array(z.string()).min(1).max(20) }),
  // no identifiers in match yet
  ...
});
```

---

## Task A: AXKeyShortcutsValue — Layer 0

### Step 1: Create `SFlowTests/ClickWatcherParseTests.swift` with 9 failing tests

```swift
import XCTest
@testable import SFlow

final class ClickWatcherParseTests: XCTestCase {

    func testParseMetaPlusKey() {
        XCTAssertEqual(ClickWatcher.parseAriaShortcut("Meta+KeyK"), ["meta", "k"])
    }

    func testParseControlShiftKey() {
        XCTAssertEqual(ClickWatcher.parseAriaShortcut("Control+Shift+KeyS"), ["ctrl", "shift", "s"])
    }

    func testParseSingleKey() {
        XCTAssertEqual(ClickWatcher.parseAriaShortcut("KeyE"), ["e"])
    }

    func testParseDigit() {
        XCTAssertEqual(ClickWatcher.parseAriaShortcut("Meta+Digit1"), ["meta", "1"])
    }

    func testParseArrowKey() {
        XCTAssertEqual(ClickWatcher.parseAriaShortcut("ArrowUp"), ["up"])
    }

    func testParseFunctionKey() {
        XCTAssertEqual(ClickWatcher.parseAriaShortcut("F5"), ["f5"])
    }

    func testParseEnterKey() {
        XCTAssertEqual(ClickWatcher.parseAriaShortcut("Meta+Enter"), ["meta", "enter"])
    }

    func testParseUnknownTokenReturnsNil() {
        XCTAssertNil(ClickWatcher.parseAriaShortcut("SomeWeirdToken"))
    }

    func testParseEmptyStringReturnsNil() {
        XCTAssertNil(ClickWatcher.parseAriaShortcut(""))
    }
}
```

You also need to add `ClickWatcherParseTests.swift` to the Xcode project. Edit `SFlow.xcodeproj/project.pbxproj`:

1. Find the PBXFileReference block for another test file like `EventLoggerTests.swift`. Copy the pattern:
   ```
   XXXX /* EventLoggerTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = EventLoggerTests.swift; sourceTree = "<group>"; };
   ```
   Add a new entry with a fresh UUID:
   ```
   CAFE0001 /* ClickWatcherParseTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ClickWatcherParseTests.swift; sourceTree = "<group>"; };
   ```

2. Find the PBXGroup block that lists test files. Add `CAFE0001 /* ClickWatcherParseTests.swift */,` inside it.

3. Find the PBXBuildFile section. Copy another test file entry and add:
   ```
   CAFE0002 /* ClickWatcherParseTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = CAFE0001 /* ClickWatcherParseTests.swift */; };
   ```

4. Find the SFlowTests Sources build phase (the one with `isa = PBXSourcesBuildPhase` that lists `EventLoggerTests.swift`). Add `CAFE0002 /* ClickWatcherParseTests.swift in Sources */,` inside the `files = (...)` list.

### Step 2: Run tests to verify they fail

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && xcodebuild test -project SFlow.xcodeproj -scheme SFlow -destination 'platform=macOS' -only-testing:SFlowTests/ClickWatcherParseTests 2>&1 | grep -E "(PASS|FAIL|error:|Build)" | head -20
```

Expected: compile error "type 'ClickWatcher' has no member 'parseAriaShortcut'".

### Step 3: Implement `parseAriaShortcut` in `ClickWatcher.swift`

Add this `static func` to the `ClickWatcher` class body (e.g., right after `interactiveRoles`, before `handleMouseDown()`). It must be `internal` (not `private`) so the test target can call it.

```swift
static func parseAriaShortcut(_ value: String) -> [String]? {
    guard !value.isEmpty else { return nil }
    let tokens = value.split(separator: "+", omittingEmptySubsequences: true).map(String.init)
    guard !tokens.isEmpty else { return nil }
    var result: [String] = []
    for token in tokens {
        switch token {
        case "Meta":      result.append("meta")
        case "Control":   result.append("ctrl")
        case "Alt":       result.append("alt")
        case "Shift":     result.append("shift")
        case "Enter":     result.append("enter")
        case "Space":     result.append("space")
        case "Escape":    result.append("escape")
        case "Tab":       result.append("tab")
        case "Backspace": result.append("backspace")
        case "Delete":    result.append("delete")
        case "ArrowUp":   result.append("up")
        case "ArrowDown": result.append("down")
        case "ArrowLeft": result.append("left")
        case "ArrowRight":result.append("right")
        default:
            if token.hasPrefix("Key"), token.count == 4, let last = token.last {
                result.append(String(last).lowercased())
            } else if token.hasPrefix("Digit"), token.count == 6, let last = token.last {
                result.append(String(last))
            } else if token.hasPrefix("F"), let n = Int(token.dropFirst()), (1...12).contains(n) {
                result.append(token.lowercased())
            } else {
                return nil
            }
        }
    }
    return result.isEmpty ? nil : result
}
```

### Step 4: Run tests to verify they pass

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && xcodebuild test -project SFlow.xcodeproj -scheme SFlow -destination 'platform=macOS' -only-testing:SFlowTests/ClickWatcherParseTests 2>&1 | grep -E "(PASS|FAIL|error:)" | head -20
```

Expected: 9 × PASS.

### Step 5: Add `AXKeyShortcutsValue` attribute read in `handleMouseDown()`

In `SFlow/ClickWatcher.swift`, in the 6-level ancestor loop, the attribute reads currently end at line 92 (`identRef`). Add the `AXKeyShortcutsValue` read immediately after:

Current (line 92):
```swift
AXUIElementCopyAttributeValue(current, kAXIdentifierAttribute as CFString, &identRef)
```

Replace with:
```swift
AXUIElementCopyAttributeValue(current, kAXIdentifierAttribute as CFString, &identRef)
var axksRef: AnyObject?
AXUIElementCopyAttributeValue(current, "AXKeyShortcutsValue" as CFString, &axksRef)
```

Then add the derived constant after the existing let-bindings (after line 97 `let currentIdentifier = ...`):

Current (line 97):
```swift
let currentIdentifier = (identRef  as? String ?? "").lowercased()
let isInteractive     = Self.interactiveRoles.contains(currentRole)
```

Replace with:
```swift
let currentIdentifier   = (identRef  as? String ?? "").lowercased()
let currentKeyShortcuts =  axksRef   as? String ?? ""
let isInteractive       = Self.interactiveRoles.contains(currentRole)
```

### Step 6: Insert Layer 0 in the loop — before the Layer 0.5 comment

Current (line 110):
```swift
// Layer 0.5: JSON-loaded rules (bundled / LLM cache / user overrides)
if let result = ruleCache.match(
```

Replace with:
```swift
// Layer 0: AXKeyShortcutsValue — Electron/Chromium aria-keyshortcuts attribute
if !currentKeyShortcuts.isEmpty,
   let keys = Self.parseAriaShortcut(currentKeyShortcuts) {
    let hint = (titleRef as? String) ?? (descRef as? String) ?? currentKeyShortcuts
    let autoId = "axks:\(bundleId):\(keys.joined(separator: "+"))"
    emit(bundleId: bundleId, shortcutId: autoId, keys: keys, hint: hint, loc: nsLoc)
    return
}

// Layer 0.5: JSON-loaded rules (bundled / LLM cache / user overrides)
if let result = ruleCache.match(
```

### Step 7: Build to verify no compile errors

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && xcodebuild build -project SFlow.xcodeproj -scheme SFlow -destination 'platform=macOS' 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" | head -20
```

Expected: `BUILD SUCCEEDED`.

### Step 8: Run full test suite and commit

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && xcodebuild test -project SFlow.xcodeproj -scheme SFlow -destination 'platform=macOS' 2>&1 | grep -E "(TEST SUCCEEDED|TEST FAILED|FAIL)" | head -5
```

Expected: `TEST SUCCEEDED`.

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && git add SFlow/ClickWatcher.swift SFlowTests/ClickWatcherParseTests.swift SFlow.xcodeproj/project.pbxproj
git commit -m "feat(client): AXKeyShortcutsValue Layer 0 — reads aria-keyshortcuts from Electron elements"
```

---

## Task B: AXIdentifier — vertical slice

### Step 9: Write failing tests

**In `SFlowTests/AXSkeletonFilterTests.swift`** — add 2 tests at the end of the class (before closing `}`):

```swift
func testIdentifierPassesThroughToSkeletonItem() {
    let items = AXSkeletonExtractor.filter(rawItems: [
        RawAXItem(role: "AXButton", title: "Send Message", identifier: "send-btn"),
        RawAXItem(role: "AXButton", title: "Send Message", identifier: "send-btn"),
    ])
    XCTAssertEqual(items.count, 1)
    XCTAssertEqual(items[0].identifier, "send-btn")
}

func testSkeletonItemNilIdentifierOmittedFromJSON() throws {
    let item = SkeletonItem(role: "AXButton", title: "Send")
    let json = try JSONEncoder().encode(item)
    let dict = try JSONSerialization.jsonObject(with: json) as! [String: Any]
    XCTAssertNil(dict["identifier"],
                 "nil identifier must not appear as null in encoded JSON")
}
```

**In `SFlowTests/RuleCacheTests.swift`** — add 3 tests at the end of the class (before closing `}`):

```swift
func testIdentifierMatchReturnsRule() throws {
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
    let rule = LoadedRule(
        match: LoadedMatch(role: "AXButton", titles: ["Completely Different"], identifiers: ["compose-btn"]),
        keys: ["meta", "n"], hint: "Compose",
        confidence: .high, source: .menuBar
    )
    let set = StoredRuleSet(bundleId: "com.id", appVersion: "1.0", fetchedAt: "2026-05-14T00:00:00Z",
                            source: .cloud, rulesVersion: nil, rules: [rule])
    try JSONEncoder().encode(set).write(to: tempDir.appendingPathComponent("cache/com.id.json"))
    let cache = RuleCache(rootDir: tempDir)
    try cache.load()
    XCTAssertNotNil(
        cache.match(bundleId: "com.id", role: "AXButton", title: "xyz", desc: "", help: "", identifier: "compose-btn"),
        "identifier match must return rule even when title doesn't match"
    )
}

func testIdentifierMismatchFallsBackToTitle() throws {
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
    let rule = LoadedRule(
        match: LoadedMatch(role: "AXButton", titles: ["Send"], identifiers: ["wrong-id"]),
        keys: ["meta", "enter"], hint: "Send",
        confidence: .high, source: .menuBar
    )
    let set = StoredRuleSet(bundleId: "com.fb", appVersion: "1.0", fetchedAt: "2026-05-14T00:00:00Z",
                            source: .cloud, rulesVersion: nil, rules: [rule])
    try JSONEncoder().encode(set).write(to: tempDir.appendingPathComponent("cache/com.fb.json"))
    let cache = RuleCache(rootDir: tempDir)
    try cache.load()
    XCTAssertNotNil(
        cache.match(bundleId: "com.fb", role: "AXButton", title: "Send", desc: "", help: "", identifier: "other-btn"),
        "title match must still work when identifier doesn't match rule's identifiers"
    )
}

func testRuleWithoutIdentifiersMatchesByTitle() throws {
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
    let rule = LoadedRule(
        match: LoadedMatch(role: "AXButton", titles: ["Search"]),
        keys: ["meta", "k"], hint: "Search",
        confidence: .high, source: .menuBar
    )
    let set = StoredRuleSet(bundleId: "com.bc", appVersion: "1.0", fetchedAt: "2026-05-14T00:00:00Z",
                            source: .cloud, rulesVersion: nil, rules: [rule])
    try JSONEncoder().encode(set).write(to: tempDir.appendingPathComponent("cache/com.bc.json"))
    let cache = RuleCache(rootDir: tempDir)
    try cache.load()
    XCTAssertNotNil(
        cache.match(bundleId: "com.bc", role: "AXButton", title: "Search", desc: "", help: "", identifier: ""),
        "backward compat: rule without identifiers must match by title with empty identifier"
    )
}
```

### Step 10: Run to verify failing tests

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && xcodebuild test -project SFlow.xcodeproj -scheme SFlow -destination 'platform=macOS' -only-testing:SFlowTests/RuleCacheTests -only-testing:SFlowTests/AXSkeletonFilterTests 2>&1 | grep -E "(PASS|FAIL|error:)" | head -30
```

Expected: `testIdentifierMatchReturnsRule` FAIL (identifier param doesn't exist yet), `testIdentifierPassesThroughToSkeletonItem` FAIL (identifier field doesn't exist on RawAXItem yet). Others may fail with compile errors.

### Step 11: Add `identifiers: [String]?` to `LoadedMatch` in `SFlow/LoadedRule.swift`

Current `LoadedMatch`:
```swift
struct LoadedMatch: Codable {
    let role: String
    let titles: [String]
}
```

Replace with:
```swift
struct LoadedMatch: Codable {
    let role: String
    let titles: [String]
    let identifiers: [String]?

    init(role: String, titles: [String], identifiers: [String]? = nil) {
        self.role = role
        self.titles = titles
        self.identifiers = identifiers
    }
}
```

The synthesized `init(from: Decoder)` handles missing `identifiers` key as `nil` automatically (optional → `decodeIfPresent`).

### Step 12: Update `RuleCache.match()` in `SFlow/RuleCache.swift`

Current signature (line 77):
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

Replace with:
```swift
func match(bundleId: String, role: String, title: String, desc: String, help: String,
           identifier: String = "") -> MatchResult? {
    guard let rules = rulesByBundle[bundleId] else { return nil }
    let isAutoDiscovered = autoDiscoveredBundleIds.contains(bundleId)
    let titleLC = title.lowercased()
    let descLC = desc.lowercased()
    let helpLC = help.lowercased()
    let identifierLC = identifier.lowercased()
    let titleStripped = Self.stripHotkeySuffix(title)?.lowercased()

    for rule in rules {
        if !showExperimental {
            if rule.confidence == .low { continue }
            if isAutoDiscovered && rule.confidence != .high { continue }
            if isAutoDiscovered && rule.source != .menuBar && rule.source != .webDocsOfficial { continue }
        }
        if !roleCompatible(ruleRole: rule.match.role, actualRole: role) { continue }
        // Identifier fast path — exact match, language-agnostic
        if let ids = rule.match.identifiers, !identifierLC.isEmpty {
            if ids.contains(where: { $0.lowercased() == identifierLC }) {
                return MatchResult(rule: rule)
            }
        }
        // Title match fallback
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

### Step 13: Add `identifier: String?` to `RawAXItem` and `SkeletonItem` in `SFlow/AXSkeletonExtractor.swift`

Current:
```swift
struct RawAXItem: Hashable {
    let role: String
    let title: String
}

struct SkeletonItem: Codable, Hashable {
    let role: String
    let title: String
}
```

Replace with:
```swift
struct RawAXItem: Hashable {
    let role: String
    let title: String
    let identifier: String?

    init(role: String, title: String, identifier: String? = nil) {
        self.role = role
        self.title = title
        self.identifier = identifier
    }
}

struct SkeletonItem: Codable, Hashable {
    let role: String
    let title: String
    let identifier: String?

    init(role: String, title: String, identifier: String? = nil) {
        self.role = role
        self.title = title
        self.identifier = identifier
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(role, forKey: .role)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(identifier, forKey: .identifier)
    }
}
```

Note: the `encodeIfPresent` in `SkeletonItem.encode(to:)` omits the `identifier` key entirely when nil — this prevents sending `"identifier": null` in the JSON payload to the backend. The synthesized `init(from:)` still handles absent keys as nil automatically.

### Step 14: Update `AXSkeletonExtractor` — `walk()` and `filter()`

**In `walk()` (lines 118–146):** currently reads `kAXTitleAttribute` and `kAXDescriptionAttribute`. Add `kAXIdentifierAttribute` read and pass it to `RawAXItem`.

Current `walk()` body — the inner allowed-role block:
```swift
if allowedRoles.contains(role) {
    var titleRef: AnyObject?
    var descRef: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
    AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
    let title = (titleRef as? String).flatMap { $0.isEmpty ? nil : $0 }
        ?? (descRef as? String) ?? ""
    if !title.isEmpty {
        raw.append(RawAXItem(role: role, title: title))
    }
}
```

Replace with:
```swift
if allowedRoles.contains(role) {
    var titleRef: AnyObject?
    var descRef: AnyObject?
    var identRef: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
    AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
    AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identRef)
    let title = (titleRef as? String).flatMap { $0.isEmpty ? nil : $0 }
        ?? (descRef as? String) ?? ""
    if !title.isEmpty {
        let ident = identRef as? String
        raw.append(RawAXItem(role: role, title: title, identifier: ident?.isEmpty == false ? ident : nil))
    }
}
```

**In `filter()` (line 49):** update the `SkeletonItem` construction to pass `identifier`:

Current:
```swift
result.append(SkeletonItem(role: item.role, title: title))
```

Replace with:
```swift
result.append(SkeletonItem(role: item.role, title: title, identifier: item.identifier))
```

### Step 15: Update `ClickWatcher` — pass `identifier` to `ruleCache.match()`

In `SFlow/ClickWatcher.swift`, find the Layer 0.5 call (added after Layer 0 in Step 6):

Current:
```swift
if let result = ruleCache.match(
    bundleId: bundleId,
    role: currentRole,
    title: currentTitle,
    desc: currentDesc,
    help: currentHelp.lowercased()
) {
```

Replace with:
```swift
if let result = ruleCache.match(
    bundleId: bundleId,
    role: currentRole,
    title: currentTitle,
    desc: currentDesc,
    help: currentHelp.lowercased(),
    identifier: currentIdentifier
) {
```

### Step 16: Run full Swift test suite to verify all pass

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && xcodebuild test -project SFlow.xcodeproj -scheme SFlow -destination 'platform=macOS' 2>&1 | grep -E "(TEST SUCCEEDED|TEST FAILED|FAIL)" | head -5
```

Expected: `TEST SUCCEEDED`.

### Step 17: Update backend — `types.ts`

Current `UISkeletonItemSchema` and `RuleSchema.match`:
```typescript
export const UISkeletonItemSchema = z.object({
  role: z.string().min(1).max(50),
  title: z.string().min(1).max(80),
});

export const RuleSchema = z.object({
  match: z.object({
    role: z.string(),
    titles: z.array(z.string()).min(1).max(20),
  }),
  ...
});
```

Replace `UISkeletonItemSchema` with:
```typescript
export const UISkeletonItemSchema = z.object({
  role: z.string().min(1).max(50),
  title: z.string().min(1).max(80),
  identifier: z.string().max(100).optional(),
});
```

Replace `RuleSchema.match` with:
```typescript
export const RuleSchema = z.object({
  match: z.object({
    role: z.string(),
    titles: z.array(z.string()).min(1).max(20),
    identifiers: z.array(z.string()).max(5).optional(),
  }),
  ...rest of fields unchanged...
});
```

### Step 18: Update backend — `prompt.ts`

**In `buildUserPrompt()`** — update skeleton line rendering to include `[id=…]` when present:

Current:
```typescript
const skeletonLines = req.uiSkeleton
  .map((s) => `  ${s.role}: "${s.title}"`)
  .join("\n");
```

Replace with:
```typescript
const skeletonLines = req.uiSkeleton
  .map((s) => `  ${s.role}: "${s.title}"${s.identifier ? ` [id=${s.identifier}]` : ""}`)
  .join("\n");
```

**In `buildSystemPrompt()`** — add identifier instruction after the HOTKEY-SUFFIX VARIANTS paragraph and before the TITLE VARIANTS paragraph:

Current (line 24–25):
```
- HOTKEY-SUFFIX VARIANTS (Electron menus only): ...
- TITLE VARIANTS: every rule's "titles" array MUST ...
```

Insert between them:
```
- IDENTIFIERS: When the UI skeleton includes [id=...] for an element, add an "identifiers" field to that rule's match object. Example: { "role": "AXButton", "titles": ["Compose", "New message"], "identifiers": ["compose-button"] }. Identifiers allow the client to match elements by stable DOM id rather than localised title — include them whenever the skeleton provides them.
```

### Step 19: Update backend tests — `validate.test.ts` and `prompt.test.ts`

**In `backend/tests/validate.test.ts`** — add 2 tests inside the `describe("DiscoverRequestSchema")` block and a new test in `describe("RuleSchema")`:

```typescript
it("accepts skeleton item with optional identifier", () => {
  const result = DiscoverRequestSchema.safeParse({
    bundleId: "com.x",
    appName: "X",
    appVersion: "1.0",
    menuBar: [],
    uiSkeleton: [{ role: "AXButton", title: "Send", identifier: "send-btn" }],
    clientVersion: "1.0.0",
  });
  expect(result.success).toBe(true);
});

it("accepts skeleton item without identifier (backward compat)", () => {
  const result = DiscoverRequestSchema.safeParse({
    bundleId: "com.x",
    appName: "X",
    appVersion: "1.0",
    menuBar: [],
    uiSkeleton: [{ role: "AXButton", title: "Send" }],
    clientVersion: "1.0.0",
  });
  expect(result.success).toBe(true);
});
```

And add inside the final `describe("RuleSchema version normalization")` block (or as a new `describe`):
```typescript
it("accepts rule with optional identifiers in match", () => {
  const result = RuleSchema.safeParse({
    match: { role: "AXButton", titles: ["Compose"], identifiers: ["compose-btn"] },
    keys: ["meta", "n"],
    hint: "Compose",
    confidence: "high",
    source: "menu_bar",
  });
  expect(result.success).toBe(true);
});
```

**In `backend/tests/prompt.test.ts`** — add inside `describe("buildUserPrompt")`:

```typescript
it("includes [id=…] tag when skeleton item has identifier", () => {
  const result = buildUserPrompt({
    bundleId: "com.x",
    appName: "X",
    appVersion: "1.0",
    menuBar: [],
    uiSkeleton: [{ role: "AXButton", title: "Send", identifier: "send-btn" }],
    clientVersion: "1.0",
  });
  expect(result).toContain('[id=send-btn]');
});
```

### Step 20: Run backend tests

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow/backend && npm test 2>&1 | tail -20
```

Expected: all tests pass.

### Step 21: TypeScript type-check

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow/backend && npx tsc --noEmit 2>&1 | tail -10
```

Expected: no errors.

### Step 22: Commit Swift + backend

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && git add SFlow/ClickWatcher.swift SFlow/AXSkeletonExtractor.swift SFlow/LoadedRule.swift SFlow/RuleCache.swift SFlowTests/AXSkeletonFilterTests.swift SFlowTests/RuleCacheTests.swift
git commit -m "feat(client): AXIdentifier support — skeleton extraction + rule matching + ClickWatcher"

git add backend/src/types.ts backend/src/prompt.ts backend/tests/validate.test.ts backend/tests/prompt.test.ts
git commit -m "feat(backend): AXIdentifier fields in skeleton schema and rule match schema"
```

---

## Task C: Update audit docs

### Step 23: Update `docs/audit-phase-1.md`

- Sesja 4.5 Status: `⬜` → `🟢 done` with comment "AXKeyShortcutsValue (Layer 0) + AXIdentifier slice ✅ (sesja 2026-05-14)"
- Sub-cel 1.2 (if tracked): update as applicable

### Step 24: Update `docs/audit-phase-0.md`

- P-6 (AXKeyShortcutsValue): `🔴 otwarte` → `🟢 zamknięte` with comment "Layer 0 w ClickWatcher, parseAriaShortcut ✅ (sesja 2026-05-14)"
- P-24 / P-25 (window element matching): `🔴 otwarte` → `🟡 częściowo` with comment "AXIdentifier dodany do schematu i match(); reguły w bundled.json jeszcze nie zaktualizowane"

### Step 25: Commit docs

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && git add docs/audit-phase-1.md docs/audit-phase-0.md
git commit -m "docs: session 4.5 complete — window element wins"
```

---

## Self-Review

**Spec coverage:**
- ✅ Layer 0: `AXKeyShortcutsValue` read → `parseAriaShortcut` → emit before Layer 0.5
- ✅ `parseAriaShortcut` handles Meta/Control/Alt/Shift + Key*/Digit*/Arrow*/F1-F12/named keys
- ✅ `parseAriaShortcut` returns nil for empty or unknown tokens
- ✅ 9 unit tests for `parseAriaShortcut`
- ✅ AXIdentifier flows: `AXSkeletonExtractor.walk()` → `RawAXItem` → `SkeletonItem` → JSON payload
- ✅ `LoadedMatch.identifiers: [String]?` — optional, backward-compat with existing JSON
- ✅ `RuleCache.match(identifier:)` — identifier fast-path before title loop, falls back to titles
- ✅ `ClickWatcher` passes `currentIdentifier` to `match()`
- ✅ `SkeletonItem.encode` uses `encodeIfPresent` — nil identifier absent from JSON
- ✅ Backend schema accepts optional `identifier` on skeleton items and `identifiers` on rule match
- ✅ Backend prompt shows `[id=…]` in skeleton lines + instructs Claude to emit `identifiers`
- ✅ All existing tests unaffected (default-nil params, synthesized Codable)

**No placeholders:** All code is complete and exact.

**Type consistency:**
- `RawAXItem.identifier: String?` → `SkeletonItem.identifier: String?` — same type, nil default preserved
- `LoadedMatch.identifiers: [String]?` — referenced as `rule.match.identifiers` in `RuleCache.match()`
- `identifier: String = ""` default in `match()` — all existing callers still compile
- `currentIdentifier` already `String` (lowercased) in `ClickWatcher` line 97

**Acceptance criteria:**
- [ ] Electron app knaku kliknięcia z `aria-keyshortcuts` → toast bez czekania na Layer 0.5
- [ ] `parseAriaShortcut("Meta+KeyK")` → `["meta", "k"]` (test zielony)
- [ ] Skeleton item z `identifier` serializuje się bez klucza `"identifier": null`
- [ ] `RuleCache.match` z pasującym identifierem zwraca regułę nawet gdy tytuły się nie zgadzają
- [ ] Stare testy nadal zielone (zero regresji)
- [ ] Backend akceptuje `identifier` w skeleton item i `identifiers` w match
