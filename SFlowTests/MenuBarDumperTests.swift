import XCTest
@testable import SFlow

final class MenuBarDumperTests: XCTestCase {
    func testFormatShortcutCmdN() {
        let s = MenuBarDumper.formatShortcut(cmdChar: "n", rawMods: 0)
        XCTAssertEqual(s, "cmd+n")
    }

    func testFormatShortcutCmdShiftK() {
        // bit 0 = shift
        let s = MenuBarDumper.formatShortcut(cmdChar: "k", rawMods: 0x01)
        XCTAssertEqual(s, "cmd+shift+k")
    }

    func testFormatShortcutNoCmd() {
        // bit 3 (0x08) set = cmd NOT used
        let s = MenuBarDumper.formatShortcut(cmdChar: "f", rawMods: 0x08)
        XCTAssertEqual(s, "f")
    }

    func testFormatShortcutAllModifiers() {
        let s = MenuBarDumper.formatShortcut(cmdChar: "a", rawMods: 0x01 | 0x02 | 0x04)
        XCTAssertEqual(s, "cmd+shift+alt+ctrl+a")
    }

    func testFormatShortcutEmpty() {
        XCTAssertNil(MenuBarDumper.formatShortcut(cmdChar: "", rawMods: 0))
    }
}
