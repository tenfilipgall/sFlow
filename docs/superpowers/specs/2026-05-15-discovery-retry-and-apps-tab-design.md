# Discovery retry + backoff + Apps tab — design spec

> **Adresuje:** P-2 (retry przy nieudanej discovery), P-3 (.failed silently
> swallowed), w `docs/audit-phase-0.md`. Sub-cel 1.2 w `docs/audit-phase-1.md`.
>
> **Data:** 2026-05-15. **Sesja:** 8.
> **Status:** design approved, plan implementacyjny TBD.

## Cel sesji

SFlow umie:
1. Spróbować ponownie nauczyć się apki która zfailowała przy pierwszej próbie
   (problem case: apka aktywowana w pierwszych 5s po starcie systemu,
   AX tree jeszcze nie załadowane → pierwsza próba zwraca śmieci).
2. Pokazać userowi (beta-testerowi) **gdzie** się to nie udało i **dlaczego**,
   oraz dać mu manual override "Try again".

Bez tego pierwszy user który aktywuje Notion 2s po starcie ma **trwale**
zepsutego Notion w SFlow (90-dniowy cache zatruty pustymi regułami).

## Scope (co wchodzi)

1. **`DiscoveryAttemptStore`** — nowa klasa zarządzająca persistowanym
   stanem prób per bundleId
2. **Modyfikacja `DiscoveryService`** — używa store zamiast in-memory Set,
   robi pre-check, klasyfikuje failure reason, publikuje notification po
   zmianie stanu
3. **Apps tab w Settings** za toggle `showDeveloperFeatures` (beta-only)
4. **`forceRetry(bundleId)`** API — wywoływane z Apps tab gdy user klika
   "Try again"

## Out of scope (NIE w tej sesji)

- Live progress bar w Apps tabie (już jest w menu bar)
- Bulk "Retry all failed" button
- Statystyki "hit rate per app"
- Edycja reguł per apka w UI
- Notification/push toast przy failure (irytujące)
- P-33 synthetic Claude self-eval (osobna sesja 10)
- P-32 ukierunkowany web research (osobna sesja 9)
- Telemetria failure reasons do backendu (osobna sesja, jeśli przyjdzie)

## Architektura

### Komponenty (4 jednostki, każda z jedną odpowiedzialnością)

```
┌──────────────────────────────────────────────────────────┐
│ AppDelegate                                              │
│  • tworzy DiscoveryAttemptStore (load z dysku)           │
│  • wstrzykuje store do DiscoveryService                  │
└─────────────────┬────────────────────────────────────────┘
                  │
                  ▼
┌──────────────────────────────────────────────────────────┐
│ DiscoveryService (modyfikacja)                           │
│  • appActivated → sprawdza store.canAttempt(bundleId)    │
│  • runDiscovery() z pre-check 15s                        │
│  • klasyfikuje failure → DiscoveryFailureReason          │
│  • store.recordSuccess / recordFailure                   │
│  • forceRetry(bundleId) — reset + uruchom pipeline       │
│  • publishuje NotificationCenter event po zmianie stanu  │
└─────────────────┬────────────────────────────────────────┘
                  │
                  ▼
┌──────────────────────────────────────────────────────────┐
│ DiscoveryAttemptStore (NEW)                              │
│  • load() / save() do ~/Library/.../attempted.json       │
│  • canAttempt(bundleId) -> Bool                          │
│  • recordSuccess(bundleId) — usuwa entry                 │
│  • recordFailure(bundleId, reason) — backoff bump        │
│  • forceRetry(bundleId) — reset entry                    │
│  • allFailures() -> [Entry] — dla Apps tab               │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ AppsTab (SwiftUI, NEW)                                   │
│  • lista bundled apek (z bundled.json)                   │
│  • lista learned apek (z cache/*.json)                   │
│  • lista failed apek (z store.allFailures())             │
│  • per-app: status + reason + nextRetryAt + Try again    │
│  • nasłuchuje notification → refresh listy               │
└──────────────────────────────────────────────────────────┘
```

