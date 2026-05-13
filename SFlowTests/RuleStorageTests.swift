import XCTest
@testable import SFlow

final class RuleStorageTests: XCTestCase {
    func testApplicationSupportDirectoryPath() {
        let url = RuleStorage.userRulesDirectory()
        XCTAssertTrue(url.path.contains("Application Support/SFlow/rules"),
                      "Got: \(url.path)")
    }

    func testEnsureDirectoryCreatesNestedFolders() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try RuleStorage.ensureDirectory(tmp.appendingPathComponent("cache"))
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("cache").path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }
}
