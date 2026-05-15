# Notion Calendar — do zrobienia

## New Event / Compose button (nie działa)

AX działa (result=0, hasElem=true), ale nie wiemy jakie atrybuty ma przycisk "New Event".

**Jak dokończyć:**
1. Uruchom SFlow z Xcode (⌘R)
2. W `AppDelegate.startWatcher()` dodaj tymczasowo:
   ```swift
   #if DEBUG
   ClickWatcher.diagnosticBundleId = "com.cron.electron"
   #endif
   ```
3. Kliknij przycisk New Event w Notion Calendar
4. Sprawdź logi `SFlow[diag]` — znajdź `role`, `desc`, `title`
5. Dodaj regułę do `ShortcutRules.swift` w bloku `"com.cron.electron"`:
   ```swift
   .init(desc: "<co zwróci AX>", id: "notion-cal-new-event", keys: ["c"], hint: "New Event"),
   // lub:
   .init(title: "<co zwróci AX>", id: "notion-cal-new-event", keys: ["c"], hint: "New Event"),
   ```

## Nawigacja (strzałki prev/next tydzień) — niemożliwe na razie

AX zwraca `AXButton desc='' title='' id=''` — całkowicie puste.
Nie można dopasować bez alternatywnego podejścia (np. pozycja ekranowa).

## MenuBarIndex testy — 3 failing (pre-existing, niezwiązane)

W `MenuBarIndexTests.swift`:
- `test_lookup_exactTitle` — kod zwraca `.high`, test oczekuje `.medium`
- `test_lookup_partialTitle` — logika `q.contains($0.key)` jest odwrócona, powinno być `$0.key.contains(q)`

Naprawić osobno przy okazji MenuBarIndex refactoru.
