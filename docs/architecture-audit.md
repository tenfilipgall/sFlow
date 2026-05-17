# SFlow — Architecture Audit (2026-05-17)

> **Cel:** strukturalny przegląd obecnej architektury + identyfikacja
> areas do refaktoryzacji **przed** Fazą 2 (infrastruktura nauki).
>
> **Pre-requisite:** rozumienie warstw L0..L4 (patrz `glossary.md`).

---

## 1. Architektura — quick ASCII map

```
                    +-------------------+
                    |  AppDelegate      | ← lifecycle, status bar, settings window
                    +---------+---------+
                              |
                              v
          +-------------------+--------------------+
          |                                        |
+---------v---------+                  +-----------v-----------+
| ClickWatcher      |                  | DiscoveryService      |
| (mouseDown tap)   |                  | (auto-discover apps)  |
+----+--------------+                  +-----+-----------------+
     |                                       |
     v                                       v
+----+--------+   +----------+   +-----------+---------+
| RuleCache   |   | Menu...  |   | DiscoveryClient     |
| L0.5 rules  |   | L3 index |   | (HTTP /v1/discover) |
+-------------+   +----------+   +---------+-----------+
                                           |
                                  HTTPS    v
                       +-------------------+-------------------+
                       |  Cloudflare Worker (backend)         |
                       |   - /v1/discover                     |
                       |   - prompt.ts (Claude API)           |
                       |   - dedup.ts, storage.ts (KV cache)  |
                       +--------------------------------------+
```

Plus side-channels:
- `TooltipObserver` (L0.3) → `DiscoveredStore` → konsumowane przez `ClickWatcher`
- `MenuBarWatcher` → `MenuBarIndex` → konsumowane przez L3 lookup
- `EventLogger` → events.jsonl (toast/miss/false-positive)
- `Analyzer` (CLI) → reads events.jsonl, produces reports

---

## 2. Modules — sizes + complexity

| Module | LOC | Cohesion | Concerns |
|---|---|---|---|
| `ClickWatcher.swift` | 567 | ⚠️ MEDIUM | Too many responsibilities — event tap, AX walk, 7 layers, miss logging |
| `ShortcutRules.swift` | 716+ (WIP) | 🟢 OK | Pure data + match function |
| `RuleCache.swift` | ~125 | 🟢 OK | Pure load + match |
| `TooltipObserver.swift` | ~390 (WIP) | ⚠️ MEDIUM | Polling + AX walk + parser + sensitive text filter — może warto split |
| `MenuBarIndex.swift` | 164 | 🟢 OK | Single responsibility |
| `AppDelegate.swift` | 153 | 🟢 OK | Standard AppKit lifecycle |
| `SettingsWindow.swift` | (?) | (?) | SwiftUI — sprawdzić depth |
| `EventLogger.swift` | 133 (post B.1) | 🟢 OK | Pure write functions |
| `DiscoveryService.swift` | 94 | 🟢 OK | Single responsibility |

**Top concerns:**
1. **`ClickWatcher` zbyt duży** — 567 LOC. 7 warstw + miss logging + event tap setup + AX walk + helpers. Refactor: wyciągnąć "Layer matchers" jako separate strategy classes.
2. **`TooltipObserver` ma 3 concerns** — polling, scanning, parsing. Po B.1 dodatkowo banned-name filter. Refactor: wyodrębnić `TooltipScanner` (pure AX walk) + `TooltipPoller` (cursor stability check).

---

## 3. Dependency graph — wąskie gardła

```
        ┌────────────────────────────────────┐
        │ ClickWatcher                        │
        │ ↓ used by AppDelegate               │
        └─┬──────────┬──────────┬─────────────┘
          │          │          │
    uses ↓     uses ↓     uses ↓
  RuleCache  ShortcutRules  MenuBarIndex
    │           │              │
    │           │              ↓
    │           │            MenuBarWatcher
    │           ↓
    │       (pure data)
    ↓
  LoadedRule (+ MatchConfidence, RuleSource enums)
```

**Wniosek:** Architektura jest **drzewiasta** — łatwa do mockowania w testach.
Brak cyclic dependencies (verified by reading imports).

**Bottleneck:** Wszystko przechodzi przez `ClickWatcher`. To może być
problem perform'owy gdy w Fazie 2 dodamy `KeyDownWatcher` + `MissAggregator`
+ scheduler — wszystko może chcieć `frontmostApplication.bundleId`,
`AX axApp` instance, etc. → cache te w `AppSession` singleton.

---

## 4. Test coverage assessment

| Module | Test file | LOC tests | Coverage |
|---|---|---|---|
| ClickWatcher | `ClickWatcherLayerGateTests`, `ClickWatcherParseTests` | ~200 | ⚠️ medium — głównie pure helpery, mało integration |
| RuleCache | `RuleCacheTests` | ~150 | 🟢 good |
| ShortcutRules | `ShortcutRulesTests` | ~120 | 🟢 good |
| MenuBarIndex | `MenuBarIndexTests` | ~100 | 🟢 good |
| EventLogger | `EventLoggerTests` (+ post-B.1) | ~200 | 🟢 good |
| TextMatching | `TextMatchingTests` | ~80 | 🟢 good |
| TooltipShortcutParser | `TooltipShortcutParserTests` | ~80 | 🟢 good |
| DiscoveredStore | `DiscoveredStoreTests` | ~70 | 🟢 good |
| AXSkeletonExtractor | `AXSkeletonFilterTests` | ~100 | 🟢 good (privacy filter heavy test) |

