#!/usr/bin/env swift
// Per-frame Claude vision analysis for SFlow video eval (Sub-cel 1.8 Droga B).
// Reads all f_*.png in a frames directory, calls Claude vision API per frame,
// writes a structured markdown report to <output_md>.
//
// Usage:
//   sflow-video-llm <frames_dir> <output_md> [--model M] [--concurrency N] [--interval-sec S]
//
// Env:
//   ANTHROPIC_API_KEY   required
//
// Report layout: timeline table (one row per dedup'd state) + raw frame log.

import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Args

func usage() -> Never {
    fputs("""
    usage: sflow-video-llm <frames_dir> <output_md> [--model M] [--concurrency N] [--interval-sec S]

      <frames_dir>     directory with f_*.png produced by sflow-video-extract.swift
      <output_md>      output path for the markdown report
      --model M        Claude model id (default: claude-haiku-4-5-20251001)
      --concurrency N  parallel API requests (default: 5)
      --interval-sec S seconds between frames, used to compute timestamps (default: 1.0)

    """, stderr)
    exit(64)
}

var positional: [String] = []
var model = "claude-haiku-4-5-20251001"
var concurrency = 5
var intervalSec: Double = 1.0

var argv = Array(CommandLine.arguments.dropFirst())
while let arg = argv.first {
    argv.removeFirst()
    switch arg {
    case "--model":
        guard let v = argv.first else { usage() }
        model = v; argv.removeFirst()
    case "--concurrency":
        guard let v = argv.first, let n = Int(v), n > 0 else { usage() }
        concurrency = n; argv.removeFirst()
    case "--interval-sec":
        guard let v = argv.first, let d = Double(v), d > 0 else { usage() }
        intervalSec = d; argv.removeFirst()
    case "--help", "-h":
        usage()
    default:
        if arg.hasPrefix("--") { usage() }
        positional.append(arg)
    }
}

guard positional.count == 2 else { usage() }
let framesDir = positional[0]
let outputMd  = positional[1]

guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !apiKey.isEmpty else {
    fputs("error: ANTHROPIC_API_KEY env var is not set\n", stderr)
    exit(2)
}

// MARK: - Find frames

let fm = FileManager.default
guard let files = try? fm.contentsOfDirectory(atPath: framesDir) else {
    fputs("error: cannot read frames dir: \(framesDir)\n", stderr)
    exit(3)
}

let frameNames = files
    .filter { $0.hasPrefix("f_") && $0.hasSuffix(".png") }
    .sorted()

guard !frameNames.isEmpty else {
    fputs("error: no f_*.png frames found in \(framesDir)\n", stderr)
    exit(4)
}

fputs("sflow-video-llm: \(frameNames.count) frames, model=\(model), concurrency=\(concurrency)\n", stderr)

// MARK: - Prompt

let analysisPrompt = """
This frame is from a screen recording on macOS. The user is testing SFlow, a tool that displays a small dark toast overlay near a clicked UI element with the action name and its keyboard shortcut.

Inspect the frame carefully. Reply with STRICT JSON, no prose, no markdown fences. Schema:

{
  "toastVisible": true|false,
  "toastAction": "string or null",
  "toastKeys": "string or null",
  "appName": "string or null",
  "nativeTooltipVisible": true|false,
  "nativeTooltipText": "string or null",
  "cursorAction": "string or null"
}

WHAT AN SFLOW TOAST IS — strict definition:

An SFlow toast is a STANDALONE overlay floating ON TOP of the app window, OUTSIDE of any menu, dropdown, panel, sidebar, or list. It has ALL of these properties:
- Compact: 1-3 words for the action + a small shortcut indicator (e.g. "Compose ⌘N", "Reply R")
- A single rounded dark pill, NOT a row inside a list or menu
- Free-floating: NOT attached to or inside a context menu, command palette, dropdown, settings panel, search results list, or sidebar nav
- Appears briefly (~1.5s) typically near the cursor or near the element that was just clicked
- It is NOT part of the app's own native UI

WHAT IS NOT AN SFLOW TOAST (set toastVisible=false for ALL of these):

1. NATIVE CONTEXT MENUS — when you right-click in Slack, Notion, etc., the app shows a vertical list of items, each row often containing an action name on the left and a keyboard shortcut on the right (e.g. "Edit message  E", "Copy link  L", "Mark unread  U"). These rows are part of the APP's native menu, NOT SFlow toasts. Even if they look "dark with a shortcut", they are inside a multi-row menu container.
2. COMMAND PALETTES — VS Code/Xcode/Cursor command palette, Slack's ⌘K Quick Switcher, Raycast results, Notion `/`-menu. All have multi-row lists with shortcut hints. NOT SFlow.
3. MENU BAR DROPDOWNS — when the user clicks "File", "Edit", "View" in the menu bar and a dropdown opens with shortcuts shown on the right. NOT SFlow.
4. NATIVE TOOLTIPS — light/yellow background, attached to an element on hover. Those go in the nativeTooltipVisible field, not toastVisible.
5. KEYBOARD SHORTCUT HELP OVERLAYS that the app itself ships with (e.g. ?-key opens a sheet of all shortcuts).

GOLDEN TEST before setting toastVisible=true: "Is this a SINGLE compact pill floating on top of the app, separate from any menu, list, or panel?" If you have to scroll your eyes through a list of similar-looking items to find it — it's a menu, not a toast.

Field rules:
- toastVisible: true ONLY if the strict definition above is met. When in doubt, set false. False negatives are MUCH better than false positives.
- toastAction: the action label visible on the toast (e.g. "Compose new email"), null if no toast.
- toastKeys: the shortcut shown on the toast (e.g. "⌘N", "C", "⌘⇧K"), null if no toast.
- appName: foreground app (read from window title bar, dock highlight, or distinctive UI). Null if unsure.
- nativeTooltipVisible: true if a native/in-app tooltip is visible near the cursor (light/yellow tooltip showing info or shortcut). NOT for SFlow toasts. NOT for context menus.
- nativeTooltipText: full text of that tooltip if visible.
- cursorAction: best guess at the UI element under the cursor right now ("Compose button", "Sidebar toggle"). Null if cursor unclear.

Output the JSON only. No commentary.
"""

