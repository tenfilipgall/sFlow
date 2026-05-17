# Plan — Sesja C.5: MenuItemObserver (P-38 / Sub-cel 1.17)

> **Status:** DRAFT, do akceptacji Filipa po teście Sesji B na Linear/Discord/
> Slack/Notion main. Decyzja go/no-go zgodnie z `audit-phase-1.md`: jeśli
> dropdowny >20% missów na tych apkach → robimy.
>
> **Czas szacunkowy:** strategia 1 ~3h, strategie 2+3 ~6h dodatkowo. Można
> wykonać w 2 sesjach (najpierw strategia 1, potem 2+3 jeśli dane potwierdzą).
>
> **Adresuje:** P-38 (audit-phase-0.md), Sub-cel 1.17 (audit-phase-1.md).
>
> **Twardych zależności:** żadnych. Działa równolegle z innymi pracami.
>
> **Punkt wejścia danych:** `docs/events-jsonl-analysis-2026-05-16.md` §6 —
> `com.cron.electron` ma 4 missy Week/Month, Comet ma "Mark unread U" jako
> menu item z inline-shortcut suffix. Potwierdza to wartość tej sesji.

---

## 1. Cel sesji

Otworzyć **trzecią ścieżkę discovery** obok menu-bar i tooltip-observera —
**dropdown menu items wewnątrz okna apki**. Konkretnie:

- **Chromium dropdown menu items** z inline-shortcut suffixem w title
  ("Mark unread U", "Reply to thread R", "Forward F")
- **Native macOS dropdown menu items** ze skrótami w `kAXMenuItemCmdChar`/
  `kAXMenuItemCmdModifiers`
- **Notion-style dropdown menu items** z badge'em po prawej ("Day  1 or D",
  "Week  0 or W", "Month  M")

Cel ilościowy: zmniejszyć % missów typu `AXMenuItem` o **co najmniej 80%**
w `events.jsonl` po 1 tygodniu po wdrożeniu.

---

## 2. Architektura — gdzie żyje nowy kod

### 2.1. Nowy plik `SFlow/MenuItemObserver.swift` (~250 LOC)

Działa analogicznie do `TooltipObserver`:
- Timer 200 ms polluje pozycję kursora
- Gdy cursor stabilny ≥150 ms (mniejszy threshold niż tooltip, bo menu się
  pojawia natychmiast po kliku, nie po hover delay)
- Skanuje drzewo AX frontmost app szukając:
  - **AXMenu** (native macOS dropdown)
  - **AXMenuItem** (children AXMenu)
  - Chromium AXMenuItem (też ma rolę `AXMenuItem` ale parent może być AXGroup,
    nie AXMenu — Chromium custom dropdown)
- Dla każdego znalezionego menu item:
  - **Strategia 1 (trailing-letter parser):** czyta title, próbuje regex
    `^(.+?)\s+([A-Z⌘⇧⌥⌃]+[A-Za-z])$` — name + shortcut suffix
  - **Strategia 2 (native AXMenuItemCmdChar):** czyta `kAXMenuItemCmdChar`
    + `kAXMenuItemCmdModifiers` (uint flag bitmask: 0x1=shift, 0x2=ctrl, 0x4=option, 0x8=cmd)
  - **Strategia 3 (pozycyjne 2× AXStaticText):** schodzi w AXMenuItem do
    AXStaticText'ów, łapie pierwszy = name, ostatni = badge; parser badge'a
    delegowany do istniejącego `TooltipShortcutParser`

Zapis do **istniejącego** `DiscoveredStore` (NIE tworzymy nowego store) —
oszczędność kodu, ten sam pipeline lookup-by-position w `ClickWatcher`.
Po prostu nowe źródło wpisów. Rozszerzyć `DiscoveredEntry` o pole
`source: "tooltip" | "menu_item"` jeśli potrzebujemy disambiguation.

### 2.2. Modyfikacje

**`SFlow/AppDelegate.swift`:** start `MenuItemObserver` w `startWatcher()`
obok `TooltipObserver`.

**`SFlow/ClickWatcher.swift`:** **bez zmian** — `DiscoveredStore.shared.lookup(near:)`
już zwraca wszystkie discovered entries niezależnie od source.

**`SFlow/ShortcutEvent.swift`:** dodać `case menuItemObserver = "L0.4"`
(między L0.3 i L0.5 — semantycznie discovered store, ale inny mechanizm).

