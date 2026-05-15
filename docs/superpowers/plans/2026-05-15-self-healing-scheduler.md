# Plan Sesji 11 — Self-healing scheduler przez miss log → `/v1/refresh` (P-8, sub-cel 1.3)

**Data:** 2026-05-15
**Adresuje:** P-8 (audit-phase-0.md), sub-cel 1.3 (audit-phase-1.md)
**Status:** ⬜ pending — do realizacji po sesji 10 (synthetic eval)
**Szacunkowy czas:** ~3 dni roboczych (~12–18h focused work)

> Plan czysto markdownowy. ZERO kodu — implementacja pisana w sesji 11 z TDD.

---

## 1. Po co to robimy (analogia jak dla 12-latka)

Wyobraź sobie, że SFlow to taki sprytny słownik tłumaczeń. "Klikasz 'Compose' w
Slacku → mówię ci że to ⌘N". Słownik został napisany raz (przez Claude'a) i
trzymany w pamięci. **Ale apki się zmieniają** — Notion co 2 tygodnie podmienia
nazwę przycisku z "Compose" na "Write". Słownik dalej szuka "Compose" — nie
znajduje — SFlow milczy. Reguły **gniją**.

Robimy **samonaprawiającą się lodówkę**: lodówka sama widzi że skończyły się
jajka i zamawia nowe. SFlow sam widzi przez miss log że "ostatnio 20 razy
klikałem coś czego nie znam w Notion", wysyła to do backendu, backend prosi
Claude'a "popraw te reguły", nowa wersja zastępuje starą. **Bez Filipa,
bez deployu, bez reseedu.**

Mamy już **30% tej drogi** — `?fresh=1` (cache bypass na backendzie, dodane
w v1.1.1). Brakuje: (a) klient wysyła miss data w body, (b) backend rozumie
"to jest refresh, nie pełny rebuild", (c) scheduler decyduje kiedy odpalić.

---

## 2. Rationale (jak to się ma do roadmap/vision)

**Z roadmap.md Faza 1.3:** "Self-healing przez miss log → `/v1/refresh`. Klient:
scheduler (NSBackgroundActivityScheduler) raz dziennie patrzy na events.jsonl,
jeśli ≥20 missów + ≥3 powtarzające się tytuły 3x → POST /v1/refresh."

**Z product-vision.md sekcja 5e2:** Self-healing jest komplementarny z synthetic
eval (P-33) — eval łapie błędy przed pierwszym kontaktem z userem, self-healing
naprawia drift po kontakcie. Razem tworzą **pełną pętlę quality**.

**Z audit-phase-0.md P-8:** Severity ŚREDNIA na początku, WYSOKA w czasie.
Notion update'uje co 2 tygodnie — po 90d (TTL cache) widzimy 6 cykli driftu
bez auto-refresh. Praktycznie znaczy że bundled.json starzeje się szybciej niż
go reseedujemy ręcznie.

**Z audit-phase-1.md sub-cel 1.3 (rekomendacja):** **Droga A** = pełny
`/v1/refresh` endpoint (osobny od `/v1/discover`). Self-healing jest unikatowym
feature'em SFlow vs konkurencja — warto zrobić porządnie.

---

## 3. Decyzje do podjęcia przed startem (Filipie, wybierz)

### Decyzja D-1: Osobny endpoint `/v1/refresh` czy rozszerzenie `/v1/discover`?

| Opcja | Plus | Minus |
|---|---|---|
| **A. Osobny `/v1/refresh`** (Recommended) | Czyste responsibilities, prostsze testy, łatwy versioning | Nowy endpoint, nowe handler, nowy prompt |
| B. Rozszerzenie `/v1/discover` o opcjonalne `missExamples` body | ~30% już zbudowane (`?fresh=1` infra) | Handler robi za dużo, mixed concerns |
| C. CLI tool only (`./scripts/sflow-refresh`) | Najprostsze, brak nowego endpointu | Wymaga manual Filipa, łamie "self-healing" hasło |

