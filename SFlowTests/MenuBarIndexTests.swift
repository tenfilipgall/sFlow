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
        XCTAssertEqual(result?.entry.keys, ["meta", "n"])
        XCTAssertEqual(result?.confidence, .high)
    }

    func test_lookup_partialTitle() {
        var index = MenuBarIndex()
        index.insert(title: "Find in Files", keys: ["meta", "shift", "f"])
        // query "files" (5 chars) is a substring of key "find in files" → .medium match
        let result = index.lookup(query: "files")
        XCTAssertEqual(result?.entry.keys, ["meta", "shift", "f"])
        XCTAssertEqual(result?.confidence, .medium)
    }

    func test_lookup_copyLink_noFalsePositive() {
        // Bug P-5: "copy link" should NOT match key "copy" (old bug: q.contains(key) was true)
        var index = MenuBarIndex()
        index.insert(title: "Copy", keys: ["meta", "c"])
        XCTAssertNil(index.lookup(query: "copy link"))
    }

    func test_lookup_shortQuery_belowThreshold_returnsNil() {
        // Partial matching requires query.count >= 5 to avoid spurious matches
        var index = MenuBarIndex()
        index.insert(title: "Find in Files", keys: ["meta", "shift", "f"])
        XCTAssertNil(index.lookup(query: "find"))
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
