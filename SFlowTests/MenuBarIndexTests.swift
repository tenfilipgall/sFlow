import XCTest
@testable import SFlow

final class MenuBarIndexTests: XCTestCase {

    func test_parseModifiers_commandOnly() {
        XCTAssertEqual(MenuBarIndex.parseModifiers(rawMods: 0), ["meta"])
    }

    func test_parseModifiers_commandShift() {
        let mods = MenuBarIndex.parseModifiers(rawMods: 1)
        XCTAssertTrue(mods.contains("meta"))
        XCTAssertTrue(mods.contains("shift"))
    }

    func test_parseModifiers_alt() {
        let mods = MenuBarIndex.parseModifiers(rawMods: 2)
        XCTAssertTrue(mods.contains("alt"))
        XCTAssertTrue(mods.contains("meta"))
    }

    func test_parseModifiers_ctrl() {
        let mods = MenuBarIndex.parseModifiers(rawMods: 4)
        XCTAssertTrue(mods.contains("ctrl"))
        XCTAssertTrue(mods.contains("meta"))
    }

    func test_lookup_exactTitle() {
        var index = MenuBarIndex()
        index.insert(title: "New Message", keys: ["meta", "n"])
        let result = index.lookup(query: "new message")
        XCTAssertEqual(result?.keys, ["meta", "n"])
    }

    func test_lookup_partialTitle() {
        var index = MenuBarIndex()
        index.insert(title: "Find in Files", keys: ["meta", "shift", "f"])
        let result = index.lookup(query: "find")
        XCTAssertEqual(result?.keys, ["meta", "shift", "f"])
    }

    func test_lookup_noMatch_returnsNil() {
        var index = MenuBarIndex()
        index.insert(title: "New Message", keys: ["meta", "n"])
        XCTAssertNil(index.lookup(query: "archive"))
    }

    func test_lookup_emptyQuery_returnsNil() {
        var index = MenuBarIndex()
        index.insert(title: "New", keys: ["meta", "n"])
        XCTAssertNil(index.lookup(query: ""))
    }
}
