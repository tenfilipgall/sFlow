import Foundation

/// Conservative PII detector used at the boundary where SFlow writes to disk
/// or transmits over the wire. Liberal — prefers false positives (over-redacting
/// safe data) over false negatives (leaking sensitive content).
///
/// Used by `EventLogger.logMiss` to redact `desc`/`title`/`value`/`subtreeLabel`
/// before writing to `events.jsonl`. UI labels like "Compose" or "Reply" pass
/// through; emails, contact names with emoji, credit-card patterns, dates,
/// phone numbers and long strings are replaced with `[REDACTED]`.
enum PrivacyFilter {
    static let redactedMarker = "[REDACTED]"

    /// True if the string contains data that should not be logged.
    /// Order: cheapest checks first.
    static func containsPII(_ s: String) -> Bool {
        if s.isEmpty { return false }

        if s.count > 80 { return true }

        if matches(s, #"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}"#) { return true }

        if matches(s, #"\d{4}-\d{2}-\d{2}"#) { return true }

        if matches(s, #"[•*]{2,}\s*\d{2,}"#) { return true }
        if matches(s, #"\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b"#) { return true }

        if matches(s, #"\+?\d{1,3}[\s-]?\d{3}[\s-]?\d{3}[\s-]?\d{2,4}"#) { return true }
        if matches(s, #"\b\d{3}[\s.\-]\d{3}[\s.\-]\d{4}\b"#) { return true }

        if matches(s, #"[$€£¥]\s?\d"#) { return true }

        if hasEmoji(s) { return true }

        return false
    }

    /// Returns the original string if safe, or the redacted marker if PII.
    static func redact(_ s: String) -> String {
        containsPII(s) ? redactedMarker : s
    }

    private static func matches(_ s: String, _ pattern: String) -> Bool {
        s.range(of: pattern, options: .regularExpression) != nil
    }

    private static func hasEmoji(_ s: String) -> Bool {
        for scalar in s.unicodeScalars {
            if scalar.properties.isEmojiPresentation { return true }
            if scalar.value >= 0x1F300 && scalar.value <= 0x1FAFF { return true }
            if scalar.value >= 0x2600 && scalar.value <= 0x27BF { return true }
        }
        return false
    }
}
