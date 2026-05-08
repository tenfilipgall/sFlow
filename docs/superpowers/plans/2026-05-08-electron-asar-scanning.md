# Electron .asar Scanning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Parse `.asar` archives from Electron apps (Slack, VS Code, Linear, Figma, etc.) to extract keyboard shortcuts and surface them as toasts when users click matching UI elements.

**Architecture:** New `AsarReader` parses the binary .asar format; new `ElectronShortcutScanner` applies a hybrid regex scan; `MenuBarWatcher` detects Electron apps and merges results into the existing `MenuBarIndex`. No changes to `ClickWatcher`, `ToastWindow`, or `MenuBarCache` structure.

**Tech Stack:** Pure Swift, XCTest, `FileHandle` for binary I/O, `NSRegularExpression`, `JSONSerialization`.

---

## File Map

| File | Change | Responsibility |
|------|--------|----------------|
| `SFlow/BundleStringsScanner.swift` | Modify | Remove `private` from `parseElectronAccelerator` |
| `SFlowTests/MenuBarIndexTests.swift` | Modify | Fix pre-existing test bug (rawMods=8 → 0) |
| `SFlow/AsarReader.swift` | **Create** | Binary .asar header parsing + file extraction |
| `SFlowTests/AsarReaderTests.swift` | **Create** | Unit tests for AsarReader |
| `SFlow/ElectronShortcutScanner.swift` | **Create** | Hybrid JS scan, regex extraction, Electron detection |
| `SFlowTests/ElectronShortcutScannerTests.swift` | **Create** | Unit tests for ElectronShortcutScanner |
| `SFlow/MenuBarWatcher.swift` | Modify | Call ElectronShortcutScanner in `loadOrScan` |

After creating each new `.swift` file, run `xcodegen generate` from the project root to regenerate `SFlow.xcodeproj` so Xcode picks up the file.

---

## Context: Codebase Orientation

**`MenuBarEntry`** (in `MenuBarIndex.swift`):
```swift
struct MenuBarEntry {
    let keys: [String]   // e.g. ["meta", "k"]
    let hint: String     // e.g. "Quick Switcher"
}
```

**`MenuBarIndex.merge`** (already exists):
```swift
mutating func merge(_ other: [String: MenuBarEntry]) {
    for (k, v) in other where titleMap[k] == nil {
        titleMap[k] = v   // "first wins" — AX entries take priority
    }
}
```

**`MenuBarWatcher.loadOrScan`** (in `MenuBarWatcher.swift:123-141`):
```swift
private func loadOrScan(app: NSRunningApplication) {
    guard let bundleId = app.bundleIdentifier else { return }
    let version = appVersion(app) ?? "unknown"
    if let cached = MenuBarCache.load(bundleId: bundleId, version: version) {
        DispatchQueue.main.async { [weak self] in self?.currentIndex = MenuBarIndex(from: cached) }
        return
    }
    queue.async { [weak self] in
        var index = MenuBarIndex()
        index.build(for: app)
        MenuBarCache.save(bundleId: bundleId, version: version, entries: index.allEntries)
        DispatchQueue.main.async { [weak self] in self?.currentIndex = index }
    }
}
```

**Running tests:**
```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "passed|failed|error:"
```

**Running build:**
```bash
xcodebuild -project SFlow.xcodeproj -scheme SFlow -configuration Debug build \
  2>&1 | grep -E "SUCCEEDED|FAILED|error:"
```

---

## Task 1: Fix Test Baseline + Expose `parseElectronAccelerator`

**Files:**
- Modify: `SFlowTests/MenuBarIndexTests.swift:7`
- Modify: `SFlow/BundleStringsScanner.swift:82`

`test_parseModifiers_commandOnly` passes rawMods=8, but 8 is the "NoCommand" bit — correct input for command-only is rawMods=0. Fix the test input.

