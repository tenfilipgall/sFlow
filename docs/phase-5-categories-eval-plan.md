# Plan zamykania 5 kategorii apek (Sub-cele 1.24-1.28)

> **Cel:** zamknąć **5 świadomie niepokrytych typów apek** z Fazy 1.5 —
> wiedzieć ile z naszych warstw uniwersalnych działa w Microsoft Office,
> Adobe Creative Suite, Qt/GTK/Tk, Catalyst i SwiftUI pure.
>
> **Adresuje:** P-47 (audit-phase-0.md), Sub-cele 1.24-1.28 (audit-phase-1.5.md).
>
> **Stworzone:** 2026-05-17. **Status:** plan, NIE zaczęty.
> **Prerequisites:** żaden hard-blocker. Adobe (1.25) czeka na U-7 (tool/mode
> switching) — patrz §5.
>
> **Powiązania:** `audit-phase-1.5.md` (statusy + ROI matrix),
> `eval-test-cases-phase-1.5.md` (test cases per apka — szczegółowe),
> `STATUS.md` (dashboard postępu).

---

## 0. TL;DR (3 zdania)

5 kategorii × różne technologie renderowania UI = każda potrzebuje osobnej
ewaluacji żeby wiedzieć ile z **warstw uniwersalnych SFlow** (Layer 0/0.3/0.5/
0.6/L3/L4) tam działa. **Kolejność wg ROI: SwiftUI (1.28) → Catalyst (1.27) →
Qt/GTK (1.26) → Office (1.24) → Adobe (1.25)** — od najtańszego najwięcej
nauki w najmniej czasu. **Razem ~32h pracy**, rozbite na 5 mini-sesji
(2h+4h+6h+10h+10h), idealne do robienia po jednej dziennie albo w pauzach
między większymi tasknami.

---

## 1. Czemu te 5 kategorii?

W audicie 2026-05-16 (P-47 / Sub-cele 1.24-1.28) wydzieliliśmy 5 typów apek
których SFlow **nigdy nie testował na natywnej macie**. Każda używa innej
technologii renderowania UI = inny model AX = inne wzorce coverage.

| # | Kategoria | Technologia | Apki | Czas eval |
|---|---|---|---|---|
| 1 | **Microsoft Office** | AppKit + ribbon | Excel, Word, PowerPoint, OneNote, Outlook | ~10h |
| 2 | **Adobe Creative Suite** | Custom rendering (Adobe runtime) | Photoshop, Illustrator, Premiere | ~10h |
| 3 | **Qt / GTK / Tk** | Linux-style toolkits z bindings AX | VLC, GIMP, Blender, OBS, Audacity | ~6h |
| 4 | **Catalyst (iPad-na-Macu)** | UIKit → AppKit translation | News, Stocks, Home, Books, Voice Memos | ~4h |
| 5 | **SwiftUI pure** | Apple modern declarative | Shortcuts.app, Freeform | ~2h |

**Analogia (12-latek):** dziś SFlow potrafi rozpoznawać kliknięcia w „normalnych"
macOS apkach jak Slack czy Notion. Ale te 5 kategorii to **różne wszechświaty
budowy UI** — jak różne marki klocków LEGO. Excel jest jak Duplo (większe
klocki, hybryda z dawnej technologii), Photoshop ma własną „technologię
klocków" niezgodną ze standardem, Blender w ogóle nie używa klocków systemowych
(rysuje wszystko OpenGL).

Cel ewaluacji: **dla każdej technologii dowiedzieć się, ile kliknięć SFlow
potrafi rozpoznać** — bez tej wiedzy nie wiemy, którym userom (programista
+ designer + księgowa) możemy obiecać że SFlow działa.

---

## 2. Kolejność — wg ROI (audit-phase-1.5.md macierz)

Liczone wzorem `P×C` / `K` gdzie P=prawdopodobieństwo sukcesu, C=coverage
unlock, K=czas:

