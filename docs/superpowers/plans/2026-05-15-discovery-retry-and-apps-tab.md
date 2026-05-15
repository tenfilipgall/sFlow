# Discovery Retry + Apps Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add persisted retry-with-backoff for failed app discovery (P-2/P-3) plus a beta-only Apps tab in Settings showing discovery state per app with a "Try again" button.

**Architecture:** New `DiscoveryAttemptStore` persists per-bundleId failure history to `~/Library/Application Support/SFlow/attempted.json` with exponential backoff (1h/24h/7d/30d cap). `DiscoveryService` consults the store before attempting, does a 15s pre-check retry when AX is unloaded, classifies failures into `DiscoveryFailureReason` cases, publishes `NotificationCenter` state-change events, and exposes a `forceRetry(bundleId:)` API. A new SwiftUI `AppsTab` (hidden behind a `showDeveloperFeatures` toggle in Advanced) renders bundled/learned/failed lists and reacts to state-change notifications.

**Tech Stack:** Swift/AppKit (Foundation persistence, URLSession, XCTest, SwiftUI for tab), no backend changes.

**Spec:** `docs/superpowers/specs/2026-05-15-discovery-retry-and-apps-tab-design.md`

---

## File Map

**New files:**
- `SFlow/DiscoveryFailureReason.swift` — enum with 6 cases + display strings
- `SFlow/DiscoveryAttemptStore.swift` — persisted store + backoff math
- `SFlow/AppsTab.swift` — SwiftUI view + view-model + entry types
- `SFlowTests/DiscoveryAttemptStoreTests.swift` — 8 store tests
- `SFlowTests/DiscoveryFailureReasonTests.swift` — 1 mapping test (DiscoveryClientError → reason)

**Modified files:**
- `SFlow/DiscoveryService.swift` — inject store, pre-check, reason classification, `forceRetry`, notification publish
- `SFlow/AppDelegate.swift` — `static var shared`, instantiate store, pass to service
- `SFlow/SettingsWindow.swift` — `showDeveloperFeatures` toggle in Advanced, conditional Apps tab
- `SFlow.xcodeproj/project.pbxproj` — register 5 new Swift files (3 source + 2 test)
- `docs/audit-phase-0.md` — flip P-2/P-3 to 🟢 done
- `docs/audit-phase-1.md` — flip Sub-cel 1.2 to 🟢 done, update sesja 8.5
- `docs/roadmap.md` — session log entry for completed session 8

---

## Task 1: DiscoveryFailureReason enum

**Files:**
- Create: `SFlow/DiscoveryFailureReason.swift`

- [ ] **Step 1: Create the enum file**

Create `SFlow/DiscoveryFailureReason.swift`:

```swift
import Foundation

/// Why a single discovery attempt for a bundleId failed.
/// Persisted as `rawValue` in `attempted.json`.
enum DiscoveryFailureReason: String, Codable, CaseIterable {
    case emptySkeleton = "empty_skeleton"
    case emptyMenuBar = "empty_menu_bar"
    case rateLimited = "rate_limited"
    case httpError = "http_error"
    case parseError = "parse_error"
    case noRulesGenerated = "no_rules_generated"

    var displayString: String {
        switch self {
        case .emptySkeleton: return "App not ready yet (empty UI tree)"
        case .emptyMenuBar: return "App has no menu bar"
        case .rateLimited: return "Server: too many requests"
        case .httpError: return "Server error or no internet"
        case .parseError: return "Server returned invalid response"
        case .noRulesGenerated: return "AI returned no rules"
        }
    }

    /// Map a thrown `DiscoveryClientError` to a reason for the store.
    /// `URLError` and other generic Errors map to `.httpError` (network class).
    static func from(error: Error) -> DiscoveryFailureReason {
        if let clientError = error as? DiscoveryClientError {
            switch clientError {
            case .rateLimited: return .rateLimited
            case .malformedResponse: return .parseError
            case .http: return .httpError
            }
        }
        return .httpError
    }
}
```

- [ ] **Step 2: Register file in Xcode project**

Run:

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && \
xcodebuild -project SFlow.xcodeproj -scheme SFlow -showBuildSettings >/dev/null 2>&1 || true
```

Then add the file to `SFlow.xcodeproj/project.pbxproj` by following the same pattern as `BundledUpdater.swift`:
1. Grep for `BundledUpdater.swift` (4 occurrences) and add corresponding lines for `DiscoveryFailureReason.swift`.

Run:

```bash
grep -n "BundledUpdater.swift" /Users/filip/Claude/Projects/Apps/SFlow/SFlow.xcodeproj/project.pbxproj
```

For each occurrence, add a sibling entry with a fresh 24-char hex object ID (use `openssl rand -hex 12` to generate).

- [ ] **Step 3: Verify build**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && \
xcodebuild -project SFlow.xcodeproj -scheme SFlow build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && \
git add SFlow/DiscoveryFailureReason.swift SFlow.xcodeproj/project.pbxproj && \
git commit -m "feat: add DiscoveryFailureReason enum

Adresuje część P-2 (klasyfikacja failure reason w discovery flow).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: DiscoveryFailureReason — error mapping test

**Files:**
- Create: `SFlowTests/DiscoveryFailureReasonTests.swift`

- [ ] **Step 1: Write the failing test**

Create `SFlowTests/DiscoveryFailureReasonTests.swift`:

```swift
import XCTest
@testable import SFlow

final class DiscoveryFailureReasonTests: XCTestCase {
    func test_from_rateLimited() {
        let e: Error = DiscoveryClientError.rateLimited(retryAfterSeconds: 60)
        XCTAssertEqual(DiscoveryFailureReason.from(error: e), .rateLimited)
    }

    func test_from_malformedResponse() {
        let e: Error = DiscoveryClientError.malformedResponse("bad json")
        XCTAssertEqual(DiscoveryFailureReason.from(error: e), .parseError)
    }

    func test_from_http() {
        let e: Error = DiscoveryClientError.http(500, "boom")
        XCTAssertEqual(DiscoveryFailureReason.from(error: e), .httpError)
    }