`parseElectronAccelerator` is `private`, but `ElectronShortcutScanner` (Task 4) needs it. Remove `private`.

- [ ] **Step 1: Fix the test bug**

In `SFlowTests/MenuBarIndexTests.swift`, change line 7:
```swift
// Before:
XCTAssertEqual(MenuBarIndex.parseModifiers(rawMods: 8), ["meta"])

// After:
XCTAssertEqual(MenuBarIndex.parseModifiers(rawMods: 0), ["meta"])
```

- [ ] **Step 2: Expose `parseElectronAccelerator`**

In `SFlow/BundleStringsScanner.swift`, change line 82:
```swift
// Before:
private static func parseElectronAccelerator(_ acc: String) -> [String] {

// After:
static func parseElectronAccelerator(_ acc: String) -> [String] {
```

- [ ] **Step 3: Run tests — all should pass**

```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "passed|failed|error:"
```

Expected: all tests pass (≥14 tests, 0 failures).

- [ ] **Step 4: Commit**

```bash
git add SFlowTests/MenuBarIndexTests.swift SFlow/BundleStringsScanner.swift
git commit -m "fix: correct parseModifiers test input; expose parseElectronAccelerator"
```

---

## Task 2: `AsarReader` — Binary Header Parsing (TDD)

**Files:**
- Create: `SFlowTests/AsarReaderTests.swift`
- Create: `SFlow/AsarReader.swift`

### ASAR Binary Format Reference

```
Bytes 0–3:   uint32LE = 4     (outer pickle payload size, always 4)
Bytes 4–7:   uint32LE = S     (inner pickle total size)
Bytes 8–11:  uint32LE = P     (inner pickle payload size)
Bytes 12–15: uint32LE = L     (JSON string byte length)
Bytes 16…:   L bytes          (JSON string, padded to 4-byte boundary)
Bytes 8+S…:  file data section  (dataOffset = 8 + S)
```

JSON header example:
```json
{"files":{"keyboard-shortcuts.js":{"offset":"0","size":42}}}
```
Nested dirs:
```json
{"files":{"app":{"files":{"main.js":{"offset":"0","size":5}}}}}
```
Leaf file fields: `offset` (string), `size` (int). Dirs have only `files`. Nodes with `"unpacked": true` are skipped.

### Fixture Builder (shared in both test files)

The helper below encodes an `[filename → content]` dict into a valid minimal `.asar` Data blob:

```swift
private func makeAsarData(files: [(path: String, content: String)]) -> Data {
    // Build JSON header with correct offsets
    var offset = 0
    var filesDict: [String: Any] = [:]
    var fileDataParts: [Data] = []
    for (path, content) in files {
        let data = Data(content.utf8)
        filesDict[path] = ["offset": "\(offset)", "size": data.count]
        offset += data.count
        fileDataParts.append(data)
    }
    let headerJSON = try! JSONSerialization.data(withJSONObject: ["files": filesDict])
    let jsonBytes = Array(headerJSON)
    let L = jsonBytes.count
    let paddedL = (L + 3) & ~3   // round up to 4-byte boundary

    // Inner pickle layout: [P (4 bytes)][L (4 bytes)][JSON bytes][padding]
    let P = 4 + paddedL           // payload = string-length field + padded JSON
    let S = 4 + P                 // total inner pickle = payload-size field + payload

    func uint32LE(_ v: Int) -> [UInt8] {
        let u = UInt32(v)
        return [UInt8(u & 0xFF), UInt8((u>>8)&0xFF), UInt8((u>>16)&0xFF), UInt8((u>>24)&0xFF)]
    }

    var bytes = [UInt8]()
    bytes += uint32LE(4)          // outer pickle payload size (always 4)
    bytes += uint32LE(S)          // inner pickle total size
    bytes += uint32LE(P)          // inner pickle payload size
    bytes += uint32LE(L)          // JSON string length
    bytes += jsonBytes
    bytes += [UInt8](repeating: 0, count: paddedL - L)
    for data in fileDataParts { bytes += Array(data) }
    return Data(bytes)
}

private func writeAsar(files: [(path: String, content: String)]) -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".asar")
    try! makeAsarData(files: files).write(to: url)
    return url
}
```

