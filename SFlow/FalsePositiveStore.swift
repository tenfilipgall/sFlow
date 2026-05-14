import Foundation
import Combine

struct ToastRecord: Identifiable {
    let id: String        // == shortcutId
    let bundleId: String
    let keys: [String]
    let hint: String
    var reportCount: Int
    var isDisabled: Bool
}

final class FalsePositiveStore: ObservableObject {
    static let shared = FalsePositiveStore()

    @Published private(set) var recentToasts: [ToastRecord] = []

    private let falsePosURL: URL
    private var disabledIds: Set<String> = []
    private var reportCounts: [String: Int] = [:]
    private weak var client: DiscoveryClient?

    init(falsePosURL: URL = EventLogger.falsePosLogURL) {
        self.falsePosURL = falsePosURL
        loadDisabledFromDisk()
    }

    func setClient(_ client: DiscoveryClient) {
        self.client = client
    }

    func isDisabled(shortcutId: String) -> Bool {
        disabledIds.contains(shortcutId)
    }

    func toastShown(event: ShortcutEvent) {
        if let idx = recentToasts.firstIndex(where: { $0.id == event.shortcutId }) {
            let existing = recentToasts.remove(at: idx)
            recentToasts.insert(existing, at: 0)
        } else {
            let record = ToastRecord(
                id: event.shortcutId, bundleId: event.bundleId,
                keys: event.keys, hint: event.hint,
                reportCount: reportCounts[event.shortcutId] ?? 0,
                isDisabled: disabledIds.contains(event.shortcutId)
            )
            recentToasts.insert(record, at: 0)
            if recentToasts.count > 50 { recentToasts.removeLast() }
        }
    }

    func report(shortcutId: String, bundleId: String, keys: [String], hint: String) {
        reportCounts[shortcutId, default: 0] += 1
        let count = reportCounts[shortcutId]!

        let logEvent = ShortcutEvent(bundleId: bundleId, shortcutId: shortcutId,
                                     keys: keys, hint: hint, mouseX: 0, mouseY: 0)
        EventLogger.logFalsePositive(event: logEvent, to: falsePosURL)

        if let idx = recentToasts.firstIndex(where: { $0.id == shortcutId }) {
            recentToasts[idx].reportCount = count
            if count >= 3 { recentToasts[idx].isDisabled = true }
        }

        if count >= 3 {
            disabledIds.insert(shortcutId)
            // backend POST wired in Task 6
        }
    }

    func report(record: ToastRecord) {
        report(shortcutId: record.id, bundleId: record.bundleId,
               keys: record.keys, hint: record.hint)
    }

    private func loadDisabledFromDisk() {
        guard let content = try? String(contentsOf: falsePosURL, encoding: .utf8) else { return }
        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let shortcutId = obj["shortcutId"] as? String else { continue }
            reportCounts[shortcutId, default: 0] += 1
            if reportCounts[shortcutId]! >= 3 {
                disabledIds.insert(shortcutId)
            }
        }
    }
}
