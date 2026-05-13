import AppKit
import Foundation

enum Reseeder {

    static let verifiedApps = [
        "com.tinyspeck.slackmacgap",       // Slack
        "md.obsidian",                      // Obsidian
        "com.linear",                       // Linear
        "com.todesktop.230313mzl4w4u92",    // Cursor
    ]

    enum Mode {
        case all
        case single(String)
    }

    static func run(arguments: [String]) {
        let mode = parseMode(arguments)
        guard preflight() else { exit(1) }

        switch mode {
        case .all:
            for bundleId in verifiedApps {
                reseedOne(bundleId)
            }
        case .single(let bundleId):
            reseedOne(bundleId)
        }
    }

    private static func parseMode(_ arguments: [String]) -> Mode {
        if let idx = arguments.firstIndex(of: "--reseed"),
           idx + 1 < arguments.count {
            return .single(arguments[idx + 1])
        }
        return .all
    }

    private static func preflight() -> Bool {
        let bundle = Bundle.main.bundleIdentifier ?? "com.gocamping.SFlow"
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundle)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if !others.isEmpty {
            let pids = others.map { String($0.processIdentifier) }.joined(separator: ",")
            fputs("Reseeder: another SFlow is running (pid \(pids)). Quit it first.\n", stderr)
            return false
        }
        if !AXIsProcessTrusted() {
            fputs("Reseeder: Accessibility permission not granted. Grant it in System Settings > Privacy & Security > Accessibility.\n", stderr)
            return false
        }
        return true
    }

    private static func reseedOne(_ bundleId: String) {
        // Filled in by Task 12.
        print("Reseeder: reseed \(bundleId) — (not implemented yet)")
    }
}
