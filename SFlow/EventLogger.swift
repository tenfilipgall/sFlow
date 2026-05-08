import Foundation

enum EventLogger {
    static let defaultLogURL: URL = {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("SFlow")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("events.jsonl")
    }()

    static func log(event: ShortcutEvent) {
        log(event: event, to: defaultLogURL)
    }

    static func log(event: ShortcutEvent, to url: URL) {
        let formatter = ISO8601DateFormatter()
        let entry: [String: Any] = [
            "timestamp": formatter.string(from: Date()),
            "bundleId":  event.bundleId,
            "shortcutId": event.shortcutId,
            "keys":      event.keys,
            "hint":      event.hint,
            "mouseX":    event.mouseX,
            "mouseY":    event.mouseY,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: entry, options: .sortedKeys),
              let line = String(data: data, encoding: .utf8) else { return }
        let lineWithNewline = (line + "\n").data(using: .utf8)!

        if FileManager.default.fileExists(atPath: url.path) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            handle.seekToEndOfFile()
            handle.write(lineWithNewline)
            try? handle.close()
        } else {
            try? lineWithNewline.write(to: url)
        }
    }
}
