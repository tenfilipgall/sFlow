# Bundled.json Update Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the developer push a new `bundled.json` to production and have every user's SFlow silently pick it up within 7 days — without shipping a new app version.

**Architecture:** The backend gains a `GET /v1/bundled` endpoint that reads from the existing `RULES_CACHE` KV (keys `bundled:version` and `bundled:latest`). A developer-side bash script uploads the local `SFlow/Resources/bundled.json` to KV. On the client, `BundledUpdater` checks the version weekly (and on demand), writes a fresh `bundled.json` to `~/Library/Application Support/SFlow/rules/`, then reloads `RuleCache`. The "Force re-seed all rules" button in Settings fires a notification that triggers a forced update.

**Tech Stack:** TypeScript/Cloudflare Workers (KV, Vitest), Swift/AppKit (URLSession, UserDefaults, XCTest), bash/wrangler CLI

---

## File Map

**New files:**
- `backend/src/handlers/bundled.ts` — `GET /v1/bundled` handler
- `backend/tests/bundled.test.ts` — 3 backend tests
- `scripts/upload-bundled` — bash script to upload bundled.json to KV
- `SFlow/BundledUpdater.swift` — weekly check + force-update logic
- `SFlowTests/BundledUpdaterTests.swift` — unit tests for BundledUpdater

**Modified files:**
- `backend/src/index.ts` — wire `/v1/bundled` route
- `SFlow/DiscoveryClient.swift` — add `BundledResponse` struct + `fetchBundled() async throws`
- `SFlow/SettingsWindow.swift` — enable "Force re-seed all rules" button
- `SFlow/AppDelegate.swift` — create BundledUpdater, call checkOnStartup, observe notification
- `SFlow.xcodeproj/project.pbxproj` — register BundledUpdater.swift + BundledUpdaterTests.swift
- `docs/audit-phase-1.md` — mark session done

---

## Task 1: Backend GET /v1/bundled

**Files:**
- Create: `backend/src/handlers/bundled.ts`
- Modify: `backend/src/index.ts`
- Create: `backend/tests/bundled.test.ts`

- [ ] **Step 1: Write failing tests**

Create `backend/tests/bundled.test.ts`:

```typescript
import { env, SELF } from "cloudflare:test";
import { describe, expect, it, beforeEach } from "vitest";

describe("GET /v1/bundled", () => {
  beforeEach(async () => {
    await env.RULES_CACHE.delete("bundled:version");
    await env.RULES_CACHE.delete("bundled:latest");
  });

  it("returns 404 when not uploaded yet", async () => {
    const r = await SELF.fetch("https://example.com/v1/bundled");
    expect(r.status).toBe(404);
  });

  it("returns 405 on POST", async () => {
    const r = await SELF.fetch("https://example.com/v1/bundled", { method: "POST" });
    expect(r.status).toBe(405);
  });

  it("returns 200 with version and rules when uploaded", async () => {
    await env.RULES_CACHE.put("bundled:version", "2026-05-14T00:00:00Z");
    await env.RULES_CACHE.put(
      "bundled:latest",
      JSON.stringify([
        {
          bundleId: "com.x",
          appVersion: "1.0",
          fetchedAt: "2026-05-14T00:00:00Z",
          source: "bundled",
          rulesVersion: "2026-05-14T00:00:00Z",
          rules: [],
        },
      ]),
    );
    const r = await SELF.fetch("https://example.com/v1/bundled");
    expect(r.status).toBe(200);
    const body = (await r.json()) as any;
    expect(body.version).toBe("2026-05-14T00:00:00Z");
    expect(body.rules).toHaveLength(1);
    expect(body.rules[0].bundleId).toBe("com.x");
  });
});
```

- [ ] **Step 2: Run to verify failure**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow/backend && npm test 2>&1 | grep -E "bundled|FAIL|✗" | head -10
```

Expected: 3 tests FAIL (route not found, returns 404 instead of 405/404/200).

- [ ] **Step 3: Create backend/src/handlers/bundled.ts**

```typescript
import type { Env } from "../index";

