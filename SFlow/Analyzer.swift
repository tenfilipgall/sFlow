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

    static func aggregate(lines: [String]) -> Report {
        var toastCount = 0
        var missByApp: [String: [String: Int]] = [:]

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
                let key = "\(role)|\(title)"
                missByApp[bundleId, default: [:]][key, default: 0] += 1
            }
        }

        let apps: [AppReport] = missByApp.map { (bundleId, tuples) in
            let total = tuples.values.reduce(0, +)
            let top = tuples
                .map { (key, count) -> MissEntry in
                    let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
                    return MissEntry(role: parts[0],
                                     title: parts.count > 1 ? parts[1] : "",
                                     count: count)
                }
                .sorted { $0.count > $1.count }
                .prefix(10)
            return AppReport(bundleId: bundleId, missCount: total, topMisses: Array(top))
        }.sorted { $0.missCount > $1.missCount }

        let totalMisses = apps.reduce(0) { $0 + $1.missCount }
        return Report(totalToasts: toastCount, totalMisses: totalMisses, appsRanked: apps)
    }

    static func format(report: Report) -> String {
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
        return out
    }

    static func run(logURL: URL = EventLogger.defaultLogURL) {
        guard let content = try? String(contentsOf: logURL, encoding: .utf8) else {
            print("SFlow: no events file at \(logURL.path) — nothing to analyze yet.")
            return
        }
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        let report = aggregate(lines: lines)
        print(format(report: report))
    }
}
