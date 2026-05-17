# SFlow — Audyt Fazy 1.5: Universal Coverage

> Faza pomiędzy Fazą 1 (jakość pokrycia dla 4–20 zweryfikowanych apek) a Fazą 2
> (infrastruktura nauki). **Cel:** zamknąć największe luki uniwersalności
> mechanizmu rozpoznawania **przed** budową drogi B (lekcje).
>
> Bez tej fazy: SFlow nadal pokrywa tylko subset apek, każdy nowy bundle wymaga
> reseedu Claude'a + manual eval. Z tą fazą: 6 nowych warstw/mechanizmów które
> działają **z dnia 0** na większości apek + eval 5 niepokrytych typów UI.
>
> **Spisany:** 2026-05-16, na bazie analizy `docs/universality-gaps-and-windows-2026-05-16.md`.
>
> **Pre-requisite:** Sub-cele 1.6 (20 zweryfikowanych apek) i 1.7 (beta z 3-5
> osób) z Fazy 1 mogą biec równolegle — nie blokują Fazy 1.5.

## Legenda statusów

- ⬜ **pending** — nie zaczęte
- 🟡 **in-progress** — zaczęte, niedokończone
- 🔵 **partial** — działa częściowo
- 🟢 **done** — zrobione + zweryfikowane
- 🔴 **regression** — cofnięte

## Aktualne statusy sub-celów

**Legenda kolumny "Plan":**
- 📋 = atomic plan napisany w `docs/superpowers/plans/`
- 📋✏️ = plan jako outline w tym dokumencie, bez TDD detail
- (puste) = plan jeszcze nie napisany
- 💻 = kod gotowy w git working tree

