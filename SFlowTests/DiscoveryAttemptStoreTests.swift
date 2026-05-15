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
}
