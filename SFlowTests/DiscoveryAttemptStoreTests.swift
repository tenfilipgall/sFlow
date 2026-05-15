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
}