| Sub-cel | Status | Plan | Komentarz |
|---|---|---|---|
| 1.18 Right-click / context menu monitoring (G-1) | ⬜ pending | 📋 [u2](superpowers/plans/2026-05-16-u2-right-click-monitoring.md) | `CGEventTap` rozszerzony o `rightMouseDown`; po right-clicku context menu (AXMenu z AXMenuItem children) eksponuje `kAXMenuItemCmdChar` natywnie — bez heurystyki. Pokrywa skróty z prawego-kliku **we wszystkich apkach naraz**. Adresuje P-41. ~3h. |
| 1.19 Web-as-app — pseudo-bundle per domena (G-2) | ⬜ pending | 📋 [u4](superpowers/plans/2026-05-16-u4-web-as-app.md) | Klik w Gmaila w Comet = `bundleId="ai.perplexity.comet"` — gubimy fakt że to **Gmail**. Mechanizm: czytać URL z `AXWebArea.AXURL` (do potwierdzenia empirycznie) lub ekstrahować domenę z `AXTitle` okna; pseudo-bundle `web:gmail.com`. Per-domain reguły. Adresuje P-42. ~5-8h. Pre-flight probe required przed start. |
| 1.20 i18n / lokalizacja reguł (G-3) | ⬜ pending | 📋 [u5](superpowers/plans/2026-05-16-u5-i18n-localization.md) | Slack PL: "Skomponuj" zamiast "Compose" → reguła `desc:"compose"` fail. Plan: czytać `AXLanguage`/`AppleLocale`, prompt Claude'a z `userLocale:"pl"` → wariant PL + EN; per-locale cache `cache/{bundleId}:pl.json` albo `localizedTitles` w schema. Adresuje P-43. ~6-10h. Plan zawiera kompletny backend prompt v2 patch. |
| 1.21 Single-key shortcut mode detection (G-4) | ⬜ pending | 📋 [u3](superpowers/plans/2026-05-16-u3-single-key-mode.md) | Gmail j/k, Notion Mail C, Obsidian Vim — single-key nawigacja. Dziś Layer 2 wymaga `count>1 OR isInteractive`. Plan: feature flag `singleKeyMode: true` w bundled.json per apka; whitelist apek; akceptuj single char w tych apkach nawet na non-interactive. Adresuje P-44. ~2h. |
| 1.22 Modal/sheet/dialog scope (G-7) | ⬜ pending | 📋 [u6](superpowers/plans/2026-05-16-u6-modal-dialog-scope.md) | "Bold" w edytorze ≠ "Bold" w dialogu formatowania. Plan: czytać `AXFocusedWindow`, sprawdzać `AXRole` — `AXSheet`/`AXFloatingWindow`/`AXSystemDialog`; dodać `scope: ["sheet"]` do schema reguł; filter rule wg scope. Eliminuje false positives. Adresuje P-45. ~6h. |
| 1.23 Tool/mode switching w kreatywnych apkach (G-8) | ⬜ pending | 📋 [u7](superpowers/plans/2026-05-16-u7-tool-mode-switching.md) | Figma V/R/T/P, Photoshop B/V/M — narzędzia z literami. Plan: `AXToolbar` role detection; toolbar children = AXButton z desc=narzędzie; L0.3 + single-key whitelist dla toolbar context. Otwiera klasę creative apek. Adresuje P-46. ~5h. |
| 1.24 Eval coverage — Microsoft Office | ⬜ pending | 📋✏️ [eval-test-cases](eval-test-cases-phase-1.5.md) | Excel, Word, PowerPoint, OneNote, Outlook — hybrid AppKit + ribbon. Test cases szczegółowe w eval-test-cases-phase-1.5.md. ~10h. |
| 1.25 Eval coverage — Adobe Creative Suite | ⬜ pending | 📋✏️ [eval-test-cases](eval-test-cases-phase-1.5.md) | Photoshop, Illustrator, Premiere. **Czeka na U-7** (tool/mode) — bez niego eval Adobe da sztucznie słabe wyniki bo toolbox nie pokryty. ~10h. |
| 1.26 Eval coverage — Qt/GTK/Tk apks | ⬜ pending | 📋✏️ [eval-test-cases](eval-test-cases-phase-1.5.md) | VLC, GIMP, Blender. Test cases szczegółowe. ~6h. |
| 1.27 Eval coverage — Catalyst (iPad-on-Mac) | ⬜ pending | 📋✏️ [eval-test-cases](eval-test-cases-phase-1.5.md) | News, Stocks, Home, Books. ~4h. |
| 1.28 Eval coverage — SwiftUI pure | ⬜ pending | 📋✏️ [eval-test-cases](eval-test-cases-phase-1.5.md) | Shortcuts.app, Freeform. ~2h. |
| 1.29 TooltipObserver false-positive integration (B.1) | 🟡 partial | 📋💻 [b.1](superpowers/plans/2026-05-16-tooltip-scrubbing-and-privacy.md) | **Kod gotowy 2026-05-16:** `SFlow/TooltipNameFilter.swift` z banned-list + whitelist + 11 testów + `PrivacyFilter` w `EventLogger.logMiss`. **Czeka na integrację** — Filip dodaje 1 linię w `TooltipObserver`: `guard TooltipNameFilter.isAcceptableActionName(name) else { return nil }`. |

---

## Mapowanie sub-celów → problemy P-X

| Sub-cel | Adresuje | Plik referencyjny |
|---|---|---|
| 1.18 | P-41 Right-click | `audit-phase-0.md` |
| 1.19 | P-42 Web-as-app | `audit-phase-0.md` |
| 1.20 | P-43 i18n | `audit-phase-0.md` |
| 1.21 | P-44 Single-key | `audit-phase-0.md` |
| 1.22 | P-45 Modal scope | `audit-phase-0.md` |
| 1.23 | P-46 Tool/mode | `audit-phase-0.md` |
| 1.24-1.28 | P-47 5 niepokrytych typów | `audit-phase-0.md` |
| 1.29 | P-39 TooltipObserver false-pos + P-40 PII | `audit-phase-0.md` |

---

## Execution sequence — Sesje U-1 do U-10