**Rekomendacja:** **A — osobny endpoint.** Zgodne z rekomendacją z audit-phase-1.md
sub-cel 1.3. Refresh ma inną semantykę niż discovery (input zawiera już istniejące
rules + miss examples) i inny prompt do Claude'a ("update these rules" vs
"generate from scratch"). Mieszanie ich w jednym handlerze tworzy spaghetti.
Plus: osobny endpoint = osobne metryki w P-21 dashboard.

### Decyzja D-2: Co backend dostaje w body `/v1/refresh`?

| Opcja | Body | Plus | Minus |
|---|---|---|---|
| **A. Minimal — currentRules + missExamples** (Recommended) | `{bundleId, appVersion, currentRules, missExamples}` | Mały payload, focused prompt | Brak fresh menu bar/skeleton — Claude może zgadywać |
| B. Full — wszystko co `/v1/discover` + miss data | `{bundleId, appVersion, currentRules, missExamples, menuBar, uiSkeleton}` | Claude ma pełny kontekst | Duży payload (~50KB), ryzykuje max_tokens jak Android Studio |
| C. Hybrid — refresh tylko zmienione reguły + minimal context | Częściowy update | Tani | Złożona logika diff |

**Rekomendacja:** **A — minimal.** Po pierwsze: miss data zawiera już nowe
tytuły (te które nie matchują), to wystarczy żeby Claude widział drift. Po
drugie: backend ma `?fresh=1` jeśli potrzebne full rebuild — refresh ma być
ekonomiczny. Po trzecie: zmniejsza ryzyko max_tokens truncation (P-34 zamknięte
ale wracać nie chcemy).

### Decyzja D-3: Trigger threshold dla schedulera (kiedy odpalać refresh)

| Opcja | Threshold | Plus | Minus |
|---|---|---|---|
| **A. ≥20 missów w 7 dniach + ≥3 powtarzające się tytuły (≥3x)** (Recommended) | konserwatywne | Niski koszt API, refresh tylko gdy drift | Może opóźniać dla mniej używanych apek |
| B. ≥10 missów w 14 dniach | luźne | Częstsze refresh, lepiej responsywne | Więcej API calli (~$0.05/refresh) |
| C. Hard time-based: 30 dni od ostatniego discovery | proste | Predictable | Refresh nawet bez driftu = strata |
| D. Hybrid: A albo C (whichever first) | konserwatywne + safety net | Balanced | Złożona logika |

**Rekomendacja:** **A — z audit-phase-1.md.** Konserwatywne progi minimalizują
nadmiarowe API calle (Faza 2 wymaga uważnego budżetu). Walidujemy progi na Filipie
+ 3 betę. Jeśli okaże się że refresh nie odpala wystarczająco często → poluzuj
do B.

### Decyzja D-4: Co robi klient gdy refresh response przyjdzie?

| Opcja | Mechanizm | Plus | Minus |
|---|---|---|---|
| **A. Zastąp cache całkowicie** (Recommended) | `cache/<bundleId>.json` overwrite | Czyste, prostsze | Tracimy "stare ale działające" reguły |
| B. Merge — nowe + stare unique | Konfliktów po `shortcutId` | Bezpieczne, brak regresji | Cache rośnie nieskończenie |
| C. Quality gate przed zastąpieniem | Sprawdź czy nowe rules mają ≥80% pokrycia starych | Bezpieczne | Złożone, wymaga additional logic |

**Rekomendacja:** **A — zastąp.** Refresh jest *gradient update* — backend
generuje **nowe pełne reguły** uwzględniając miss data. Jeśli backend zwróci
gorszy zestaw, synthetic eval (sesja 10) powinno to wyłapać przez score. W
ostateczności user może rollback przez manual reseed. **Merge byłby zły** —
gromadziłby duplikaty po N refresh'ach. Quality gate (opcja C) overengineered.

### Decyzja D-5: Częstotliwość schedulera klient-side

| Opcja | Częstotliwość | Plus | Minus |
|---|---|---|---|
| **A. Raz dziennie** (Recommended) | 24h interval, NSBackgroundActivityScheduler `tolerance: 2h` | Niski wpływ na bateria, predictable | Drift do 24h po przekroczeniu threshold |
| B. Co godzinę | 1h | Bardzo responsywne | Częste skanowanie events.jsonl — koszt CPU |
| C. Reaktywnie — gdy miss event zwiększa licznik ponad threshold | event-driven | Najszybsze | Trudne do test, scheduler complexity |