    func test_from_unknownError_fallsBackToHttp() {
        struct Boom: Error {}
        XCTAssertEqual(DiscoveryFailureReason.from(error: Boom()), .httpError)
    }

    func test_rawValuesRoundTrip() {
        for reason in DiscoveryFailureReason.allCases {
            let decoded = DiscoveryFailureReason(rawValue: reason.rawValue)
            XCTAssertEqual(decoded, reason)
        }
    }
}
```

- [ ] **Step 2: Register test file in Xcode project**

Same pattern as Task 1 Step 2 but for `SFlowTests` target. Grep for `BundledUpdaterTests.swift` for reference.

- [ ] **Step 3: Run tests to verify they pass**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && \
xcodebuild test -project SFlow.xcodeproj -scheme SFlow \
  -only-testing:SFlowTests/DiscoveryFailureReasonTests 2>&1 | tail -10
```

Expected: 5 tests passing.

- [ ] **Step 4: Commit**

```bash
git add SFlowTests/DiscoveryFailureReasonTests.swift SFlow.xcodeproj/project.pbxproj && \
git commit -m "test: DiscoveryFailureReason error mapping (5 tests)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: DiscoveryAttemptStore — skeleton + persistence

**Files:**
- Create: `SFlow/DiscoveryAttemptStore.swift`
- Create: `SFlowTests/DiscoveryAttemptStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Create `SFlowTests/DiscoveryAttemptStoreTests.swift`:

```swift
import XCTest
@testable import SFlow

final class DiscoveryAttemptStoreTests: XCTestCase {
    private var tempDir: URL!
    private var storeFile: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storeFile = tempDir.appendingPathComponent("attempted.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_empty_store_canAttempt_returnsTrueForAnyBundle() {
        let store = DiscoveryAttemptStore(fileURL: storeFile)
        XCTAssertTrue(store.canAttempt(bundleId: "com.x"))
        XCTAssertTrue(store.allFailures().isEmpty)
    }

    func test_missing_file_loads_as_empty() {
        // storeFile does not exist
        let store = DiscoveryAttemptStore(fileURL: storeFile)
        XCTAssertTrue(store.allFailures().isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && \
xcodebuild test -project SFlow.xcodeproj -scheme SFlow \
  -only-testing:SFlowTests/DiscoveryAttemptStoreTests 2>&1 | tail -10
```

Expected: compile error "Cannot find 'DiscoveryAttemptStore'".

- [ ] **Step 3: Create DiscoveryAttemptStore.swift**

Create `SFlow/DiscoveryAttemptStore.swift`:

```swift
import Foundation

/// Persisted record of one bundleId's most-recent discovery failure.
struct DiscoveryAttemptEntry: Codable, Equatable {
    let bundleId: String
    let lastAttemptAt: Date
    let failureCount: Int
    let lastReason: DiscoveryFailureReason
    let nextRetryAt: Date
}

/// Tracks per-bundleId discovery failure state with exponential backoff.
///
/// Invariant: entry exists in `attempts` iff `failureCount >= 1`.
/// Success or `forceRetry` removes the entry.
final class DiscoveryAttemptStore {
    private struct FileState: Codable {
        var version: Int
        var attempts: [String: StoredAttempt]
    }

    private struct StoredAttempt: Codable {
        let lastAttemptAt: Date
        let failureCount: Int
        let lastReason: String
        let nextRetryAt: Date
    }

    private let fileURL: URL
    private let clock: () -> Date
    private var attempts: [String: StoredAttempt]
    private let queue = DispatchQueue(label: "com.filip.sflow.attemptStore")

    init(fileURL: URL, clock: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.clock = clock
        self.attempts = Self.load(from: fileURL)
    }

    func canAttempt(bundleId: String) -> Bool {
        queue.sync {
            guard let entry = attempts[bundleId] else { return true }
            return clock() >= entry.nextRetryAt
        }
    }

    func allFailures() -> [DiscoveryAttemptEntry] {
        queue.sync {
            attempts.compactMap { (bundleId, stored) in
                guard let reason = DiscoveryFailureReason(rawValue: stored.lastReason) else {
                    return nil
                }
                return DiscoveryAttemptEntry(
                    bundleId: bundleId,
                    lastAttemptAt: stored.lastAttemptAt,
                    failureCount: stored.failureCount,
                    lastReason: reason,
                    nextRetryAt: stored.nextRetryAt
                )
            }.sorted { $0.bundleId < $1.bundleId }
        }
    }

    // MARK: - Persistence

    private static func load(from url: URL) -> [String: StoredAttempt] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return [:]
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(FileState.self, from: data),
              state.version == 1 else {
            NSLog("SFlow: attempted.json invalid or wrong version — starting empty")
            // Backup the bad file for inspection
            let backup = url.appendingPathExtension("bak")
            try? FileManager.default.moveItem(at: url, to: backup)
            return [:]
        }
        return state.attempts
    }

    private func save() {
        let state = FileState(version: 1, attempts: attempts)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(state) else {
            NSLog("SFlow: failed to encode attempted.json")
            return
        }
        // Atomic write: temp + rename
        let tmp = fileURL.appendingPathExtension("tmp")
        do {
            try? FileManager.default.removeItem(at: tmp)
            try data.write(to: tmp)
            try? FileManager.default.removeItem(at: fileURL)
            try FileManager.default.moveItem(at: tmp, to: fileURL)
        } catch {
            NSLog("SFlow: failed to write attempted.json: \(error)")
        }
    }
}
```

- [ ] **Step 4: Register both files in Xcode project**

Same pattern as Task 1.

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && \
xcodebuild test -project SFlow.xcodeproj -scheme SFlow \
  -only-testing:SFlowTests/DiscoveryAttemptStoreTests 2>&1 | tail -10
```

Expected: 2 tests passing.

- [ ] **Step 6: Commit**

```bash
git add SFlow/DiscoveryAttemptStore.swift SFlowTests/DiscoveryAttemptStoreTests.swift SFlow.xcodeproj/project.pbxproj && \
git commit -m "feat: DiscoveryAttemptStore skeleton + persistence

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: DiscoveryAttemptStore — recordFailure with backoff

