# WIP: Web Shortcut Support (Toasty dla stron www)

**Status:** Zresetowane. Architektura działała, matching nie.  
**Snapshot przed próbą:** commit `f66bbc4`

---

## Cel

Pokazywać toasty ze skrótami klawiszowymi gdy user klika przyciski na stronach www  
(np. Gmail: klik Compose → toast `C  Compose`).

Bez rozszerzenia do przeglądarki — tylko macOS AX API.

---

## Co zbudowaliśmy

### `BrowserURLReader` — działa ✅
Nowy plik. Zamiast szukać paska adresu w toolbarze (nie działa — Comet nie eksponuje  
`AXURLTextField`), podchodzimy od klikniętego elementu i idziemy w górę drzewa AX  
szukając `AXWebArea`. Ten element ma `kAXURLAttribute` z pełnym URL strony.  
Działa w każdej przeglądarce bez wyjątku.

```swift
// Pomysł który NIE działał:
// findURLField szuka AXURLTextField w toolbarze — Comet ma tylko puste AXGroup

// Pomysł który DZIAŁA:
func currentDomain(clickedElement: AXUIElement) -> String {
    // idź po parentach w górę aż znajdziesz AXWebArea
    // odczytaj kAXURLAttribute → URL → host
}
```

### `ShortcutRules.webRules` + `matchWeb()` — architektura OK ✅
Nowy słownik keyed domeną (np. `"mail.google.com"`), ta sama logika matchowania co  
istniejące reguły. Layer 0 w `ClickWatcher` sprawdzany przed per-app rules (żeby  
Gmail nie dostawał ⌘N zamiast C dla Compose).

---

## Dlaczego nie działało

### Problem 1: `desc` vs `title` w Chrome AX

Istniejące reguły dopasowują na `kAXDescriptionAttribute` (`desc:`).  
W **natywnych macOS appkach** accessible name trafia do `AXDescription`.  
W **web content przez Chrome/Comet** accessible name (z `aria-label`) trafia do `AXTitle`.

Logi pokazały:
```
role='AXButton' desc='' title='utwórz' help='' id=''
```

Wszystkie Gmail rules mają `desc: "compose"` — nigdy nie matchują bo `desc` jest puste.  
**Fix:** zmienić Gmail webRules na `title:` zamiast `desc:`.

### Problem 2: Lokalizacja

Gmail w języku polskim pokazuje:
- Compose → `"utwórz"`
- Archive → prawdopodobnie `"archiwizuj"`  
- Reply → `"odpowiedz"`

Hardkodowanie po angielsku (`title: "compose"`) nie zadziała dla polskich userów.

---

## Co NIE zostało przetestowane

### `AXKeyShortcutsValue` — obiecujące następne podejście

Chrome eksponuje HTML atrybut `aria-keyshortcuts` jako AX atrybut `AXKeyShortcutsValue`.  
Jeśli Gmail ustawia `aria-keyshortcuts="c"` na przycisku Compose — możemy odczytać skrót  
**bezpośrednio**, niezależnie od języka interfejsu.

Przerwaliśmy sesję zanim zrobiliśmy pełny dump atrybutów (`AXUIElementCopyAttributeNames`),  
który by to potwierdził.

---

## Plan na następną sesję

1. **Sprawdzić `AXKeyShortcutsValue`** — uruchomić all-attrs dump na przycisku Compose  
   i zobaczyć czy `AXKeyShortcutsValue` jest dostępne i zawiera `"c"`.

2. **Jeśli tak** → Layer 2 (`kAXHelp` auto-parse) można rozszerzyć lub dodać osobny  
   Layer dla `AXKeyShortcutsValue`. Byłoby to language-independent i automatyczne  
   dla DOWOLNEJ strony która używa `aria-keyshortcuts`. Zero hardkodowania.

3. **Jeśli nie** → Zmienić Gmail rules na `title:` + dodać reguły per-język  
   (angielski, polski, niemiecki, francuski jako minimum).

4. W każdym przypadku — zachować `BrowserURLReader` z podejściem przez `AXWebArea`  
   (to działa i jest eleganckie).

---

## Gotowe fragmenty do reużycia

```swift
// BrowserURLReader.currentDomain(clickedElement:) — gotowe, działa
// ShortcutRules.matchWeb() — gotowe, do ponownego użycia
// Layer 0 w ClickWatcher — gotowe, właściwe miejsce
```

Pliki były: `SFlow/BrowserURLReader.swift`, zmiany w `ShortcutRules.swift`  
i `ClickWatcher.swift`. Wszystko zresetowane do `f66bbc4`.