**Rekomendacja:** **A — raz dziennie.** Drift na poziomie godzin nie ma znaczenia
dla user value (i tak nie używa skrótu którego nie zna). 24h interval daje
predictable behavior, łatwy test, niskie zużycie zasobów.

### Decyzja D-6: Co jeśli refresh fails (network, rate limit, max_tokens)?

| Opcja | Plus | Minus |
|---|---|---|
| **A. Silent retry następnym ticku schedulera (24h później)** (Recommended) | Brak spam logów, samonaprawiające | Drift przez 24h więcej |
| B. Immediate retry z exp backoff (1min, 5min, 30min) | Szybsza naprawa | Może spam'ować backend |
| C. Notyfikacja menu bar "refresh failed, retry later?" | User-aware | UX inwazyjne, większość userów ignoruje |

**Rekomendacja:** **A — silent retry.** Self-healing ma być **niewidzialne**.
Filip widzi failures w events.jsonl jeśli chce (logujemy `refresh_failed`).
Backend metryki (P-21) pokażą agregat.

---

## 4. Files to touch (pliki dotykane w tej sesji)

| Akcja | Plik | Zmiana |
|---|---|---|
| New | `backend/src/handlers/refresh.ts` | Cała logika `/v1/refresh` endpoint — input validation, prompt Claude'a, response |
| New | `backend/src/refreshPrompt.ts` | Prompt template dla refresh ("update these rules to match these unmatched elements") |
| Modify | `backend/src/index.ts` | Wire route `/v1/refresh` POST |
| Modify | `backend/src/types.ts` | `RefreshRequestSchema` (zod), reuse `RuleSchema` dla response |
| New | `backend/test/refresh.test.ts` | Tests: valid request, malformed body, prompt structure |
| New | `SFlow/RefreshScheduler.swift` | `NSBackgroundActivityScheduler`, ticka co 24h, agreguje miss data |
| New | `SFlow/MissAggregator.swift` | Czyta `events.jsonl` z ostatnich 7 dni, grupuje per bundleId, liczy threshold |
| Modify | `SFlow/DiscoveryClient.swift` | Nowa metoda `requestRefresh(bundleId:, currentRules:, missExamples:)` |
| Modify | `SFlow/AppDelegate.swift` | Wystartuj `RefreshScheduler` przy launchu |
| New | `SFlowTests/RefreshSchedulerTests.swift` | Test schedulera (fake clock, fixture events.jsonl) |
| New | `SFlowTests/MissAggregatorTests.swift` | Test agregacji, threshold logic |
| Modify | `docs/audit-phase-0.md` | P-8 status 🔵 → 🟢 |
| Modify | `docs/audit-phase-1.md` | Sub-cel 1.3 status 🔵 → 🟢 |
| Modify | `docs/roadmap.md` | Session log entry |

**Pliki NIETYKANE w tej sesji:**
- `ClickWatcher.swift`, `TooltipObserver.swift`, `ShortcutRules.swift`,
  `AXSkeletonExtractor.swift`, `RuleCache.swift` (do drobnych jeśli sesja 10
  złamie coś — patrz §7 Risk 4)
- `scripts/sflow-video-*`

---

## 5. Task breakdown (TDD-style, atomic)

### Task 1 — `MissAggregator` testy failing (TDD red)

- Plik: `SFlowTests/MissAggregatorTests.swift`
- Test 1: 20 missów w 7 dniach, 3 powtórzone tytuły 3x → `shouldRefresh: true`
- Test 2: 5 missów → `shouldRefresh: false` (poniżej threshold)
- Test 3: 20 missów ale każdy unikalny tytuł → `shouldRefresh: false` (brak powtórzeń)
- Test 4: events.jsonl pusty → `shouldRefresh: false`
- Test 5: events.jsonl ma misses ze starszej niż 7 dni → ignorowane

**Acceptance:** 5 testów czerwone

### Task 2 — `MissAggregator` implementation (TDD green)

