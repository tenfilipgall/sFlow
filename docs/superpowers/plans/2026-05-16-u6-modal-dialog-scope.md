# Plan — Sesja U-6: Modal / sheet / dialog scope (Sub-cel 1.22 / P-45)

> **Status:** DRAFT, ~6h. Średni priorytet — eliminuje false-positives w
> specific case'ach.
>
> **Adresuje:** Sub-cel 1.22 (audit-phase-1.5.md), P-45 (audit-phase-0.md),
> G-7 z `universality-gaps-and-windows-2026-05-16.md`.
>
> **Pre-requisite:** U-1 (B.1). Niezależne od U-2/U-3/U-4/U-5.

---

## 1. Problem

SFlow przyjmuje "skróty są globalne dla apki". To prawda dla większości
przypadków ale **fail** w:

| Sytuacja | Skutek |
|---|---|
| Save dialog otwarty w TextEdit. Kliknięcie "Don't Save" → SFlow widzi AXButton z desc="don't save" → próbuje matchować reguły TextEdit (np. ⌘D = duplicate?). | False match na akcję dialogu z regułami main window. |
| Print sheet w Pages. Kliknięcie "PDF" dropdown → reguły Pages dla main edytora. | False match na "PDF" akcję. |
| Modal w Slack "Set up Slack Connect". Kliknięcie "Skip" → próbuje matchować reguły Slack channel. | Brak sensownego match, ale TooltipObserver może coś złowić. |
| Notion modal "Move page to". Kliknięcie page → reguły Notion main. | Możliwe pomylenie modal action z reguła main. |

**Konsekwencja:** zaszumione toasty w dialogach, gdzie skróty często **nie istnieją** lub są inne.

---

## 2. Rozwiązanie — AXFocusedWindow role check + scope field

### 2.1. Wykrywanie kontekstu kliku

W `ClickWatcher.handleMouseDown`, po `let bundleId`, dodać:

```swift
let windowContext = detectWindowContext(axApp: axApp)
// windowContext jest jednym z:
//   .main              — normalne okno apki
//   .sheet             — modalny sheet (Save/Print/Open dialog)
//   .dialog            — system dialog (alert, confirmation)
//   .floating          — floating panel (Inspector, Color picker)
//   .unknown           — nie udało się ustalić
```

**Implementacja:**

```swift
enum WindowContext: String {
    case main
    case sheet
    case dialog
    case floating
    case unknown
}

func detectWindowContext(axApp: AXUIElement) -> WindowContext {
    var focusedRef: AnyObject?
    AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedRef)
    guard let focused = focusedRef else { return .unknown }
    let window = focused as! AXUIElement

    var roleRef: AnyObject?; var subroleRef: AnyObject?
    AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef)
    AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRef)
    let role = roleRef as? String ?? ""
    let subrole = subroleRef as? String ?? ""

    switch subrole {
    case "AXStandardWindow":        return .main
    case "AXDialog", "AXSystemDialog": return .dialog
    case "AXFloatingWindow", "AXSystemFloatingWindow": return .floating
    default:
        break
    }

    if role == "AXSheet" { return .sheet }
    if role == "AXWindow" { return .main }
    return .unknown
}
```

### 2.2. Schema scope field na rule

W `SFlow/LoadedRule.swift`:

```swift
struct LoadedRule: Codable {
    let match: LoadedMatch
    let keys: [String]
    let hint: String
    let confidence: MatchConfidence
    let source: RuleSource
    let scope: [String]?    // NEW — opcjonalna lista kontekstów; nil = main only
    let version: Int?
}
```

`scope` to lista raw values `WindowContext`. **Default `nil` = `["main"]`** (zachowanie obecne).

Wartości:
- `["main"]` — tylko w main window (default)
- `["sheet"]` — tylko w sheet (np. specjalna reguła dla Save dialog)
- `["main", "sheet"]` — w main i w sheet (np. ⌘. = anuluj w obu)
- `["any"]` — wszędzie (rzadkie, np. universal rules)

### 2.3. RuleCache.match filter by scope

```swift
func match(bundleId: String, windowContext: WindowContext, ...) -> MatchResult? {
    for rule in rules {
        // Scope check
        let scopes = rule.scope ?? ["main"]
        if !scopes.contains("any"),
           !scopes.contains(windowContext.rawValue) {
            continue
        }
        // ... reszta matchingu
    }
}
```

### 2.4. Universal heuristics (L4) — przykład scope

Niektóre uniwersalne reguły **mają sens w sheet/dialog**:
- "Cancel" w sheet/dialog → Escape
- "OK"/"Done" w sheet/dialog → Enter

Te dostają `scope: ["sheet", "dialog"]` zamiast default `["main"]`.

W `SFlow/ShortcutRules.swift universalRules` dodać:

```swift
.init("AXButton", title: "cancel",
      id: "universal-cancel-sheet", keys: ["escape"], hint: "Cancel",
      scope: ["sheet", "dialog"]),
.init("AXButton", title: "ok",
      id: "universal-ok-sheet", keys: ["enter"], hint: "OK",
      scope: ["sheet", "dialog"]),
.init("AXButton", title: "done",
      id: "universal-done-sheet", keys: ["enter"], hint: "Done",
      scope: ["sheet", "dialog"]),
```

To **otwiera nową klasę pokrycia** — Cancel/OK w każdym dialogu, bez per-app
pracy.

---

## 3. Test-driven kroki

### 3.1. WindowContext detection

**Nowy plik:** `SFlowTests/WindowContextDetectionTests.swift` — wymaga
mocków AXUIElement (sprawdzić wzorzec w istniejących `MenuBarIndexTests`):

