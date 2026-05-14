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
| P-2 Retry przy fail | ⬜ otwarte | — |
| P-3 .failed silently | ⬜ otwarte | — |
| P-4 False-positive feedback | ⬜ otwarte | **Krytyczne** — miss log nie łapie wrong toasts |
| P-5 MenuBarIndex bug | 🟢 zamknięte | Fix + 2 nowe testy + 2 poprawione testy (sesja 2026-05-14) |
| P-6 AXKeyShortcutsValue | ⬜ otwarte | **Awansowane** — kluczowy quick win dla window elements, Electron. Patrz P-24 |
| P-8 Brak /v1/refresh | 🔵 częściowo | `?fresh=1` ✅. Brakuje pełnego refresh z miss data |
| P-19 Bundled.json update path | ⬜ otwarte | Krytyczne dla launch'a |
| P-15 Permissions check Input Monitoring | 🟢 zamknięte | CGPreflightListenEventAccess() + alert (sesja 2026-05-14) |
| P-21 Backend observability | 🔵 częściowo | Structured JSON log w /v1/discover (sesja 2026-05-14). Brakuje: dashboard |
| P-23 Within-rule title dupes | 🟢 zamknięte | Fix w `dedup.ts` + test (sesja 2026-05-14) |
| P-24 Window element matching pasywne | ⬜ otwarte | **Nowe** — główny powód że okna < menu bar. Brakuje AXKeyShortcutsValue + identifier layer |
| P-25 AXIdentifier nie w schemacie reguł | ⬜ otwarte | **Nowe** — blokuje language-agnostic matching dla window elements |

Reszta problemów P-7, P-9..P-22 — patrz pełna lista poniżej.

---

## Executive summary

**Co działa:** SFlow ma w pełni zaimplementowany silnik detekcji kliknięć
z 5-warstwowym matchingiem (L0.5/L1/L2/L3/L4), backend Cloudflare Worker
generujący reguły przez Claude API, automatyczny pipeline discovery przy
aktywacji nowej apki, miss log do analizy luk, oraz CLI do reseed'owania
4 zweryfikowanych apek. ~3000 linii Swift, ~600 linii TypeScript, ~1900 linii
testów.

**Co nie działa / nie istnieje:** Brak quality gate dla auto-discovered
rules, brak retry przy nieudanej discovery, brak mechanizmu false-positive
feedback, brak `/v1/refresh`, jeden znany bug w fuzzy matching (false
positives "Copy link" → ⌘C), brak AXKeyShortcutsValue, brak testów E2E.

**Kluczowa diagnoza:** Mamy **infrastrukturę** klasy produktowej, ale brakuje
**mechanizmów higieny jakości** które są niezbędne gdy zaczynamy działać
dla setek apek (a nie 4 zweryfikowanych ręcznie).

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
