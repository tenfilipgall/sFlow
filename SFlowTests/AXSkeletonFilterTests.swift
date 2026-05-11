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

    func testRejectsSingletonNonVerbLed() {
        // Appears once, doesn't look like a verb
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXButton", title: "Foo Bar"),
        ])
        XCTAssertEqual(items.count, 0)
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
}