- [ ] **Step 1: Write failing tests**

Create `SFlowTests/AsarReaderTests.swift`:

```swift
import XCTest
@testable import SFlow

final class AsarReaderTests: XCTestCase {

    // MARK: - Fixture helpers (copy into ElectronShortcutScannerTests too)

    private func makeAsarData(files: [(path: String, content: String)]) -> Data {
        var offset = 0
        var filesDict: [String: Any] = [:]
        var fileDataParts: [Data] = []
        for (path, content) in files {
            let data = Data(content.utf8)
            filesDict[path] = ["offset": "\(offset)", "size": data.count]
            offset += data.count
            fileDataParts.append(data)
        }
        let headerJSON = try! JSONSerialization.data(withJSONObject: ["files": filesDict])
        let jsonBytes = Array(headerJSON)
        let L = jsonBytes.count
        let paddedL = (L + 3) & ~3
        let P = 4 + paddedL
        let S = 4 + P
        func uint32LE(_ v: Int) -> [UInt8] {
            let u = UInt32(v); return [UInt8(u&0xFF),UInt8((u>>8)&0xFF),UInt8((u>>16)&0xFF),UInt8((u>>24)&0xFF)]
        }
        var bytes = [UInt8]()
        bytes += uint32LE(4); bytes += uint32LE(S); bytes += uint32LE(P); bytes += uint32LE(L)
        bytes += jsonBytes; bytes += [UInt8](repeating: 0, count: paddedL - L)
        for data in fileDataParts { bytes += Array(data) }
        return Data(bytes)
    }

    private func writeAsar(files: [(path: String, content: String)]) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".asar")
        try! makeAsarData(files: files).write(to: url)
        return url
    }

    // MARK: - Tests

    func test_readHeader_singleFile_returnsEntry() {
        let url = writeAsar(files: [("test.js", "hello world")])
        defer { try? FileManager.default.removeItem(at: url) }

        guard let result = AsarReader.readHeader(from: url) else {
            XCTFail("readHeader returned nil"); return
        }
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "test.js")
        XCTAssertEqual(result.files[0].size, 11)
        XCTAssertEqual(result.files[0].offset, 0)
    }

    func test_readHeader_dataOffset_isCorrect() {
        let url = writeAsar(files: [("a.js", "hi")])
        defer { try? FileManager.default.removeItem(at: url) }
        // dataOffset = 8 + S; verify file bytes at dataOffset == "hi"
        guard let result = AsarReader.readHeader(from: url) else { XCTFail(); return }
        let data = try! Data(contentsOf: url)
        let fileBytes = data[Int(result.dataOffset)...]
        XCTAssertEqual(fileBytes.prefix(2), Data("hi".utf8))
    }

    func test_readHeader_nestedDirectory_flattensPath() {
        // Build ASAR with nested JSON manually (makeAsarData only does flat)
        let json = #"{"files":{"app":{"files":{"main.js":{"offset":"0","size":5}}}}}"#
        let jsonBytes = Array(json.utf8)
        let L = jsonBytes.count
        let paddedL = (L + 3) & ~3
        let P = 4 + paddedL; let S = 4 + P
        func u32(_ v: Int) -> [UInt8] {
            let u=UInt32(v); return [UInt8(u&0xFF),UInt8((u>>8)&0xFF),UInt8((u>>16)&0xFF),UInt8((u>>24)&0xFF)]
        }
        var bytes = [UInt8]()
        bytes += u32(4); bytes += u32(S); bytes += u32(P); bytes += u32(L)
        bytes += jsonBytes; bytes += [UInt8](repeating:0,count:paddedL-L)
        bytes += Array("hello".utf8)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".asar")
        try! Data(bytes).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        guard let result = AsarReader.readHeader(from: url) else { XCTFail(); return }
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "app/main.js")
    }

    func test_readHeader_malformedData_returnsNil() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".asar")
        try! Data([0,1,2,3]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNil(AsarReader.readHeader(from: url))
    }

    func test_readHeader_unpackedFile_isSkipped() {
        let json = #"{"files":{"packed.js":{"offset":"0","size":5},"skip.js":{"offset":"5","size":3,"unpacked":true}}}"#
        let jsonBytes = Array(json.utf8)
        let L = jsonBytes.count; let paddedL = (L+3)&~3
        let P = 4+paddedL; let S = 4+P
        func u32(_ v:Int)->[UInt8]{let u=UInt32(v);return[UInt8(u&0xFF),UInt8((u>>8)&0xFF),UInt8((u>>16)&0xFF),UInt8((u>>24)&0xFF)]}
        var bytes=[UInt8](); bytes+=u32(4); bytes+=u32(S); bytes+=u32(P); bytes+=u32(L)
        bytes+=jsonBytes; bytes+=[UInt8](repeating:0,count:paddedL-L); bytes+=Array("hellobye".utf8)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".asar")
        try! Data(bytes).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        guard let result = AsarReader.readHeader(from: url) else { XCTFail(); return }
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "packed.js")
    }
}
```

