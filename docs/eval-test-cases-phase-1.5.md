# Eval test cases — Phase 1.5 sub-cele 1.24-1.28

> **Cel:** Konkretne checklisty manual eval dla 5 niepokrytych typów apek.
> Każda apka ma 6-10 actions które Filip ma kliknąć i odnotować wynik.
> Sub-cele: 1.24 (Office), 1.25 (Adobe), 1.26 (Qt/GTK/Tk), 1.27 (Catalyst),
> 1.28 (SwiftUI).
>
> **Format każdej apki:** instrukcja otwarcia + tabela "klik → expected toast"
> + sekcja "co odnotować".
>
> **Pre-requisite:** SFlow działa (po U-1 commit). Apka zainstalowana.
> Sesja 1 raz na apkę, ~15-30 min każda.

---

## Wspólny protokół eval

Dla każdej apki:

1. **Otwórz apkę normalnie** (Spotlight ⌘Space → nazwa → Enter)
2. **Poczekaj 5s** żeby SFlow auto-discovery odpaliła (lub był już cache)
3. **Sprawdź menu bar SFlow:** ikona ma napis "ready" lub liczba reguł
4. **Kliknij każdą akcję z poniższej listy.** Dla każdej zapisz:
   - ✅ **HIT** — toast się pojawił + nazwa skrótu OK
   - ⚠️ **WRONG** — toast pojawił się ale ze złym skrótem
   - ❌ **MISS** — żaden toast (sprawdź `events.jsonl` że klik był zarejestrowany)
   - 🚫 **N/A** — element niedostępny (apka w innym mode itp.)
5. **Po eval** otwórz `~/Library/Application Support/SFlow/events.jsonl` i
   skopiuj wpisy z ostatnich 10 min do `docs/eval-results/{date}-{app}.txt`
6. **Update statusu** w `docs/coverage-report.md` (per apka)

**Typ pokrycia dla każdej apki:**
- 🟢 GOOD — ≥70% HIT
- 🟡 PARTIAL — 40-70% HIT
- 🔴 POOR — <40% HIT (decyzja: reseed / wpisać per-app reguły / odpuścić)

---

## Sub-cel 1.24 — Microsoft Office (~10h całość)

### 1.24.1 — Excel (`com.microsoft.Excel`)

**Otwórz pusty workbook.**

| # | Click | Expected toast |
|---|---|---|
| 1 | "File" menu → "New Workbook" | ⌘N New Workbook |
| 2 | Cell A1, then click name box (formula bar lewo) | Coś o navigacji |
| 3 | Toolbar "Bold" button (B na ribbon) | ⌘B Bold |
| 4 | Toolbar "Save" icon (dyskietka) | ⌘S Save |
| 5 | Ribbon "Insert" tab | Brak skrótu lub ⌃F2 |
| 6 | "Sum" function w funkcjach | ⌃⌥T albo nothing |
| 7 | Cell, kliknij "Fill color" w toolbar | brak skrótu |
| 8 | View → "Freeze Panes" w menu | Coś specific |
| 9 | Sidebar "Sheet1" tab | Brak skrótu |
| 10 | "Find" button w toolbar (⌘F equivalent) | ⌘F Find |

**Co odnotować:**
- Czy ribbon eksponuje `kAXMenuItemCmdChar`? (probe przez Accessibility Inspector)
- Czy menu bar (File/Edit/View) jest pełne czy okrojone?
- Ile reguł Claude wygenerował dla Excel (sprawdź `cache/com.microsoft.Excel.json`)

### 1.24.2 — Word (`com.microsoft.Word`)

Otwórz pusty dokument.

| # | Click | Expected |
|---|---|---|
| 1 | Toolbar "B" (Bold) | ⌘B |
| 2 | Toolbar "Italic" | ⌘I |
| 3 | Toolbar "Underline" | ⌘U |
| 4 | Toolbar "Save" (dyskietka) | ⌘S |
| 5 | Ribbon "Layout" tab | brak |
| 6 | "Format" menu → "Paragraph" | brak / coś |
| 7 | View → "Outline" | coś |
| 8 | "Spell check" button (toolbar) | F7 |
| 9 | "Comments" button | ⌘⌥A |
| 10 | "Track Changes" toggle | ⌘⇧E |

### 1.24.3 — PowerPoint (`com.microsoft.Powerpoint`)

| # | Click | Expected |
|---|---|---|
| 1 | "New Slide" button | ⌘⇧N |
| 2 | Slide sorter view → kliknij slajd | brak |
| 3 | "Bold" toolbar | ⌘B |
| 4 | "Start slideshow" button (Play icon) | ⌘⏎ albo F5 |
| 5 | "Insert Shape" button | brak |
| 6 | Sidebar slide list kliknij | brak |
| 7 | "Slide show" menu | brak |
| 8 | Reaction box do prezenter view | brak |

### 1.24.4 — OneNote (`com.microsoft.onenote.mac`)

