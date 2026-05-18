import ApplicationServices
import Foundation

/// L0.7 — Standard macOS shortcuts that apply across (almost) every Mac app.
///
/// This layer lives *alongside* the per-app rule cache. The flow:
///   1. `RuleCache.match(bundleId: …)` runs first (per-app, today's L0.5).
///   2. Only when L0.5 misses does ClickWatcher consult this resolver.
///   3. App-specific rules therefore always win — this layer never overrides
///      anything in `bundled.json`, cache, or `user_overrides.json`.
///
/// Two backends:
///   - Backend A: AX subrole map (window-chrome traffic lights). Locale-agnostic
///     because subroles are stable across languages.
///   - Backend B: title-based lookup against `Resources/macosSystemShortcuts.json`
///     using the existing `LoadedRule` title-match logic in `RuleCache`.
enum SystemShortcuts {

    /// Subrole → (keys, hint). Stable across locales because subroles are
    /// returned by AppKit itself in fixed identifier form.
    ///
    /// Returns nil for `AXZoomButton` — macOS doesn't ship a default keyboard
    /// shortcut for it. We could surface "Ctrl+Cmd+F" (Enter Full Screen) but
    /// that's a different action; better to stay silent than mislead.
    static func matchSubrole(_ subrole: String) -> (keys: [String], hint: String)? {
        switch subrole {
        case "AXCloseButton":      return (["meta", "w"], "Close")
        case "AXMinimizeButton":   return (["meta", "m"], "Minimize")
        case "AXFullScreenButton": return (["ctrl", "meta", "f"], "Toggle Full Screen")
        default: return nil
        }
    }
}
