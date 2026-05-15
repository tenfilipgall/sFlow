# SFlow — Audyt Fazy 0: Stan aktualny

> Krytyczna analiza wszystkiego co dziś jest zbudowane. Bazuje na **kodzie**,
> nie na poprzednich dokumentach. Każdy problem ma odniesienie do pliku i linii.
> Stan: 2026-05-13, aktualizowany po każdej sesji.

## Legenda statusów problemów (dla AI updatującego po sesji)

- ⬜ **otwarte** — nie tknięte
- 🟡 **w trakcie** — zaczęte, niedokończone
- 🔵 **częściowo** — częściowo rozwiązane (opis co zostaje)
- 🟢 **zamknięte** — rozwiązane + zweryfikowane
- 🔴 **regresja** — wróciło po poprzednim rozwiązaniu

## Aktualne statusy problemów (krytyczne)

| ID | Status | Komentarz |
|---|---|---|
| P-1 Quality gate | 🟢 zamknięte | Backend dedup ✅ + client-side filtr confidence/source ✅ (sesja 2026-05-14) |
| P-2 Retry przy fail | 🟢 zamknięte | DiscoveryAttemptStore (persisted attempted.json) + 1h/24h/7d/30d backoff + 15s AX pre-check + DiscoveryFailureReason classification (6 cases) + forceRetry API + auto-retry on app activation. 15 nowych testów. Manual eval: pre-check zweryfikowany (AppCleaner 0→127). Sesja 8 (2026-05-15) |
| P-3 .failed silently | 🟢 zamknięte | Apps tab w Settings (za toggle showDeveloperFeatures w Advanced) — failed apps z displayString reason + Try again button + persistence + Bug 1 fix (entry preservation gdy app not running). Sesja 8 (2026-05-15) |
| P-4 False-positive feedback | 🟢 zamknięte | cmd-klik na toast + false_positives.jsonl + lokalny disable po 3 zgłoszeniach + /v1/feedback backend + Settings Recent Shortcuts list (sesja 5) |
| P-5 MenuBarIndex bug | 🟢 zamknięte | Fix + 2 nowe testy + 2 poprawione testy (sesja 2026-05-14) |
| P-6 AXKeyShortcutsValue | 🟢 zamknięte | Layer 0 w ClickWatcher, parseAriaShortcut + 10 testów ✅ (sesja 2026-05-14) |
| P-8 Brak /v1/refresh | 🔵 częściowo | `?fresh=1` ✅. Brakuje pełnego refresh z miss data |
| P-19 Bundled.json update path | ⬜ otwarte | Krytyczne dla launch'a |
| P-15 Permissions check Input Monitoring | 🟢 zamknięte | CGPreflightListenEventAccess() + alert (sesja 2026-05-14) |
| P-21 Backend observability | 🔵 częściowo | Structured JSON log w /v1/discover (sesja 2026-05-14). Brakuje: dashboard |
| P-23 Within-rule title dupes | 🟢 zamknięte | Fix w `dedup.ts` + test (sesja 2026-05-14) |
| P-24 Window element matching pasywne | 🔵 częściowo | P-6 (Layer 0) ✅ + P-25 (identifier schema) ✅ (sesja 2026-05-14). Brakuje: backend musi zacząć generować reguły z identifiers (wymaga reseedu apek) |
| P-25 AXIdentifier nie w schemacie reguł | 🟢 zamknięte | AXIdentifier w AXSkeletonExtractor + LoadedMatch.identifiers + RuleCache.match(identifier:) + backend types+prompt ✅ (sesja 2026-05-14) |
| P-26 Layer 0.5/L1 matchuje na rodzicach (parent containers) | 🟢 zamknięte | Audyt 2026-05-14 wskazał że L0.5 i L1 nie mają bramki `isInteractive` — strzelają na AXWindow/AXScrollArea/AXGroup z opisem zawierającym słowo z reguły. Fix: plan `2026-05-14-matching-engine-quality.md` Task 3 (sesja 6, 2026-05-14) |
| P-27 RuleCache.match używa substring zamiast word-boundary | 🟢 zamknięte | `String.contains` matchuje "search" w "research"/"researcher tools". Fix: `wordBoundaryContains` utility + zamiana w RuleCache.match. Plan Task 1+2 (sesja 6, 2026-05-14) |
| P-28 MenuBarIndex.lookup niedeterministyczny | 🟢 zamknięte | `titleMap.first(where:)` iteruje słownik Swift w niezdefiniowanym porządku — to samo kliknięcie może dać różne wyniki. Fix: zbierz wszystkie matche, sortuj po długości klucza desc. Plan Task 4 (sesja 6, 2026-05-14) |
| P-29 AXSkeletonExtractor zrzuca single-occurrence noun-led titles | 🟢 zamknięte | Filtr `count < 2 && !looksVerbLed` zrzuca "Quick Switcher", "Preferences", "Mentions", "Settings" przed wysłaniem do LLM. Fix: usunąć filtr — pozostałe reguły (email/data/digits/imię) wystarczą. Plan Task 8 (sesja 6, 2026-05-14) |
| P-30 Brak per-layer telemetry w events.jsonl | 🟢 zamknięte | `ShortcutEvent` nie wie którą warstwą został wyprodukowany. Bez tego nie da się policzyć "która warstwa fire'uje najczęściej dla apki X" → ślepe iteracje promptu. Fix: dodać `RecognitionLayer` enum + pole `layer` w ShortcutEvent i events.jsonl. Plan Task 5+6+7 (sesja 6, 2026-05-14) |
| P-31 Coverage holes — gdzie SFlow nie pokazuje toasta dla klikalnych elementów | 🟡 w trakcie | Brainstorm sesji 6 (2026-05-14) zidentyfikował 12 potencjalnych źródeł skrótów których SFlow jeszcze nie tapuje: AXCustomActions, AXRoleDescription, `AXUIElementCopyActionNames` probe, AppleScript sdef, szersze Electron regex (Mousetrap, react-hotkeys, blueprintjs), walk-down z interactive ancestor, AXSkeletonExtractor identyfikatory stable-only, GitHub code-search dla OSS apek, Help→Shortcuts auto-scrape, embedded sqlite, keystroke monitoring (Phase 2.2), crowdsource submission. Konkretny plan czeka na dane z `events.jsonl` (sesja 7 telemetry analysis). Sesja 7 quick wins (AXPress probe, walk-down, RoleDescription/CustomActions) ✅ — patrz `2026-05-14-coverage-quick-wins.md`. Pełna iteracja czeka na analizę `events.jsonl` (sesja 8). |
| P-32 Web research w backend prompt jest niesterowany | ⬜ otwarte | Dziś Claude sam decyduje kiedy/jak użyć `web_search` (max 4 use). Brak ukierunkowania per element ani per typ apki. Plan: prompt prowadzi Claude'a — najpierw `{appName} keyboard shortcuts cheatsheet`, potem per-element queries dla unknown skrótów. Łączymy z reseedem (sesja 9, C-bundle). |
| P-33 Quality eval nie skaluje powyżej manualnego (Filip+5 osób) | ⬜ otwarte | Dziś jakość reguł sprawdzamy ręcznie (manual eval per apka) — to nie skaluje na 100+ apek. Plan: synthetic Claude self-eval per regule przy generowaniu (drugi call, ~$0.001/reguła, score 1-5 + reason). Score <3 → experimental flag. Tańsza droga niż AppleScript runner / video eval per apka. Sesja 10. |
| P-34 Claude max_tokens truncation dla wielkich apek | 🟢 zamknięte | max_tokens 8192→32768 + switch na `messages.stream()` (Anthropic wymaga streaming dla max_tokens > 8192). Android Studio: 0 → 93 reguł ✅ (sesja 9a, 2026-05-15). |
| P-35 Backend timeout (>90s) dla niektórych apek | 🔵 częściowo | Prawdopodobnie naprawione przez streaming switch z P-34 — Anthropic odrzucał wcześniej niektóre calle z tego samego powodu. Wymaga weryfikacji na DisplayTuner (`com.benderbureau.displaytuner`) przez Try again. |
| P-36 Chromium window AX labels są puste (Notion Mail) | 🟢 zamknięte (czeka na verify) | Sesja A (2026-05-15) zaadresowała 4 dziury w `ClickWatcher.swift`: (a) gate `depth > 0` usunięty, (b) `extractFallbackTitleFromChildren` czyta `kAXValue` dziecka (z filtrem static-text-like ról + cap 100 znaków), (c) 1-level rekurencja, (d) `kAXValue` czytane na głównym elemencie i feed do effectiveTitle gdy element to static-text-like. Plus rich `MissEvent` (identifier/value/roleDescription/customActions/subtreeLabel) — sub-cel 1.14. 219 testów passing. Manual verify na Notion Mail: kliknięcie ikonek Compose/Archive/Sidebar po rebuildzie z Xcode. |
| P-37 Tooltip-as-discovery (React portal) nie eksploatowane | 🟢 zamknięte (B verified na 2 apkach) | **Sesja B verified Filipem 2026-05-15 wieczór** na Notion Mail (5/5 ikonek: Compose/Archive/Close sidebar/Reply/Forward) + Notion Calendar (po dorobieniu split-badge parser). 4 iteracje fix'ów: (1) `+` separator w parserze, (2) hit-test pod kursorem zwraca rect przycisku (nie tooltipa), (3) sanity-check rect >200×200 (Chromium czasem zwraca cały panel), (4) split-badge dla apek wystawiających modyfikator osobno. Warstwa `L0.3` w `ClickWatcher` query'uje `DiscoveredStore.lookup(near: cursorAX)` na początku każdego klika. 256 testy passing. **Sesja C (backend `/v1/discovered` crowdsource) — odłożona** do testu generalizacji B na Linear/Discord/Slack/Notion main. |