export async function handleBundled(
  request: Request,
  env: Env,
): Promise<Response> {
  if (request.method !== "GET") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const [version, latest] = await Promise.all([
    env.RULES_CACHE.get("bundled:version"),
    env.RULES_CACHE.get("bundled:latest"),
  ]);

  if (!version || !latest) {
    return new Response(JSON.stringify({ error: "Not available" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({ version, rules: JSON.parse(latest) }),
    {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=3600",
      },
    },
  );
}
```

- [ ] **Step 4: Wire route in backend/src/index.ts**

Add import and route. Full file after change:

```typescript
import { handleDiscover } from "./handlers/discover";
import { handleFeedback } from "./handlers/feedback";
import { handleBundled } from "./handlers/bundled";

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

    if (url.pathname === "/v1/bundled") {
      return handleBundled(request, env);
    }

    if (url.pathname === "/" || url.pathname === "/health") {
      return new Response("SFlow Rules Worker", { status: 200 });
    }

    return new Response("Not Found", { status: 404 });
  },
};
```

- [ ] **Step 5: Run tests**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow/backend && npm test 2>&1 | tail -5
```

Expected: All tests pass (50 total: 47 existing + 3 new).

- [ ] **Step 6: TypeScript check**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow/backend && npx tsc --noEmit 2>&1 | grep -v "claude.ts"
```

Expected: No new errors.

- [ ] **Step 7: Commit**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow
git add backend/src/handlers/bundled.ts backend/src/index.ts backend/tests/bundled.test.ts
git commit -m "feat(backend): GET /v1/bundled serves latest bundled rules from KV"
```

---

## Task 2: Developer upload script

**Files:**
- Create: `scripts/upload-bundled`

No unit tests — this is a developer tool run manually.

- [ ] **Step 1: Create scripts/upload-bundled**

```bash
#!/usr/bin/env bash
# Uploads SFlow/Resources/bundled.json to Cloudflare KV so clients can auto-update.
# Run from project root: ./scripts/upload-bundled
set -euo pipefail

BUNDLED="SFlow/Resources/bundled.json"

if [[ ! -f "$BUNDLED" ]]; then
  echo "Error: $BUNDLED not found. Run from project root." >&2
  exit 1
fi

VERSION=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "Uploading bundled.json (version: $VERSION)..."
cd backend
wrangler kv key put "bundled:version" "$VERSION" --binding=RULES_CACHE --remote
wrangler kv key put "bundled:latest" --path="../$BUNDLED" --binding=RULES_CACHE --remote
echo "Done. Users will receive the update within 7 days or on next force-update."
```

- [ ] **Step 2: Make executable**

```bash
chmod +x /Users/filip/Claude/Projects/Apps/SFlow/scripts/upload-bundled
```

- [ ] **Step 3: Commit**

```bash
git add scripts/upload-bundled
git commit -m "feat(scripts): add upload-bundled to push bundled.json to KV"
```

---

## Task 3: DiscoveryClient.fetchBundled()

**Files:**
- Modify: `SFlow/DiscoveryClient.swift`
- Modify: `SFlowTests/DiscoveryClientTests.swift`

- [ ] **Step 1: Write failing test**

Add to `SFlowTests/DiscoveryClientTests.swift` inside the class:

```swift
func testParseBundledResponse() throws {
    let json = #"""
    {
      "version": "2026-05-14T00:00:00Z",
      "rules": [
        {
          "bundleId": "com.x",
          "appVersion": "1.0",
          "fetchedAt": "2026-05-14T00:00:00Z",
          "source": "bundled",
          "rulesVersion": "2026-05-14T00:00:00Z",
          "rules": []
        }
      ]
    }
    """#.data(using: .utf8)!
    let result = try JSONDecoder().decode(BundledResponse.self, from: json)
    XCTAssertEqual(result.version, "2026-05-14T00:00:00Z")
    XCTAssertEqual(result.rules.count, 1)
    XCTAssertEqual(result.rules[0].bundleId, "com.x")
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/DiscoveryClientTests/testParseBundledResponse \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "PASS|FAIL|error:" | head -5
```

Expected: FAIL — `BundledResponse` not found.

- [ ] **Step 3: Add BundledResponse and fetchBundled() to DiscoveryClient.swift**

Read `SFlow/DiscoveryClient.swift` first. Add after the `BackendRuleSet`-related code (after the closing `}` of `parseResponse`):

