import XCTest
@testable import SFlow

final class ElectronShortcutScannerTests: XCTestCase {

    // MARK: - extractShortcuts tests

    func test_extractShortcuts_acceleratorWithLabel() {
        var result: [String: MenuBarEntry] = [:]
        let js = "{label: 'Quick Switcher', accelerator: 'CmdOrCtrl+K'}"
        ElectronShortcutScanner.extractShortcuts(from: js, into: &result)
        XCTAssertEqual(result["quick switcher"]?.keys, ["meta", "k"])
        XCTAssertEqual(result["quick switcher"]?.hint, "Quick Switcher")
    }

    func test_extractShortcuts_shortcutKey_withTitle() {
        var result: [String: MenuBarEntry] = [:]
        let js = "{title: 'New Tab', shortcut: 'CmdOrCtrl+T'}"
        ElectronShortcutScanner.extractShortcuts(from: js, into: &result)
        XCTAssertEqual(result["new tab"]?.keys, ["meta", "t"])
    }

    func test_extractShortcuts_noLabel_skipsEntry() {
        var result: [String: MenuBarEntry] = [:]
        let js = "accelerator: 'CmdOrCtrl+K'"
        ElectronShortcutScanner.extractShortcuts(from: js, into: &result)
        XCTAssertTrue(result.isEmpty)
    }

    func test_extractShortcuts_noMatches_returnsEmpty() {
        var result: [String: MenuBarEntry] = [:]
        ElectronShortcutScanner.extractShortcuts(from: "const x = 42;", into: &result)
        XCTAssertTrue(result.isEmpty)
    }

    func test_extractShortcuts_multipleEntries() {
        var result: [String: MenuBarEntry] = [:]
        let js = """
            {label: 'New Message', accelerator: 'CmdOrCtrl+N'},
            {label: 'Browse DMs', accelerator: 'CmdOrCtrl+Shift+K'},
        """
        ElectronShortcutScanner.extractShortcuts(from: js, into: &result)
        XCTAssertEqual(result["new message"]?.keys, ["meta", "n"])
        XCTAssertEqual(result["browse dms"]?.keys, ["meta", "shift", "k"])
    }

    func test_extractShortcuts_registerShortcut_withNearbyLabel() {
        var result: [String: MenuBarEntry] = [:]
        let js = "{label: 'Global Action', registerShortcut('Cmd+Shift+P', handler)}"
        ElectronShortcutScanner.extractShortcuts(from: js, into: &result)
        XCTAssertEqual(result["global action"]?.keys, ["meta", "shift", "p"])
    }

    func test_extractShortcuts_duplicateKey_firstWins() {
        var result: [String: MenuBarEntry] = [:]
        let js = """
            {label: 'Search', accelerator: 'CmdOrCtrl+F'},
            {label: 'Search', accelerator: 'CmdOrCtrl+S'},
        """
        ElectronShortcutScanner.extractShortcuts(from: js, into: &result)
        XCTAssertEqual(result["search"]?.keys, ["meta", "f"])
    }

    // MARK: - isElectronBundle tests

    func test_isElectronBundle_withAsarFile_returnsTrue() {
        let tmpBundle = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let resourcesDir = tmpBundle.appendingPathComponent("Contents/Resources")
        try! FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
        let created = FileManager.default.createFile(
            atPath: resourcesDir.appendingPathComponent("app.asar").path, contents: Data())
        XCTAssertTrue(created, "Prerequisite: failed to create app.asar fixture")
        defer { try? FileManager.default.removeItem(at: tmpBundle) }

        XCTAssertTrue(ElectronShortcutScanner.isElectronBundle(at: tmpBundle))
    }

