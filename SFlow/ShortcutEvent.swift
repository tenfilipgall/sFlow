import Foundation

struct ShortcutEvent {
    let bundleId: String
    let shortcutId: String
    let keys: [String]
    let hint: String
    let mouseX: Double
    let mouseY: Double
}