**Granice odpowiedzialności:**

- `DiscoveryAttemptStore` wie **tylko** o "kiedy próbowałem i czy mogę
  znowu". Zero znajomości HTTP/AX/UI.
- `DiscoveryService` wie o discovery flow. Deleguje "czy próbować?" do
  store. Publishuje status events.
- `AppsTab` wie tylko o renderowaniu + reagowaniu na user input. Czyta z
  store + ruleCache, woła `DiscoveryService.forceRetry`.
- `AppDelegate` wire-up.

## Persistencja

### Plik

`~/Library/Application Support/SFlow/attempted.json`

(W tym samym katalogu co `events.jsonl`, `false_positives.jsonl`,
`rules/cache/*.json`.)

### Schema

```json
{
  "version": 1,
  "attempts": {
    "com.notion.notion": {
      "lastAttemptAt": "2026-05-15T14:23:00Z",
      "failureCount": 2,
      "lastReason": "empty_skeleton",
      "nextRetryAt": "2026-05-16T14:23:00Z"
    },
    "com.linear.app": {
      "lastAttemptAt": "2026-05-15T12:00:00Z",
      "failureCount": 1,
      "lastReason": "rate_limited",
      "nextRetryAt": "2026-05-15T13:00:00Z"
    }
  }
}
```

**Invariant:** entry w `attempts` istnieje **wtedy i tylko wtedy gdy** ostatnia
próba zakończyła się failure (`failureCount >= 1`). Success usuwa entry.
Apki nigdy nie próbowane też nie mają entry.

**Pola entry:**
- `lastAttemptAt` (ISO8601, required) — kiedy ostatnia próba zakończyła się
  zapisem failure do store
- `failureCount` (Int, required, ≥1) — ile failures w ciągu
- `lastReason` (String, required) — match `DiscoveryFailureReason.rawValue`
- `nextRetryAt` (ISO8601, required) — kiedy auto-retry może spróbować

**Atomowość zapisu:** zapis `attempted.json` przez temp file + rename
(`fm.moveItem`) żeby uniknąć korupcji przy crashu w trakcie zapisu.

### Migration

Pierwsza wersja schema — `version: 1`. Brak migracji. Jeśli plik nie
istnieje, store startuje z pustym `{}`.

Jeśli plik istnieje ale `version != 1` (kiedyś w przyszłości) — log warn,
zachowaj stary plik jako `.bak`, start z pustym.

## DiscoveryFailureReason enum

```swift
enum DiscoveryFailureReason: String, Codable, CaseIterable {
    case emptySkeleton = "empty_skeleton"
    case emptyMenuBar = "empty_menu_bar"
    case rateLimited = "rate_limited"
    case httpError = "http_error"
    case parseError = "parse_error"
    case noRulesGenerated = "no_rules_generated"

    var displayString: String {
        switch self {
        case .emptySkeleton: return "App not ready yet (empty UI tree)"
        case .emptyMenuBar: return "App has no menu bar"
        case .rateLimited: return "Server: too many requests"
        case .httpError: return "Server error or no internet"
        case .parseError: return "Server returned invalid response"
        case .noRulesGenerated: return "AI returned no rules"
        }
    }
}
```

## Backoff schedule

| failureCount | Następna próba | nextRetryAt = lastAttemptAt + |
|---|---|---|
| 1 | za 1 godzinę | `+1h` |
| 2 | za 24 godziny | `+24h` |
| 3 | za 7 dni | `+7d` |
| 4+ | za 30 dni | `+30d` |

**Cap przy 30 dniach** (zamiast "never") — żeby self-healing miało szansę
gdy backend prompt zostanie poprawiony za miesiąc.

**Reset przy success:** entry usunięty z `attempts`. Następny fail (gdyby
nastąpił) startuje od `failureCount = 1` (1h backoff).

**Reset przy `forceRetry`:** entry usunięty z `attempts`. Pipeline rusza
natychmiast.

## DiscoveryService — nowy flow