- Plik: `SFlow/MissAggregator.swift`
- Czyta `~/Library/Application Support/SFlow/events.jsonl`
- Filter: `type == "miss"`, `timestamp` w ostatnich 7 dniach
- Group by `bundleId`
- Per bundleId: count, count of repeated titles
- Returns `[BundleId: AggregatedMisses]`
- Threshold logic z decyzji D-3 (configurable struct)

**Acceptance:** 5 testów z Task 1 zielone

### Task 3 — Backend `/v1/refresh` handler tests (TDD red)

- Plik: `backend/test/refresh.test.ts`
- Test 1: valid request → response z rules
- Test 2: malformed body → 400 z error message
- Test 3: missing `currentRules` → 400
- Test 4: empty `missExamples` array → 400 ("no misses to refresh on")
- Test 5: rate limit (>10/h per IP) → 429
- Mock Anthropic SDK call

**Acceptance:** 5 testów czerwone

### Task 4 — Backend `/v1/refresh` handler implementation

- Plik: `backend/src/handlers/refresh.ts` + `refreshPrompt.ts`
- Zod walidacja `RefreshRequestSchema`
- Prompt template (patrz §6)
- Call Claude (sonnet-4-6, streaming jak w `/v1/discover` po P-34)
- Parse response, walidacja przez `RuleSchema`
- **Integracja z synthetic eval (sesja 10):** po Claude call zawołaj
  `evaluateRules()` jeśli refresh zwraca >1 regułę
- Response: `{rules: [...]}`
- Rate limit: same jak `/v1/discover` (10/h per IP)
- Wire route w `index.ts`

**Acceptance:** 5 testów z Task 3 zielone

### Task 5 — `DiscoveryClient.requestRefresh()`

- Plik: `SFlow/DiscoveryClient.swift`
- Nowa metoda symmetric do existing `requestDiscovery()`
- POST do `/v1/refresh` z body z decyzji D-2A
- Response → parse rules → return `[LoadedRule]`
- Error handling: network errors, 4xx, 5xx, timeout
- Test E2E z fake URLSession

**Acceptance:** unit test passes

### Task 6 — `RefreshScheduler` testy failing

- Plik: `SFlowTests/RefreshSchedulerTests.swift`
- Test 1: scheduler tick → wywołuje `MissAggregator`, dla apek `shouldRefresh: true`
  wywołuje `DiscoveryClient.requestRefresh()`
- Test 2: scheduler tick → `shouldRefresh: false` → nic nie wywołuje
- Test 3: refresh fails (mock) → log `refresh_failed` event, brak retry w tym ticku
- Test 4: refresh success → `RuleCache` reload (mock)
- Fake clock dla `NSBackgroundActivityScheduler`

**Acceptance:** 4 testy czerwone

### Task 7 — `RefreshScheduler` implementation

- Plik: `SFlow/RefreshScheduler.swift`
- `NSBackgroundActivityScheduler` interval=24h, tolerance=2h, repeats=true
- Tick logic: aggregate misses → for each app `shouldRefresh: true` → request
  refresh → write to `cache/<bundleId>.json` → reload RuleCache
- Logging do events.jsonl: `refresh_triggered`, `refresh_success`, `refresh_failed`

**Acceptance:** 4 testy zielone

### Task 8 — Integration w `AppDelegate`

- Plik: `SFlow/AppDelegate.swift`
- W `applicationDidFinishLaunching` startuj `RefreshScheduler`
- Stop przy quit
- Manual test: zostaw SFlow na 24h, sprawdź events.jsonl czy `refresh_triggered`
  pojawia się

**Acceptance:** kompiluje się, manual smoke test passes

### Task 9 — E2E manual test (Filipie)

- Sztucznie wygeneruj misses: kliknij 20× przyciski w Notion których SFlow
  nie zna (lub manually edit events.jsonl)
- Trigger scheduler manualnie (debug menu albo CLI hook)
- Sprawdź: backend dostaje POST `/v1/refresh`, response zawiera nowe rules,
  cache/notion.json zastąpiony, RuleCache widzi nowe rules po `load()`
- Toast pojawia się dla wcześniej missowanych elementów

**Acceptance:** E2E flow działa od kliknięcia w Notion do nowego toasta

### Task 10 — Update audit + roadmap + session log