Reszta problemów P-7, P-9..P-22 — patrz pełna lista poniżej.

---

## Executive summary

**Co działa:** SFlow ma w pełni zaimplementowany silnik detekcji kliknięć
z 7-warstwowym matchingiem (L0/L0.5/L1/L2/L3/L4 + direct menu bar), backend
Cloudflare Worker generujący reguły przez Claude API, automatyczny pipeline
discovery przy aktywacji nowej apki, miss log + per-layer telemetry, oraz
CLI do reseed'owania 5 zweryfikowanych apek. **Word-boundary matching +
depth gate + MenuBarIndex determinism** (sesja 6) wyeliminowały fundamentalne
bugi rozpoznawania. **AXPress probe + walk-down + AXRoleDescription/CustomActions**
(sesja 7) rozszerzyły detection surface. ~3300 linii Swift, ~600 linii TypeScript,
~2200 linii testów (**198 passing**).

**Co nie działa / nie istnieje:** Brak retry przy nieudanej discovery (P-2),
brak `/v1/refresh` z miss data (P-8), brak bundled.json update path (P-19),
brak testów E2E (P-18). **Coverage holes** — quick wins zrobione w sesji 7
(P-31 🟡 partial), pełna iteracja czeka na dane z `events.jsonl` (sesja 8).

**Kluczowa diagnoza:** Fundament rozpoznawania jest **stabilny** (sesja 6) +
detection surface **rozszerzona** (sesja 7). Telemetria per-layer w
`events.jsonl` odblokowuje **data-driven coverage iteration** (sesja 8 po
1-2 dniach użycia). Następne mechanizmy higieny jakości (retry, refresh,
bundled update path) — sesje 9-11.

---

## Inwentaryzacja: co jest, gdzie, ile

### Klient (Swift) — `SFlow/`

| Plik | LOC | Rola | Stan |
|---|---|---|---|
| `ClickWatcher.swift` | 311 | Główna pętla detekcji, 5 warstw matching | ✅ działa |
| `ShortcutRules.swift` | 716 | Hardcoded L1 + L4 reguły, 18 apek | ✅ działa, legacy |
| `RuleCache.swift` | ~125 | Ładuje JSON rules, decyduje match. Od v1.1.1: `stripHotkeySuffix()` second-chance match dla Electron menu items ("Edit message E" matchuje regułę "Edit message") | ✅ działa, ⚠️ brak quality gate filtr po confidence/source |
| `MenuBarIndex.swift` | 164 | L3: fuzzy menu match | ✅ działa, ⚠️ znany bug |
| `MenuBarDumper.swift` | 67 | Dump menu bar dla `/v1/discover` | ✅ działa |
| `MenuBarCache.swift` | 52 | Cache menu bar per bundleId+version | ✅ działa |
| `AXSkeletonExtractor.swift` | 147 | Skanuje AX tree, filtruje privacy | ✅ działa |
| `DiscoveryService.swift` | 94 | **Auto-trigger przy aktywacji apki** | ✅ działa, ⚠️ brak retry |
| `DiscoveryClient.swift` | 88 | HTTP do `/v1/discover` | ✅ działa |
| `LoadedRule.swift` | 77 | Model danych dla JSON rules | ✅ działa |
| `MatchConfidence.swift` | 13 | Enum + comparable | ✅ działa |
| `EventLogger.swift` | 79 | Loguje toast + miss do JSONL | ✅ działa |
| `Analyzer.swift` | 94 | CLI `--analyze` agreguje miss log | ✅ działa |
| `Reseeder.swift` | 236 | CLI `--reseed[-all]` dla 4 apek | ✅ działa |
| `ElectronShortcutScanner.swift` | 290 | Skan ASAR + Service Worker cache | ✅ działa |
| `AsarReader.swift` | 62 | Parser formatu ASAR | ✅ działa |
| `BundleStringsScanner.swift` | 94 | Skan stringów z bundle | ✅ działa |
| `AppDelegate.swift` | 153 | Lifecycle + status item | ✅ działa |
| `ToastWindow.swift` | 111 | UI toasta | ✅ działa |
| `SeedMode.swift` | 78 | CLI `--seed` dev tool | ✅ działa |
| `main.swift` | 23 | CLI dispatcher | ✅ działa |
| `RuleStorage.swift` | 31 | Path management + seed | ✅ działa |
| `ShortcutEvent.swift` | 10 | Model | ✅ działa |

**RAZEM:** 3079 linii produkcyjnych Swift.

### Backend (TypeScript) — `backend/src/`

| Plik | LOC | Rola | Stan |
|---|---|---|---|
| `index.ts` | 25 | Router | ✅ działa |
| `handlers/discover.ts` | ~75 | Endpoint `/v1/discover` (+ `?fresh=1` cache bypass) | ✅ działa, ⚠️ pełny `/v1/refresh` z miss data nadal brakuje |
| `claude.ts` | ~95 | Claude API call z web_search, wywołuje `dedupOverlappingRules` przed return | ✅ działa |
| `prompt.ts` | ~80 | System + user prompt z DISJOINT TITLES + HOTKEY-SUFFIX VARIANTS sekcjami | ✅ v1.1.1 prompt |
| `prompt-examples.ts` | ~45 | Few-shot examples (Slack + Obsidian + "Edit message E" Electron menu example) | ✅ działa |
| `storage.ts` | 36 | KV cache (key=`rules:bundle:M.m`) | ✅ 90d TTL, bypass przez `?fresh=1` |
| `dedup.ts` | 95 | Usuwa cross-rule title overlaps. Ranking: `menu_bar > confidence > fewer titles > order` | ✅ działa (v1.1.1) |
| `ratelimit.ts` | 28 | 10/h per IP | ✅ działa, ⚠️ za sztywne |
| `types.ts` | 53 | Zod schemas | ✅ działa, ⚠️ luźny `keys` |

### Testy

- **Swift:** 15 plików, 1432 linii, pokrywają parsing, matching, dedup,
  privacy filter
- **Backend:** 7 plików, 433 linii, pokrywają Claude parsing, dedup, prompt
- **Brakuje:** E2E (uruchom Slack → SFlow → klik → toast), integration
  z real apps

### Dokumentacja

- `product-vision.md` — wizja produktu **+ zasady współpracy AI (sekcja 0)**
- `roadmap.md` — plan v2 **+ Proces ciągły + Session log**
- `audit-phase-0.md` — ten plik (status problemów)
- `audit-phase-1.md` — sub-cele Fazy 1 (status sub-celów + sub-cel 1.8 video eval)
- `layer-1-5-design-brief.md` — design brief dla agentów (historyczny)
- `deep-think-auto-discovery.md` — deep think prompt (historyczny)
- `v1.1-roadmap.md` — odłożone idee (5 pomysłów)
- `wip-web-shortcuts.md` — porzucona próba (web shortcuts)
- `notion-calendar-todo.md` — stuck items
- `superpowers/specs/*` + `superpowers/plans/*` — sukcesywne specy

