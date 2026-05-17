import Foundation

/// Identifies which recognition layer produced a shortcut event.
/// Used for per-layer hit-rate telemetry (Phase 1.5 of roadmap).
enum RecognitionLayer: String {
    case axKeyShortcuts = "L0"     // AXKeyShortcutsValue attribute
    case tooltipObserver = "L0.3"  // DiscoveredStore — tooltip seen by hovering
    case ruleCache      = "L0.5"   // bundled.json / cache / user overrides
    case inlineShortcut = "L0.6"   // (name, badge) pair in element's own children
                                    // (Notion sidebar "New chat ⌘O" pattern)
    case shortcutRules  = "L1"     // hardcoded ShortcutRules.rules
    case axHelp         = "L2"     // kAXHelpAttribute auto-parse
    case menuBarIndex   = "L3"     // MenuBarIndex fuzzy lookup
    case universal      = "L4"     // ShortcutRules.universalRules
    case menuItem       = "menu"   // direct menu bar item click
    case menuItemFallback = "menu-fallback" // checkMenuBar non-AXMenuItem path
}

struct ShortcutEvent {
    let bundleId: String
    let shortcutId: String
    let keys: [String]
    let hint: String
    let mouseX: Double
    let mouseY: Double
    let layer: RecognitionLayer
}