- `audit-phase-0.md` P-8 → 🟢
- `audit-phase-1.md` sub-cel 1.3 → 🟢
- `roadmap.md` Session log "Sesja 11: Self-healing scheduler"
- Commit "docs: session 11 log + P-8/1.3 closed"

**Acceptance:** wszystkie 3 zaktualizowane

---

## 6. Refresh prompt template (do dopracowania w Task 4)

> Draft. Finalna wersja w `backend/src/refreshPrompt.ts`.

**System:** "Jesteś ekspertem od skrótów klawiszowych aplikacji macOS. Twoje
zadanie: zaktualizować istniejące reguły skrótów tak, żeby pasowały do nowych
elementów UI które user kliknął ale których obecne reguły nie pokrywają."

**User template:**
```
Apka: {appName} ({bundleId}), wersja: {appVersion}

OBECNE reguły (działają częściowo):
[
  { titles: ['Compose'], keys: ['meta','n'], ... },
  ...
]

NIEPOKRYTE elementy (user klikał, brak matcha):
[
  { role: 'AXButton', title: 'Write new email', count: 8 },
  { role: 'AXButton', title: 'New conversation', count: 5 },
  ...
]

Zadanie:
1. Dla każdego niepokrytego elementu, zaktualizuj `titles` w odpowiedniej
   regule (jeśli istnieje semantically equivalent) ALBO dodaj nową regułę.
2. NIE usuwaj reguł które nie są w "niepokrytych" — zostaw je.
3. Sprawdź czy nowe tytuły mają standardowy skrót dla {appName} przez web search.

Zwróć JSON: pełna lista zaktualizowanych reguł.
```

---

## 7. Acceptance criteria (mierzalne)

- [ ] `MissAggregator` testy passing (5 nowych)
- [ ] `RefreshScheduler` testy passing (4 nowe)
- [ ] Backend `/v1/refresh` testy passing (5 nowych)
- [ ] E2E manual flow: 20 misses w events.jsonl → scheduler tick → backend call
      → cache replace → toast appears (Task 9)
- [ ] Łącznie testów: 198 baseline + 4 (sesja 10) + 14 (sesja 11) = **216 passing**
- [ ] Koszt: 1 refresh = ~$0.05 (Claude generation), expected ~10 refreshów/tydzień
      dla 5 apek bundled = $0.50/tydzień
- [ ] Backend log każdy `/v1/refresh`: `{type: refresh, bundleId, missCount, rulesGenerated}`
- [ ] Klient log każdy refresh: `refresh_triggered/success/failed` w events.jsonl

---

## 8. Risks

### Risk 1 — Scheduler trigger w niewłaściwym momencie (Mac uśpiony)

**Symptom:** Scheduler powinien tickać raz dziennie ale Mac jest uśpiony 8h,
scheduler triggeruje w środku dnia roboczego → spike CPU/network.

**Mitigacja:**
- `NSBackgroundActivityScheduler` honoruje system schedule (uruchamia gdy
  bateria OK, network OK, system idle)
- `tolerance: 2h` daje OS swobodę wyboru optimal time
- Test na real Macu z prawdziwym usage 24h+

**Probability:** NISKA. NSBAS jest właśnie do tego.

### Risk 2 — Refresh psuje istniejące reguły (regresja)

**Symptom:** Po refresh, reguły które działały wcześniej teraz nie matchują
("Compose" zostało zastąpione przez "Write" w `titles`).

**Mitigacja:**
- Synthetic eval (sesja 10) automatically rozwiązuje — score nowych reguł musi
  być ≥3 żeby nie były experimental
- Refresh response idzie przez `evaluateRules` (Task 4 wymaga integracji)
- W ostateczności: manual rollback przez `?fresh=1&action=force_rebuild`

**Probability:** ŚREDNIA. Refresh prompt **musi** mówić Claude'owi "nie usuwaj
istniejących titles bez powodu".

### Risk 3 — Refresh storm — wszyscy userzy refresh'ują tę samą apkę jednocześnie

**Symptom:** Notion releases update, 100 userów ma misses, wszyscy triggerują
refresh w ten sam dzień → backend rate limit hit, koszty Claude'a spike'ują.