| # | Sub-cel | ROI score | Czas | Komentarz |
|---|---|---|---|---|
| 🥇 | **1.28 SwiftUI** | **36** | 2h | Najwyższe ROI z całej piątki — tanie, prawie pewne że działa (Sesja A już testowała kAXValue fallback) |
| 🥈 | **1.27 Catalyst** | **24** | 4h | Wielu userów Maca używa Stocks/News codziennie — wysokie P (Apple-native) |
| 🥉 | **1.26 Qt/GTK** | **10** | 6h | Niche userzy (VLC powszechne, GIMP/Blender rzadziej) — Blender prawdopodobnie 0% (OpenGL) |
| 4 | **1.24 Office** | **24** | 10h | Wielu enterprise userów — ale Microsoft schodzi z platformy macOS, długoterminowo niska wartość |
| 5 | **1.25 Adobe** | **7** | 10h | **Czeka na U-7** (tool/mode switching) — bez U-7 strzelamy w martwe pole |

**Dwie zasady kolejności:**

1. **„Tanie zwycięstwa najpierw"** — SwiftUI 2h może dać 80% pokrycia (Apple
   ujednolicił AX dla SwiftUI), zaczynamy od najwyższego ROI
2. **Adobe ostatnie** — bez U-7 zmarnujemy 10h żeby udowodnić że nie działa.
   Albo robimy U-7 najpierw, albo odkładamy 1.25 na po Becie.

---

## 3. Per-kategoria sesja (E-1 do E-5)

### Sesja E-1 — SwiftUI pure (1.28) ⭐ start tu

**Czas:** ~2h. **Apki:** Shortcuts.app, Freeform.

**Cel mierzalny:** dla 10 typowych kliknięć w każdej apce → mierzymy
hit-rate. Cel sukcesu: ≥6/10 toastów per apka.

**Hipoteza:** SwiftUI używa `kAXValue` zamiast `kAXTitle` dla wielu etykiet
— Sesja A (2026-05-15) już to rozwiązała w `extractFallbackTitleFromChildren`.
Oczekujemy **wysokiego pokrycia** (Apple-native + nasz fallback gotowy).

**Krok po kroku:**

1. **Pre-eval** (~10 min): otwórz Shortcuts.app → kliknij ikonkę SFlow w menu
   barze → Settings → Apps tab → sprawdź czy `com.apple.shortcuts` jest
   w „Learned" (auto-discovery powinien zadziałać). Jeśli „Failed" — Try
   Again.
2. **Eval kliknięć** (~30 min, Shortcuts.app):
   - Kliknij **"All Shortcuts"** w sidebarze → oczekujemy toasta
   - Kliknij **"New Shortcut"** (+ ikona) → oczekujemy `⌘N`
   - Kliknij **"Show as Grid"** (toolbar) → oczekujemy toggle toast
   - Kliknij **"Settings"** w pasku menu Shortcuts → oczekujemy `⌘,`
   - Kliknij **"Run"** (play button na karcie shortcuta) → oczekujemy `⌘R`
   - + 5 więcej z `eval-test-cases-phase-1.5.md` §1.28.1
3. **Eval kliknięć** (~20 min, Freeform):
   - Kliknij **"New Board"** → toast
   - Toolbar tools (pen, square, arrow) → single-key shortcuts (U-3 active)
   - Sidebar nav → toast
   - + 5 więcej
4. **Decision** (~10 min):
   - ≥6/10 GOOD per apka → 🟢, dopisz do `coverage-report.md` jako verified
   - 3-5/10 → 🟡 PARTIAL, otwórz P-X jeśli pattern wskazuje konkretny gap
   - ≤2/10 → 🔴, otwórz nowy P-X i `audit-phase-0.md`
5. **Update statusów** (~20 min):
   - `audit-phase-1.5.md` Sub-cel 1.28 → 🟢/🟡/🔴
   - `STATUS.md` Faza 1.5 progress
   - `coverage-report.md` rozszerzenie tabeli o 2 nowe apki
   - Session log w `roadmap.md`
6. **Commit** „eval: Sub-cel 1.28 SwiftUI pure — Shortcuts/Freeform verified"

**Najgorszy scenariusz:** Shortcuts.app pokazuje 0 toastów bo Apple używa
niestandardowych identyfikatorów. **Plan B:** sprawdzamy w `events.jsonl`
co dokładnie się stało (`subtreeLabel`/`identifier`/`value`) i otwieramy
nowy P-X dla SwiftUI-specific fallback.

---

### Sesja E-2 — Catalyst (1.27)

**Czas:** ~4h. **Apki:** News, Stocks, Home, Books, Voice Memos.

**Cel mierzalny:** 5 apek × 8 typowych kliknięć = 40 events. Per apka cel
≥4/8.

