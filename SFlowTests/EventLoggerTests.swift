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

    func test_logMiss_redactsPIIInDescAndValue() throws {
        let event = MissEvent(
            bundleId: "net.whatsapp.WhatsApp",
            role: "AXButton",
            title: "",
            desc: "☀️Sade☀️",
            help: "",
            identifier: "",
            value: "Missed video call from filip@example.com",
            subtreeLabel: ""
        )
        EventLogger.logMiss(event: event, to: logFile)
        EventLogger.flush()
        let content = try String(contentsOf: logFile, encoding: .utf8)
        let line = content.trimmingCharacters(in: .newlines)
        let json = try JSONSerialization.jsonObject(with: line.data(using: .utf8)!) as! [String: Any]
        XCTAssertEqual(json["desc"] as? String, "[REDACTED]",
                       "emoji-containing desc must be redacted")
        XCTAssertEqual(json["value"] as? String, "[REDACTED]",
                       "email-containing value must be redacted")
        XCTAssertEqual(json["bundleId"] as? String, "net.whatsapp.WhatsApp",
                       "bundleId is metadata, never redacted")
        XCTAssertEqual(json["role"] as? String, "AXButton",
                       "role is metadata, never redacted")
    }

    func test_logMiss_preservesSafeUILabels() throws {
        let event = MissEvent(
            bundleId: "com.tinyspeck.slackmacgap",
            role: "AXButton",
            title: "Compose",
            desc: "Reply to thread",
            help: "",
            subtreeLabel: "Quick Switcher"
        )
        EventLogger.logMiss(event: event, to: logFile)
        EventLogger.flush()
        let content = try String(contentsOf: logFile, encoding: .utf8)
        let line = content.trimmingCharacters(in: .newlines)
        let json = try JSONSerialization.jsonObject(with: line.data(using: .utf8)!) as! [String: Any]
        XCTAssertEqual(json["title"] as? String, "Compose")
        XCTAssertEqual(json["desc"] as? String, "Reply to thread")
        XCTAssertEqual(json["subtreeLabel"] as? String, "Quick Switcher")
    }

    func test_logMiss_skipsWriteWhenLogMissesDisabled() throws {
        try? FileManager.default.removeItem(at: EventLogger.defaultLogURL)
        UserDefaults.standard.set(false, forKey: "logMisses")
        defer { UserDefaults.standard.removeObject(forKey: "logMisses") }

        EventLogger.logMiss(event: MissEvent(bundleId: "test", role: "AXButton",
                                              title: "Foo", desc: "", help: ""))
        EventLogger.flush()
        XCTAssertFalse(FileManager.default.fileExists(atPath: EventLogger.defaultLogURL.path),
                       "logMiss must not write when logMisses is disabled")
    }

    func test_logFalsePositive_createsFileAndWritesType() throws {
        let event = makeEvent(bundleId: "com.test", shortcutId: "fp-test",
                              keys: ["meta", "k"], hint: "Test")
        EventLogger.logFalsePositive(event: event, to: logFile)
        EventLogger.flush()
        XCTAssertTrue(FileManager.default.fileExists(atPath: logFile.path))
        let content = try String(contentsOf: logFile, encoding: .utf8)
        let line = content.trimmingCharacters(in: .newlines)
        let json = try JSONSerialization.jsonObject(with: line.data(using: .utf8)!) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "false_positive")
        XCTAssertEqual(json["bundleId"] as? String, "com.test")
        XCTAssertEqual(json["shortcutId"] as? String, "fp-test")
        XCTAssertEqual(json["keys"] as? [String], ["meta", "k"])
        XCTAssertEqual(json["hint"] as? String, "Test")
        XCTAssertNotNil(json["timestamp"])
    }

    func test_logFalsePositive_appendsMultipleLines() throws {
        EventLogger.logFalsePositive(event: makeEvent(shortcutId: "fp-1"), to: logFile)
        EventLogger.flush()
        EventLogger.logFalsePositive(event: makeEvent(shortcutId: "fp-2"), to: logFile)
        EventLogger.flush()
        let content = try String(contentsOf: logFile, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 2)
        let json0 = try JSONSerialization.jsonObject(with: lines[0].data(using: .utf8)!) as! [String: Any]
        let json1 = try JSONSerialization.jsonObject(with: lines[1].data(using: .utf8)!) as! [String: Any]
        XCTAssertEqual(json0["shortcutId"] as? String, "fp-1")
        XCTAssertEqual(json1["shortcutId"] as? String, "fp-2")
    }

    private func makeEvent(bundleId: String = "com.test", shortcutId: String = "test",
                           keys: [String] = ["meta", "k"], hint: String = "Test",
                           mouseX: Double = 0, mouseY: Double = 0) -> ShortcutEvent {
        ShortcutEvent(bundleId: bundleId, shortcutId: shortcutId,
                      keys: keys, hint: hint, mouseX: mouseX, mouseY: mouseY,
                      layer: .ruleCache)
    }

    func test_log_includesLayerField() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sflow-test-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let event = ShortcutEvent(
            bundleId: "com.test", shortcutId: "x", keys: ["meta","k"], hint: "Test",
            mouseX: 0, mouseY: 0, layer: .ruleCache
        )
        EventLogger.log(event: event, to: tempURL)
        EventLogger.flush()

        let content = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertTrue(content.contains("\"layer\":\"L0.5\""),
                      "events.jsonl line must contain layer field; got: \(content)")
    }

    func test_log_includesCorrectLayerForEachVariant() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sflow-test-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let cases: [(RecognitionLayer, String)] = [
            (.axKeyShortcuts, "L0"),
            (.ruleCache, "L0.5"),
            (.shortcutRules, "L1"),
            (.axHelp, "L2"),
            (.menuBarIndex, "L3"),
            (.universal, "L4"),
            (.menuItem, "menu"),
            (.menuItemFallback, "menu-fallback"),
        ]
        for (layer, _) in cases {
            let event = ShortcutEvent(
                bundleId: "com.test", shortcutId: "x", keys: ["k"], hint: "h",
                mouseX: 0, mouseY: 0, layer: layer
            )
            EventLogger.log(event: event, to: tempURL)
        }
        EventLogger.flush()

        let content = try String(contentsOf: tempURL, encoding: .utf8)
        for (_, expected) in cases {
            XCTAssertTrue(content.contains("\"layer\":\"\(expected)\""),
                          "missing layer=\(expected) in output: \(content)")
        }
    }
}