**Files:**
- Modify: `SFlow/DiscoveryAttemptStore.swift`
- Modify: `SFlowTests/DiscoveryAttemptStoreTests.swift`

- [ ] **Step 1: Write failing tests**

Append to `SFlowTests/DiscoveryAttemptStoreTests.swift` (inside the class):

```swift
func test_recordFailure_first_setsCountOneAnd1h() {
    let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    let store = DiscoveryAttemptStore(fileURL: storeFile, clock: { fixedNow })

    store.recordFailure(bundleId: "com.x", reason: .emptySkeleton)

    let entries = store.allFailures()
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].failureCount, 1)
    XCTAssertEqual(entries[0].lastReason, .emptySkeleton)
    XCTAssertEqual(entries[0].nextRetryAt.timeIntervalSince(fixedNow), 3600, accuracy: 1)
}

func test_recordFailure_second_setsCountTwoAnd24h() {
    let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    let store = DiscoveryAttemptStore(fileURL: storeFile, clock: { fixedNow })

    store.recordFailure(bundleId: "com.x", reason: .httpError)
    store.recordFailure(bundleId: "com.x", reason: .httpError)

    let entries = store.allFailures()
    XCTAssertEqual(entries[0].failureCount, 2)
    XCTAssertEqual(entries[0].nextRetryAt.timeIntervalSince(fixedNow), 86_400, accuracy: 1)
}

func test_recordFailure_third_sets7d() {
    let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    let store = DiscoveryAttemptStore(fileURL: storeFile, clock: { fixedNow })

    for _ in 0..<3 { store.recordFailure(bundleId: "com.x", reason: .httpError) }

    XCTAssertEqual(store.allFailures()[0].failureCount, 3)
    XCTAssertEqual(store.allFailures()[0].nextRetryAt.timeIntervalSince(fixedNow), 7 * 86_400, accuracy: 1)
}

func test_recordFailure_fourthAndBeyond_cappedAt30d() {
    let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    let store = DiscoveryAttemptStore(fileURL: storeFile, clock: { fixedNow })

    for _ in 0..<6 { store.recordFailure(bundleId: "com.x", reason: .httpError) }

    XCTAssertEqual(store.allFailures()[0].failureCount, 6)
    XCTAssertEqual(store.allFailures()[0].nextRetryAt.timeIntervalSince(fixedNow), 30 * 86_400, accuracy: 1)
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlow \
  -only-testing:SFlowTests/DiscoveryAttemptStoreTests 2>&1 | tail -10
```

Expected: compile error "Value of type 'DiscoveryAttemptStore' has no member 'recordFailure'".

- [ ] **Step 3: Add recordFailure to DiscoveryAttemptStore**

Append inside `DiscoveryAttemptStore` (after `allFailures()`):

```swift
// MARK: - Mutations

func recordFailure(bundleId: String, reason: DiscoveryFailureReason) {
    queue.sync {
        let now = clock()
        let previousCount = attempts[bundleId]?.failureCount ?? 0
        let newCount = previousCount + 1
        let delay: TimeInterval
        switch newCount {
        case 1:  delay = 3_600          // 1h
        case 2:  delay = 86_400         // 24h
        case 3:  delay = 7 * 86_400     // 7d
        default: delay = 30 * 86_400    // 30d (cap)
        }
        attempts[bundleId] = StoredAttempt(
            lastAttemptAt: now,
            failureCount: newCount,
            lastReason: reason.rawValue,
            nextRetryAt: now.addingTimeInterval(delay)
        )
        save()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlow \
  -only-testing:SFlowTests/DiscoveryAttemptStoreTests 2>&1 | tail -10
```

Expected: 6 tests passing (2 from Task 3 + 4 new).

- [ ] **Step 5: Commit**

```bash
git add SFlow/DiscoveryAttemptStore.swift SFlowTests/DiscoveryAttemptStoreTests.swift && \
git commit -m "feat: recordFailure with 1h/24h/7d/30d backoff schedule

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: DiscoveryAttemptStore — recordSuccess + forceRetry + canAttempt

**Files:**
- Modify: `SFlow/DiscoveryAttemptStore.swift`
- Modify: `SFlowTests/DiscoveryAttemptStoreTests.swift`

- [ ] **Step 1: Write failing tests**

Append to `SFlowTests/DiscoveryAttemptStoreTests.swift`:

```swift
func test_recordSuccess_removesEntry() {
    let store = DiscoveryAttemptStore(fileURL: storeFile)
    store.recordFailure(bundleId: "com.x", reason: .emptySkeleton)
    store.recordFailure(bundleId: "com.x", reason: .emptySkeleton)
    XCTAssertEqual(store.allFailures().count, 1)

    store.recordSuccess(bundleId: "com.x")

    XCTAssertTrue(store.allFailures().isEmpty)
    XCTAssertTrue(store.canAttempt(bundleId: "com.x"))
}

func test_forceRetry_resetsEntry() {
    let store = DiscoveryAttemptStore(fileURL: storeFile)
    store.recordFailure(bundleId: "com.x", reason: .httpError)

    store.forceRetry(bundleId: "com.x")

    XCTAssertTrue(store.allFailures().isEmpty)
    XCTAssertTrue(store.canAttempt(bundleId: "com.x"))
}

func test_canAttempt_falseDuringBackoffWindow() {
    var fakeNow = Date(timeIntervalSince1970: 1_700_000_000)
    let store = DiscoveryAttemptStore(fileURL: storeFile, clock: { fakeNow })
    store.recordFailure(bundleId: "com.x", reason: .httpError)

    XCTAssertFalse(store.canAttempt(bundleId: "com.x"))
    fakeNow = fakeNow.addingTimeInterval(3_500)  // 58min later — still locked
    XCTAssertFalse(store.canAttempt(bundleId: "com.x"))
    fakeNow = fakeNow.addingTimeInterval(200)    // total 1h+ later
    XCTAssertTrue(store.canAttempt(bundleId: "com.x"))
}

