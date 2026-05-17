# Slack toast nie renderuje — głęboka diagnostyka H1-H5

> **Status:** offline analysis 2026-05-16. Rozszerzenie
> `2026-05-16-slack-toast-not-rendering.md` o **konkretne kroki testowe**
> i **alternatywne renderery** gdy NSPanel zawiedzie.
>
> **Outstanding blocker dla:** drogi A (intro/onboarding) i drogi B (nauka)
> w product-vision sekcja "Outstanding blockers".

---

## Recap (krótki)

Klik 🔖 w Slack na 2. monitorze (fullscreen Space):
- `events.jsonl` → wpis `{type: "toast", layer: "L1", hint: "Save for later"}`
- `ToastWindow.show()` wywołane
- **Wizualnie:** zero. Toast nie pojawia się.

Test Toast z menu bar SFlow (primary monitor) → renderuje OK.

→ **Bug specyficzny dla pozycji 2. monitor + Slack fullscreen Space.**

---

## Hipotezy H1-H5 — kolejność testowania + ROI

### H1: Spaces / fullscreen blokuje NSPanel
**Pewność (P):** 6/10. Najbardziej prawdopodobne (macOS Spaces ma agresywne
window isolation).

**Test (5 min):**
1. Wyciągnij Slack z fullscreen (windowed mode na 2. monitorze)
2. Klik 🔖 → sprawdź renderowanie

**Jeśli renderuje:** H1 confirmed → bug fullscreen-specific. Mitigacja:
- `collectionBehavior` bardziej agresywne (już `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`)
- Może dodać `.transient` lub `.ignoresCycle`
- Próba `NSWindow.Level(rawValue: CGWindowLevelForKey(.maximumWindow))` — najwyższy possible

**Jeśli NADAL nie renderuje:** H1 odrzucone, idź do H2.

### H2: Frame poza visible area mimo clampingu
**P:** 5/10. Możliwe że `NSScreen.screens.first(where: $0.frame.contains(cursor))`
zwraca **inny screen** niż `visibleFrame`.

**Test (15 min):**
1. W `ToastWindow.appear()` (linia 109) na początku dodaj:
   ```swift
   NSLog("ToastWindow: cursor=\(cursor.x),\(cursor.y)")
   NSLog("ToastWindow: hostScreen=\(hostScreen?.frame ?? .zero)")
   NSLog("ToastWindow: visibleFrame=\(hostScreen?.visibleFrame ?? .zero)")
   NSLog("ToastWindow: finalFrame=\(frame)")
   NSLog("ToastWindow: NSScreen.screens=\(NSScreen.screens.map { $0.frame })")
   ```
2. Klik 🔖 → sprawdź Console.app filtr `SFlow`
3. Sprawdź czy frame jest w sensownym rect dla **któregokolwiek** screena

**Jeśli frame poza screens:** H2 confirmed. Fix: hardcode pixel buffer i
fallback do primary screen jeśli żaden contains.

### H3: Level `.popUpMenu` za niski
**P:** 4/10. Mniej prawdopodobne — popUpMenu jest **wysoki**.

**Test (10 min, sekwencyjnie):**
1. Zmień `level = .popUpMenu` na każdy z poniższych po kolei, build, test:
   - `.statusBar` (highest)
   - `NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))`
   - `.modalPanel`
   - Custom: `NSWindow.Level(rawValue: 2147483647)`

**Jeśli któryś działa:** H3 confirmed, użyj go.

### H4: Animacja zawodzi z popUpMenu level
**P:** 3/10. Niska.

**Test (5 min):**
1. W `appear()` pomiń animację — set `alphaValue = 1` od razu, **bez**
   `orderFrontRegardless` w animation context:
   ```swift
   func appear() {
       alphaValue = 1
       orderFrontRegardless()
       // skip the NSAnimationContext block
       ...
   }
   ```

**Jeśli renderuje statycznie:** H4 confirmed → animation needs different
approach for popUpMenu level.

### H5: Slack zabiera focus, ukrywa overlay
**P:** 5/10. Slack znany z agresywnego window management.

**Test (15 min):**
1. W `appear()` po `orderFrontRegardless()` dodaj timer:
   ```swift
   for delay in [0.05, 0.1, 0.2, 0.5, 1.0] {
       DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
           NSLog("ToastWindow: t+\(delay)s isVisible=\(self?.isVisible ?? false), occlusionState=\(self?.occlusionState.rawValue ?? 0)")
       }
   }
   ```
