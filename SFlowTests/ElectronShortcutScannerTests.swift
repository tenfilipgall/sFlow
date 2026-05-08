import XCTest
@testable import SFlow

final class ElectronShortcutScannerTests: XCTestCase {

    // MARK: - ASAR fixture helpers (same pattern as AsarReaderTests)

    private func makeAsarData(files: [(path: String, content: String)]) -> Data {
        var offset = 0; var filesDict: [String: Any] = [:]; var fileDataParts: [Data] = []
        for (path, content) in files {
            let data = Data(content.utf8)
            filesDict[path] = ["offset": "\(offset)", "size": data.count]
            offset += data.count; fileDataParts.append(data)
        }
        let headerJSON = try! JSONSerialization.data(withJSONObject: ["files": filesDict])
        let jsonBytes = Array(headerJSON); let L = jsonBytes.count; let paddedL = (L+3) & ~3
        let P = 4+paddedL; let S = 4+P
        func u32(_ v:Int)->[UInt8]{let u=UInt32(v);return[UInt8(u&0xFF),UInt8((u>>8)&0xFF),UInt8((u>>16)&0xFF),UInt8((u>>24)&0xFF)]}
        var bytes=[UInt8](); bytes+=u32(4); bytes+=u32(S); bytes+=u32(P); bytes+=u32(L)
        bytes+=jsonBytes; bytes+=[UInt8](repeating:0,count:paddedL-L)
        for data in fileDataParts { bytes+=Array(data) }; return Data(bytes)
    }

    private func writeAsar(files: [(path: String, content: String)]) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".asar")
        try! makeAsarData(files: files).write(to: url); return url
    }

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
        FileManager.default.createFile(atPath: resourcesDir.appendingPathComponent("app.asar").path,
                                       contents: Data())
        defer { try? FileManager.default.removeItem(at: tmpBundle) }

        XCTAssertTrue(ElectronShortcutScanner.isElectronBundle(at: tmpBundle))
    }

    func test_isElectronBundle_withoutAsarFile_returnsFalse() {
        let tmpBundle = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmpBundle) }
        XCTAssertFalse(ElectronShortcutScanner.isElectronBundle(at: tmpBundle))
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
}
