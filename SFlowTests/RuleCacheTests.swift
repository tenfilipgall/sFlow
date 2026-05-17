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

    func testIdentifierMatchReturnsRule() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        let rule = LoadedRule(
            match: LoadedMatch(role: "AXButton", titles: ["Completely Different"], identifiers: ["compose-btn"]),
            keys: ["meta", "n"], hint: "Compose",
            confidence: .high, source: .menuBar
        )
        let set = StoredRuleSet(bundleId: "com.id", appVersion: "1.0", fetchedAt: "2026-05-14T00:00:00Z",
                                source: .cloud, rulesVersion: nil, rules: [rule])
        try JSONEncoder().encode(set).write(to: tempDir.appendingPathComponent("cache/com.id.json"))
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        XCTAssertNotNil(
            cache.match(bundleId: "com.id", role: "AXButton", title: "xyz", desc: "", help: "", identifier: "compose-btn"),
            "identifier match must return rule even when title doesn't match"
        )
    }

    func testIdentifierMismatchFallsBackToTitle() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        let rule = LoadedRule(
            match: LoadedMatch(role: "AXButton", titles: ["Send"], identifiers: ["wrong-id"]),
            keys: ["meta", "enter"], hint: "Send",
            confidence: .high, source: .menuBar
        )
        let set = StoredRuleSet(bundleId: "com.fb", appVersion: "1.0", fetchedAt: "2026-05-14T00:00:00Z",
                                source: .cloud, rulesVersion: nil, rules: [rule])
        try JSONEncoder().encode(set).write(to: tempDir.appendingPathComponent("cache/com.fb.json"))
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        XCTAssertNotNil(
            cache.match(bundleId: "com.fb", role: "AXButton", title: "Send", desc: "", help: "", identifier: "other-btn"),
            "title match must still work when identifier doesn't match rule's identifiers"
        )
    }

    func testRuleWithoutIdentifiersMatchesByTitle() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        let rule = LoadedRule(
            match: LoadedMatch(role: "AXButton", titles: ["Search"]),
            keys: ["meta", "k"], hint: "Search",
            confidence: .high, source: .menuBar
        )
        let set = StoredRuleSet(bundleId: "com.bc", appVersion: "1.0", fetchedAt: "2026-05-14T00:00:00Z",
                                source: .cloud, rulesVersion: nil, rules: [rule])
        try JSONEncoder().encode(set).write(to: tempDir.appendingPathComponent("cache/com.bc.json"))
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        XCTAssertNotNil(
            cache.match(bundleId: "com.bc", role: "AXButton", title: "Search", desc: "", help: "", identifier: ""),
            "backward compat: rule without identifiers must match by title with empty identifier"
        )
    }

    // MARK: - Word-boundary match (BUG #2)

    func testTitleSearch_doesNotMatchInsideResearch() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("search", keys: ["meta", "k"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        // "research papers" should NOT match rule with title "search" (substring match was the bug)
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "research papers", desc: "", help: "")
        XCTAssertNil(result, "title 'search' must not match inside 'research'")
    }

    func testDescSearch_doesNotMatchInsideResearcher() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("search", keys: ["meta", "k"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "", desc: "researcher tools", help: "")
        XCTAssertNil(result, "desc 'researcher tools' must not match title 'search'")
    }

    func testTitleSearch_stillMatchesSearchSlack() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("search", keys: ["meta", "k"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        // "Search Slack" should still match (start of string)
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "Search Slack", desc: "", help: "")
        XCTAssertEqual(result?.keys, ["meta", "k"])
    }

    func testHelpAttribute_substringNowChecked() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("compose", keys: ["meta", "n"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        // help="Compose a new message" should match rule title="compose" via word-boundary
        // (previously help only checked equality, was inconsistent with title/desc paths)
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "", desc: "", help: "Compose a new message")
        XCTAssertEqual(result?.keys, ["meta", "n"])
    }

    func testPluralStillMatches() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("bookmark", keys: ["meta", "d"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        // Right-side extension is allowed: "bookmarks" should still match "bookmark"
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "bookmarks", desc: "", help: "")
        XCTAssertEqual(result?.keys, ["meta", "d"])
    }

    // MARK: - RoleDescription + CustomActions match (Coverage QW Fix 3)

    func testRoleDescriptionMatches() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("compose", keys: ["meta", "n"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        // Empty title/desc, but AXRoleDescription says "compose button"
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "", desc: "", help: "",
                                 roleDescription: "compose button")
        XCTAssertEqual(result?.keys, ["meta", "n"])
    }

    func testCustomActionsMatches() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("send message", keys: ["meta", "enter"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        // Empty title, but registers "Send message" as a custom action name
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "", desc: "", help: "",
                                 customActions: ["Send message", "Save draft"])
        XCTAssertEqual(result?.keys, ["meta", "enter"])
    }

    func testRoleDescriptionWordBoundaryRespected() throws {
        // Word-boundary still respected for roleDescription
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("search", keys: ["meta", "k"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        let result = cache.match(bundleId: "com.x", role: "AXButton",
                                 title: "", desc: "", help: "",
                                 roleDescription: "researcher tools")
        XCTAssertNil(result)
    }

    // MARK: - Sub-cel 1.21 / U-3: singleKeyMode feature flag

    func test_isSingleKeyApp_returnsFalse_byDefault() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("Send", keys: ["meta", "enter"])], source: .bundled)
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        XCTAssertFalse(cache.isSingleKeyApp(bundleId: "com.x"))
    }

    func test_isSingleKeyApp_returnsTrue_whenFlagSet() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        let set = StoredRuleSet(
            bundleId: "notion.mail.id", appVersion: nil,
            fetchedAt: "2026-05-17T00:00:00Z", source: .bundled, rulesVersion: nil,
            features: Features(singleKeyMode: true),
            rules: []
        )
        let data = try JSONEncoder().encode([set])
        try data.write(to: tempDir.appendingPathComponent("bundled.json"))
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        XCTAssertTrue(cache.isSingleKeyApp(bundleId: "notion.mail.id"))
    }

    func test_emptyRulesBundledEntry_doesNotBlock_cacheRules() throws {
        // Bundled.json declares notion.mail.id with empty rules + singleKeyMode flag.
        // Cache file has actual rules for notion.mail.id. Result: features registered
        // from bundled AND rules loaded from cache (empty-rules bundled doesn't block).
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        let bundledSet = StoredRuleSet(
            bundleId: "notion.mail.id", appVersion: nil,
            fetchedAt: "2026-05-17T00:00:00Z", source: .bundled, rulesVersion: nil,
            features: Features(singleKeyMode: true),
            rules: []
        )
        let bundledData = try JSONEncoder().encode([bundledSet])
        try bundledData.write(to: tempDir.appendingPathComponent("bundled.json"))

        let cacheSet = StoredRuleSet(
            bundleId: "notion.mail.id", appVersion: "1.0",
            fetchedAt: "2026-05-17T00:00:00Z", source: .cloud, rulesVersion: nil,
            rules: [rule("Compose", keys: ["c"])]
        )
        let cacheData = try JSONEncoder().encode(cacheSet)
        try cacheData.write(to: tempDir.appendingPathComponent("cache/notion.mail.id.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        XCTAssertTrue(cache.isSingleKeyApp(bundleId: "notion.mail.id"))
        let result = cache.match(bundleId: "notion.mail.id", role: "AXButton",
                                 title: "Compose", desc: "", help: "")
        XCTAssertEqual(result?.keys, ["c"], "cache rules not blocked by empty-rules bundled entry")
    }

    func test_features_areBackwardCompat_legacyBundledLoadsFine() throws {
        // Bundled.json without features field — older format. Must load and
        // singleKeyMode returns false.
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        let legacyJSON = """
        [{
          "bundleId": "com.legacy.app",
          "fetchedAt": "2026-01-01T00:00:00Z",
          "source": "bundled",
          "rules": []
        }]
        """
        try legacyJSON.data(using: .utf8)!
            .write(to: tempDir.appendingPathComponent("bundled.json"))
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        XCTAssertFalse(cache.isSingleKeyApp(bundleId: "com.legacy.app"))
    }
}
