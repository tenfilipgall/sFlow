import XCTest
@testable import SFlow

final class RightClickMenuHarvesterTests: XCTestCase {

    // MARK: - parseShortcut: modifier bitfield → key array

    func test_plainCmdC() {
        let keys = RightClickMenuHarvester.parseShortcut(cmdChar: "c", cmdModifiers: 0)
        XCTAssertEqual(keys, ["cmd", "c"])
    }

    func test_cmdShiftC() {
        let keys = RightClickMenuHarvester.parseShortcut(cmdChar: "c",
                                                         cmdModifiers: RightClickMenuHarvester.modifierShift)
        XCTAssertEqual(keys, ["cmd", "shift", "c"])
    }

    func test_cmdOptionEnter() {
        let keys = RightClickMenuHarvester.parseShortcut(cmdChar: "",
                                                         cmdModifiers: RightClickMenuHarvester.modifierOption,
                                                         cmdVirtualKey: 0x24)
        XCTAssertEqual(keys, ["cmd", "alt", "return"])
    }

    func test_cmdControlOptionShiftA() {
        let mods = RightClickMenuHarvester.modifierShift
                 | RightClickMenuHarvester.modifierOption
                 | RightClickMenuHarvester.modifierControl
        let keys = RightClickMenuHarvester.parseShortcut(cmdChar: "a", cmdModifiers: mods)
        XCTAssertEqual(keys, ["cmd", "ctrl", "alt", "shift", "a"])
    }

    func test_noCommandBit_dropsCmd() {
        // kAXMenuItemModifierNoCommand bit set → cmd is omitted from result.
        let mods = RightClickMenuHarvester.modifierNoCommand
                 | RightClickMenuHarvester.modifierShift
        let keys = RightClickMenuHarvester.parseShortcut(cmdChar: "f", cmdModifiers: mods)
        XCTAssertEqual(keys, ["shift", "f"])
    }

    func test_emptyCharAndNoVirtualKey_returnsNil() {
        let keys = RightClickMenuHarvester.parseShortcut(cmdChar: "", cmdModifiers: 0,
                                                         cmdVirtualKey: nil)
        XCTAssertNil(keys)
    }

    func test_unknownVirtualKey_returnsNil() {
        let keys = RightClickMenuHarvester.parseShortcut(cmdChar: "", cmdModifiers: 0,
                                                         cmdVirtualKey: 0xFFFF)
        XCTAssertNil(keys)
    }

    func test_virtualKey_arrows() {
        XCTAssertEqual(RightClickMenuHarvester.virtualKeyName(0x7B), "left")
        XCTAssertEqual(RightClickMenuHarvester.virtualKeyName(0x7C), "right")
        XCTAssertEqual(RightClickMenuHarvester.virtualKeyName(0x7D), "down")
        XCTAssertEqual(RightClickMenuHarvester.virtualKeyName(0x7E), "up")
    }

    func test_virtualKey_fkeys() {
        XCTAssertEqual(RightClickMenuHarvester.virtualKeyName(0x7A), "f1")
        XCTAssertEqual(RightClickMenuHarvester.virtualKeyName(0x6F), "f12")
    }

    func test_cmdCharTrimmed() {
        let keys = RightClickMenuHarvester.parseShortcut(cmdChar: "  c  ", cmdModifiers: 0)
        XCTAssertEqual(keys, ["cmd", "c"])
    }

    func test_cmdCharLowercased() {
        let keys = RightClickMenuHarvester.parseShortcut(cmdChar: "C", cmdModifiers: 0)
        XCTAssertEqual(keys, ["cmd", "c"])
    }

    // MARK: - DiscoveredStore integration: menu-harvested entries
    //         bypass the tooltip 200×200 rect filter

    func test_menuRect_300x29_passesLookup() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sflow-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = DiscoveredStore(dir: tempDir)

        let menuRect = CGRect(x: 1162, y: 126, width: 300, height: 29)
        let entry = DiscoveredEntry(
            bundleId: "com.example.app",
            actionName: "Copy",
            keys: ["cmd", "c"],
            identifier: nil,
            rect: DiscoveredEntry.CGRectCodable(menuRect),
            observedAt: Date(),
            source: "rightclick_menu"
        )
        store.record(entry)
        _ = store.allEntries()  // flush queue

        let hit = store.lookup(near: CGPoint(x: 1300, y: 140), bundleId: "com.example.app")
        XCTAssertEqual(hit?.actionName, "Copy")
        XCTAssertEqual(hit?.source, "rightclick_menu")
    }

    func test_tooltipRect_300x29_isRejected() {
        // Same shape but source=nil (legacy tooltip path) → must still be rejected
        // by the tight 200×200 filter to keep the Chromium false-positive guard.
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sflow-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = DiscoveredStore(dir: tempDir)

        let bigRect = CGRect(x: 100, y: 100, width: 300, height: 29)
        let entry = DiscoveredEntry(
            bundleId: "com.example.app",
            actionName: "Bogus",
            keys: ["b"],
            identifier: nil,
            rect: DiscoveredEntry.CGRectCodable(bigRect),
            observedAt: Date(),
            source: nil
        )
        store.record(entry)
        _ = store.allEntries()

        let hit = store.lookup(near: CGPoint(x: 200, y: 110), bundleId: "com.example.app")
        XCTAssertNil(hit)
    }

    func test_oversizedMenuRect_stillRejected() {
        // Even with source=rightclick_menu, 500-wide is bogus (real menu items <400).
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sflow-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = DiscoveredStore(dir: tempDir)

        let bogusRect = CGRect(x: 0, y: 0, width: 500, height: 29)
        let entry = DiscoveredEntry(
            bundleId: "com.example.app",
            actionName: "Bogus",
            keys: ["b"],
            identifier: nil,
            rect: DiscoveredEntry.CGRectCodable(bogusRect),
            observedAt: Date(),
            source: "rightclick_menu"
        )
        store.record(entry)
        _ = store.allEntries()

        let hit = store.lookup(near: CGPoint(x: 250, y: 15), bundleId: "com.example.app")
        XCTAssertNil(hit)
    }
}