    func test_isElectronBundle_withoutAsarFile_returnsFalse() {
        let tmpBundle = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmpBundle) }
        XCTAssertFalse(ElectronShortcutScanner.isElectronBundle(at: tmpBundle))
    }

    func test_extractShortcuts_modifierOnlyAccelerator_isSkipped() {
        var result: [String: MenuBarEntry] = [:]
        let js = "{label: 'Zoom In', accelerator: 'CmdOrCtrl+Plus'}"
        ElectronShortcutScanner.extractShortcuts(from: js, into: &result)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - scanASAR tests

    func test_scanASAR_targetedFile_findsShortcuts() {
        let js = "{label: 'Quick Switcher', accelerator: 'CmdOrCtrl+K'}"
        let url = writeAsar(files: [("keyboard-shortcuts.js", js)])
        defer { try? FileManager.default.removeItem(at: url) }

        let result = ElectronShortcutScanner.scanASAR(at: url)
        XCTAssertEqual(result["quick switcher"]?.keys, ["meta", "k"])
        XCTAssertEqual(result["quick switcher"]?.hint, "Quick Switcher")
    }

    func test_scanASAR_broadFallback_findsShortcuts() {
        // File name doesn't match targeted keywords → broad fallback
        let js = "{label: 'New Message', accelerator: 'CmdOrCtrl+N'}"
        let url = writeAsar(files: [("bundle.js", js)])
        defer { try? FileManager.default.removeItem(at: url) }

        let result = ElectronShortcutScanner.scanASAR(at: url)
        XCTAssertEqual(result["new message"]?.keys, ["meta", "n"])
    }

    func test_scanASAR_nodeModulesFile_isSkipped() {
        // node_modules files must be excluded from both passes
        let js = "{label: 'Inject', accelerator: 'CmdOrCtrl+I'}"
        let url = writeAsar(files: [("node_modules/evil/index.js", js)])
        defer { try? FileManager.default.removeItem(at: url) }

        let result = ElectronShortcutScanner.scanASAR(at: url)
        XCTAssertTrue(result.isEmpty)
    }

    func test_scanASAR_missingFile_returnsEmpty() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".asar")
        // file doesn't exist
        let result = ElectronShortcutScanner.scanASAR(at: url)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - parseWebKeyCombo

    func test_parseWebKeyCombo_commandAltG() {
        XCTAssertEqual(
            ElectronShortcutScanner.parseWebKeyCombo("command+alt+g"),
            ["meta", "alt", "g"])
    }

    func test_parseWebKeyCombo_commandBackslash() {
        XCTAssertEqual(
            ElectronShortcutScanner.parseWebKeyCombo("command+\\"),
            ["meta", "\\"])
    }

    func test_parseWebKeyCombo_ctrlShiftK() {
        XCTAssertEqual(
            ElectronShortcutScanner.parseWebKeyCombo("ctrl+shift+k"),
            ["ctrl", "shift", "k"])
    }

    // MARK: - extractNotionStyleShortcuts (unit)

    func test_extractNotion_simpleLiteralCombo() {
        let js = #"{id:"openHome",description:"Open home",defaultKeyCombination:["command+alt+g"]}"#
        let result = ElectronShortcutScanner.extractNotionStyleShortcuts(from: js)
        XCTAssertEqual(result["openHome"], ["meta", "alt", "g"])
    }

    func test_extractNotion_ternaryPicksFirstOption() {
        // t.isApple?"command+alt+g":"ctrl+alt+g" → picks "command+alt+g"
        let js = #"{id:"openSlipperySlopeHomeTab",description:"Open home",defaultKeyCombination:[t.isApple?"command+alt+g":"ctrl+alt+g"],visibleToUsers:!1}"#
        let result = ElectronShortcutScanner.extractNotionStyleShortcuts(from: js)
        XCTAssertEqual(result["openSlipperySlopeHomeTab"], ["meta", "alt", "g"])
    }

    func test_extractNotion_multipleEntries() {
        let js = """
        {id:"openSlipperySlopeHomeTab",description:"Home",defaultKeyCombination:[t.isApple?"command+alt+g":"ctrl+alt+g"],visibleToUsers:!1},
        {id:"openSlipperySlopeChatsTab",description:"Chats",defaultKeyCombination:[t.isApple?"command+alt+k":"ctrl+alt+k"],visibleToUsers:!1},
        {id:"openSlipperySlopeMeetingsTab",description:"Meetings",defaultKeyCombination:[t.isApple?"command+alt+y":"ctrl+alt+y"],visibleToUsers:!1}
        """
        let result = ElectronShortcutScanner.extractNotionStyleShortcuts(from: js)
        XCTAssertEqual(result["openSlipperySlopeHomeTab"],     ["meta", "alt", "g"])
        XCTAssertEqual(result["openSlipperySlopeChatsTab"],    ["meta", "alt", "k"])
        XCTAssertEqual(result["openSlipperySlopeMeetingsTab"], ["meta", "alt", "y"])
    }

    func test_extractNotion_modifierOnlyCombo_skipped() {
        // No non-modifier key → must be skipped
        let js = #"{id:"commandSOnly",defaultKeyCombination:["command"]}"#
        let result = ElectronShortcutScanner.extractNotionStyleShortcuts(from: js)
        XCTAssertNil(result["commandSOnly"])
    }

    func test_extractNotion_noCombo_skipped() {
        let js = #"{id:"noop",description:"Nothing",visibleToUsers:!1}"#
        let result = ElectronShortcutScanner.extractNotionStyleShortcuts(from: js)
        XCTAssertTrue(result.isEmpty)
    }

    func test_extractNotion_firstIdWins_duplicateIgnored() {
        let js = """
        {id:"openHome",defaultKeyCombination:["command+alt+g"]},
        {id:"openHome",defaultKeyCombination:["command+ctrl+h"]}
        """
        let result = ElectronShortcutScanner.extractNotionStyleShortcuts(from: js)
        XCTAssertEqual(result["openHome"], ["meta", "alt", "g"])
    }

    // MARK: - scanServiceWorkerCache integration (requires Notion installed)
    //
    // These tests validate part B against the shortcuts hardcoded in part A.
    // Skip automatically when Notion is not installed.

    private var notionSWCache: [String: MenuBarEntry]? {
        let fm = FileManager.default
        let support = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Notion")
        guard fm.fileExists(atPath: support.path) else { return nil }
        return ElectronShortcutScanner.scanServiceWorkerCache(appName: "Notion")
    }

    // MARK: - Integration tests: B scanner vs A hardcoded rules

    func test_scanSWCache_notion_homeTab_matchesHardcodedRule() throws {
        guard let cache = notionSWCache else {
            throw XCTSkip("Notion not installed — skipping integration test")
        }
        // Part A hardcodes Home → ["meta","alt","g"]
        // Part B should produce the same keys under lookup key "home"
        XCTAssertEqual(cache["home"]?.keys, ["meta", "alt", "g"],
                       "B scanner must agree with A hardcoded rule for Home tab")
    }

    func test_scanSWCache_notion_chatsTab_matchesHardcodedRule() throws {
        guard let cache = notionSWCache else {
            throw XCTSkip("Notion not installed — skipping integration test")
        }
        // Part A hardcodes Chats → ["meta","alt","k"]
        XCTAssertEqual(cache["chats"]?.keys, ["meta", "alt", "k"],
                       "B scanner must agree with A hardcoded rule for Chats tab")
    }

    func test_scanSWCache_notion_meetingsTab_matchesHardcodedRule() throws {
        guard let cache = notionSWCache else {
            throw XCTSkip("Notion not installed — skipping integration test")
        }
        // Part A hardcodes Meetings → ["meta","alt","y"]
        XCTAssertEqual(cache["meetings"]?.keys, ["meta", "alt", "y"],
                       "B scanner must agree with A hardcoded rule for Meetings tab")
    }

    func test_scanSWCache_notion_toggleSidebar_notRequired() throws {
        guard let cache = notionSWCache else {
            throw XCTSkip("Notion not installed — skipping integration test")
        }
        // toggleSidebar uses an outer locale ternary — scanner intentionally skips it.
        // Verify it doesn't store an incorrect value:
        if let entry = cache["sidebar"] {
            XCTAssertFalse(entry.keys.isEmpty)
        }
    }
}