Albo **zostawić jako L0.3** — jeden layer "discovered store" obejmujący oba
źródła. Decyzja: **zostawić L0.3** dla prostoty, **dodać pole `source` do
ShortcutEvent.metadata** dla debugowania.

### 2.3. Persistencja

`~/Library/Application Support/SFlow/discovered/<bundleId>.jsonl` —
**ten sam plik** co tooltipy z Sesji B. Format JSON:
```json
{"rect":[100,200,40,40],"name":"Mark unread","keys":["u"],"source":"menu_item","ts":"2026-05-16T..."}
```

Pole `source` opcjonalne (default "tooltip" dla backward-compat z istniejącym
plikami). Lookup zwraca **najnowszy** wpis w rect — nie ma znaczenia source.

---

## 3. Test-driven plan (TDD, ~10 testów per strategia)

### Strategia 1: Trailing-letter parser (~3h, ~6 testów)

**Nowy plik testowy:** `SFlowTests/MenuItemTrailingShortcutParserTests.swift`

Tests:
1. `"Mark unread U"` → `("Mark unread", ["u"])`
2. `"Reply to thread R"` → `("Reply to thread", ["r"])`
3. `"Quick Switcher ⌘K"` → `("Quick Switcher", ["meta","k"])`
4. `"Quick Switcher Cmd+K"` → `("Quick Switcher", ["meta","k"])` (alt format)
5. `"Move"` → `nil` (no shortcut)
6. `"Move To Folder"` → `nil` (multi-word, no single-letter suffix)
7. `"Edit message E"` → `("Edit message", ["e"])` (już rozumiane przez
   `stripHotkeySuffix()` w `RuleCache` — sprawdzić czy parser zwraca tę
   samą warstwę abstrakcji)

**Implementacja:** pure function w nowym pliku
`SFlow/MenuItemTrailingShortcutParser.swift` (~80 LOC). Delikatny regex +
modifier-to-key mapping przez istniejący `TooltipShortcutParser.modifierMap`.

**Granica błędu:** parser może zwrócić false-positive na:
- "Tab 1" (przegląda tabs) — "1" jako shortcut? Zależy od kontekstu.
- "Layer 2" w jakiejś grafice apce.
- "Sale 50" w sklepie.

**Mitigacja:** parser zwraca `nil` dla suffix'u który jest **cyfrą bez
modifier'a** (single digit bez ⌘/⇧). Akceptuje tylko literę A-Z (1 znak).
Tworzy się 7. test: `"Tab 1"` → `nil`.

### Strategia 2: Native AXMenuItemCmd attributes (~2h, ~4 testy)

**Nowy plik testowy:** `SFlowTests/MenuItemNativeAXTests.swift`

Tests używają mock `AXUIElement` (zobacz `MenuBarIndexTests.swift` pattern):
1. AXMenuItem z `kAXMenuItemCmdChar="k"` + `kAXMenuItemCmdModifiers=0x8`
   → `("Quick Switcher", ["meta","k"])`
2. AXMenuItem z `kAXMenuItemCmdChar="s"` + `kAXMenuItemCmdModifiers=0x9`
   (shift+cmd) → `("Save As", ["meta","shift","s"])`
3. AXMenuItem bez cmd char → `nil`
4. AXMenuItem z cmd char ale empty title → `nil` (nie zapisujemy bezimiennych)

**Implementacja:** w `MenuItemObserver.swift` dodać `readNativeMenuItemShortcut(_ element:)`
metodę. Wykorzystać znany pattern z `MenuBarWatcher.swift` (już czyta te atrybuty
dla menu bar) — **DRY: wyekstraktować helper do nowego pliku
`SFlow/AXMenuItemReader.swift`**, używany przez i `MenuBarWatcher` i
`MenuItemObserver`.

### Strategia 3: Pozycyjne 2× AXStaticText badge parser (~2h, ~5 testów)

**Nowy plik testowy:** `SFlowTests/MenuItemTwoTextParserTests.swift`

Tests:
1. AXMenuItem z 2 dziećmi AXStaticText: `["Day", "1 or D"]` →
   `("Day", ["d"])` — pierwsza opcja z "or"
2. `["Week", "0 or W"]` → `("Week", ["w"])`
3. `["Month", "M"]` → `("Month", ["m"])`
4. `["Number of days", "▶"]` → `nil` (submenu chevron, nie shortcut)
5. `["View settings", "▶"]` → `nil`