// MARK: - Frame analysis

struct FrameResult {
    let index: Int
    let name: String
    let timestampSec: Double
    let toastVisible: Bool
    let toastAction: String?
    let toastKeys: String?
    let appName: String?
    let nativeTooltipVisible: Bool
    let nativeTooltipText: String?
    let cursorAction: String?
    let rawText: String?
    let error: String?
}

func readJSONString(_ raw: String) -> [String: Any]? {
    // Tolerate stray fences just in case the model misbehaves.
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("```") {
        if let firstNewline = s.firstIndex(of: "\n") {
            s = String(s[s.index(after: firstNewline)...])
        }
        if let fenceRange = s.range(of: "```", options: .backwards) {
            s = String(s[..<fenceRange.lowerBound])
        }
    }
    guard let data = s.data(using: .utf8) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}

func httpPost(url: URL, body: Data, headers: [String: String], timeout: TimeInterval = 90) -> (Data?, Int, Error?) {
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.httpBody = body
    req.timeoutInterval = timeout
    for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

    var outData: Data?
    var outStatus = 0
    var outErr: Error?
    let sem = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: req) { data, resp, err in
        outData = data
        outStatus = (resp as? HTTPURLResponse)?.statusCode ?? 0
        outErr = err
        sem.signal()
    }.resume()
    sem.wait()
    return (outData, outStatus, outErr)
}

func analyzeFrame(index: Int, name: String, path: String) -> FrameResult {
    let timestamp = Double(index) * intervalSec

    guard let pngData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
        return FrameResult(index: index, name: name, timestampSec: timestamp,
                           toastVisible: false, toastAction: nil, toastKeys: nil,
                           appName: nil, nativeTooltipVisible: false, nativeTooltipText: nil,
                           cursorAction: nil, rawText: nil, error: "cannot read frame file")
    }

    let b64 = pngData.base64EncodedString()
    let payload: [String: Any] = [
        "model": model,
        "max_tokens": 600,
        "messages": [[
            "role": "user",
            "content": [
                ["type": "image",
                 "source": ["type": "base64", "media_type": "image/png", "data": b64]],
                ["type": "text", "text": analysisPrompt]
            ]
        ]]
    ]
    guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
        return FrameResult(index: index, name: name, timestampSec: timestamp,
                           toastVisible: false, toastAction: nil, toastKeys: nil,
                           appName: nil, nativeTooltipVisible: false, nativeTooltipText: nil,
                           cursorAction: nil, rawText: nil, error: "payload encode failed")
    }

    let (respData, status, err) = httpPost(
        url: URL(string: "https://api.anthropic.com/v1/messages")!,
        body: body,
        headers: [
            "content-type": "application/json",
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01"
        ]
    )

    if let err = err {
        return FrameResult(index: index, name: name, timestampSec: timestamp,
                           toastVisible: false, toastAction: nil, toastKeys: nil,
                           appName: nil, nativeTooltipVisible: false, nativeTooltipText: nil,
                           cursorAction: nil, rawText: nil, error: "transport: \(err.localizedDescription)")
    }
    guard let data = respData else {
        return FrameResult(index: index, name: name, timestampSec: timestamp,
                           toastVisible: false, toastAction: nil, toastKeys: nil,
                           appName: nil, nativeTooltipVisible: false, nativeTooltipText: nil,
                           cursorAction: nil, rawText: nil, error: "no response body")
    }
    guard status == 200 else {
        let snippet = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
        return FrameResult(index: index, name: name, timestampSec: timestamp,
                           toastVisible: false, toastAction: nil, toastKeys: nil,
                           appName: nil, nativeTooltipVisible: false, nativeTooltipText: nil,
                           cursorAction: nil, rawText: nil, error: "http \(status): \(snippet)")
    }

    guard
        let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let content = envelope["content"] as? [[String: Any]],
        let first = content.first,
        let text = first["text"] as? String
    else {
        return FrameResult(index: index, name: name, timestampSec: timestamp,
                           toastVisible: false, toastAction: nil, toastKeys: nil,
                           appName: nil, nativeTooltipVisible: false, nativeTooltipText: nil,
                           cursorAction: nil, rawText: nil, error: "envelope parse failed")
    }

    guard let parsed = readJSONString(text) else {
        return FrameResult(index: index, name: name, timestampSec: timestamp,
                           toastVisible: false, toastAction: nil, toastKeys: nil,
                           appName: nil, nativeTooltipVisible: false, nativeTooltipText: nil,
                           cursorAction: nil, rawText: text, error: "model returned non-JSON")
    }

    func str(_ key: String) -> String? {
        if let v = parsed[key] as? String, !v.isEmpty { return v }
        return nil
    }
    func bool(_ key: String) -> Bool {
        return (parsed[key] as? Bool) ?? false
    }

    return FrameResult(
        index: index,
        name: name,
        timestampSec: timestamp,
        toastVisible: bool("toastVisible"),
        toastAction: str("toastAction"),
        toastKeys: str("toastKeys"),
        appName: str("appName"),
        nativeTooltipVisible: bool("nativeTooltipVisible"),
        nativeTooltipText: str("nativeTooltipText"),
        cursorAction: str("cursorAction"),
        rawText: text,
        error: nil
    )
}