func test_persistence_roundTrip() {
    let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    do {
        let store = DiscoveryAttemptStore(fileURL: storeFile, clock: { fixedNow })
        store.recordFailure(bundleId: "com.a", reason: .emptySkeleton)
        store.recordFailure(bundleId: "com.b", reason: .rateLimited)
        store.recordFailure(bundleId: "com.b", reason: .rateLimited)
    }
    let reloaded = DiscoveryAttemptStore(fileURL: storeFile, clock: { fixedNow })
    let entries = reloaded.allFailures()
    XCTAssertEqual(entries.count, 2)
    XCTAssertEqual(entries.first(where: { $0.bundleId == "com.a" })?.failureCount, 1)
    XCTAssertEqual(entries.first(where: { $0.bundleId == "com.b" })?.failureCount, 2)
    XCTAssertEqual(entries.first(where: { $0.bundleId == "com.b" })?.lastReason, .rateLimited)
}
```

- [ ] **Step 2: Add recordSuccess + forceRetry to DiscoveryAttemptStore**

Append inside `DiscoveryAttemptStore` (after `recordFailure`):

```swift
func recordSuccess(bundleId: String) {
    queue.sync {
        if attempts.removeValue(forKey: bundleId) != nil {
            save()
        }
    }
}

func forceRetry(bundleId: String) {
    queue.sync {
        if attempts.removeValue(forKey: bundleId) != nil {
            save()
        }
    }
}
```

- [ ] **Step 3: Run all store tests to verify they pass**

```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlow \
  -only-testing:SFlowTests/DiscoveryAttemptStoreTests 2>&1 | tail -10
```

Expected: 10 tests passing (6 from prior + 4 new).

- [ ] **Step 4: Commit**

```bash
git add SFlow/DiscoveryAttemptStore.swift SFlowTests/DiscoveryAttemptStoreTests.swift && \
git commit -m "feat: recordSuccess + forceRetry + canAttempt + persistence tests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: DiscoveryService — wire AttemptStore + canAttempt gate

**Files:**
- Modify: `SFlow/DiscoveryService.swift`

- [ ] **Step 1: Update DiscoveryService init + appActivated to use store**

In `SFlow/DiscoveryService.swift`, replace the existing class properties + init + `appActivated` body with the version below. Also add a top-level Notification.Name extension.

At the top of the file (after the existing `import` lines and the `DiscoveryStatus` enum), add:

```swift
extension Notification.Name {
    static let sflowDiscoveryStateChanged =
        Notification.Name("com.sflow.discoveryStateChanged")
}
```

Then replace the existing properties and init:

```swift
final class DiscoveryService {
    private let client: DiscoveryClient
    private let ruleCache: RuleCache
    private let rulesDir: URL
    private let attemptStore: DiscoveryAttemptStore
    private var inFlight: Set<String> = []
    private let queue = DispatchQueue(label: "com.filip.sflow.discovery", qos: .utility)
    var onStatusChange: ((DiscoveryStatus) -> Void)?

    init(client: DiscoveryClient,
         ruleCache: RuleCache,
         rulesDir: URL,
         attemptStore: DiscoveryAttemptStore) {
        self.client = client
        self.ruleCache = ruleCache
        self.rulesDir = rulesDir
        self.attemptStore = attemptStore
    }
```

Note: removed the `attempted: Set<String>` in-memory set — replaced by store.

Then replace `appActivated`:

```swift
    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
        guard let bundleId = app.bundleIdentifier else { return }
        if ruleCache.hasRules(bundleId: bundleId) { return }
        if inFlight.contains(bundleId) { return }
        if !attemptStore.canAttempt(bundleId: bundleId) { return }

        inFlight.insert(bundleId)

        let appName = app.localizedName ?? bundleId
        let appVersion = readAppVersion(app) ?? "unknown"
        onStatusChange?(.running(appName: appName))

        queue.async { [weak self] in
            self?.runDiscovery(app: app, bundleId: bundleId,
                               appName: appName, appVersion: appVersion)
        }
    }
```

- [ ] **Step 2: Add runDiscovery helper (carve out from the prior closure body)**

Add the following method to `DiscoveryService` (the old inline closure body becomes a private method; keep behavior identical for now — pre-check and reason classification come in Tasks 7-8):

```swift
    private func runDiscovery(app: NSRunningApplication,
                              bundleId: String,
                              appName: String,
                              appVersion: String) {
        let menuBar = MenuBarDumper.dump(for: app)
        let skeleton = AXSkeletonExtractor.extract(for: app)
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.client.discover(
                    bundleId: bundleId, appName: appName, appVersion: appVersion,
                    menuBar: menuBar, skeleton: skeleton
                )
                try self.writeToCache(bundleId: bundleId, appVersion: appVersion, result: result)
                try self.ruleCache.load()
                await MainActor.run { self.onStatusChange?(.completed(appName: appName)) }
            } catch {
                await MainActor.run {
                    self.onStatusChange?(.failed(appName: appName, message: "\(error)"))
                }
            }
            self.inFlight.remove(bundleId)
        }
    }
```

- [ ] **Step 3: Verify build still passes**

```bash
xcodebuild build -project SFlow.xcodeproj -scheme SFlow 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. AppDelegate will fail to compile (init signature changed) — proper wiring lands in Task 10. To pass this step's build, temporarily change `AppDelegate.swift` line creating `DiscoveryService(...)`: replace with placeholder that passes a throwaway store. Specifically replace:

```swift
discoveryService = DiscoveryService(
    client: client,
    ruleCache: ruleCache,
    rulesDir: RuleStorage.userRulesDirectory()
)
```

with:

```swift
let _attemptStore = DiscoveryAttemptStore(
    fileURL: RuleStorage.userRulesDirectory()
        .deletingLastPathComponent()
        .appendingPathComponent("attempted.json")
)
discoveryService = DiscoveryService(
    client: client,
    ruleCache: ruleCache,
    rulesDir: RuleStorage.userRulesDirectory(),
    attemptStore: _attemptStore
)
```

(The proper `static var shared` wiring lands in Task 10 — this is just a stop-gap to keep the project compiling.)

- [ ] **Step 4: Commit**

```bash
git add SFlow/DiscoveryService.swift SFlow/AppDelegate.swift && \
git commit -m "refactor: DiscoveryService uses AttemptStore for canAttempt gate

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: DiscoveryService — 15s pre-check for empty AX

