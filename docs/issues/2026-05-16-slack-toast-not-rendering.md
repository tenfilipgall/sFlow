# 2026-05-16 — Toast Slacka nie renderuje się wizualnie (mimo emisji)

**Status:** otwarty, do rozwiązania
**Priorytet:** średni (Slack message-actions, drugi monitor)
**Powiązane:** reguły `slack-msg-*` w `ShortcutRules.swift` (dodane tej sesji)

---

## TL;DR

ClickWatcher poprawnie wykrywa klik, `ShortcutRules` poprawnie dopasowuje
regułę, `EventLogger` wpisuje toast do `events.jsonl`, **ale `ToastWindow`
nie pojawia się wizualnie** dla klików w Slacka renderowanego na drugim
monitorze. Test Toast (z menu bar SFlow) renderuje się poprawnie — czyli
sama infrastruktura `ToastWindow` działa, problem jest specyficzny dla
**pozycjonowania** toastu nad oknem Slacka.

## Symptom

- Klik 🔖 Save for later / 💬 Reply / ⋮ → Mark unread w Slacku
- W `events.jsonl` pojawia się wpis `{"type":"toast","hint":"...","layer":"L1"}`
- Wizualnie żadne okienko nie pojawia się na ekranie
- "Show Test Toast" z menu bar — pojawia się prawidłowo na primary screen

## Co już zostało zrobione w tej sesji

1. **AXManualAccessibility w TooltipObserver** (`TooltipObserver.swift:67-74`) —
   fix dla Electronów które bez tej flagi mają puste AX-tree
2. **Re-enable callback dla CGEventTap** (`ClickWatcher.swift:526-541`) —
   obsługa `tapDisabledByTimeout` żeby tap nie umarł na zawsze po pierwszym
   long-running klik'u
3. **Heartbeat timer dla tap state** (`ClickWatcher.swift:43-57`) — co 2s
   sprawdza `CGEvent.tapIsEnabled` i włącza z powrotem (na przypadek gdy
   macOS wyłączy tap bez wysłania callbacka)
4. **Reguły Slack message-actions** (`ShortcutRules.swift:250-269`) —
   `slack-msg-save/unsave/reply/forward/more/edit/unread/link/copy`, plus
   helper `messageActions(...)` do DRY (gotowy do re-use dla Discord/Linear)
5. **Screen-aware ToastWindow placement** (`ToastWindow.swift:27-50`) —
   clamp do `visibleFrame` ekranu pod kursorem; bump levelu z `.screenSaver`
   do `.popUpMenu`

Po #4 i #5: **`events.jsonl` pokazuje że toasty `slack-msg-forward`,
`slack-msg-more` są emitowane.** Wizualnie ich nie widać.

## Diagnoza obecnego stanu

- Slack jest najprawdopodobniej **w trybie fullscreen na drugim monitorze**
  (osobny macOS Space). `canJoinAllSpaces` + `.fullScreenAuxiliary` ustawione
  w `ToastWindow` powinny pomóc, ale nie pomagają w tym konkretnym układzie
- `mouseY` z klika to ~1432-1440 w globalnym NS-coord — na sekundarnym
  monitorze (powyżej primary)
- Test Toast używa `NSScreen.main.frame.midX/midY` (czyli primary) — działa
- Realne kliki używają surowych event.mouseX/Y — nie działają

## Hipotezy do sprawdzenia

### H1 — Spaces / fullscreen Slack blokuje NSPanel
NSPanel z `.canJoinAllSpaces` w `collectionBehavior` powinien pojawiać się
nad fullscreen apkami, ale **NSPanel w `.popUpMenu` level** może być
przechwytywany przez warstwę Spaces. Test: wyciągnąć Slacka z fullscreen
(window'd mode na drugim monitorze) i powtórzyć. Jeśli wtedy działa → bug
fullscreen-specific.

### H2 — Frame poza visible area mimo clampingu
Możliwe że `NSScreen.screens.first(where: $0.frame.contains(cursor))`
zwraca **inny screen** niż `visibleFrame`. Np. cursor wykraczający tuż za
krawędź monitora przy slack-toolbar przy granicy. Test: dodać `NSLog` w
`ToastWindow.appear()` że loguje wybrany screen, jego visibleFrame i
końcowy frame toastu. Porównać z faktycznym układem monitorów.

### H3 — Level `.popUpMenu` nadal za niski dla Slack fullscreen
Alternatywy do przetestowania:
- `.statusBar` (25) — najwyższy "normalny"
- `.modalPanel` (8)
- `.dock` (20)
- `.mainMenu` (24)
- Custom: `NSWindow.Level(rawValue: CGWindowLevelKey.maximumWindow.rawValue)`

### H4 — `wantsLayer` + alpha animacja zawodzi z popUpMenu level
`appear()` startuje od `alphaValue = 0` i animuje do 1. Możliwe że na
popUpMenu level animacja nie wykonuje się (różny renderer / pomijanie
animacji dla "modal" levels). Test: pominąć animację, ustawić alphaValue
= 1 od razu i zrobić tylko `orderFrontRegardless`.

### H5 — Slack agresywnie odbiera focus i ukrywa overlay'e
NSPanel z `.nonactivatingPanel` nie powinien zabierać focusu, ale Slack
może wywoływać `[NSApp activateIgnoringOtherApps:YES]` przy każdym kliku,
co może spychać overlay. Test: timer log że NSPanel.isVisible 100ms po
emit; jeśli był visible przez chwilę → focus battle.

## Następne kroki diagnostyczne

1. **Dodać verbose logging do `ToastWindow.appear()`** — co spawnujemy,
   na którym screenie, jaki frame, czy isVisible po 200ms
2. **User test**: wyciągnąć Slacka z fullscreen (zwykłe okno), powtórzyć
   klik 🔖 — sprawdzić czy działa. To rozdzieli H1 od reszty.
3. **Jeśli H1**: zbadać alternatywy do NSPanel — `NSStatusBar` overlay
   albo `NSWindow` z custom level rawValue 2147483647 (max)
4. **Alternatywa awaryjna**: jeśli NSPanel jest w martwym końcu — przeciąć
   problem inaczej, np. animacja na ikonie statusbar SFlow z tymczasowym
   ukryciem nazwy akcji jako title (zamiast osobnego okna). Mniej "pretty"
   ale działa zawsze.

## Wpływ na produkt

- **Slack po lewej / na primary monitorze** — prawdopodobnie działa
  (nieprzetestowane w tej sesji)
- **Slack fullscreen na 2. monitorze** — bug aktywny
- **Inne Electrony (Linear, Discord, Notion Mail)** — nieznane, podobne
  ryzyko jeśli używasz multi-monitor + fullscreen
- **Reguły `slack-msg-*` same w sobie działają** — `events.jsonl`
  potwierdza. Wartość będzie odzyskana gdy fix renderowania ruszy.

## Powiązane pliki

- `SFlow/ToastWindow.swift` — głównie tu fixujemy
- `SFlow/ShortcutRules.swift:172-191` — helper `messageActions(...)` + 8 reguł Slack
- `SFlow/TooltipObserver.swift:67-74` — Fix AXManualAccessibility (działa)
- `SFlow/ClickWatcher.swift:43-57, 519-525, 526-541` — tap re-enable (działa)