- [ ] **Step 2: Run — expect FAIL (AsarReader not defined)**

```bash
xcodegen generate 2>/dev/null; \
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "error:|FAILED" | head -5
```

Expected: compile error "cannot find type 'AsarReader'".

- [ ] **Step 3: Create `SFlow/AsarReader.swift`**

```swift
import Foundation

struct AsarFile {
    let path: String
    let offset: UInt64
    let size: Int
}

enum AsarReader {

    /// Parses the .asar binary header and returns a flat file list + data section offset.
    /// Returns nil if the file is missing, too short, or has invalid JSON.
    static func readHeader(from url: URL) -> (files: [AsarFile], dataOffset: UInt64)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        // Read outer pickle (8 bytes): bytes 0-3 = always 4, bytes 4-7 = S (inner pickle size)
        guard let first8 = try? handle.read(upToCount: 8), first8.count == 8 else { return nil }
        let S = first8.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).littleEndian }

        // Read inner pickle (S bytes starting at position 8)
        guard let inner = try? handle.read(upToCount: Int(S)), inner.count == Int(S) else { return nil }

        // Inner pickle: bytes 0-3 = payload size (P), bytes 4-7 = JSON string length (L)
        guard inner.count >= 8 else { return nil }
        let L = inner.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).littleEndian }
        guard inner.count >= 8 + Int(L) else { return nil }

        let jsonData = inner[8 ..< (8 + Int(L))]
        guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let root = json["files"] as? [String: Any] else { return nil }

        var files: [AsarFile] = []
        flatten(root, prefix: "", into: &files)
        return (files: files, dataOffset: UInt64(8 + S))
    }

    /// Reads the raw bytes of a single file from the archive.
    static func readFile(_ entry: AsarFile, in url: URL, dataOffset: UInt64) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard (try? handle.seek(toOffset: dataOffset + entry.offset)) != nil else { return nil }
        return try? handle.read(upToCount: entry.size)
    }

    // MARK: - Private

    private static func flatten(_ dict: [String: Any], prefix: String, into files: inout [AsarFile]) {
        for (name, value) in dict {
            guard let info = value as? [String: Any] else { continue }
            let path = prefix.isEmpty ? name : "\(prefix)/\(name)"
            if let nested = info["files"] as? [String: Any] {
                flatten(nested, prefix: path, into: &files)
            } else if info["unpacked"] as? Bool != true,
                      let offsetStr = info["offset"] as? String,
                      let offset = UInt64(offsetStr),
                      let size = info["size"] as? Int {
                files.append(AsarFile(path: path, offset: offset, size: size))
            }
        }
    }
}
```

