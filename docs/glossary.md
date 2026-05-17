# SFlow Glossary

> **Cel:** definicje terminów technicznych dla onboardingu nowych
> contributors / AI sessions. Każdy term — 1-2 zdania definicji + gdzie
> zobaczyć w kodzie.

---

## AX terminologia (macOS Accessibility)

| Term | Definicja | Gdzie |
|---|---|---|
| **AX (Accessibility API)** | macOS API do programatycznego czytania UI elementów (drzewo widget'ów apki). | `import ApplicationServices` |
| **AXUIElement** | Pojedynczy element w drzewie AX (przycisk, tekst, okno). | wszędzie w `ClickWatcher.swift` |
| **AXRole** | Typ elementu: `AXButton`, `AXTextField`, `AXMenuItem`, `AXWindow`, `AXGroup`, etc. | `kAXRoleAttribute` |
| **AXTitle / AXDescription** | Czytelne nazwy elementu. Title = main label, Description = alternative (often the only one Chromium exposes). | `kAXTitleAttribute`, `kAXDescriptionAttribute` |
| **AXValue** | Wartość elementu — dla AXTextField to wpisany tekst, dla AXStaticText to widoczny tekst, dla AXButton to często stan (0/1). | `kAXValueAttribute` |
| **AXIdentifier** | Programatic identifier (`data-testid` w React, accessibility identifier w Cocoa). Stabilne, języko-agnostyczne. | `kAXIdentifierAttribute` |
| **AXMenuItemCmdChar / CmdModifiers** | Natywne atrybuty menu item z literą skrótu + bitmask modyfikatorów (0x8=cmd, 0x1=shift). | `MenuBarIndex.parseModifiers` |
| **AXKeyShortcutsValue** | Atrybut z ARIA shortcut hintem (np. `Meta+K`). Działa w Chromium gdy aria-keyshortcuts ustawione. | Layer 0 w `ClickWatcher` |
| **AXManualAccessibility / AXEnhancedUserInterface** | Flagi forcing Chromium/Electron żeby eksponował drzewo AX. Bez nich Slack/Notion zwracają puste atrybuty. | `ClickWatcher.handleMouseDown` line 244 |
| **AXFocusedWindow** | Aktualnie aktywne okno w apce. Używane do scope detection (main vs sheet vs dialog). | Sub-cel 1.22 |
| **AXWebArea** | Specjalny element w Chromium browser eksponujący web page content. Może mieć AXURL. | Sub-cel 1.19 (web-as-app) |
| **AXPress action** | Akcja "this element responds to click" — alternatywa do role check. | `ClickWatcher.elementHasAXPress` |

## SFlow architecture

| Term | Definicja | Gdzie |
|---|---|---|
| **ClickWatcher** | Główny komponent — CGEventTap na mouseDown, pipeline L0..L4. | `ClickWatcher.swift` |
| **CGEventTap** | macOS API do globalnego monitorowania eventów myszy/klawiatury. | `ClickWatcher.setup` |
| **Layer 0 (L0)** | AXKeyShortcutsValue check — Electron aria-keyshortcuts. Najsilniejsza warstwa. Empirycznie martwa (0% hit). | line 309 |
| **Layer 0.3 (L0.3)** | TooltipObserver — React-portal tooltips zaobserwowane na hoverze, lookup po position. | line 226 |
| **Layer 0.5 (L0.5)** | RuleCache.match — JSON rules (bundled + cache). 32% wszystkich toastów. | line 339 |
| **Layer 1 (L1)** | ShortcutRules.match — hardcoded Swift dictionary 10 apek. 28% toastów. | line 357 |
| **Layer 2 (L2)** | kAXHelp + parseShortcut — extract shortcut z help text. Empirycznie martwa (0%). | line 370 |
| **Layer 3 (L3)** | MenuBarIndex.lookup — fuzzy match w menu bar bieżącej apki. 21% toastów. | line 384 |
| **Layer 4 (L4)** | Universal heuristics — semantic rules (search → ⌘F, back → ⌘←). 2% toastów. | line 396 |
| **menu-fallback** | Second pass — sysWide hit-test gdy app-level walk nic nie znalazł. 9% toastów. | line 415 |
| **RuleCache** | Loaded JSON rules z `bundled/` (manual) + `cache/` (Claude AI). | `RuleCache.swift` |
| **ShortcutRules** | Hardcoded per-app rules w Swift dictionary. | `ShortcutRules.swift` |
| **MenuBarIndex** | Index of menu bar items per app, fuzzy lookup by title. | `MenuBarIndex.swift` |
| **MenuBarWatcher** | Aktualizuje MenuBarIndex gdy app się zmienia. | `ClickWatcher` member |
| **DiscoveredStore** | Persistent store of tooltip-observed entries. `~/Library/.../discovered/{bundleId}.jsonl`. | `DiscoveredStore.swift` |
| **TooltipObserver** | Pollujue cursor, skanuje AX tree dla floating AXGroup tooltipów. | `TooltipObserver.swift` |
| **EventLogger** | Zapisuje toast / miss / false-positive eventy do `events.jsonl`. | `EventLogger.swift` |
| **MissEvent** | Struct dla unmatched klik (interactive element bez rule). | `EventLogger.swift` |
| **PrivacyFilter** | Pure helper — `containsPII()` + `redact()` przed write/upload. | `PrivacyFilter.swift` (B.1) |
| **TooltipNameFilter** | Pure helper — banned-list + whitelist dla tooltip action names. | `TooltipNameFilter.swift` (B.1) |
| **AXSkeletonExtractor** | Buduje uproszczony skeleton drzewa AX dla wysłania do backendu. | `AXSkeletonExtractor.swift` |
| **DiscoveryService** | Auto-trigger discovery przy aktywacji nowej apki. | `DiscoveryService.swift` |
| **DiscoveryAttemptStore** | Persistent backoff state dla retry'ów. | `DiscoveryAttemptStore.swift` |

## Konfiguracja / data files

| File | Co zawiera |
|---|---|
| `bundled/{bundleId}.json` | Manualnie zweryfikowane reguły (5 apek baseline) |
| `cache/{bundleId}.json` | Claude AI auto-generated rules (90d TTL) |
| `~/Library/Application Support/SFlow/events.jsonl` | Wszystkie toast/miss/false-positive eventy |
| `~/Library/Application Support/SFlow/false_positives.jsonl` | Tylko false-positive zgłoszenia |
| `~/Library/Application Support/SFlow/discovered/{bundleId}.jsonl` | TooltipObserver entries |
| `~/Library/Application Support/SFlow/attempted.json` | Discovery attempt history + backoff state |
| `~/Library/Application Support/SFlow/user.json` | Anonymous UUID (Faza 2.1) |

## Phasing / fazy

| Faza | Co | Status |
|---|---|---|
| 0 | Detektor mocy — pipeline L0..L4, auto-discovery | 🟢 done |
| 1 | Jakość pokrycia w skali — 20 apek, beta z 5 osobami | 🟡 in-progress |
| **1.5** | **Universal Coverage — G-1..G-8 + eval 5 typów apek** | ⬜ pending |
| 2 | Infrastruktura nauki — keystroke monitoring, telemetry | ⬜ |
| 3 | Droga A — intro toast + onboarding | ⬜ |
| 4 | Droga B 1.0 — personalizowane lekcje | ⬜ |
| 5 | Droga E — raporty + dashboard | ⬜ |
| 6 | Pricing + launch | ⬜ |
| 7 | B2B / Team | ⬜ |

## Drogi (z product-vision)

| Droga | Pomysł | Status w roadmap |
|---|---|---|
| A | Intro toast + onboarding | Faza 3 |
| B | Personalized learning (curriculum + lessons) | Faza 4 — **core produktu** |
| C | Daily Drill (mini-Duolingo) | odrzucone — fragments funkcji w B |
| D | Force-Learning blocker | odłożone na Fazę 5+ |
| E | Heatmap / retrospective raport | Faza 5 — uzupełnienie B |
| F | B2B / Team curriculum | Faza 7 |

## Problemy (P-X notation)

P-1..P-48 to numerowane problemy w `audit-phase-0.md`. **Mapping**:
- P-1..P-22 — z initial audyta (2026-05-13)
- P-23..P-30 — Sesja 6 matching engine quality
- P-31..P-35 — Coverage iteration + backend issues
- P-36, P-37 — Sesja A (Chromium AX) + Sesja B (TooltipObserver)
- P-38 — Dropdown menu items (Sub-cel 1.17 / Sesja C.5)
- **P-39, P-40** — B.1 dziś (TooltipObserver scrubbing + MissEvent PII)
- **P-41..P-48** — Faza 1.5 (universal coverage gaps)

## Sub-cele (X.Y notation)

Sub-cele w `audit-phase-1.md` (1.0..1.17) i `audit-phase-1.5.md` (1.18..1.29).

## Sesje (numbery + litery)

Konwencja:
- **1, 2, 3...** — Sesje wczesnej Fazy 1 (chronologicznie)
- **A, B, C, D** — Sesje tematyczne Fazy 1 (Sesja A = Chromium AX, B = TooltipObserver, C = backend discovered)
- **9a, 9b** — Sub-sesje (rozbicie jednej)
- **C.5** — Sesja "między" C i D
- **U-1..U-10** — Sesje Fazy 1.5 (Universal Coverage)

## ROI scoring (z phase-1.5)

ROI = (C × P × W) / K, gdzie:
- **K** = koszt w godzinach (1-10)
- **C** = coverage — ile apek dotyka (1-10)
- **P** = pewność działania (1-10)
- **W** = wartość dla usera (1-10)

Wysoki ROI = lepiej. Top: U-1 ROI=1440, U-2 ROI=270.

## Confidence values

W schema reguł `confidence: "high" | "medium" | "low"`:
- **high** — source `menu_bar` lub `web_docs_official`
- **medium** — source `web_docs_third_party` (cheatsheet/forum)
- **low** — source `inferred_pattern` (Claude zgaduje z similar apps)

Quality gate w RuleCache: jeśli `!showExperimental && confidence == .low` → skip.

## RecognitionLayer enum

```swift
enum RecognitionLayer: String {
    case axKeyShortcuts = "L0"
    case tooltipObserver = "L0.3"
    case ruleCache = "L0.5"
    case shortcutRules = "L1"
    case axHelp = "L2"
    case menuBarIndex = "L3"
    case universal = "L4"
    case menuItem = "menu"
    case menuItemFallback = "menu-fallback"
}
```

---

*Glossary napisany 2026-05-17 offline. Update gdy pojawia się nowy term.*