**Hipoteza:** Catalyst tłumaczy UIKit na AppKit — historycznie miało **dziwne
mapowania AX** (np. UIButton bez kAXTitle). Apple to powoli naprawia (w
macOS 14+ powinno być lepiej). Oczekujemy **średniego pokrycia** (50-70%).

**Sub-sesje (~40 min każda):**

| App | Top akcje do kliknięcia | Oczekiwane |
|---|---|---|
| **News** | Today / Sports / Following / Saved / Share article | toast lub miss z `subtreeLabel` |
| **Stocks** | Search ticker / Watchlist / News tab / Settings | search⌘F, settings⌘, |
| **Home** | Add accessory / Home tab / Automations / Settings | menu items |
| **Books** | Reading Now / Library / Want to Read / Bookmark / Highlight | mostly menu |
| **Voice Memos** | Record (red button) / Done / Edit / Share / Trash | toolbar buttons |

**Decyzja:**
- ≥3 z 5 apek ma ≥4/8 toast hit-rate → 🟢 GOOD dla Catalyst kategorii
- 1-2 z 5 → 🟡 PARTIAL, dodaj tylko te 1-2 do `coverage-report.md`
- 0 z 5 → 🔴, otwórz P-X „Catalyst-specific AX mapping gap"

---

### Sesja E-3 — Qt / GTK / Tk (1.26)

**Czas:** ~6h. **Apki:** VLC, GIMP, Blender (reprezentanci 3 sub-frameworków).

**Hipoteza:** Qt-apek (VLC) **menu bar zwykle działa** (L3 MenuBarIndex) ale
custom widgets canvas (timeline VLC, GIMP canvas, Blender viewport) **w ogóle
nie eksponują AX**. Oczekujemy: **L3 ≥80%, window-level ≤30%**.

**Mini-sesje:**

| App | Co testować | Oczekiwane wyniki |
|---|---|---|
| **VLC** (~2h) | Menu bar (File/Playback/Video) + okno (Play/Pause/Stop buttons + slider) | Menu bar 80%+, okno ~30% |
| **GIMP** (~2h) | Menu bar (File/Edit/Image) + toolbox tools (Brush, Pencil...) | Menu bar OK, toolbox **prawdopodobnie 0%** (custom GTK rendering) |
| **Blender** (~2h) | Menu bar tylko + 5-10 viewport clicks | **Oczekujemy 0% window**, menu bar może być nawet pusty |

**Decyzja po 1.26:**
- Jeśli Qt menu bar działa ale window 0% → **opt-out window dla Qt** — w
  `coverage-report.md` zapisać „Qt apek: menu bar only support"
- Blender 0% wszędzie → **świadomie wykluczyć** z bundled/auto-discovery
  (zaktualizować backend prompt: nie generuj reguł dla `bundleId == org.blendrfoundation.blender`)
- GIMP toolbox = otwiera P-X „GTK toolbox rendering AX gap"

---

### Sesja E-4 — Microsoft Office (1.24)

**Czas:** ~10h. **Apki:** Excel, Word, PowerPoint, OneNote, Outlook (5 apek).

**Hipoteza:** Office używa **hybridy AppKit + własnego ribbona**. Menu bar
działa (L3), ale **ribbon** (główny pas akcji u góry) jest **niestandardowy**.
Oczekujemy: **menu bar 90%+, ribbon ~40-60%** (zależnie czy Microsoft
ustawił aria/AX-equivalents).

**Krytyczna obserwacja przed startem:** Office na macOS dostaje coraz **mniej**
update'ów (Microsoft pcha Office 365 web jako primary). Może warto **opt-out
desktop Office, wspierać Office Web** w Fazie 1.8 (web-as-app). To dobre
pytanie ROI po pierwszych 2-3h sesji.

**Sub-sesje (~2h każda):**

1. Excel — top 15 akcji (formuły, formatowanie, autosum, freeze, sort)
2. Word — top 15 (bold/italic/underline, headings, lists, table)
3. PowerPoint — top 12 (new slide, format, transition, animation)
4. OneNote — **SKIP** (low priority, Microsoft de-prioritized)
5. Outlook — top 12 (compose, reply, archive, folders)