- [ ] **Step 4: Run xcodegen and tests — expect PASS**

```bash
xcodegen generate 2>/dev/null; \
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "passed|failed|error:"
```

Expected: all AsarReaderTests pass, no other regressions.

- [ ] **Step 5: Commit**

```bash
git add SFlow/AsarReader.swift SFlowTests/AsarReaderTests.swift
git commit -m "feat: add AsarReader for .asar binary header parsing"
```

---

## Task 3: `AsarReader` — File Data Reading (TDD)

**Files:**
- Modify: `SFlowTests/AsarReaderTests.swift`
- Modify: `SFlow/AsarReader.swift` (already has `readFile` — verify it passes)

- [ ] **Step 1: Add test for `readFile`**

Append to `SFlowTests/AsarReaderTests.swift` inside the class:

```swift
func test_readFile_returnsCorrectBytes() {
    let url = writeAsar(files: [("test.js", "hello world")])
    defer { try? FileManager.default.removeItem(at: url) }

    guard let (files, dataOffset) = AsarReader.readHeader(from: url),
          let first = files.first else { XCTFail(); return }

    let data = AsarReader.readFile(first, in: url, dataOffset: dataOffset)
    XCTAssertEqual(data, Data("hello world".utf8))
}

func test_readFile_secondFile_correctOffset() {
    let url = writeAsar(files: [("a.js", "AAAA"), ("b.js", "BBBB")])
    defer { try? FileManager.default.removeItem(at: url) }

    guard let (files, dataOffset) = AsarReader.readHeader(from: url) else { XCTFail(); return }
    // Find b.js
    guard let bFile = files.first(where: { $0.path == "b.js" }) else { XCTFail(); return }
    let data = AsarReader.readFile(bFile, in: url, dataOffset: dataOffset)
    XCTAssertEqual(data, Data("BBBB".utf8))
}
```

- [ ] **Step 2: Run — expect PASS**

```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "passed|failed|error:"
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add SFlowTests/AsarReaderTests.swift
git commit -m "test: verify AsarReader.readFile byte extraction"
```

---

## Task 4: `ElectronShortcutScanner` — Shortcut Extraction (TDD)

**Files:**
- Create: `SFlowTests/ElectronShortcutScannerTests.swift`
- Create: `SFlow/ElectronShortcutScanner.swift`

This task covers `extractShortcuts(from:into:)` — the regex + label-search logic. The `scan` and `isElectronBundle` entry points come in Task 5.

- [ ] **Step 1: Write failing tests**

Create `SFlowTests/ElectronShortcutScannerTests.swift`:

```swift
import XCTest
@testable import SFlow

final class ElectronShortcutScannerTests: XCTestCase {

    // MARK: - ASAR fixture helpers (same as AsarReaderTests)

    private func makeAsarData(files: [(path: String, content: String)]) -> Data {
        var offset = 0; var filesDict: [String: Any] = [:]; var fileDataParts: [Data] = []
        for (path, content) in files {
            let data = Data(content.utf8)
            filesDict[path] = ["offset": "\(offset)", "size": data.count]
            offset += data.count; fileDataParts.append(data)
        }
        let headerJSON = try! JSONSerialization.data(withJSONObject: ["files": filesDict])
        let jsonBytes = Array(headerJSON); let L = jsonBytes.count; let paddedL = (L+3)&~3
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
        // Without a preceding label/title, we cannot produce a useful lookup key
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
```

- [ ] **Step 2: Run — expect FAIL (ElectronShortcutScanner not defined)**

```bash
xcodegen generate 2>/dev/null; \
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep "error:" | head -3
```

Expected: compile error "cannot find type 'ElectronShortcutScanner'".