// MARK: - Parallel run

let semaphore = DispatchSemaphore(value: concurrency)
let group = DispatchGroup()
let resultsLock = NSLock()
var results = [FrameResult?](repeating: nil, count: frameNames.count)
var done = 0
let total = frameNames.count
let startTs = Date()

for (i, name) in frameNames.enumerated() {
    let path = (framesDir as NSString).appendingPathComponent(name)
    group.enter()
    semaphore.wait()
    DispatchQueue.global(qos: .userInitiated).async {
        let r = analyzeFrame(index: i, name: name, path: path)
        resultsLock.lock()
        results[i] = r
        done += 1
        let progress = done
        resultsLock.unlock()
        if progress % 5 == 0 || progress == total {
            fputs("sflow-video-llm: \(progress)/\(total) frames analyzed\n", stderr)
        }
        semaphore.signal()
        group.leave()
    }
}
group.wait()

let elapsed = Date().timeIntervalSince(startTs)
fputs(String(format: "sflow-video-llm: done in %.1fs\n", elapsed), stderr)

let finals: [FrameResult] = results.compactMap { $0 }

// MARK: - Aggregation

// Build a "state" string per frame to dedup consecutive identical frames.
func stateKey(_ r: FrameResult) -> String {
    let toast = r.toastVisible
        ? "TOAST[\(r.toastAction ?? "?")|\(r.toastKeys ?? "?")]"
        : "noToast"
    let tip = r.nativeTooltipVisible
        ? "TIP[\(r.nativeTooltipText ?? "?")]"
        : "noTip"
    let cur = r.cursorAction ?? "?"
    return "\(toast)::\(tip)::\(cur)"
}

struct Span {
    var startIndex: Int
    var endIndex: Int
    var startTs: Double
    var endTs: Double
    var sample: FrameResult
}

var spans: [Span] = []
for r in finals {
    if var last = spans.last, stateKey(last.sample) == stateKey(r) {
        last.endIndex = r.index
        last.endTs = r.timestampSec
        spans[spans.count - 1] = last
    } else {
        spans.append(Span(startIndex: r.index, endIndex: r.index,
                          startTs: r.timestampSec, endTs: r.timestampSec, sample: r))
    }
}

// Stats
let toastFrames = finals.filter { $0.toastVisible }.count
let tipFrames = finals.filter { $0.nativeTooltipVisible }.count
let errFrames = finals.filter { $0.error != nil }.count

// Group toast hits per (action, keys)
struct ToastHit: Hashable { let action: String; let keys: String; let app: String }
var toastCounts: [ToastHit: Int] = [:]
for r in finals where r.toastVisible {
    let hit = ToastHit(
        action: r.toastAction ?? "?",
        keys: r.toastKeys ?? "?",
        app: r.appName ?? "?"
    )
    toastCounts[hit, default: 0] += 1
}
let topToasts = toastCounts.sorted { $0.value > $1.value }

