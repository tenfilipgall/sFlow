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
}