Skip dla teraz — niski priority, Microsoft schodzi z platformy.

### 1.24.5 — Outlook (`com.microsoft.Outlook`)

| # | Click | Expected |
|---|---|---|
| 1 | "New Email" button | ⌘N |
| 2 | Inbox → kliknij wiadomość | brak |
| 3 | "Reply" button | ⌘R |
| 4 | "Reply All" button | ⌘⇧R |
| 5 | "Forward" button | ⌘J |
| 6 | "Delete" button | Delete |
| 7 | "Flag" button | ⌘⇧M albo coś |
| 8 | "Mark as Unread" | ⌘U |

**Wniosek po Office 1.24:** sprawdzić czy ribbon ma natywne AX skróty. Jeśli
tak → main L3 menu bar + L0.5 cache po reseedzie powinny dać 70%+. Jeśli ribbon
nie eksponuje AX skrótów → potrzebny **ribbon-specific scanner** (nowy P-X
do dodania).

---

## Sub-cel 1.25 — Adobe Creative Suite (~10h całość)

### 1.25.1 — Photoshop (`com.adobe.Photoshop`)

**Otwórz dowolny obraz.**

| # | Click | Expected |
|---|---|---|
| 1 | Toolbox "Move" tool (strzałka) | V |
| 2 | Toolbox "Brush" tool | B |
| 3 | Toolbox "Eraser" | E |
| 4 | Toolbox "Marquee" (rectangle selection) | M |
| 5 | Toolbox "Lasso" | L |
| 6 | Toolbox "Pen" tool | P |
| 7 | Toolbox "Type" | T |
| 8 | Menu File → New | ⌘N |
| 9 | Menu Edit → Undo | ⌘Z |
| 10 | Menu Layer → New → Layer | ⌘⇧N |

**Krytyczna obserwacja:** Toolbox to **dziewiczy obszar** dla SFlow.
Każde narzędzie to AXButton z literą jako skrót. To wprost test G-8
(tool/mode switching, Sub-cel 1.23).

### 1.25.2 — Illustrator (`com.adobe.illustrator`)

Toolbox podobny do Photoshop, ale inne literki:
- V (Selection), A (Direct Selection), P (Pen), T (Type), R (Rotate),
  S (Scale), W (Blend), B (Brush), N (Pencil)

**Eval:** 10 narzędzi z toolbox + 5 menu actions = jak Photoshop.

### 1.25.3 — Premiere Pro

**Otwórz dowolny project.**

| # | Click | Expected |
|---|---|---|
| 1 | Timeline play button | Spacja |
| 2 | "Razor" tool | C |
| 3 | "Selection" tool | V |
| 4 | "Track Select Forward" | A |
| 5 | "Ripple Edit" | B |
| 6 | "Slip" tool | Y |
| 7 | "Pen" tool | P |
| 8 | "Hand" tool | H |
| 9 | "Zoom" tool | Z |
| 10 | Menu File → Save | ⌘S |

### 1.25.4 — Lightroom / InDesign

Skip dla teraz — Photoshop+Illustrator+Premiere wystarczają jako MVP eval.

**Wniosek po Adobe 1.25:** Adobe ma własny runtime, AX może być bardzo
ograniczone. Hipoteza: menu bar (L3) działa OK, **toolbox toolbar to
luka** wymagająca G-8 (Sub-cel 1.23) zanim eval da rezultaty.

**Strategia:** eval Adobe **po** zaimplementowaniu U-7 (G-8 tool/mode
switching). Inaczej rezultaty będą sztucznie słabe.

---

## Sub-cel 1.26 — Qt/GTK/Tk apek (~6h)

### 1.26.1 — VLC (`org.videolan.vlc`)

**Otwórz dowolny plik wideo.**

| # | Click | Expected |
|---|---|---|
| 1 | Play/Pause button | Spacja |
| 2 | "Next" button | ⌘→ |
| 3 | "Previous" button | ⌘← |
| 4 | "Volume Up" button | ⌘↑ |
| 5 | "Fullscreen" toggle | ⌘F |
| 6 | "Stop" button | ⌘. |
| 7 | Menu File → Open File | ⌘O |
| 8 | "Subtitle Track" dropdown | brak skrótu |

### 1.26.2 — GIMP (`org.gimp.gimp-2.10` lub podobne)

Otwórz dowolny obraz.

| # | Click | Expected |
|---|---|---|
| 1 | Toolbox "Move" | M |
| 2 | Toolbox "Rectangle Select" | R |
| 3 | Toolbox "Brush" | P |
| 4 | Toolbox "Eraser" | ⇧E |
| 5 | Menu File → New | ⌘N |
| 6 | Menu Image → Scale Image | brak |

### 1.26.3 — Blender (`org.blendrfoundation.blender`)