**Files:**
- Modify: `SFlow/DiscoveryService.swift`

- [ ] **Step 1: Replace runDiscovery body with pre-check**

Replace the body of `runDiscovery(app:bundleId:appName:appVersion:)` with:

```swift
    private func runDiscovery(app: NSRunningApplication,
                              bundleId: String,
                              appName: String,
                              appVersion: String) {
        var menuBar = MenuBarDumper.dump(for: app)
        var skeleton = AXSkeletonExtractor.extract(for: app)

        if skeleton.count < 3 && menuBar.isEmpty {
            // App likely still loading AX tree — wait 15s and retry once
            NSLog("SFlow: empty AX for \(bundleId), waiting 15s for app to settle")
            Thread.sleep(forTimeInterval: 15)
            menuBar = MenuBarDumper.dump(for: app)
            skeleton = AXSkeletonExtractor.extract(for: app)
        }

        if skeleton.count < 3 && menuBar.isEmpty {
            self.attemptStore.recordFailure(bundleId: bundleId, reason: .emptySkeleton)
            DispatchQueue.main.async {
                self.onStatusChange?(.failed(
                    appName: appName,
                    message: DiscoveryFailureReason.emptySkeleton.displayString
                ))
                NotificationCenter.default.post(
                    name: .sflowDiscoveryStateChanged, object: nil
                )
            }
            self.inFlight.remove(bundleId)
            return
        }

        Task { [weak self] in
            await self?.callBackendAndStore(
                bundleId: bundleId, appName: appName, appVersion: appVersion,
                menuBar: menuBar, skeleton: skeleton
            )
        }
    }
```

(`callBackendAndStore` is added in Task 8.)

- [ ] **Step 2: Add stub for callBackendAndStore so the file compiles**

Add to `DiscoveryService`:

```swift
    private func callBackendAndStore(
        bundleId: String, appName: String, appVersion: String,
        menuBar: [MenuBarDumpEntry], skeleton: [SkeletonItem]
    ) async {
        // Real implementation in Task 8
        await MainActor.run { self.onStatusChange?(.idle) }
        self.inFlight.remove(bundleId)
    }
```

- [ ] **Step 3: Verify build passes**

```bash
xcodebuild build -project SFlow.xcodeproj -scheme SFlow 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add SFlow/DiscoveryService.swift && \
git commit -m "feat: DiscoveryService 15s pre-check for unloaded AX

Adresuje race condition gdy apka aktywuje się w pierwszych sekundach po
starcie systemu (Notion w autostarcie → pusty skeleton → trwale zepsute
reguły bez retry).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: DiscoveryService — classify errors + recordSuccess/Failure

**Files:**
- Modify: `SFlow/DiscoveryService.swift`

- [ ] **Step 1: Replace callBackendAndStore with real implementation**

Replace the stub from Task 7 with:

```swift
    private func callBackendAndStore(
        bundleId: String, appName: String, appVersion: String,
        menuBar: [MenuBarDumpEntry], skeleton: [SkeletonItem]
    ) async {
        defer {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .sflowDiscoveryStateChanged, object: nil
                )
            }
            self.inFlight.remove(bundleId)
        }

        let result: BackendRuleSet
        do {
            result = try await self.client.discover(
                bundleId: bundleId, appName: appName, appVersion: appVersion,
                menuBar: menuBar, skeleton: skeleton
            )
        } catch {
            let reason = DiscoveryFailureReason.from(error: error)
            self.attemptStore.recordFailure(bundleId: bundleId, reason: reason)
            await MainActor.run {
                self.onStatusChange?(.failed(
                    appName: appName, message: reason.displayString
                ))
            }
            return
        }

        if result.rules.isEmpty {
            self.attemptStore.recordFailure(bundleId: bundleId, reason: .noRulesGenerated)
            await MainActor.run {
                self.onStatusChange?(.failed(
                    appName: appName,
                    message: DiscoveryFailureReason.noRulesGenerated.displayString
                ))
            }
            return
        }

        do {
            try self.writeToCache(bundleId: bundleId, appVersion: appVersion, result: result)
            try self.ruleCache.load()
            self.attemptStore.recordSuccess(bundleId: bundleId)
            await MainActor.run {
                self.onStatusChange?(.completed(appName: appName))
            }
        } catch {
            // Local I/O failure — classify as parseError (closest match) so
            // the entry persists and backoff applies. Treat as transient.
            self.attemptStore.recordFailure(bundleId: bundleId, reason: .parseError)
            await MainActor.run {
                self.onStatusChange?(.failed(
                    appName: appName, message: "Failed to write rule cache"
                ))
            }
        }
    }
```

- [ ] **Step 2: Verify build passes**

```bash
xcodebuild build -project SFlow.xcodeproj -scheme SFlow 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add SFlow/DiscoveryService.swift && \
git commit -m "feat: classify discovery failures + recordSuccess on completion

DiscoveryClientError → DiscoveryFailureReason mapping + empty rules =
.noRulesGenerated. Posts NotificationCenter event on state change for
Apps tab.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: DiscoveryService — forceRetry public API

**Files:**
- Modify: `SFlow/DiscoveryService.swift`

- [ ] **Step 1: Add forceRetry to DiscoveryService**

Append to `DiscoveryService`:

