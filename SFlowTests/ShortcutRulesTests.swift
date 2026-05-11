import XCTest
@testable import SFlow

final class ShortcutRulesTests: XCTestCase {

    func test_parseShortcut_singleModifierPlusLetter() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "⌘K"), ["meta", "k"])
    }

    func test_parseShortcut_twoModifiers() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "⌘⇧P"), ["meta", "shift", "p"])
    }

    func test_parseShortcut_threeModifiers() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "⌘⌥⇧F"), ["meta", "alt", "shift", "f"])
    }

    func test_parseShortcut_embeddedInText() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "Quick Find ⌘K"), ["meta", "k"])
    }

    func test_parseShortcut_noShortcut_returnsNil() {
        XCTAssertNil(ShortcutRules.parseShortcut(from: "No shortcut here"))
    }

    func test_parseShortcut_modifierAloneNoKey_returnsNil() {
        XCTAssertNil(ShortcutRules.parseShortcut(from: "⌘"))
    }

    func test_parseShortcut_number() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "⌘1"), ["meta", "1"])
    }

    func test_parseShortcut_ctrl() {
        XCTAssertNil(ShortcutRules.parseShortcut(from: "⌃`")) // backtick not letter/number
    }

    // Raw single-char kAXHelp (strategy 2)
    func test_parseShortcut_rawSingleLetter() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "e"), ["e"])
    }

    func test_parseShortcut_rawSingleLetterUppercase() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "K"), ["k"])
    }

    func test_parseShortcut_singleDigit_doesNotFire() {
        XCTAssertNil(ShortcutRules.parseShortcut(from: "1"))
    }

    // Single-key patterns (strategy 3)
    func test_parseShortcut_parensSingleKey() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "Archive (E)"), ["e"])
    }

    func test_parseShortcut_bracketsSingleKey() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "Today [T]"), ["t"])
    }

    func test_parseShortcut_dashSingleKey() {
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "Reply — R"), ["r"])
    }

    func test_parseShortcut_singleKeyPreferModifierMatch() {
        // When both exist, modifier+key wins over single-key pattern
        XCTAssertEqual(ShortcutRules.parseShortcut(from: "Search ⌘F (also F)"), ["meta", "f"])
    }

    func test_parseShortcut_midSentenceLetter_doesNotFire() {
        // "Archive" contains letters but no isolated single-key pattern
        XCTAssertNil(ShortcutRules.parseShortcut(from: "Archive your messages"))
    }

    // MARK: - Notion sidebar nav rules (structural)

    private var notionRules: [ClickRule] { ShortcutRules.rules["notion.id"] ?? [] }

    func test_notionRules_homeTab_hasCorrectKeys() {
        let rule = notionRules.first { $0.shortcutId == "notion-home-tab" }
        XCTAssertNotNil(rule, "notion-home-tab rule must exist")
        XCTAssertEqual(rule?.keys, ["meta", "alt", "g"])
    }

    func test_notionRules_chatsTab_hasCorrectKeys() {
        let rule = notionRules.first { $0.shortcutId == "notion-chats-tab" }
        XCTAssertNotNil(rule, "notion-chats-tab rule must exist")
        XCTAssertEqual(rule?.keys, ["meta", "alt", "k"])
    }

    func test_notionRules_chatsTab_matchesSingularDesc() {
        // Notion reports desc='chat' (singular) — both forms must be covered
        let singularRule = notionRules.first {
            $0.shortcutId == "notion-chats-tab" && $0.descContains == "chat"
        }
        XCTAssertNotNil(singularRule, "notion-chats-tab must have a rule matching desc='chat' (singular)")
    }

    func test_notionRules_meetingsTab_hasCorrectKeys() {
        let rule = notionRules.first { $0.shortcutId == "notion-meetings-tab" }
        XCTAssertNotNil(rule, "notion-meetings-tab rule must exist")
        XCTAssertEqual(rule?.keys, ["meta", "alt", "y"])
    }

    func test_notionRules_inbox_hasCorrectKeys() {
        let rule = notionRules.first { $0.shortcutId == "notion-inbox" }
        XCTAssertNotNil(rule, "notion-inbox rule must exist")
        XCTAssertEqual(rule?.keys, ["meta", "alt", "u"])
    }

    func test_notionRules_homeTab_appearsBeforeSidebarToggle() {
        let ids = notionRules.map(\.shortcutId)
        let homeIdx = ids.firstIndex(of: "notion-home-tab") ?? Int.max
        let toggleIdx = ids.firstIndex(of: "notion-toggle-sidebar") ?? Int.max
        XCTAssertLessThan(homeIdx, toggleIdx,
            "notion-home-tab must be listed before notion-toggle-sidebar")
    }

    func test_notionRules_noGenericSidebarDescRule() {
        // The old broad `desc: "sidebar"` rule was catching sidebar nav items.
        // We now only allow "toggle sidebar", "close sidebar", "open sidebar".
        let broadSidebarRule = notionRules.first {
            $0.shortcutId == "notion-toggle-sidebar" &&
            ($0.descContains == "sidebar") &&
            $0.titleContains == nil
        }
        XCTAssertNil(broadSidebarRule,
            "Generic desc='sidebar' rule must not exist — it triggers on sidebar containers")
    }

    func test_notionRules_goBack_usesBracketKey() {
        let rule = notionRules.first { $0.shortcutId == "notion-go-back" }
        XCTAssertNotNil(rule, "notion-go-back rule must exist")
        XCTAssertEqual(rule?.keys, ["meta", "["],
            "Notion uses ⌘[ for back, not ⌘← (browser-style shortcut)")
    }

    func test_notionRules_goForward_usesBracketKey() {
        let rule = notionRules.first { $0.shortcutId == "notion-go-forward" }
        XCTAssertNotNil(rule, "notion-go-forward rule must exist")
        XCTAssertEqual(rule?.keys, ["meta", "]"],
            "Notion uses ⌘] for forward, not ⌘→ (browser-style shortcut)")
    }

    func test_notionRules_comment_hasCorrectKeys() {
        let rule = notionRules.first { $0.shortcutId == "notion-comment" }
        XCTAssertNotNil(rule, "notion-comment rule must exist")
        XCTAssertEqual(rule?.keys, ["meta", "shift", "m"])
    }

    func test_notionRules_editBlock_hasCorrectKeys() {
        let rule = notionRules.first { $0.shortcutId == "notion-edit-block" }
        XCTAssertNotNil(rule, "notion-edit-block rule must exist")
        XCTAssertEqual(rule?.keys, ["meta", "/"])
    }

    func test_notionRules_expandToggle_hasCorrectKeys() {
        let rule = notionRules.first { $0.shortcutId == "notion-toggle-expand" }
        XCTAssertNotNil(rule, "notion-toggle-expand rule must exist")
        XCTAssertEqual(rule?.keys, ["meta", "alt", "t"])
    }

    func test_notionRules_goUp_hasCorrectKeys() {
        let rule = notionRules.first { $0.shortcutId == "notion-go-up" }
        XCTAssertNotNil(rule, "notion-go-up rule must exist")
        XCTAssertEqual(rule?.keys, ["meta", "shift", "u"])
    }
}