**Decyzja:**
- Office ≥60% → kontynuować, dodać do bundled.json
- Office ≤30% → **odłożyć**, polecić Office Web (Faza 1.8) jako alternatywę
- W trakcie: jeśli widać że ribbon = 0% dla wszystkich → otwórz P-X
  „Office ribbon AX gap", zakończ wcześnie (~4h zamiast 10h)

---

### Sesja E-5 — Adobe Creative Suite (1.25)

**Czas:** ~10h. **WARNING: blocked by U-7** (tool/mode switching).

**Hipoteza:** Adobe runtime renderuje większość UI **sam** — AX tree jest
prawdopodobnie bardzo płytkie/puste. Tools w toolbox (Brush, Lasso, Pen) =
single-key shortcuts (B/L/P) — **wymaga U-7** żeby SFlow rozpoznał.

**Czemu czekamy na U-7:** bez tool/mode switching SFlow nie wie że klik
w toolbox button to akcja z single-key shortcut. Pokaże miss. Eval Adobe
bez U-7 = sztucznie zaniżone wyniki.

**Plan:**
1. Najpierw zrobić **U-7 (Sub-cel 1.23)** — ~5h
2. Po U-7 → eval Adobe (~10h)
3. Razem 15h, ale Adobe sam w sobie da prawdziwe dane

**Pytanie do Filipa po Sesji E-4 (Office):** czy w ogóle robimy Adobe?
Najniższe ROI z piątki (7), wąska niche userów, długo. Możliwa decyzja:
**świadomie odpuścić** Adobe w obecnej iteracji, focus na Web Faza 1.8
(gdzie Photoshop Web/Illustrator Web mogą się pojawić w przyszłości).

---

## 4. Universal prerequisites — co MUSI być done

| Pre | Stan | Wpływ na sekwencję |
|---|---|---|
| **U-1** TooltipNameFilter + PrivacyFilter | 🟢 done 2026-05-17 | Bez tego eval byłby zaszumiony PII + false-positives |
| **U-2** Right-click context menu | 🟢 done 2026-05-17 | Office/Adobe mają sporo context menu |
| **U-3** Single-key mode | 🟢 done 2026-05-17 | Krytyczne dla Adobe toolbox (B/L/P) + Catalyst (some) |
| **U-5** i18n | ⬜ pending | Office PL/DE → po U-5 wyniki będą czystsze. **Można robić eval bez U-5** ale notować że PL/DE userzy widzą gorszy obraz |
| **U-7** Tool/mode switching | ⬜ pending | **HARD blocker dla Adobe (1.25).** Office może działać bez U-7 (ribbon ≠ toolbox). Qt GIMP toolbox **też** wymaga U-7. |

**Rekomendacja sekwencji:** najpierw E-1 (SwiftUI) → E-2 (Catalyst) → E-3
(Qt VLC + GIMP **bez** toolbox details) → decyzja czy robić U-7 → E-4 (Office)
→ U-7 → E-5 (Adobe) lub skip Adobe.

---

## 5. Decision tree po każdej sesji

```
Po każdej sesji E-X, dla każdej apki:

  hit rate ≥6/10  →  🟢 GOOD
                  →  dodać do coverage-report.md verified table
                  →  jeśli reguły z auto-discovery są dobre, dodaj do
                     bundled.json (po quality gate)

  hit rate 3-5/10 →  🟡 PARTIAL
                  →  dodać do coverage-report.md z notą "PARTIAL"
                  →  identyfikować dominujący gap pattern
                  →  jeśli nowy pattern → otwórz P-X
                  →  jeśli istniejący P-X → dopisz apki do listy "affected"

  hit rate ≤2/10  →  🔴 POOR
                  →  zapisać w coverage-report.md jako "POOR"
                  →  jeśli technologia-wide (cała kategoria fail)
                       →  zaktualizować backend prompt by NIE generować
                          reguł dla tego bundleId (oszczędność LLM costs)
                       →  zaznaczyć w product-vision sekcja 5 jako
                          "kategoria świadomie nieobsługiwana"
                  →  jeśli pojedyncza apka fail
                       →  notować ale nie blokować
```

---

## 6. Acceptance criteria — kiedy „Plan 5 kategorii done"

