import XCTest
@testable import SFlow

final class DiscoveredStoreTests: XCTestCase {
    var tempDir: URL!
    var store: DiscoveredStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sflow-discovered-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = DiscoveredStore(dir: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeEntry(bundleId: String = "notion.mail.id",
                           name: String = "Compose a new email",
                           keys: [String] = ["c"],
                           rect: CGRect = CGRect(x: 200, y: 50, width: 24, height: 24),
                           ageSeconds: TimeInterval = 0) -> DiscoveredEntry {
        DiscoveredEntry(
            bundleId: bundleId, actionName: name, keys: keys,
            identifier: nil,
            rect: DiscoveredEntry.CGRectCodable(rect),
            observedAt: Date().addingTimeInterval(-ageSeconds)
        )
    }

    func test_recordAndLookup_byCursorPosition() {
        let e = makeEntry()
        store.record(e)
        store.allEntries()  // wait for queue flush by triggering sync read
        let found = store.lookup(near: CGPoint(x: 210, y: 60), bundleId: "notion.mail.id")
        XCTAssertEqual(found?.actionName, "Compose a new email")
        XCTAssertEqual(found?.keys, ["c"])
    }

    func test_lookup_missesWhenCursorOutsideRect() {
        store.record(makeEntry())
        _ = store.allEntries()
        let found = store.lookup(near: CGPoint(x: 800, y: 800), bundleId: "notion.mail.id")
        XCTAssertNil(found)
    }

    func test_lookup_missesForDifferentBundleId() {
        store.record(makeEntry())
        _ = store.allEntries()
        let found = store.lookup(near: CGPoint(x: 210, y: 60), bundleId: "com.other.app")
        XCTAssertNil(found)
    }

    func test_lookup_respectsTimeWindow() {
        // 2-min-old entry: within default (7d) window, but rejected with
        // explicit short window. Default extended to 7d in 2026-05-17:
        // shortcut for a button doesn't change over time, persistent
        // cross-session means hover-once-then-instant flow.
        store.record(makeEntry(ageSeconds: 120))
        _ = store.allEntries()
        let foundDefault = store.lookup(near: CGPoint(x: 210, y: 60),
                                         bundleId: "notion.mail.id")
        XCTAssertNotNil(foundDefault, "default 7d window should include 2-min-old entry")
        let foundShort = store.lookup(near: CGPoint(x: 210, y: 60),
                                       bundleId: "notion.mail.id", within: 60)
        XCTAssertNil(foundShort, "explicit 60s window should exclude 2-min-old entry")
    }

    func test_duplicate_within5seconds_isSkipped() {
        let rect = CGRect(x: 200, y: 50, width: 24, height: 24)
        store.record(makeEntry(name: "Compose a new email", keys: ["c"], rect: rect))
        store.record(makeEntry(name: "Compose a new email", keys: ["c"], rect: rect))
        store.record(makeEntry(name: "Compose a new email", keys: ["c"], rect: rect))
        let all = store.allEntries()
        XCTAssertEqual(all.count, 1, "Identical entries within 5s should de-dupe")
    }

    func test_distinctActions_areKept() {
        store.record(makeEntry(name: "Compose a new email", keys: ["c"]))
        store.record(makeEntry(name: "Archive", keys: ["e"]))
        let all = store.allEntries()
        XCTAssertEqual(all.count, 2)
    }

    func test_persistence_roundTrip() {
        store.record(makeEntry(name: "Compose a new email", keys: ["c"]))
        store.record(makeEntry(name: "Archive", keys: ["e"]))
        _ = store.allEntries()  // flush

        // New store instance reads from same directory
        let store2 = DiscoveredStore(dir: tempDir)
        let entries = store2.allEntries()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(Set(entries.map { $0.actionName }),
                       ["Compose a new email", "Archive"])
    }

    func test_lookup_returnsMostRecentMatch() {
        let rect = CGRect(x: 200, y: 50, width: 100, height: 50)
        store.record(makeEntry(name: "Old action", keys: ["x"], rect: rect, ageSeconds: 10))
        store.record(makeEntry(name: "New action", keys: ["y"], rect: rect, ageSeconds: 0))
        _ = store.allEntries()
        let found = store.lookup(near: CGPoint(x: 250, y: 75), bundleId: "notion.mail.id")
        XCTAssertEqual(found?.actionName, "New action")
    }
}
