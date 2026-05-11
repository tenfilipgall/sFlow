import AppKit
import Foundation

enum SeedMode {
    static func run(bundleIdArg: String?) {
        // bundleIdArg is args.last after stripping --seed; if no bundleId was given,
        // args.last == the executable path itself.
        guard let bundleId = bundleIdArg,
              !bundleId.hasPrefix("-"),
              bundleId != CommandLine.arguments.first else {
            FileHandle.standardError.write(Data("usage: SFlow --seed <bundleId>\n".utf8))
            return
        }

        // Find the running app
        let running = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleId }
        guard let app = running else {
            FileHandle.standardError.write(Data("error: app \(bundleId) is not running. Launch it first.\n".utf8))
            return
        }

        let appName = app.localizedName ?? bundleId
        let appVersion = readVersion(app) ?? "unknown"
        let menuBar = MenuBarDumper.dump(for: app)
        let skeleton = AXSkeletonExtractor.extract(for: app)

        FileHandle.standardError.write(Data(
            "Seeding \(appName) (\(bundleId) v\(appVersion)) — \(menuBar.count) menu items, \(skeleton.count) UI items\n".utf8
        ))

        let client = DiscoveryClient(baseURL: DiscoveryClient.productionURL, clientVersion: "seed")
        let semaphore = DispatchSemaphore(value: 0)
        var outcome: Result<BackendRuleSet, Error>!

        Task {
            do {
                let r = try await client.discover(
                    bundleId: bundleId, appName: appName, appVersion: appVersion,
                    menuBar: menuBar, skeleton: skeleton
                )
                outcome = .success(r)
            } catch {
                outcome = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()

        switch outcome! {
        case .success(let rs):
            let stored = StoredRuleSet(
                bundleId: rs.bundleId,
                appVersion: appVersion,
                fetchedAt: ISO8601DateFormatter().string(from: Date()),
                source: .bundled,
                rulesVersion: rs.rulesVersion,
                rules: rs.rules
            )
            do {
                let data = try JSONEncoder().encode(stored)
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data("\n".utf8))
            } catch {
                FileHandle.standardError.write(Data("encode error: \(error)\n".utf8))
            }
        case .failure(let err):
            FileHandle.standardError.write(Data("error: \(err)\n".utf8))
        }
    }

    private static func readVersion(_ app: NSRunningApplication) -> String? {
        guard let url = app.bundleURL else { return nil }
        let dict = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist"))
        return (dict?["CFBundleShortVersionString"] as? String) ?? (dict?["CFBundleVersion"] as? String)
    }
}
