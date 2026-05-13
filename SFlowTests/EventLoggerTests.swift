import XCTest
@testable import SFlow

final class EventLoggerTests: XCTestCase {
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

    func test_log_createsFileOnFirstWrite() {
        EventLogger.log(event: makeEvent(), to: logFile)
        EventLogger.flush()
        XCTAssertTrue(FileManager.default.fileExists(atPath: logFile.path))
    }

    func test_log_writesValidJSONLine() throws {
        let event = makeEvent(bundleId: "com.test.app", shortcutId: "test-id",
                              keys: ["meta", "k"], hint: "Test", mouseX: 100, mouseY: 200)
        EventLogger.log(event: event, to: logFile)
        EventLogger.flush()
        let content = try String(contentsOf: logFile, encoding: .utf8)
        XCTAssertTrue(content.hasSuffix("\n"))
        let line = content.trimmingCharacters(in: .newlines)
        let data = line.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["bundleId"] as? String, "com.test.app")
        XCTAssertEqual(json["shortcutId"] as? String, "test-id")
        XCTAssertEqual(json["keys"] as? [String], ["meta", "k"])
        XCTAssertEqual(json["hint"] as? String, "Test")
        XCTAssertEqual(json["mouseX"] as? Double, 100)
        XCTAssertEqual(json["mouseY"] as? Double, 200)
        XCTAssertNotNil(json["timestamp"])
    }

    func test_log_appendsMultipleLines() throws {
        EventLogger.log(event: makeEvent(shortcutId: "first"), to: logFile)
        EventLogger.flush()
        EventLogger.log(event: makeEvent(shortcutId: "second"), to: logFile)
        EventLogger.flush()
        let content = try String(contentsOf: logFile, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 2)
        let json0 = try JSONSerialization.jsonObject(with: lines[0].data(using: .utf8)!) as! [String: Any]
        let json1 = try JSONSerialization.jsonObject(with: lines[1].data(using: .utf8)!) as! [String: Any]
        XCTAssertEqual(json0["shortcutId"] as? String, "first")
        XCTAssertEqual(json1["shortcutId"] as? String, "second")
    }

    func test_logMiss_writesTypeMissLine() throws {
        let event = MissEvent(bundleId: "md.obsidian",
                              role: "AXButton",
                              title: "open quick switcher",
                              desc: "",
                              help: "")
        EventLogger.logMiss(event: event, to: logFile)
        EventLogger.flush()
        let content = try String(contentsOf: logFile, encoding: .utf8)
        let line = content.trimmingCharacters(in: .newlines)
        let json = try JSONSerialization.jsonObject(with: line.data(using: .utf8)!) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "miss")
        XCTAssertEqual(json["bundleId"] as? String, "md.obsidian")
        XCTAssertEqual(json["role"] as? String, "AXButton")
        XCTAssertEqual(json["title"] as? String, "open quick switcher")
        XCTAssertEqual(json["desc"] as? String, "")
        XCTAssertEqual(json["help"] as? String, "")
        XCTAssertNotNil(json["timestamp"])
    }

    func test_log_toastEventIncludesTypeField() throws {
        EventLogger.log(event: makeEvent(), to: logFile)
        EventLogger.flush()
        let content = try String(contentsOf: logFile, encoding: .utf8)
        let line = content.trimmingCharacters(in: .newlines)
        let json = try JSONSerialization.jsonObject(with: line.data(using: .utf8)!) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "toast")
    }

    private func makeEvent(bundleId: String = "com.test", shortcutId: String = "test",
                           keys: [String] = ["meta", "k"], hint: String = "Test",
                           mouseX: Double = 0, mouseY: Double = 0) -> ShortcutEvent {
        ShortcutEvent(bundleId: bundleId, shortcutId: shortcutId,
                      keys: keys, hint: hint, mouseX: mouseX, mouseY: mouseY)
    }
}
