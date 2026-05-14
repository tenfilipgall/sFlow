import Foundation

func keySymbol(_ key: String) -> String {
    switch key {
    case "meta":       return "⌘"
    case "shift":      return "⇧"
    case "alt":        return "⌥"
    case "ctrl":       return "⌃"
    case "arrowleft":  return "←"
    case "arrowright": return "→"
    case "arrowup":    return "↑"
    case "arrowdown":  return "↓"
    case "enter":      return "↵"
    case "space":      return "␣"
    case "escape":     return "⎋"
    case "delete":     return "⌫"
    case "tab":        return "⇥"
    case "capslock":   return "⇪"
    case "[":          return "["
    case "]":          return "]"
    default:           return key.uppercased()
    }
}
