import Foundation

enum RuleStorage {
    static func userRulesDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("SFlow/rules", isDirectory: true)
    }

    static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Copies the bundled.json shipped inside the app bundle into the user's rules dir on first launch.
    /// Returns true if the file was just copied.
    @discardableResult
    static func seedBundledIfMissing() throws -> Bool {
        let userDir = userRulesDirectory()
        try ensureDirectory(userDir)
        try ensureDirectory(userDir.appendingPathComponent("cache"))

        let dest = userDir.appendingPathComponent("bundled.json")
        if FileManager.default.fileExists(atPath: dest.path) { return false }

        guard let src = Bundle.main.url(forResource: "bundled", withExtension: "json") else {
            return false
        }
        try FileManager.default.copyItem(at: src, to: dest)
        return true
    }
}
