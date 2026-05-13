import XCTest
@testable import SFlow

final class RuleCacheTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func write(_ filename: String, _ rules: [LoadedRule], source: StoredSource) throws {
        let set = StoredRuleSet(
            bundleId: "com.x",
            appVersion: "1.0",
            fetchedAt: "2026-05-11T00:00:00Z",
            source: source,
            rulesVersion: nil,
            rules: rules
        )
        let data = try JSONEncoder().encode(set)
        try data.write(to: tempDir.appendingPathComponent(filename))
    }

    private func rule(_ title: String, keys: [String]) -> LoadedRule {
        LoadedRule(
            match: LoadedMatch(role: "AXButton", titles: [title]),
            keys: keys,
            hint: title,
            confidence: .high,
            source: .menuBar
        )
    }

    func testLoadsBundledRulesWhenNothingElseExists() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("Send", keys: ["meta", "enter"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        let result = cache.match(bundleId: "com.x", role: "AXButton", title: "Send", desc: "", help: "")
        XCTAssertEqual(result?.keys, ["meta", "enter"])
    }

    func testCacheRuleOverridesBundled() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("Send", keys: ["meta", "enter"])], source: .bundled)

        let cacheSet = StoredRuleSet(
            bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-11T00:00:00Z",
            source: .cloud, rulesVersion: nil,
            rules: [rule("Send", keys: ["meta", "s"])]
        )
        let data = try JSONEncoder().encode(cacheSet)
        try data.write(to: tempDir.appendingPathComponent("cache/com.x.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        let result = cache.match(bundleId: "com.x", role: "AXButton", title: "Send", desc: "", help: "")
        XCTAssertEqual(result?.keys, ["meta", "s"], "cache overrides bundled")
    }

    func testUserOverridesWinOverEverything() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("Send", keys: ["meta", "enter"])], source: .bundled)

        let cacheSet = StoredRuleSet(
            bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-11T00:00:00Z",
            source: .cloud, rulesVersion: nil,
            rules: [rule("Send", keys: ["meta", "s"])]
        )
        let cacheData = try JSONEncoder().encode(cacheSet)
        try cacheData.write(to: tempDir.appendingPathComponent("cache/com.x.json"))

        let userSet = StoredRuleSet(
            bundleId: "com.x", appVersion: nil, fetchedAt: "2026-05-11T00:00:00Z",
            source: .user, rulesVersion: nil,
            rules: [rule("Send", keys: ["meta", "x"])]
        )
        let userData = try JSONEncoder().encode(userSet)
        try userData.write(to: tempDir.appendingPathComponent("user_overrides.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        let result = cache.match(bundleId: "com.x", role: "AXButton", title: "Send", desc: "", help: "")
        XCTAssertEqual(result?.keys, ["meta", "x"], "user overrides win")
    }

    func testMatchesAgainstAnyTitleInArray() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)

        let set = StoredRuleSet(
            bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-11T00:00:00Z",
            source: .cloud, rulesVersion: nil,
            rules: [LoadedRule(
                match: LoadedMatch(role: "AXButton", titles: ["Send", "Wyślij", "Senden"]),
                keys: ["meta", "enter"], hint: "Send",
                confidence: .high, source: .menuBar
            )]
        )
        let data = try JSONEncoder().encode(set)
        try data.write(to: tempDir.appendingPathComponent("cache/com.x.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()

        XCTAssertNotNil(cache.match(bundleId: "com.x", role: "AXButton", title: "Wyślij", desc: "", help: ""))
        XCTAssertNotNil(cache.match(bundleId: "com.x", role: "AXButton", title: "Senden", desc: "", help: ""))
        XCTAssertNil(cache.match(bundleId: "com.x", role: "AXButton", title: "Cancel", desc: "", help: ""))
    }

    func testAXButtonRuleMatchesAnyClickableRole() throws {
        // Chromium/Electron apps wrap aria-label'd clickables in AXGroup, menu items
        // appear as AXMenuItem, links as AXLink. An LLM-generated rule with role:AXButton
        // should match any of these — but not non-interactive roles like AXTextField.
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)

        let set = StoredRuleSet(
            bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-11T00:00:00Z",
            source: .cloud, rulesVersion: nil,
            rules: [rule("Send", keys: ["meta", "enter"])]
        )
        let data = try JSONEncoder().encode(set)
        try data.write(to: tempDir.appendingPathComponent("cache/com.x.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()

        // Should match — semantically clickable
        for clickable in ["AXButton", "AXLink", "AXMenuItem", "AXGroup", "AXCell"] {
            XCTAssertNotNil(
                cache.match(bundleId: "com.x", role: clickable, title: "Send", desc: "", help: ""),
                "AXButton rule should match \(clickable)"
            )
        }
        // Should NOT match — non-interactive structural roles
        for nonClickable in ["AXTextField", "AXScrollArea", "AXWindow", "AXStaticText"] {
            XCTAssertNil(
                cache.match(bundleId: "com.x", role: nonClickable, title: "Send", desc: "", help: ""),
                "AXButton rule should not match \(nonClickable)"
            )
        }
    }

    func testNonButtonRuleStillRequiresExactRole() throws {
        // Rules with specific roles (AXTextField, AXSearchField) match strictly — no
        // permissive aliasing. Only AXButton is the "any clickable" wildcard.
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)

        let textFieldRule = LoadedRule(
            match: LoadedMatch(role: "AXTextField", titles: ["Search"]),
            keys: ["meta", "f"], hint: "Search",
            confidence: .high, source: .menuBar
        )
        let set = StoredRuleSet(
            bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-11T00:00:00Z",
            source: .cloud, rulesVersion: nil,
            rules: [textFieldRule]
        )
        let data = try JSONEncoder().encode(set)
        try data.write(to: tempDir.appendingPathComponent("cache/com.x.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()

        XCTAssertNotNil(cache.match(bundleId: "com.x", role: "AXTextField", title: "Search", desc: "", help: ""))
        XCTAssertNil(cache.match(bundleId: "com.x", role: "AXButton", title: "Search", desc: "", help: ""))
    }

    func testFiltersLowConfidenceByDefault() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)

        let lowRule = LoadedRule(
            match: LoadedMatch(role: "AXButton", titles: ["Maybe"]),
            keys: ["m"], hint: "Maybe",
            confidence: .low, source: .inferredPattern
        )
        let set = StoredRuleSet(
            bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-11T00:00:00Z",
            source: .cloud, rulesVersion: nil,
            rules: [lowRule]
        )
        let data = try JSONEncoder().encode(set)
        try data.write(to: tempDir.appendingPathComponent("cache/com.x.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()

        XCTAssertNil(cache.match(bundleId: "com.x", role: "AXButton", title: "Maybe", desc: "", help: ""),
                     "low-confidence rules are hidden by default")
    }
}
