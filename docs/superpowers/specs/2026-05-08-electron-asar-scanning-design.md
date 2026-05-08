# Electron .asar Scanning — Implementation Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically extract keyboard shortcuts from Electron app bundles by parsing their `.asar` archives, merging results into the existing `MenuBarIndex` so `ClickWatcher` surfaces them as toasts.

**Architecture:** Three-part change — a new `AsarReader` (binary parser), a new `ElectronShortcutScanner` (shortcut extraction), and a small extension to `MenuBarWatcher` (Electron detection + trigger). The rest of the system (`ClickWatcher`, `ToastWindow`, `MenuBarCache`) is untouched.

**Tech Stack:** Pure Swift, no third-party dependencies. Reuses existing `MenuBarEntry`, `MenuBarCache`, `parseElectronAccelerator()` from `BundleStringsScanner`.

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `SFlow/AsarReader.swift` | Create | Parse `.asar` binary format; enumerate and extract files |
| `SFlow/ElectronShortcutScanner.swift` | Create | Hybrid JS scan; regex extraction; accelerator parsing |
| `SFlow/MenuBarWatcher.swift` | Modify | Detect Electron apps; trigger scanner in background queue |
| `SFlow/BundleStringsScanner.swift` | Modify | Extract `parseElectronAccelerator()` to shared scope |

---

## Section 1: Architecture

`ClickWatcher` consumes `menuBarWatcher.currentIndex` for Layer 3 fuzzy lookup. It does not know or care whether entries came from the native menu bar AX scan or from `.asar`. This is intentional — sources are an implementation detail of `MenuBarWatcher`.

Data flow on app-switch:

```
NSWorkspace.didActivateApplicationNotification
  └── MenuBarWatcher.loadOrScan(app:)
        ├── cache hit  → currentIndex = MenuBarIndex(from: cache)   [unchanged]
        └── cache miss → background queue:
              ├── MenuBarIndex.build(for: app)                       [unchanged — AX menu scan]
              ├── isElectronApp(app) == true?
              │     └── ElectronShortcutScanner.scan(app:)
              │           └── index.merge(asarEntries)
              └── MenuBarCache.save(...) + currentIndex = index
```

---

## Section 2: ASAR Format Parsing (`AsarReader`)

The `.asar` format uses Chromium's Pickle encoding for its header.

**Binary layout:**
```
Bytes 0–3:   uint32LE = 4          (outer pickle payload size, always 4)
Bytes 4–7:   uint32LE = S          (inner pickle size)
Bytes 8–11:  uint32LE = P          (inner pickle payload size)
Bytes 12–15: uint32LE = L          (JSON string byte length)
Bytes 16…:   L bytes               (JSON header string)
Bytes 8+S…:  file data section     (dataOffset = 8 + S)
```

**JSON header** is a nested tree of `files` dicts. Leaf nodes have `offset` (string, relative to dataOffset) and `size` (int). Directories have only `files`. Nodes with `"unpacked": true` are skipped (their data lives in `.asar.unpacked/`, never `.js` app logic).

**`AsarReader` API:**
```swift
struct AsarFile {
    let path: String      // e.g. "app/keyboard-shortcuts.js"
    let offset: UInt64    // relative to dataOffset
    let size: Int
}

enum AsarReader {
    // Returns flattened file list + dataOffset, or nil on parse failure.
    static func readHeader(from url: URL) -> (files: [AsarFile], dataOffset: UInt64)?

    // Reads raw bytes of a single file from the archive.
    static func readFile(_ entry: AsarFile, in url: URL, dataOffset: UInt64) -> Data?
}
```

`readHeader` opens the file handle once, reads the binary header, parses JSON, and recursively flattens the tree. `readFile` opens a new handle, seeks to `dataOffset + entry.offset`, reads `entry.size` bytes.

---

## Section 3: Shortcut Extraction (`ElectronShortcutScanner`)

