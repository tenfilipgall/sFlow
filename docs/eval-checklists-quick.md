# Eval checklists — quick 5-min version

> **Cel:** uproszczone check listy dla **szybkiego** eval coverage. 5 minut
> per apka zamiast 15-30 min z `eval-test-cases-phase-1.5.md`.
>
> **Kiedy używać:**
> - "Mam 5 minut, sprawdzę czy SFlow działa w X" — quick triage
> - **Przed** głębokim eval — żeby zdecydować czy w ogóle warto inwestować
>   30 min na pełny test cases
>
> **Wynik:** 🟢 GOOD / 🟡 PARTIAL / 🔴 POOR (jeden tag) + 1-zdanio
>   komentarz "co działa/co nie"

---

## Protokół 5-min eval

1. **Otwórz apkę** (2 sek)
2. **Poczekaj 10 sek** (auto-discovery)
3. **Kliknij 5 najczęściej używanych akcji** w tej apce — jak normalnie
4. **Zlicz:** ile pokazało toast?
5. **Wynik:**
   - 5/5 lub 4/5 → 🟢 GOOD
   - 2-3/5 → 🟡 PARTIAL
   - 0-1/5 → 🔴 POOR
6. **Zapisz** w `docs/coverage-report.md`

---

## Quick eval per apka (top-5 actions)

### Code editors

**Cursor** (`com.todesktop.230313mzl4w4u92`)
- File menu (⌘O) / Save (⌘S) / Find (⌘F) / Toggle sidebar (⌘B) / Cmd palette (⌘⇧P)

**VSCode** (`com.microsoft.VSCode`)
- File menu / Save / Find / Toggle sidebar / Cmd palette

**Cursor + VSCode dzielą skróty** — eval razem.

**Xcode** (`com.apple.dt.Xcode`)
- Build (⌘B) / Run (⌘R) / Stop (⌘.) / Find (⌘F) / Open Quickly (⌘⇧O)

### Knowledge/notes

**Notion** (`notion.id`)
- New page / Quick find (⌘K) / Toggle sidebar (⌘\) / Search workspace (⌘P) / Inbox

**Obsidian** (`md.obsidian`)
- New note (⌘N) / Quick switcher (⌘O) / Cmd palette (⌘P) / Toggle sidebar / Search

**Notion Mail** (`notion.mail.id`)
- Compose (C) / Reply (R) / Forward (F) / Archive (E) / Go to inbox (G+I)

### Communication

**Slack** (`com.tinyspeck.slackmacgap`)
- Quick switcher (⌘K) / Compose / DMs / Browse channels / Mentions

**Discord** (`com.hnc.Discord`)
- Quick switcher (⌘K) / Mark as read / New message / Server settings / Mute

**Mail** (`com.apple.mail`)
- New message (⌘N) / Reply (⌘R) / Forward (⌘⇧F) / Delete / Search (⌘⌥F)

### Browser

**Chrome / Comet / Arc** (`com.google.chrome` / `ai.perplexity.comet` / Arc)
- New tab (⌘T) / Close tab (⌘W) / Reopen tab (⌘⇧T) / Address bar (⌘L) / Reload (⌘R)

### Native

**Finder** (`com.apple.finder`)
- New window (⌘N) / New folder (⌘⇧N) / Go to folder (⌘⇧G) / Get info (⌘I) / Trash (⌘⌫)

**Mail.app** — patrz wyżej (Communication)

**Calendar** (`com.apple.iCal`)
- New event (⌘N) / Today (⌘T) / Week view (⌘2) / Search (⌘F) / Preferences (⌘,)

**Music** (`com.apple.Music`)
- Play/pause (Spacja) / Next (⌘→) / Prev (⌘←) / Search (⌘F) / View (⌘1/2/3)

**Terminal** (`com.apple.Terminal`)
- New tab (⌘T) / New window (⌘N) / Find (⌘F) / Clear (⌘K) / Close tab (⌘W)

### Creative (wymaga U-7)

