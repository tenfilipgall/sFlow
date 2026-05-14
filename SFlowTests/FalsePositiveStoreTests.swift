import XCTest
@testable import SFlow

@MainActor
final class FalsePositiveStoreTests: XCTestCase {
    private var tempDir: URL!
    private var falsePosURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        falsePosURL = tempDir.appendingPathComponent("false_positives.jsonl")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_toastShown_addsToRecentToasts() {
        let store = FalsePositiveStore(falsePosURL: falsePosURL)
        store.toastShown(event: makeEvent(shortcutId: "s1"))
        XCTAssertEqual(store.recentToasts.count, 1)
        XCTAssertEqual(store.recentToasts[0].id, "s1")
        XCTAssertEqual(store.recentToasts[0].keys, ["meta", "k"])
    }

    func test_toastShown_movesExistingToFront() {
        let store = FalsePositiveStore(falsePosURL: falsePosURL)
        store.toastShown(event: makeEvent(shortcutId: "s1"))
        store.toastShown(event: makeEvent(shortcutId: "s2"))
        store.toastShown(event: makeEvent(shortcutId: "s1"))
        XCTAssertEqual(store.recentToasts.count, 2)
        XCTAssertEqual(store.recentToasts[0].id, "s1")
        XCTAssertEqual(store.recentToasts[1].id, "s2")
    }

    func test_toastShown_capsAt50() {
        let store = FalsePositiveStore(falsePosURL: falsePosURL)
        for i in 0..<60 {
            store.toastShown(event: makeEvent(shortcutId: "s\(i)"))
        }
        XCTAssertEqual(store.recentToasts.count, 50)
    }

    func test_report_incrementsCountAndUpdatesRecord() {
        let store = FalsePositiveStore(falsePosURL: falsePosURL)
        store.toastShown(event: makeEvent(shortcutId: "fp1"))
        store.report(shortcutId: "fp1", bundleId: "com.test", keys: ["meta", "k"], hint: "Test")
        store.report(shortcutId: "fp1", bundleId: "com.test", keys: ["meta", "k"], hint: "Test")
        XCTAssertEqual(store.recentToasts[0].reportCount, 2)
        XCTAssertFalse(store.isDisabled(shortcutId: "fp1"))
    }

    func test_report_disablesAtThreshold() {
        let store = FalsePositiveStore(falsePosURL: falsePosURL)
        store.toastShown(event: makeEvent(shortcutId: "fp2"))
        for _ in 0..<3 {
            store.report(shortcutId: "fp2", bundleId: "com.test", keys: ["meta", "k"], hint: "Test")
        }
        XCTAssertTrue(store.isDisabled(shortcutId: "fp2"))
        XCTAssertTrue(store.recentToasts[0].isDisabled)
    }

    func test_isDisabled_persistsAcrossRestarts() {
        let url = falsePosURL!
        let store1 = FalsePositiveStore(falsePosURL: url)
        store1.toastShown(event: makeEvent(shortcutId: "fp3"))
        for _ in 0..<3 {
            store1.report(shortcutId: "fp3", bundleId: "com.test", keys: ["meta", "k"], hint: "Test")
        }
        EventLogger.flush()

        let store2 = FalsePositiveStore(falsePosURL: url)
        XCTAssertTrue(store2.isDisabled(shortcutId: "fp3"))
    }

    func test_isDisabled_belowThresholdNotDisabledAfterRestart() {
        let url = falsePosURL!
        let store1 = FalsePositiveStore(falsePosURL: url)
        store1.toastShown(event: makeEvent(shortcutId: "fp4"))
        store1.report(shortcutId: "fp4", bundleId: "com.test", keys: ["meta", "k"], hint: "Test")
        store1.report(shortcutId: "fp4", bundleId: "com.test", keys: ["meta", "k"], hint: "Test")
        EventLogger.flush()

        let store2 = FalsePositiveStore(falsePosURL: url)
        XCTAssertFalse(store2.isDisabled(shortcutId: "fp4"))
    }

    private func makeEvent(shortcutId: String) -> ShortcutEvent {
        ShortcutEvent(bundleId: "com.test", shortcutId: shortcutId,
                      keys: ["meta", "k"], hint: "Test", mouseX: 0, mouseY: 0)
    }
}