### `appActivated(_:)` zmiana

```
guard let app, bundleId else { return }

// Has rules already?
if ruleCache.hasRules(bundleId) { return }

// In-flight? (in-memory Set — ephemeral, ok)
if inFlight.contains(bundleId) { return }

// Backoff window — can we attempt?
if !attemptStore.canAttempt(bundleId) { return }

inFlight.insert(bundleId)
onStatusChange?(.running(appName: appName))
queue.async { self.runDiscovery(app, bundleId, appName, appVersion) }
```

`canAttempt(bundleId)` zwraca:
- `true` jeśli `attempts[bundleId] == nil` (nigdy nie próbowane LUB success
  je usunął)
- `true` jeśli `Date() >= attempts[bundleId].nextRetryAt`
- `false` w przeciwnym wypadku

### `runDiscovery(...)` — wewnątrz queue

```
1. menuBar = MenuBarDumper.dump(app)
   skeleton = AXSkeletonExtractor.extract(app)

2. IF skeleton.count < 3 AND menuBar.isEmpty:
     // Pre-check: app może jeszcze ładować AX tree
     await sleep(15s)
     menuBar = MenuBarDumper.dump(app)
     skeleton = AXSkeletonExtractor.extract(app)

3. IF skeleton.count < 3 AND menuBar.isEmpty:
     attemptStore.recordFailure(bundleId, reason: .emptySkeleton)
     onStatusChange?(.failed(appName, "App UI not ready"))
     publishStateChanged()
     inFlight.remove(bundleId)
     return

4. IF menuBar.isEmpty AND skeleton.count >= 3:
     // Skeleton ma elementy, ale menu bar jest pusty — to OK dla niektórych
     // apek (Electron z hidden menu). Nie blokujemy.
     // (NIE rejestrujemy reason .emptyMenuBar tu — to nie failure, to OK case.)
     // (Reason .emptyMenuBar jest dla przypadku gdy backend potem zwróci
     // problem bo menu jest puste — rzadkie, low priority.)

5. TRY:
     result = await client.discover(bundleId, appName, appVersion, menuBar, skeleton)
   CATCH DiscoveryClientError.rateLimited:
     attemptStore.recordFailure(bundleId, reason: .rateLimited)
     onStatusChange?(.failed(appName, .rateLimited.displayString))
     publishStateChanged()
     inFlight.remove(bundleId)
     return
   CATCH DiscoveryClientError.httpError, .networkError, .timeout:
     attemptStore.recordFailure(bundleId, reason: .httpError)
     [same pattern]
   CATCH DiscoveryClientError.parseError:
     attemptStore.recordFailure(bundleId, reason: .parseError)
     [same pattern]

6. IF result.rules.isEmpty:
     attemptStore.recordFailure(bundleId, reason: .noRulesGenerated)
     onStatusChange?(.failed(...))
     publishStateChanged()
     inFlight.remove(bundleId)
     return

7. // Success path
   writeToCache(bundleId, appVersion, result)
   ruleCache.load()
   attemptStore.recordSuccess(bundleId)
   onStatusChange?(.completed(appName))
   publishStateChanged()
   inFlight.remove(bundleId)
```

**`publishStateChanged()`** posts `NotificationCenter` event
`.sflowDiscoveryStateChanged` — AppsTab nasłuchuje i odświeża listę.

### `forceRetry(bundleId)` — new API

```
func forceRetry(bundleId: String) {
    attemptStore.forceRetry(bundleId)  // reset failureCount, nextRetryAt

    // Find running NSRunningApplication for bundleId
    guard let app = NSRunningApplication.runningApplications(
        withBundleIdentifier: bundleId).first else {
        // App not running — notify caller
        onStatusChange?(.failed(
            appName: bundleId,
            message: "Launch the app first, then try again"
        ))
        return
    }

    // Trigger pipeline manually (skip in-flight check — user wants this)
    if inFlight.contains(bundleId) { return }  // already running, no-op
    inFlight.insert(bundleId)

    let appName = app.localizedName ?? bundleId
    let appVersion = readAppVersion(app) ?? "unknown"
    onStatusChange?(.running(appName: appName))

    queue.async { [weak self] in
        self?.runDiscovery(app: app, bundleId: bundleId,
                          appName: appName, appVersion: appVersion)
    }
}
```