### Dev workflow tools

| Narzędzie | Lokacja | Stan | Cel |
|---|---|---|---|
| `sflow-analyze` | `scripts/` | ✅ działa | CLI raport top miss apek + przyciski |
| `sflow-reseed` / `--reseed[-all]` | `scripts/` + Reseeder.swift | ✅ działa | Wymusza fresh discovery dla bundled apek (z `?fresh=1`) |
| `promote-to-bundled.sh` | `scripts/` | ✅ działa | Merge cache files → bundled.json z review |
| `sflow-video-eval` | `scripts/` (PLANOWANY) | ⬜ pending | Extract klatek + analiza wrong toasts. Patrz audit-phase-1.md sub-cel 1.8 |
| `sflow-video-extract.swift` | `scripts/` (PLANOWANY) | ⬜ pending | Helper dla `sflow-video-eval` używający AVFoundation |
| AppleScript driver per apka | brak | ⬜ pending (Faza 2) | Headless test runner per Sub-cel 1.8 Droga A |

---

## Architektura detekcji (pseudokod z `ClickWatcher.swift`)

```
handleMouseDown():
  frontmost = NSWorkspace.frontmostApplication
  bundleId = frontmost.bundleIdentifier
  
  axApp = AXUIElementCreateApplication(pid)
  AXManualAccessibility = true       // wymuś Electron AX tree
  AXEnhancedUserInterface = true
  element = AXUIElementCopyElementAtPosition(axApp, x, y)
  
  for depth in 0..6:
    attrs = read 7 AX attrs (role, desc, title, subrole, placeholder, help, identifier)
    
    if isInteractive(role) && firstInteractiveMiss == nil:
      capture firstInteractiveMiss for log
    
    # Layer 0.5: JSON rules (bundled + cache + user_overrides)
    if ruleCache.match(...): emit(); return
    
    # Layer 1: hardcoded ShortcutRules.match (per-app Swift)
    if ShortcutRules.match(...) confidence ≥ medium: emit(); return
    
    # Layer 2: kAXHelpAttribute parse
    if help text contains shortcut: emit(); return
    
    # Layer 3 + 4: only on interactive roles
    if isInteractive:
      query = elementQuery(element)  # desc > title > placeholder > id
      if menuBarIndex.lookup(query) confidence ≥ medium: emit(); return
      if ShortcutRules.universalRules.first(matching: ...): emit(); return
    
    element = element.parent
  
  # Fallback
  checkMenuBar(bundleId, pid, ...)
  
  if !didEmit && firstInteractiveMiss:
    EventLogger.logMiss(...)
```

### Co tu jest **dobrze zaprojektowane**

1. **AXManualAccessibility forcing** (ClickWatcher.swift:73-75) — kluczowy
   trick dla Electron. Bez tego Slack/Notion/Cursor zwracają puste atrybuty.
2. **Multi-monitor coord conversion** (ClickWatcher.swift:66-69) — używa
   `NSScreen.screens[0]` (menu-bar screen), nie `main`. Bez tego AX-pos
   z drugiego ekranu kończy w menu barze.
3. **6-poziomowa pętla po przodkach** — user trafia w ikonkę SVG wewnątrz
   przycisku, my znajdujemy `compose` na przodku.
4. **Debounce w `emit()`** (ClickWatcher.swift:289) — 2s blokuje powtórki
   tego samego shortcutId, ale różne shortcuts przechodzą.
5. **Privacy filter w AXSkeletonExtractor** — emails, ISO dates, human
   names, hash/@ prefixes — wszystko filtrowane przed wysłaniem.
6. **Layer-by-layer fall-through** — pierwsze trafienie wygrywa, deterministyczna
   kolejność priorytetów.
7. **Async write w EventLogger** — `writeQueue.async` zapobiega blokowaniu
   CGEventTap callback.

---

## Architektura silnika LLM (backend)

```
POST /v1/discover { bundleId, appName, appVersion, menuBar, uiSkeleton, clientVersion }
   │
   ▼
Zod validation (DiscoverRequestSchema)
   │
   ▼
?fresh=1 ? skip cache : KV lookup (key=rules:bundleId:major.minor)
   │
   ▼ (cache miss)
Rate limit check (10/h per IP)
   │
   ▼
Claude API (claude-sonnet-4-6, max 8192 tokens, web_search 4 uses)
   │  System prompt: schema + rules + few-shot
   │  User prompt: menu bar dump + UI skeleton
   ▼
extractFinalText (ostatni text block po tool_use)
   │
   ▼
parseRulesJSON (strip ```, extract { ... })
   │
   ▼
Zod RuleSchema validation per rule (drop invalid silently)
   │
   ▼
dedupOverlappingRules (menu_bar > confidence > fewer titles)
   │
   ▼
KV put (90-day TTL)
   │
   ▼
Response { bundleId, rulesVersion, rules: [...] }
```

### Co tu jest **dobrze zaprojektowane**

1. **Web search tool** — Claude może wyszukać hidden shortcuts (Slack ⌘K
   nie ma w menu bar, tylko w docs).
2. **`extractFinalText`** — bierze ostatni text block, pomija preamble +
   tool_use. To krytyczne bo Claude z web_search emituje multiple blocks.
3. **`extractJSONObject`** — strip code fence + slice od pierwszego `{`
   do ostatniego `}` — odporne na prozę przed/po JSON.
4. **Dedup po titles** — kluczowy quality gate. Bez tego Claude generuje
   2 reguły z tym samym title "Search" → konflikt → fałszywy match.
5. **Dedup winner ranking** — menu_bar > confidence > specificity. Sensowne
   priorytety.
6. **Cache key z `major.minor`** — apka 1.5.3 i 1.5.7 dzielą cache.
   Discord 27.0 → 28.0 wymusi refresh.

---

## Problemy — pełna lista (P-1 do P-22)

### P-1: Brak quality gate dla auto-discovered rules

**Plik:** `RuleCache.swift:81`
```swift
if !showExperimental, rule.confidence == .low { continue }
```

**Co jest:** Tylko `low` confidence jest ukrywane przy `showExperimental=false`
(default). Wszystkie `medium` reguły idą do toasta.

**Problem:** Auto-discovery przez Claude zwraca też **`medium`** reguły
z `source: web_docs_third_party` (cheatsheets, forum posts) lub przypadkiem
sourceless. Te są niepotwierdzone. Pokazujemy je jako toasty → ryzyko
fałszywych skrótów uczonych userowi.

**Severity:** WYSOKA. Dla bundled.json (4 zweryfikowane apki) to OK bo ręcznie
sprawdziliśmy. Dla auto-discoverowanej Notion / Figma / random apki — to
najbliższy false-positive vector.

### P-2: Brak retry przy nieudanej discovery

**Plik:** `DiscoveryService.swift:40-44`
```swift
if attempted.contains(bundleId) { return }
attempted.insert(bundleId)
```

**Co jest:** `attempted: Set<String>` w pamięci. Jedna nieudana próba
discovery → `attempted` markuje apkę, drugiej próby nie ma. Po restarcie
SFlow restartuje set, więc raz na sesję jest jedna szansa.

**Problem case:** User aktywuje Notion 2 sekundy po starcie systemu. AX tree
jeszcze nie wczytane. `MenuBarDumper.dump` zwraca pustą listę. `AXSkeletonExtractor`
zwraca puste skeleton. `/v1/discover` dostaje puste dane → Claude generuje
bezsens albo nic → cache jest **trwale** pusty (90 dni!) → user
nigdy nie zobaczy toastów w Notion dopóki:
1. KV cache nie wygaśnie (90 dni)
2. Albo user nie odpali `--reseed notion.id` ręcznie
3. Albo nie ubije bundled.json + cache i restart

**Severity:** WYSOKA. To pierwsza rzecz która się zepsuje u prawdziwego usera.

### P-3: `.failed` status silently swallowed

**Plik:** `AppDelegate.swift:131-132`
```swift
case .failed:
    self?.updateStatusItemTitle("")