| # | Sesja | Sub-cel | Czas | Priorytet | Status |
|---|---|---|---|---|---|
| **U-1** | B.1 finalize | 1.29 — integracja TooltipNameFilter w TooltipObserver (1 linia kodu + xcodegen + commit) | ~30 min | **NAJWYŻSZY** (kod gotowy, wymaga 1 commit) | ⬜ |
| **U-2** | Right-click monitoring | 1.18 — `rightMouseDown` mask + AXMenu handler | ~3h | **WYSOKI** (uniwersalny win wszędzie) | ⬜ |
| **U-3** | Single-key mode | 1.21 — feature flag w bundled.json + Layer 2 logic | ~2h | **WYSOKI** (tani fix, Gmail/Notion Mail value) | ⬜ |
| **U-4** | Web-as-app | 1.19 — AXURL/AXTitle parsing + per-domain rules | ~6-8h | **WYSOKI** (odblokowuje cały rozdział web apek) | ⬜ |
| **U-5** | i18n locale-aware | 1.20 — AXLanguage detect + Claude prompt extension | ~6-10h | **ŚREDNI-WYSOKI** (non-EN market) | ⬜ |
| **U-6** | Modal/dialog scope | 1.22 — AXFocusedWindow + scope field w schema | ~6h | ŚREDNI (eliminate false positives) | ⬜ |
| **U-7** | Tool/mode switching | 1.23 — AXToolbar detection + single-key whitelist | ~5h | ŚREDNI (Figma/Photoshop users) | ⬜ |
| **U-8** | Eval Office | 1.24 — Excel/Word/PowerPoint/OneNote/Outlook reseed + manual | ~10h | ŚREDNI (popular enterprise apki) | ⬜ |
| **U-9** | Eval Adobe | 1.25 — Photoshop/Illustrator/Premiere reseed + manual | ~10h | NISKI (canvas content nie-AX) | ⬜ |
| **U-10** | Eval Qt + Catalyst + SwiftUI | 1.26 + 1.27 + 1.28 — VLC/GIMP/Blender + News/Books + Shortcuts.app | ~6h | NISKI (niche apek) | ⬜ |

**Suma:** ~55-70h pracy dla pełnej Fazy 1.5. **Kluczowe top-4 (U-1..U-4):** ~12h.

---

## Kryteria wyjścia z Fazy 1.5

Aby zamknąć Fazę 1.5 i przejść do Fazy 2 (infrastruktura nauki):

- [ ] Wszystkie sub-cele 1.18-1.23 (G-1..G-4, G-7, G-8) zaimplementowane lub
      świadomie odłożone z dokumentacją "dlaczego nie"
- [ ] Sub-cel 1.29 (B.1 follow-up) zacommitowane do main
- [ ] Co najmniej 3 z 5 typów apek (1.24-1.28) zewaluowane manualnie z
      raportem coverage
- [ ] **Coverage 50 apek** (z 20 zweryfikowanych w Fazie 1.6 → 50 z mix
      auto-discovered + manual eval Fazy 1.5)
- [ ] **Brak nowych P-X o priorytecie WYSOKIM** w `audit-phase-0.md` które
      pojawiły się podczas Fazy 1.5
- [ ] Empirycznie: po Fazie 1.5 % missów w `events.jsonl` per kategoria
      kliknięcia (right-click, web content, dialog) spada o **≥60%**

---

## Co NIE robimy w Fazie 1.5

Świadomie odłożone — wracają w Fazie 2 lub później:

- **G-6 Keystroke monitoring** — już zaplanowane w **Fazie 2.2** (drugi
  event tap dla `shortcut_used`). Wymaga drugiej Input Monitoring permission.
- **G-9 Version detection per app** — przyda się dopiero gdy mamy 50+ apek
  i refresh staje się problematic. Faza 2+.
- **G-10 Drag detection** — niska wartość, dragi rzadko mają keyboard
  alternative. Faza 3+.
- **G-11 User-customized shortcuts** — wymaga app-specific integracji
  (VSCode keybindings.json, Sublime config). Faza 3+.
