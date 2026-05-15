import Foundation

/// Why a single discovery attempt for a bundleId failed.
/// Persisted as `rawValue` in `attempted.json`.
enum DiscoveryFailureReason: String, Codable, CaseIterable {
    case emptySkeleton = "empty_skeleton"
    case emptyMenuBar = "empty_menu_bar"
    case rateLimited = "rate_limited"
    case httpError = "http_error"
    case parseError = "parse_error"
    case noRulesGenerated = "no_rules_generated"

    var displayString: String {
        switch self {
        case .emptySkeleton: return "App not ready yet (empty UI tree)"
        case .emptyMenuBar: return "App has no menu bar"
        case .rateLimited: return "Server: too many requests"
        case .httpError: return "Server error or no internet"
        case .parseError: return "Server returned invalid response"
        case .noRulesGenerated: return "AI returned no rules"
        }
    }

    /// Map a thrown `DiscoveryClientError` to a reason for the store.
    /// `URLError` and other generic Errors map to `.httpError` (network class).
    static func from(error: Error) -> DiscoveryFailureReason {
        if let clientError = error as? DiscoveryClientError {
            switch clientError {
            case .rateLimited: return .rateLimited
            case .malformedResponse: return .parseError
            case .http: return .httpError
            }
        }
        return .httpError
    }
}