```

**Co jest:** Discovery faila → menu bar wraca do pustego stanu. User nie wie
że coś poszło źle. Nie ma "Retry" buttona, nie ma log'a, nie ma alert'u.

**Severity:** ŚREDNIA. UX problem, ale powiązane z P-2 (mechanizm retry).

### P-4: Brak false-positive feedback od usera

**Co nie istnieje:** Nie ma sposobu żeby user powiedział "ten toast pokazuje
złe ⌘C". Miss log łapie "brak matcha", ale nie "zły match".

**Konsekwencja:** SFlow uczy złych skrótów, my się o tym nie dowiadujemy
nigdy.

**Severity:** WYSOKA. Mniej widoczna niż P-1 i P-2, ale długoterminowo
najgorsza dla zaufania użytkowników.

### P-5: Bug w `MenuBarIndex.lookup` — odwrócony substring

**Plik:** `MenuBarIndex.swift:72`
```swift
if let pair = titleMap.first(where: { q.contains($0.key) }) {
    return (entry: pair.value, confidence: .medium)
}
```

**Co jest:** Sprawdza czy **query** zawiera **klucz menu**. Czyli:
- query "Copy link" → contains "copy" → match → ⌘C ❌ false positive
- query "Search messages" → contains "search" → match → ⌘F (lub cokolwiek)

**Co powinno być:** `$0.key.contains(q)` — menu item title zawiera query.
- query "Copy link" → menu items: ["copy", "paste", ...] → żaden nie zawiera
  "copy link" → no match ✅

Lub: tylko exact match (zostawić tylko linię 71).

**Plik:** `notion-calendar-todo.md` notuje to jako **znany bug** — nigdy
nie naprawiony.

**Severity:** WYSOKA. To **główny vector false-positives w dzisiejszym
kodzie**. `MatchConfidence.threshold = .medium`, więc te .medium matche idą
do toasta.

### P-6: Brak AXKeyShortcutsValue (Layer 0)

**Plik:** `SFlow/ClickWatcher.swift:80-178`

**Co nie istnieje:** `ClickWatcher.handleMouseDown()` czyta 7 AX atrybutów
(role, desc, title, subrole, placeholder, help, identifier) — ale
`AXKeyShortcutsValue` nie jest wśród nich. Nigdzie w kodzie.

W Electron/Chromium: `<button aria-keyshortcuts="Meta+K">` →
`AXKeyShortcutsValue = "Meta+K"`. Dostajemy skrót BEZPOŚREDNIO z elementu,
bez żadnych pregenerowanych reguł. Language-agnostic (nie zależy od title).

Gmail ustawia `aria-keyshortcuts="c"` na Compose. Inne Electron apki
prawdopodobnie też — zakres nieznany, wymaga empirycznej weryfikacji.

**Konsekwencja:** Tracimy potencjalnie dużą warstwę zero-config detection
dla window elements. Menu bar dostaje skrót przez `kAXMenuItemCmdChar` —
to samo podejście aktywne, bezpośrednie. Window elements mogłyby mieć
analogiczne dzięki AXKeyShortcutsValue.

**Severity:** **WYSOKA** (awansowana z ŚREDNIEJ). To najszybszy win dla
window element coverage. Implementacja ~2h, potencjalny zwrot ogromny.
Część rozwiązania P-24. Patrz też P-24.

### P-7: Auto-discovery triggeruje natychmiast (no debounce)

**Plik:** `DiscoveryService.swift:35-71`

**Co jest:** Każda `didActivateApplicationNotification` która spełnia warunki
od razu odpala POST.

**Problem case:** User rapidly app-switching (cmd-tab) → 5 apek bez reguł →
5 backend calls w 3 sekundy → rate limit (10/h per IP) zjedzony połowicznie.

**Severity:** NISKA dla typowego usera, ŚREDNIA jeśli wielu userów za jednym
NAT.

### P-8: Brak `/v1/refresh` — reguły gniją w cache

**Plik:** `storage.ts:32-34`

**Co jest:** 90-day TTL na KV. Nic poza tym. Jeśli apka updatuje UI (Notion
co 2 tygodnie zmienia jakieś labels), reguły się starzeją. Miss log to
zobaczy, ale nie ma mechanizmu "wygeneruj nowe na podstawie missów".

**Severity:** ŚREDNIA na początku, WYSOKA w czasie.

### P-9: KV cache key bazuje na `major.minor` — minor bumps invalidate

**Plik:** `storage.ts:5-9`
```typescript
const major = parts[0] ?? "0";
const minor = parts[1] ?? "0";
return `rules:${bundleId}:${major}.${minor}`;
```

**Co jest:** Cache key = `rules:bundle:M.m`. Notion 1.5.7 → 1.5.8 dzieli cache.
Notion 1.6.0 wymusi refresh.

**Problem:** Niektóre apki bumpują minor 10x w miesiącu (Cursor) — wymusza
nadmiarowe Claude calls. Inne nie bumpują minor latami (Slack stabilny).
Per-app strategy byłaby lepsza.

**Severity:** NISKA, ale skaluje się koszt LLM przy dużej bazie userów.

### P-10: KV cache niezależny per user/maszyna (shared globally)

**Co jest:** KV jest globalny — pierwszy user który odpali Notion zapełnia
cache, wszyscy następni dostają tę samą wersję.

**Skutek dobry:** $0.05 per app w sumie, nie per user.
**Skutek zły:** Jeśli pierwszy user miał uszkodzoną AX (Notion 5s po starcie),
cached reguły są kiepskie dla wszystkich. Brak mechanizmu pruning.

**Severity:** ŚREDNIA. Zależy od jakości pierwszych N hitów.

### P-11: Brak walidacji formatu `keys` po stronie backendu

**Plik:** `types.ts:29`
```typescript
keys: z.array(z.string()).min(1).max(5),
```

**Co jest:** Akceptuje dowolne stringi. Claude może zwrócić `["⌘", "K"]` zamiast
`["meta", "k"]`. Klient (`ToastWindow.keySymbol`) zna tylko nasze tokeny.
Jeśli backend przepuści `["⌘", "K"]` → toast zrenderuje "⌘K" → przypadkowo
działa wizualnie, ALE … `keys` jest też porównywane jako `shortcutId`
(debounce + analyzer) — z mixin'em obu formatów debounce się rozjedzie.

**Severity:** NISKA, ale subtelny bug.

### P-12: Hardcoded `ShortcutRules.match` zwraca zawsze `.high`

**Plik:** `ShortcutRules.swift:55`
```swift
return (rule: rule, confidence: .high)
```

**Co jest:** Wszystkie L1 hardcoded reguły są `.high` z założenia (bo "ja je
napisałem ręcznie"). Ale niektóre były napisane bez weryfikacji w real
app — szczególnie te dodane podczas WIP web shortcuts (`wip-web-shortcuts.md`).

**Severity:** NISKA. Większość L1 jest sprawdzona. Po migracji do JSON
rules L1 całkowicie zniknie.

### P-13: MenuBarWatcher skanuje WSZYSTKIE aplikacje przy starcie

**Plik:** `MenuBarIndex.swift:124-127`
```swift
for app in NSWorkspace.shared.runningApplications
    where app.activationPolicy == .regular && app.bundleIdentifier != nil {
    loadOrScan(app: app)
}
```

**Co jest:** Przy starcie SFlow iteruje przez wszystkie aktualnie uruchomione
aplikacje i każdą skanuje (jeśli nie ma w cache). Dla maca z 15-20 apkami
to 15-20× walk całego menu bar.

**Severity:** NISKA. To w tle, ale spike CPU przy starcie. Plus każda apka
może wymagać `AXManualAccessibility` co ją "budzi".

### P-14: `localizedName`-dependent paths w ElectronShortcutScanner

**Plik:** `ElectronShortcutScanner.swift:142, 187-189`
```swift
let support = fm.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/\(appName)")
```

**Co jest:** Service Worker cache pod ścieżką `~/Library/Application Support/<localizedName>/`.
Polski user z apką "Slack" → folder "Slack" (po angielsku, OK). Ale apki
które mają polskie nazwy ekranowe → mismatch.

**Severity:** NISKA dla większości apek.

### P-15: Permissions check tylko AX, brak Input Monitoring

**Plik:** `AppDelegate.swift:78-89`

**Co jest:** Sprawdza `AXIsProcessTrustedWithOptions`, ale nie sprawdza Input
Monitoring. CGEventTap silently fails w `ClickWatcher.setup()` jeśli IM
nie jest grantowane.

**Konsekwencja:** User daje AX, myśli że jest OK, klika — nic się nie dzieje.
Log w `NSLog` ale nie w UI.

**Severity:** ŚREDNIA. Pierwszy onboarding może być słaby.

### P-16: Toggle Enabled/Disabled wycieka observers?

**Plik:** `AppDelegate.swift:56-63`
```swift
@objc private func toggleEnabled() {
    isEnabled.toggle()
    ...
    if isEnabled { startWatcher() } else { clickWatcher = nil }
}
```

**Co jest:** Toggle OFF kasuje `clickWatcher`. Toggle ON woła `startWatcher()`
ponownie, tworzy nowy `DiscoveryService` i woła `observeAppActivation()`.
Ale **stary DiscoveryService nie jest odpinany** — `observer` w
`NSWorkspace.shared.notificationCenter.addObserver(self, …)` nie ma
deinit'u.

**Sprawdzić:** `DiscoveryService` nie ma `deinit` z `removeObserver`.
**Konsekwencja:** Toggle dwa razy → dwa observery → dwa POSTy per app
activation → rate limit szybszy.

**Severity:** NISKA (nikt nie togluje 10x), ale technical debt.

### P-17: Status indicator UI bug potentially

**Plik:** `AppDelegate.swift:99`
```swift
button.title = " " + text   // small offset from the ⌘ icon
```

**Co jest:** Setuje `button.title`, NSImage zostaje obok. Ale w setupie
(linia 47-48) jak jest image, czyści title (`button.title = ""`). Ten flow
może migać.

**Severity:** NISKA.

### P-18: Brak end-to-end testów

**Co nie istnieje:** Żaden test nie uruchamia rzeczywistego AX flow.
Wszystkie testy są jednostkowe na fixtures. Quality regression przy
zmianach `ClickWatcher` lub `RuleCache` może przejść niezauważona.

**Severity:** ŚREDNIA. Manual eval pokrywa lukę, ale jest czasochłonny.

### P-19: bundled.json wersjonowanie i update path nieuregulowane

**Plik:** `RuleStorage.swift:17-30`
```swift
if FileManager.default.fileExists(atPath: dest.path) { return false }
```

**Co jest:** `seedBundledIfMissing` kopiuje shipping bundled.json **tylko
gdy go nie ma**. Po update'cie SFlow 1.0 → 1.1: shipping zawiera nowsze
reguły, ale user ma stare w `~/Library/Application Support/SFlow/rules/bundled.json`.

**Konsekwencja:** Updaty reguł w bundled.json nigdy nie docierają do
istniejących userów.

**Severity:** WYSOKA długoterminowo. Musi być mechanizm "shipping version
> user version → overwrite".

### P-20: Rate limit 10/h per IP — sztywne

**Plik:** `ratelimit.ts:4-5`
```typescript
const WINDOW_SECONDS = 3600;
const MAX_PER_WINDOW = 10;
```

**Problem case:** Power-user instaluje SFlow, ma 30 apek których backend
jeszcze nie zna. Pierwsze 10 dostanie reguły, kolejne 20 → "Rate limit".
Próbują 1h później → cache jeszcze nie ma → Claude call → znowu 10 max.
Onboarding trwa 3h zamiast 3min.

**Severity:** ŚREDNIA. Onboarding UX będzie cierpieć.

### P-21: Brak observability na backendzie

**Co nie istnieje:** Backend nie loguje metrics. Nie wiemy:
- Ile rules per app Claude zwraca w średniej
- Jakie są błędy parsowania JSON (dropped silently w `parseRulesJSON`)
- Ile rules failuje Zod validation (dropped silently w pętli)
- Które bundleIds są najczęstsze
- Ile czasu zajmuje średnio call

**Konsekwencja:** Latamy ślepo. Quality issues u userów = quality issues
których nigdy nie zobaczymy bez bezpośredniego raportu.

**Severity:** WYSOKA gdy zaczniemy mieć userów (Faza 6).

### P-23: Within-rule title duplicates w response Claude'a

**Plik:** `backend/src/dedup.ts` (post-v1.1.1)

**Co jest:** Cross-rule dedup działa, ale Claude czasem listuje ten sam
tytuł 2× w `titles` array jednej reguły (np. rule[14] dla Slack ma
`["Close All", ..., "Close All"]`). Wykryte w analizie reseedu v1.1.1.

**Konsekwencja:** Lekkie zaśmiecenie cache (duplikaty zwiększają payload
~5%). Brak innego efektu — title matchowanie i tak działa.

**Fix:** Jedna linia w `dedupOverlappingRules`:
```typescript
rule.match.titles = [...new Set(rule.match.titles.map(t => t.toLowerCase()))]
  .map(lower => rule.match.titles.find(t => t.toLowerCase() === lower)!);