struct TipHit: Hashable { let text: String; let app: String }
var tipCounts: [TipHit: Int] = [:]
for r in finals where r.nativeTooltipVisible {
    let hit = TipHit(text: r.nativeTooltipText ?? "?", app: r.appName ?? "?")
    tipCounts[hit, default: 0] += 1
}
let topTips = tipCounts.sorted { $0.value > $1.value }

// MARK: - Markdown report

func mdEscape(_ s: String) -> String {
    return s.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
}

func tsFormat(_ s: Double) -> String {
    let m = Int(s) / 60
    let sec = s - Double(m * 60)
    return String(format: "%d:%05.2f", m, sec)
}

var md = ""
md += "# SFlow Video Eval — LLM analysis\n\n"
let runDate = ISO8601DateFormatter().string(from: Date())
md += "- Generated: `\(runDate)`\n"
md += "- Frames dir: `\(framesDir)`\n"
md += "- Frames analyzed: **\(finals.count)** (interval \(intervalSec)s, ~\(String(format: "%.1f", Double(finals.count) * intervalSec))s of video)\n"
md += "- Model: `\(model)`\n"
md += "- Toast visible in: **\(toastFrames)** frames (\(finals.count > 0 ? toastFrames * 100 / finals.count : 0)%)\n"
md += "- Native tooltip visible in: **\(tipFrames)** frames\n"
md += "- Errors: \(errFrames)\n\n"

md += "## Toast hits summary (most frequent first)\n\n"
if topToasts.isEmpty {
    md += "_No SFlow toasts detected._\n\n"
} else {
    md += "| Count | App | Action | Keys |\n"
    md += "|---|---|---|---|\n"
    for (hit, cnt) in topToasts {
        md += "| \(cnt) | \(mdEscape(hit.app)) | \(mdEscape(hit.action)) | `\(mdEscape(hit.keys))` |\n"
    }
    md += "\n"
}

md += "## Native tooltip hits\n\n"
if topTips.isEmpty {
    md += "_No native tooltips detected._\n\n"
} else {
    md += "| Count | App | Tooltip |\n"
    md += "|---|---|---|\n"
    for (hit, cnt) in topTips {
        md += "| \(cnt) | \(mdEscape(hit.app)) | \(mdEscape(hit.text)) |\n"
    }
    md += "\n"
}

md += "## Timeline (consecutive identical states collapsed)\n\n"
md += "| Start | End | Frames | App | Toast | Cursor | Tooltip |\n"
md += "|---|---|---|---|---|---|---|\n"
for s in spans {
    let sample = s.sample
    let toastCell: String = sample.toastVisible
        ? "**\(mdEscape(sample.toastAction ?? "?"))** `\(mdEscape(sample.toastKeys ?? "?"))`"
        : "—"
    let tipCell: String = sample.nativeTooltipVisible
        ? mdEscape(sample.nativeTooltipText ?? "?")
        : "—"
    let cur = sample.cursorAction.map(mdEscape) ?? "—"
    let appCell = sample.appName.map(mdEscape) ?? "—"
    let frames = s.endIndex == s.startIndex ? "\(s.startIndex)" : "\(s.startIndex)-\(s.endIndex)"
    md += "| \(tsFormat(s.startTs)) | \(tsFormat(s.endTs)) | \(frames) | \(appCell) | \(toastCell) | \(cur) | \(tipCell) |\n"
}
md += "\n"

if errFrames > 0 {
    md += "## Errors\n\n"
    for r in finals where r.error != nil {
        md += "- `\(r.name)` (t=\(tsFormat(r.timestampSec))): \(r.error!)\n"
    }
    md += "\n"
}

md += "## Next steps (suggested workflow)\n\n"
md += "1. Open this report side-by-side with `SFlow/Resources/bundled.json` and `cache/*.json`.\n"
md += "2. For each **toast hit** in the summary, find the matching rule in bundled. Confirm keys agree.\n"
md += "3. For each **native tooltip** with shortcut keys, check whether SFlow ever fired a toast for the same cursorAction. If not — that's a coverage hole; consider seeding/refreshing the app.\n"
md += "4. If toast keys disagree with bundled/tooltip — that's a wrong-toast; log as a regression and pick the offending app for re-seed (`./scripts/sflow-reseed <bundleId>`).\n"
md += "5. Append findings to `docs/coverage-report.md` (per-app row) and to the next session log entry.\n"

let outputURL = URL(fileURLWithPath: outputMd)
do {
    try md.write(to: outputURL, atomically: true, encoding: .utf8)
    fputs("sflow-video-llm: wrote report → \(outputMd)\n", stderr)
} catch {
    fputs("error: cannot write report: \(error.localizedDescription)\n", stderr)
    exit(5)
}

print(outputMd)
