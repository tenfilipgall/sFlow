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