```swift
    /// User-initiated retry triggered from Apps tab.
    /// Resets the backoff entry and runs the discovery pipeline immediately.
    /// If the app is not currently running, emits a `.failed` status with
    /// guidance to launch the app first.
    func forceRetry(bundleId: String) {
        attemptStore.forceRetry(bundleId: bundleId)

        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleId
        ).first else {
            DispatchQueue.main.async {
                self.onStatusChange?(.failed(
                    appName: bundleId,
                    message: "Launch the app first, then try again"
                ))
                NotificationCenter.default.post(
                    name: .sflowDiscoveryStateChanged, object: nil
                )
            }
            return
        }

        if inFlight.contains(bundleId) { return }
        inFlight.insert(bundleId)

        let appName = app.localizedName ?? bundleId
        let appVersion = readAppVersion(app) ?? "unknown"
        DispatchQueue.main.async {
            self.onStatusChange?(.running(appName: appName))
        }

        queue.async { [weak self] in
            self?.runDiscovery(app: app, bundleId: bundleId,
                               appName: appName, appVersion: appVersion)
        }
    }
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild build -project SFlow.xcodeproj -scheme SFlow 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add SFlow/DiscoveryService.swift && \
git commit -m "feat: DiscoveryService.forceRetry(bundleId:) public API

Wywoływane z Apps tab. Resetuje store entry + uruchamia pipeline
natychmiast. Bez działającej apki → status .failed z 'Launch first'.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: AppDelegate.shared + wire up store

**Files:**
- Modify: `SFlow/AppDelegate.swift`

- [ ] **Step 1: Add static shared + store property**

Edit `SFlow/AppDelegate.swift`:

1. Add `static var shared: AppDelegate?` near the top of the class:

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    private var statusItem: NSStatusItem!
    private var clickWatcher: ClickWatcher?
    private var ruleCache: RuleCache!
    private var discoveryService: DiscoveryService?
    private var bundledUpdater: BundledUpdater?
    var attemptStore: DiscoveryAttemptStore?
    private var statusIndicatorText: String = ""
```

(`attemptStore` is `internal` so `AppsTab` can read it.)

2. Set `shared` in `applicationDidFinishLaunching`:

```swift
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        // Skip full startup when running unit tests
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        ...
    }
```

3. In `startWatcher()`, replace the stop-gap from Task 6 step 3 with proper wiring. Find:

```swift
let _attemptStore = DiscoveryAttemptStore(
    fileURL: RuleStorage.userRulesDirectory()
        .deletingLastPathComponent()
        .appendingPathComponent("attempted.json")
)
discoveryService = DiscoveryService(
    client: client,
    ruleCache: ruleCache,
    rulesDir: RuleStorage.userRulesDirectory(),
    attemptStore: _attemptStore
)
```

Replace with:

```swift
let store = DiscoveryAttemptStore(
    fileURL: RuleStorage.userRulesDirectory()
        .deletingLastPathComponent()
        .appendingPathComponent("attempted.json")
)
self.attemptStore = store

discoveryService = DiscoveryService(
    client: client,
    ruleCache: ruleCache,
    rulesDir: RuleStorage.userRulesDirectory(),
    attemptStore: store
)
```

Also expose `discoveryService` so AppsTab can read it. Change line in property declaration:

```swift
var discoveryService: DiscoveryService?
```

(remove `private`).

- [ ] **Step 2: Verify build**

```bash
xcodebuild build -project SFlow.xcodeproj -scheme SFlow 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add SFlow/AppDelegate.swift && \
git commit -m "feat: AppDelegate.shared + wire up DiscoveryAttemptStore

Exposes attemptStore + discoveryService internally so AppsTab can read
state and call forceRetry. Store lives in
~/Library/Application Support/SFlow/attempted.json.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: Settings — Show developer features toggle in Advanced

**Files:**
- Modify: `SFlow/SettingsWindow.swift`

- [ ] **Step 1: Read existing AdvancedTab content**

Run to inspect:

```bash
grep -n "AdvancedTab\|showDeveloperFeatures" /Users/filip/Claude/Projects/Apps/SFlow/SFlow/SettingsWindow.swift
```

Locate the existing `AdvancedTab` view body.

- [ ] **Step 2: Add toggle inside AdvancedTab**

Inside `AdvancedTab.body`, add the following `Toggle` (after existing controls but before any trailing `Spacer()` — keep the layout consistent with existing code style):

```swift
@AppStorage("showDeveloperFeatures") private var showDeveloperFeatures: Bool = false

// ... inside body
Toggle("Show developer features", isOn: $showDeveloperFeatures)
    .help("Reveals an Apps tab with discovery diagnostics. For beta testing and debugging only.")
```

(Place the `@AppStorage` line near other `@AppStorage` properties in `AdvancedTab`.)

- [ ] **Step 3: Verify build**

```bash
xcodebuild build -project SFlow.xcodeproj -scheme SFlow 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add SFlow/SettingsWindow.swift && \
git commit -m "feat: Show developer features toggle in Settings Advanced tab

Default OFF. When ON, the Apps tab (next commit) becomes visible. Lets
beta-testers and dev see discovery state without exposing it to all users.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: AppsTab — bundled + learned sections

**Files:**
- Create: `SFlow/AppsTab.swift`
- Modify: `SFlow/SettingsWindow.swift`

- [ ] **Step 1: Create AppsTab.swift with view-model + bundled/learned sections**

Create `SFlow/AppsTab.swift`:

