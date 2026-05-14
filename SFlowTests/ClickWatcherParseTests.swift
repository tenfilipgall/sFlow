import XCTest
@testable import SFlow

final class ClickWatcherParseTests: XCTestCase {

    func testParseMetaPlusKey() {
        XCTAssertEqual(ClickWatcher.parseAriaShortcut("Meta+KeyK"), ["meta", "k"])
    }

    func testParseControlShiftKey() {
        XCTAssertEqual(ClickWatcher.parseAriaShortcut("Control+Shift+KeyS"), ["ctrl", "shift", "s"])
    }

    func testParseSingleKey() {
        XCTAssertEqual(ClickWatcher.parseAriaShortcut("KeyE"), ["e"])
    }

    func testParseDigit() {
        XCTAssertEqual(ClickWatcher.parseAriaShortcut("Meta+Digit1"), ["meta", "1"])
    }

    func testParseArrowKey() {
        XCTAssertEqual(ClickWatcher.parseAriaShortcut("ArrowUp"), ["up"])
    }

    func testParseFunctionKey() {
        XCTAssertEqual(ClickWatcher.parseAriaShortcut("F5"), ["f5"])
    }

    func testParseEnterKey() {
        XCTAssertEqual(ClickWatcher.parseAriaShortcut("Meta+Enter"), ["meta", "enter"])
    }

    func testParseUnknownTokenReturnsNil() {
        XCTAssertNil(ClickWatcher.parseAriaShortcut("SomeWeirdToken"))
    }

    func testParseEmptyStringReturnsNil() {
        XCTAssertNil(ClickWatcher.parseAriaShortcut(""))
    }
}
