import XCTest
@testable import SFlow

final class MenuBarCacheTests: XCTestCase {
    private var tempFile: URL!

    override func setUp() {
        super.setUp()
        tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFile)
        super.tearDown()
    }

    func test_saveAndLoad_roundTrip() throws {
        let entries = ["new message": MenuBarEntry(keys: ["meta","n"], hint: "New Message"),
                       "reply":       MenuBarEntry(keys: ["meta","r"], hint: "Reply")]
        MenuBarCache.save(bundleId: "com.test.app", version: "1.0",
                          entries: entries, to: tempFile)
        let loaded = MenuBarCache.load(bundleId: "com.test.app", version: "1.0", from: tempFile)
        XCTAssertEqual(loaded?["new message"]?.keys, ["meta","n"])
        XCTAssertEqual(loaded?["reply"]?.hint, "Reply")
    }

    func test_load_wrongVersion_returnsNil() {
        let entries = ["new message": MenuBarEntry(keys: ["meta","n"], hint: "New Message")]
        MenuBarCache.save(bundleId: "com.test.app", version: "1.0",
                          entries: entries, to: tempFile)
        let loaded = MenuBarCache.load(bundleId: "com.test.app", version: "2.0", from: tempFile)
        XCTAssertNil(loaded)
    }

    func test_load_missingFile_returnsNil() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist.json")
        XCTAssertNil(MenuBarCache.load(bundleId: "com.test.app", version: "1.0", from: url))
    }

    func test_load_differentBundleId_returnsNil() {
        let entries = ["search": MenuBarEntry(keys: ["meta","f"], hint: "Find")]
        MenuBarCache.save(bundleId: "com.app.one", version: "1.0",
                          entries: entries, to: tempFile)
        let loaded = MenuBarCache.load(bundleId: "com.app.two", version: "1.0", from: tempFile)
        XCTAssertNil(loaded)
    }
}
