import XCTest
@testable import SFlow

final class AXSkeletonFilterTests: XCTestCase {
    func testAcceptsStaticButton() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXButton", title: "New Message"),
            RawAXItem(role: "AXButton", title: "New Message"),  // appears 2x → static
        ])
        XCTAssertEqual(items.count, 1)  // deduped
        XCTAssertEqual(items[0].title, "New Message")
    }

    func testRejectsTextField() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXTextField", title: "Search"),
        ])
        XCTAssertEqual(items.count, 0)
    }

    func testRejectsHashPrefixed() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXLink", title: "#general"),
            RawAXItem(role: "AXLink", title: "#general"),
            RawAXItem(role: "AXLink", title: "#general"),
        ])
        XCTAssertEqual(items.count, 0)
    }

    func testRejectsLongTitles() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXButton", title: String(repeating: "x", count: 100)),
            RawAXItem(role: "AXButton", title: String(repeating: "x", count: 100)),
        ])
        XCTAssertEqual(items.count, 0)
    }

    func testRejectsLikelyHumanNames() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXLink", title: "Anna Kowalska"),
            RawAXItem(role: "AXLink", title: "Anna Kowalska"),
        ])
        XCTAssertEqual(items.count, 0)
    }

    func testRejectsEmail() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXLink", title: "user@example.com"),
            RawAXItem(role: "AXLink", title: "user@example.com"),
        ])
        XCTAssertEqual(items.count, 0)
    }

    func testAcceptsSingletonVerbLed() {
        // Appears once, but starts with a verb → likely static UI label
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXButton", title: "Add channel"),
        ])
        XCTAssertEqual(items.count, 1)
    }

    func testAllowedRoles() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXButton", title: "Send Message"),
            RawAXItem(role: "AXLink", title: "Open Settings"),
            RawAXItem(role: "AXMenuItem", title: "Save File"),
            RawAXItem(role: "AXCheckBox", title: "Show Notifications"),
            RawAXItem(role: "AXRadioButton", title: "Use Light Theme"),
            RawAXItem(role: "AXPopUpButton", title: "Choose Language"),
            RawAXItem(role: "AXStaticText", title: "Hello world"),   // rejected
            RawAXItem(role: "AXWindow", title: "Main"),               // rejected
        ])
        XCTAssertEqual(items.count, 6)
    }

    func testCapsTotalCount() {
        let many = (0..<700).map { RawAXItem(role: "AXButton", title: "Button \($0)") }
        let items = AXSkeletonExtractor.filter(rawItems: many)
        XCTAssertLessThanOrEqual(items.count, 500)
    }

    func testIdentifierPassesThroughToSkeletonItem() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXButton", title: "Send Message", identifier: "send-btn"),
            RawAXItem(role: "AXButton", title: "Send Message", identifier: "send-btn"),
        ])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].identifier, "send-btn")
    }

    func testSkeletonItemNilIdentifierOmittedFromJSON() throws {
        let item = SkeletonItem(role: "AXButton", title: "Send")
        let json = try JSONEncoder().encode(item)
        let dict = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        XCTAssertNil(dict["identifier"],
                     "nil identifier must not appear as null in encoded JSON")
    }

    // MARK: - Single-occurrence noun-led titles must survive (BUG B1)

    func test_filter_keepsSingleOccurrenceNounLedTitle_QuickSwitcher() {
        let items = [RawAXItem(role: "AXButton", title: "Quick Switcher")]
        let result = AXSkeletonExtractor.filter(rawItems: items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Quick Switcher")
    }

    func test_filter_keepsSingleOccurrencePreferences() {
        let items = [RawAXItem(role: "AXMenuItem", title: "Preferences")]
        let result = AXSkeletonExtractor.filter(rawItems: items)
        XCTAssertEqual(result.count, 1)
    }

    func test_filter_keepsSingleOccurrenceMentions() {
        let items = [RawAXItem(role: "AXButton", title: "Mentions & Reactions")]
        let result = AXSkeletonExtractor.filter(rawItems: items)
        XCTAssertEqual(result.count, 1)
    }

    func test_filter_stillDropsEmail() {
        // Sanity: other filters not affected
        let items = [RawAXItem(role: "AXButton", title: "user@example.com")]
        XCTAssertEqual(AXSkeletonExtractor.filter(rawItems: items).count, 0)
    }

    func test_filter_stillDropsHumanName() {
        let items = [RawAXItem(role: "AXButton", title: "John Smith")]
        XCTAssertEqual(AXSkeletonExtractor.filter(rawItems: items).count, 0)
    }
}
