# Plan — Sesja U-7: Tool/mode switching (Sub-cel 1.23 / P-46)

> **Status:** DRAFT, ~5h. G-8 z analizy uniwersalności.
>
> **Adresuje:** Sub-cel 1.23, P-46. **Pre-requisite dla U-9 (Adobe eval)** —
> bez U-7 toolbox Adobe pozostaje czarną skrzynką.
>
> **Wartość:** otwiera klasę creative apek (Figma, Photoshop, Illustrator,
> Sketch, Premiere). Power-userzy w tych apkach to silny target market
> ($50+/mc willingness-to-pay).

---

## 1. Problem

Creative apki używają **toolbar po lewej/górze** z narzędziami pod literami:

| Apka | Toolbar tools |
|---|---|
| Figma | V (Move), R (Rectangle), T (Text), P (Pen), L (Line), F (Frame), C (Comment), H (Hand), K (Scale) |
| Photoshop | V (Move), B (Brush), E (Eraser), M (Marquee), L (Lasso), P (Pen), T (Type), Z (Zoom), H (Hand), I (Eyedropper) |
| Illustrator | V (Selection), A (Direct), P (Pen), T (Type), R (Rotate), S (Scale), W (Blend), B (Brush), N (Pencil) |
| Sketch | V (Vector), R (Rectangle), O (Oval), T (Text), L (Line), A (Artboard) |
| Premiere | V (Selection), C (Razor), A (Track Select), B (Ripple), Y (Slip), P (Pen), H (Hand), Z (Zoom) |

**Dziś:** klik w ikonkę narzędzia → SFlow widzi `AXButton` z `desc="Brush"`
lub similar → próbuje L0.5 (cache) → brak reguły dla creative apek →
miss.

**Mechanizm potrzebny:** rozpoznawanie **toolbar context** + **single-key
shortcuts** w tym kontekście.

---

## 2. Mechanizm

### 2.1. Detekcja toolbar context

W `ClickWatcher.handleMouseDown`, walking up ancestors po klikniętym
elemencie:

```swift
private func isInToolbar(_ element: AXUIElement) -> Bool {
    var current = element
    for _ in 0..<5 {
        var roleRef: AnyObject?
        AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""
        if role == "AXToolbar" { return true }
        var parentRef: AnyObject?
        guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString,
                                            &parentRef) == .success,
              let parent = parentRef else { break }
        current = parent as! AXUIElement
    }
    return false
}
```

### 2.2. Toolbar-aware L0.5 lookup

Jeśli `isInToolbar(clickedElement)`:
- Pobierz `desc` lub `title` (nazwa narzędzia)
- Lookup w `RuleCache` z **specjalnym scope** `"toolbar"` (extension Sub-cel
  1.22 schema)

W bundled.json dla creative apek:

```json
{
  "bundleId": "com.figma.Desktop",
  "features": { "singleKeyMode": true },
  "rules": [
    {
      "match": { "role": "AXButton", "titles": ["move", "select"] },
      "keys": ["v"], "hint": "Move tool",
      "scope": ["toolbar"],
      "confidence": "high", "source": "web_docs_official"
    },
    {
      "match": { "role": "AXButton", "titles": ["rectangle", "frame"] },
      "keys": ["r"], "hint": "Rectangle tool",
      "scope": ["toolbar"],
      "confidence": "high", "source": "web_docs_official"
    },
    // ... 9-15 toolbar rules per apka
  ]
}
```

### 2.3. Backup: TooltipObserver dla toolbar

Creative apki często mają **tooltipy na hover** ikonek toolbox z literą
po prawej ("Move • V"). To **już** łapie Sesja B (L0.3 TooltipObserver) —
po U-7 toolbar-context-aware rules są fallback gdy tooltip nie zostanie
zaobserwowany w okienku 60s.

### 2.4. Synergy z U-3 (single-key mode)

Single-key mode (`features.singleKeyMode: true`) jest **wymagany** dla
creative apek bo skróty toolbar są single-letter. U-3 musi być **wcześniej**.

---

## 3. TDD kroki

### 3.1. ClickWatcher detection test

`SFlowTests/ToolbarContextTests.swift`:

```swift
func test_isInToolbar_returnsTrueForButtonInsideToolbar() {
    // Mock: AXButton → parent AXGroup → parent AXToolbar
    // Asercja: true
}

func test_isInToolbar_returnsFalseForButtonInWindow() {
    // Mock: AXButton → parent AXGroup → parent AXWindow
    // Asercja: false
}

func test_isInToolbar_walksAtMost5Ancestors() {
    // Mock: AXButton z głęboko zagnieżdżonym AXToolbar (depth=6)
    // Asercja: false (giveup po 5)
}
```

### 3.2. RuleCache scope match

W `RuleCacheTests.swift` (już rozbudowane przez U-6):
- Toolbar context + rule `scope=["toolbar"]` → matches
- Main window context + rule `scope=["toolbar"]` → NO match (preserves
  scope semantyki)

### 3.3. Bundled rules dla Figma (~30 LOC)

`bundled/com.figma.Desktop.json` — top 10 tools z [help.figma.com/hc/en-us/articles/360039827874](https://help.figma.com).

### 3.4. Manual eval

Otwórz Figma → klik każdą ikonkę z toolboxa → oczekuj toast z poprawną literą.

---

## 4. Acceptance criteria

- [ ] `isInToolbar()` helper + 3 testy
- [ ] `bundled/com.figma.Desktop.json` z 10+ toolbar rules
- [ ] `bundled/com.adobe.Photoshop.json` z 10+ toolbar rules (jeśli istnieje
      bundle, inaczej cache)
- [ ] Manual test Figma: klik V/R/T/P → toasty
- [ ] Manual test Photoshop: klik B/V/M → toasty
- [ ] 300+ testów passing

---

## 5. Plik manifest

**Nowe:**
- `SFlowTests/ToolbarContextTests.swift`
- `bundled/com.figma.Desktop.json` (lub update istniejącego)
- `bundled/com.adobe.Photoshop.json`
- `bundled/com.adobe.illustrator.json`

**Zmienione:**
- `SFlow/ClickWatcher.swift` — `isInToolbar()` helper, pass jako scope
  context do `RuleCache.match`
- `SFlow/RuleCache.swift` — uznaje `"toolbar"` jako valid scope value (po
  U-6 framework już istnieje)

---

## 6. Statusy

- `audit-phase-0.md`: P-46 ⬜ → 🟢
- `audit-phase-1.5.md`: Sub-cel 1.23 → 🟢, **odblokowuje** Sub-cel 1.25
  (Adobe eval)

---

*Plan napisany 2026-05-16 offline. Robić **po** U-3 (single-key mode)
i U-6 (scope schema).*