```
lub prościej: `rule.match.titles = Array.from(new Set(rule.match.titles))`.

**Severity:** BARDZO NISKA. Łatwy fix, można zrobić w następnej sesji
przy okazji innych zmian w `dedup.ts`.

### P-24: Window element matching jest pasywne — główna przyczyna "okna < menu bar"

**Pliki:**
- `SFlow/ClickWatcher.swift:111-122` — L0.5: `ruleCache.match()` porównuje
  title z pregenerowanymi wariantami
- `SFlow/AXSkeletonExtractor.swift:118-146` — `walk()` nie czyta
  `AXKeyShortcutsValue` ani `AXIdentifierAttribute`
- `SFlow/LoadedRule.swift:16-19` — `LoadedMatch: {role, titles}` — brak
  pola `identifiers`
- `SFlow/RuleCache.swift:73-95` — `match()` nie przyjmuje identifiera

**Problem architektoniczny:**

Menu bar matching jest **aktywne**: `checkMenuBar()` czyta
`kAXMenuItemCmdCharAttribute` + `kAXMenuItemCmdModifiersAttribute` —
pobiera PRAWDZIWY skrót z aktualnego menu item w momencie kliknięcia.
Żadnych pregenerowanych danych, żadnej lokalizacji, żadnego przewidywania.

Window element matching jest **pasywne**: `ruleCache.match()` porównuje
title z pregenerowanymi wariantami tytułów z reguł LLM (np.
`["Compose", "Write", "New message", "Utwórz"]`). Reguły muszą z góry
PRZEWIDZIEĆ jak element będzie się nazywał w runtime.

**Konsekwencje tej asymetrii:**
1. **Localization problem** — Discord PL: `title = "Wycisz"`, reguła ma
   `"Mute"` → brak trafienia mimo identycznego elementu
2. **UI drift** — apka zmienia "Add block" na "Insert" → reguła nie
   działa do następnego reseedu (który następuje co 90 dni)
3. **Brak identifier matching** — `kAXIdentifierAttribute` (DOM id, np.
   `"compose-btn"`) jest stable i language-agnostic, ale nie trafia
   ani do skeletonu, ani do schematu reguł
4. **Brak AXKeyShortcutsValue** (P-6) — dla Electron z
   `aria-keyshortcuts` moglibyśmy dostać skrót bezpośrednio z elementu,
   jak menu bar dostaje go z `kAXMenuItemCmdChar`

**Konkretne luki w kodzie (potwierdzone inspekcją):**

| Luka | Plik:linia | Status |
|------|-----------|--------|
| `AXKeyShortcutsValue` nie czytany | `ClickWatcher.swift:80-92` | ⬜ P-6 |
| `AXIdentifierAttribute` nie w `AXSkeletonExtractor` | `AXSkeletonExtractor.swift:122-135` | ⬜ P-25 |
| `LoadedMatch` nie ma pola `identifiers` | `LoadedRule.swift:16-19` | ⬜ P-25 |
| `RuleCache.match()` nie przyjmuje identifier | `RuleCache.swift:73` | ⬜ P-25 |

**Rozwiązanie (dwa etapy):**

Etap 1 (P-6, ~2h): Czytaj `AXKeyShortcutsValue` jako Layer 0 w ClickWatcher,
przed L0.5. Dla elementów z tym atrybutem — instant toast, zero reguł.

Etap 2 (P-25, ~1 dzień): Dodaj `AXIdentifierAttribute` do skeletonu +
`identifiers: [String]?` do `LoadedMatch` + identifier matching w
`RuleCache.match()`. Backend zaczyna generować rules z identifierami.

**Severity:** WYSOKA. Bez tego okna zawsze będą słabsze niż menu bar,
a każda nowa Electron apka z polskim UI wymaga manualnego rozszerzenia
listy wariantów tytułów.

---

### P-26 do P-30: bugi rozpoznawania klikniec wykryte przez audyt 2026-05-14

Wszystkie 5 problemów zostały zidentyfikowane podczas pełnego audytu trybu rozpoznawania klikniec (2026-05-14). Mają wspólny mianownik: **fundament SFlow nie jest jeszcze stabilny**. Każdy z nich tłumaczy konkretny objaw "elementy są pomijane lub źle przypisywane" raportowany przez Filipa.

**Implementacja zaplanowana w:** `docs/superpowers/plans/2026-05-14-matching-engine-quality.md` (9 tasków, ~4h pracy, TDD).

#### P-26: Layer 0.5 i L1 strzelają na rodzicach niezwiązanych

**Plik:** `ClickWatcher.swift:159-184`

**Co jest:** Pętla walking-up (`for _ in 0..<6`) sprawdza Layer 0.5 (RuleCache) i Layer 1 (ShortcutRules) na **każdym** rodzicu — bez sprawdzenia czy rodzic jest klikalny (`isInteractive`). Tylko Layer 2/3/4 mają tę bramkę.

**Konsekwencja:** Klikasz w środek tekstu notki w Notion → walking-up trafia na AXGroup którego description = "page content with search results" → L0.5 matchuje regułę z tytułem "search" przez `desc.contains("search")` → toast ⌘K wystrzeli mimo że żaden przycisk nie był kliknięty.

**Fix:** dodać `shouldRunNonInteractiveLayers(role:depth:)` — depth 0 zawsze przepuszcza (preserwuje Chromium AXGroup clickables), depth > 0 tylko gdy role jest w `interactiveRoles`.

**Severity:** **WYSOKA** — to **najbardziej fundamentalny bug** trybu rozpoznawania. Tłumaczy większość raportowanych false-positives.

#### P-27: RuleCache.match używa `String.contains` zamiast word-boundary

**Plik:** `RuleCache.swift:101-109`

**Co jest:** Stara wersja:
```swift
if titleLC.contains(c) || descLC.contains(c) { return true }
```
Plus `helpLC` ma tylko `==`, bez substring — niespójne.

**Konsekwencja:** Reguła z tytułem `"search"` matchuje **dowolny** element którego tytuł zawiera ciąg liter "s-e-a-r-c-h":
- "Search Slack" ✅ (chcemy)
- "Researcher Tools" ❌ (zawiera "search"!)
- "Vermicotti" ❌ ("micot" zawiera "i" w środku, ale weź gorszy przykład — "research" zawiera "search")

**Fix:** nowa funkcja `wordBoundaryContains(haystack:needle:)` w pliku `TextMatching.swift`. Match wymaga że `needle` jest aligned do word-boundary na lewej stronie (start stringa lub poprzedzający znak nie jest literą/cyfrą). Prawa strona może rozciągać się — "bookmark" dalej matchuje "bookmarks" (plurale OK).

**Severity:** **WYSOKA**. Drugi największy vector false-positives.

#### P-28: MenuBarIndex.lookup niedeterministyczny

**Plik:** `MenuBarIndex.swift:72`

**Co jest:**
```swift
if let pair = titleMap.first(where: { $0.key.contains(q) }) {
    return (entry: pair.value, confidence: .medium)
}
```
`titleMap` to Swift Dictionary. `first(where:)` iteruje go w niezdefiniowanym porządku — **to samo zapytanie może dawać różne wyniki** w różnych instancjach apki.

**Konsekwencja:** Czasem klik na "Find in Files" zwraca regułę z "Find", czasem z "Find Next", czasem z "Find in Files" — losowość.

**Fix:** zbierz **wszystkie** klucze pasujące word-boundary, **sortuj** po długości DESC (najdłuższy = najbardziej specyficzny), pick first. Plus zamiana `contains` na `wordBoundaryContains`.

**Severity:** **WYSOKA**. To tłumaczy wrażenie "czasem działa, czasem nie".

#### P-29: AXSkeletonExtractor zrzuca single-occurrence noun-led titles

**Plik:** `AXSkeletonExtractor.swift:67-68`

**Co jest:**
```swift
let count = counts[item] ?? 1
if count < 2 && !looksVerbLed(title) { continue }
```

Filtr usuwa każdy element który pojawia się tylko raz I nie zaczyna się od czasownika.

**Konsekwencja:** Tytuły "Quick Switcher", "Preferences", "Mentions & Reactions", "Settings", "Saved Items", "Inbox" — same rzeczowniki — **są wyrzucane przed wysłaniem do LLM**. LLM nie generuje dla nich reguł. Toast nigdy się nie pokazuje dla tych elementów.

**Fix:** usunąć filtr `count < 2 && !looksVerbLed`. Pozostałe filtry (email, data, digits, human-name) wystarczą do oczyszczenia szumu.

**Severity:** ŚREDNIA-WYSOKA. Wpływa na pokrycie dla wszystkich nowych apek auto-discoverowanych.

#### P-30: Brak per-layer telemetry

**Plik:** `ShortcutEvent.swift`, `EventLogger.swift`

**Co nie istnieje:** `ShortcutEvent` nie ma pola "który layer (L0/L0.5/L1/L2/L3/L4/menu) wyprodukował ten event". W `events.jsonl` widzimy tylko że toast się pokazał, ale nie wiemy która z 7 ścieżek go wystrzeliła.

**Konsekwencja:** Ślepe iteracje. Filip pyta "czemu w Slacku zły toast?" — ja nie wiem czy Layer 0.5 (LLM rules) źle matchnęło, czy Layer 4 (universal) źle zgadło, czy Layer 1 (hardcoded) zostało shadowed. Bez tej informacji każda iteracja prompta to strzelanie w ciemno.

**Fix:** nowy enum `RecognitionLayer` z casami L0/L0.5/L1/L2/L3/L4/menu/menu-fallback. Pole `layer: RecognitionLayer` w `ShortcutEvent`. Każdy `emit(...)` w ClickWatcher i checkMenuBar tag'uje layer. `EventLogger.log` zapisuje `"layer": "L0.5"` do JSONL.

**Severity:** ŚREDNIA-WYSOKA. Bez tego nie da się prowadzić data-driven iteracji prompta i fixów reguł.

---

### P-25: AXIdentifierAttribute nie jest w schemacie reguł ani w skeletonie

**Pliki:**
- `SFlow/AXSkeletonExtractor.swift:122-135` — `walk()` czyta tylko
  `kAXRoleAttribute` + `kAXTitleAttribute` + `kAXDescriptionAttribute`
- `SFlow/LoadedRule.swift:16-19` — `LoadedMatch: {role: String,
  titles: [String]}` — brak pola `identifiers: [String]?`
- `SFlow/RuleCache.swift:73-95` — `match()` nie sprawdza identifiera
- `SFlow/ClickWatcher.swift:204-218` — `elementQuery()` czyta
  `kAXIdentifierAttribute` ale TYLKO jako fallback query dla L3
  (MenuBarIndex), nie dla L0.5

**Co jest:** DOM id jest czytany w ClickWatcher ale użyty tylko do
generowania query stringa dla fuzzy menu match. Nie ma ścieżki która
pozwoliłaby regule targetować element przez stable identifier zamiast
title.

**Co powinno być (w 3 krokach):**
```
1. AXSkeletonExtractor.walk() — dodaj kAXIdentifierAttribute do SkeletonItem
   (jako opcjonalne pole "identifier")
