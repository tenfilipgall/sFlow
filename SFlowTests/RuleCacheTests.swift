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

    func testMatchAcceptsAXTitleWithTrailingHotkeySuffix() throws {
        // Slack/Discord render menu access keys in the AX title: "Edit message E".
        // Bundled rules only carry "Edit message" — the matcher must tolerate the suffix.
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)

        let menuRule = LoadedRule(
            match: LoadedMatch(role: "AXMenuItem", titles: ["Edit message"]),
            keys: ["e"], hint: "Edit message",
            confidence: .high, source: .menuBar
        )
        let set = StoredRuleSet(
            bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-11T00:00:00Z",
            source: .cloud, rulesVersion: nil,
            rules: [menuRule]
        )
        let data = try JSONEncoder().encode(set)
        try data.write(to: tempDir.appendingPathComponent("cache/com.x.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        let result = cache.match(bundleId: "com.x", role: "AXMenuItem",
                                  title: "Edit message E", desc: "", help: "")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.keys, ["e"])
    }

    func testMatchDoesNotStripSuffixWhenStrippedTitleTooShort() throws {
        // Candidate "ab" is not a substring of AX title "Q Y", and stripping "Q Y" would
        // leave just "Q" (length 1) which is rejected — so no match by either path.
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)

        let menuRule = LoadedRule(
            match: LoadedMatch(role: "AXMenuItem", titles: ["ab"]),
            keys: ["x"], hint: "ab",
            confidence: .high, source: .menuBar
        )
        let set = StoredRuleSet(
            bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-11T00:00:00Z",
            source: .cloud, rulesVersion: nil,
            rules: [menuRule]
        )
        let data = try JSONEncoder().encode(set)
        try data.write(to: tempDir.appendingPathComponent("cache/com.x.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        let result = cache.match(bundleId: "com.x", role: "AXMenuItem",
                                  title: "Q Y", desc: "", help: "")
        XCTAssertNil(result)
    }

    func testMatchDoesNotStripWhenLastCharIsNotLetter() throws {
        // Candidate "hello" is not a substring of AX title "ello 1"; stripping would
        // require a trailing letter (last char is "1") — neither path matches.
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)

        let menuRule = LoadedRule(
            match: LoadedMatch(role: "AXMenuItem", titles: ["hello"]),
            keys: ["h"], hint: "hello",
            confidence: .high, source: .menuBar
        )
        let set = StoredRuleSet(
            bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-11T00:00:00Z",
            source: .cloud, rulesVersion: nil,
            rules: [menuRule]
        )
        let data = try JSONEncoder().encode(set)
        try data.write(to: tempDir.appendingPathComponent("cache/com.x.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        let result = cache.match(bundleId: "com.x", role: "AXMenuItem",
                                  title: "ello 1", desc: "", help: "")
        XCTAssertNil(result)
    }

    func testStripHotkeySuffixExamples() {
        XCTAssertEqual(RuleCache.stripHotkeySuffix("Edit message E"), "Edit message")
        XCTAssertEqual(RuleCache.stripHotkeySuffix("Mark unread U"), "Mark unread")
        // "AB C" stripped → "AB" (2 chars) — allowed by `stripped.count >= 2`.
        XCTAssertEqual(RuleCache.stripHotkeySuffix("AB C"), "AB")
        XCTAssertNil(RuleCache.stripHotkeySuffix("A B"))         // stripped "A" → too short
        XCTAssertNil(RuleCache.stripHotkeySuffix("Hello"))       // no space-letter ending
        XCTAssertNil(RuleCache.stripHotkeySuffix("Hello 9"))     // digit, not letter
        XCTAssertNil(RuleCache.stripHotkeySuffix(""))            // empty
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

    func testAutoDiscoveredMediumRuleHiddenByDefault() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        let mediumRule = LoadedRule(
            match: LoadedMatch(role: "AXButton", titles: ["Maybe"]),
            keys: ["m"], hint: "Maybe",
            confidence: .medium, source: .inferredPattern
        )
        let set = StoredRuleSet(bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-14T00:00:00Z",
                                source: .cloud, rulesVersion: nil, rules: [mediumRule])
        try JSONEncoder().encode(set).write(to: tempDir.appendingPathComponent("cache/com.x.json"))
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        XCTAssertNil(cache.match(bundleId: "com.x", role: "AXButton", title: "Maybe", desc: "", help: ""),
                     "auto-discovered medium+inferred_pattern must be hidden by default")
    }

    func testAutoDiscoveredHighMenuBarActiveByDefault() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        let highRule = LoadedRule(
            match: LoadedMatch(role: "AXButton", titles: ["Send"]),
            keys: ["meta", "enter"], hint: "Send",
            confidence: .high, source: .menuBar
        )
        let set = StoredRuleSet(bundleId: "com.y", appVersion: "1.0", fetchedAt: "2026-05-14T00:00:00Z",
                                source: .cloud, rulesVersion: nil, rules: [highRule])
        try JSONEncoder().encode(set).write(to: tempDir.appendingPathComponent("cache/com.y.json"))
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        XCTAssertNotNil(cache.match(bundleId: "com.y", role: "AXButton", title: "Send", desc: "", help: ""),
                        "auto-discovered high+menu_bar must be active by default")
    }

    func testExperimentalToggleUnlocksMediumAutoDiscovered() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        let mediumRule = LoadedRule(
            match: LoadedMatch(role: "AXButton", titles: ["Maybe"]),
            keys: ["m"], hint: "Maybe",
            confidence: .medium, source: .inferredPattern
        )
        let set = StoredRuleSet(bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-14T00:00:00Z",
                                source: .cloud, rulesVersion: nil, rules: [mediumRule])
        try JSONEncoder().encode(set).write(to: tempDir.appendingPathComponent("cache/com.x.json"))
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        cache.showExperimental = true
        XCTAssertNotNil(cache.match(bundleId: "com.x", role: "AXButton", title: "Maybe", desc: "", help: ""),
                        "showExperimental=true must unlock medium auto-discovered rules")
    }

    func testBundledMediumRuleActiveByDefault() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        let mediumRule = LoadedRule(
            match: LoadedMatch(role: "AXButton", titles: ["Search"]),
            keys: ["meta", "k"], hint: "Search",
            confidence: .medium, source: .webDocsThirdParty
        )
        let set = StoredRuleSet(bundleId: "com.z", appVersion: "1.0", fetchedAt: "2026-05-14T00:00:00Z",
                                source: .bundled, rulesVersion: nil, rules: [mediumRule])
        try JSONEncoder().encode(set).write(to: tempDir.appendingPathComponent("bundled.json"))
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        XCTAssertNotNil(cache.match(bundleId: "com.z", role: "AXButton", title: "Search", desc: "", help: ""),
                        "bundled medium+web_docs_third_party must be active by default")
    }
}