```swift
struct BundledResponse: Codable {
    let version: String
    let rules: [StoredRuleSet]
}
```

Then add `fetchBundled()` as a method on `DiscoveryClient`, after `parseResponse(_:)`:

```swift
func fetchBundled() async throws -> BundledResponse {
    let url = baseURL.appendingPathComponent("v1/bundled")
    let (data, response) = try await session.data(for: URLRequest(url: url))
    guard let http = response as? HTTPURLResponse,
          (200..<300).contains(http.statusCode) else {
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        throw DiscoveryClientError.http(code, String(data: data, encoding: .utf8) ?? "")
    }
    do {
        return try JSONDecoder().decode(BundledResponse.self, from: data)
    } catch {
        throw DiscoveryClientError.malformedResponse(error.localizedDescription)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/DiscoveryClientTests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Test Suite|passed|failed" | tail -5
```

Expected: All DiscoveryClientTests PASS.

- [ ] **Step 5: Commit**

```bash
git add SFlow/DiscoveryClient.swift SFlowTests/DiscoveryClientTests.swift
git commit -m "feat(client): add BundledResponse + fetchBundled() to DiscoveryClient"
```

---

## Task 4: BundledUpdater + tests

**Files:**
- Create: `SFlow/BundledUpdater.swift`
- Create: `SFlowTests/BundledUpdaterTests.swift`
- Modify: `SFlow.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing tests**

Create `SFlowTests/BundledUpdaterTests.swift`:

```swift
import XCTest
@testable import SFlow

final class BundledUpdaterTests: XCTestCase {
    private var tempDir: URL!
    private var rulesDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        rulesDir = tempDir.appendingPathComponent("rules")
        try! FileManager.default.createDirectory(at: rulesDir, withIntermediateDirectories: true)
        UserDefaults.standard.removeObject(forKey: "bundledLastCheck")
        UserDefaults.standard.removeObject(forKey: "bundledVersion")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        UserDefaults.standard.removeObject(forKey: "bundledLastCheck")
        UserDefaults.standard.removeObject(forKey: "bundledVersion")
        super.tearDown()
    }

    func test_shouldCheck_trueWhenNeverChecked() {
        let updater = BundledUpdater(fetch: { fatalError("not called") }, rulesDir: rulesDir)
        XCTAssertTrue(updater.shouldCheck())
    }

    func test_shouldCheck_falseWhenCheckedJustNow() {
        UserDefaults.standard.set(Date(), forKey: "bundledLastCheck")
        let updater = BundledUpdater(fetch: { fatalError("not called") }, rulesDir: rulesDir)
        XCTAssertFalse(updater.shouldCheck())
    }

    func test_shouldCheck_trueWhenLastCheckWasOld() {
        let oldDate = Date().addingTimeInterval(-8 * 86400)  // 8 days ago
        UserDefaults.standard.set(oldDate, forKey: "bundledLastCheck")
        let updater = BundledUpdater(fetch: { fatalError("not called") }, rulesDir: rulesDir)
        XCTAssertTrue(updater.shouldCheck())
    }

    func test_update_writesFileAndSetsVersion() async throws {
        let expectedVersion = "2026-05-14T12:00:00Z"
        let rules: [StoredRuleSet] = [
            StoredRuleSet(
                bundleId: "com.test",
                appVersion: "1.0",
                fetchedAt: expectedVersion,
                source: .bundled,
                rulesVersion: expectedVersion,
                rules: []
            )
        ]
        let response = BundledResponse(version: expectedVersion, rules: rules)

        let updater = BundledUpdater(fetch: { response }, rulesDir: rulesDir)
        await updater.update(force: true)

        let dest = rulesDir.appendingPathComponent("bundled.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.path))
        XCTAssertEqual(UserDefaults.standard.string(forKey: "bundledVersion"), expectedVersion)
    }

    func test_update_skipsWhenVersionUnchanged() async throws {
        let version = "2026-05-14T12:00:00Z"
        UserDefaults.standard.set(version, forKey: "bundledVersion")

        var fetchCalled = false
        let updater = BundledUpdater(
            fetch: { fetchCalled = true; return BundledResponse(version: version, rules: []) },
            rulesDir: rulesDir
        )
        await updater.update(force: false)

        // fetch was called but file write skipped (version unchanged)
        XCTAssertTrue(fetchCalled)
        let dest = rulesDir.appendingPathComponent("bundled.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest.path))
    }
}
```

- [ ] **Step 2: Register test file in project.pbxproj**

Add `BundledUpdaterTests.swift` to `SFlowTests` target in `SFlow.xcodeproj/project.pbxproj`. Use UUIDs `CAFE0206` (file ref) and `CAFE0207` (build file). Follow the same pattern as other `CAFE02xx` entries in the file.

In `/* Begin PBXBuildFile section */`:
```
		CAFE0207 /* BundledUpdaterTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = CAFE0206 /* BundledUpdaterTests.swift */; };