**Electron detection:**
```swift
static func isElectronApp(_ app: NSRunningApplication) -> Bool {
    guard let url = app.bundleURL else { return false }
    return FileManager.default.fileExists(
        atPath: url.appendingPathComponent("Contents/Resources/app.asar").path)
}
```

**ASAR location:** `{bundleURL}/Contents/Resources/app.asar`

**Hybrid scan strategy:**

1. **Targeted pass** — filter `AsarFile` list to entries where `path` (lowercased) contains any of: `shortcut`, `keyboard`, `keybind`, `hotkey`, `accelerator`, `keymap`; extension `.js`; path does NOT start with `node_modules/`. Scan all matching files.

2. **Broad fallback** (only if targeted pass found zero entries) — take all `.js` files not in `node_modules/`, filter to size ≤ 500 000 bytes, sort descending by `size`, take first 30. Scan those.

**Regex patterns applied to each file's UTF-8 text:**
```
accelerator:\s*['"]([^'"]+)['"]
shortcut:\s*['"]([^'"]+)['"]
registerShortcut\(['"]([^'"]+)['"]
```

**Hint extraction:** For each accelerator match, search backwards up to 200 characters for a `label:` or `title:` value on the same JS object. If found, use it as the hint. Otherwise hint = formatted key symbols (e.g. `⌘K`).

**Accelerator parsing:** Reuse `parseElectronAccelerator()` from `BundleStringsScanner`. `CmdOrCtrl+Shift+K` → `["meta", "shift", "k"]`.

**`ElectronShortcutScanner` API:**
```swift
enum ElectronShortcutScanner {
    static func scan(app: NSRunningApplication) -> [String: MenuBarEntry]
}
```

Returns a `[lowercasedLabel: MenuBarEntry]` dict, same format as `MenuBarIndex.allEntries`. Empty dict if no .asar found or no shortcuts extracted.

---

## Section 4: MenuBarWatcher Integration

**Changes to `loadOrScan(app:)`** — after the existing `MenuBarIndex.build(for: app)` call on the background queue, add:

```swift
if ElectronShortcutScanner.isElectronApp(app) {
    let asarEntries = ElectronShortcutScanner.scan(app: app)
    index.merge(asarEntries)
}
```

`MenuBarIndex.merge()` already exists and uses a "first wins" policy — native AX menu entries take precedence over ASAR entries for the same key.

**`parseElectronAccelerator` scope:** Move from `private` in `BundleStringsScanner` to `internal` so `ElectronShortcutScanner` can call it. No signature change.

---

## Error Handling

- If `.asar` header parse fails (corrupt file, unsupported format) → return empty dict, log one NSLog error line, continue.
- If a specific JS file read fails → skip that file, continue with others.
- If no shortcuts found in any file → return empty dict (no toast, no error).
- File handle always closed in `defer` blocks.

---

## Testing

**`AsarReader` unit tests** (`AsarReaderTests.swift`):
- Create a minimal valid `.asar` binary fixture (header + one JS file) and verify `readHeader` returns correct file list and dataOffset.
- Verify `readFile` returns correct bytes for the fixture.
- Verify malformed header returns `nil`.

**`ElectronShortcutScanner` unit tests** (`ElectronShortcutScannerTests.swift`):
- Feed a JS string containing `accelerator: 'CmdOrCtrl+K'` with preceding `label: 'Quick Switcher'` → expect `["quick switcher": MenuBarEntry(keys: ["meta","k"], hint: "Quick Switcher")]`.
- Feed JS with no matches → expect empty dict.
- Feed JS with `registerShortcut('Cmd+Shift+P'` → expect correct keys.
- Verify `isElectronApp` returns true for a mock bundle path containing `app.asar`.

**Integration (manual):** Launch SFlow, switch to Slack. After <1s, click the "Quick Switcher" button — toast should show `⌘K  Quick Switcher`. Verify `events.jsonl` entry has `shortcutId` prefixed `menuindex:` (the existing lookup path) or no change if ASAR data merged correctly into index.
