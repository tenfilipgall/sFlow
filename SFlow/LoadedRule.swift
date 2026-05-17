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
    let identifiers: [String]?

    init(role: String, titles: [String], identifiers: [String]? = nil) {
        self.role = role
        self.titles = titles
        self.identifiers = identifiers
    }
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

/// Per-app capability flags. Sub-cel 1.21 / U-3 introduces `singleKeyMode`
/// which whitelists apps that legitimately bind single-letter shortcuts
/// (Gmail j/k, Notion Mail C/R/F, Obsidian Vim). Without the flag, Layer 2
/// in ClickWatcher rejects single-char `kAXHelp` values to avoid false
/// positives from incidental single letters in arbitrary text.
struct Features: Codable {
    let singleKeyMode: Bool?

    init(singleKeyMode: Bool? = nil) {
        self.singleKeyMode = singleKeyMode
    }
}

/// On-disk format under ~/Library/Application Support/SFlow/rules/.
struct StoredRuleSet: Codable {
    let bundleId: String
    let appVersion: String?
    let fetchedAt: String
    let source: StoredSource
    let rulesVersion: String?
    let features: Features?
    let rules: [LoadedRule]

    init(bundleId: String, appVersion: String? = nil, fetchedAt: String,
         source: StoredSource, rulesVersion: String? = nil,
         features: Features? = nil, rules: [LoadedRule]) {
        self.bundleId = bundleId
        self.appVersion = appVersion
        self.fetchedAt = fetchedAt
        self.source = source
        self.rulesVersion = rulesVersion
        self.features = features
        self.rules = rules
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleId    = try c.decode(String.self,         forKey: .bundleId)
        self.appVersion  = try c.decodeIfPresent(String.self, forKey: .appVersion)
        self.fetchedAt   = try c.decode(String.self,          forKey: .fetchedAt)
        self.source      = try c.decode(StoredSource.self,    forKey: .source)
        self.rulesVersion = try c.decodeIfPresent(String.self, forKey: .rulesVersion)
        self.features    = try c.decodeIfPresent(Features.self, forKey: .features)
        self.rules       = try c.decode([LoadedRule].self,    forKey: .rules)
    }
}
