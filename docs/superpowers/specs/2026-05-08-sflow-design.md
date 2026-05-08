# SFlow — Design Spec
_Data: 2026-05-08_

## Cel produktu

Standalone macOS app (menu bar agent) która wykrywa gdy użytkownik klika myszką w elementy UI innych aplikacji, które mają przypisany skrót klawiszowy, i pokazuje 3-sekundowy toast obok kursora z tym skrótem.

Cel edukacyjny: użytkownik stopniowo uczy się skrótów w kontekście swojej normalnej pracy, bez dodatkowego wysiłku.

---

## Tech Stack

- **Język:** Swift (pure Swift, bez Electron, bez zależności zewnętrznych)
- **UI:** AppKit (NSPanel dla toastów, NSStatusItem dla menu bar)
- **Kompilacja:** Swift Package / Xcode project → standalone `.app`
- **macOS:** 13.0+ (Ventura)

Uzasadnienie: CGEventTap, AXUIElement, NSPanel to natywne macOS API — Swift ma do nich bezpośredni dostęp bez pośredników. Jeden proces, zero IPC.

Migracja do Electron w przyszłości: ClickWatcher.swift staje się sidecar — bez zmian w logice.

---

## Struktura plików

```
SFlow/
  main.swift          — AppDelegate, NSStatusItem, toggle enabled/disabled
  ClickWatcher.swift  — CGEventTap, AX query, orchestracja
  ShortcutRules.swift — baza reguł dla 18 apek + AX Help auto-parser
  ToastWindow.swift   — NSPanel, pozycjonowanie, fade animacja
  EventLogger.swift   — zapis zdarzeń do events.jsonl
```

---

## Przepływ danych

```
[macOS system]
     │  leftMouseDown event
     ▼
ClickWatcher
  CGEventTap (listenOnly, cgAnnotatedSessionEventTap)
     │
     ▼
  1. Sprawdź czy frontmost app jest na watch-liście
  2. AXUIElementCopyElementAtPosition(appElement, x, y)
  3. Idź po przodkach (max 6 poziomów):
     a. matchElement() vs ShortcutRules bazy → wynik
     b. parseShortcutFromText(kAXHelpAttribute) → auto-parse
  4. Jeśli brak wyniku → checkMenuBarClick():
     AXUIElementCreateSystemWide() → szuka AXMenuItem
     → kAXMenuItemCmdChar + kAXMenuItemCmdModifiers
     │
     ▼
  Wynik: (keys, hint, shortcutId) lub nil
     │
     ├─→ ToastWindow  (pokazuje toast)
     └─→ EventLogger  (dopisuje do events.jsonl)
```

**Rate limiting:** ten sam `shortcutId` ignorowany przez 2 sekundy po pokazaniu toastu.

---

## Wykrywanie skrótów — dwie warstwy

### Warstwa 1: Hardcoded rules (ShortcutRules.swift)

Baza reguł dla 18 aplikacji (łącznie ~181 reguł):

| Apka | Bundle ID | Przykładowe skróty |
|------|-----------|-------------------|
| Slack | com.tinyspeck.slackmacgap | ⌘K, ⌘N, ⌘⇧K |
| Notion | notion.id | ⌘K, ⌘N, ⌘\ |
| Figma | com.figma.Desktop | ⌘/, ⌘⌥1 |
| VS Code | com.microsoft.VSCode | ⌘⇧P, ⌘P, ⌘⇧F |
| Linear | com.linear | ⌘K, ⌘I |
| Claude | com.anthropic.claudefordesktop | ⌘↵, ⌘⇧O |
| WhatsApp | net.whatsapp.WhatsApp | ⌘↵, ⌘N |
| Comet | ai.perplexity.comet | ⌘L, ⌘T, ⌘R |
| Chrome | com.google.Chrome | ⌘L, ⌘T |
| Arc | company.thebrowser.Browser | ⌘L, ⌘T |
| Mail | com.apple.mail | ⌘N, ⌘R, ⌘⇧F |
| Safari | com.apple.Safari | ⌘L, ⌘T, ⌘R |
| Xcode | com.apple.dt.Xcode | ⌘F, ⌘1 |
| Terminal | com.apple.Terminal | ⌘F, ⌘T |
| Finder | com.apple.finder | ⌘F, ⌘[, ⌘] |
| Notion Calendar | com.cron.electron | ⌘K, T, C |
| Notion Mail | notion.mail.id | C, E, ⌘↵ |
| Spotify | com.spotify.client | ⌘L, Space |