```

In `/* Begin PBXFileReference section */`:
```
		CAFE0206 /* BundledUpdaterTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BundledUpdaterTests.swift; sourceTree = "<group>"; };
```

In SFlowTests group children, add `CAFE0206`. In SFlowTests Sources build phase files, add `CAFE0207`.

- [ ] **Step 3: Run to verify failure**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/BundledUpdaterTests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "PASS|FAIL|error:" | head -8
```

Expected: FAIL — `BundledUpdater` not found.

- [ ] **Step 4: Create SFlow/BundledUpdater.swift**

```swift
import Foundation

final class BundledUpdater {
    private let fetch: () async throws -> BundledResponse
    private let rulesDir: URL
    private weak var ruleCache: RuleCache?
    private static let checkIntervalSeconds: TimeInterval = 7 * 86400

    init(client: DiscoveryClient, rulesDir: URL, ruleCache: RuleCache) {
        self.fetch = { try await client.fetchBundled() }
        self.rulesDir = rulesDir
        self.ruleCache = ruleCache
    }

    // Testable init — inject a custom fetch closure and skip ruleCache
    init(fetch: @escaping () async throws -> BundledResponse, rulesDir: URL) {
        self.fetch = fetch
        self.rulesDir = rulesDir
    }

    func shouldCheck() -> Bool {
        guard let last = UserDefaults.standard.object(forKey: "bundledLastCheck") as? Date else {
            return true
        }
        return Date().timeIntervalSince(last) > Self.checkIntervalSeconds
    }

    func checkOnStartup() {
        guard shouldCheck() else { return }
        Task { await update(force: false) }
    }

    func forceUpdate() async {
        await update(force: true)
    }

    func update(force: Bool) async {
        UserDefaults.standard.set(Date(), forKey: "bundledLastCheck")
        do {
            let response = try await fetch()
            let storedVersion = UserDefaults.standard.string(forKey: "bundledVersion") ?? ""
            guard force || response.version != storedVersion else { return }
            let data = try JSONEncoder().encode(response.rules)
            let dest = rulesDir.appendingPathComponent("bundled.json")
            try data.write(to: dest)
            UserDefaults.standard.set(response.version, forKey: "bundledVersion")
            try await MainActor.run { try self.ruleCache?.load() }
            NSLog("SFlow: bundled.json updated to version \(response.version)")
        } catch {
            NSLog("SFlow: bundled.json update failed: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 5: Register BundledUpdater.swift in project.pbxproj**

Add to SFlow app target. Use UUIDs `CAFE0208` (file ref) and `CAFE0209` (build file). Add to SFlow group children and SFlow app target Sources build phase.

- [ ] **Step 6: Run tests**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' \
  -only-testing:SFlowTests/BundledUpdaterTests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Test Suite|passed|failed" | tail -5
```

Expected: All 4 BundledUpdaterTests PASS.

- [ ] **Step 7: Run full suite**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "Test Suite 'All tests' passed|FAIL" | tail -3
```

Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add SFlow/BundledUpdater.swift SFlowTests/BundledUpdaterTests.swift \
        SFlow.xcodeproj/project.pbxproj
git commit -m "feat(client): BundledUpdater — weekly auto-update of bundled.json from server"
```

---

## Task 5: Settings button + AppDelegate wiring

**Files:**
- Modify: `SFlow/SettingsWindow.swift`
- Modify: `SFlow/AppDelegate.swift`

- [ ] **Step 1: Add notification name + enable button in SettingsWindow.swift**

Read `SFlow/SettingsWindow.swift`. Add this extension before or after `SettingsView`:

```swift
extension Notification.Name {
    static let sflowForceReSeed = Notification.Name("com.sflow.forceReSeed")
}
```

Replace the disabled button block in `AdvancedTab`:

Old:
```swift
            Form {
                Button("Force re-seed all rules") {}
                    .disabled(true)
                    .help("Coming in Session 6.")
            }
            .padding([.horizontal, .bottom])
```

New:
```swift
            Form {
                Button("Update built-in rules") {
                    NotificationCenter.default.post(name: .sflowForceReSeed, object: nil)
                }
                .help("Downloads the latest built-in shortcuts from the server.")
            }
            .padding([.horizontal, .bottom])
```

- [ ] **Step 2: Wire BundledUpdater in AppDelegate.swift**

Read `SFlow/AppDelegate.swift`. Add a property declaration near the other private vars:

```swift
private var bundledUpdater: BundledUpdater?
```

In `startWatcher()`, after creating `client` and before `discoveryService = DiscoveryService(...)`:

```swift
        let updater = BundledUpdater(
            client: client,
            rulesDir: RuleStorage.userRulesDirectory(),
            ruleCache: ruleCache
        )
        bundledUpdater = updater
        updater.checkOnStartup()

        NotificationCenter.default.addObserver(
            forName: .sflowForceReSeed, object: nil, queue: .main
        ) { [weak updater] _ in
            Task { await updater?.forceUpdate() }
        }
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -scheme SFlow -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run full test suite**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "Test Suite 'All tests' passed|FAIL" | tail -3
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add SFlow/SettingsWindow.swift SFlow/AppDelegate.swift
git commit -m "feat: wire BundledUpdater into AppDelegate + enable Update built-in rules button"
```

---

## Task 6: Audit docs update

**Files:**
- Modify: `docs/audit-phase-1.md`

- [ ] **Step 1: Update session row**

In `docs/audit-phase-1.md`, find the session row for "Bundled.json update path" (currently Session 11) and mark `⬜` → `🟢 done`.

- [ ] **Step 2: Commit**

```bash
git add docs/audit-phase-1.md
git commit -m "docs: mark bundled.json update path session complete"
```

---

## Self-Review

### Spec coverage

| Requirement | Task |
|---|---|
| Backend endpoint `GET /v1/bundled` serving KV content | Task 1 |
| 404 when not uploaded, 405 for non-GET | Task 1 |
| Developer upload script using wrangler | Task 2 |
| `BundledResponse` Codable struct | Task 3 |
| `DiscoveryClient.fetchBundled()` | Task 3 |
| `BundledUpdater.shouldCheck()` — 7-day cooldown | Task 4 |
| `BundledUpdater.checkOnStartup()` — runs on first launch | Task 4/5 |
| `BundledUpdater.forceUpdate()` — skips version check | Task 4/5 |
| Writes new bundled.json to rules dir on version change | Task 4 |
| Reloads RuleCache after write | Task 4 |
| "Update built-in rules" button in Settings fires notification | Task 5 |
| AppDelegate observes notification + calls forceUpdate | Task 5 |
| Tests for shouldCheck (3 cases) + update logic (2 cases) | Task 4 |
| Backend tests (404/405/200) | Task 1 |

### Placeholder scan

No TBD or "implement later" present. All code is complete.

### Type consistency

- `BundledResponse` defined in Task 3 (`DiscoveryClient.swift`), used in Task 4 (`BundledUpdater.swift`) — same struct, consistent ✓
- `BundledUpdater.update(force:)` is `internal` (not `private`) so tests can call it — verified ✓
- `StoredRuleSet` already `Codable` — used in `BundledResponse.rules: [StoredRuleSet]` — `JSONEncoder().encode(response.rules)` produces `[{...}]` array that `RuleCache.loadFile` reads as `[StoredRuleSet]` — consistent ✓
- `Notification.Name.sflowForceReSeed` defined in `SettingsWindow.swift`, used in `AppDelegate.swift` — both in same module, accessible ✓