**OSTRZEŻENIE:** Blender renderuje wszystko w OpenGL — AX prawdopodobnie
**nic** nie zobaczy w viewport. Eval głównie sprawdza menu bar + toolbar
górny.

| # | Click | Expected |
|---|---|---|
| 1 | Menu File → New | ⌘N |
| 2 | Menu Edit → Undo | ⌘Z |
| 3 | Top toolbar "Object Mode" dropdown | Tab |
| 4 | Top toolbar "Add" → "Cube" | ⇧A → ... |
| 5 | Viewport — kliknij pusty obszar | **prawdopodobnie zero AX**, klik nie zostanie zarejestrowany |

**Co odnotować:** ile kliknięć w viewport faktycznie pojawiło się w
`events.jsonl`. Hipoteza: 0%. To potwierdza że gry/3D apek są poza
zasięgiem.

### 1.26.4 — OBS, Audacity, RStudio

Skip dla MVP eval. VLC + GIMP + Blender wystarczają jako reprezentanci
3 sub-frameworków (Qt / GTK / OpenGL).

**Wniosek po 1.26:** Qt/GTK/Tk dają **menu bar L3** (działa), ale custom
widget kontent nie. Blender całkowicie zero. **Decyzja:** dla tych apek
nie inwestujemy w per-app rules — universal heuristics + menu bar muszą
wystarczyć.

---

## Sub-cel 1.27 — Catalyst apek (~4h)

### 1.27.1 — News (`com.apple.news`)

| # | Click | Expected |
|---|---|---|
| 1 | "Today" tab | brak |
| 2 | "News+" tab | brak |
| 3 | Article → "Bookmark" button | ⌘D |
| 4 | Article → "Share" button | ⌘⇧I |
| 5 | Menu File → Mark as Read | brak |

### 1.27.2 — Stocks (`com.apple.stocks`)

| # | Click | Expected |
|---|---|---|
| 1 | Watchlist → kliknij stock | brak |
| 2 | "Add to Watchlist" + | brak |
| 3 | Settings gear icon | ⌘, |

### 1.27.3 — Home (`com.apple.Home`)

| # | Click | Expected |
|---|---|---|
| 1 | "Add Accessory" + | brak |
| 2 | Sidebar room → kliknij | brak |
| 3 | Light toggle button | brak (chyba že Home ma jakieś skróty) |

### 1.27.4 — Books, Voice Memos, Find My

Skip — niski priority.

**Wniosek 1.27:** Catalyst apek mają **mało** skrótów przez design
(zaprojektowane dla iPad → touch-first). Coverage prawdopodobnie 30-50%.
Akceptujemy ten poziom — to nie target market.

---

## Sub-cel 1.28 — SwiftUI pure (~2h)

### 1.28.1 — Shortcuts.app (`com.apple.shortcuts`)

| # | Click | Expected |
|---|---|---|
| 1 | "New Shortcut" + button | ⌘N |
| 2 | Sidebar "All Shortcuts" | brak |
| 3 | Shortcut row → kliknij → "Run" play button | ⌘R |
| 4 | "Delete" button na shortcut | Delete |
| 5 | Search field | ⌘F |

### 1.28.2 — Freeform (`com.apple.freeform`)

| # | Click | Expected |
|---|---|---|
| 1 | "New Board" button | ⌘N |
| 2 | Toolbar — "Sticky Note" | ⌥⌘S |
| 3 | Toolbar — "Shape" | ⌥⌘E |
| 4 | "Insert from..." button | brak |

**Wniosek 1.28:** SwiftUI pure apek mogą mieć "value zamiast title" pattern
— sprawdzić w `events.jsonl` czy labelki są w fields które SFlow czyta.
Jeśli nie → potrzebny fix podobny do Sesji A (kAXValue fallback) — ale
on JUŻ działa. Powinno być OK.

---

## Po eval — co dalej

### Output deliverable

Plik `docs/coverage-report.md` — tabela 30+ apek × status pokrycia
(GOOD/PARTIAL/POOR) + 1-zdanio komentarz "co nie działa" gdy POOR.

### Decyzje per apka

| Wynik | Decyzja |
|---|---|
| 🟢 GOOD ≥70% | Apka idzie do bundled.json, **manual review reguł**, promote |
| 🟡 PARTIAL 40-70% | Reseed z nowym prompt (po U-5 i18n + U-2 right-click), retest |
| 🔴 POOR <40% (Adobe, Blender, niektóre Qt) | **Opt-out** — zaznacz w
  `coverage-report.md` jako "not supported", nie zaśmiecaj bundled |

### Aktualizacja Sub-cel 1.6

Po wszystkich eval — Sub-cel 1.6 (20 zweryfikowanych apek) zostanie
zamknięty z **30+ zweryfikowanymi** apkami (Faza 1 baseline + Phase 1.5
eval).

---

*Dokument napisany przez AI 2026-05-16 (offline). Filip wykonuje eval
przy kompie, ~3-10h całość rozproszone w 5 dni.*