**Implementacja:** parser delegowany do **istniejącego** `TooltipShortcutParser`,
ale z rozszerzeniem o format `"X or Y"` (alternatywne skróty — zwracamy
pierwszą, tę z literą; cyfra "1 or D" → "d" preferowane bo czytelniejsze).

**Schema impact:** `DiscoveredEntry.alternateKeys: [[String]]?` opcjonalne —
zapisujemy obie alternatywy ("1" i "d") jeśli format "X or Y" wykryty.
Lookup zwraca pierwszą; toast pokazuje obie ("1 or D"). Patrz `audit-phase-0.md`
P-38 (3): "schemat `DiscoveredEntry.alternateKeys: [[String]]?` dla formatu
'X or Y'".

---

## 4. Test plan manualny (po implementacji wszystkich 3 strategii)

### 4.1. Apki do przetestowania

- **Notion Calendar (com.cron.electron)**: klik "Week" → dropdown → najedź
  na każdy item → kliknij → toast powinien pokazać "1 or D" itd.
- **Slack**: prawy-klik na wiadomość → dropdown ("Reply", "Forward",
  "Mark unread" — wszystkie z literami) → klik → toast.
- **Notion main**: slash-menu (`/`) w edytorze → pierwsze 5 itemów → klik.
- **Linear**: ⌘K → command palette items → klik.
- **Xcode**: prawy-klik w editor → dropdown ("Cut ⌘X", "Copy ⌘C") → kliknij
  inny niż copy/cut → toast.
- **Chrome / Comet**: prawy-klik na link → "Open in new tab" → toast (jeśli
  ma skrót — Comet używa ⌘kliknij dla tego).

### 4.2. Anti-test (false-positive guard)

- Otwórz **dowolny submenu z chevronem ▶** ("Open recent", "Move To", "Send
  via") — toast **nie powinien się pojawić** (parser musi rozpoznać że "▶"
  to nie shortcut).
- Otwórz dropdown z dynamicznymi itemami (nazwy plików w "Open recent" —
  "MyDoc.txt", "Photo.png") → toast **nie powinien się pojawić** (kropka +
  extension = filename pattern, nie shortcut).

### 4.3. Privacy test

- Otwórz **WhatsApp prawy-klik** na czacie → dropdown z imionami i treściami →
  **nic nie zapisuje się do `discovered/`** (parser odrzuca dynamic content
  z emoji/PII patterns).

---

## 5. Zadania (atomic, kolejność dla TDD)

| # | Zadanie | Plik(i) | Czas |
|---|---|---|---|
| 1 | `MenuItemTrailingShortcutParser` + 7 testów | nowy `.swift` + nowy test | 1h |
| 2 | `AXMenuItemReader` helper (refaktor z `MenuBarWatcher`) | nowy `.swift` | 0.5h |
| 3 | `MenuItemNativeReader` + 4 testy używające helpera | nowy `.swift` + nowy test | 1h |
| 4 | `MenuItemTwoTextParser` + 5 testów | nowy `.swift` + nowy test | 1h |
| 5 | `DiscoveredEntry.alternateKeys` opcjonalne pole + backward-compat decoder | edit `DiscoveredStore.swift` + test | 0.5h |
| 6 | `MenuItemObserver` — timer + skanner łączący 3 strategie | nowy `.swift` (~150 LOC) | 1.5h |
| 7 | `AppDelegate.startWatcher` — start MenuItemObserver | edit `AppDelegate.swift` | 5 min |
| 8 | Privacy filter — odrzucanie filename/PII patterns | edit `MenuItemObserver.swift` + 2 testy | 0.5h |
| 9 | Manual test na 4 apkach (Notion Calendar, Slack, Notion main, Xcode) | — | 30 min |
| 10 | Update statusów + session log + commit | edit docs | 15 min |

**Suma:** ~6h (strategia 1 sama: ~3h jeśli pominąć 3+4+5).

---

## 6. Acceptance criteria

- [ ] 3 nowe testy plików: `MenuItemTrailingShortcutParserTests`,
      `MenuItemNativeAXTests`, `MenuItemTwoTextParserTests` — łącznie ≥16 testów
- [ ] Cron Calendar Week/Month: kliknięcie w dropdown item → toast pokazuje
      poprawny shortcut