**Gaps:**
- **No E2E tests** — uruchom Slack, klik, sprawdź toast. Cały pipeline od mouseDown → ClickWatcher → render. Trudne automated (AX requires fake app or simulator).
- **No performance tests** — Slack z 5000 AX elementów: ile ms walk-up parent chain?

---

## 5. Refactor candidates (przed Fazą 2)

### R-Arch-1: Extract `LayerMatcher` strategy

**Co:** `ClickWatcher.handleMouseDown` zawiera 7 inline'owanych warstw
(L0/L0.3/L0.5/L1/L2/L3/L4) jako block `if let ... { return }` lawina.
Refactor:

```swift
protocol LayerMatcher {
    func match(context: ClickContext) -> ShortcutEvent?
    var name: RecognitionLayer { get }
}

final class ClickWatcher {
    private let matchers: [LayerMatcher] = [
        AXKeyShortcutsMatcher(),
        TooltipObserverMatcher(store: DiscoveredStore.shared),
        RuleCacheMatcher(cache: ruleCache),
        ShortcutRulesMatcher(),
        AXHelpMatcher(),
        MenuBarIndexMatcher(watcher: menuBarWatcher),
        UniversalRulesMatcher(),
    ]

    func handleMouseDown(...) {
        let context = buildContext(...)
        for matcher in matchers {
            if let event = matcher.match(context: context) {
                emit(event)
                return
            }
        }
        logMiss(context)
    }
}
```

**Plus:** każda warstwa testowalna w izolacji. Łatwiej dodać L0.4 (right-click)
albo L0.6 (web-as-app).

**Minus:** ~3-4h refactor. Wymaga regresji test suite. **Wartość:** wysoka
przed Fazą 2 (dodajemy keyDown matcher).

### R-Arch-2: AppSession singleton

**Co:** `frontmostApplication`, `axApp`, `bundleId`, `webDomain`, `appLocale`
są re-resolved przy każdym kliku. W Fazie 2 dodajemy `KeyDownWatcher` —
też potrzebuje tych samych danych.

```swift
final class AppSession {
    static let shared = AppSession()
    private(set) var current: AppContext? = nil

    func update() {
        // Refresh from NSWorkspace.frontmostApplication
        // Cache axApp, bundleId, webDomain, appLocale
    }
}

struct AppContext {
    let bundleId: String
    let axApp: AXUIElement
    let webDomain: String?  // post-U-4
    let appLocale: String   // post-U-5
}
```

Update on `NSWorkspace.didActivateApplicationNotification`. ClickWatcher
+ KeyDownWatcher czytają z cached singleton.

**Wartość:** średnia. **Czas:** ~2h.

### R-Arch-3: Move PrivacyFilter wider

**Co:** Po B.1, PrivacyFilter jest tylko w EventLogger.logMiss. Ale **też**
powinien być w:
- DiscoveredStore.record (już planowane via TooltipNameFilter)
- DiscoveryClient (skeleton przed POST)
- AnalyzerCLI (cmd line tool nie powinien echo'ować PII)

Refactor: helper functions wszędzie, każdy file-output / network-output
przez PrivacyFilter.redact.

**Wartość:** wysoka pre-beta. **Czas:** ~2h.

---

## 6. Tech debt do uznania

| # | Long-term concern | Severity |
|---|---|---|
| TD-1 | ClickWatcher.swift 567 LOC → trudno utrzymać | MEDIUM |
| TD-2 | ShortcutRules.swift 716+ LOC dictionary → trudno utrzymać | MEDIUM |
| TD-3 | Brak E2E tests | MEDIUM |
| TD-4 | Hardcoded thresholds (300ms tooltip delay, 2s emit dedup, etc.) — jako constants w random miejscach | LOW |
| TD-5 | Brak performance instrumentation (czas AX walk per click) | LOW |
| TD-6 | `Reseeder.swift` 236 LOC dev tool — może wyciągnąć z głównego target'u | LOW |

**Sumarycznie:** moderate tech debt. Nic critical. Pre-Phase-2 cleanup
~10h pracy (R-Arch-1 + R-Arch-2 + R-Arch-3).

---

## 7. Recommendations

**Pre-Faza 2 must-do (~10h refactor):**
1. R-Arch-1 — LayerMatcher strategy (3-4h)
2. R-Arch-3 — PrivacyFilter wider (2h)
3. R-Arch-2 — AppSession singleton (2h)

**Optional cleanup (~5h):**
- Extract constants do `SFlowConfig.swift`
- Performance instrumentation (`Signpost`)
- E2E test framework setup

**NIE robić:**
- Pełnego MVVM refactoru SettingsWindow — działa, nie ma sygnału problemu
- Migracji na Combine — async/await wystarczy gdzie potrzebne

---

*Architecture audit napisany 2026-05-17 offline. Decyzja refactoru po
zamknięciu Fazy 1.5 (~3-4 tygodnie).*
