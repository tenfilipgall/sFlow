# UAT checklist — 4 nietknięte apki w bundled.json

> **Cel:** zweryfikować manualnie 4 apki (Obsidian, Terminal, Linear, Cursor)
> oznaczone jako ⬜ UNTESTED w `coverage-report.md`. Po zamknięciu tego
> checklistu **Sub-cel 1.6** robi skok z 3-5/10 → 7-9/10 zweryfikowanych apek.
>
> **Czas dla Filipa:** ~30-40 minut wszystkich razem.
>
> **Stworzone przez:** AI, podczas nieobecności Filipa, na bazie inspekcji
> `bundled.json` + `~/Library/Application Support/SFlow/rules/cache/`.
>
> **Stan AI po 2026-05-17:** dokument **niescommitowany** — czeka na
> wykonanie i Twoje decyzje.

---

## ❗ Ważne odkrycie zanim zaczniesz

Przy inspekcji `bundled.json` wyszło że dystrybucja ról reguł jest bardzo
nierówna:

| App | Reguły total | AXMenuItem | AXButton | Implikacja |
|---|---|---|---|---|
| **Obsidian** | 44 | 39 (88%) | 5 (12%) | UAT = mix menu + window |
| **Terminal** | 69 | 69 (100%) | 0 | UAT = **TYLKO menu bar** |
| **Linear** | **0** | 0 | 0 | **Brak reguł — najpierw discovery!** |
| **Cursor** | **brak w bundled i cache** | — | — | **Brak reguł — najpierw discovery!** |

**Wniosek:** UAT czterech apek to NIE jest 4 × 30min. Realnie:
- Obsidian: 15-20 min UAT (5 buttons + 10 menu)
- Terminal: 10 min UAT (5-7 menu items wystarczy — wszystkie idą tą samą
  ścieżką L3 MenuBarIndex / L0.5 cache)
- Linear: **15 min discovery** (odpal, poczekaj, sprawdź w Settings → Apps
  czy Learned) **+ 15 min UAT** w **następnej sesji**
- Cursor: **15 min discovery + 15 min UAT** w **następnej sesji**

---

## Apka 1 — Obsidian (`md.obsidian`)

**Co zrobić:** otwórz Obsidian z dowolnym vaultem (najlepiej z kilkoma notatkami).
SFlow musi być włączony (sprawdź ikonkę w menu barze).

**Oczekiwanie:** dla każdej akcji poniżej toast pojawia się ~0.5s **po**
kliknięciu z odpowiednim skrótem. Jeśli toast jest złym skrótem, cmd-klik na
nim oznacza false-positive.

### A. Window buttons (5 akcji) — testują czy SFlow widzi window UI Obsidiana

| # | Akcja (klik myszką) | Oczekiwany toast | Status |
|---|---|---|---|
| 1 | Klik **„Command Palette"** (zwykle ikona ⚡ w sidebarze lub `:` w sidebar) | `⌘P` | ⬜ |
| 2 | Klik **„Search"** w sidebarze (lupka) | `⌘⇧F` | ⬜ |
| 3 | Klik **„Toggle Left Sidebar"** (strzałka po lewej) | `⌘[` | ⬜ |
| 4 | Klik **„Toggle Right Sidebar"** (strzałka po prawej) | `⌘]` | ⬜ |
| 5 | Klik **„Graph View"** (ikona grafu w sidebarze) | `⌘G` | ⬜ |

### B. Menu items (5 akcji) — testują czy menu bar matching działa

| # | Akcja (klik w pasek menu Obsidian) | Oczekiwany toast | Status |
|---|---|---|---|
| 6 | File → **„New Note"** | `⌘N` | ⬜ |
| 7 | File → **„Close Tab"** | `⌘W` | ⬜ |
| 8 | File → **„Open Quickly..."** | `⌘O` | ⬜ |
| 9 | Edit → **„Find"** | `⌘F` | ⬜ |
| 10 | Obsidian → **„Settings..."** | `⌘,` | ⬜ |

### C. Świadomie pomijamy (out of scope dla tego UAT)

- Wszystkie pluginy / community shortcuts (zbyt user-specific)
- Cut/Copy/Paste (oczywiste, system-level, nie potrzebują weryfikacji SFlow)
- Markdown formatting (Bold/Italic w editorze — to są command-mode triggers,
  nie shortcuts dla SFlow)

### D. Decyzja po UAT

- ≥8/10 toastów poprawnych + 0 cmd-klików → **Obsidian → 🟢 GOOD** w
  `coverage-report.md`
- 5-7/10 lub 1-2 false-positive → 🟡 PARTIAL, wpisz w session log które
  akcje miss'owały
- ≤4/10 → 🔴 POOR, otwórz nowy P-X w `audit-phase-0.md`

---

## Apka 2 — Terminal (`com.apple.Terminal`)

**Co zrobić:** otwórz Terminal.app (Apple, NIE iTerm2). Otwórz menu bar
i klikaj poniższe.

**Uwaga ważna:** Terminal ma **100% reguł = AXMenuItem**, więc UAT to
tylko menu bar. Window-level (klik w content terminala) **nie da toastów**
bo to text input.

| # | Akcja (klik w pasek menu Terminal) | Oczekiwany toast | Status |
|---|---|---|---|
| 1 | Shell → **„New Window"** | `⌘N` | ⬜ |
| 2 | Shell → **„New Tab"** | `⌘T` | ⬜ |
| 3 | Shell → **„Close Window"** | `⌘W` | ⬜ |
| 4 | Shell → **„Close All"** | `⌘⌥W` | ⬜ |
| 5 | Shell → **„Export Text As..."** | `⌘S` | ⬜ |
| 6 | View → **„Show Inspector"** | `⌘I` | ⬜ |
| 7 | View → **„Edit Title"** | `⌘⇧I` | ⬜ |
| 8 | View → **„Print..."** (Shell menu) | `⌘P` | ⬜ |

