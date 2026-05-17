# Plan — Sesja U-2: Right-click / context menu monitoring (Sub-cel 1.18 / P-41)

> **Status:** DRAFT detail, ~3h. Drugi w sekwencji ROI (po U-1, 270 score).
>
> **Adresuje:** Sub-cel 1.18, P-41, G-1.
>
> **Pre-requisite:** U-1 (B.1 integracja) zacommitowane.
>
> **Wartość:** pokrycie skrótów z prawego-kliku we **wszystkich** apkach
> naraz, bez per-app pracy. Mechanizm: `kAXMenuItemCmdChar` natywne — zero
> heurystyki.

---

## 1. Mechanizm

### 1.1. Event mask extension

W `ClickWatcher.setup()` linia 28:

```swift
let mask = CGEventMask((1 << CGEventType.leftMouseDown.rawValue) |
                       (1 << CGEventType.rightMouseDown.rawValue))
```

### 1.2. Callback dispatcher

`tapCallback` (linia 551) — zachowaj re-enable check, dodaj rozróżnienie typu:

```swift
if type == .leftMouseDown {
    sharedWatcher?.handleMouseDown(rightClick: false)
} else if type == .rightMouseDown {
    sharedWatcher?.handleMouseDown(rightClick: true)
}
```

### 1.3. handleMouseDown branching

Sygnatura: `func handleMouseDown(rightClick: Bool)`. Dla `rightClick == false` —
istniejący flow. Dla `rightClick == true` — **NEW**:

1. **Nie** odpalaj L0..L4 pipeline (right-click sam nie wywołuje akcji)
2. **Schedule scan po 300ms** dla context menu który się pojawi:
   ```swift
   DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
       self?.scanRightClickContextMenu(bundleId: bundleId)
   }
   ```
3. `scanRightClickContextMenu` walks AX tree szukając `AXMenu` widocznego
   teraz (po right-clicku macOS otwiera natywne AXMenu)

### 1.4. scanRightClickContextMenu — szczegół

```swift
private func scanRightClickContextMenu(bundleId: String) {
    guard let app = NSWorkspace.shared.frontmostApplication else { return }
    let axApp = AXUIElementCreateApplication(app.processIdentifier)

    var windowsRef: AnyObject?
    AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
    let windows = (windowsRef as? [AXUIElement]) ?? []

    // Menu może być na app-level lub jako floating window
    for window in windows {
        if let menu = findOpenMenu(in: window) {
            harvestMenuItems(menu, bundleId: bundleId)
            return
        }
    }
    // Fallback: app-level (niektóre Electron mają tu)
    if let menu = findOpenMenu(in: axApp) {
        harvestMenuItems(menu, bundleId: bundleId)
    }
}

private func findOpenMenu(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    guard depth < 6 else { return nil }
    var roleRef: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
    if (roleRef as? String) == "AXMenu" {
        return element
    }
    var childrenRef: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
    for child in (childrenRef as? [AXUIElement]) ?? [] {
        if let found = findOpenMenu(in: child, depth: depth + 1) {
            return found
        }
    }
    return nil
}

private func harvestMenuItems(_ menu: AXUIElement, bundleId: String) {
    var childrenRef: AnyObject?
    AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &childrenRef)
    for item in (childrenRef as? [AXUIElement]) ?? [] {
        var roleRef: AnyObject?
        AXUIElementCopyAttributeValue(item, kAXRoleAttribute as CFString, &roleRef)
        guard (roleRef as? String) == "AXMenuItem" else { continue }

        var titleRef: AnyObject?; var cmdRef: AnyObject?; var modsRef: AnyObject?
        AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
        AXUIElementCopyAttributeValue(item, kAXMenuItemCmdCharAttribute as CFString, &cmdRef)
        AXUIElementCopyAttributeValue(item, kAXMenuItemCmdModifiersAttribute as CFString, &modsRef)

        guard let title = titleRef as? String, !title.isEmpty,
              let cmdChar = (cmdRef as? String)?.lowercased(), !cmdChar.isEmpty else { continue }

        let rawMods = (modsRef as? Int) ?? 0
        let mods = MenuBarIndex.parseModifiers(rawMods: rawMods)
        let keys = mods + [cmdChar]

        guard let rect = frameOf(item) else { continue }
        DiscoveredStore.shared.record(
            actionName: title,
            keys: keys,
            rect: rect,
            bundleId: bundleId,
            source: "rightclick_menu"  // new field, optional
        )
    }
}
```

### 1.5. Integracja z L0.3

Brak nowej warstwy — wpisy do `DiscoveredStore` automatycznie trafiają do
**istniejącego L0.3 lookup w handleMouseDown line 232**. Po right-clicku
user porusza myszą do pozycji menu (kursor jest nad item-em), klika lewy —
L0.3 hit-test pod kursorem zwraca matching item z `rect`.

**Bonus efekt:** items menu mają persistent rect → jeśli user otworzy to
samo menu ponownie, lookup jest cache'owany. Po kilku otwarciach SFlow zna
context menu danej apki bez dodatkowego scan'u.

---

## 2. TDD plan

### 2.1. Nowy plik testowy: `SFlowTests/RightClickMenuHarvestTests.swift`

