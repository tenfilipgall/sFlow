# SFlow — roadmap budowy (drogi B + E z dodatkiem A)

> Plan kierunkowy. Dokument ma odpowiedzieć: **co po kolei robimy, żeby dojść
> z obecnego stanu do produktu który uczy userów skrótów i da się sprzedawać**.
>
> Dokument decyzyjny — nie spec implementacyjny. Każda faza zostanie potem
> rozpisana na osobny spec + plan (jak v1.0, v1.1).
>
> **Druga wersja** (2026-05-13 wieczór) — po sprawdzeniu kodu okazało się że
> auto-discovery jest już zbudowane, a "tryb cichy" toasta sam się rozwiązuje.
> Skrócone Fazy 1 i 3.

---

## Założenie kierunkowe

Z `product-vision.md`: budujemy **drogę B (personalizowana nauka)** jako core
produktu. **Droga E (raport/heatmap)** jako naturalne uzupełnienie. **Droga A
(intro toast + onboarding)** jako warstwa wejścia — pierwsze 1–2 tygodnie usera.

**Sekwencja jest święta.** Nie buduj B zanim nie zadziała Faza 1 (jakość
pokrycia). Nie buduj E zanim nie ma danych z B. Nie sprzedaj nikomu nic
zanim nie ma A+B+E zaprojektowanych jako jedna historia.

---

## Proces ciągły (rituals i workflow)

> **AI: Przeczytaj tę sekcję na początku każdej sesji. Stosuj się.**

### A. Czytanie kontekstu na start każdej sesji

Pierwsza czynność każdej nowej sesji = **przeczytać 4 pliki równolegle**:

```
docs/product-vision.md       ← zasady współpracy + wizja produktu
docs/roadmap.md              ← plan fazowy + ta sekcja
docs/audit-phase-0.md        ← stan kodu + lista problemów (P-X)
docs/audit-phase-1.md        ← sub-cele Fazy 1 + statusy
```

Cel: AI ma wiedzieć **na jakim etapie jesteśmy**, **co zrobione**, **co
następne**, zanim cokolwiek zaproponuje. Bez tego ryzykuje że poleci robić
rzecz która już jest zrobiona albo poza obecnym scope'em.

### B. End-of-session protocol (po każdej sesji)

Kiedy sesja kończy się ze zmianami w kodzie, AI MUSI:

1. **Zaktualizować statusy** w `audit-phase-0.md` (problemy P-X) oraz
   `audit-phase-1.md` (sub-cele). Symbole:
   - ⬜ pending (nie zaczęte)
   - 🟡 in-progress (zaczęte, niedokończone — opisać czego brakuje)
   - 🔵 partial (działa częściowo — opisać co działa a co nie)
   - 🟢 done (zrobione + zweryfikowane)
   - 🔴 regression (cofnięte z poprzedniego statusu — opisać dlaczego)

2. **Dopisać wpis do "Session log"** (sekcja niżej) — reverse-chronological,
   najnowszy na górze.

3. **Scommitować razem** z kodem jednym dodatkowym commitem o nazwie
   `docs: session log + status update [v.X.Y.Z]` lub w osobnym jeśli
   commit kodu już istnieje.

### C. Video-based quality eval (okresowo)

Patrz `docs/audit-phase-1.md` Sub-cel 1.8. AI **proaktywnie sugeruje**
Filipowi nagranie 60-90s screen recordingu jeśli:

- Minęła >1 sesja od ostatniego video evalu
- Wprowadzono zmianę w `backend/src/prompt.ts` lub `dedup.ts`
- Reseedowano apkę w `bundled.json`

Filip nagrywa MP4 (CleanShot), wrzuca do repo (gitignored), AI uruchamia
analizę klatek (Swift+AVFoundation), raportuje:

- ✅ toasty które wystrzeliły poprawnie
- ❌ kliknięcia bez toasta (chybienia) — porównać z `events.jsonl`
- ⚠️ toasty z błędnymi keys/hintami (jeśli widać hover-tooltip w klatce)

Wyniki idą do `docs/coverage-report.md` (jeśli istnieje) i jako wpis
w session log.

### D. Rekomendacje + decyzje

Zasady w `product-vision.md` sekcja 0.2-0.3. Skrót:

- Każda rekomendacja uzasadniona przez cel z roadmap albo decyzję z vision
- Pytania zawsze multi-choice (`AskUserQuestion`) z rekomendacją w pierwszej opcji
- Tłumacz jak 12-latkowi (analogie, polski, technika w nawiasach)

### E. Co AI robi samodzielnie vs co pyta

Patrz `product-vision.md` sekcje 0.7-0.8. Najważniejsze:

- **Robi sam:** edycje, testy, commit do main, reseed, eksperymenty
- **Pyta:** deploy backendu, kasowanie historii, zmiany cenowe,
  rzeczy poza scope obecnego sub-celu

---

## Session log

> **Reverse-chronological — najnowsza sesja na górze.**
> AI dodaje nową sekcję po każdej sesji ze zmianami w kodzie.

### 2026-05-17 — Audyt 4 dokumentów + poprawki sekwencjonowania (meta, bez kodu)

**Co:** Filip wskazał priorytet "rozpoznawanie elementów w oknach + toast display dla wszystkich apek". Pełny audyt `audit-phase-0.md` + `audit-phase-1.md` + `roadmap.md` + `product-vision.md` ujawnił 11 luk dokumentacyjnych. Wykonane 5 poprawek surgicznie:

1. **P-49 sformalizowany** w `audit-phase-0.md` — Slack multi-monitor toast blocker (do tej pory wiszący bez numeru P-X jako "Outstanding bug"). Krytyczny dla Fazy 1.7 beta.
2. **"Outstanding bugs"** w audit-phase-0 + **"Outstanding issues"** w roadmap zlinkowane z P-49.
3. **Graf zależności Faza 1 ↔ 1.5 ↔ 1.6 ↔ 1.7** dodany na początku sekcji Fazy 1.5. Reguła: Faza 1.5 i 1.6 idą **równolegle**, Faza 1.7 czeka na P-49 + ≥10 verified apps (zmniejszone z 20 dla beta MVP).
4. **U-5 (i18n) podniesione z MEDIUM na HIGH** — uzasadnienie: polski UI Slack/Notion daje 0% pokrycia bez i18n, beta sygnał niewiarygodny.
5. **P-49 wstawione w sekwencji U-1..U-7** jako #2 (zaraz po U-1 B.1) — przed U-2/U-3/U-4.

**Dlaczego:** dokumentacja była aktualna ale **niespójna w 5 miejscach** (Slack toast bez P-numeru, kolejność Faza 1.5 vs 1.7 niejasna, i18n nie pasowała do polskiego ICP, brak grafu zależności). Audyt zamknął te luki przed dziś wieczorem sesją techniczną U-1.

**Następny krok:** Sesja U-1 (B.1 integracja, 30 min) → P-49 fix (~2h, multi-monitor) → U-2 (right-click, 3h). Sekwencja zatwierdzona przez Filipa.

### 2026-05-16 — T2 (diagnoza, bez kodu): Dropdown menu items nie są tapowane (P-38)

**Co:** Filip pokazał screenshot z Notion Calendar — dropdown otwarty po kliknięciu „Week" z pozycjami `Day` (1 or D), `Week` (0 or W), `Month` (M), `Number of days` (>), `View settings` (>). SFlow nie pokazuje toasta dla żadnego z nich mimo aktywnej Sesji B.

**Diagnoza (z `TooltipObserver.swift` + `TooltipShortcutParser.swift`):** 4 niezależne powody — (1) `walk()` nie iteruje po `AXMenu`/`AXMenuItem` (poza białą listą `containerRoles`), (2) `isTooltipShape` wymaga 40–500×16–100 px (menu ~280×400 — za wysokie), (3) `parseTooltipTexts` wymaga 2 oddzielnych `AXStaticText` (nazwa + badge) — `AXMenuItem` ma title+shortcut na jednym elemencie, (4) `TooltipShortcutParser` nie rozumie formatu „X or Y" (alternatywne skróty).

**Decyzja architekturalna:** to jest **trzecia osobna ścieżka discovery**, nie rozszerzenie TooltipObservera:
- Menu bar → `MenuBarWatcher` przez `kAXMenuItemCmdChar` ✅
- Window button tooltips → `TooltipObserver` L0.3 ✅ (Sesja B)
- Window dropdown menus → **brak**, planowany `MenuItemObserver` (Sub-cel 1.17 / Sesja C.5)

**Dodane do dokumentacji:**
- `audit-phase-0.md`: nowe P-38 w tabeli statusów + pełny opis na końcu listy problemów (4 powody blokady, plan 3-etapowy)
- `audit-phase-1.md`: nowy Sub-cel 1.17 w tabeli statusów + Sesja C.5 w execution sequence (po Sesji C)
- `product-vision.md`: notka w sekcji 3 snapshot
- `roadmap.md`: ten wpis

**Decyzja go/no-go:** zależy od wyników testu Sesji B na Linear/Discord/Slack/Notion main (memory `next-session-2026-05-16`). Jeśli dropdowny to >20% missów na tych apkach → priorytet ŚREDNIA-WYSOKA i robimy Sesję C.5 zaraz po C. Jeśli marginalne — Faza 2.

**Zero zmian w kodzie.** Diagnoza + plan only.

### 2026-05-16 — T1 (w toku, weryfikacja jutro): LLM video eval `--llm` flag

**Co:** Dokończenie Sub-celu 1.8 Droga B (audit-phase-1.md row 1.8). Pasywna ścieżka rozumiana jak "stripy → AI manualnie czyta" (Droga C) → automatyczna ścieżka "klatki → Claude vision per frame → raport markdown" (Droga B).

**Nowe pliki (~280 LOC):**
- `scripts/sflow-video-llm.swift` — czyta `f_*.png` z katalogu, base64-enkoduje, POST do Anthropic API per klatka (concurrency 5 via DispatchSemaphore), agreguje per-(action, keys, app), pisze strukturyzowany `docs/video-eval-<ts>.md` z tabelami Toast hits / Native tooltips / Timeline (consecutive identical states collapsed).

**Modyfikacje:**
- `scripts/sflow-video-eval` — flagi `--llm/--model/--concurrency/--report/--no-strips`, backward compatible z pozycyjnym intervalem. `--llm` woła `sflow-video-llm.swift` po extract'cie klatek.

**Pipeline test 2026-05-15 wieczór:**
- 32 klatek z 32s screencast'a (CleanShot, Slack/Xcode/Google Chat aktywne)
- Po fixie błędnego klucza API w env: 0 errors, raport wygenerowany, struktura OK
- **Issue znaleziony przez Filipa:** 4 wykryte SFlow toasty (Remind me ?, Mark unread U, Copy link L, Quick Switcher ⌘K) **nie istniały w wideo** — Claude (Haiku 4.5) zinterpretował pozycje natywnego context menu Slacka (right-click → lista z klawiszami po prawej) jako SFlow toasty.