2. Klik 🔖, sprawdź logi
3. Jeśli `isVisible=true` ale `occlusionState` zawiera `.visible=false`
   → focus battle confirmed

**Mitigacja:** re-add NSPanel periodically (Timer co 100ms × 25 calls):
```swift
let raiseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
    self?.orderFrontRegardless()
}
// Stop po 2.5s gdy dismiss
```

To brzydkie ale pragmatyczne.

---

## Sekwencja testów (od najtańszego do najdroższego)

| # | Test | Czas | Pewność potwierdzenia |
|---|---|---|---|
| 1 | H1 — windowed Slack | 5 min | Jednoznaczne |
| 2 | H4 — skip animacji | 5 min | Jednoznaczne |
| 3 | H3 — różne levels | 10 min | Jednoznaczne |
| 4 | H2 — frame logging | 15 min | Wymaga interpretacji |
| 5 | H5 — focus + occlusion logging | 15 min | Wymaga interpretacji |

**Total: ~50 min.** W jednej krótkiej sesji.

---

## Alternatywne renderery (gdy NSPanel **całkowicie** zawiedzie)

Gdyby żadna z H1-H5 nie zadziałała, rozważyć:

### Alt A: NSStatusBar title animation

Najtańsza alternatywa. Zamiast osobnego okna — animuj `NSStatusItem.button.title`
ikony SFlow w menu bar.

**Plus:** zero issues z Spaces / fullscreen / focus.
**Minus:** mniej widoczne, brak pozycji "obok kursora", nie wszyscy widzą menu bar.

```swift
// W AppDelegate, statusItem.button.title = "⌘N • Compose" przez 2s
// Animation: fade-in z monitor mocniejszym font (NSAttributedString)
```

**Implementacja:** ~2h.

### Alt B: Floating CALayer-based overlay

Zamiast NSPanel — `CGSCreateRegionFromRect` + low-level Quartz layer.
**To jest poziom Mission Control / Spotlight overlay** — gwarantowane
renderowanie nad wszystkim.

**Plus:** działa zawsze.
**Minus:** dramatycznie więcej kodu (~10h), trudne debug, undocumented API
(może łamać się w nowszych macOS).

**Implementacja:** ostatnia deska ratunku.

### Alt C: SwiftUI WindowGroup z `.windowLevel(.floating)`

macOS 13+ SwiftUI ma cleaner API dla floating windows. Może być bardziej
reliable niż AppKit NSPanel.

**Plus:** cleaner code, nowoczesny API.
**Minus:** wymaga refaktoru, nie pewno czy obsłuży fullscreen Spaces lepiej.

**Implementacja:** ~4-6h refactor.

---

## Decyzja kolejności

1. **Najpierw 50-min sesja testów H1-H5** — w 80% przypadków znajduje root cause
2. **Jeśli H1-H5 wszystkie odrzucone:** zacząć Alt A (NSStatusBar) jako
   tymczasowy fallback **dla 2. monitor + fullscreen scenariusza**
   - W `ToastWindow.show()` wykryj `isFullscreen2ndMonitor` i fall back
     do `MenuBarStatusItem.flash(toast)` zamiast NSPanel
   - To kompromis: większość userów na primary monitor → NSPanel dalej.
     Tylko fullscreen + 2nd monitor → fallback do menu bar.
3. **Alt B (Quartz layer) tylko jeśli Alt A jest niewystarczające**

---

## Akceptacja

- [ ] Po testach H1-H5 wiemy które z 5 hipotez są confirmed/rejected
- [ ] Decyzja: fix istniejący `ToastWindow` (low-effort) lub fallback
      do Alt A (higher confidence)
- [ ] Reguły `slack-msg-*` które już są w `ShortcutRules.swift` zostają —
      one działają od strony logiki, tylko rendering w bug
- [ ] Outstanding blocker w product-vision oznaczony jako 🟢 (resolved)
      lub 🔵 (partial — fallback działa, root cause nieznany)

---

*Plan napisany 2026-05-16 offline jako pogłębienie istniejącego issue file.
Filip wykonuje testy na kompie 50 min, decyduje strategy.*