```swift
import XCTest
@testable import SFlow

final class RightClickMenuHarvestTests: XCTestCase {

    func test_harvestMenuItems_recordsTitleAndShortcut() {
        // Mock AXMenu z 3 dziećmi AXMenuItem:
        //   - title="Copy", cmdChar="c", mods=0x8 (cmd)
        //   - title="Paste", cmdChar="v", mods=0x8
        //   - title="Open in New Tab", cmdChar="t", mods=0x9 (cmd+shift)
        // Wywołaj harvestMenuItems
        // Asercje: DiscoveredStore zawiera 3 entries z odpowiednimi keys
    }

    func test_harvestMenuItems_skipsItemsWithoutCmdChar() {
        // Mock AXMenu z item bez cmdChar (np. separator "—" lub submenu →)
        // Asercja: skipped
    }

    func test_findOpenMenu_findsNestedMenu() {
        // Mock window → child AXGroup → child AXMenu
        // Asercja: znajduje AXMenu w depth=2
    }

    func test_findOpenMenu_returnsNilForNoMenu() {
        // Mock window bez żadnego AXMenu w drzewie
        // Asercja: nil
    }

    func test_harvestMenuItems_supportsSubmenus() {
        // Mock AXMenu z child AXMenuItem który ma sub-AXMenu
        // Submenu items też harvest'owane
        // Asercja: wszystkie items z drzewa
    }
}
```

### 2.2. Test integracyjny

`ClickWatcherRightClickIntegrationTests.swift` — full pipeline z mock CGEvent
right-clicku.

---

## 3. Edge cases

### 3.1. Sub-menu (submenu chevron ▶)

Item "Open With" w Finderze ma submenu. AXMenuItem ma dziecko AXMenu które
otwiera się **dopiero po hover**.

**Decyzja:** scan tylko **bieżący menu level** w U-2. Submenu odkładamy
na U-2.5 albo po-eval (mała wartość, rzadko skróty).

### 3.2. Chromium context menu vs natywne

Chromium browsers (Comet, Chrome) **NIE renderują** natywnego macOS context
menu domyślnie — używają własnego custom menu w Chromium UI. Te **nie**
mają `kAXMenuItemCmdChar`.

**Mitigacja:**
- Etap 1: U-2 łapie natywne (Finder, Notion, większość)
- Etap 2: dla Chromium right-click — odpalamy ten sam mechanizm co
  TooltipObserver (skanuje AXMenuItem children, parsuje trailing-letter
  z title — np. "Mark unread U")

Drugi etap = część Sesji C.5 (P-38). Robi się **razem** dobrze.

### 3.3. Bottom-right rendering — overflow

Context menu na krawędzi ekranu macOS auto-flips. Rect items może być
poza primary screen frame. Hit-test L0.3 nie znajdzie ich → toast nie
wystrzeli mimo poprawnego harvest.

**Mitigacja:** sprawdź że `DiscoveredStore.record` clamp'uje rect do
visible frame i lookup tolerance ±6px działa dla overflowed menus.

### 3.4. Menu znika za szybko

User right-click → 300ms później scan, ale jeśli user już zamknął menu
(np. clicked away) — AXMenu nie istnieje. Scan zwraca nil silently. OK.

### 3.5. Right-click w background app

User right-click w Finder gdy Slack jest focused (przez przejęcie focusa).
`NSWorkspace.frontmostApplication` może mieć opóźnienie.

**Mitigacja:** poll przez 100ms × 5 prób żeby dać macOS czas na switch.
Albo cache `frontmostApplication` w moment rightMouseDown event.

---

## 4. Acceptance criteria

- [ ] 5+ testów w `RightClickMenuHarvestTests`
- [ ] 2 testy integracyjne w `ClickWatcherRightClickIntegrationTests`
- [ ] Manual test: prawy-klik w Finder na pliku → "Open With..." → kliknij
      → toast pokazuje skrót (jeśli Finder ma)
- [ ] Manual test: prawy-klik w Notion na bloku → "Duplicate" → toast ⌘D
- [ ] Manual test: prawy-klik w Pages na tekście → "Copy" → toast ⌘C
- [ ] Manual test (negative): prawy-klik w Blender viewport → nic się nie
      dzieje (Blender custom render, brak AXMenu)
- [ ] 295+ testów passing
- [ ] Zero regresji w lewym kliknięciu (sample 50 left-clicks daje ten sam
      wynik co przed U-2)
- [ ] `events.jsonl` zawiera entries z `source="rightclick_menu"` po użyciu

---

## 5. Plik manifest

**Nowe pliki:**
- `SFlowTests/RightClickMenuHarvestTests.swift` (~150 LOC, 5 testów)
- `SFlowTests/ClickWatcherRightClickIntegrationTests.swift` (~100 LOC,
  2 testy)

**Zmienione pliki:**
- `SFlow/ClickWatcher.swift` — event mask + dispatcher + handleMouseDown
  signature + new helpers `scanRightClickContextMenu`/`findOpenMenu`/`harvestMenuItems`/`frameOf`
- `SFlow/DiscoveredStore.swift` — `record(...source:)` opcjonalne pole
- `SFlow/MenuBarIndex.swift` — `parseModifiers(rawMods:)` jeśli jeszcze
  nie public (sprawdzić — używa `checkMenuBar`)

**Zmienione pliki testów:**
- `SFlowTests/DiscoveredStoreTests.swift` — dodać test "record with source field"

---

## 6. Statusy po sesji

- `audit-phase-0.md`: P-41 ⬜ → 🟢
- `audit-phase-1.5.md`: Sub-cel 1.18 ⬜ → 🟢, sesja U-2 → 🟢
- `coverage-report.md`: aktualizuj per app gdzie right-click rules teraz
  wpadają — Finder, Notion main, większość natywnych
- `roadmap.md`: Session log

---

*Plan napisany 2026-05-16 offline. Drugi w sekwencji ROI po U-1.*
