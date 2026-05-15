import XCTest
@testable import SFlow

final class TooltipShortcutParserTests: XCTestCase {

    func test_singleLetter() {
        XCTAssertEqual(TooltipShortcutParser.parseBadge("C"), ["c"])
        XCTAssertEqual(TooltipShortcutParser.parseBadge("e"), ["e"])
        XCTAssertEqual(TooltipShortcutParser.parseBadge("R"), ["r"])
    }

    func test_singleDigit() {
        XCTAssertEqual(TooltipShortcutParser.parseBadge("1"), ["1"])
        XCTAssertEqual(TooltipShortcutParser.parseBadge("9"), ["9"])
    }

    func test_metaPlusLetter() {
        XCTAssertEqual(TooltipShortcutParser.parseBadge("⌘K"), ["meta", "k"])
        XCTAssertEqual(TooltipShortcutParser.parseBadge("⌘\\"), ["meta", "\\"])
    }

    func test_shiftPlusLetter() {
        XCTAssertEqual(TooltipShortcutParser.parseBadge("⇧R"), ["shift", "r"])
    }

    func test_threeModifiers() {
        XCTAssertEqual(TooltipShortcutParser.parseBadge("⌘⇧K"), ["meta", "shift", "k"])
        XCTAssertEqual(TooltipShortcutParser.parseBadge("⌃⌥⌘N"), ["ctrl", "alt", "meta", "n"])
    }

    func test_punctuation() {
        XCTAssertEqual(TooltipShortcutParser.parseBadge("/"), ["/"])
        XCTAssertEqual(TooltipShortcutParser.parseBadge("["), ["["])
    }

    func test_notionPlusSeparator() {
        // Notion Mail writes "⌘+\\" with explicit + between modifier and key.
        XCTAssertEqual(TooltipShortcutParser.parseBadge("⌘+\\"), ["meta", "\\"])
        XCTAssertEqual(TooltipShortcutParser.parseBadge("⌘+,"), ["meta", ","])
        XCTAssertEqual(TooltipShortcutParser.parseBadge("⌘+K"), ["meta", "k"])
        XCTAssertEqual(TooltipShortcutParser.parseBadge("⇧+R"), ["shift", "r"])
        XCTAssertEqual(TooltipShortcutParser.parseBadge("⌘+⇧+K"), ["meta", "shift", "k"])
    }

    func test_spaceSeparator() {
        XCTAssertEqual(TooltipShortcutParser.parseBadge("⌘ K"), ["meta", "k"])
        XCTAssertEqual(TooltipShortcutParser.parseBadge("⌘ ⇧ K"), ["meta", "shift", "k"])
    }

    func test_emptyReturnsNil() {
        XCTAssertNil(TooltipShortcutParser.parseBadge(""))
        XCTAssertNil(TooltipShortcutParser.parseBadge("   "))
    }

    func test_tooLongReturnsNil() {
        XCTAssertNil(TooltipShortcutParser.parseBadge("Compose"))
        XCTAssertNil(TooltipShortcutParser.parseBadge("Hello"))
    }

    func test_modifierWithoutKeyReturnsNil() {
        XCTAssertNil(TooltipShortcutParser.parseBadge("⌘"))
        XCTAssertNil(TooltipShortcutParser.parseBadge("⌘⇧"))
    }

    func test_modifierAfterKeyReturnsNil() {
        XCTAssertNil(TooltipShortcutParser.parseBadge("K⌘"))
    }

    func test_unknownCharReturnsNil() {
        XCTAssertNil(TooltipShortcutParser.parseBadge("→"))
        XCTAssertNil(TooltipShortcutParser.parseBadge("★"))
    }

    func test_trimsWhitespace() {
        XCTAssertEqual(TooltipShortcutParser.parseBadge(" C "), ["c"])
        XCTAssertEqual(TooltipShortcutParser.parseBadge("\t⌘K\n"), ["meta", "k"])
    }
}

final class TooltipObserverParseTests: XCTestCase {

    func test_parseTooltipTexts_basicNotionCompose() {
        let texts = ["Compose a new email", "C"]
        let result = TooltipObserver.parseTooltipTexts(texts)
        XCTAssertEqual(result?.badge, "C")
        XCTAssertEqual(result?.name, "Compose a new email")
    }

    func test_parseTooltipTexts_badgeFirst() {
        let texts = ["⌘\\", "Close sidebar"]
        let result = TooltipObserver.parseTooltipTexts(texts)
        XCTAssertEqual(result?.badge, "⌘\\")
        XCTAssertEqual(result?.name, "Close sidebar")
    }

    func test_parseTooltipTexts_noShortcutReturnsNil() {
        let texts = ["Save changes", "Cancel"]
        XCTAssertNil(TooltipObserver.parseTooltipTexts(texts))
    }

    func test_parseTooltipTexts_emptyReturnsNil() {
        XCTAssertNil(TooltipObserver.parseTooltipTexts([]))
    }

    func test_isTooltipShape_acceptsSmallNearCursor() {
        let cursor = CGPoint(x: 200, y: 200)
        let rect = CGRect(x: 180, y: 220, width: 200, height: 50)
        XCTAssertTrue(TooltipObserver.isTooltipShape(rect, cursor: cursor))
    }

    func test_isTooltipShape_rejectsTooLarge() {
        let cursor = CGPoint(x: 200, y: 200)
        let rect = CGRect(x: 100, y: 100, width: 800, height: 600)
        XCTAssertFalse(TooltipObserver.isTooltipShape(rect, cursor: cursor))
    }

    func test_isTooltipShape_rejectsFarFromCursor() {
        let cursor = CGPoint(x: 200, y: 200)
        let rect = CGRect(x: 1500, y: 1500, width: 200, height: 50)
        XCTAssertFalse(TooltipObserver.isTooltipShape(rect, cursor: cursor))
    }

    func test_isTooltipShape_rejectsTooSmall() {
        let cursor = CGPoint(x: 200, y: 200)
        let rect = CGRect(x: 180, y: 200, width: 10, height: 10)
        XCTAssertFalse(TooltipObserver.isTooltipShape(rect, cursor: cursor))
    }

    func test_privacyFilter_rejectsEmail() {
        XCTAssertTrue(TooltipObserver.containsSensitiveText("Reply to filip@example.com"))
    }

    func test_privacyFilter_rejectsURL() {
        XCTAssertTrue(TooltipObserver.containsSensitiveText("https://notion.so/help"))
    }

    func test_privacyFilter_rejectsDate() {
        XCTAssertTrue(TooltipObserver.containsSensitiveText("Snooze until 2026-05-20"))
    }

    func test_privacyFilter_rejectsLongStrings() {
        let long = String(repeating: "a", count: 100)
        XCTAssertTrue(TooltipObserver.containsSensitiveText(long))
    }

    func test_privacyFilter_acceptsRegularLabel() {
        XCTAssertFalse(TooltipObserver.containsSensitiveText("Compose a new email"))
        XCTAssertFalse(TooltipObserver.containsSensitiveText("Archive"))
        XCTAssertFalse(TooltipObserver.containsSensitiveText("Close sidebar"))
    }
}