Każda reguła dopasowuje element przez: `role`, `subroleEquals`, `descContains`, `titleContains`, `placeholderContains`, `helpContains`.

### Warstwa 2: AX Help auto-parser

Dla dowolnej apki (nie tylko z bazy): jeśli `kAXHelpAttribute` tooltipa zawiera symbole modifierów (⌘⇧⌥⌃) + literę — wyciąga skrót automatycznie.

Przykład: tooltip `"Quick Switcher ⌘K"` → keys: `["meta", "k"]`.

### Warstwa 3: Menu bar auto-detection

Gdy klik trafi w element menu bar (AXMenuItem):
- czyta `kAXMenuItemCmdChar` + `kAXMenuItemCmdModifiers`
- działa dla każdej apki macOS z natywnym menu
- nie wymaga reguł

---

## Toast UI

```
╭─────────────────────────╮
│  ⌘K  Quick Switcher     │
╰─────────────────────────╯
```

- **Tło:** `NSColor.windowBackgroundColor` opacity 0.95 (auto dark/light mode)
- **Skrót:** SF Mono 13pt bold (⌘, ⇧, ⌥, ⌃ jako symbole Unicode)
- **Hint:** SF Pro 12pt, secondary label color
- **Corner radius:** 8px
- **Shadow:** system shadow
- **Szerokość:** dynamiczna (min 120px)
- **Pozycja:** punkt kliknięcia + (16px prawo, -8px góra)
- **Animacja:** fade-in 0.15s → widoczny 2.7s → fade-out 0.15s → usunięty z pamięci
- **Czas życia:** 3 sekundy łącznie

Konwersja klawiszy:
```
meta  → ⌘   shift → ⇧   alt → ⌥   ctrl → ⌃
```

---

## Menu bar

```
[⌘] SFlow
    ─────────────
    ✓ Enabled        ← toggle, checkmark gdy aktywne
    ─────────────
    Quit SFlow
```

- Ikonka: SF Symbol `keyboard` lub `command` (template image — auto dark/light)
- Gdy disabled: ikonka blednie (alpha 0.4)
- Stan persystowany w `UserDefaults`

---

## Event logging

**Plik:** `~/Library/Application Support/SFlow/events.jsonl`

Format JSONL (JSON Lines) — każde zdarzenie to jedna linia:

```json
{"timestamp":"2026-05-08T14:32:11Z","bundleId":"com.tinyspeck.slackmacgap","shortcutId":"slack-quick-switcher","keys":["meta","k"],"hint":"Quick Switcher","mouseX":432.0,"mouseY":218.0}
```

Pola:
- `timestamp` — ISO 8601 UTC
- `bundleId` — bundle ID aplikacji
- `shortcutId` — unikalny ID akcji (np. `"slack-quick-switcher"`, `"auto:bundleId:meta+k"`)
- `keys` — tablica klawiszy
- `hint` — nazwa akcji
- `mouseX`, `mouseY` — pozycja kliknięcia w AppKit coordinates

Zapis: `append` — dopisuje linię, nigdy nie nadpisuje całego pliku.

---

## Uprawnienia macOS

Przy pierwszym uruchomieniu apka sprawdza dwa uprawnienia:

1. **Accessibility** (`kAXTrustedCheckOptionPrompt`) — do czytania AXUIElement
2. **Input Monitoring** — do CGEventTap

Jeśli brak → `NSAlert` z przyciskiem "Open System Settings" → otwiera odpowiednią sekcję ustawień.

Sprawdzane przy starcie i po powrocie apki na pierwszy plan.

---

## Poza zakresem (v1)

- Okno statystyk / historia kliknięć
- Konfiguracja własnych reguł przez użytkownika
- Integracja z Chrome extension
- Auto-start przy logowaniu (można dodać ręcznie w System Settings)
- Onboarding screen