**Prompt v2 (rozwiązanie):** Ścisła definicja w `analysisPrompt`:
- Pozytywna: "standalone overlay floating ON TOP of the app, OUTSIDE any menu/dropdown/list"
- 5 jawnych negacji z przykładami: context menu / command palette (⌘K) / menu bar dropdown / native tooltip / help overlay
- Golden test: "Is this a SINGLE compact pill, separate from any menu?"
- Bias: "false negatives MUCH better than false positives"

**TODO 2026-05-17 (Filip):**
1. `./scripts/sflow-video-llm.swift /tmp/sflow_video_eval_20260515T164056 docs/video-eval-test.md` — re-run na istniejących klatkach z promptem v2. Oczekiwane: 4 halucynowane toasty znikają z "Toast hits summary".
2. Nagrać krótki screencast Notion Mail (po Sesji B verify): kliknięcia w Compose/Archive/Reply/Forward. Puścić `./scripts/sflow-video-eval <video> --llm` end-to-end.
3. Jeśli oba OK → status 1.8 🔵→🟢.

**Acceptance criteria sub-celu 1.8 (z audit-phase-1.md):**
- [x] `scripts/sflow-video-eval` istnieje i działa (Droga C minimum)
- [x] `.gitignore` zawiera `*.mp4`
- [x] (Droga B) `--llm` flag wywołuje Claude vision per klatka
- [ ] Wykonano ≥1 video eval z udokumentowanymi findings w session log ← **TODO jutro**

**Pliki dotknięte:** `scripts/sflow-video-llm.swift` (nowy), `scripts/sflow-video-eval` (modyfikacja), `docs/audit-phase-1.md` (status row 1.8). **NIE dotknięto** żadnych plików ze ścieżki Sesji A/B/C — pełna izolacja od głównego terminala.

**Coś niezamknięte na czysto:** plik `docs/video-eval-test.md` (raport z prompt v1, z halucynacjami) zostawiony — po pozytywnej weryfikacji jutro można zostawić jako proof-of-concept albo zmienić nazwę na `docs/video-eval-20260515T1640-slack-poc.md`. **Decyzja Filipa.**

### 2026-05-15 (wieczór) — Sesja B verified + 4 iteracje fix'ów

**Verified end-to-end** na 2 apkach:
- **Notion Mail** (5/5 testowanych ikonek): Compose [c], Archive [e], Close sidebar [meta+\\], Reply [r], Forward [f] — wszystkie emit'ują toast via warstwę L0.3 po hoverze.
- **Notion Calendar**: również działa po dorobieniu split-badge parser (Notion Calendar wystawia `["⌘", "\\"]` jako 2 osobne AXStaticText, nie jeden `"⌘+\\"` jak Notion Mail).

**4 fix'y iteracyjne (z empirycznych testów Filipa):**

1. `+` separator w parserze badge'a (`⌘+\\` → meta+\\). Notion Mail tooltipe piszą explicit `+` między modyfikatorem a klawiszem. Plus zmiana max length 6→8.
2. Hit-test pod kursorem zamiast tooltip-rect — tooltip flot'uje obok przycisku, click coords land'ują na przycisku. Hit-test `AXUIElementCopyElementAtPosition` zwraca frame przycisku (typowo 22×23 px) używany jako rect zapisany w DiscoveredStore.
3. Sanity-check rect size >200×200 → fallback 36×36 cursor-centered. Chromium czasami zwraca cały kontener paneli widoku (810×809) jako hit-test response; bez sanity check'a fałszywie strzela Reply toastem dla każdego kliku w panelu.
4. Split-badge parser — łączy WSZYSTKIE krótkie AXStaticText fragmenty przed parsowaniem (Notion Calendar wystawia modyfikator i klawisz osobno).

**Tests:** 256 passing (+37 vs baseline 219), 0 failed.

**Verbose debug toggle:** `defaults write com.filip.sflow tooltipDebug -bool true|false`. Bez verbose, production logi to: init / candidate / recorded / rejected / L0.3 HIT.

**Decyzja na następną sesję:** Filip ma przetestować B na innych Chromium apkach (Linear, Discord, Slack-nowy, Notion main) zanim zaczniemy Sesję C (backend crowdsource). Jeśli B = generic killer feature → C uzasadniona, jeśli tylko Notion-rodzina → C czeka. Patrz memory `project_next_session_2026_05_16` dla pełnego planu.

### 2026-05-15 — Sesja B (complete): TooltipObserver — passive React-portal tooltip scraping

**Co:** Nowa warstwa rozpoznawania `L0.3 tooltipObserver` — pasywnie obserwuje React-portal tooltipy w focused app i emit'uje toast przy kliku w obszar, gdzie wcześniej był tooltip. Adresuje P-37: Notion Mail (i każda inna Chromium-bazowana React-app z własnymi tooltipami) nie wystawia accessible name dla ikonkowych przycisków, ale **renderuje tooltipy** zawierające parę (nazwa akcji + skrót). Te tooltipy żyją w drzewie AX jako floating AXGroup z dwoma AXStaticText.

**Nowe pliki (~430 LOC):**
- `SFlow/TooltipShortcutParser.swift` — pure function, parsuje badge tooltipa (`"C"`, `"⌘\\"`, `"⇧R"`, `"⌘⇧K"`) → `[String]`. Rzecz wymaga dokładnie 1 znaku-klucza po opcjonalnych modyfikatorach (⌘⇧⌥⌃) — odrzuca "Hello", "Compose" jako szum.
- `SFlow/DiscoveredStore.swift` — persistent in-memory store. Zapis do `~/Library/Application Support/SFlow/discovered/{bundleId}.jsonl`. Lookup po pozycji kursora w prostokącie z buforem 6px. De-dup w oknie 5s (cursor pause re-skanuje ten sam tooltip wielokrotnie). Cap 2000 entries w pamięci.
- `SFlow/TooltipObserver.swift` — polluje pozycję kursora co 200ms (cleaner niż CGEventTap na mouseMoved). Scan fire'uje gdy: cursor stabilny ≥350ms (delay renderu tooltipa) + nie skanowaliśmy w ostatnich 500ms (rate-limit). Walk drzewa AX frontmost app głębokość 8, szuka `AXGroup` z prostokątem 40-500×16-100 w promieniu 350px kursora, parsuje wewnątrz AXStaticText'y. Privacy filter: odrzuca tooltipy z `@`, URL, datami ISO, długimi tekstami (>80 znaków).

**Modyfikacje:**
- `SFlow/ShortcutEvent.swift` — dodany `case tooltipObserver = "L0.3"`.
- `SFlow/ClickWatcher.swift` — na początku `handleMouseDown`, przed całym walk'iem AX, query `DiscoveredStore.shared.lookup(near: cursorAX)` — jeśli match, emit i return. To staje się **najsilniejszą warstwą po L0** (AXKeyShortcuts), bo tooltipe to direct user-facing signal.
- `SFlow/AppDelegate.swift` — `tooltipObserver = TooltipObserver()` w `startWatcher()`.

**Testy:** 33 nowe (`TooltipShortcutParserTests` 13, `TooltipObserverParseTests` 13, `DiscoveredStoreTests` 7). **252 testy passing**, 0 failed.

**Dlaczego:** Sesja A potwierdziła empirycznie że dla Notion Mail Chromium nie eksponuje dzieci ikonkowych AXButton — `subtreeLabel` zostaje puste mimo naprawionego fallbacku. Jedyną drogą do tych etykiet są tooltipe które Notion sam pokazuje na hoverze. Sesja B otwiera **nową, asymetryczną warstwę zdobywania reguł** niezależną od Claude'a — działa dla apek których jeszcze nikt nie eval'ował.

**Verification plan dla Filipa:**
1. Zbuduj z Xcode (Cmd+R)
2. Otwórz Notion Mail. Najedź ~500ms na ikonkę Compose (czekaj aż pojawi się czarny tooltip „Compose a new email" + „C")
3. Następnie kliknij Compose
4. **Oczekiwany rezultat:** toast „C — Compose a new email" (layer L0.3)
5. Powtórz dla Archive (⌘) ikony przy mailu i Close sidebar (top-left)
6. `~/Library/Application Support/SFlow/discovered/notion.mail.id.jsonl` powinien rosnąć z każdym tooltipem
7. **Jeśli nie działa**: dwa zwykłe powody — (a) Chromium nie wystawia tooltipów do drzewa AX (wtedy `discovered/...jsonl` jest puste mimo poprawnego buildu); (b) heurystyka rozmiaru/pozycji nie pasuje do Notion Maila (debug: dorzucić jednorazowy NSLog w `scanForTooltip` żeby zobaczyć co AX widzi)

**Sesja C (backend) zostawiamy:** najpierw zweryfikujemy że B faktycznie łapie tooltipe Notion Maila. Jeśli tak — bez problemu robimy C (crowdsource). Jeśli nie — debugujemy heurystykę albo wracamy do Sesji A5 (rich parent-log).

---

### 2026-05-15 — Sesja A (complete): Chromium AX deep fallback + miss-log enrichment

**Co:** Naprawa 4 dziur w `ClickWatcher.swift` plus wzbogacenie `MissEvent` o nowe pola — adresuje P-36 (Notion Mail i podobne Electron-apki, gdzie ikonkowe `AXButton` mają puste accessible names).

(A1) Usunięto gate `depth > 0` w warunku fallbacku w `ClickWatcher.swift:241`. Hit-test depth=0 też schodzi do dzieci, jeśli ma puste title+desc.

