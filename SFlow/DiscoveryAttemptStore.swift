import Foundation

/// Persisted record of one bundleId's most-recent discovery failure.
struct DiscoveryAttemptEntry: Codable, Equatable {
    let bundleId: String
    let lastAttemptAt: Date
    let failureCount: Int
    let lastReason: DiscoveryFailureReason
    let nextRetryAt: Date
}

/// Tracks per-bundleId discovery failure state with exponential backoff.
///
/// Invariant: entry exists in `attempts` iff `failureCount >= 1`.
/// Success or `forceRetry` removes the entry.
final class DiscoveryAttemptStore {
    private struct FileState: Codable {
        var version: Int
        var attempts: [String: StoredAttempt]
    }

    private struct StoredAttempt: Codable {
        let lastAttemptAt: Date
        let failureCount: Int
        let lastReason: String
        let nextRetryAt: Date
    }

    private let fileURL: URL
    private let clock: () -> Date
    private var attempts: [String: StoredAttempt]
    private let queue = DispatchQueue(label: "com.filip.sflow.attemptStore")

    init(fileURL: URL, clock: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.clock = clock
        self.attempts = Self.load(from: fileURL)
    }

    func canAttempt(bundleId: String) -> Bool {
        queue.sync {
            guard let entry = attempts[bundleId] else { return true }
            return clock() >= entry.nextRetryAt
        }
    }

    func allFailures() -> [DiscoveryAttemptEntry] {
        queue.sync {
            attempts.compactMap { (bundleId, stored) in
                guard let reason = DiscoveryFailureReason(rawValue: stored.lastReason) else {
                    return nil
                }
                return DiscoveryAttemptEntry(
                    bundleId: bundleId,
                    lastAttemptAt: stored.lastAttemptAt,
                    failureCount: stored.failureCount,
                    lastReason: reason,
                    nextRetryAt: stored.nextRetryAt
                )
            }.sorted { $0.bundleId < $1.bundleId }
        }
    }

    // MARK: - Persistence

    private static func load(from url: URL) -> [String: StoredAttempt] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return [:]
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(FileState.self, from: data),
              state.version == 1 else {
            NSLog("SFlow: attempted.json invalid or wrong version — starting empty")
            let backup = url.appendingPathExtension("bak")
            try? FileManager.default.moveItem(at: url, to: backup)
            return [:]
        }
        return state.attempts
    }

    private func save() {
        let state = FileState(version: 1, attempts: attempts)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(state) else {
            NSLog("SFlow: failed to encode attempted.json")
            return
        }
        let tmp = fileURL.appendingPathExtension("tmp")
        do {
            try? FileManager.default.removeItem(at: tmp)
            try data.write(to: tmp)
            try? FileManager.default.removeItem(at: fileURL)
            try FileManager.default.moveItem(at: tmp, to: fileURL)
        } catch {
            NSLog("SFlow: failed to write attempted.json: \(error)")
        }
    }
}