### Decyzja po UAT

- ≥6/8 → 🟢 GOOD, Terminal zamknięty
- 3-5/8 → 🟡, możliwy bug w MenuBarIndex dla Terminal
- ≤2/8 → 🔴, sprawdź czy `tooltipDebug` wlacza i czy menu bar w ogóle jest
  walked

---

## Apka 3 — Linear desktop (`com.linear.LinearMac`)

**Stan:** `bundled.json` ma wpis ale **0 reguł**. Brak też w cache.
SFlow **nigdy** nie zrobił auto-discovery na Linear.

### Krok 1 (~15 min) — Discovery

1. **Otwórz Linear.app** (jeśli nie zainstalowane: pobierz z linear.app)
2. **Zaczekaj 30-60 sekund** na pierwszym ekranie po loginie
3. Sprawdź ikonkę SFlow w menu barze → **Settings** → **Apps tab**
   (jeśli ukryta: Advanced → włącz „Show developer features")
4. Powinieneś zobaczyć Linear w **„Learning…"** lub **„Failed"** lub
   **„Learned"**:
   - **„Learning..."** → poczekaj jeszcze 30s, refresh
   - **„Failed"** → naciśnij **Try again**, sprawdź internet
   - **„Learned"** + count >10 → ✅ discovery OK, idź do Kroku 2
   - Brak Linear w żadnej sekcji → discovery jeszcze nie został triggered,
     wykonaj 5-10 kliknięć w Linear (otwarcie issue, sidebar nav) żeby
     pobudzić AppLifecycleObserver

5. Po discovery sprawdź: `~/Library/Application Support/SFlow/rules/cache/com.linear.LinearMac.json`
   powinien istnieć z ≥20 regułami.

### Krok 2 (~15 min, **następna sesja**) — UAT

Po Discovery zrób analogiczny checklist do Obsidian:
- 5 najczęstszych akcji window (Cmd+K palette, sidebar nav, create issue,
  notifications, settings)
- 5 menu items (File/Edit/View)

**Nie wykonuj UAT zanim discovery nie da co najmniej 15 reguł.**

---

## Apka 4 — Cursor (`com.todesktop.230313mzl4w4u92` — VS Code fork)

**Stan:** brak w `bundled.json` (powinno być? — check) i brak w cache.

### Krok 1 (~15 min) — Discovery

1. **Otwórz Cursor.app** (jeśli nie masz: cursor.com)
2. Otwórz dowolny folder kodu (np. SFlow projekt sam)
3. **Zaczekaj 30-60s**, sprawdź **Settings → Apps tab**
4. Cursor jest forkiem VS Code → ma identyczne shortcuty (`⌘P`, `⌘⇧P`,
   `⌘B`, `⌘J`, ...). Discovery powinno dać 50+ reguł.
5. Jeśli **„Failed"** → backend może mieć rate limit dla nowych apek
   (P-2 retry policy). Try Again po godzinie.

### Krok 2 (~15 min, **następna sesja**) — UAT

Top 10 cursor actions do testu:
1. Klik command palette button → `⌘⇧P`
2. Klik file search (lupka) → `⌘P`
3. Klik toggle sidebar → `⌘B`
4. Klik toggle terminal → `⌘J`
5. Klik AI panel / Cursor chat → `⌘L` (Cursor-specific)
6. Klik split editor → `⌘\\`
7. Klik command palette → `⌘⇧P`
8. Klik new file → `⌘N`
9. Klik save → `⌘S`
10. Klik close editor → `⌘W`

---

## Po wszystkim — co update'ować

Po wykonaniu UAT na 4 apkach:

1. **`coverage-report.md`** — przesuń wpisy Obsidian/Terminal/Linear/Cursor
   z ⬜ UNTESTED do 🟢/🟡/🔴 z notatką
2. **`audit-phase-1.md`** Sub-cel 1.6 — update count zweryfikowanych
   apek (cel ≥10 dla bety)
3. **`roadmap.md` session log** — dodaj wpis „2026-05-XX — UAT bundled apek
   (Obsidian/Terminal/Linear/Cursor)" z findings
4. Jeśli któraś apka 🔴 POOR — otwórz nowy P-X w `audit-phase-0.md`

---

## Brutalna prawda: czego ten UAT NIE rozwiąże

- **Obsidian community plugins** — userzy mają tysiące pluginów z własnymi
  skrótami. SFlow nigdy nie pokryje tego pełniej niż menu bar.
- **Terminal jako bash REPL** — `Ctrl+C`, `Ctrl+R`, `Ctrl+D` to nie macOS
  shortcuts, to **terminal control codes**. SFlow celowo nie próbuje ich
  matchować.
- **Linear keyboard shortcuts są web-app-ish** — w Linear desktop wiele
  akcji ma single-key shortcuts (C = create, M = move, ...). U-3
  (single-key mode) z 2026-05-17 powinien pomóc. Test wstawi się naturalnie
  podczas UAT Linear (Krok 2).
- **Cursor AI features** (Cmd+K do prompta, Cmd+L do chat) są specyficzne
  dla Cursora — auto-discovery może je pominąć bo Claude może nie wiedzieć
  że to fork VS Code z extension'ami AI. Manual review reguł rekomendowany
  po Discovery.

---

*Status pliku: roboczy checklist. Wykonaj UAT → wpisz wyniki → commit z
zaktualizowanym coverage-report.md.*