(A2) Rozszerzony `extractFallbackTitleFromChildren` o czytanie `kAXValueAttribute` (gdzie AXStaticText trzyma swój widoczny tekst — nie w kAXTitle). `kAXValue` honorowane tylko dla static-text-like ról (AXStaticText/AXLink/AXImage), cap 100 znaków (nie wciągamy textarea'ów).

(A3) 1-level rekurencja w skanie dzieci dla kontenerowych ról (AXGroup/AXImage/AXButton) — Chromium często ma AXButton→AXGroup→AXStaticText.

(A4) `kAXValueAttribute` czytane na głównym elemencie pętli `handleMouseDown`. Gdy effectiveTitle pusty i element to static-text-like rola → `currentValueAsLabel` używany jako effectiveTitle.

(A5) `MissEvent` wzbogacony o pola: `identifier` (kAXIdentifier — `data-testid` z React), `value` (kAXValue), `roleDescription`, `customActions`, `subtreeLabel` (concatenated co znalazł skan dzieci). `EventLogger.logMiss` zapisuje wszystkie do `events.jsonl`. Custom init w MissEvent z defaultami zachowuje backward-compat dla istniejących testów.

**Dodatkowo:** `project.yml` — dopisane `GENERATE_INFOPLIST_FILE: YES` do SFlowTests (build pokazał błąd o brakującym Info.plist).

**Build/test:** 219 testów passing, 0 failed (bez regresji). Pełny build wymaga GUI Xcode (jedyne dostępne signing identity to "Apple Development", xcodebuild wymaga "Mac Development" dla CLI signed buildu).

**Dlaczego:** sesja diagnozy (2026-05-15) potwierdziła empirycznie że w Notion Mail (Electron) toasty pojawiają się tylko z menu bara, nie z okna. `events.jsonl` pokazał missy `{role:"AXButton", title:"", desc:"", help:""}`. Probe żywego drzewa AX potwierdził: Chromium nie eksponuje accessible name na ikonkach bez `aria-label`. Sesja A to tania (~50 LOC) naprawa fundamentu — jeśli zadziała, odblokuje większość ikonkowych przycisków we wszystkich Electron/Chromium apkach. Jeśli częściowo, A5 daje dane do iteracji (Notion `data-testid` widoczny w `identifier`, label w `subtreeLabel`).

**Verification plan dla Filipa:**
1. Zbuduj z Xcode (Cmd+R)
2. Otwórz Notion Mail, klikaj różne ikonki w oknie (Compose, Close sidebar, Archive, Search itd.)
3. Sprawdź czy pojawiają się toasty (powinny dla Compose/Archive/Sidebar — mamy reguły w `ShortcutRules` `notion.mail.id`)
4. `~/Library/Application Support/SFlow/events.jsonl` — jeśli miss się jednak zdarzy, powinien teraz mieć wypełnione `identifier`, `value`, `subtreeLabel` zamiast pustek

**Dlaczego:** sesja diagnozy (2026-05-15) potwierdziła empirycznie że w Notion Mail (Electron) toasty pojawiają się tylko z menu bara, nie z okna. `events.jsonl` pokazał missy `{role:"AXButton", title:"", desc:"", help:""}`. Probe żywego drzewa AX potwierdził: Chromium nie eksponuje accessible name na ikonkach bez `aria-label`. Sesja A to tania (~50 LOC) naprawa fundamentu — jeśli zadziała, odblokuje większość ikonkowych przycisków we wszystkich Electron/Chromium apkach. Jeśli częściowo, A5 da nam dane do iteracji.

**Plan kontynuacji (B → C → D opcjonalna):**
- **Sesja B**: `TooltipObserver` — pasywnie wykrywa React-portal tooltipy (np. "Compose a new email / C" z hovera) i wpisuje do `discovered/{bundleId}.jsonl`. Click-time fallback "L2.5" — emit z tooltipa jeśli widoczny.
- **Sesja C**: backend `/v1/discovered` endpoint + agregator. Crowdsourced: jeden user hoveruje → wszyscy dostają regułę.
- **Sesja D (opcjonalna)**: dev-only tryb `--seed-app` z syntetycznym hoverem dla zespołu SFlow.

### 2026-05-15 — Sesja 9a (complete): P-34 Claude streaming + max_tokens

**Co:** Naprawa generacji reguł dla wielkich apek (Android Studio i podobne).

(1) `max_tokens: 8192 → 32768` w `backend/src/claude.ts` (commit `16f180d`).
(2) Switch `client.messages.create()` → `client.messages.stream() + finalMessage()` — Anthropic SDK wymaga streamingu dla operacji z `max_tokens > 8192` (ochrona przed HTTP timeoutami). Bez streamingu SDK natychmiast odrzuca call błędem 502 "Streaming is required for operations that may take longer than 10 minutes". Pozostała część pipeline'u (parseRulesJSON, extractFinalText) niezmieniona — `finalMessage()` zwraca regularny Message.

**Dlaczego:** P-34 oznaczona w sesji 8 jako gating issue dla nowych użytkowników z wielkimi apkami w autostarcie (Android Studio, JetBrains stack, Xcode-like Electron apps). Bez fixu backend zwracał 502 i klient utykał w Failed apps z myląco-brzmiącym "Server error or no internet".

**Manual eval (12:42):** Android Studio → kliknięcie Try again → discovery ~90 sekund streaming → **93 reguły** wygenerowane → apka przeniesiona do Learned ✅.

**Bonus — P-35 prawdopodobnie też naprawione:** poprzednie timeouty (DisplayTuner) najpewniej były tym samym problemem (Anthropic odrzucał calle z innych powodów ale dłuższym czasem). Status P-35 → 🔵 partial pending verification na DisplayTuner.

**Backend deployed:** version `6f489e00-3c59-4f2b-a458-b4692e38f14c` na `https://sflow-rules.shortcutflow.workers.dev`. 50/50 testów backend passing.

**Następny krok (sesja 9b):** P-32 (ukierunkowany web research w backend prompt) + verify P-35 na DisplayTuner + reseed 5 bundled apek nowym promptem.

### 2026-05-15 — Sesja 8 (complete): P-2/P-3 discovery retry + Apps tab

**Co:** Persistowany retry + backoff dla nieudanej discovery (P-2) plus UI feedback dla failed status (P-3). 13 atomic tasks TDD + 4 follow-up fixes.

(1) `DiscoveryFailureReason` enum (6 cases: emptySkeleton, emptyMenuBar, rateLimited, httpError, parseError, noRulesGenerated) + 5 testów mapowania z DiscoveryClientError.

(2) `DiscoveryAttemptStore` — atomic write do `attempted.json` (`~/Library/Application Support/SFlow/`), backoff 1h/24h/7d/30d (cap), canAttempt/recordFailure/recordSuccess/forceRetry, mock clock + 10 testów (skeleton, każdy backoff bucket, persistence round-trip, time-travel clock).

(3) `DiscoveryService` przepisany: canAttempt gate, 15s pre-check gdy skeleton<3 + menu empty, klasyfikacja errorów do reason, recordSuccess po success, `NotificationCenter` event po każdej zmianie stanu, forceRetry public API z guard "launch app first" PRESERVUJĄCY entry gdy app not running (Bug 1 fix).

(4) `AppDelegate.shared` + wstrzyknięcie store **WCZEŚNIE** w applicationDidFinishLaunching (przed setupStatusItem — fix bo Settings → Apps mogło zwracać empty gdy store jeszcze nie istniał).

(5) `AppsTab` SwiftUI — 3 sekcje (bundled / learned / failed) z `Try again` button. Display name z Info.plist via Launch Services (NSWorkspace.urlForApplication) gdy apka nie działa — zamiast bundleId tail "studio". Ukryta za toggle `showDeveloperFeatures` w Advanced.

(6) menuBar/skeleton capped at 500 items klient-side (backend Zod max(500) — Android Studio z 575 items zwraca 400 Bad Request).

**Dlaczego:** P-2/P-3 oznaczone w audycie jako WYSOKA priorytet — pierwszy user który aktywuje Notion 5s po starcie systemu miał trwale zepsute reguły do końca 90-dniowego cache. Z backoffem auto-retry naprawia sam, a beta-tester ma manual override.

**Manual eval ujawnił 2 nowe problemy backendowe (przeniesione do Sesji 9):**
- **P-34**: Android Studio — Claude max_tokens 8192 truncation → backend 502 non-JSON. Fix: zwiększyć max_tokens w `backend/src/claude.ts`.
- **P-35**: DisplayTuner — backend timeout 90s. Diagnoza wymaga inspekcji backend latency logów.

**Pre-check 15s WERYFIKOWANE działa:** AppCleaner wszedł z `skeleton=0, menu=0` → wait 15s → `skeleton=127, menu=150` → callBackendAndStore.

**Wpływ:** Eliminuje gating issue dla bety (P-2/P-3 były WYSOKA priorytet). Apps tab ukryty domyślnie, nie zaśmieca UI zwykłym userom. **219 testów passing**, 15 nowych (z 198 baseline).

**Commits:** patrz `git log --oneline` od `098a726`.

**Następny krok (sesja 9):** Bundle C — P-32 (ukierunkowany web research w backend prompt) + P-34 (max_tokens) + P-35 (timeout diagnoza) + reseed 5 bundled apek nowym promptem.

### 2026-05-14 — Sesja 7: Coverage Quick Wins (P-31 część 1)

**Co:** 3 niezależne, additive fixy rozszerzające detection surface (bez czekania na dane z events.jsonl).
(1) `AXUIElementCopyActionNames` probe + `elementHasAXPress` helper + `hasAXPress` parametr w `shouldRunNonInteractiveLayers` — element z akcją AXPress traktowany jako klikalny niezależnie od role (catches Chromium AXImage/AXGroup widgets).
(2) `extractFallbackTitleFromChildren` — gdy klikalny rodzic ma puste title+desc, skanujemy do 5 dzieci po pierwszą niepustą labelkę (Chromium AXButton→AXImage pattern).
(3) `kAXRoleDescriptionAttribute` + `AXCustomActions` czytane w ClickWatcher; `RuleCache.match` rozszerzony o `roleDescription` i `customActions` parametry; defensive `extractCustomActionNames` parser dla 3 shape'ów (String/dict/NSObject KVC).

**Dlaczego:** Sesja 7 z planu (analiza events.jsonl) wymaga 1-2 dni użycia. W międzyczasie te 3 fixy bez czekania na dane rozszerzają zbiór "widocznych klikalnych elementów" — bezpośrednia odpowiedź na "klikam i toast się nie pokazuje".

**Wpływ:** ~30-50% wzrost coverage szacunkowo. 198 testów passing (192 + 6 nowych). Po tym sesja 8 analizy events.jsonl będzie miała bogatsze dane do diagnozy "co JESZCZE dodać".

**Commits:** `dfbb508` (Fix 1 — AXPress probe), `b1bf172` (Fix 2 — walk-down), `77fe805` (Fix 3 — RoleDescription + CustomActions).

**Następny krok:** Filip używa SFlow 1-2 dni → analiza `events.jsonl` per-layer per-apka → sesja 8 (targeted coverage based on data).

### 2026-05-14 — Sesja 6: Matching engine quality (P-26..P-30)

**Co:** 4 fundamentalne bugi rozpoznawania klikniec + telemetria per-layer.
(1) Nowy `wordBoundaryContains` utility w `TextMatching.swift` + 12 testów (Task 1).
(2) `RuleCache.match` używa word-boundary zamiast `String.contains` — "search" nie matchuje wewnątrz "research" (Task 2, BUG #2).
(3) `ClickWatcher.shouldRunNonInteractiveLayers` — L0.5 i L1 nie strzelają na rodziców powyżej depth 0 chyba że role jest interaktywna (Task 3, BUG #1).
(4) `MenuBarIndex.lookup` deterministyczny — sortuje po długości klucza desc + alfabetycznie ASC dla tie-break, najdłuższy match wygrywa (Task 4, BUG #3).
(5) `RecognitionLayer` enum + pole `layer` w `ShortcutEvent` i `events.jsonl` — telemetria per-layer dla toastów I false-positives (Tasks 5+6+7).
(6) `AXSkeletonExtractor.filter` przestaje zrzucać single-occurrence noun-led titles ("Quick Switcher", "Preferences") (Task 8, BUG B1).

**Dlaczego:** audyt 2026-05-14 wskazał te 4 bugi jako fundamentalne dla "wrażenia że niektóre elementy są pomijane lub źle przypisywane". Bez nich Faza 2-6 buduje na piasku. Telemetria per-layer odblokowuje data-driven coverage iteration jako następny krok.

**Wpływ:** Substring false-positives wyeliminowane. Strukturalne rodzice (AXWindow, AXScrollArea, AXGroup-bez-interactive-roli) nie odpalają toastów. Deterministyczne matche w MenuBarIndex. Skeletony obejmują ~30-50% więcej elementów (impact widoczny po następnym discoverze). `events.jsonl` ma teraz `"layer": "L0/L0.5/L1/L2/L3/L4/menu/menu-fallback"` w każdym entry — można zapytać `jq` "która warstwa fire'uje najczęściej dla apki X".

**Commits:** `fab9bd2` (Task 1), `1c9c2ad` (Task 2), `da2e146` (Task 3), `a35f1e4` + `704b561` (Task 4 + tie-break fix), `eb29538` + `4ff4f27` (Tasks 5+6+7 + layer-propagation fix), `3efba77` (Task 8).

**Następny krok:** używać SFlow przez 1-2 dni → przeanalizować `events.jsonl` → plan coverage (P-31+) targetujący konkretne luki per layer per apka.

### 2026-05-14 (wieczór) — Sesja 2: Bug squashing

**Co:** 3 bugi naprawione: (1) MenuBarIndex.lookup — zmiana kierunku substring + próg 5 znaków, naprawiono 2 failing testy + 2 nowe. (2) Input Monitoring permission check w AppDelegate — `CGPreflightListenEventAccess()` + alert z linkiem. (3) Structured JSON log w `/v1/discover` — `bundleId`, `cacheHit`, `rulesGenerated`, `durationMs` w każdym request.

**Dlaczego:** P-5 (fałszywy ⌘C dla "Copy link") był głównym wektorem false-positives. P-15 (milczący brak IM permission) powodował że user nie wiedział dlaczego nic nie działa. P-21 (brak logów) — lataliśmy ślepo.

**Wpływ:** Wyeliminowany główny wektor false-positives w Layer 3. Onboarding nie wymaga zgadywania co jest nie tak z permissions. Backend zaczyna zbierać dane.

**Commits:** `3a960be` (MenuBarIndex), `22ec8e2` (Input Monitoring), `5844285` (backend logs)

### 2026-05-14 (wieczór) — Sesja 1: Sweet wins

**Co:** 3 zadania: (1) Re-seed Terminal/Notion/Claude z v1.1.1 promptem — Terminal avg 3.4, Notion avg 4.3, Claude avg 4.4 wariantów per regule (było 1.05–2.13). (2) Fix P-23 w `dedup.ts` — deduplikacja tytułów within-rule + test. (3) Nowe skrypty `sflow-video-eval` + `sflow-video-extract.swift` (droga C sub-cel 1.8).

**Dlaczego:** Najszybszy ROI: 3 apki w bundled.json miały stary v1.0 prompt z minimalną liczbą wariantów. Teraz wszystkie 5 bundled apek jest na v1.1.1.

**Wpływ:** bundled.json wyrównany (wszystkie apki 3-5 wariantów per regule). P-23 zamknięty. Narzędzie do analizy wideo gotowe.

**Commits:** `0f14e92` (reseed), `28dd50b` (P-23 fix), `c2b171f` (video-eval)

### 2026-05-14 — Process & context rules dodane (ta sesja)

**Co:** Dodano sekcję "Proces ciągły" do roadmap, "Jak współpracujemy"
do product-vision (sekcja 0), sub-cel 1.8 do audit-phase-1 (video eval),
mechanizm status-tracking dla problemów P-X i sub-celów.

**Dlaczego:** Filip zauważył że bez tego każda sesja AI zaczyna się od
zera, zapomina poprzedni kontekst, czasem buduje rzeczy już zrobione.
Plus: video eval z poprzedniej sesji okazał się bardzo wartościowy
(wykrył Slack search ⌘F vs ⌘G bug) — warto sformalizować.

**Wpływ:** Każda następna sesja zaczyna się od **wymuszonej dawki kontekstu**.
AI musi czytać 4 pliki na start. Decyzje są łatwiejsze (rekomendacje
z uzasadnieniem). Postęp jest mierzalny (statusy w audytach).

**Commits:** *(ten — uzupełnij SHA przy commit'cie)*

### 2026-05-13 (wieczór) — v1.1.1: wrong-toast fix + audyt dokumentacji

**Co:** 4 fixy: prompt anti-overlap, backend dedup, Swift hotkey-suffix
tolerance, reseed Slack/Obsidian. Plus update 3 dokumentów (roadmap,
audyty) z poprawkami fakt'ualnymi.

**Dlaczego:** Wideo Filipa pokazało wrong toast (Slack search bar
hover ⌘G, toast pokazał ⌘F). Diagnoza: 2 reguły Claude'a z nakładającymi
się tytułami, hint+keys przemieszane. Plus odkryto pattern "Edit message E"
(Electron hotkey suffix w AX title).

**Wpływ:** Sub-cel 1.1 (quality gate) częściowo zrealizowany (backend dedup).
Sub-cel 1.5 (MenuBarIndex bug) NADAL pending — to inny matcher. Bundled.json
ma teraz Slack+Obsidian w v1.1.1 promtem (avg 4+ wariantów), pozostałe 3
apki w starym.

**Commits:** `c2c690c` (prompt), `72a4bb2` (dedup), `1f8891c` (Swift),
`cea1828` (reseed), `ede9c97` (docs).

### 2026-05-13 (popołudnie) — v1.1: miss log + better prompt + auto-reseed

**Co:** 21 commitów. EventLogger.logMiss + Analyzer + sflow-analyze CLI.
Backend prompt v1.1 z 3-5 wariantami tytułów + few-shot examples. Forward-compat
`version: 1` field. Auto-reseeder (`SFlow --reseed-all`) z backup'em.

**Dlaczego:** v1.0 manual eval pokazał ~50% hit rate. Cel: 70%+ przez
multi-variant tytuły. Plus narzędzie do mierzenia (miss log) żeby
v1.2 mógł być data-driven.

**Wpływ:** Hit rate po reseedzie ~99% w testach na Slack/Obsidian.
Linear/Cursor skipowane (not installed). Pre-existing 3 MenuBarIndex test
failures pozostały (nie z tej sesji).

**Commits:** Tag `pre-v1.1-misslog-prompt-2026-05-13` na początku + 21 feat
commitów. Główne: `ee9bd1c` (EventLogger), `556fe58` (ClickWatcher logMiss),
`1f0bc12` (Analyzer), `55e3e36` (prompt v1.1), `5666ddb` (reseed result).

---

## Faza 0: Co już mamy — pełna inwentaryzacja

Zaktualizowana lista (sprawdzona w kodzie, nie z pamięci):

### Detekcja i matching ✅

- `ClickWatcher` — CGEventTap nasłuchuje kliknięć (`SFlow/ClickWatcher.swift`)
- 4 warstwy reguł L0.5–L4 (LLM bundled, tooltip auto-parse, menu bar fuzzy,
  universal heuristics)
- `MatchConfidence` + filtrowanie wg confidence
- AXSkeletonExtractor — zbiera atrybuty AX z drzewa elementu

### LLM rules engine ✅

- Backend Cloudflare Worker (`backend/`) z endpointem `/v1/discover`
- Claude API generuje reguły dla **dowolnej** apki (menu bar + skeleton → rules)
- KV cache na backendzie (per bundleId+version)
- Production URL: `https://sflow-rules.shortcutflow.workers.dev`
- `SFlow/Resources/bundled.json` zaszyty z 5 apkami: **Slack, Obsidian** (regenerowane w v1.1.1 promtem, 3–5 wariantów tytułów per regule, average 4+), **Terminal, Notion, Claude Desktop** (regenerowane starym v1.0 promtem, ~1.05–2.13 wariantów per regule — do re-seedu w pierwszej kolejności). Linear i Cursor są na liście `Reseeder.verifiedApps`, ale w praktyce nie są zainstalowane na maszynie deweloperskiej, więc nigdy nie trafiły do bundled.

### Auto-discovery flow ✅ (to było moje wcześniejsze przegapienie)

- `DiscoveryService.observeAppActivation()` nasłuchuje
  `NSWorkspace.didActivateApplicationNotification`
- Gdy user aktywuje apkę bez reguł → automatyczny POST do `/v1/discover`
- Menu bar pokazuje **"✨ Learning [AppName]…"** podczas pracy
- Wynik trafia do `cache/<bundleId>.json`, `ruleCache.load()` przeładowuje
- **Czyli flow działa automatycznie dla setek apek już dziś** — to się może
  popsuć na jakości, ale nie na zasięgu

### Telemetria + diagnostyka v1.1 ✅

- `EventLogger` loguje `toast` i `miss` events do `events.jsonl`
- `Analyzer` (`SFlow --analyze`) agreguje miss log do raportu
- `Reseeder` (`SFlow --reseed-all` / `--reseed <bundleId>`) — narzędzie dev do
  ręcznego odświeżenia hardcoded listy 4 apek. **Skipuje apki nie-zainstalowane**
  (Linear/Cursor na devsie Filipa). Wymaga ubicia GUI SFlow przed odpaleniem.
  Tworzy backup `bundled.json.bak.<ts>` przed pierwszym zapisem
- Backend `?fresh=1` query param na `/v1/discover` — pozwala obejść 90-dniowy
  KV cache. Reseeder używa tego od v1.1.1 (poprzednio cache zwracał stare reguły
  generowane przed deployem nowego promptu)

### Co **nie** jest zbudowane (czyli prawdziwa kolejka Fazy 1)

- ❌ Quality gate dla auto-discovered rules (przyjmujemy każdy wynik LLM)
- ❌ Retry logic dla nieudanych discovery (jedna porażka = no rules forever)
- ❌ Self-healing przez miss log (`/v1/refresh` endpoint)
- ❌ Wykrywanie **false positives** (toast pokazany dla błędnego skrótu)
- ❌ `AXKeyShortcutsValue` jako Layer 0 (zero-config dla apek z aria-keyshortcuts)
- ❌ Manualnie zweryfikowane coverage report dla 20 apek
- ❌ **Ukierunkowany web research w backend prompt** (P-32) — Claude sam
  decyduje czy/kiedy szukać w necie. Brak per-element search dla nieznanych
  skrótów. Sub-cel 1.12.
- ❌ **Synthetic Claude self-eval per regule** (P-33) — quality eval skaluje
  się dziś tylko do liczby apek które fizycznie obklikamy. Auto-discovery dla
  100+ apek bez eval = ślepe ufanie Claude'owi. Sub-cel 1.13.

---

## Lokalne vs serwer — decyzja architekturalna

To pytanie zadałeś — odpowiadam zanim wejdziemy w fazy.

### Co musi być lokalnie (zawsze)

- **Raw clicks** (każdy klik z atrybutami AX) — `events.jsonl`. Nigdy nie wysyłamy.
  To dane wrażliwe ("user kliknął element o tytule «Salary 2026»").
- **Per-element matching** (decyzja czy pokazać toast). Działa offline.
- **Bundled rules** (zaszyte w apce na start, bez internetu).

### Co musi być na serwerze (uzasadnione)

- **Rules database** (już mamy: CF Worker + KV). Bez serwera nie da się generować
  reguł dla nowych apek przez Claude. Lokalny LLM odpada (model ~10GB).
- **Curriculum generator** (droga B) — Faza 4. LLM raz w tygodniu układa
  userowi plan. Wysyłamy **agregaty**, nie raw events.
- **Cross-device sync** (mobile/web companion w przyszłości). Opcjonalne.

### Co może być oba

- **Heatmap/raporty** (droga E). Lokalnie wystarcza dla MVP. Serwer potrzebny
  gdy user chce sync lub porównanie z avg user.
- **Postęp nauki** (droga B). Lokalnie dla MVP, serwer dla multi-device.

### Rekomendacja architektury

**Hybrid privacy-first.**

```
        Lokalne (SFlow.app)              |          Serwer (CF Worker)
                                          |
[raw clicks]──────────────────────────────|  (nigdy nie opuszcza Maca)
       │                                  |
       ▼                                  |
[lokalny profil: top-N akcje]─────────────|──[agregat: bundleId + akcja + freq]
       │                                  |       │
       ▼                                  |       ▼
[matching + toast]                        |  [curriculum LLM call (raz/tydz.)]
       │                                  |       │
       ▼                                  |       ▼
[lokalny dashboard E]◄────────────────────|──[lesson plan JSON]
```

**Co wysyłamy do serwera (z Fazy 2):**
```json
{
  "anonymousUserId": "uuid-na-zawsze-na-tym-macu",
  "weekISO": "2026-W19",
  "aggregates": [
    {"bundleId": "com.tinyspeck.slackmacgap", "shortcutId": "slack-compose", "clicks": 47, "shortcutsUsed": 3}
  ]
}
```

**Czego NIE wysyłamy:** treści, dokładnych timestampów, pozycji kursora, raw
AX atrybutów (poza `/v1/discover` skeleton — tam już są filtrowane).

**User toggle "Disable telemetry":** od pierwszej wersji.

---

## Faza 1: Jakość pokrycia (2–4 tygodnie)

**Cel:** SFlow działa "dobrze" dla **dowolnej apki którą user zainstaluje**.
"Dobrze" = ≥70% hit rate, **<5% false positives**, samonaprawia się gdy
reguły się starzeją.

**Nie budujemy auto-discovery** (jest). Budujemy **jakość, retry,
samonaprawianie, eval**.

**Kryterium wyjścia (musimy to mieć przed Fazą 2):**
- 20 apek z confirmed hit rate ≥70% i false-positive rate <5%
- Quality gate filtruje błędne reguły z auto-discovery
- Retry mechanism naprawia nieudane discovery
- `/v1/refresh` endpoint + scheduler działają
- Zero blocking issues z beta-testów (3–5 osób, 1 tydzień)

### 1.1 Quality gate dla auto-discovered rules

**Problem:** dziś `DiscoveryService` (linia 60) zapisuje cokolwiek backend
zwróci. Jeśli Claude zhalucynuje "Notion: ⌘Z = Toggle Sidebar", toast będzie
fałszywie pokazywany przez wieki.

**Rozwiązanie:**
- Filtr przy zapisie: tylko `confidence: high` z `source: menu_bar` lub
  `web_docs_official` ląduje w aktywnym cache
- `medium` zapisany ale wyłączony (toast nie pokazuje) do czasu user-feedback
- `low` (`source: inferred_pattern`) całkowicie ignorowany dla auto-discovery
- Bundled rules (4 zweryfikowane apki) — bez filtra, są już sprawdzone

**Wpływ na UX:** auto-discoverowana apka pokazuje **mniej** toastów ale
prawie **żadnych fałszywych**. Lepiej cisza niż uczenie złego skrótu.

### 1.2 Retry logic dla failed discovery

**Problem:** `DiscoveryService` linia 42: `attempted.insert(bundleId)` — jedna
porażka, koniec. Jeśli apka jeszcze nie wczytała AX tree (pierwsze 5s po
launch) → discovery z pustym skeleton → backend zwraca puste lub błędne reguły
→ użytkownik forever bez reguł.

**Rozwiązanie:**
- `attempted` zapisany na dysku z timestampem (`attempted.json`)
- Backoff: po 1. failure czekamy 1h, po 2. — 24h, po 3. — 7 dni
- Trzymanymy info o przyczynie (HTTP error / pustay skeleton / rate limited)
- Settings: "Try again" button per apka (force retry now)
- Pre-check przed POST: jeśli `skeleton.count < 3` → poczekaj 30s, odpal jeszcze
  raz (apka się ładuje)

### 1.3 Self-healing przez miss log → `/v1/refresh`

**Problem:** reguły starzeją się gdy apka zmienia UI (Notion update'uje labels
co 2 tygodnie). Dziś nic się nie dzieje — reguły są stale do następnego
manualnego reseed'u.

**Rozwiązanie:**
- Nowy endpoint backendu `/v1/refresh`:
  - Wejście: `{bundleId, currentRules, recentMisses: [...]}`
  - Backend prosi Claude: "Te reguły są niedopasowane do tych elementów —
    wygeneruj zaktualizowane wersje"
  - Wyjście: nowy zestaw reguł
- Klient: scheduler (`NSBackgroundActivityScheduler`, niskopriorytetowy)
  - Raz dziennie patrzy na `events.jsonl` z ostatnich 7 dni
  - Dla każdej apki: jeśli ≥20 missów, ≥3 tytuły powtarzające się 3x → POST `/v1/refresh`
  - Nowy zestaw reguł zastępuje cache po passowaniu quality gate (1.1)

### 1.4 False-positive detection — to było moje przegapienie

**Problem:** miss log łapie "kliknięcie nie zmatchowane" ale **nie łapie**
"kliknięcie zmatchowane do błędnego skrótu". A to drugie jest **gorsze** —
uczy usera złego nawyku.

**Rozwiązanie (proste):** cmd-klik na toast (lub corner X) = "to jest źle".
Zapisuje do `events.jsonl` event `false_positive` z bundleId + shortcutId.
W Fazie 2.5 jeśli ≥3 razy ten sam shortcutId → automatycznie wyłączony
lokalnie. Dla bundled rules — agregat na backendzie (po Fazie 2): jeśli ≥5
unikalnych userów raportuje ten sam shortcutId → globalne wyłączenie.

**Wpływ:** użytkownik dostaje **kontrolę** nad SFlow, system uczy się szybciej.

### 1.5 AXKeyShortcutsValue jako Layer 0

**Z `deep-think-auto-discovery.md`:** Chromium eksponuje `aria-keyshortcuts`
jako AX atrybut `AXKeyShortcutsValue`. Gmail to ustawia (`c` = compose).
Niektóre inne apki też.

**Co dostajemy:** zero-config, language-agnostic toast dla apek które ten
atrybut ustawiają. Nawet bez backend call.

**Zadanie minimum:** dodać Layer 0 w `ClickWatcher`:
```swift
if let ks = readAttribute(element, "AXKeyShortcutsValue") as? String,
   let parsed = parseAriaShortcut(ks) {
    emit(parsed)
    return
}
```

**Risk:** nieznane jak szeroko adoptowane. Sprawdzić empirycznie podczas
1.6 (beta) — jeśli żadna apka tego nie używa, możemy odpiąć. Koszt
implementacji niski (~1h), warto spróbować.

### 1.5.5 Ukierunkowany web research w backend prompt (NOWY, P-32)

**Problem:** Claude w backendzie ma `web_search` tool (max 4 uses) ale sam
decyduje czy/jak go użyć. Dla popularnych apek (Slack ⌘K) działa, dla niche
i regional apek może w ogóle nie sięgnąć po niego.

**Rozwiązanie:** prompt prowadzi Claude'a — najpierw `{appName} keyboard
shortcuts cheatsheet`, potem per-element queries dla nieznanych skrótów.
Plus zwiększamy `max_uses` z 4 na 8.

**Łączymy ze sesją reseedu (sesja 9, bundle C):** zmiana prompta + reseed
5 bundled apek + diff sprawdzający że liczba reguł nie spadła. Sub-cel 1.12
w `audit-phase-1.md`.

### 1.5.6 Synthetic Claude self-eval per regule (NOWY, P-33)

**Problem ujawniony w brainstormie 2026-05-15:** manual eval per apka
(60min/apka) nie skaluje na 100+ apek które auto-discovery wygeneruje.
Beta z 3-5 osobami pokryje ~10 apek. Resta = ślepe ufanie Claude'owi.

**Rozwiązanie:** drugi Claude call po generacji — `claude-haiku-4-5` ocenia
każdą regułę 1-5 z reasoning + alternative suggestion. Score <3 → flag
`experimental: true`. Klient honoruje przez quality gate (z Sub-celu 1.1):
experimental rules ukryte przez default, widoczne po toggle.

**Koszt:** ~$3 łącznie dla 100 apek (jednorazowo per apka, cache'owane).

**Wpływ:** quality eval skaluje **bez Filipa**. Real-world signal nadal
przychodzi z P-4 (false-positive feedback) w Fazie 2 — synthetic eval jest
**pre-flight**, FP feedback jest **post-flight**. Komplementarne. Sub-cel
1.13 w `audit-phase-1.md`.

### 1.6 Coverage eval — 20 zweryfikowanych apek

Pipeline (powtórzony 16 razy, bo Slack/Obsidian/Linear/Cursor już są):
1. Otwórz apkę → SFlow auto-discoveruje (sprawdzić menu bar status "Learning")
2. Czekaj na completion
3. Manual eval: 10 najpopularniejszych kliknięć, hit rate?
4. Jeśli <70% → iteruj prompt na backendzie, redeploy, force-refresh tej apki
5. Sprawdź false-positive rate (klikaj rzeczy random, czy fałszywe toasty?)
6. Jeśli OK → promote do `bundled.json` (`scripts/promote-to-bundled.sh`)

**Output:** `docs/coverage-report.md`:

```
| App         | Hit % | False+ % | Verified | Notes               |
|-------------|-------|----------|----------|---------------------|
| Slack       | 85%   | 2%       | 2026-05-13 | bundled           |
| Notion      | 78%   | 4%       | 2026-05-15 | bundled (new)     |
| Figma       | 45%   | 12%      | 2026-05-16 | needs prompt tune |
```

Ten plik **publicznie** na landing page'u — pokazuje "supported apps" z
konkretnymi liczbami.

### 1.7 Beta z 3–5 znajomymi (decyzyjne!)

**To jest najważniejszy krok Fazy 1.** Wszystko poprzednie to przygotowanie.

- 5 power-userów, 2 tygodnie
- Build z 20 zweryfikowanymi apkami + auto-discovery dla reszty
- Codzienny `sflow-analyze` raport → email do Filipa
- Po tygodniu 1: ankieta "ile fałszywych toastów zobaczyłeś?" (cel: ≤5)
- Po tygodniu 2: ankieta "ile **NOWYCH** skrótów teraz używasz częściej niż
  przed instalacją?" (cel: ≥3 średnio na osobę)

**Decyzja blokująca:**
- Jeśli średnia ≥3 → toast uczy → idziemy w Fazę 2 z planem
- Jeśli średnia 1–2 → toast trochę uczy → idziemy ale agresywniej w drogę B
  (więcej forced practice, mniej "subtle hint")
- Jeśli średnia 0–1 → toast nie uczy → **kompletny pivot**, droga D (blocker)
  lub C (drill) jako core

**Risk:** ta odpowiedź zmienia cały produkt. Lepiej dostać teraz niż po
6 miesiącach.

---

## Sekwencja Faza 1 ↔ 1.5 ↔ 1.6 ↔ 1.7 (graf zależności)

```
Faza 1 (jakość fundamentu, P-26..P-30 ✅, P-49 ⬜)
   │
   ├──► Faza 1.5 (Universal Coverage U-1..U-7)
   │       │   robi się równolegle, bo każda warstwa
   │       │   uniwersalna zwiększa Sub-cel 1.6 hit-rate
   │       ▼
   ├──► Faza 1.6 (20 verified apps, hit-rate ≥70%)
   │       │   wymaga U-1..U-4 żeby trafić 70% na apkach
   │       │   typu Notion Mail / Gmail web / Figma
   │       ▼
   └──► Faza 1.7 (beta 3-5 osób, 2 tygodnie)
           │   wymaga P-49 ZAMKNIĘTE (multi-monitor toast)
           │   bo bez widocznego toasta beta nic nie mierzy
           ▼
       Decyzja: kontynuować Fazę 2 czy pivot
```

**Reguły:**
1. **Faza 1.5 nie czeka na Fazę 1.6** — wykonujemy je współbieżnie, każda
   warstwa U-X zasila hit-rate w 1.6.
2. **Faza 1.7 (beta) wymaga zamknięcia P-49** — multi-monitor toast blocker.
   Bez tego beta-testerzy z 2-monitorami nie zobaczą produktu.
3. **Faza 1.7 wymaga ≥10 verified apps z 1.6** (zniżamy z 20→10 dla beta MVP)
   — 20 to cel pełny, 10 wystarczy żeby beta-tester miał codzienne pokrycie.
4. **Faza 2 nie startuje** dopóki beta nie odpowie na pytanie "czy toast uczy".

---

## Faza 1.5: Universal Coverage (2–3 tygodnie)

**Cel:** zamknąć największe luki uniwersalności mechanizmu rozpoznawania
**przed** budową drogi B. Bez tej fazy każda nowa apka wymaga reseedu
Claude + manual eval. Z tą fazą — 6 nowych warstw działa **z dnia 0** dla
większości popularnych Mac apek.

**Kontekst:** po analizie 2026-05-16 (`docs/universality-gaps-and-windows-2026-05-16.md`)
zidentyfikowano 15 dziur uniwersalności (G-1..G-15) + 5 niepokrytych typów
apek (Office / Adobe / Qt-GTK / Catalyst / SwiftUI). Faza 1.5 robi
**najwyższy ROI subset** — 6 priorytetów (G-1, G-2, G-3, G-4, G-7, G-8) +
eval coverage 5 typów apek.

**Kryterium wyjścia:**
- Sub-cele 1.18–1.23 (G-1..G-4, G-7, G-8) zaimplementowane lub świadomie
  odłożone
- Sub-cel 1.29 (B.1 follow-up — TooltipNameFilter + PrivacyFilter
  zintegrowane)
- Coverage 50 apek (z 20 w Fazie 1.6 → 50 z mix auto-discovered + manual
  eval Fazy 1.5)
- % missów per kategoria (right-click, web content, dialog) w `events.jsonl`
  spada o **≥60%**

**Pełna lista sub-celów + execution sequence + atomic plany:**
patrz [`audit-phase-1.5.md`](audit-phase-1.5.md).

### 1.5.1 Najważniejsze sub-cele (top-4 ROI, ~12h razem)

| Sub-cel | Krótko | Czas |
|---|---|---|
| 1.18 (G-1) | **Right-click monitoring** — `rightMouseDown` + AXMenu handler. Pokrywa skróty z context menu we **wszystkich** apkach naraz. | ~3h |
| 1.21 (G-4) | **Single-key mode** — feature flag dla Gmail/Notion Mail/Obsidian Vim. Tani fix, czysty mental model. | ~2h |
| 1.19 (G-2) | **Web-as-app** — pseudo-bundleId `web:gmail.com` per domena. Otwiera klasę web-apek bez per-app pracy. | ~5-8h |
| 1.20 (G-3) | **i18n lokalizacja** — `AXLanguage` + Claude prompt z `userLocale`. Odblokowuje non-EN market. | ~6-10h |

### 1.5.2 Inne sub-cele Fazy 1.5

| Sub-cel | Krótko | Czas |
|---|---|---|
| 1.22 (G-7) | Modal/sheet/dialog scope — `AXFocusedWindow` role check, scope field w schema | ~6h |
| 1.23 (G-8) | Tool/mode switching — `AXToolbar` detection, single-key whitelist dla creative apek | ~5h |
| 1.24 | Eval Microsoft Office (Excel/Word/PowerPoint/OneNote/Outlook) — reseed + manual | ~10h |
| 1.25 | Eval Adobe (Photoshop/Illustrator/Premiere) — reseed + manual | ~10h |
| 1.26 | Eval Qt/GTK/Tk (VLC/GIMP/Blender/OBS/RStudio) | ~6h |
| 1.27 | Eval Catalyst (News/Stocks/Home/Books) | ~4h |
| 1.28 | Eval SwiftUI (Shortcuts.app/Freeform) | ~2h |
| 1.29 | B.1 finalize — integracja `TooltipNameFilter` + `PrivacyFilter` (kod gotowy 2026-05-16, 1 linia integracji) | ~30 min |

**Łącznie Faza 1.5:** ~55-70h. Można rozbić na ~10 sesji.

### 1.5.3 Świadomie odłożone na późniejsze fazy

- **G-5 P-38 MenuItemObserver** — już Sub-cel 1.17 w Fazie 1 (sesja C.5 po Sesji C)
- **G-6 Keystroke monitoring** — już Faza 2.2 (drugi event tap)
- **G-15 Active probing** — już Sub-cel 1.16 (Sesja D, opcjonalna)
- **G-9, G-10, G-11, G-13, G-14** — niski priorytet, Faza 2+ (patrz
  `audit-phase-1.5.md` § "Co NIE robimy")
- **G-12 Team/admin** — już Faza 7 (B2B)
- **Windows port** — Q1 2027, po PMF na Macu

### 1.5.4 Decyzja kolejności

Sesje U-1..U-10 mają priorytety. Sekwencja zalecana (zmiana 2026-05-17):

1. **U-1** (B.1 integracja, ~30 min) — kod gotowy, najszybszy commit
2. **P-49** (Slack multi-monitor toast, ~2h) — **WSTAWIONE TUTAJ:** blocker
   dla Fazy 1.7 beta; bez tego beta-testerzy z 2-monitorami nie zobaczą produktu
3. **U-2** (Right-click, ~3h) — największy uniwersalny win
4. **U-3** (Single-key, ~2h) — najtańszy fix
5. **U-4** (Web-as-app, ~6-8h) — największy unlock zakresu (Gmail/Linear/Slack web)
6. **U-5** (i18n, ~6-10h) — **PODNIESIONE z MEDIUM na HIGH (2026-05-17):**
   Filip pisze po polsku i większość polskich beta-testerów ma polski UI
   Slacka/Notion. Bez i18n te apki dają 0% pokrycia okien (tylko menu bar).
   Beta sygnał będzie niewiarygodny jeśli pokrycie zależy od locale apki.
7. **U-6, U-7** (modal scope, tool/mode) — kolejność zależna od bety Fazy 1.7
8. **U-8..U-10** (eval 5 typów apek) — w międzyczasie jako "small sessions"

---

## Faza 2: Infrastruktura nauki (3–4 tygodnie)

**Cel:** mamy serwer + lokalne hooki potrzebne do drogi B i E.

**Kryterium wyjścia:**
- Anonymous user ID działa
- `shortcut_used` events się logują (drugi event tap dla klawiatury)
- Lokalne agregaty raz dziennie liczone z `events.jsonl`
- Endpoint `/v1/agg` przyjmuje agregaty + opt-out toggle działa
- Privacy UI w Settings

### 2.1 Anonymous user ID

UUIDv4 generowany przy pierwszym uruchomieniu, zapisany w
`~/Library/Application Support/SFlow/user.json`. Bez nazwiska, bez emaila, bez
konta. User może go wyczyścić ("Reset SFlow identity").

### 2.2 Rozbudowa EventLogger o nowe typy

Dziś:
- `toast` (SFlow pokazał toast)
- `miss` (kliknięcie nie zmatchowało)

Dodajemy:
- **`shortcut_used`** (user wcisnął klawiaturą skrót który jest w bazie)
- **`false_positive`** (już opisane w 1.4 — cmd-klik na toast)
- **`clicked_despite_known`** (user kliknął myszką akcję dla której pokazaliśmy
  toast w ostatnich N dniach — najcenniejszy event dla drogi B)

**Implementacja `shortcut_used`:** drugi CGEventTap na keyDown z filtrem **tylko
kombinacje z modifierami** (⌘/⌥/⌃/⇧). Raw keypresses NIE są logowane.
Cross-reference z aktywnym bundleId + rules cache.

**Risk:** drugi event tap = potencjalny perf hit + privacy concern. Filtr
modifier-only ogranicza to do ~50 eventów/dzień zamiast tysięcy.

### 2.3 Daily aggregator

Raz dziennie (NSBackgroundActivityScheduler):
1. Czytaj `events.jsonl` z ostatnich 24h
2. Agreguj per `(bundleId, shortcutId)`: `{clicked, used, missed, falsePos}`
3. Zapisz w `daily-aggregates.jsonl` (już agregat, nie raw)
4. Jeśli telemetry włączone → POST `/v1/agg` (batch jeśli były offline dni)
5. Rotate `events.jsonl` (zachowaj 30 dni)

### 2.4 Endpoint `/v1/agg`

Cloudflare Worker przyjmuje agregaty, zapisuje do D1 (sqlite na CF) lub KV.
Schema prosta: `(userId, date, bundleId, shortcutId, clicked, used, missed, falsePos)`.
Rate limit per IP, max 10KB payload, walidacja Zod.

### 2.5 Privacy UI w Settings

Nowe okno SwiftUI:
- "Telemetry: ON/OFF" toggle (default decyzja przy launch)
- Lista konkretnych pól które są wysyłane (z przykładem JSON)
- Lista pól które NIGDY nie są wysyłane
- Przycisk "Pokaż mi wszystko co o mnie wiecie" (otwiera `daily-aggregates.jsonl`
  w Finderze)
- Przycisk "Skasuj moje dane lokalne + zdalne" (POST `/v1/forget`)

**Powiązany endpoint `/v1/forget`** — RODO-friendly.

### 2.6 False-positive global aggregation

Z 1.4: lokalne wyłączenie po 3 zgłoszeniach. Tu dokładamy globalne agregaty
na backendzie. `/v1/agg` zlicza `false_positive` events. Jeśli ≥5 unikalnych
userów (różne `anonymousUserId`) zgłosi ten sam `(bundleId, shortcutId)` →
backend automatycznie ustawia `disabled: true` w rules KV → następne
`/v1/discover` zwraca rules bez tej.

To jest **droga #2 z `v1.1-roadmap.md` (Phase F feedback loop)** — naturalnie
trafia tutaj.

---

## Faza 3: Droga A — intro toast + onboarding (1 tydzień)

**Cel:** pierwsze 7–14 dni usera ma głośniejszy onboarding. Później system się
sam ucisza (przez naturalny mechanizm: nauczył się → klika klawiaturą → toast
się nie pojawia).

**Krytyczna uwaga (z dyskusji):** "tryb cichy" nie wymaga budowania. Gdy user
naprawdę opanuje skrót, przestaje klikać → toast się nie pojawia. **System
sam siebie wycisza.** Wystarczy zająć się **głośnym wejściem**.

### 3.1 Welcome sequence (jednorazowa)

Pierwsze uruchomienie:
1. Welcome screen: "SFlow pokazuje skróty gdy klikasz przyciski. Pierwszego
   tygodnia zobaczysz dużo toastów. Apka się sama uciszy gdy nauczysz się
   skrótów (bo będziesz klikać klawiaturą zamiast myszki)."
2. Permissions: AX + Input Monitoring (pierwsza prośba)
3. "Z których apek korzystasz najczęściej?" (lista top-20 wg bundled.json,
   checkbox)
4. Wynik: SFlow priorytetuje auto-discovery dla wskazanych (rozgrzewa cache
   w pierwszych 5 minutach po onboardingu)
5. Pokaż demo toast ("teraz wygląda to tak")

### 3.2 Intro toast — pierwsza ekspozycja jest mocniejsza

Liczone per `(userId, shortcutId)` w `learning-state.json`:
- Pierwsze 1–3 ekspozycje (`clickedCount < 3`) → **intro toast**: większy
  font (15pt zamiast 12), dłuższy timeout (4s zamiast 1.5s), lekka animacja
  fade-in z pulsem. Tekst: `⌘K  Quick Switcher — try this next time!`
- Kolejne (`clickedCount >= 3`) → **standardowy toast** jak dziś

**Counter store** (per shortcutId):
```json
{
  "slack-compose": {
    "clickedCount": 27,
    "shortcutUsedCount": 5,
    "lastClicked": "2026-05-13T...",
    "lastShortcutUsed": "2026-05-12T..."
  }
}
```

To wystarcza. Bez trybu "silent" (samoreguluje się).

### 3.3 Reinforcement w toaście dla curriculum (preview Fazy 4)

Krótki preview: gdy w Fazie 4 user dostanie tygodniowy plan, toast dla
skrótów **z planu** dostaje gwiazdkę:
```
⭐ ⌘K  Quick Switcher (cel tygodnia: 5/10)
```

Mała zmiana w renderze, big psychological win — user widzi że jego praca
łączy się z planem.

**Implementacja w Fazie 3 wstępna:** flaga w counter store `isCurriculum: true`
zmienia rendering. Logika "co jest w planie" przychodzi z Fazy 4.

---

## Faza 4: Droga B 1.0 — personalizowane lekcje (4–6 tygodni)

**Cel:** SFlow raz w tygodniu mówi "ćwicz te 5 skrótów, oto plan na 7 dni",
dashboard pokazuje postęp.

**Kryterium wyjścia:**
- Tygodniowy curriculum generowany przez Claude (lub prosty algorytm — patrz 4.1)
- Dashboard z aktualnym planem + postępem (`shortcut_used` count)
- Po 4 tygodniach z 5 beta-testerami: ≥3 osoby raportują "nauczyłem się
  N nowych skrótów dzięki SFlow"

### 4.1 Curriculum generator — wybór: algorytm vs LLM

**Wariant A (prosty algorytm, zero LLM cost):**
Lokalnie. Dla każdego skrótu policz `score = clickedCount × timesSaved × easeOfLearning`.
- `timesSaved`: predefiniowana sekunda zaoszczędzona per użycie (w bazie reguł,
  np. ⌘K w Slacku → 3s; ⌘Z → 1s)
- `easeOfLearning`: heurystyka (1-key vs 3-key combo)
Top 5 z najwyższym score (wykluczając te już opanowane, gdzie
`shortcutUsedCount > 10`).

**Wariant B (LLM curation):**
Endpoint `/v1/curriculum`. Backend dostaje aggregaty, woła Claude z promptem
"Ułóż userowi plan tygodniowy uwzględniając jego pattern usage, prioritize
skróty które dadzą mu najwięcej oszczędności czasu, dodaj ludzki opis".
Zwrot: lesson plan + krótkie uzasadnienie ("zaczynamy od ⌘K bo to twoje #1
najczęstsze kliknięcie w Slacku").

**Decyzja:** zacząć od **A**. Tańsze, deterministyczne, łatwiej debugować.
Dodać **B** później jako "Pro feature" jeśli userzy poproszą o personality.
Koszt B: ~$0.01 per user per week. Akceptowalne.

### 4.2 Lokalna lesson view (SwiftUI window)

Otwiera się:
- Po pierwszym logowaniu (powitalne curriculum po 3 dniach zbierania danych)
- W poniedziałek rano (NSUserNotification "Twój plan na ten tydzień jest gotowy")
- Z menu bar (klik na ikonkę SFlow → "Show this week's plan")

Zawartość:
- 5 kart skrótów (apka + akcja + skrót + statystyki "kliknięcia: 47x,
  użyłeś klawiatury: 2x")
- Progress bar per skrót ("opanowanie: ▓▓░░░░ — uderz 10x klawiaturą żeby
  zaliczyć")
- Tygodniowy heatmap (mini-wykres z miesięcznym kontekstem)
- "Ćwicz teraz" button przy każdej karcie → otwiera odpowiednią apkę

### 4.3 Reinforcement w toaście (pełna implementacja)

Z 3.3 — toast dla skrótów z curriculum dostaje gwiazdkę + progres. Pełna
integracja: lesson view ↔ counter store ↔ toast renderer.

### 4.4 Mierzenie postępu

Co tydzień raport "tydzień zamknięty":
- Skróty z planu: opanowane (`used ≥ 10`) / pominięte
- Łączny czas zaoszczędzony (`sum(used × timesSaved)`)
- Comparison z poprzednim tygodniem (+/- minuty)

To naturalnie pływa w drogę E.

---

## Faza 5: Droga E — raporty + dashboard (2–3 tygodnie)

**Cel:** user widzi konkretną wartość liczbową. "Zaoszczędziłeś 27 minut
w tym miesiącu używając skrótów dzięki SFlow."

**Kryterium wyjścia:**
- Tygodniowy raport (in-app + opcjonalny email)
- Lifetime dashboard
- Eksport CSV

### 5.1 SavingsCalculator

Lokalny moduł:
- Input: `daily-aggregates.jsonl` + tabela `timesSaved` per skrót
- Output: `weekly-savings.json`:
  - `totalMinutesSaved`
  - `topShortcuts: [...]`
  - `improvementVsPrevWeek: +X%`
  - `comparisonToFirstWeek: +Y%`

### 5.2 Weekly Report Window

Pełnoekranowy widok (raz w tygodniu, w sobotę rano):
- "Tydzień 19, 2026"
- Big number: "Zaoszczędziłeś **27 minut** dzięki skrótom"
- Wykres: dni tygodnia × skróty użyte
- Lista top-10 skrótów których użyłeś
- "Następny tydzień" link → curriculum (droga B)

### 5.3 Menu bar icon updates

Mała liczba "27" obok ikony oznacza "27 minut zaoszczędzonych w tym tygodniu".
Resetuje się w poniedziałek. Mały dopaminowy reward stale widoczny.

### 5.4 Email raport (opt-in)

Tylko jeśli user da email. Tygodniowy mailing z najlepszymi cytatami.
Marketingowo silne ("share your savings").

---

## Faza 6: Pricing + launch (2–3 tygodnie)

**Cel:** ludzie kupują.

### 6.1 Decyzja modelu

- **A. $25 one-time forever.** Najprostszy. Dobry dla walidacji
  willingness-to-pay. Brak revenue retention.
- **B. $5/mies subscription.** Free: 5 apek + raporty E. Paid: nielimitowane
  apki, drogi B, curriculum LLM, email raport.
- **C. Free fully (B2B only).** Pricing przez team license (Faza 7).

**Sugestia:** wariant **A** dla pierwszych 100 userów (Gumroad, prosta
sprzedaż). Po 100 → przejście na **B** z grandfathered pricing.

### 6.2 Onboarding paywall

Po Phase 3 onboarding sequence dodać:
- 14-dniowy free trial counter
- Po 14 dniach okno "Twój darmowy okres się kończy. Już zaoszczędziłeś X minut.
  Kup pełną wersję żeby kontynuować."
- Pricing card $25 one-time, link do Gumroad

### 6.3 Landing page

`sflow.app` (lub podobna). Sekcje:
- Hero: 10-sec wideo "klikasz → toast → uczysz się"
- **Lista 20 supportowanych apek** z `coverage-report.md` (faza 1.6)
- "Twoje pierwsze 14 dni za darmo"
- Testimonials z bety
- Privacy: pełny opis
- FAQ

### 6.4 Distribution

- Product Hunt launch
- HN Show (opcjonalnie)
- Twitter/X — Filip + 5 friendly accounts
- Newsletter dla power-userów (DenseDiscovery, Refind, Hacker Newsletter)
- Reddit r/macapps (ostrożnie, czytają regulamin)

---

## Faza 7: B2B / Team (długoterminowo)

**Cel:** sprzedaż pakietów licencji firmom.

Wymaga: SSO, admin dashboard, "company-wide curriculum", security audit.

**Decyzja:** otwierać dopiero po **udowodnieniu B2C** (Faza 6 dostarcza
ARR $50k+). Sprzedaż B2B jest 6–12-miesięcznym wysiłkiem.

---

## Risk register

### R1: Toast nie uczy (najwyższy risk)

**Mitigacja:** beta z 3–5 osobami w Fazie 1.7. Pytanie "ile NOWYCH skrótów
używasz częściej". Jeśli wynik 0–1 → pivot do drogi D lub C. **Decyzja
blokująca Fazy 2–4.**

### R2: Auto-discovery zwraca niskiej jakości reguły dla wielu apek

**Mitigacja:** quality gate (1.1) filtruje. Beta (1.7) ujawni które apki są
problematyczne. Iteracja prompta + bundled overrides dla TOP 20.

### R3: Privacy odstrasza userów

**Mitigacja:** Faza 2.5 dostarcza widoczne UI. Default OFF dla telemetry
**przy launchu**, default ON dla bety. Wyraźne opt-in CTA z konkretnym
benefit ("włącz żeby dostać personalizowane lekcje").

### R4: Konkurencja (KeyCue) wypuści podobną feature

**Mitigacja:** prędkość. Każda faza kończona, decyzja go/no-go, kolejna
zaczynana. Nie utknąć w "perfekcjonizacji" jednej fazy.

### R5: macOS update łamie AX API lub CGEventTap

**Mitigacja:** sprawdzaj betę macOS. Wbudowany "diagnostic mode" żeby user
mógł wysłać raport jednym klikiem. Hotfix w ciągu 48h.

### R6: Coraz większa baza = większe koszty Claude API

**Mitigacja:** Claude tylko dla `/v1/discover` (raz per apka per user) i
`/v1/curriculum` (raz/tydzień per user, **jeśli wariant B**). Łączny koszt:
~$0.10/user/miesiąc przy wariancie B, ~$0.02 przy A. Akceptowalne nawet
przy 10k userów.

### R7: False positives nie są wykrywane bez user feedback

**Mitigacja:** mechanizm cmd-klik z 1.4 jest **obowiązkowy** w pierwszym
releasie. Beta-testerzy świadomie szukają fałszywych toastów.

---

## Sequence pictorial

```
Phase 1: Jakość pokrycia (2-4 tyg.)
  ├── 1.1 Quality gate dla auto-discovery
  ├── 1.2 Retry + backoff
  ├── 1.3 /v1/refresh self-healing
  ├── 1.4 False-positive detection (cmd-klik)
  ├── 1.5 AXKeyShortcutsValue L0
  ├── 1.6 20 zweryfikowanych apek (coverage-report.md)
  └── 1.7 Beta z 3-5 osobami      ← DECYZJA: idziemy dalej?
                │
                ▼
Phase 2: Infra (3-4 tyg.)
  ├── 2.1 Anonymous user ID
  ├── 2.2 shortcut_used + false_positive + clicked_despite_known events
  ├── 2.3 Daily aggregator
  ├── 2.4 /v1/agg endpoint
  ├── 2.5 Privacy UI + /v1/forget
  └── 2.6 Global false-positive aggregation
                │
                ▼
Phase 3: Droga A (1 tydzień)
  ├── 3.1 Welcome sequence
  ├── 3.2 Intro toast (pierwsze 3 ekspozycje)
  └── 3.3 Curriculum hook w toaście (preview Fazy 4)
                │
                ▼
Phase 4: Droga B 1.0 (4-6 tyg.)
  ├── 4.1 Curriculum generator (algorytm A → ew. LLM B później)
  ├── 4.2 Lesson view
  ├── 4.3 Reinforcement w toaście
  └── 4.4 Postęp tygodniowy
                │
                ▼
Phase 5: Droga E (2-3 tyg.)
  ├── 5.1 SavingsCalculator
  ├── 5.2 Weekly Report
  ├── 5.3 Menu bar updates
  └── 5.4 Email raport (opt-in)
                │
                ▼
Phase 6: Launch (2-3 tyg.)
  ├── 6.1 Pricing decyzja
  ├── 6.2 Paywall
  ├── 6.3 Landing page
  └── 6.4 Distribution
                │
                ▼
Phase 7: B2B (długoterminowo)
```

**Łączny czas do launch (Fazy 1–6):** **14–22 tygodnie** (3.5–5.5 miesięcy)
przy pracy part-time. Krótszy niż w v1 dokumentu dzięki rozpoznaniu że Faza 1
jest mniejsza.

---

## Najbliższy krok (tydzień 1)

**AKTUALIZACJA 2026-05-14 (po sesjach 6 i 7):**

**Sesja 6 — Matching Engine Quality ✅** — P-26..P-30 zamknięte. Word-boundary
match, depth+isInteractive gate, deterministyczny MenuBarIndex, większe
skeletony do LLM, per-layer telemetria.

**Sesja 7 — Coverage Quick Wins ✅** — P-31 częściowo: 3 niezależne fixy
rozszerzające detection surface bez czekania na dane:
- AXPress probe (element z akcją AXPress = klikalny niezależnie od role)
- Walk-down z klikalnego rodzica (gdy puste title+desc → szukamy w dzieciach)
- AXRoleDescription + AXCustomActions czytane i w match() RuleCache

**198 testów passing.** ~30-50% szacunkowy wzrost coverage.

**NASTĘPNY KROK (sesja 8):** Filip używa SFlow 1-2 dni normalnie → analiza
`events.jsonl` poleceniem `jq` (per-layer hit rate per apka) → na bazie danych
**pełny plan coverage iteration** (P-31 część 2, sub-cel 1.11) — wybór 2-3
fixów z 12 brainstormowanych źródeł (sdef parser, GitHub scan, Help-scrape,
prompt rework, etc.) targetujących **konkretne luki Filipa**, nie generyczne.

```bash
# Per-layer hit rate per apka (toasty)
cat ~/Library/Application\ Support/SFlow/events.jsonl | \
  jq -r 'select(.type=="toast") | "\(.bundleId)\t\(.layer)"' | \
  sort | uniq -c | sort -rn

# Per-layer false positives
cat ~/Library/Application\ Support/SFlow/false_positives.jsonl | \
  jq -r '"\(.bundleId)\t\(.layer)"' | \
  sort | uniq -c | sort -rn

# Top misses per apka
./scripts/sflow-analyze
```

Konkretny, do zrobienia jutro. Kolejność zmieniona po sesji v1.1.1, w której
ukończono częściowo Fazę 1.1 (dedup na backendzie) oraz dodano tolerancję
hotkey-suffix w `RuleCache.match` (klient akceptuje "Edit message E" gdy
reguła ma tylko "Edit message"):

1. **Faza 1.0 (NOWA, najszybszy ROI) — re-seed pozostałych bundled apek
   z v1.1.1 promtem.** Terminal, Notion, Claude Desktop nadal mają reguły
   starego v1.0 promptu (avg 1.05–2.13 wariantów tytułów per regule,
   versus 4+ w nowych). 5–10 minut: dla każdej `./scripts/sflow-reseed <bundleId>`
   → review → `promote-to-bundled.sh` → commit. **Robić PIERWSZE** zanim
   ruszamy resztę.

2. **Faza 1.4 + 1.5 — false-positive feedback (cmd-klik) + naprawa bugu
   MenuBarIndex.lookup.** To dwie rzeczy nietknięte przez v1.1.1 a kluczowe
   dla jakości pokrycia. Backend dedup (zrobiony w v1.1.1) odpowiada za
   "rule conflicts before client" — ale **false-positives które przeszły
   przez dedup** wymagają user feedback. Spec:
   `docs/superpowers/specs/2026-05-XX-quality-and-feedback-design.md`

3. **Równolegle Faza 1.6 (rozpoczęcie) — coverage eval dla 5 nowych apek.**
   Wybierz: Notion (po re-seedzie z #1!), Figma, VS Code, Chrome, Raycast.
   Po jednej dziennie: otwórz apkę z SFlow, czekaj na auto-discovery (powinno
   się stać automatycznie!), klikaj 10 popularnych przycisków, notuj hit% i
   false+%. Wynik wpisuj do `docs/coverage-report.md` (nowy plik).

4. **W tle Faza 1.7 (rozpoczęcie) — zaprosić 3 znajomych do bety.** Daj im
   bieżący build, instrukcję "używaj normalnie 7 dni, raz na 2 dni odpal
   `sflow-analyze` i wyślij output". Nie wymagaj jeszcze żadnych ankiet —
   po prostu zbierz baseline data.

Co zostało **częściowo wykonane** w v1.1.1 (a co nadal trzeba w Fazie 1.1
quality gate):
- ✅ Backend post-process dedup overlapping rules (zapobiega lottery toasts
  jak Slack "Search Slack" ⌘F vs ⌘G)
- ✅ Client-side tolerance "Edit message E" → match "Edit message"
- ❌ Client-side filtr `confidence: medium + source: inferred_pattern`
  (nadal pokazujemy te toasty)
- ❌ Mechanizm "experimental" toggle dla low-confidence reguł
- ❌ Quality gate przy zapisie do cache (`DiscoveryService`)

**Czego NIE robić w tym tygodniu:**
- Nie projektuj curriculum (Faza 4) — za wcześnie
- Nie pisz landing page'u (Faza 6) — nie ma czego sprzedawać
- Nie integruj telemetry z serwerem (Faza 2) — Faza 1 musi być solidna
- Nie poleruj toasta wizualnie (Faza 3) — to 1 tydzień pracy później, nie teraz

---

## Outstanding issues (do rozwiązania)

- **P-49 (2026-05-16) — Toast Slacka nie renderuje wizualnie mimo emisji**
  (multi-monitor / fullscreen) — sformalizowane jako P-49 w `audit-phase-0.md`.
  Reguły `slack-msg-*` poprawnie dopasowane w `ShortcutRules`, `events.jsonl`
  pokazuje toast, ale `ToastWindow` na 2. monitorze nie pojawia się.
  **Blocker dla Fazy 1.7 (beta)** — multi-monitor to większość ICP power-userów.
  Pełna diagnoza + hipotezy + plan testów:
  [`issues/2026-05-16-slack-toast-not-rendering.md`](./issues/2026-05-16-slack-toast-not-rendering.md)

---

*Status: roboczy roadmap, v2. Każda faza dostanie osobny spec + plan przed
implementacją. Następny krok: spec Fazy 1.1+1.4 (quality gate + false-positive
detection).*