### DiscoveryClient — error classification

**Sprawdzam w `DiscoveryClient.swift` co dziś jest** (jest 88 LOC). Jeśli
dziś rzuca tylko generic error, dorzucam mapping:

```swift
enum DiscoveryClientError: Error {
    case rateLimited       // HTTP 429
    case httpError(Int)    // HTTP 4xx/5xx (poza 429)
    case networkError      // URLError no connectivity / timeout
    case parseError        // JSON decode failed
}
```

`DiscoveryClient.discover(...)` mapuje `URLResponse.statusCode`:
- `200` → parse + return
- `429` → throw `.rateLimited`
- `4xx`/`5xx` → throw `.httpError(code)`
- `URLError` → throw `.networkError`
- `DecodingError` → throw `.parseError`

`DiscoveryService` `catch` te konkretne case'y zamiast `catch { ... }`.

## UI — Apps tab

### Lokalizacja

Settings → tab "Apps" (4-ty tab obok General/Privacy/Advanced).

**Visibility gating:** tab pojawia się tylko gdy
`UserDefaults.standard.bool(forKey: "showDeveloperFeatures") == true`.

Toggle do włączania feature lives in Advanced tab:
```
Toggle("Show developer features (Apps tab with diagnostics)",
       isOn: $showDeveloperFeatures)
```

Default OFF dla zwykłych userów. Filip i beta-testerzy ręcznie włączają.

### Lista

3 sekcje (mogą być rozdzielone Section headers SwiftUI):

**Bundled apps:**
```
🟢 Slack             bundled        58 rules
🟢 Notion            bundled        44 rules
🟢 Obsidian          bundled        44 rules
🟢 Terminal          bundled        12 rules
🟢 Claude Desktop    bundled        18 rules
```
Źródło: `RuleCache.bundled.rules` zgrupowane po bundleId.

**Learned apps:**
```
🟢 Cursor            learned        23 rules
🟢 Figma             learned        31 rules
```
Źródło: `cache/*.json` files (parsed `StoredRuleSet`).

**Failed apps:**
```
❌ Notion Calendar   App not ready yet (empty UI tree)
   last attempt: 14:23 today (1 fail)
   next auto-retry: 15:23 today
   [Try again]
❌ Linear            Server: too many requests
   last attempt: 12:00 today (2 fails)
   next auto-retry: tomorrow 12:00
   [Try again]
```
Źródło: `attemptStore.allFailures()`.

**Footer:**
```
[Refresh list]      [Open rules folder]
```

### Stan reaktywny

`AppsTab` ma `@StateObject AppsTabViewModel: ObservableObject` z polami:
- `@Published bundled: [AppEntry]`
- `@Published learned: [AppEntry]`
- `@Published failed: [FailedAppEntry]`

`init`:
- subscribes to `NotificationCenter.default.publisher(for:
  .sflowDiscoveryStateChanged)`
- calls `refresh()` on each event
- calls `refresh()` initially