- **G-12 Team/admin overrides** — już w Fazie 7 (B2B).
- **G-13 Gestures** — niska wartość. Może nigdy.
- **G-14 AppleScript discovery** — częściowo pokryte przez backend Claude
  + sdef. Niski priorytet.
- **G-15 Active probing** — Sub-cel 1.16 (Sesja D), internal team only,
  opcjonalne.
- **Windows port** — odłożone do końca 2026/Q1 2027, po PMF na Macu (patrz
  `docs/universality-gaps-and-windows-2026-05-16.md` §4).

---

## Atomic plan — Sesja U-1 (B.1 integracja, ~30 min)

**Pre-requisite:** masz uncommitted WIP w TooltipObserver (+97 LOC, twój
`diagMode`). Najpierw commit twoje WIP-y, potem U-1 w drugim commicie.

### Kroki

1. `xcodegen generate` — żeby Xcode zobaczył nowe pliki z B.1
   (`PrivacyFilter.swift`, `TooltipNameFilter.swift`, ich testy)
2. Otwórz `SFlow/TooltipObserver.swift`. Znajdź miejsce gdzie nazwa
   kandydata `name` jest akceptowana (linia ~100, po
   `TooltipShortcutParser.parseBadge(f.badge)`). Dodaj:
   ```swift
   guard TooltipNameFilter.isAcceptableActionName(f.name) else {
       NSLog("SFlow[Tooltip]: rejected name='\(f.name)' — non-action label")
       return
   }
   ```
3. Sprawdź że `TooltipObserver.containsSensitiveText` można teraz uprościć
   (PrivacyFilter pokrywa ten sam zakres). Opcjonalne — zostaw dla teraz,
   refaktor po build.
4. Build + run testy: `xcodebuild test -scheme SFlow` (lub Cmd+U w Xcode).
   Oczekuję **285+ testów passing** (256 baseline + 33 nowe B.1).
5. Manual sanity: otwórz Notion Mail → najedź na ikonkę Compose → klik →
   toast OK (B regression check). Otwórz Comet → cokolwiek → czekaj 30s
   → kliknij — sprawdź `events.jsonl` że nowych entries z `hint="shortcut"`
   nie ma (false-positive scrubbed).
6. Commit: `feat(client): integrate TooltipNameFilter + PrivacyFilter (B.1)`
7. Update statusów: Sub-cel 1.29 🟡 → 🟢; w `audit-phase-0.md` P-39
   ⬜ → 🟢, P-40 ⬜ → 🟢.

### Acceptance criteria U-1
- [ ] 285+ testów passing
- [ ] `events.jsonl` z 1 dnia użycia po fix nie zawiera fałszywych
      `hint="shortcut"`
- [ ] WhatsApp/Notion content w `events.jsonl` jest `[REDACTED]` zamiast
      raw text
- [ ] Notion Mail tooltipy nadal działają (Compose → toast "C")

---

## Atomic plan — Sesja U-2 (Right-click, ~3h)

### Cel
Pokryć **klasę** skrótów dostępnych w context menu po prawym kliku — we
**wszystkich** apkach naraz, bez per-app pracy.

### Adresowane
- Sub-cel 1.18 → 🟢 done
- P-41 → 🟢 done

### Kroki

1. **Rozszerz event mask w `ClickWatcher.setup()`:**
   ```swift
   let mask = CGEventMask((1 << CGEventType.leftMouseDown.rawValue) |
                          (1 << CGEventType.rightMouseDown.rawValue))
   ```

2. **W `tapCallback`:**
   ```swift
   if type == .leftMouseDown || type == .rightMouseDown {
       sharedWatcher?.handleMouseDown(rightClick: type == .rightMouseDown)
   }
   ```