**Figma Desktop** (`com.figma.Desktop`)
- Move (V) / Frame (F) / Rectangle (R) / Text (T) / Pen (P)

**Photoshop** (`com.adobe.Photoshop`)
- Move (V) / Brush (B) / Eraser (E) / Marquee (M) / Type (T)

**Sketch** (`com.bohemiancoding.sketch3`)
- Rectangle (R) / Oval (O) / Text (T) / Vector (V) / Artboard (A)

### Office (wymaga osobnego eval — patrz `eval-test-cases-phase-1.5.md`)

**Excel** / **Word** / **PowerPoint** — quick 5-action eval:
- Save (⌘S) / Find (⌘F) / Bold (⌘B) / New file (⌘N) / Print (⌘P)

(Te są **uniwersalne** macOS shortcuty, **nie** Office-specific. Eval
sprawdza tylko czy SFlow pokazuje toasty dla standardowych akcji w Office.)

### Catalyst

**News** (`com.apple.news`)
- Today tab / Search / Bookmark / Share / Settings

**Books** (`com.apple.iBooksX`)
- Search / Library / New collection / Settings / Bookmark

### Niche/utility

**1Password 8** (`com.1password.1password8`)
- Quick access (⌘⇧Space) / New item / Search / Settings / Lock

**Spotify** (`com.spotify.client`)
- Play/Pause / Next / Prev / Search (⌘F) / Library

**CleanShot X** (`pl.maketheweb.cleanshotx`)
- Screenshot / Recording / Settings / History / Quit

---

## Decision matrix po quick eval

| Wynik | Akcja |
|---|---|
| 🟢 GOOD (4-5/5) | Dodaj do `coverage-report.md` jako 🟢. **Nie inwestuj** w dalszy test. |
| 🟡 PARTIAL (2-3/5) | Decyzja: (a) reseed + retest 5-min, (b) jeśli nadal 🟡 → full 30-min eval z `eval-test-cases-phase-1.5.md` |
| 🔴 POOR (0-1/5) | **Zatrzymaj** — pierwszy: sprawdź AX permission, czy apka aktywna, czy bundle.json istnieje. Jeśli wszystko OK → escalate: brak per-app rules + universal też nie pokrywa → potencjalny case dla nowego sub-celu / G-X gap. |

---

## Aktualny stan eval (template do zaczęcia)

| Apka | Quick eval | Data | Komentarz |
|---|---|---|---|
| Slack | 🟢 | 2026-05-15 | 4/5 (Quick switcher, Compose, DMs, Mentions; gap: 2nd monitor toast bug) |
| Notion Mail | 🟢 | 2026-05-15 | 5/5 po Sesji B |
| Notion (main) | ? | — | TODO |
| Notion Calendar (Cron) | 🟡 | 2026-05-15 | 3/5 (Create event OK; Week/Month dropdown miss — P-38) |
| Claude Desktop | 🟢 | 2026-05-15 | 5/5 |
| Comet | 🟡 | 2026-05-15 | 3/5 (browser chrome OK; 4 false-positive L0.3 fixed in B.1) |
| Obsidian | ? | — | TODO |
| Linear | ? | — | TODO |
| Cursor | ? | — | TODO |
| VSCode | ? | — | TODO |
| Xcode | 🔴 | 2026-05-15 | 1/5 (Stop ⌘. OK; reszta — brak bundled, reseed wymagany) |
| Mail.app | ? | — | TODO |
| Finder | 🔴 | 2026-05-16 | 0/5 (większość missów to AXCell non-actionable) |
| Calendar.app | ? | — | TODO |
| Terminal | ? | — | TODO |
| Spotify | ? | — | TODO |
| 1Password | ? | — | TODO |
| Chrome | ? | — | TODO |
| Arc | ? | — | TODO |
| Discord | ? | — | TODO |
| CleanShot X | 🔴 | 2026-05-16 | 0/5 (brak bundled; reseed wymagany) |

---

*Quick eval doc napisany 2026-05-17 offline. Filip wykonuje ~5 min per
apka, w 1 godzinę pokrywa 12+ aplikacji.*