2. LoadedMatch — dodaj `identifiers: [String]?`
3. RuleCache.match() — sprawdź identifiers PRZED titles (bardziej stable)
4. Backend types.ts — dodaj `identifiers` do RuleSchema (opcjonalne)
5. Backend prompt.ts — powiedz Claude żeby generował identifiers gdy dostępne
```

**Przykład działania po fix:**
- Element: `role=AXButton, title="Wycisz", identifier="mute-button"`
- Reguła: `{role: AXButton, titles: ["Mute", "Toggle Mute"], identifiers: ["mute-button"]}`
- Match przez `identifier "mute-button"` — działa nawet po polsku ✅

**Severity:** ŚREDNIA. Czysta implementacja (~half day), ale wymaga zmian
w 3 warstwach (skeleton extractor + LoadedRule schema + RuleCache + backend).

---

### P-32: Web research w backend prompt jest niesterowany

**Plik:** `backend/src/prompt.ts`, `backend/src/claude.ts`

**Co jest:** Claude w backendzie ma dostęp do `web_search` tool (max 4 uses
per call). Sam decyduje kiedy go użyć i jakie zapytania wpisać. Działa dla
popularnych apek (Slack — wyszukuje cheatsheet i znajduje ⌘K), ale **nie ma
gwarancji** że zrobi to dla niche apek ani że pokryje konkretne elementy.

**Brakuje:**
1. **Ukierunkowanie per-app:** prompt nie mówi "najpierw wyszukaj
   `{appName} keyboard shortcuts cheatsheet` i `{appName} hotkey list`"
2. **Ukierunkowanie per-element:** gdy widzimy w skeletonie nieznany przycisk
   "Toggle Sidebar" bez menu bar entry — moglibyśmy wymusić dedicated search
   `{appName} {elementName} shortcut`
3. **Więcej uses:** dziś max 4. Dla nowej apki gdzie Claude nic nie wie z
   pretrenowania, 6-8 dałoby mu szansę.

**Severity:** ŚREDNIA-WYSOKA. Bezpośrednio wpływa na hit rate dla apek
których Claude nie ma "w głowie" (indie apki, regional apki).

**Wpływ Faza 1:** Łączymy z reseedem bundled.json (sesja 9) — update prompt
+ reseed 5 apek + porównanie liczby reguł / coverage przed-po.

---

### P-33: Quality eval nie skaluje powyżej manualnego (Filip + 5 osób)

**Plik:** Brak — nie istnieje.

**Co nie istnieje:** Dziś jakość reguł sprawdzamy ręcznie — Filip otwiera apkę,
klika 10 elementów, notuje hit% / false+. To zajmuje 30-60 min per apka.
Beta z 3-5 osobami doda real-world signal, ale 5 osób fizycznie nie obkliknie
100 apek.

**Konsekwencja:** Auto-discovery zadziała dla setek apek, ale **nie wiemy które
działają dobrze a które źle**. Wisemy między "zaufaj Claude'owi" (ryzyko
halucynacji u userów) a "pozwól tylko zweryfikowanym apkom" (zaprzecza
auto-discovery flow).

**Rozwiązanie — synthetic Claude self-eval per regule:**

Po wygenerowaniu reguł przez `claude.ts`, drugi call (~$0.001/regule):

```
PROMPT: "Oto reguła którą wygenerowałeś dla apki {appName}:
  { titles: ['Duplicate'], keys: ['meta','d'], source: '...' }