```swift
import SwiftUI
import AppKit

struct AppEntry: Identifiable, Hashable {
    let id: String        // bundleId
    let name: String
    let ruleCount: Int
    let source: Source

    enum Source: String {
        case bundled, learned
    }
}

struct FailedAppEntry: Identifiable, Hashable {
    let id: String        // bundleId
    let name: String
    let reason: DiscoveryFailureReason
    let failureCount: Int
    let lastAttemptAt: Date
    let nextRetryAt: Date
}

@MainActor
final class AppsTabViewModel: ObservableObject {
    @Published var bundled: [AppEntry] = []
    @Published var learned: [AppEntry] = []
    @Published var failed: [FailedAppEntry] = []

    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .sflowDiscoveryStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.refresh() }
        refresh()
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func refresh() {
        let rulesDir = RuleStorage.userRulesDirectory()
        bundled = loadGroupedRules(from: rulesDir.appendingPathComponent("bundled.json"),
                                   source: .bundled)
        learned = loadCacheFiles(in: rulesDir.appendingPathComponent("cache"))
        if let store = AppDelegate.shared?.attemptStore {
            failed = store.allFailures().map { entry in
                FailedAppEntry(
                    id: entry.bundleId,
                    name: appNameFor(bundleId: entry.bundleId),
                    reason: entry.lastReason,
                    failureCount: entry.failureCount,
                    lastAttemptAt: entry.lastAttemptAt,
                    nextRetryAt: entry.nextRetryAt
                )
            }
        } else {
            failed = []
        }
    }

    private func loadGroupedRules(from url: URL, source: AppEntry.Source) -> [AppEntry] {
        guard let data = try? Data(contentsOf: url),
              let sets = try? JSONDecoder().decode([StoredRuleSet].self, from: data) else {
            return []
        }
        return sets
            .map { AppEntry(id: $0.bundleId,
                            name: appNameFor(bundleId: $0.bundleId),
                            ruleCount: $0.rules.count,
                            source: source) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadCacheFiles(in dir: URL) -> [AppEntry] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }
        var entries: [AppEntry] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let set = try? JSONDecoder().decode(StoredRuleSet.self, from: data)
            else { continue }
            entries.append(AppEntry(
                id: set.bundleId,
                name: appNameFor(bundleId: set.bundleId),
                ruleCount: set.rules.count,
                source: .learned
            ))
        }
        return entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func appNameFor(bundleId: String) -> String {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first,
           let name = app.localizedName {
            return name
        }
        // Fallback: last path component of the bundleId
        return bundleId.components(separatedBy: ".").last ?? bundleId
    }
}

struct AppsTab: View {
    @StateObject private var vm = AppsTabViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section(title: "Bundled apps", entries: vm.bundled, status: "🟢")
                section(title: "Learned apps", entries: vm.learned, status: "🟢")
                failedSection()
                HStack(spacing: 12) {
                    Button("Refresh list") { vm.refresh() }
                    Button("Open rules folder") {
                        NSWorkspace.shared.activateFileViewerSelecting(
                            [RuleStorage.userRulesDirectory()]
                        )
                    }
                    Spacer()
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func section(title: String, entries: [AppEntry], status: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            if entries.isEmpty {
                Text("None yet").foregroundColor(.secondary).font(.caption)
            } else {
                ForEach(entries) { entry in
                    HStack {
                        Text(status)
                        Text(entry.name).frame(maxWidth: .infinity, alignment: .leading)
                        Text(entry.source.rawValue).foregroundColor(.secondary).font(.caption)
                        Text("\(entry.ruleCount) rules").foregroundColor(.secondary).font(.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func failedSection() -> some View {
        // Real content arrives in Task 13. For now, a placeholder so the
        // view compiles.
        VStack(alignment: .leading, spacing: 6) {
            Text("Failed apps").font(.headline)
            if vm.failed.isEmpty {
                Text("None — nice").foregroundColor(.secondary).font(.caption)
            }
        }
    }
}
```

- [ ] **Step 2: Add Apps tab into SettingsView (conditional)**

In `SFlow/SettingsWindow.swift`, modify `SettingsView.body`:

```swift
struct SettingsView: View {
    @AppStorage("showDeveloperFeatures") private var showDeveloperFeatures: Bool = false

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            PrivacyTab()
                .tabItem { Label("Privacy", systemImage: "eye.slash") }
            AdvancedTab()
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
            if showDeveloperFeatures {
                AppsTab()
                    .tabItem { Label("Apps", systemImage: "app.badge") }
            }
        }
        .frame(width: 480, height: 300)
        .padding([.horizontal, .bottom])
    }
}
```

- [ ] **Step 3: Register AppsTab.swift in project.pbxproj**

Same pattern as Task 1 Step 2.

- [ ] **Step 4: Verify build**

```bash
xcodebuild build -project SFlow.xcodeproj -scheme SFlow 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add SFlow/AppsTab.swift SFlow/SettingsWindow.swift SFlow.xcodeproj/project.pbxproj && \
git commit -m "feat: AppsTab (bundled + learned sections) hidden behind dev toggle

ViewModel observes .sflowDiscoveryStateChanged + refreshes lists from
RuleStorage. Failed section placeholder — implemented in next commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: AppsTab — failed section with Try again

**Files:**
- Modify: `SFlow/AppsTab.swift`

- [ ] **Step 1: Replace failedSection() with full implementation**

Replace the placeholder `failedSection()` in `SFlow/AppsTab.swift` with:

```swift
    @ViewBuilder
    private func failedSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Failed apps").font(.headline)
            if vm.failed.isEmpty {
                Text("None — nice").foregroundColor(.secondary).font(.caption)
            } else {
                ForEach(vm.failed) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("❌")
                            Text(entry.name).frame(maxWidth: .infinity, alignment: .leading)
                            Text(entry.reason.displayString)
                                .foregroundColor(.secondary).font(.caption)
                            Button("Try again") {
                                AppDelegate.shared?.discoveryService?
                                    .forceRetry(bundleId: entry.id)
                            }
                        }
                        Text("last: \(format(entry.lastAttemptAt)) · \(entry.failureCount) fails · next auto-retry: \(format(entry.nextRetryAt))")
                            .foregroundColor(.secondary).font(.caption)
                    }
                }
            }
        }
    }

    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild build -project SFlow.xcodeproj -scheme SFlow 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add SFlow/AppsTab.swift && \
git commit -m "feat: AppsTab failed section + Try again button (P-3 done)

Renders each failed app with reason, failure count, last attempt, next
auto-retry. Try again button invokes DiscoveryService.forceRetry which
resets backoff and runs pipeline immediately for the targeted bundleId.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: Run full test suite + manual eval

**Files:** none — verification step

- [ ] **Step 1: Run all tests**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow && \
xcodebuild test -project SFlow.xcodeproj -scheme SFlow 2>&1 | tail -20
```

Expected: all tests pass. Count should be at least previous count + 15
(5 from `DiscoveryFailureReasonTests` + 10 from `DiscoveryAttemptStoreTests`).
Note exact total in the session log entry (Task 15).

- [ ] **Step 2: Run app and complete manual eval checklist**

```bash
xcodebuild -project SFlow.xcodeproj -scheme SFlow -configuration Debug \
  -derivedDataPath /tmp/sflow-dd build 2>&1 | tail -3