**Mitigacja:**
- Rate limit per-IP nie pomaga (różne IP). Trzeba per-bundleId rate limit w KV:
  jeśli `lastRefresh<bundleId>` <24h temu, zwróć cached result bez nowego call
- Effectively: 1 refresh dziennie per apka globalnie, koszt $0.05/dzień/apka
  niezależnie od liczby userów

**Probability:** ŚREDNIA-WYSOKA. Skala issue.

**Implementacja mitigacji:** Task 4 wprowadza `KV:lastRefresh:<bundleId>` →
TTL 24h. Pierwszy user wywoła Claude, kolejni 23h dostają cached response.

### Risk 4 — RuleCache reload po refresh łapie się z innymi sesjami (lock)

**Symptom:** Inny terminal (sesja A/B/C/D nad ClickWatcher) modyfikuje
`RuleCache.swift` (np. tooltip rules integration), nasza sesja 11 dodaje
trigger `RuleCache.reload()`. Konflikt merge.

**Mitigacja:**
- Sesja 11 czeka aż A/B/C/D zostaną zmerge'owane
- `RuleCache.reload()` jest już atomic (load() removeAll → reload all files)
- Trigger tylko przez Notification — RefreshScheduler post'uje notification,
  istniejący kod RuleCache słucha (jeśli jeszcze nie, dodaj 1 linię)

**Probability:** NISKA. Trigger to 1 linia notification.

### Risk 5 — Self-healing nie jest "self" bo Claude robi błędy

**Symptom:** Po 5 refresh'ach dla Notion, reguły są **gorsze** niż bundled
baseline. Score Claude'a daje wysoki (theatrical eval) ale userzy mają więcej
false positives.

**Mitigacja:**
- W Fazie 2 (po beta z 3-5 osobami): porównuj `false_positive_rate` przed/po
  refresh per bundleId
- Jeśli post-refresh false_positive_rate > 1.5× pre-refresh → automatyczny
  rollback do bundled.json
- Wymaga aggregation w Fazie 2 — w sesji 11 zostawiamy hook ale logic w Fazie 2

**Probability:** ŚREDNIA. Trudno przewidzieć bez real data.

### Risk 6 — events.jsonl rośnie nieskończenie

**Symptom:** Po 6 miesiącach events.jsonl ma 500MB, MissAggregator skan trwa
30s, blokuje scheduler tick.

**Mitigacja:**
- Rotation już istnieje (lub powinno) — sprawdź `EventLogger.swift`
- Sub-cel z fazy 0: events.jsonl rotuje co 7 dni do `events-YYYY-MM-DD.jsonl`
- MissAggregator czyta TYLKO aktualny + ostatnie 7 dni (file glob)
- Jeśli rotation nie ma — dodaj jako micro-task w sesji 11 (Task 11)

**Probability:** WYSOKA jeśli rotation nie istnieje. Sprawdzić w sesji 11 step 0.

---

## 9. Out of scope (NIE robimy w tej sesji)

- ❌ `/v1/refresh` dla `bundled.json` (nie tylko cache/*) — sub-cel 1.16 lub dalej
- ❌ Per-user vs globalny refresh (P-10 KV cache shared globally) — Faza 2
- ❌ Rollback mechanism dla failed refresh — Faza 2 po beta
- ❌ User UI "Refresh now" button w Settings — opcjonalne, jeśli czas
- ❌ Refresh dla apek poza `cache/` (np. tooltip-discovered z sesji B+C) —
      wymaga dyskusji po sesji C

---

## 10. Po sesji 11 — co dalej

Po zamknięciu sesji 11:
- Faza 1 prawie kompletna — pozostają sub-cele 1.4 (false-positive), 1.6
  (coverage report), 1.7 (beta), 1.9 (AXKeyShortcutsValue + identifier)
- **P-21 dashboard** implementacja (spec gotowy w `2026-05-15-backend-observability.md`)
- Faza 2: telemetria, agregacja, korelacja score z false_positive_rate

---

*Plan v1.0. Po sesji A/B/C/D + sesji 10 zaktualizować jeśli sesje 10 wprowadzi
zmiany w schemacie reguł (`score`/`experimental` muszą być honorowane też w
refresh response).*