- AXWindow z subrole=AXStandardWindow → `.main`
- AXWindow z subrole=AXDialog → `.dialog`
- AXSheet role → `.sheet`
- AXFloatingWindow → `.floating`
- Brak focused window → `.unknown`

### 3.2. Rule scope field

W `SFlowTests/LoadedRuleTests.swift`:

- Decode rule bez `scope` → `rule.scope == nil`
- Decode rule z `scope: ["sheet"]` → matches
- Backward-compat: stary JSON bez scope parsuje się OK

### 3.3. RuleCache scope filter

W `SFlowTests/RuleCacheTests.swift`:

- Rule z `scope=nil`, context=`.main` → matches
- Rule z `scope=nil`, context=`.sheet` → **rejected** (default to main)
- Rule z `scope=["sheet"]`, context=`.sheet` → matches
- Rule z `scope=["sheet"]`, context=`.main` → rejected
- Rule z `scope=["any"]`, context=`.dialog` → matches

### 3.4. Universal heuristics — Cancel/OK in sheet

**Nowy test** w `ShortcutRulesTests.swift`:
- Mock click on AXButton title="Cancel" in `.sheet` context → universal rule matches → keys=["escape"]
- Mock same in `.main` context → universal rule NOT matched (sheet-scoped)

---

## 4. Acceptance criteria

- [ ] `WindowContext` enum + 5+ testów detekcji
- [ ] `LoadedRule.scope` opcjonalne, backward-compat
- [ ] `RuleCache.match(windowContext:)` filter
- [ ] 3 universal rules dla sheet/dialog (Cancel, OK, Done)
- [ ] Manual test: w TextEdit otwórz Save dialog → Cancel → toast Escape
- [ ] Manual test: w main window TextEdit → kliknij "Untitled" w tytule
      → reguły main działają normalnie (no regression)
- [ ] Manual test: w Mail kliknij "Reply" w main → toast ⌘R; w Reply
      compose window kliknij "Send" → toast ⌘Enter (jeśli reguła ma
      `scope: ["main", "sheet"]`)
- [ ] 290+ testów passing po dodaniu

---

## 5. Plik manifest

**Nowe pliki:**
- `SFlow/WindowContext.swift` — enum + `detectWindowContext` helper
- `SFlowTests/WindowContextDetectionTests.swift`

**Zmienione pliki:**
- `SFlow/LoadedRule.swift` — `scope: [String]?` field
- `SFlow/RuleCache.swift` — `match(windowContext:...)` signature + filter
- `SFlow/ClickWatcher.swift` — detect context, przekaż do RuleCache
- `SFlow/ShortcutRules.swift` — `universalRules` 3 nowe dla sheet/dialog
- `SFlowTests/LoadedRuleTests.swift` — 3 testy decode
- `SFlowTests/RuleCacheTests.swift` — 5 testów scope filter
- `SFlowTests/ShortcutRulesTests.swift` — 2 testy sheet universals

---

## 6. Backend impact

**Schema update w `backend/src/types.ts`:**

```typescript
const RuleSchema = z.object({
  match: MatchSchema,
  keys: z.array(z.string()),
  hint: z.string(),
  confidence: ConfidenceSchema,
  source: SourceSchema,
  scope: z.array(z.string()).optional(),  // NEW
  version: z.number().int().optional(),
});
```

**Prompt update (`backend/src/prompt.ts`):**

```text
SCOPE (optional, per rule):
- For most rules, omit "scope" — defaults to main window only.
- Add "scope": ["sheet"] for rules specific to save/open/print dialogs.
- Add "scope": ["main", "sheet"] for rules applicable in both contexts (e.g. Escape/Enter for sheet OK/Cancel + main window cancel).
- Use "scope": ["any"] sparingly — only for truly universal cancellation/confirmation shortcuts.
```

Few-shot examples dorzucić: jedna reguła z `scope: ["sheet"]`.

---

## 7. Ryzyka

### Ryzyko 1: AXFocusedWindow nie zwraca informacji

Niektóre Electron apki mają **wszystko jako jedno AXWindow** — modal jest
dziećmi tego window, nie osobnym AXSheet. SFlow widziałby `.main` mimo
że modal jest otwarty.

**Mitigacja:** walk od klikniętego elementu w górę szukając `AXSheet` /
`AXDialog` parent. Jeśli znajdzie → kontekst = sheet/dialog mimo top-level
window=main. Drugi tryb wykrywania kontekstu.

### Ryzyko 2: False scope rejection

Reguła z `scope=["main"]` nie odpali w sheet — ale user **może** kliknąć
modal "Send" w sheet który jest funkcjonalnie equivalent do main "Send".
False rejection.

**Mitigacja:** start z domyślnym `scope=["main", "sheet"]` dla większości
istniejących reguł (Compose, Reply itp.). Tylko nowe reguły dialog-specific
mają `["sheet"]`.

Actually... lepszy default: **`scope=nil` = pass everywhere**, zamiast
"main only". Wtedy zachowujemy backward-compat **bez** ryzyka false rejection.
Strict scoping (`scope=["sheet"]` = TYLKO sheet) jest opt-in dla nowych
reguł.

**Wybieram opcję 2 (nil = any).** Bardziej konserwatywne, brak regresji.

---

## 8. Statusy po sesji

- `audit-phase-0.md`: P-45 ⬜ → 🟢
- `audit-phase-1.5.md`: Sub-cel 1.22 ⬜ → 🟢, sesja U-6 → 🟢
- `roadmap.md`: Session log

---

*Plan napisany przez AI 2026-05-16 (offline). Niski-średni ryzyko, ~6h
pracy. Eliminuje false-positives bez wprowadzania nowych.*