`refresh()`:
- Reads RuleCache.bundled rules → groups by bundleId
- Reads cache/*.json files
- Reads `attemptStore.allFailures()`
- Updates `@Published` arrays

`tryAgain(bundleId:)`:
- Calls `AppDelegate.shared.discoveryService.forceRetry(bundleId)`
- (No manual refresh — notification will fire after pipeline completes)

### Why ObservableObject

`@StateObject` over `@State [AppEntry]` because we need NotificationCenter
subscription to live with the view. `ObservableObject` is the standard
SwiftUI pattern for that.

## Wire-up w AppDelegate

```swift
// w startWatcher() po RuleCache load
let attemptStore = DiscoveryAttemptStore(
    fileURL: RuleStorage.userRulesDirectory()
        .deletingLastPathComponent()
        .appendingPathComponent("attempted.json")
)
self.attemptStore = attemptStore  // store as instance var dla AppsTab access

discoveryService = DiscoveryService(
    client: client,
    ruleCache: ruleCache,
    rulesDir: RuleStorage.userRulesDirectory(),
    attemptStore: attemptStore  // NEW PARAM
)
```

`AppsTab` access przez:
```swift
AppDelegate.shared.attemptStore
AppDelegate.shared.discoveryService
```

(Add `static var shared: AppDelegate?` w `AppDelegate`, set in
`applicationDidFinishLaunching`.)

## Notification name

```swift
extension Notification.Name {
    static let sflowDiscoveryStateChanged =
        Notification.Name("com.sflow.discoveryStateChanged")
}
```

(W `SettingsWindow.swift` już istnieje `.sflowForceReSeed` extension —
dorzucamy obok.)

## Testowanie

### `DiscoveryAttemptStoreTests` (8 testów, ~120 LOC)

1. `recordFailure(.emptySkeleton)` → entry z `failureCount=1`,
   `nextRetryAt ≈ now+1h` (tolerance ±5s)
2. Drugi `recordFailure` → `failureCount=2`, `nextRetryAt ≈ now+24h`
3. Trzeci `recordFailure` → `failureCount=3`, `nextRetryAt ≈ now+7d`
4. Czwarty `recordFailure` → `failureCount=4`, `nextRetryAt ≈ now+30d`,
   piąty również 30d (cap)
5. `recordSuccess(bundleId)` po dwóch failures → entry usunięty (allFailures
   nie zawiera bundleId)
6. `canAttempt` returns `false` for fresh failure (now < nextRetryAt) and
   `true` after time travel (mock clock)
7. `canAttempt` returns `true` for bundleId not in store
8. Round-trip: zapisz failures dla 2 bundleIds, init nowy store z tego
   samego pliku → te same dane

**Mock clock:** Store przyjmuje `clock: () -> Date` parametrem (default
`Date.init`). Tests podają deterministic clock.

### `DiscoveryServiceTests` — 4 nowe testy (~80 LOC do istniejących)

1. **Pre-check waits 15s** when first extract returns skeleton<3 + empty
   menu. Mock skeleton/menu generator to return empty on first call, full
   on second. Assert that after 15s wait, second extract is called and POST
   succeeds.
2. **Pre-check fails twice** → `recordFailure(.emptySkeleton)` called,
   status `.failed` emitted.
3. **Backend returns rules=[]** → `recordFailure(.noRulesGenerated)` called.
4. **`forceRetry(bundleId)` with running app** → store reset, pipeline runs.
   **`forceRetry(bundleId)` without running app** → status `.failed` emitted
   with "launch first" message, no pipeline.

### Co NIE testujemy

- `AppsTab` SwiftUI rendering — manual eval only (no snapshot framework)
- `Toggle showDeveloperFeatures` — trivialny SwiftUI `@AppStorage`

### Manual eval checklist (po implementacji)

- [ ] Open Settings → Advanced → toggle Show developer features ON
- [ ] Apps tab pojawia się — zawiera 5 bundled apek
- [ ] Aktywuj nową apkę (np. Cron jeśli zainstalowany) → po success widać
      ją w "Learned apps"
- [ ] Force fail: ubij backend lokalnie, aktywuj nową apkę → widać w
      "Failed apps" z reason "http_error"
- [ ] Kliknij Try again z otwartą apką → status .running, po chwili success
- [ ] Kliknij Try again z apką nieuruchomioną → status .failed "launch first"
- [ ] Restart SFlow → Apps tab nadal pokazuje failed apki (persistencja)
- [ ] Toggle Show developer features OFF → Apps tab znika

## Pliki — zakres zmian

**Nowe pliki:**
- `SFlow/DiscoveryAttemptStore.swift` (~120 LOC)
- `SFlow/DiscoveryFailureReason.swift` (~25 LOC enum + displayStrings)
- `SFlow/AppsTab.swift` (~180 LOC SwiftUI)
- `SFlowTests/DiscoveryAttemptStoreTests.swift` (~150 LOC)

**Modyfikacje:**
- `SFlow/DiscoveryService.swift` (~80 LOC diff) — store integration,
  pre-check, reason tracking, `forceRetry`, notification publish
- `SFlow/DiscoveryClient.swift` (~40 LOC diff) — `DiscoveryClientError`
  enum + statusCode mapping
- `SFlow/AppDelegate.swift` (~15 LOC) — wire up store, `static var shared`
- `SFlow/SettingsWindow.swift` (~35 LOC) — toggle in Advanced, tab "Apps"
  conditional on `showDeveloperFeatures`
- `SFlowTests/DiscoveryServiceTests.swift` (~80 LOC) — nowe testy
  retry/precheck

**Łącznie:** ~720 LOC kodu + testów. ~3-4h pracy w TDD.

## Decyzje strategiczne (zapis na przyszłość)

| Decyzja | Wartość | Uzasadnienie |
|---|---|---|
| Backoff: 1h/24h/7d/30d | progressive | Audit propozycja. 30d cap zamiast "never" — pozwala self-healing po fixie. |
| Pre-check delay | 15s | Mid-ground: Electron apki (Slack/Notion) potrzebują ~12s. Native instant. Audit oryginalnie 30s — user uznał za długie. |
| Pre-check trigger | skeleton<3 AND menu empty | Oba puste = apka jeszcze nie ready. Tylko menu puste = OK (Electron hidden menu). |
| Failure reasons | 6 enum cases | Pokrywa wszystkie obecne błędy. Dodawanie później = łatwo (`Codable`). |
| Store persistence | atomic write (temp + rename) | Crash w trakcie zapisu nie korumpuje pliku. |
| UI lokalizacja | Settings → Apps tab | User preference — out of menu bar, sąsiad istniejących tabów. |
| UI visibility | beta-only za toggle | User decyzja — nie chcemy zwykłym userom (overkill). |
| Auto-retry trigger | app activation | Już istnieje, naturalny moment. Cron scheduler overkill. |

## Risks

**R-1: forceRetry w trakcie auto-retry causes race**
- Mitigacja: `inFlight.contains(bundleId)` check w `forceRetry` — no-op
  if already running.

**R-2: Plik attempted.json korupcja przy crashu**
- Mitigacja: atomic write (temp + rename). Plus jeśli decode fail → log
  warn + start z pustym (nie crash).

**R-3: ObservableObject w AppsTab nie odświeża się**
- Mitigacja: notification on every state change. Manual "Refresh list"
  button jako safety net.

**R-4: `forceRetry` z apką unable to find AX (nie odpowiada)**
- Mitigacja: timeout 90s na discovery (już istnieje). Po 90s fail z
  reason `.httpError` (network error timeout).

**R-5: User feature flag misuse — zwykły user włącza dev mode**
- Mitigacja: warning text przy toggle "Advanced diagnostics — show only
  if you know what you're doing". Brak dalszych konsekwencji (read-only
  feature, nic nie psuje).

## Acceptance criteria

- [ ] 12 nowych testów (8 + 4) passing
- [ ] Wszystkie istniejące testy passing (198 → 210)
- [ ] Manual eval checklist completed (8 punktów)
- [ ] `attempted.json` persistuje przez restart SFlow
- [ ] Apps tab pokazuje 3 sekcje (bundled / learned / failed) — visible
      tylko za toggle
- [ ] `forceRetry` z apką uruchomioną → success w <90s
- [ ] `forceRetry` bez apki → status .failed z "launch first" message
- [ ] Pre-check 15s observable: pierwsze pobranie skeleton<3 + menu empty
      → wait → second extract → success

## Następna sesja

Po user-approval tego spec'a → invoke `superpowers:writing-plans` →
implementacyjny plan z atomic tasks (TDD format).