- [ ] **Step 3: Create `SFlow/ElectronShortcutScanner.swift`** with `extractShortcuts` only (scan/isElectronBundle come in Task 5):

```swift
import Foundation
import AppKit

enum ElectronShortcutScanner {

    // MARK: - Regex extraction

    private static let acceleratorPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"accelerator:\s*['"]([^'"]+)['"]"#),
        try! NSRegularExpression(pattern: #"shortcut:\s*['"]([^'"]+)['"]"#),
        try! NSRegularExpression(pattern: #"registerShortcut\(['"]([^'"]+)['"]"#),
    ]

    private static let labelPattern = try! NSRegularExpression(
        pattern: #"(?:label|title):\s*['"]([^'"]{2,50})['"]"#)

    /// Scans `text` for Electron accelerator patterns, searching backwards for a label/title.
    /// Only adds entries where a label was found (label becomes the lookup key).
    static func extractShortcuts(from text: String, into result: inout [String: MenuBarEntry]) {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        for pattern in acceleratorPatterns {
            for match in pattern.matches(in: text, range: fullRange) {
                guard let accelRange = Range(match.range(at: 1), in: text) else { continue }
                let accelerator = String(text[accelRange])
                let keys = BundleStringsScanner.parseElectronAccelerator(accelerator)
                guard !keys.isEmpty else { continue }

                // Search backwards up to 200 chars for label:/title:
                let matchStart = match.range.location
                let searchStart = max(0, matchStart - 200)
                let searchRange = NSRange(location: searchStart, length: matchStart - searchStart)
                let labelMatches = labelPattern.matches(in: text, range: searchRange)
                guard let labelMatch = labelMatches.last,
                      let labelRange = Range(labelMatch.range(at: 1), in: text) else { continue }

                let hint = String(text[labelRange])
                let key = hint.lowercased()
                if result[key] == nil {
                    result[key] = MenuBarEntry(keys: keys, hint: hint)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "passed|failed|error:"
```

Expected: all ElectronShortcutScannerTests pass, no regressions.

- [ ] **Step 5: Commit**

```bash
git add SFlow/ElectronShortcutScanner.swift SFlowTests/ElectronShortcutScannerTests.swift
git commit -m "feat: add ElectronShortcutScanner regex extraction"
```

---

## Task 5: `ElectronShortcutScanner` — Hybrid Scan + Electron Detection (TDD)

**Files:**
- Modify: `SFlowTests/ElectronShortcutScannerTests.swift`
- Modify: `SFlow/ElectronShortcutScanner.swift`

- [ ] **Step 1: Add tests**

Append inside `ElectronShortcutScannerTests` class:

```swift
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
```

- [ ] **Step 2: Run — expect FAIL (isElectronBundle / scanASAR not defined)**

```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep "error:" | head -3
```

Expected: compile error "value of type 'ElectronShortcutScanner.Type' has no member 'isElectronBundle'".

- [ ] **Step 3: Add `isElectronBundle`, `isElectronApp`, `scan`, and `scanASAR` to `SFlow/ElectronShortcutScanner.swift`**

Append before the final `}` of the enum:

