import XCTest
@testable import SFlow

final class PrivacyFilterTests: XCTestCase {

    // MARK: - Safe UI labels pass through unchanged

    func test_safeUILabel_passesThrough() {
        XCTAssertFalse(PrivacyFilter.containsPII("Compose"))
        XCTAssertFalse(PrivacyFilter.containsPII("Quick Switcher"))
        XCTAssertFalse(PrivacyFilter.containsPII("Mark unread"))
        XCTAssertFalse(PrivacyFilter.containsPII("Open Quick Switcher"))
        XCTAssertFalse(PrivacyFilter.containsPII("Reply to thread"))
        XCTAssertFalse(PrivacyFilter.containsPII("Save for later"))
        XCTAssertFalse(PrivacyFilter.containsPII(""))
    }

    func test_safeUILabel_redactPreservesValue() {
        XCTAssertEqual(PrivacyFilter.redact("Compose"), "Compose")
        XCTAssertEqual(PrivacyFilter.redact("Reply"), "Reply")
        XCTAssertEqual(PrivacyFilter.redact(""), "")
    }

    // MARK: - Emails

    func test_email_isDetected() {
        XCTAssertTrue(PrivacyFilter.containsPII("filip@example.com"))
        XCTAssertTrue(PrivacyFilter.containsPII("Message from filip@gocamping.tv"))
        XCTAssertTrue(PrivacyFilter.containsPII("contact+spam@sub.domain.co.uk"))
    }

    // MARK: - ISO dates

    func test_isoDate_isDetected() {
        XCTAssertTrue(PrivacyFilter.containsPII("2026-05-16"))
        XCTAssertTrue(PrivacyFilter.containsPII("Created 2026-05-16 at noon"))
    }

    // MARK: - Credit card patterns

    func test_maskedCardNumber_isDetected() {
        XCTAssertTrue(PrivacyFilter.containsPII("MasterCard •••• 2534 Filip Gawel 4 2032"))
        XCTAssertTrue(PrivacyFilter.containsPII("Visa **** 1234"))
    }

    func test_fullCardNumber_isDetected() {
        XCTAssertTrue(PrivacyFilter.containsPII("4111 1111 1111 1111"))
        XCTAssertTrue(PrivacyFilter.containsPII("4111-1111-1111-1111"))
    }

    // MARK: - Emoji (signals user-generated content / contact names)

    func test_emojiInString_isDetected() {
        XCTAssertTrue(PrivacyFilter.containsPII("☀️Sade☀️"))
        XCTAssertTrue(PrivacyFilter.containsPII("Bona nit! 🌙"))
        XCTAssertTrue(PrivacyFilter.containsPII("👋 Hello"))
    }

    // MARK: - Long content strings (heuristic for non-label content)

    func test_longString_isDetected() {
        let long = String(repeating: "a", count: 81)
        XCTAssertTrue(PrivacyFilter.containsPII(long))
    }

    func test_shortString_atBoundary_isNotDetected() {
        let eighty = String(repeating: "a", count: 80)
        XCTAssertFalse(PrivacyFilter.containsPII(eighty))
    }

    // MARK: - Currency markers (purchase / order info)

    func test_currencyAmount_isDetected() {
        XCTAssertTrue(PrivacyFilter.containsPII("Total: $19.99"))
        XCTAssertTrue(PrivacyFilter.containsPII("€50 charged"))
        XCTAssertTrue(PrivacyFilter.containsPII("Pay £25 now"))
    }

    // MARK: - Phone numbers

    func test_phoneNumber_isDetected() {
        XCTAssertTrue(PrivacyFilter.containsPII("+48 123 456 789"))
        XCTAssertTrue(PrivacyFilter.containsPII("Call 555-123-4567"))
    }

    // MARK: - redact() replaces unsafe values

    func test_redact_replacesEmailWithMarker() {
        XCTAssertEqual(PrivacyFilter.redact("filip@example.com"), "[REDACTED]")
    }

    func test_redact_replacesEmojiContent() {
        XCTAssertEqual(PrivacyFilter.redact("☀️Sade☀️"), "[REDACTED]")
    }

    func test_redact_preservesPlainLabel() {
        XCTAssertEqual(PrivacyFilter.redact("Mark unread"), "Mark unread")
    }
}
