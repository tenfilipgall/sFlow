import Foundation

enum MenuBarCache {
    static let defaultCacheURL: URL = {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("SFlow")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("menu-cache.json")
    }()

    static func load(bundleId: String, version: String) -> [String: MenuBarEntry]? {
        load(bundleId: bundleId, version: version, from: defaultCacheURL)
    }

    static func save(bundleId: String, version: String, entries: [String: MenuBarEntry]) {
        save(bundleId: bundleId, version: version, entries: entries, to: defaultCacheURL)
    }

    static func load(bundleId: String, version: String, from url: URL) -> [String: MenuBarEntry]? {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let appData = root[bundleId] as? [String: Any],
              let cachedVersion = appData["version"] as? String,
              cachedVersion == version,
              let entriesRaw = appData["entries"] as? [String: [String: Any]] else { return nil }

        var result: [String: MenuBarEntry] = [:]
        for (title, raw) in entriesRaw {
            guard let keys = raw["keys"] as? [String],
                  let hint = raw["hint"] as? String else { continue }
            result[title] = MenuBarEntry(keys: keys, hint: hint)
        }
        return result
    }

    static func save(bundleId: String, version: String,
                     entries: [String: MenuBarEntry], to url: URL) {
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = existing
        }
        var entriesRaw: [String: [String: Any]] = [:]
        for (title, entry) in entries {
            entriesRaw[title] = ["keys": entry.keys, "hint": entry.hint]
        }
        root[bundleId] = ["version": version, "entries": entriesRaw]
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: .prettyPrinted) else { return }
        try? data.write(to: url)
    }
}