- [ ] **E-1 SwiftUI** zamknięte (Shortcuts.app + Freeform) — sub-cel 1.28 🟢/🟡/🔴
- [ ] **E-2 Catalyst** zamknięte (5 apek) — sub-cel 1.27 🟢/🟡/🔴
- [ ] **E-3 Qt/GTK** zamknięte (VLC + GIMP + Blender) — sub-cel 1.26 🟢/🟡/🔴
- [ ] **E-4 Office** zamknięte (Excel + Word + PowerPoint + Outlook) — sub-cel 1.24 🟢/🟡/🔴
- [ ] **E-5 Adobe** zamknięte lub świadomie odłożone z uzasadnieniem — sub-cel 1.25 🟢/🟡/🔴/odłożone
- [ ] `coverage-report.md` zawiera tabelę verified per-app dla wszystkich 5 kategorii
- [ ] `STATUS.md` Faza 1.5 progress podniesione (3/12 → 8/12 lub więcej)
- [ ] Decyzje opt-out (jeśli są) udokumentowane w product-vision sekcja 5
- [ ] Backend prompt zaktualizowany jeśli któraś technologia świadomie wykluczona

---

## 7. Wartość dodana — jak to pomaga Becie i strategii ogólnej

**Dla Bety (Faza 1.7):** beta-testerzy używają różnych narzędzi.
- Designer = Figma/Sketch (Faza 1.8 web) + ewentualnie Adobe (1.25)
- Programista = Cursor/VS Code/Terminal (już mamy)
- Manager = Office + Outlook (1.24) + Calendar (już mamy)
- Researcher = Notion + Obsidian (już mamy) + PDF readers
- **Ten plan pokrywa wszystkie 4 person'y poza programistą-tylko**

**Dla Sub-celu 1.6 (10 verified apek):** po zakończeniu planu mamy potencjalnie
**+10-15 zweryfikowanych apek** w bundled.json. Faza 1.6 zamknięta.

**Dla product-vision (sekcja 1 — kto kupi SFlow):** wiemy konkretnie którym
person'om możemy obiecać że SFlow działa, a którym jeszcze nie. To **rzeczywista
deliverable wartość** — nie tylko liczby, ale **pewność marketingowa**.

---

## 8. Decyzje zatwierdzone przez Filipa 2026-05-17 ✅

1. **Kiedy zaczynamy?** → **(a) przed Betą** — E-1+E-2 dadzą boost coverage
   reportu przed beta-testerami
2. **Adobe?** → **odłożone** do Fazy 1.9 post-Beta. ROI=7 nie uzasadnia 15h
   przed beta-testerami
3. **Office Outlook?** → **eval normalnie** (top 12 akcji). Jeśli ribbon
   ≤30%, opt-out całego Office desktop, polecać Office 365 Web w Fazie 1.8
4. **Catalyst?** → **3 reprezentantów** (News + Stocks + Voice Memos). Home
   i Books można dodać po Becie jeśli beta-testerzy o nie pytają

---

## 9. Sekwencja sugerowana (po Twoich decyzjach §8)

**Optymistyczna (jeśli akceptujesz rekomendacje §8):**

| # | Sesja | Czas | Gdzie w roadmap |
|---|---|---|---|
| 1 | **E-1 SwiftUI** | 2h | przed Betą |
| 2 | **E-2 Catalyst (3 apek)** | 2.5h | przed Betą |
| 3 | **E-3 Qt (VLC + GIMP, skip Blender)** | 4h | przed Betą |
| 4 | **E-4 Office (4 apek)** | 8h | po E-1..E-3, przed Betą |
| 5 | **E-5 Adobe** | odłożone | post-Beta |

**Razem ~16.5h przed Betą** = ~3-4 dni roboty rozbite na 2-godzinne sesje.

**Najszybsza droga do bety:** robimy tylko E-1 i E-2 (4.5h) → dane do `coverage-
report.md` → Sub-cel 1.6 dostaje +3-5 verified apek (z SwiftUI + Catalyst) →
łatwiej zamknąć ≥10 verified threshold.

---

## 10. Następne kroki

1. **Filip odpowiada na 4 decyzje z §8** (a/b/odłożyć/3 apek-style)
2. AI updatuje ten plan z decyzjami
3. Filip wybiera moment startu E-1
4. Po E-1 → review wyników → decyzja czy idziemy E-2 czy przerwa
5. Każda E-X kończy się aktualizacją `STATUS.md` i `coverage-report.md`

---

*Status pliku: plan strategiczny. Aktualizacja: po każdej sesji E-X (kolejne
decyzje go/no-go).*
