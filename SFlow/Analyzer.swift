import Foundation

enum Analyzer {
    struct MissEntry: Equatable {
        let role: String
        let title: String
        let count: Int
    }

    struct AppReport: Equatable {
        let bundleId: String
        let missCount: Int
        let topMisses: [MissEntry]
    }

    struct Report: Equatable {
        let totalToasts: Int
        let totalMisses: Int
        let appsRanked: [AppReport]
    }

    struct FalsePosEntry: Equatable {
        let keys: [String]
        let hint: String
        let count: Int
    }

    struct FalsePosAppReport: Equatable {
        let bundleId: String
        let totalReports: Int
        let topEntries: [FalsePosEntry]
    }

    private struct MissKey: Hashable {
        let role: String
        let title: String
    }

    static func aggregate(lines: [String]) -> Report {
        var toastCount = 0
        var missByApp: [String: [MissKey: Int]] = [:]

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            let type = obj["type"] as? String ?? "toast"
            if type == "toast" {
                toastCount += 1
            } else if type == "miss" {
                guard let bundleId = obj["bundleId"] as? String,
                      let role     = obj["role"]     as? String else { continue }
                let title = obj["title"] as? String ?? ""
                let key = MissKey(role: role, title: title)
                missByApp[bundleId, default: [:]][key, default: 0] += 1
            }
        }

        let apps: [AppReport] = missByApp.map { (bundleId, tuples) in
            let total = tuples.values.reduce(0, +)
            let top = tuples
                .map { (key, count) -> MissEntry in
                    return MissEntry(role: key.role, title: key.title, count: count)
                }
                .sorted { $0.count > $1.count }
                .prefix(10)
            return AppReport(bundleId: bundleId, missCount: total, topMisses: Array(top))
        }.sorted { $0.missCount > $1.missCount }

        let totalMisses = apps.reduce(0) { $0 + $1.missCount }
        return Report(totalToasts: toastCount, totalMisses: totalMisses, appsRanked: apps)
    }

    static func aggregateFalsePositives(lines: [String]) -> [FalsePosAppReport] {
        var byApp: [String: [String: (keys: [String], hint: String, count: Int)]] = [:]

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  obj["type"] as? String == "false_positive",
                  let bundleId = obj["bundleId"] as? String,
                  let shortcutId = obj["shortcutId"] as? String,
                  let keys = obj["keys"] as? [String] else { continue }
            let hint = obj["hint"] as? String ?? ""
            if byApp[bundleId] == nil { byApp[bundleId] = [:] }
            let prev = byApp[bundleId]![shortcutId]
            byApp[bundleId]![shortcutId] = (keys: keys, hint: hint, count: (prev?.count ?? 0) + 1)
        }

        return byApp.map { (bundleId, entries) in
            let total = entries.values.reduce(0) { $0 + $1.count }
            let top = entries.values
                .map { FalsePosEntry(keys: $0.keys, hint: $0.hint, count: $0.count) }
                .sorted { $0.count > $1.count }
                .prefix(10)
            return FalsePosAppReport(bundleId: bundleId, totalReports: total, topEntries: Array(top))
        }.sorted { $0.totalReports > $1.totalReports }
    }

    static func format(report: Report, falsePositives: [FalsePosAppReport] = []) -> String {
        var out = "SFlow Miss Analysis\n===================\n\n"
        if report.appsRanked.isEmpty {
            out += "No miss events logged yet. Use SFlow normally and try again.\n"
        } else {
            for app in report.appsRanked {
                out += "\(app.bundleId) \u{2014} \(app.missCount) misses\n"
                for entry in app.topMisses {
                    let titleDisplay = entry.title.isEmpty ? "(no title)" : entry.title
                    let rolePadded = entry.role.padding(toLength: 12, withPad: " ", startingAt: 0)
                    out += String(format: "  %3dx  %@  \"%@\"\n",
                                  entry.count,
                                  rolePadded,
                                  titleDisplay)
                }
                out += "\n"
            }
        }
        out += "Total: \(report.totalMisses) misses, \(report.totalToasts) toasts.\n"

        if !falsePositives.isEmpty {
            out += "\nFalse Positive Reports\n======================\n\n"
            for app in falsePositives {
                out += "\(app.bundleId) \u{2014} \(app.totalReports) reports\n"
                for entry in app.topEntries {
                    let keysStr = entry.keys.joined(separator: "+")
                    out += "  \(entry.count)x  \(keysStr)  \"\(entry.hint)\"\n"
                }
                out += "\n"
            }
        }
        return out
    }

    static func run(logURL: URL = EventLogger.defaultLogURL,
                    falsePosURL: URL = EventLogger.falsePosLogURL) {
        let eventsContent = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        let fpContent = (try? String(contentsOf: falsePosURL, encoding: .utf8)) ?? ""
        let eventLines = eventsContent.components(separatedBy: "\n").filter { !$0.isEmpty }
        let fpLines = fpContent.components(separatedBy: "\n").filter { !$0.isEmpty }

        if eventLines.isEmpty && fpLines.isEmpty {
            print("SFlow: no events file at \(logURL.path) — nothing to analyze yet.")
            return
        }

        let report = aggregate(lines: eventLines)
        let fpReport = aggregateFalsePositives(lines: fpLines)
        print(format(report: report, falsePositives: fpReport))
    }
}
