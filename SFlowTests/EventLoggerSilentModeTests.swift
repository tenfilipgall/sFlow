import XCTest
@testable import SFlow

/// Silent-mode tests for `EventLogger.log(event:silent:)`.
/// Verifies the `silent: true` field is written exactly when caller opts in,
/// and the entry shape stays backward-compatible when silent is false / default.
final class EventLoggerSilentModeTests: XCTestCase {
    private var tempDir: URL!
    private var logFile: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        logFile = tempDir.appendingPathComponent("events.jsonl")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_log_silentTrue_addsSilentFieldEqualToTrue() throws {
        let event = makeEvent()
        EventLogger.log(event: event, to: logFile, silent: true)
        EventLogger.flush()

        let json = try readOnlyEntry()
        XCTAssertEqual(json["silent"] as? Bool, true)
        XCTAssertEqual(json["type"] as? String, "toast")
    }

    func test_log_silentFalse_omitsSilentField() throws {
        EventLogger.log(event: makeEvent(), to: logFile, silent: false)
        EventLogger.flush()

        let json = try readOnlyEntry()
        XCTAssertNil(json["silent"], "Expected no `silent` field when silent=false")
        XCTAssertEqual(json["type"] as? String, "toast")
    }

    func test_log_defaultSilentIsFalse() throws {
        // Calling without `silent:` argument is equivalent to silent=false.
        EventLogger.log(event: makeEvent(), to: logFile)
        EventLogger.flush()

        let json = try readOnlyEntry()
        XCTAssertNil(json["silent"], "Default call should not include `silent` field")
    }

    func test_log_silentTrue_preservesAllNormalFields() throws {
        let event = makeEvent(bundleId: "com.test.silent", shortcutId: "abc",
                              keys: ["meta", "k"], hint: "Hint",
                              mouseX: 1, mouseY: 2)
        EventLogger.log(event: event, to: logFile, silent: true)
        EventLogger.flush()

        let json = try readOnlyEntry()
        XCTAssertEqual(json["bundleId"] as? String, "com.test.silent")
        XCTAssertEqual(json["shortcutId"] as? String, "abc")
        XCTAssertEqual(json["keys"] as? [String], ["meta", "k"])
        XCTAssertEqual(json["hint"] as? String, "Hint")
        XCTAssertEqual(json["mouseX"] as? Double, 1)
        XCTAssertEqual(json["mouseY"] as? Double, 2)
        XCTAssertNotNil(json["timestamp"])
        XCTAssertNotNil(json["layer"])
    }

    // MARK: - Helpers

    private func readOnlyEntry(file: StaticString = #file, line: UInt = #line) throws -> [String: Any] {
        let content = try String(contentsOf: logFile, encoding: .utf8)
        let trimmed = content.trimmingCharacters(in: .newlines)
        guard let data = trimmed.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Could not parse JSONL entry", file: file, line: line)
            return [:]
        }
        return obj
    }

    private func makeEvent(bundleId: String = "com.test", shortcutId: String = "id",
                           keys: [String] = ["meta"], hint: String = "Hint",
                           mouseX: Double = 0, mouseY: Double = 0,
                           layer: RecognitionLayer = .ruleCache) -> ShortcutEvent {
        ShortcutEvent(bundleId: bundleId, shortcutId: shortcutId,
                      keys: keys, hint: hint, mouseX: mouseX, mouseY: mouseY,
                      layer: layer)
    }
}
