import XCTest
@testable import SFlow

final class TextMatchingTests: XCTestCase {

    func test_exactMatch() {
        XCTAssertTrue(wordBoundaryContains(haystack: "search", needle: "search"))
    }

    func test_atStart_followedBySpace_matches() {
        XCTAssertTrue(wordBoundaryContains(haystack: "search slack", needle: "search"))
    }

    func test_atEnd_precededBySpace_matches() {
        XCTAssertTrue(wordBoundaryContains(haystack: "quick search", needle: "search"))
    }

    func test_inMiddle_surroundedBySpaces_matches() {
        XCTAssertTrue(wordBoundaryContains(haystack: "open search bar", needle: "search"))
    }

    func test_pluralExtension_matches() {
        // "bookmark" appears at start of "bookmarks", right side extends into "s" — allowed
        XCTAssertTrue(wordBoundaryContains(haystack: "bookmarks", needle: "bookmark"))
    }

    func test_insideWord_doesNotMatch() {
        // "search" inside "research" — left side is "e" (word char), not a boundary
        XCTAssertFalse(wordBoundaryContains(haystack: "research", needle: "search"))
    }

    func test_insideMultiwordPhrase_doesNotMatch() {
        XCTAssertFalse(wordBoundaryContains(haystack: "researcher tools", needle: "search"))
    }

    func test_punctuationIsBoundary() {
        XCTAssertTrue(wordBoundaryContains(haystack: "(search)", needle: "search"))
        XCTAssertTrue(wordBoundaryContains(haystack: "search…", needle: "search"))
    }

    func test_emptyNeedle_returnsFalse() {
        XCTAssertFalse(wordBoundaryContains(haystack: "anything", needle: ""))
    }

    func test_emptyHaystack_returnsFalse() {
        XCTAssertFalse(wordBoundaryContains(haystack: "", needle: "search"))
    }

    func test_needleLongerThanHaystack_returnsFalse() {
        XCTAssertFalse(wordBoundaryContains(haystack: "ab", needle: "abc"))
    }

    func test_unicodeBoundaryHandling() {
        // Polish: "wyślij" at start of "wyślij wiadomość" — leading char is at index 0 → boundary
        XCTAssertTrue(wordBoundaryContains(haystack: "wyślij wiadomość", needle: "wyślij"))
        // "ślij" inside "wyślij" — leading "y" is letter → no match
        XCTAssertFalse(wordBoundaryContains(haystack: "wyślij", needle: "ślij"))
    }
}
