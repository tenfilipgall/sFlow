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

    func test_extractShortcuts_duplicateKey_firstWins() {
        var result: [String: MenuBarEntry] = [:]
        let js = """
            {label: 'Search', accelerator: 'CmdOrCtrl+F'},
            {label: 'Search', accelerator: 'CmdOrCtrl+S'},
        """
        ElectronShortcutScanner.extractShortcuts(from: js, into: &result)
        XCTAssertEqual(result["search"]?.keys, ["meta", "f"])
    }
}
