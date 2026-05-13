import Foundation

enum LoadedConfidence: String, Codable {
    case high
    case medium
    case low
}

enum LoadedSource: String, Codable {
    case menuBar = "menu_bar"
    case webDocsOfficial = "web_docs_official"
    case webDocsThirdParty = "web_docs_third_party"
    case inferredPattern = "inferred_pattern"
}

struct LoadedMatch: Codable {
    let role: String
    let titles: [String]
}

struct LoadedRule: Codable {
    let match: LoadedMatch
    let keys: [String]
    let hint: String
    let confidence: LoadedConfidence
    let source: LoadedSource
    let version: Int

    init(
        match: LoadedMatch,
        keys: [String],
        hint: String,
        confidence: LoadedConfidence,
        source: LoadedSource,
        version: Int = 1
    ) {
        self.match = match
        self.keys = keys
        self.hint = hint
        self.confidence = confidence
        self.source = source
        self.version = version
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.match      = try c.decode(LoadedMatch.self,      forKey: .match)
        self.keys       = try c.decode([String].self,         forKey: .keys)
        self.hint       = try c.decode(String.self,           forKey: .hint)
        self.confidence = try c.decode(LoadedConfidence.self, forKey: .confidence)
        self.source     = try c.decode(LoadedSource.self,     forKey: .source)
        self.version    = try c.decodeIfPresent(Int.self,     forKey: .version) ?? 1
    }
}

/// Wire format: what the backend returns from /v1/discover.
struct BackendRuleSet: Codable {
    let bundleId: String
    let rulesVersion: String
    let rules: [LoadedRule]
}

enum StoredSource: String, Codable {
    case bundled
    case cloud
    case user
}

/// On-disk format under ~/Library/Application Support/SFlow/rules/.
struct StoredRuleSet: Codable {
    let bundleId: String
    let appVersion: String?
    let fetchedAt: String
    let source: StoredSource
    let rulesVersion: String?
    let rules: [LoadedRule]
}