3. **Modyfikuj `handleMouseDown` o flag `rightClick: Bool`:**
   - Dla left-click: zachowanie obecne (pipeline L0..L4)
   - Dla right-click: **zarejestruj że za chwilę pojawi się AXMenu** —
     uruchom 1-time observer który po 300ms (delay renderu menu) skanuje
     focused-app AX tree szukając `AXMenu` z `AXMenuItem` dziećmi
   - Dla każdego `AXMenuItem`: czytaj `kAXTitle` + `kAXMenuItemCmdChar` +
     `kAXMenuItemCmdModifiers` → zapisz do `DiscoveredStore` z rect dziecka

4. **Bonus — natychmiastowe wyświetlanie toastu dla pozycji menu pod
   kursorem:** gdy user porusza myszą po pozycjach menu, ostatnia hovered
   `AXMenuItem` rect → po kliknięciu zwykłą lewy click logiką L0.3 trafia
   match z DiscoveredStore.

5. **Nowy plik testowy:** `SFlowTests/RightClickMenuHarvestTests.swift` —
   mockuje `AXMenu` z dziećmi, weryfikuje że `kAXMenuItemCmdChar` jest
   poprawnie czytany i zapisywany do `DiscoveredStore`.

### Acceptance criteria U-2
- [ ] Prawy klik w **Notion** → context menu → klik w "Open in side peek"
      → toast pokazuje skrót (Notion ma `⌘+enter` lub coś)
- [ ] Prawy klik w **Comet** → "Open link in new tab" → toast (⌘klik)
- [ ] Prawy klik w **Finder** na pliku → "Open With..." → toast jeśli
      menu ma skrót
- [ ] `events.jsonl` zawiera nowy `layer="L0.3"` entries z `source="rightclick_menu"`
- [ ] Zero regresji w lewym kliknięciu

---

## ROI re-ranking — precyzyjny scoring (2026-05-16 offline)

Po stworzeniu atomic plans dla U-3..U-6, mam więcej danych o realistycznym
koszcie i wartości. Re-ranking z 4-osiowym scoringiem:

**Wymiary:**
- **Koszt (K):** godziny (1-10, gdzie 10 = max 10h+)
- **Coverage (C):** ile apek dostaje korzyść (1-10, gdzie 10 = wszystkie)
- **Pewność działania (P):** czy mechanizm na pewno zadziała (1-10, gdzie
  10 = trywialne, 5 = wymaga empirycznego probe, 1 = niepewne)
- **Wartość dla usera (W):** jak ważne dla typowego usera (1-10, gdzie
  10 = przełomowe, 5 = nice-to-have, 1 = niche)

**Wzór ROI:** `(C × P × W) / K` — wyższy = lepszy.

### Tabela ROI

| Sub-cel | Sesja | K (h) | C (apek) | P (cert) | W (user) | **ROI** |
|---|---|---|---|---|---|---|
| 1.29 B.1 finalize | U-1 | 0.5 | 9 (wszystkie) | 10 | 8 | **1440** |
| 1.18 Right-click | U-2 | 3 | 10 (wszystkie) | 9 | 9 | **270** |
| 1.21 Single-key | U-3 | 2 | 4 (Notion/Cron/Obsidian) | 8 | 7 | **112** |
| 1.17 P-38 MenuItem (C.5) | (Faza 1) | 6 | 9 (z dropdownami) | 7 | 8 | **84** |
| 1.19 Web-as-app | U-4 | 7 | 10 (web apek) | 5 (empiryczny probe wymagany) | 9 | **64** |
| 1.22 Modal scope | U-6 | 6 | 6 (apek z dialogami) | 8 | 5 | **40** |
| 1.20 i18n | U-5 | 8 | 4 (per locale × apka) | 7 | 6 | **21** |
| 1.23 Tool/mode | U-7 | 5 | 4 (creative apek) | 6 | 6 | **29** |
| 1.24 Office eval | U-8 | 10 | 5 (Office) | 7 | 7 | **24** |
| 1.25 Adobe eval | U-9 | 10 | 3 (Adobe) | 4 | 6 | **7** |
| 1.26 Qt eval | U-10 | 6 | 3 (Qt) | 5 | 4 | **10** |
| 1.27 Catalyst eval | U-10 | 4 | 4 (Catalyst) | 8 | 3 | **24** |
| 1.28 SwiftUI eval | U-10 | 2 | 2 (SwiftUI) | 9 | 4 | **36** |