```swift
    // MARK: - Electron detection

    static func isElectronApp(_ app: NSRunningApplication) -> Bool {
        guard let url = app.bundleURL else { return false }
        return isElectronBundle(at: url)
    }

    static func isElectronBundle(at bundleURL: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: bundleURL.appendingPathComponent("Contents/Resources/app.asar").path)
    }

    // MARK: - Scan entry points

    static func scan(app: NSRunningApplication) -> [String: MenuBarEntry] {
        guard let bundleURL = app.bundleURL else { return [:] }
        return scanASAR(at: bundleURL.appendingPathComponent("Contents/Resources/app.asar"))
    }

    static func scanASAR(at url: URL) -> [String: MenuBarEntry] {
        guard let (allFiles, dataOffset) = AsarReader.readHeader(from: url) else { return [:] }

        let jsFiles = allFiles.filter {
            $0.path.hasSuffix(".js") && !$0.path.hasPrefix("node_modules/")
        }

        // Targeted pass: files whose path contains shortcut-related keywords
        let keywords = ["shortcut", "keyboard", "keybind", "hotkey", "accelerator", "keymap"]
        let targeted = jsFiles.filter { file in
            let lower = file.path.lowercased()
            return keywords.contains(where: { lower.contains($0) })
        }

        var result: [String: MenuBarEntry] = [:]
        for file in targeted {
            if let data = AsarReader.readFile(file, in: url, dataOffset: dataOffset),
               let text = String(data: data, encoding: .utf8) {
                extractShortcuts(from: text, into: &result)
            }
        }
        if !result.isEmpty { return result }

        // Broad fallback: largest JS files up to 500KB, max 30
        let broad = jsFiles
            .filter { $0.size <= 500_000 }
            .sorted { $0.size > $1.size }
            .prefix(30)

        for file in broad {
            if let data = AsarReader.readFile(file, in: url, dataOffset: dataOffset),
               let text = String(data: data, encoding: .utf8) {
                extractShortcuts(from: text, into: &result)
            }
        }
        return result
    }
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "passed|failed|error:"
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add SFlow/ElectronShortcutScanner.swift SFlowTests/ElectronShortcutScannerTests.swift
git commit -m "feat: add ElectronShortcutScanner hybrid ASAR scan and Electron detection"
```

---

## Task 6: Wire `ElectronShortcutScanner` into `MenuBarWatcher`

**Files:**
- Modify: `SFlow/MenuBarWatcher.swift:134-141`

- [ ] **Step 1: Update `loadOrScan` in `SFlow/MenuBarWatcher.swift`**

Find the `queue.async` block (currently lines 134–141). Replace it:

```swift
// Before:
queue.async { [weak self] in
    var index = MenuBarIndex()
    index.build(for: app)
    MenuBarCache.save(bundleId: bundleId, version: version, entries: index.allEntries)
    DispatchQueue.main.async { [weak self] in
        self?.currentIndex = index
    }
}

// After:
queue.async { [weak self] in
    var index = MenuBarIndex()
    index.build(for: app)
    if ElectronShortcutScanner.isElectronApp(app) {
        let asarEntries = ElectronShortcutScanner.scan(app: app)
        index.merge(asarEntries)
    }
    MenuBarCache.save(bundleId: bundleId, version: version, entries: index.allEntries)
    DispatchQueue.main.async { [weak self] in
        self?.currentIndex = index
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodegen generate 2>/dev/null; \
xcodebuild -project SFlow.xcodeproj -scheme SFlow -configuration Debug build \
  2>&1 | grep -E "SUCCEEDED|FAILED|error:"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run all tests**

```bash
xcodebuild test -project SFlow.xcodeproj -scheme SFlowTests -configuration Debug \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "passed|failed|error:"
```

Expected: all tests pass.

- [ ] **Step 4: Manual integration test**

```bash
# Kill any running SFlow, launch fresh
pkill -x SFlow 2>/dev/null; sleep 1
open /Users/filip/Library/Developer/Xcode/DerivedData/SFlow-fdvokifvonbqhgewimkxhiaxluff/Build/Products/Debug/SFlow.app
```

1. Switch to Slack (or any Electron app). Wait 1–2 seconds for background scan.
2. Click the Quick Switcher icon (top of sidebar). Toast should show `⌘K  Quick Switcher`.
3. Click Compose button. Toast should show `⌘N  New Message`.
4. Check `events.jsonl` for new entries:
   ```bash
   tail -5 ~/Library/Application\ Support/SFlow/events.jsonl
   ```

- [ ] **Step 5: Commit**

```bash
git add SFlow/MenuBarWatcher.swift
git commit -m "feat: integrate ElectronShortcutScanner into MenuBarWatcher for Electron app support"
```
