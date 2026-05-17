import XCTest
@testable import SFlow

final class TooltipNameFilterTests: XCTestCase {

    // MARK: - Multi-word names always pass (legitimate action labels)

    func test_multiWord_accepted() {
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("Mark unread"))
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("Reply to thread"))
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("Open Quick Switcher"))
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("Save for later"))
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("Compose a new email"))
    }

    // MARK: - Single-word names need whitelist

    func test_whitelistedSingleWord_accepted() {
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("Compose"))
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("Reply"))
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("Forward"))
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("Archive"))
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("Save"))
    }

    func test_unknownSingleWord_rejected() {
        // "randomword" is not on the whitelist — reject as likely noise.
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName("randomword"))
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName("Foo"))
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName("Bar"))
    }

    // MARK: - Banned meta-words always rejected (even though they look like words)

    func test_bannedMetaWord_rejected() {
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName("shortcut"))
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName("Shortcut"))
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName("SHORTCUT"))
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName("hotkey"))
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName("keyboard"))
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName("keys"))
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName("press"))
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName("help"))
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName("tip"))
    }

    // MARK: - Edge cases

    func test_empty_rejected() {
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName(""))
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName("   "))
    }

    func test_tooLong_rejected() {
        let long = String(repeating: "a", count: 61)
        XCTAssertFalse(TooltipNameFilter.isAcceptableActionName(long))
    }

    func test_caseInsensitive_whitelist() {
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("REPLY"))
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("compose"))
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("FoRwArD"))
    }

    func test_whitespaceTrimmed() {
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("  Reply  "))
        XCTAssertTrue(TooltipNameFilter.isAcceptableActionName("\nCompose\n"))
    }
}
