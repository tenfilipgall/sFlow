import SwiftUI
import AppKit

struct AppEntry: Identifiable, Hashable {
    let id: String        // bundleId
    let name: String
    let ruleCount: Int
    let source: Source

    enum Source: String {
        case bundled, learned
    }
}

struct FailedAppEntry: Identifiable, Hashable {
    let id: String        // bundleId
    let name: String
    let reason: DiscoveryFailureReason
    let failureCount: Int
    let lastAttemptAt: Date
    let nextRetryAt: Date
}

@MainActor
final class AppsTabViewModel: ObservableObject {
    @Published var bundled: [AppEntry] = []
    @Published var learned: [AppEntry] = []
    @Published var failed: [FailedAppEntry] = []

    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .sflowDiscoveryStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.refresh() }
        refresh()
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func refresh() {
        let rulesDir = RuleStorage.userRulesDirectory()
        bundled = loadGroupedRules(from: rulesDir.appendingPathComponent("bundled.json"),
                                   source: .bundled)
        learned = loadCacheFiles(in: rulesDir.appendingPathComponent("cache"))
        if let store = AppDelegate.shared?.attemptStore {
            failed = store.allFailures().map { entry in
                FailedAppEntry(
                    id: entry.bundleId,
                    name: appNameFor(bundleId: entry.bundleId),
                    reason: entry.lastReason,
                    failureCount: entry.failureCount,
                    lastAttemptAt: entry.lastAttemptAt,
                    nextRetryAt: entry.nextRetryAt
                )
            }
        } else {
            failed = []
        }
        NSLog("SFlow AppsTab refresh: bundled=\(bundled.count), learned=\(learned.count), failed=\(failed.count), attemptStore=\(AppDelegate.shared?.attemptStore == nil ? "nil" : "set")")
    }

    private func loadGroupedRules(from url: URL, source: AppEntry.Source) -> [AppEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        // bundled.json is written as [StoredRuleSet] by BundledUpdater.
        // Fall back to single StoredRuleSet for resilience.
        let sets: [StoredRuleSet]
        if let arr = try? JSONDecoder().decode([StoredRuleSet].self, from: data) {
            sets = arr
        } else if let single = try? JSONDecoder().decode(StoredRuleSet.self, from: data) {
            sets = [single]
        } else {
            return []
        }
        return sets
            .map { AppEntry(id: $0.bundleId,
                            name: appNameFor(bundleId: $0.bundleId),
                            ruleCount: $0.rules.count,
                            source: source) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadCacheFiles(in dir: URL) -> [AppEntry] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }
        var entries: [AppEntry] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let set = try? JSONDecoder().decode(StoredRuleSet.self, from: data)
            else { continue }
            entries.append(AppEntry(
                id: set.bundleId,
                name: appNameFor(bundleId: set.bundleId),
                ruleCount: set.rules.count,
                source: .learned
            ))
        }
        return entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func appNameFor(bundleId: String) -> String {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first,
           let name = app.localizedName {
            return name
        }
        return bundleId.components(separatedBy: ".").last ?? bundleId
    }
}

struct AppsTab: View {
    @StateObject private var vm = AppsTabViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section(title: "Bundled apps", entries: vm.bundled, status: "🟢")
                section(title: "Learned apps", entries: vm.learned, status: "🟢")
                failedSection()
                HStack(spacing: 12) {
                    Button("Refresh list") { vm.refresh() }
                    Button("Open rules folder") {
                        NSWorkspace.shared.activateFileViewerSelecting(
                            [RuleStorage.userRulesDirectory()]
                        )
                    }
                    Spacer()
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func section(title: String, entries: [AppEntry], status: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            if entries.isEmpty {
                Text("None yet").foregroundColor(.secondary).font(.caption)
            } else {
                ForEach(entries) { entry in
                    HStack {
                        Text(status)
                        Text(entry.name).frame(maxWidth: .infinity, alignment: .leading)
                        Text(entry.source.rawValue).foregroundColor(.secondary).font(.caption)
                        Text("\(entry.ruleCount) rules").foregroundColor(.secondary).font(.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func failedSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Failed apps").font(.headline)
            if vm.failed.isEmpty {
                Text("None — nice").foregroundColor(.secondary).font(.caption)
            } else {
                ForEach(vm.failed) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("❌")
                            Text(entry.name).frame(maxWidth: .infinity, alignment: .leading)
                            Text(entry.reason.displayString)
                                .foregroundColor(.secondary).font(.caption)
                            Button("Try again") {
                                AppDelegate.shared?.discoveryService?
                                    .forceRetry(bundleId: entry.id)
                            }
                        }
                        Text("last: \(format(entry.lastAttemptAt)) · \(entry.failureCount) fails · next auto-retry: \(format(entry.nextRetryAt))")
                            .foregroundColor(.secondary).font(.caption)
                    }
                }
            }
        }
    }

    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
