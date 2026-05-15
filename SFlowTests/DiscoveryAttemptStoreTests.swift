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
