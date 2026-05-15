import Foundation

struct MissEvent {
    let bundleId: String
    let role: String
    let title: String
    let desc: String
    let help: String
    let identifier: String
    let value: String
    let roleDescription: String
    let customActions: [String]
    let subtreeLabel: String

    init(bundleId: String, role: String, title: String, desc: String, help: String,
         identifier: String = "", value: String = "",
         roleDescription: String = "", customActions: [String] = [],
         subtreeLabel: String = "") {
        self.bundleId = bundleId
        self.role = role
        self.title = title
        self.desc = desc
        self.help = help
        self.identifier = identifier
        self.value = value
        self.roleDescription = roleDescription
        self.customActions = customActions
        self.subtreeLabel = subtreeLabel
    }
}

enum EventLogger {
    static let defaultLogURL: URL = {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("SFlow")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("events.jsonl")
    }()

    static let falsePosLogURL: URL = {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("SFlow")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("false_positives.jsonl")
    }()

    private static let writeQueue = DispatchQueue(label: "com.sflow.eventlog", qos: .utility)

    static func flush() {
        writeQueue.sync {}
    }

    static func log(event: ShortcutEvent) {
        log(event: event, to: defaultLogURL)
    }

    static func log(event: ShortcutEvent, to url: URL) {
        let formatter = ISO8601DateFormatter()
        let entry: [String: Any] = [
            "type":       "toast",
            "timestamp":  formatter.string(from: Date()),
            "bundleId":   event.bundleId,
            "shortcutId": event.shortcutId,
            "keys":       event.keys,
            "hint":       event.hint,
            "mouseX":     event.mouseX,
            "mouseY":     event.mouseY,
            "layer":      event.layer.rawValue,
        ]
        write(entry, to: url)
    }

    static func logMiss(event: MissEvent) {
        guard UserDefaults.standard.object(forKey: "logMisses") as? Bool ?? true else { return }
        logMiss(event: event, to: defaultLogURL)
    }

    static func logMiss(event: MissEvent, to url: URL) {
        let formatter = ISO8601DateFormatter()
        let entry: [String: Any] = [
            "type":            "miss",
            "timestamp":       formatter.string(from: Date()),
            "bundleId":        event.bundleId,
            "role":            event.role,
            "title":           event.title,
            "desc":            event.desc,
            "help":            event.help,
            "identifier":      event.identifier,
            "value":           event.value,
            "roleDescription": event.roleDescription,
            "customActions":   event.customActions,
            "subtreeLabel":    event.subtreeLabel,
        ]
        write(entry, to: url)
    }

    static func logFalsePositive(event: ShortcutEvent) {
        logFalsePositive(event: event, to: falsePosLogURL)
    }

    static func logFalsePositive(event: ShortcutEvent, to url: URL) {
        let formatter = ISO8601DateFormatter()
        let entry: [String: Any] = [
            "type":       "false_positive",
            "timestamp":  formatter.string(from: Date()),
            "bundleId":   event.bundleId,
            "shortcutId": event.shortcutId,
            "keys":       event.keys,
            "hint":       event.hint,
            "layer":      event.layer.rawValue,
        ]
        write(entry, to: url)
    }

    private static func write(_ entry: [String: Any], to url: URL) {
        guard let data = try? JSONSerialization.data(withJSONObject: entry, options: .sortedKeys),
              let line = String(data: data, encoding: .utf8) else { return }
        let lineWithNewline = (line + "\n").data(using: .utf8)!

        writeQueue.async {
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
}
