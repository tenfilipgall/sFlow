import Foundation
import CoreGraphics

/// One observed tooltip — the action name + shortcut keys + where the cursor
/// was hovering when we saw it. Used to emit toasts on subsequent clicks when
/// AX exposes no label (Notion Mail icon-only buttons).
struct DiscoveredEntry: Codable {
    let bundleId: String
    let actionName: String
    let keys: [String]
    let identifier: String?
    let rect: CGRectCodable?
    let observedAt: Date

    struct CGRectCodable: Codable {
        let x: Double
        let y: Double
        let w: Double
        let h: Double
        init(_ r: CGRect) {
            x = Double(r.origin.x); y = Double(r.origin.y)
            w = Double(r.size.width); h = Double(r.size.height)
        }
        var cgRect: CGRect { CGRect(x: x, y: y, width: w, height: h) }
    }
}

/// Persists discovered tooltips per app to `~/Library/Application Support/SFlow/discovered/{bundleId}.jsonl`
/// and serves click-time lookups by cursor proximity.
final class DiscoveredStore {
    static let shared = DiscoveredStore(dir: DiscoveredStore.defaultDir())

    private let dir: URL
    private let queue = DispatchQueue(label: "com.sflow.discovered")
    private var entries: [DiscoveredEntry] = []

    init(dir: URL) {
        self.dir = dir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        loadRecent()
    }

    static func defaultDir() -> URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("SFlow/discovered")
    }

    private func fileURL(bundleId: String) -> URL {
        dir.appendingPathComponent("\(bundleId).jsonl")
    }

    /// Append a newly-observed tooltip. De-dupes identical entries from the
    /// last 5 seconds (cursor pause re-scans the same tooltip repeatedly).
    func record(_ entry: DiscoveredEntry) {
        queue.async { [weak self] in
            guard let self else { return }
            if self.isRecentDuplicate(entry) { return }
            self.entries.append(entry)
            if self.entries.count > 2000 {
                self.entries.removeFirst(self.entries.count - 2000)
            }
            self.appendToDisk(entry)
        }
    }

    private func isRecentDuplicate(_ candidate: DiscoveredEntry) -> Bool {
        let cutoff = Date().addingTimeInterval(-5)
        for e in entries.reversed() where e.observedAt >= cutoff {
            if e.bundleId == candidate.bundleId,
               e.actionName == candidate.actionName,
               e.keys == candidate.keys { return true }
        }
        return false
    }

    private func appendToDisk(_ entry: DiscoveredEntry) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entry),
              let line = String(data: data, encoding: .utf8) else { return }
        let payload = (line + "\n").data(using: .utf8) ?? Data()
        let url = fileURL(bundleId: entry.bundleId)
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(payload)
                try? handle.close()
            }
        } else {
            try? payload.write(to: url)
        }
    }

    /// Look up a discovered entry whose stored button-rect contains the
    /// click position (in AX coords). Returns most recent match within `seconds`.
    func lookup(near point: CGPoint, bundleId: String,
                within seconds: TimeInterval = 60) -> DiscoveredEntry? {
        return queue.sync {
            let cutoff = Date().addingTimeInterval(-seconds)
            for entry in entries.reversed() where entry.bundleId == bundleId {
                if entry.observedAt < cutoff { continue }
                if let r = entry.rect?.cgRect, r.insetBy(dx: -6, dy: -6).contains(point) {
                    return entry
                }
            }
            return nil
        }
    }

    /// Returns all entries (for tests / debugging).
    func allEntries() -> [DiscoveredEntry] {
        queue.sync { entries }
    }

    private func loadRecent() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for f in files where f.pathExtension == "jsonl" {
            guard let data = try? Data(contentsOf: f),
                  let str = String(data: data, encoding: .utf8) else { continue }
            let lines = str.split(separator: "\n").suffix(2000)
            for line in lines {
                if let d = String(line).data(using: .utf8),
                   let entry = try? decoder.decode(DiscoveredEntry.self, from: d) {
                    entries.append(entry)
                }
            }
        }
    }
}
