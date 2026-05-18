import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Resolves a locale code (e.g. "pl", "de", "zh-Hans") for the focused app.
///
/// Sub-cel 1.20 / P-43: matching rules must be locale-aware because Slack PL
/// renders "Skomponuj" instead of "Compose" — a rule keyed only on the English
/// title fails. LocaleDetector returns the active locale so RuleCache can
/// consult `localizedTitles[locale]` before falling back to English titles.
///
/// Priority (highest to lowest):
///  1. `AXLanguage` attribute on the AX application element (if exposed)
///  2. `Locale.preferredLanguages.first` (system preference)
///  3. "en" if all else fails
enum LocaleDetector {
    /// Reads `AXLanguage` from the AX application; falls back to system locale.
    /// Tests usually call `normalize` directly — `detect(for:)` only on a live
    /// `AXUIElement`, which is awkward to fake.
    static func detect(for axApp: AnyObject?) -> String {
        if let axApp = axApp,
           let raw = readAXLanguage(axApp),
           !raw.isEmpty {
            return normalize(raw)
        }
        return systemLocale()
    }

    /// Pure helper exposed for tests. Reduces locale code variants to the form
    /// we use as cache key + `localizedTitles` key.
    ///
    /// Rules:
    ///  - `"en-US"` → `"en"` — drop region for Latin-script languages
    ///  - `"pl-PL"` → `"pl"`
    ///  - `"zh-Hans"`, `"zh-Hant"` → kept verbatim — script tag is semantic for CJK
    ///  - `"zh-Hans-CN"` → `"zh-Hans"` — drop region but keep script
    ///  - `"EN"` → `"en"` — case-normalize
    ///  - `""` → `""` — caller decides fallback
    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "" }
        let lower = trimmed.lowercased()
        let parts = lower.split(separator: "-")
        guard let first = parts.first else { return lower }
        // CJK: preserve script tag (Hans/Hant/Hang/Hira/Kana). Drop only region.
        if first == "zh" || first == "yue" {
            if parts.count >= 2 {
                let script = String(parts[1])
                if script == "hans" || script == "hant" {
                    return "\(first)-\(script.prefix(1).uppercased())\(script.dropFirst())"
                }
            }
            return String(first)
        }
        return String(first)
    }

    /// System locale fallback — used when an app doesn't expose `AXLanguage`.
    static func systemLocale() -> String {
        normalize(Locale.preferredLanguages.first ?? "en")
    }

    // MARK: - Private

    private static func readAXLanguage(_ axApp: AnyObject) -> String? {
        #if canImport(AppKit)
        let element = axApp as! AXUIElement
        var ref: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, "AXLanguage" as CFString, &ref)
        guard result == .success else { return nil }
        return ref as? String
        #else
        return nil
        #endif
    }
}