### Wnioski z re-rankingu

1. **U-1 (B.1 finalize)** ma DRAMATYCZNIE wyższy ROI (1440) — to nie
   przypadek. Kod gotowy, jeden commit, pokrywa false-positives WSZYSTKICH
   apek z L0.3 + całe PII redaction. **Zawsze pierwsze.**

2. **U-2 (Right-click)** na 2. miejscu (270) — wysokie K=3h ale ogromne C=10
   apek + P=9 (kAXMenuItemCmdChar natywne, zero heurystyki). **Drugie.**

3. **U-3 (Single-key)** na 3. miejscu (112) — bardzo tanie K=2h ale węższe
   C=4. **Trzecie, można robić w przerwach.**

4. **U-4 (Web-as-app)** spada z miejsca #3 na #5 (ROI=64) ze względu na **P=5**
   (empiryczny probe AX wymagany, ryzyko że AXURL nie istnieje). Pre-flight
   probe redukuje ryzyko — po nim ROI rośnie do ~130.

5. **U-5 (i18n)** ma ROI=21 — najniższy z priorytetów. Coverage wąski (per
   locale × apka), wymaga reseedu + deploy backend. **Odłożyć** dopóki nie
   pojawi się non-EN beta-tester sygnalizujący ból.

6. **U-10 SwiftUI eval** ma zaskakująco wysokie ROI (36) — tanie K=2h, wysoka
   P=9 (Sesja A już to robi via kAXValue fallback). Skipowane jako "niche
   target", ale **w 2h dostajemy weryfikację** że Apple's nowe apki działają.

7. **Eval Adobe** (ROI=7) — najniższy ze wszystkich. **Odłożyć** dopóki U-7
   (tool/mode switching) nie pokryje toolbox use case. Bez U-7 eval Adobe
   to strzelanie w martwe pole.

### Zalecana sekwencja na podstawie ROI

**Sprint 1 (~5.5h):**
- U-1 (B.1 finalize) — 30 min
- U-2 (Right-click) — 3h
- U-3 (Single-key) — 2h

**Sprint 2 (~9h):**
- U-4 pre-probe (Filip uruchamia probe script) — 30 min
- U-4 (Web-as-app) — 6-8h jeśli probe OK

**Sprint 3 (~10h):**
- U-6 (Modal scope) — 6h
- U-7 (Tool/mode dla creative) — opcjonalnie po U-2 — 5h

**Sprint 4 (~14h):**
- U-10 SwiftUI + Catalyst eval — 6h
- U-8 Office eval — 10h (cherry-pick top 3: Excel + Word + Outlook)

**Świadomie odłożone:**
- U-5 (i18n) — czeka na non-EN beta-tester sygnał
- U-9 (Adobe eval) — czeka na U-7 (tool/mode) by mieć z czym test

**Łącznie 4 sprinty:** ~38h (vs original estimate ~55-70h). Optymalizacja
przez ROI.

---

## Cross-reference

- **Pełna analiza dziur:** `docs/universality-gaps-and-windows-2026-05-16.md`
- **Stan obecnej uniwersalności (przed Fazą 1.5):** `docs/universality-analysis-2026-05-16.md`
- **Plan B.1 (integracja w U-1):** `docs/superpowers/plans/2026-05-16-tooltip-scrubbing-and-privacy.md`
- **Plan C.5 (P-38, dropdown menu — już zaplanowany jako 1.17):** `docs/superpowers/plans/2026-05-16-menu-item-observer.md`
- **Faza 2 (gdzie idziemy po Fazie 1.5):** `docs/roadmap.md` § Faza 2

---

*Status: świeży audyt Fazy 1.5. Następny krok: U-1 (B.1 integracja, ~30 min)
jako warm-up przed głównymi sesjami U-2..U-10.*