Oto element ze skeletonu UI:
  { role: AXButton, title: 'Duplicate Frame' }

Pytanie 1: Czy ta reguła pasuje do tego elementu?
Pytanie 2: Czy istnieje INNY powszechniej znany skrót Figma dla
'Duplicate' który byłby lepszy?
Zwróć JSON: { score: 1-5, reason: '...', alternative: '...' | null }"
```

Reguły z `score < 3` → flag `experimental: true` w response. Klient wie że
ma je traktować ostrożniej (np. nie pokazywać w pierwszym tygodniu onboarding).

**Koszt:** ~$0.001 × 30 reguł × 100 apek = ~$3 łącznie (jednorazowo per apka,
cache'owane razem z regułami).

**Wpływ:**
- Łapie halucynacje Claude'a przed dotarciem do usera
- Skaluje na nieograniczoną liczbę apek bez Filipa
- Daje signal "this rule is uncertain" do UI / quality gate
- Komplementarny z P-4 (crowdsourced false-positives — to działa tylko gdy
  mamy userów)

**Severity:** ŚREDNIA-WYSOKA. Krytyczne dla launch'a z 100+ supported apks.

**Wpływ Faza 1:** Sesja 10. Implementacja: 2nd Claude call w `claude.ts`,
nowe pole `score` + `experimental` w schemacie reguł. Wymaga adjust client-side
quality gate (P-1) żeby honorowała `experimental` flag.

---

### P-34: Claude max_tokens truncation dla wielkich apek

**Plik:** `backend/src/claude.ts`

**Symptom:**
```
LLM error: Claude returned non-JSON: 'Now I have all the information needed.
Let me compile the full JSON rule list, using the menu bar as the primary
(high-confidence) source for every shortcut that appeared there, and web-verified or we'
```

Android Studio discovery zwróciła HTTP 502 z backendu. Claude API skończyło output mid-sentence — wyjście zostało obcięte zanim Claude ukończył listę JSON. Backend próbował sparsować, dostał prozę naturalną, zwrócił 502.

**Przyczyna:** Z 500 menu items + 500 skeleton items + wyniki web_search w kontekście, Claude przekroczył limit 8192 `max_tokens` na output ZANIM skończył generować listę reguł. Android Studio ma 575 items menu pre-cap — po obcięciu do 500 nadal produkuje ogromny payload.

**Severity:** ŚREDNIA. Dotyczy wielkich apek (Android Studio, JetBrains stack, Xcode, złożone IDE-podobne Electron apki).

**Fix:** Backend — zwiększyć `max_tokens` z 8192 do 16000+ w `backend/src/claude.ts`. Może wymagać przejścia na wariant modelu z dłuższym budżetem wyjściowym. Alternatywnie: streaming / JSON mode jeśli dostępne. Łączy się z Sub-celem 1.12 (Sesja 9, bundle C).

**Status update (Sesja 9a, 2026-05-15):** Zamknięte.

Fix był dwuczęściowy:
1. `max_tokens: 8192 → 32768` w `backend/src/claude.ts` (commit `16f180d`)
2. Switch `client.messages.create()` → `client.messages.stream() + finalMessage()` — Anthropic SDK wymaga streamingu dla max_tokens > 8192 z safety check'iem "operations that may take longer than 10 minutes". Bez streamingu SDK natychmiast odrzuca call błędem 502.

Manual eval (2026-05-15 12:42): Android Studio przeszło z Failed → Learned z **93 regułami** po ~90 sekundach streamingu.

Backend deployed: version `6f489e00-3c59-4f2b-a458-b4692e38f14c` na production.

---

### P-35: Backend timeout (>90s) dla niektórych apek

**Plik:** `backend/src/handlers/discover.ts`, `SFlow/DiscoveryClient.swift`

**Symptom:**
```
NSURLErrorDomain Code=-1001 "The request timed out."
URL: https://sflow-rules.shortcutflow.workers.dev/v1/discover
```

DisplayTuner (`com.benderbureau.displaytuner`) — skeleton 149, menuBar 136 — żądanie do `/v1/discover` przekroczyło timeout 90s po stronie klienta. Nie jest to ogromny payload — ale backend potrzebował >90s na odpowiedź.

**Możliwe przyczyny:**
- Claude API rate limiting (żądanie czeka w kolejce)
- Wolne `web_search` tool dla tej domeny apki
- Cloudflare Worker CPU time zbliżający się do limitu (max 30s CPU, ale może spędzać więcej na async I/O)

**Severity:** ŚREDNIA. Dotyczy nieprzewidywalnego podzbioru apek w zależności od obciążenia Claude API + latency web_search.

**Fix — diagnostyka:** backend `/v1/discover` powinien logować `durationMs` (Sub-cel z wcześniejszych sesji). Sprawdzić p95/p99 — jeśli wiele wywołań >60s, problem jest realny. Mitigacje:
- Zwiększyć client timeout z 90s do 120s
- Cache wyników `web_search` osobno żeby retry były szybsze
- Lub split Claude call: najpierw reguły tylko z menu-bar (szybko), potem wzbogacenie przez web_search asynchronicznie

Łączy się z Sub-celem 1.12 (Sesja 9, bundle C) — ta sama sesja iteracji promptu.

**Status update (Sesja 9a, 2026-05-15):** Częściowo rozwiązane.

Najprawdopodobniej P-34 fix (streaming switch) naprawia również P-35 — niektóre calle Anthropic odrzucał wcześniej z tym samym streaming-required errorem (a klient widział to jako timeout 90s bo backend zwracał 502 dopiero po próbie reasoningu). Wymaga weryfikacji: kliknij Try again na `com.benderbureau.displaytuner` w SFlow Apps tab po deployu sesji 9a. Jeśli zadziała — flip do 🟢.

---

### P-22: Subtelność: Layer 0.5 cache uderza PRZED hardcoded L1

**Plik:** `ClickWatcher.swift:111-122` (L0.5) vs `124-134` (L1)

**Co jest:** RuleCache (JSON) sprawdza się przed `ShortcutRules.match`
(hardcoded). Jeśli LLM dla Slacka wygeneruje regułę o niskiej jakości
ale matchującą — wygra nad sprawdzoną hardcoded.

**Konsekwencja:** Bundled.json może shadowsować dobrze przemyślaną L1.
Dziś nie jest to problem (bundled.json dla 4 apek = przemyślane Claude
output po manual review), ale jeśli kiedyś Claude zhalucynuje coś co trafi
do bundled.json, hardcoded L1 nie jest backup'em.

**Severity:** NISKA-ŚREDNIA. Zależy od strategii. Niektóre teamy uznałyby
to za **feature** ("LLM nadpisuje legacy") — kwestia decyzji architekturalnej.

---

## Architektoniczne mocne strony

1. **Czyste separacje** — ClickWatcher = detection, RuleCache = storage,
   DiscoveryService = network. Każdy ma jedną odpowiedzialność.
2. **Async write w EventLogger** — nie blokuje hot path (CGEventTap callback).
3. **6-warstwowy fallback** — graceful degradation. Najgorszy przypadek to
   "no toast", nie "crash".
4. **Force AX enhancement dla Electron** — kluczowy hack, działa.
5. **Multi-monitor coord handling** — poprawione w `9a9855d` commicie.
6. **Privacy filter w skeleton extraction** — strict, dobrze przemyślane
   (emails, dates, names, hash prefixes).
7. **Dedup po stronie backendu** — zapobiega konfliktom które byłyby
   trudne do debugowania client-side.
8. **Web search w Claude API** — pozwala generować shortcuty bez polegania
   tylko na menu bar (Slack ⌘K).
9. **TTL 90 dni na cache** — rozsądne dla 99% apek.
10. **CGEventTap w listenOnly mode** — nie modyfikujemy zdarzeń, mniejszy
    blast radius bezpieczeństwa.
11. **Backend dedup zapobiega lottery toasts** (v1.1.1) — gdy Claude
    wygeneruje 2 reguły o pokrywających się tytułach (jak realny bug Slack
    "Search Slack" ⌘F vs ⌘G), `dedupOverlappingRules` w `claude.ts` wybiera
    `menu_bar`-sourced lub wyższe confidence i drop'uje konflikt zanim
    leci do klienta. Eliminuje całą klasę wrong-toast bugów.
12. **Hotkey-suffix tolerance w RuleCache** (v1.1.1) — `stripHotkeySuffix()`
    pozwala starym regułom (bez wariantów typu "Edit message E") matchować
    Electron menu items bez re-seedu. Klient sam się leczy z dryftu między
    AX a regułami z poprzedniego promptu.

---

## Architektoniczne słabości (sumarycznie)

1. **Brak quality controls dla auto-discovered rules** (P-1, P-12, P-22)
2. **Brak retry/recovery dla nieudanej discovery** (P-2, P-3)
3. **Brak feedback loop dla błędów** (P-4)
4. **Znane bugi w fuzzy matching** (P-5)
5. **Brak observability** (P-21)
6. **Brak mechanizmu update dla bundled.json** (P-19)
7. **Onboarding UX gap (permissions, status)** (P-15, P-17, P-20)
8. **Brak `/v1/refresh`** (P-8)
9. **Window element matching jest pasywne** (P-24, P-6, P-25) — menu bar
   dostaje skróty aktywnie z `kAXMenuItemCmdChar`, window elements polegają
   na przewidywaniu tytułów przez LLM. Fundamentalna asymetria quality.

---

## Known unknowns (nie da się odpowiedzieć z kodu)

1. **Ile rules per app Claude faktycznie generuje?** Częściowa odpowiedź
   po v1.1.1 reseedzie:
   - Slack: 58 reguł, średnio 4.41 wariantów tytułów per regule (range 3–5)
   - Obsidian: 44 reguły, średnio 4.05 wariantów per regule (range 3–5)
   - Stare reguły (v1.0 prompt): avg 1.05–2.13 wariantów per regule.
   Pełna mediana/ogon dla 20 apek nadal wymaga uruchomienia.
2. **Hit rate w real life dla 4 zweryfikowanych?** Manual eval w `v1.1`
   roadmapie był celem, ale wyników nigdzie nie ma spisanych.
3. **False positive rate dziś?** Bug P-5 implikuje że jest niezerowy, ale
   nie wiemy ile. Beta z 3-5 osobami to ujawni.
4. **AXKeyShortcutsValue adoption?** — ile apek to ustawia? Wymaga manualnej
   probe.
5. **`localizedName` w przypadku polskiej apki?** — Slack jest "Slack",
   ale np. Pages może być "Pages" lub "Strony" w PL macOS.
6. **Co robi backend gdy menu bar jest pusty i skeleton jest pusty?** —
   Claude prawdopodobnie zwróci empty rules, ale to nie jest assertowane.
7. **Jak szybko skaluje się czas `/v1/discover`?** — dla małej apki ~5s,
   dla dużej Notion z 500 items skeleton i web_search × 4 — może 60s+.
   Klient ma timeout 90s.
8. **Czy `attempted` Set resetuje się prawidłowo przy app restart?** — kod
   sugeruje że tak (in-memory), ale persistence cache `cache/<bundle>.json`
   może zachowywać "puste" entries z nieudanych prób.

---

## Wnioski

### Co należy uznać za "ukończone" w Fazie 0

- Mechanika detekcji kliknięć (L0.5–L4)
- Auto-trigger przy aktywacji apki
- Backend LLM rules engine z cache i rate limit
- Bundled rules dla 4 apek z manualnym eval
- Miss log + analyzer CLI
- Reseed pipeline dla developerów
- ~16% test coverage na codebase (wnioskuję z LOC: 1865/(3079+460) ≈ 53% LOC w testach co jest dobre, ale niewystarczające bez E2E)

### Co MUSI być naprawione w Fazie 1 (priorytety)

**Bramki krytyczne (bez tego nie ma jak iść dalej):**
1. **P-1** Quality gate dla auto-discovered rules
2. **P-2** Retry + backoff dla nieudanej discovery
3. **P-5** Bug w MenuBarIndex.lookup (substring direction) — 🟢 DONE
4. **P-4** False-positive feedback od usera (cmd-klik)
5. **P-19** Bundled.json update path po SFlow update

**Bramki ważne (powinniśmy mieć przed launch'em):**
6. **P-3** UI feedback dla `.failed` (retry button)
7. **P-8** `/v1/refresh` z miss log
8. **P-15** Permissions check dla Input Monitoring — 🟢 DONE
9. **P-20** Rate limit reform (per anonymous user ID, nie IP)
10. **P-21** Backend observability (basic metrics) — 🔵 częściowo
11. **P-6** AXKeyShortcutsValue Layer 0 (~2h, awansowane z opcjonalnych)
    — główny quick win dla window element coverage, część rozwiązania P-24
12. **P-24** Window element passive matching — P-6 to Etap 1, P-25 to Etap 2

**Bramki opcjonalne (warto sprawdzić, możliwie pominąć):**
13. **P-25** AXIdentifierAttribute w schemacie reguł (~half day)
14. **P-7** Debounce na app activation
15. **P-13** Lazy MenuBarWatcher (tylko aktywna apka)

**Nice-to-have (Faza 2+):**
14. **P-9, P-10, P-11, P-12, P-14, P-16, P-17, P-18, P-22**

### Decyzje strategiczne do podjęcia (przed pisaniem specu Fazy 1)

1. **Quality gate threshold** — `high only`, `high + menu_bar medium`, czy
   coś bardziej elastycznego?
2. **Retry strategy** — exponential backoff persistowany do dysku? Manual
   retry button only? Hybrid?
3. **False-positive UX** — cmd-klik czy hover-button na toaście?
4. **Backend metrics** — Cloudflare Analytics czy Logflare/Sentry?
5. **`/v1/refresh` activation threshold** — ile missów wystarczy? (sugeruję
   20 missów na apkę z ≥3 powtarzającymi się tytułami).
6. **Bundled.json update** — full overwrite czy merge z user_overrides
   protection?

Te decyzje są przedmiotem audytu Fazy 1.

---

*Status: kompletny inwentarz Fazy 0. Następny krok: audyt Fazy 1
(`docs/audit-phase-1.md`).*