- [ ] Slack context menu Reply/Forward/Mark unread: klik → toast
- [ ] WhatsApp prawy-klik na czacie: **brak** entries w `discovered/net.whatsapp.WhatsApp.jsonl`
- [ ] `events.jsonl` po 1 tygodniu: missy `AXMenuItem` < 1/dzień (vs aktualnie
      ~3/10h)
- [ ] Wszystkie 256+ poprzednich testów dalej passing
- [ ] Zero regresji w Sesjach A/B (Notion Mail tooltips dalej działają)

---

## 7. Statusy do zaktualizowania po sesji

- `audit-phase-0.md`: P-38 ⬜ → 🟢 (jeśli wszystkie 3 strategie) lub 🔵 partial
  (jeśli tylko strategia 1)
- `audit-phase-1.md`: Sub-cel 1.17 ⬜ → 🟢 / 🔵
- `audit-phase-1.md` Execution sequence: dodać wpis "Sesja C.5 done" w kolumnie
  Status
- `roadmap.md`: dopisać wpis w Session log

---

## 8. Ryzyka i mitigacje

### Ryzyko 1: AXMenu/AXMenuItem znika natychmiast po kliku

Dropdownowe menu w macOS często zamyka się natychmiast po kliknięciu item'a.
**MenuItemObserver scanuje 200 ms tick** — może nie zdążyć zarejestrować.

**Mitigacja:** scanner pollujue **WHILE menu jest widoczne** — wykrywa otwarcie
menu przez sprawdzenie `frontmost app.windows()` count zmienił się (nowe AXWindow
pojawi się dla native menu, lub AXGroup dla Chromium dropdown). Wtedy uruchamia
szybszy poll (50 ms) aż menu się zamknie.

**Alternatywnie:** zamiast scanowania menu, **proaktywnie odkrywamy menu** przez
hook na `AXMenuOpenedNotification` (jeśli istnieje w macOS AX API).

### Ryzyko 2: Slack ma natywne menu ALE z customowym renderowaniem

Slack message context menu wygląda jak macOS native ale może być Electron-rendered.
Sprawdzić empirycznie czy `kAXMenuItemCmdChar` zwraca wartości czy zero.

**Mitigacja:** jeśli zwraca zero → strategia 1 (trailing-letter parser) działa
bo Slack ma format "Mark unread U" w title. Robustness przez OR wszystkich
3 strategii.

### Ryzyko 3: False positives w trailing-letter parser

"Tab 1", "Layer 2", "Slack 5" — wszędzie gdzie cyfra/litera kończy nazwę.

**Mitigacja:** **whitelist apek** dla strategii 1 — tylko aktywuj dla
bundle ID matching pattern `\.electron|\.slack|notion\.` (Chromium-based).
Dla natywnych apek (Xcode, Finder, Mail) używamy WYŁĄCZNIE strategii 2
(AXMenuItemCmdChar — deterministyczna).

### Ryzyko 4: PII w menu items dynamicznych

WhatsApp prawy-klik na czacie zawiera imiona; Finder "Open Recent" zawiera
filenames.

**Mitigacja:** privacy filter w MenuItemObserver — odrzucać:
- Title zawiera `.` (extension)
- Title zawiera emoji
- Title >40 znaków
- Title zawiera dane wrażliwe (regex z `AXSkeletonExtractor.shouldEmit`)

---

## 9. Co NIE robimy w tej sesji

- **Crowdsource backend** dla menu items — to czeka na Sesję C (backend
  `/v1/discovered`). Sesja C.5 zostawia entries tylko lokalnie.
- **Synthetic seed dla menu items** — to Sesja D (`--seed-app`), tylko dla
  team SFlow przed releasem.
- **Schema rules update** w `LoadedMatch` — bo MenuItemObserver pisze do
  `DiscoveredStore`, nie do `rules/cache/*.json`. Zero impactu na backend.

---

## 10. Pre-requisites przed startem sesji

1. Sesja B przetestowana na Linear/Discord/Slack/Notion main (decyzja go/no-go
   wymaga danych z tego testu)
2. `events.jsonl` po 1-2 dniach użycia ma >5 missów typu AXMenuItem (potwierdza
   że problem istnieje empirycznie poza Cron)
3. Filip ma godzinę bez przerwy żeby zrobić TDD wszystkich 3 strategii naraz
   ALBO 3 sesje 1h dla strategii 1, 2, 3 osobno

---

*Plan napisany przez AI 2026-05-16 jako część "co bezpiecznie robić gdy Filip
nie ma czasu". Czeka na review.*