open /tmp/sflow-dd/Build/Products/Debug/SFlow.app
```

Verify in order:

- [ ] Open Settings → Advanced. Toggle "Show developer features" ON.
- [ ] Settings tab bar now shows a 4th "Apps" tab.
- [ ] Apps tab renders Bundled apps (5: Slack, Notion, Obsidian, Terminal,
      Claude Desktop) each with a rule count.
- [ ] Open a new app on the machine that has no rules yet (e.g., a small
      utility app). Within ~30s, it appears under "Learned apps" with its
      rule count.
- [ ] Force a failure: temporarily change `DiscoveryClient.productionURL`
      to `https://does-not-exist.invalid` (revert immediately after) and
      activate another new app. After ~30s it should appear under
      "Failed apps" with reason "Server error or no internet".
- [ ] Restore the production URL. Click "Try again" on the failed app with
      the app open → status switches to running → after success it moves
      to "Learned apps".
- [ ] Force-quit the target app, then click "Try again" → reason becomes
      "Launch the app first, then try again".
- [ ] Quit SFlow, relaunch, open Settings → Apps → failed apps are still
      present (persistence works).
- [ ] Toggle Advanced → "Show developer features" OFF → Apps tab disappears.

Note any deviations from expected behavior to fix before commit.

- [ ] **Step 3: Inspect attempted.json**

```bash
cat "$HOME/Library/Application Support/SFlow/attempted.json" 2>/dev/null | jq . | head -30
```

Verify schema matches spec: `version: 1`, entries with `lastAttemptAt`,
`failureCount`, `lastReason`, `nextRetryAt`.

- [ ] **Step 4: No commit needed** (verification only)

---

## Task 15: Update docs + session log

**Files:**
- Modify: `docs/audit-phase-0.md`
- Modify: `docs/audit-phase-1.md`
- Modify: `docs/roadmap.md`

- [ ] **Step 1: Flip P-2 and P-3 to 🟢 in audit-phase-0.md**

In the status table near the top of `docs/audit-phase-0.md`, change the
rows for **P-2** and **P-3**:

```markdown
| P-2 Retry przy fail | 🟢 zamknięte | DiscoveryAttemptStore + 1h/24h/7d/30d backoff + 15s pre-check + forceRetry API + DiscoveryFailureReason classification (sesja 8) |
| P-3 .failed silently | 🟢 zamknięte | Apps tab w Settings (za toggle showDeveloperFeatures) — failed apps z reason + Try again button + persistence (sesja 8) |
```

- [ ] **Step 2: Flip Sub-cel 1.2 to 🟢 in audit-phase-1.md**

In the status table near the top of `docs/audit-phase-1.md`, change the
row for **1.2**:

```markdown
| 1.2 Retry + backoff dla failed discovery | 🟢 done | DiscoveryAttemptStore + Apps tab (beta-only) — patrz spec `2026-05-15-discovery-retry-and-apps-tab-design.md` + plan `2026-05-15-discovery-retry-and-apps-tab.md`. Sesja 8 (2026-05-15). |
```

In the execution sequence table, change the row for **sesja 8.5** to:

```markdown
| **8.5** | Retry + backoff + Apps tab | 1.2 (P-2/P-3 + Apps tab beta-only) | ~3-4h | 🟢 done | 📋 `2026-05-15-discovery-retry-and-apps-tab.md` |
```

- [ ] **Step 3: Add session log entry to roadmap.md**

Replace the in-design entry in `docs/roadmap.md` (the
`### 2026-05-15 — Sesja 8 (in design): ...` block) with the completed
version:

```markdown
### 2026-05-15 — Sesja 8 (complete): P-2/P-3 discovery retry + Apps tab

**Co:** Persistowany retry + backoff dla nieudanej discovery (P-2) plus UI
feedback dla failed status (P-3).
(1) `DiscoveryFailureReason` enum (6 cases) + 5 testów mapowania z
`DiscoveryClientError`.
(2) `DiscoveryAttemptStore` — `attempted.json` z atomic write, backoff
1h/24h/7d/30d (cap), `canAttempt`/`recordFailure`/`recordSuccess`/`forceRetry`
+ 10 testów (skeleton, każdy backoff bucket, persistence round-trip, time-travel
clock).
(3) `DiscoveryService` przepisany: `canAttempt` gate, 15s pre-check gdy
skeleton<3 + menu empty, klasyfikacja errorów do reason, `recordSuccess` po
success, `NotificationCenter` event po każdej zmianie stanu, `forceRetry`
public API z guard "launch app first".
(4) `AppDelegate.shared` + wstrzyknięcie store do service.
(5) `AppsTab` SwiftUI — 3 sekcje (bundled / learned / failed) z `Try again`
button, ukryta za toggle `showDeveloperFeatures` w Advanced.

**Dlaczego:** P-2/P-3 oznaczone w audycie jako WYSOKA priorytet — pierwszy
user który aktywuje Notion 5s po starcie systemu (Notion w autostarcie) miał
trwale zepsute reguły do końca 90-dniowego cache. Z backoffem auto-retry
naprawia sam, a beta-tester ma manual override.

**Wpływ:** Eliminuje gating issue dla bety. Apps tab ukryty domyślnie, więc
nie zaśmieca UI zwykłym userom. Liczba testów: 198 → (po Task 14 wpisać tu
realną liczbę).

**Commits:** wiele atomic commits per task — patrz `git log --oneline` od
`098a726`.

**Następny krok (sesja 9):** Bundle C — P-32 (ukierunkowany web research w
backend prompt) + reseed 5 bundled apek nowym promptem.
```

- [ ] **Step 4: Commit docs**

```bash
git add docs/audit-phase-0.md docs/audit-phase-1.md docs/roadmap.md && \
git commit -m "docs: sesja 8 complete — P-2/P-3 zamknięte

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Acceptance criteria (final check)

After Task 15:
- [ ] 15 new tests passing (5 `DiscoveryFailureReasonTests` + 10
      `DiscoveryAttemptStoreTests`); full suite green
- [ ] Manual eval checklist (Task 14 Step 2) — every box checked
- [ ] `attempted.json` persists through restart with valid schema
- [ ] Apps tab visible only when `showDeveloperFeatures` is ON
- [ ] `forceRetry` works for running app; emits "Launch first" for missing
- [ ] Pre-check 15s observable in console log when skeleton was empty
- [ ] `docs/audit-phase-0.md`, `docs/audit-phase-1.md`, `docs/roadmap.md`
      updated to reflect 🟢 done state
