# Plan — Sesja U-3: Single-key shortcut mode (Sub-cel 1.21 / P-44)

> **Status:** DRAFT, ~2h, najtańszy fix w Fazie 1.5.
>
> **Adresuje:** Sub-cel 1.21 (audit-phase-1.5.md), P-44 (audit-phase-0.md).
> Wynika z analizy uniwersalności (G-4) w `universality-gaps-and-windows-2026-05-16.md`.
>
> **Pre-requisite:** U-1 (B.1 integracja) zacommitowane. U-2 nie blokuje
> — można robić równolegle.

---

## 1. Problem

Niektóre apki używają **single-key navigation**:
- **Gmail:** `j`/`k` (next/prev message), `c` (compose), `e` (archive), `r` (reply)
- **Notion Mail:** `c`/`r`/`f` (compose/reply/forward) — działa dziś tylko dzięki L0.3 tooltipom
- **Obsidian Vim mode:** `h`/`j`/`k`/`l` (left/down/up/right)
- **Notion slash-menu:** literki w submenu otwartym po `/`
- **Linear:** `c` (new issue), `e` (edit)

**Dziś:** Layer 2 (`kAXHelp` + `parseShortcut`) w `ClickWatcher.swift:372` wymaga
`currentHelp.count > 1 || isInteractive` żeby zaakceptować single char.

To była **ochrona** przed false-positives — bez niej pojedyncze literki w
tekstach (np. "F" w "FAQ" jako kAXHelp) generowały toasty.

**Konsekwencja:** w apkach **gdzie single-key skróty są standardem**, Layer 2
odrzuca legalne skróty.

---

## 2. Rozwiązanie — per-app feature flag

### 2.1. Schema bundled.json/cache.json

Rozszerzyć schema o pole top-level (poziom apki, nie reguły):

```json
{
  "bundleId": "notion.mail.id",
  "rulesVersion": "...",
  "features": {
    "singleKeyMode": true
  },
  "rules": [...]
}
```

### 2.2. Whitelist apek (start)

Te apki dostają `singleKeyMode: true` w bundled.json (po reseedzie):

| Bundle ID | Dlaczego |
|---|---|
| `notion.mail.id` | C/R/F navigation (potwierdzone w Sesji B) |
| `com.cron.electron` | 1/D, 0/W, M w dropdown (potwierdzone P-38) |
| `md.obsidian` | Vim mode (jeśli włączone) |
| `notion.id` | slash-menu literki |
| `com.linear.LinearMac` | C/E/Z navigation |
| `com.figma.Desktop` | V/R/T/P narzędzia (gdy U-7 tool/mode) |

Dla **web apek** (Gmail, Slack web, Linear web) — czeka na U-4 (web-as-app
pseudo-bundleId).

### 2.3. ClickWatcher logika

W `RuleCache` dodać metodę `isSingleKeyApp(bundleId:) -> Bool` zwracającą
flagę z loaded ruleset.

W `ClickWatcher.swift:372` (Layer 2 check), zmienić:

```swift
if !currentHelp.isEmpty {
    // Przed: if (currentHelp.count > 1 || isInteractive), ...
    let allowSingleChar = isInteractive || ruleCache.isSingleKeyApp(bundleId: bundleId)
    if (currentHelp.count > 1 || allowSingleChar),
       let keys = ShortcutRules.parseShortcut(from: currentHelp) {
        ...
    }
}
```

### 2.4. Bonus — TooltipObserver może też używać flagi

TooltipObserver dziś akceptuje badge 1-key (np. "C", "R"). Whitelist dla
apek single-key by **podniosła confidence** tych entries (mogą być dłużej
trzymane w `DiscoveredStore` bo wiemy że apka faktycznie tak działa).

Opcjonalne — pominąć w U-3, dorobić jeśli okaże się potrzebne.

---

## 3. Test-driven kroki

### 3.1. RuleCache extension

**Nowy test w `SFlowTests/RuleCacheTests.swift`:**

```swift
func test_isSingleKeyApp_returnsTrueForFlaggedBundle() {
    let cache = RuleCache(...)
    cache.loadRules(for: "notion.mail.id", from: jsonWithFeaturesSingleKeyTrue)
    XCTAssertTrue(cache.isSingleKeyApp(bundleId: "notion.mail.id"))
}

func test_isSingleKeyApp_returnsFalseByDefault() {
    let cache = RuleCache(...)
    cache.loadRules(for: "com.test.app", from: jsonWithoutFeatures)
    XCTAssertFalse(cache.isSingleKeyApp(bundleId: "com.test.app"))
}
```

### 3.2. LoadedRule schema extension

W `SFlow/LoadedRule.swift` dodać opcjonalne `features`:

```swift
struct LoadedRuleSet: Codable {
    let bundleId: String?
    let rulesVersion: String?
    let features: Features?
    let rules: [LoadedRule]

    struct Features: Codable {
        let singleKeyMode: Bool?
    }
}
```

Codable z opcjonalnymi polami zachowuje **backward-compat** — istniejące
bundled.json bez `features` parsują się jako `features = nil`.

### 3.3. ClickWatcher integration test

**Nowy test w `SFlowTests/ClickWatcherLayerGateTests.swift`:**

```swift
func test_layer2_acceptsSingleCharHelp_whenSingleKeyAppFlagSet() {
    // Mock RuleCache zwraca isSingleKeyApp(bundleId: "test.app") == true
    // Mock element z role="AXStaticText" (non-interactive), help="c"
    // Oczekiwane: Layer 2 fires emit z keys=["c"]
}

func test_layer2_rejectsSingleCharHelp_whenFlagNotSet() {
    // Same setup, ale isSingleKeyApp == false
    // Oczekiwane: emit nie fires
}
```

### 3.4. Bundled.json edits

Dla każdej z apek w whitelist (§2.2) — edytuj `bundled/{bundleId}.json`
dodając `features.singleKeyMode: true`. **Reseed nie potrzebny** — to
manualna edycja.

---

## 4. Acceptance criteria

- [ ] Schema `LoadedRuleSet.features.singleKeyMode` opcjonalna, backward-compat
- [ ] 4+ nowe testy (RuleCacheTests + ClickWatcherLayerGateTests)
- [ ] 6 bundled apek ma `features.singleKeyMode: true`
- [ ] Manual test: w Notion Mail kliknij ikonkę bez hover → toast pokazuje
      single-key (jeśli kAXHelp ma single char)
- [ ] Manual test (negative): w Slack kliknij dowolne miejsce → nadal NIE
      strzela toastami z single chars (Slack nie ma flagi)
- [ ] Wszystkie 285+ testów dalej passing
- [ ] Zero regresji w events.jsonl po 1 dniu użycia

---

## 5. Plik manifest

**Nowe pliki:** brak

**Zmienione pliki:**
- `SFlow/LoadedRule.swift` — `Features` struct + decode
- `SFlow/RuleCache.swift` — `isSingleKeyApp(bundleId:)` method
- `SFlow/ClickWatcher.swift` — Layer 2 gate uses `allowSingleChar`
- `SFlowTests/RuleCacheTests.swift` — 2 nowe testy
- `SFlowTests/ClickWatcherLayerGateTests.swift` — 2 nowe testy
- `bundled/notion.mail.id.json` — +features
- `bundled/com.cron.electron.json` — +features
- `bundled/md.obsidian.json` — +features
- `bundled/notion.id.json` — +features
- `bundled/com.linear.LinearMac.json` — +features
- `bundled/com.figma.Desktop.json` — +features (jeśli istnieje)

---

## 6. Statusy po sesji

- `audit-phase-0.md`: P-44 ⬜ → 🟢
- `audit-phase-1.5.md`: Sub-cel 1.21 ⬜ → 🟢, sesja U-3 w execution sequence ⬜ → 🟢
- `roadmap.md`: nowy wpis w Session log

---

## 7. Ryzyka

### Ryzyko 1: False positives w mainstream apkach

**Diagnoza:** włączyć flagę dla **wszystkich** apek = lawina toastów z
single chars w przypadkowych elementach.

**Mitigacja:** **strict whitelist** — flaga TYLKO w bundled.json, nigdy
domyślnie. Auto-discovered cache nie ustawia tej flagi (Claude prompt
nie generuje `features`).

### Ryzyko 2: Notion Mail "shortcut" false-positive wraca

**Diagnoza:** U-1 (B.1) naprawia false-positive "shortcut" przez
`TooltipNameFilter`. U-3 dotyczy Layer 2 (kAXHelp), nie L0.3 (tooltip) —
**inny pipeline**, nie wpływa.

**Mitigacja:** żadna nie potrzebna.

### Ryzyko 3: Apka ma single-key mode tylko gdy włączone w ustawieniach

Gmail wymaga "Keyboard shortcuts ON" w settings. Obsidian Vim mode jest
opt-in. Nie potrafimy z poziomu SFlow sprawdzić czy user to włączył.

**Mitigacja:** akceptuj false-positives w tym przypadku jako acceptable —
user wyłączył flagę "Show experimental shortcuts" w SFlow Settings może
disable. Albo: kolejna iteracja per-feature opt-in.

---

*Plan napisany przez AI 2026-05-16 (offline, bez kompa). Czeka na execution.*
