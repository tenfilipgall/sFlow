import Foundation
import AppKit

/// Creates a .zip bundle with local SFlow telemetry for beta-tester export.
///
/// Bundle contents:
///   - events.jsonl              — toast + miss + (silent) events
///   - false_positives.jsonl     — user cmd-clicks (when not silent)
///   - attempted.json            — discovery retry state per app
///   - discovered/*.jsonl        — tooltip discovery dumps (Sesja B)
///   - system-info.txt           — macOS version, locale, hostname, screen count
///
/// **Privacy guarantees:**
///   - events.jsonl is already PII-redacted at write-time (PrivacyFilter)
///   - system-info contains NO usernames, NO IPs, NO apps list
///   - User picks save location (NSSavePanel) — nothing uploaded automatically
///
/// Use case: beta tester runs SFlow 2-3 days in silent mode, clicks
/// "Export diagnostic bundle" in Settings → Advanced, DMs zip to Filip.
enum DiagnosticBundleExporter {
    /// Returns the directory holding SFlow's runtime data
    /// (`~/Library/Application Support/SFlow/`).
    static var dataDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SFlow")
    }

    /// Builds the bundle into a temporary directory and returns the
    /// final .zip URL. Throws on file IO / zip errors.
    static func buildBundle() throws -> URL {
        let fm = FileManager.default
        let tmpRoot = fm.temporaryDirectory.appendingPathComponent("sflow-bundle-\(UUID().uuidString)")
        try fm.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpRoot) }

        let timestamp = makeTimestamp()
        let bundleDirName = "sflow-diagnostic-\(timestamp)"
        let staging = tmpRoot.appendingPathComponent(bundleDirName)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)

        let src = dataDirectory

        // Copy single-file artifacts if present
        for filename in ["events.jsonl", "false_positives.jsonl", "attempted.json"] {
            let from = src.appendingPathComponent(filename)
            let to = staging.appendingPathComponent(filename)
            if fm.fileExists(atPath: from.path) {
                try? fm.copyItem(at: from, to: to)
            }
        }

        // Copy discovered/ directory if present
        let discoveredSrc = src.appendingPathComponent("discovered")
        let discoveredDst = staging.appendingPathComponent("discovered")
        if fm.fileExists(atPath: discoveredSrc.path) {
            try? fm.copyItem(at: discoveredSrc, to: discoveredDst)
        }

        // Write system info (NO sensitive fields)
        let systemInfo = makeSystemInfo()
        try systemInfo
            .data(using: .utf8)?
            .write(to: staging.appendingPathComponent("system-info.txt"))

        // Build .zip in tmp via /usr/bin/zip (system binary, always available)
        let zipURL = fm.temporaryDirectory.appendingPathComponent("\(bundleDirName).zip")
        try? fm.removeItem(at: zipURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = tmpRoot
        process.arguments = ["-r", zipURL.path, bundleDirName]
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let errOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(),
                                   encoding: .utf8) ?? "unknown error"
            throw DiagnosticBundleError.zipFailed(errOutput)
        }
        return zipURL
    }

    /// Opens a save panel, builds bundle, copies to user-chosen path,
    /// reveals in Finder. Shows alert on error. Main-actor only.
    @MainActor
    static func exportInteractive() {
        do {
            let zipURL = try buildBundle()
            let panel = NSSavePanel()
            panel.title = "Save SFlow diagnostic bundle"
            panel.nameFieldStringValue = zipURL.lastPathComponent
            panel.allowedContentTypes = []
            panel.directoryURL = FileManager.default.urls(for: .desktopDirectory,
                                                          in: .userDomainMask).first
            let response = panel.runModal()
            guard response == .OK, let dest = panel.url else {
                try? FileManager.default.removeItem(at: zipURL)
                return
            }
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: zipURL, to: dest)
            NSWorkspace.shared.activateFileViewerSelecting([dest])
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not export diagnostic bundle"
            alert.informativeText = "\(error)"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    // MARK: - Helpers

    static func makeTimestamp(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    static func makeSystemInfo() -> String {
        let info = ProcessInfo.processInfo
        let osVersion = info.operatingSystemVersion
        let osString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        let locale = Locale.current.identifier
        let screenCount = NSScreen.screens.count
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let exportedAt = ISO8601DateFormatter().string(from: Date())

        return """
        SFlow diagnostic bundle
        =======================

        Exported at:    \(exportedAt)
        SFlow version:  \(appVersion) (build \(buildNumber))
        macOS version:  \(osString)
        Locale:         \(locale)
        Screen count:   \(screenCount)

        Notes:
        - events.jsonl is PII-redacted at write time (see PrivacyFilter.swift)
        - No usernames, IPs, app inventory, or any cloud upload was performed
        - All data above is for offline diagnosis only
        """
    }
}

enum DiagnosticBundleError: Error, CustomStringConvertible {
    case zipFailed(String)

    var description: String {
        switch self {
        case .zipFailed(let stderr):
            return "zip command failed: \(stderr)"
        }
    }
}
