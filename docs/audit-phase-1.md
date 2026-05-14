# SFlow — Audyt Fazy 1: Jakość pokrycia w skali

> Idealny stan po Fazie 1, problemy do rozwiązania (z odniesieniami do
> `audit-phase-0.md`), sub-cele z opcjami implementacji, decyzje, kryteria
> akceptacji. Spisany 2026-05-13, aktualizowany po każdej sesji.

## Legenda statusów (dla AI updatującego po sesji)

- ⬜ **pending** — nie zaczęte
- 🟡 **in-progress** — zaczęte, niedokończone (opisać co jeszcze trzeba)
- 🔵 **partial** — działa częściowo (opisać co działa a co nie)
- 🟢 **done** — zrobione + zweryfikowane
- 🔴 **regression** — cofnięte z poprzedniego statusu (opisać dlaczego)

## Aktualne statusy sub-celów

| Sub-cel | Status | Komentarz |
|---|---|---|
| 1.0 Re-seed Terminal/Notion/Claude | 🟢 done | Terminal avg 3.4, Notion avg 4.3, Claude avg 4.4 wariantów per regule (sesja 2026-05-14) |
| 1.1 Quality gate dla auto-discovered rules | 🟢 done | Backend dedup ✅ (v1.1.1). Settings toggle ✅. Client-side filtr confidence/source w RuleCache ✅ (sesja 2026-05-14) |
| 1.2 Retry + backoff dla failed discovery | ⬜ pending | — |
| 1.3 Self-healing przez miss log → /v1/refresh | 🔵 partial | `?fresh=1` cache bypass zrobiony (v1.1.1). Brakuje: miss data w body + scheduler client-side |
| 1.4 False-positive feedback (cmd-klik) | 🟢 done | cmd-klik na toast + false_positives.jsonl + lokalny disable po 3 zgłoszeniach + Settings Recent Shortcuts list + /v1/feedback backend (sesja 5) |
| 1.5 Naprawa bugu MenuBarIndex.lookup | 🟢 done | Fix key.contains(q) + próg 5 znaków + 4 testy (sesja 2026-05-14) |
| 1.6 20 zweryfikowanych apek + coverage-report.md | ⬜ pending | Dziś: 2 zweryfikowane w v1.1.1 (Slack, Obsidian) |
| 1.7 Beta z 3-5 osobami | ⬜ pending | — |
| 1.8 Video-based eval protocol | 🔵 partial | Skrypt `sflow-video-eval` + `sflow-video-extract.swift` zbudowany (sesja 2026-05-14, droga C). Brakuje: LLM vision `--llm` flag (droga B) |
| 1.9 Window element improvements (P-6 + P-25) | 🟢 done | AXKeyShortcutsValue Layer 0 + AXIdentifier w całym stosie ✅ (sesja 2026-05-14) |
| 1.10 Matching engine quality (P-26..P-30) | 🟢 done | Audyt 2026-05-14 wykrył 4 fundamentalne bugi rozpoznawania + brak telemetrii per-layer. Plan: `docs/superpowers/plans/2026-05-14-matching-engine-quality.md` (9 tasków TDD, ~4h) (sesja 6, 2026-05-14) |

---

## Execution sequence (~10-12 sesji do końca Fazy 1)

> **AI: ta tabela mówi w jakiej kolejności robimy sub-cele i problemy. Po
> każdej zakończonej sesji aktualizujesz kolumnę Status i jeśli trzeba
> dopisujesz Atomic plan dla kolejnej sesji.**
> Pierwsze 4 sesje są rozpisane detalicznie w "Atomic plans" niżej. Sesje
> 5-12 są szkicowe — zostaną doprecyzowane po sesji 4 (gdy będziemy mieli
> więcej danych z early sub-celów).

| # | Sesja | Sub-cele / Problemy | Time | Status | Detail |
|---|---|---|---|---|---|
| **1** | Sweet wins | 1.0 + P-23 + 1.8 droga C | ~3h | 🟢 done | 📋 below |
| **2** | Bug squashing | 1.5 + P-15 + P-21 | ~4h | 🟢 done | 📋 below |
| **3** | Settings foundation | Nowe okno SwiftUI (baza dla 1.1/1.4/1.7) | ~6h | 🟢 done | 📋 below |
| **4** | Client quality gate | 1.1 dokończenie (filtr po confidence/source) | ~4h | 🟢 done | 📋 below |
| **4.5** | Window element wins | 1.9 (P-6 AXKeyShortcutsValue + P-25 identifier) | ~1 dzień | 🟢 done | 📋 below |
| **5** | False-positive feedback | 1.4 (cmd-klik + Recent shortcuts list w Settings) | ~2 dni | 🟢 done | ✏️ sketch |
| **6** | Retry + backoff | 1.2 (persisted state, exponential backoff) | ~2 dni | ⬜ | ✏️ sketch |
| **7** | Self-healing /v1/refresh | 1.3 (miss data + scheduler) | ~3 dni | ⬜ | ✏️ sketch |
| **8** | Bundled.json update path | P-19 + versioning | ~1 dzień | ⬜ | ✏️ sketch |
| **9-10** | Coverage eval batch 1+2 | 1.6 (10-15 apek, ~1/dzień) | ~10 mini-sesji 60min | ⬜ | ✏️ sketch (per-batch detail) |
| **11** | Beta setup | 1.7 (DMG + 5 znajomych) | ~1 dzień | ⬜ | ✏️ sketch |
| **12** | Beta debrief + decyzja | 1.7 (po 2 tyg.) → go-Faza-2 lub pivot | ~4h | ⬜ | ✏️ sketch (po danych z bety) |

**Decyzyjny checkpoint po sesji 4:** rewizja sesji 5-12 na podstawie tego co
nauczyliśmy się o czasie/scope w sesjach 1-4. Możliwe że niektóre sesje
trzeba rozbić/scalić.

**Decyzyjny checkpoint po sesji 12 (beta debrief):** jeśli toast nie uczy
(średnia <2 nowych skrótów per user) → PIVOT (droga D lub C z product-vision)
— sesje 13+ nie istnieją w obecnej formie.

---

## Atomic plans — sesje 1-4 (detal)

### Sesja 1: "Sweet wins" (~3h)

**Cel:** Najszybszy ROI dostępny dziś. Wyrównanie jakości bundled.json,
usunięcie minor bugu, budowa narzędzia do dalszych ewaluacji.

**Adresowane elementy:**
- ✅ Sub-cel 1.0 → 🟢 done
- ✅ P-23 (within-rule dupes) → 🟢 done
- ✅ Sub-cel 1.8 droga C (sflow-video-eval) → 🔵 partial (skrypt zrobiony,
  droga B/A nadal pending)

**Kroki:**

1. Quit GUI SFlow: `osascript -e 'tell application "SFlow" to quit'`
2. Reseed Terminal: `./scripts/sflow-reseed com.apple.Terminal`
3. Verify cache file: `jq '.rules | map(.match.titles | length) | {avg: (add/length), min, max}' "$HOME/Library/Application Support/SFlow/rules/cache/com.apple.Terminal.json"` — oczekujemy avg ≥3
4. Reseed Notion + Claude Desktop (powtórz krok 2-3 dla obu)
5. Promote: `./scripts/promote-to-bundled.sh com.apple.Terminal notion.id com.anthropic.claudefordesktop`
6. Build + manual sanity: `xcodebuild build -project SFlow.xcodeproj -scheme SFlow`
7. Commit: `feat(rules): re-seed Terminal/Notion/Claude with v1.1.1 prompt`
8. Fix P-23 w `backend/src/dedup.ts`: dodać dedupe within-rule titles przed return — `rule.match.titles = Array.from(new Map(rule.match.titles.map(t => [t.toLowerCase(), t])).values())` (preserves case of first occurrence)
9. Test w `backend/tests/dedup.test.ts`: nowy test "drops duplicate titles within single rule"
10. `cd backend && npm test && cd ..`, commit: `fix(backend): dedupe duplicate titles within single rule`
11. Build `scripts/sflow-video-eval` + `scripts/sflow-video-extract.swift` per audit-phase-1.md Sub-cel 1.8 Droga C section (~30 min)
12. Test: `./scripts/sflow-video-eval <ostatni mp4 Filipa>` — sprawdzić że stripy się tworzą
13. Commit: `feat(scripts): sflow-video-eval extracts frames + builds montage strips`
14. Update statusy + session log + commit: `docs: session 1 complete — sweet wins`

**Acceptance criteria:**
- [ ] 5 apek w bundled.json mają avg ≥3 wariantów per regule (Terminal, Notion, Claude osiągają poziom Slack+Obsidian)
- [ ] `backend/tests/dedup.test.ts` ma test dla within-rule dupes
- [ ] `./scripts/sflow-video-eval <mp4>` działa end-to-end
- [ ] Zero regression w istniejących testach

**Statusy do zaktualizowania po sesji:**
- audit-phase-1.md: Sub-cel 1.0 ⬜→🟢, Sub-cel 1.8 (status) ⬜→🔵, kolumna Status w Execution sequence dla sesji 1 ⬜→🟢
- audit-phase-0.md: P-23 ⬜→🟢
- roadmap.md: nowy wpis w Session log "2026-XX-XX — Sesja 1: Sweet wins"

**Commits oczekiwane:**
1. `feat(rules): re-seed Terminal/Notion/Claude with v1.1.1 prompt`
2. `fix(backend): dedupe duplicate titles within single rule`
3. `feat(scripts): sflow-video-eval extracts frames + builds montage strips`
4. `docs: session 1 complete — sweet wins`

---

### Sesja 2: "Bug squashing" (~4h)

**Cel:** 3 niezależne, znane bugi/luki naprawione w jednej sesji. Wszystkie
proste, ale każdy ma realny user impact.

**Adresowane elementy:**
- ✅ Sub-cel 1.5 (MenuBarIndex.lookup substring direction) → 🟢 done
- ✅ P-15 (Input Monitoring permission check) → 🟢 done
- ✅ P-21 (backend console.log observability) → 🔵 partial (basic logs ✅, dashboard później)

**Kroki:**

1. **MenuBarIndex fix** (1-2h):
   - W `SFlow/MenuBarIndex.swift:72` zamienić `q.contains($0.key)` na hybrid: exact match → .high, OR (`$0.key.contains(q)` AND `q.count >= 5`) → .medium
   - Naprawić istniejące pre-existing failing tests `MenuBarIndexTests.test_lookup_exactTitle`, `test_lookup_partialTitle`
   - Dodać test: "Copy link" → no match na .medium z key "copy"
   - Commit: `fix(client): MenuBarIndex.lookup uses correct substring direction with length threshold`
2. **Input Monitoring permission check** (~1h):
   - W `SFlow/AppDelegate.swift` po `AXIsProcessTrustedWithOptions` dodać `IOHIDCheckAccess(.listenEvent)` (lub `CGPreflightListenEventAccess()` jeśli istnieje)
   - Jeśli `denied` lub `unknown` → pokazać alert "Input Monitoring required" z linkiem `x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent`
   - Commit: `feat(client): check Input Monitoring permission before starting watcher`
3. **Backend observability** (~1h):
   - W `backend/src/handlers/discover.ts` przed return dodać:
     ```ts
     console.log(JSON.stringify({
       type: "discover", bundleId: req.bundleId, appVersion: req.appVersion,
       cacheHit: !!cached, fresh: skipCache,
       rulesGenerated: rules?.rules?.length ?? 0,
       dropped: droppedCount, durationMs: Date.now() - start,
     }));
     ```
   - `Date.now()` capture na początku handlera
   - Commit: `feat(backend): structured /v1/discover logs for observability`
4. Update statusy + session log + commit

**Acceptance criteria:**
- [ ] MenuBarIndex tests przechodzą (3 pre-existing failures znikają)
- [ ] User z odebraną Input Monitoring permission widzi alert
- [ ] Każdy `/v1/discover` request loguje strukturalny JSON z timing+counts

**Statusy do zaktualizowania po sesji:**
- audit-phase-1.md: Sub-cel 1.5 ⬜→🟢, kolumna Status dla sesji 2 ⬜→🟢
- audit-phase-0.md: P-5 ⬜→🟢, P-15 ⬜→🟢, P-21 ⬜→🔵
- roadmap.md: Session log

---

### Sesja 3: "Settings foundation" (~6h)

**Cel:** Zbudować bazowe okno Settings (SwiftUI) — fundament potrzebny dla
sesji 4, 5, 7. Bez tego nie da się zrobić "experimental toggle", "Recent
shortcuts list", "Telemetry toggle".

**Adresowane elementy:**
- (przygotowanie) Sub-cel 1.1 fundament
- (przygotowanie) Sub-cel 1.4 fundament (Recent shortcuts list)
- (przygotowanie) Sub-cel 1.7 fundament (Telemetry settings dla bety)

**Kroki:**

1. Nowy plik `SFlow/SettingsWindow.swift` (~200 linii) — SwiftUI `Window`
   z TabView (3 zakładki: General / Privacy / Advanced)
2. Menu bar item dodaje "Settings…" (⌘,) → otwiera okno
3. **General tab** (pusty preview na razie):
   - Placeholder "App preferences will appear here"
4. **Privacy tab**:
   - Toggle "Log miss events" (default ON) → zapisuje do UserDefaults `logMisses`
   - Toggle "Telemetry — share aggregates with backend" (default OFF, na razie nie wysyła nic)
   - Przycisk "Open events.jsonl in Finder"
   - Przycisk "Clear local data"
5. **Advanced tab**:
   - Toggle "Show experimental shortcuts" (default OFF) — zapisuje `RuleCache.showExperimental`
   - Lista "Recent toasts" (placeholder na razie — pełna w sesji 5)
   - Przycisk "Force re-seed all rules"
6. Hookup do `EventLogger` (sprawdza `UserDefaults.logMisses` przed zapisem)
7. Hookup do `RuleCache` (już ma `showExperimental: Bool`, podpiąć do UserDefaults)
8. Testy snapshot dla layout'u (opcjonalne)
9. Build + manual test: każdy toggle działa, settings persistują przez restart
10. Commit: `feat(client): Settings window with Privacy + Advanced tabs`
11. Update statusy + session log

**Acceptance criteria:**
- [ ] Settings okno otwiera się z menu bar + skrótem ⌘,
- [ ] 3 tabs widoczne, navigation działa
- [ ] Privacy.logMisses toggle wpływa na EventLogger
- [ ] Advanced.showExperimental wpływa na RuleCache filter
- [ ] Persistencja przez restart aplikacji

**Statusy do zaktualizowania po sesji:**
- audit-phase-1.md: Sub-cel 1.1 🔵 → 🟡 (in-progress, fundament gotowy)
- (nowy P-24?): "Settings window built but most controls placeholder" → ⬜ docelowo doprecyzowane

---

### Sesja 4: "Client quality gate (1.1 dokończenie)" (~4h)

**Cel:** Dokończyć Sub-cel 1.1 — auto-discoverowane reguły z niskim
zaufaniem nie są aktywne by default. User może je włączyć przez
"Show experimental shortcuts" w Settings (z sesji 3).

**Adresowane elementy:**
- ✅ Sub-cel 1.1 → 🟢 done (po sesji)

**Kroki:**

1. W `SFlow/RuleCache.swift:81` rozszerzyć filtr:
   ```swift
   for rule in rules {
       if !showExperimental {
           // Bundled apps: zostaw .high i .medium
           // Auto-discovered (cache/*.json): .high + (menu_bar lub web_docs_official)
           if rule.confidence == .low { continue }
           if isAutoDiscovered && rule.confidence != .high { continue }
           if isAutoDiscovered && rule.source != .menuBar && rule.source != .webDocsOfficial { continue }
       }
       // ... reszta
   }
   ```
2. Dodać property `isAutoDiscovered: Bool` per ruleset (wnioskuje z source path
   — `bundled.json` vs `cache/<bundle>.json`)
3. Testy w `RuleCacheTests.swift`:
   - "auto-discovered medium+inferred_pattern not active by default"
   - "auto-discovered high+menu_bar active by default"
   - "experimental toggle activates all medium"
   - "bundled medium+web_docs_third_party active by default (no auto-discovered restriction)"
4. Manual eval: świeży reseed Figmy (auto-discovery) — sprawdzić że pokazujemy
   tylko `high + menu_bar/web_docs_official`. `--show-experimental` flag w
   build dev pokazuje wszystko
5. Commit: `feat(client): RuleCache filters auto-discovered rules by confidence+source`
6. Update statusy + session log

**Acceptance criteria:**
- [ ] Świeża auto-discovery dla NIEzweryfikowanej apki nie pokazuje toastów dla
      `medium + inferred_pattern` ani niżej
- [ ] Włączenie "Show experimental" w Settings aktywuje wszystkie medium
- [ ] Bundled.json bez zmian (wszystkie reguły aktywne jak dziś)
- [ ] Pełen test suite green (+ 4 nowe testy)

**Statusy do zaktualizowania po sesji:**
- audit-phase-1.md: Sub-cel 1.1 🔵 → 🟢
- audit-phase-0.md: P-1 🔵 → 🟢

---

### Sesja 4.5: "Window element wins" (~1 dzień)

**Cel:** Zamknąć główną architektoniczną asymetrię między menu bar (aktywne)
a window elements (pasywne). Dwa niezależne, czyste kroki.

**Adresowane elementy:**
- Sub-cel 1.9 → 🟢 done (po sesji)
- P-6 (AXKeyShortcutsValue) → 🟢 done
- P-24 Etap 1 → 🔵 partial (P-6 rozwiązuje Etap 1, P-25 to Etap 2)
- P-25 (identifier w schemacie reguł) → 🟢 done

**Krok 1: AXKeyShortcutsValue jako Layer 0 (~2h)**

W `SFlow/ClickWatcher.swift`, w pętli `for _ in 0..<6` przed Layer 0.5
(linia 110), dodaj nowe odczytanie:

```swift
// Layer 0: AXKeyShortcutsValue (Electron/Chromium aria-keyshortcuts)
var ksRef: AnyObject?
AXUIElementCopyAttributeValue(current, "AXKeyShortcutsValue" as CFString, &ksRef)
if let ks = ksRef as? String, !ks.isEmpty,
   let keys = parseAriaShortcut(ks) {
    let autoId = "aria:\(bundleId):\(keys.joined(separator: "+"))"
    let hintText = (titleRef as? String) ?? ks
    emit(bundleId: bundleId, shortcutId: autoId, keys: keys,
         hint: hintText, loc: nsLoc)
    return
}
```

Implementuj `parseAriaShortcut(_ s: String) -> [String]?` jako prywatną
metodę w `ClickWatcher`:
```swift
// "Meta+K" → ["meta","k"], "Meta+Shift+M" → ["meta","shift","m"]
// "c" → ["c"] (single key)
private func parseAriaShortcut(_ s: String) -> [String]? {
    let parts = s.lowercased().split(separator: "+").map(String.init)
    guard !parts.isEmpty else { return nil }
    // Normalize: "meta" → "meta", "shift" → "shift", "alt" → "alt", "ctrl" → "ctrl"
    let normalized = parts.map { p -> String in
        switch p {
        case "meta", "cmd", "command": return "meta"
        case "alt", "option":          return "alt"
        case "ctrl", "control":        return "ctrl"
        case "shift":                  return "shift"
        default:                       return p  // single char key
        }
    }
    return normalized
}
```

Testy w `ClickWatcherTests.swift` (lub nowym `AXKeyShortcutsValueTests.swift`):
- `parseAriaShortcut("Meta+K")` → `["meta","k"]`
- `parseAriaShortcut("Meta+Shift+M")` → `["meta","shift","m"]`
- `parseAriaShortcut("c")` → `["c"]`
- `parseAriaShortcut("")` → `nil`

**Krok 2: AXIdentifier w skeletonie i schemacie reguł (~4h)**

2a. `SFlow/AXSkeletonExtractor.swift`:
```swift
// W SkeletonItem — dodaj opcjonalne pole
struct SkeletonItem: Codable, Hashable {
    let role: String
    let title: String
    let identifier: String?  // DOM id — stable, language-agnostic
}

// W walk() — po odczycie title/desc, dodaj:
var identRef: AnyObject?
AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identRef)
let identifier = (identRef as? String).flatMap { $0.isEmpty ? nil : $0 }
if !title.isEmpty {
    raw.append(RawAXItem(role: role, title: title, identifier: identifier))
}
```

Uwaga: `RawAXItem` też dostaje opcjonalne `identifier: String?`.

2b. `SFlow/LoadedRule.swift` — rozszerz `LoadedMatch`:
```swift
struct LoadedMatch: Codable {
    let role: String
    let titles: [String]
    let identifiers: [String]?  // opcjonalne — istniejące reguły bez tego pola nadal działają
}
```

2c. `SFlow/RuleCache.swift` — dodaj identifier matching w `match()`:
```swift
func match(bundleId: String, role: String, title: String, desc: String,
           help: String, identifier: String = "") -> MatchResult? {
    // ...
    for rule in rules {
        // ...
        // Identifier check (język-agnostic, sprawdź PRZED titles)
        if let ruleIds = rule.match.identifiers, !identifier.isEmpty {
            let identLC = identifier.lowercased()
            if ruleIds.contains(where: { identLC == $0.lowercased() }) {
                return MatchResult(rule: rule)
            }
        }
        // Existing title match...
        let titleMatches = rule.match.titles.contains { ... }
        if titleMatches { return MatchResult(rule: rule) }
    }
}
```

2d. `SFlow/ClickWatcher.swift` — przekaż `identifier` do `ruleCache.match()`:
```swift
if let result = ruleCache.match(
    bundleId: bundleId, role: currentRole,
    title: currentTitle, desc: currentDesc,
    help: currentHelp.lowercased(),
    identifier: currentIdentifier  // już czytany w linii 92
) { ... }
```

2e. `backend/src/types.ts` — dodaj do `MatchSchema`:
```typescript
identifiers: z.array(z.string()).max(5).optional(),
```

2f. `backend/src/prompt.ts` — dodaj instrukcję do systemu:
```
- "identifiers": optional array of stable DOM ids/AX identifiers for this element.
  Include when you can identify a stable, language-agnostic identifier from the
  skeleton (e.g. "compose-btn", "search-input"). Omit if not present in skeleton.
```

**Testy end-to-end:**
- Sprawdź Gmail (web w Chrome) — czy `AXKeyShortcutsValue = "c"` na Compose
- Sprawdź Slack — czy jakiekolwiek przyciski mają `AXKeyShortcutsValue`
- Sprawdź że istniejące reguły bez `identifiers` nadal działają (null safety)

**Acceptance criteria:**
- [ ] `parseAriaShortcut` testy pass
- [ ] Przynajmniej 1 apka (Gmail/Slack) daje toast przez Layer 0 AXKeyShortcutsValue
- [ ] `SkeletonItem` ma opcjonalne `identifier` i nie łamie istniejących testów
- [ ] `RuleCache.match()` akceptuje identifier i sprawdza go przed titles
- [ ] `LoadedMatch` z `identifiers: null` (stare reguły) nadal matchuje poprawnie
- [ ] Backend `types.ts` akceptuje opcjonalne `identifiers` w regułach

---

## Atomic plans — sesje 5-12 (szkice, do doprecyzowania po sesji 4)

> Krótki opis każdej sesji. Po sesji 4 wracamy do tego pliku i rozpiszemy
> sesje 5-12 jak 1-4 (z konkretnymi krokami).

**Sesja 5: False-positive feedback (~2 dni)**  
Sub-cel 1.4. Cmd-klik na toast → "marked as wrong" + lokalny disable po 3
zgłoszeniach. Plus Settings → Recent Shortcuts list (z sesji 3) z "Disable"
button per pozycja. Wymaga ostrożnej modyfikacji `ToastWindow.ignoresMouseEvents`.

**Sesja 6: Retry + backoff (~2 dni)**  
Sub-cel 1.2. `~/Library/Application Support/SFlow/discovery-state.json`
persistowany stan: `{attempts, lastAttempt, nextRetryAt, status}`. Backoff
1m/5m/30m/24h/7d. Settings "Apps without rules" lista + "Retry now" button.

**Sesja 7: Self-healing /v1/refresh (~3 dni)**  
Sub-cel 1.3. Rozszerzenie `?fresh=1` o opcjonalne `missExamples` w body.
Backend prompt warunkowy ("here are unmatched elements"). Client
`NSBackgroundActivityScheduler` co 24h agreguje misses + decyduje czy refresh.

**Sesja 8: Bundled.json update path (~1 dzień)**  
P-19. Versioning w bundled.json (`fileVersion: Int`). `RuleStorage.seedBundledIfMissing`
porównuje shipping vs user. Test scenariusza upgrade. User_overrides.json
NIGDY nadpisywany.

**Sesje 9-10: Coverage eval (10 mini-sesji 60min/apka)**  
Sub-cel 1.6. Per apka: otwórz → wait auto-discovery → 20 kliknięć → notuj
hit%+false+ → iteruj prompt jeśli <70% → promote. Build `docs/coverage-report.md`.
Tier 2 lista: Notion (po sesji 1), Figma, VS Code, Chrome, Arc, Raycast, Mail,
Finder, Safari, Spotify.

**Sesja 11: Beta setup (~1 dzień)**  
Sub-cel 1.7. Build DMG signowany. Onboarding doc 3 strony. Rekrutacja 5
znajomych (network). Email/Slack channel do raportowania. NDA-free.

**Sesja 12: Beta debrief + decyzja (~4h po 2 tyg.)**  
Sub-cel 1.7 finalny. Analiza danych z 2 tygodni. Ankiety pre/post:
"ile nowych skrótów teraz używasz?". Decyzja: ≥3 → Faza 2; 1-2 → Faza 2
agresywniejsza; 0-1 → PIVOT (droga D lub C w vision).

---

## Executive summary

**Cel Fazy 1:** SFlow działa "dobrze" dla **dowolnej apki którą user
zainstaluje** — nie tylko 4 zweryfikowanych. "Dobrze" mierzymy 3 metrykami:

- **Hit rate ≥70%** dla 10 najczęściej klikanych elementów per apka
- **False-positive rate <5%** kliknięć
- **Recovery <24h** gdy reguły się starzeją (samonaprawianie przez miss log)

**Dlaczego to jest blokujące:** Bez tego nie warto budować Fazy 2-5 (uczenie,
raporty, pricing). Jeśli toast pokazuje fałszywy skrót w 1 na 10 kliknięć,
user **przestaje ufać** apce w pierwszym tygodniu i nikt nigdy nie zobaczy
naszego curriculum.

**Co budujemy:** 7 sub-celów (1.1-1.7), z których każdy adresuje konkretny
problem z audytu Fazy 0. Każdy ma 2-3 możliwe drogi z plusami/minusami.

---

## Idealny stan na koniec Fazy 1

### Z perspektywy usera

**Tydzień 1 doświadczenia po instalacji:**

1. Pierwsze uruchomienie. Welcome screen. Permissions (AX **i** Input
   Monitoring — obie sprawdzone przed startem watchera). Wybierz top apki.
2. Otwiera Slacka po raz pierwszy z SFlow. Menu bar pokazuje
   "✨ Learning Slack…" przez ~10s. Po zakończeniu — toast działa od pierwszego
   kliknięcia.
3. Otwiera Notion. Pierwsza próba discovery dostaje pusty skeleton bo Notion
   jeszcze się ładuje. SFlow **automatycznie ponawia** 30s później. Cache
   się zapełnia. Toasty działają.
4. Otwiera Figmę. Discovery succeeds, ale jeden toast jest **wyraźnie zły**
   (Figma ⌘C zamiast nic na "Copy properties" buttonie). User cmd-klika
   toast → "marked as wrong". Lokalnie ten skrót jest wyłączony.
5. Dzień 5. SFlow już zna 12 apek z których user korzysta. Toast pojawia się
   średnio w 75% kliknięć interaktywnych. Zero fałszywych toastów ze skróconej
   listy (user oznaczył 2 jako złe, oba wyłączone).
6. Dzień 7. SFlow w tle ponowił 1 apkę bo miss log pokazał że stare reguły
   się zdegradowały (Notion update). Bez wiedzy usera nowe reguły działają.

### Z perspektywy developera (Filipa)

**Codzienna praca:**

1. `sflow-analyze` pokazuje top miss tytuły per apka — jasna lista TODO
   dla kolejnych iteracji promptu.
2. Backend dashboard (CF Analytics + custom logs) pokazuje:
   - Top 10 najczęściej discoverowanych apek
   - Średni czas `/v1/discover`
   - % requestów z 0 rules zwróconych
   - Top 10 apek z najwięcej `false_positive` zgłoszeń
3. `docs/coverage-report.md` — żywy dokument z aktualnym statusem 20+ apek,
   linkowany z landing page'u.
4. `--reseed` jest narzędziem developerskim, ale **production user nigdy
   nie musi go odpalać** — auto-flow plus self-healing wystarczają.

### Z perspektywy systemu

**Mierzalne charakterystyki:**

- 20 apek z confirmed `hit_rate ≥ 70%`, `false_positive_rate < 5%`
- Zero `medium`-confidence reguł z `source: inferred_pattern` aktywnych
- Mediana czasu od `app_activated` do "rules available" ≤ 20s
- Retry path: po failure ≥1 retry w ciągu 24h dla aktywnie używanych apek
- Backend: rate limit obsługuje "power user onboarding" (30 apek w 1h)
- Bundled.json: po SFlow update reguły dla bundled apek są odświeżone

---

## Sub-cele Fazy 1

### Sub-cel 1.0: Re-seed pozostałych bundled apek z v1.1.1 promtem (NOWY)

**Status:** Najszybszy ROI dostępny dziś. **Trzeba zrobić PIERWSZE**, przed
sub-celem 1.1 lub innym, bo:
- Backend v1.1.1 jest zdeployowany
- Reseeder + `?fresh=1` infrastruktura istnieje
- Trzy apki w bundled.json (Terminal, Notion, Claude Desktop) wciąż mają
  reguły v1.0 promptu — average 1.05–2.13 wariantów per regule, vs 4+
  dla Slack/Obsidian po v1.1.1 reseedzie

**Problem:** Mieszana jakość w bundled.json. User otwiera Notion → dostaje
gorsze reguły niż gdy otwiera Slacka. Powód: Notion był seedowana w v1.0,
Slack w v1.1.1. Inkonsystencja.

**Idealny outcome:** Wszystkie 5 apek w bundled.json ma reguły z v1.1.1
promtem (3-5 wariantów + hotkey-suffix), zero cross-rule overlaps, version: 1
w każdej regule.

**Pipeline (jednorazowy, ~30 min total):**
```bash
# Ubić GUI SFlow
osascript -e 'tell application "SFlow" to quit'

# Reseed jednej apki na raz (Reseeder skipuje te nie zainstalowane)
./scripts/sflow-reseed com.apple.Terminal
./scripts/sflow-reseed notion.id
./scripts/sflow-reseed com.anthropic.claudefordesktop

# Sprawdź każdy cache file
for app in com.apple.Terminal notion.id com.anthropic.claudefordesktop; do
  jq '.rules | map(.match.titles | length) | {avg: (add/length)}' \
    "$HOME/Library/Application Support/SFlow/rules/cache/$app.json"
done

# Promote
./scripts/promote-to-bundled.sh com.apple.Terminal notion.id com.anthropic.claudefordesktop
git add SFlow/Resources/bundled.json
git commit -m "feat(rules): re-seed Terminal/Notion/Claude with v1.1.1 prompt"
```

**Acceptance:** wszystkie 5 apek w bundled.json mają avg ≥3 wariantów tytułów
per regule. Backend dedup nie wyrzuca >5% reguł per apka (sygnał że prompt
działa czysto).

**Risk:** Notion ma dużo skomplikowanego AX tree — może wymagać większego
skeleton size w `AXSkeletonExtractor`. Sprawdzić po pierwszej próbie.

---

### Sub-cel 1.1: Quality gate dla auto-discovered rules

**Problem:** P-1 (Faza 0) — wszystkie `medium` reguły idą do toasta, część
z nich to `source: web_docs_third_party` lub `inferred_pattern` które mogą
być błędne.

**Idealny outcome:**
- Auto-discoverowana apka pokazuje toasty **tylko dla wysoce zaufanych
  reguł**.
- Bundled.json (manualnie zweryfikowane apki) — bez zmian, wszystkie reguły
  aktywne.
- User-overrides — najwyższy priorytet, zawsze aktywne.

**Drogi (opcje implementacji):**

**Droga A: Stała bramka po confidence + source**
```swift
func shouldEmit(_ rule: LoadedRule, isBundled: Bool) -> Bool {
    if isBundled { return rule.confidence != .low }  // bundled zawiera high+medium
    // Auto-discovered: tylko high + (high or menu_bar)
    return rule.confidence == .high && 
           (rule.source == .menuBar || rule.source == .webDocsOfficial)
}
```
- **Plus:** prostota, deterministyczne, łatwe do testowania
- **Minus:** może być zbyt rygorystyczne (Claude czasem oznacza menu_bar
  rules jako medium "for safety")

**Droga B: Dwa pliki — `cache/active/` i `cache/dormant/`**
- High confidence + menu_bar/web_docs_official → `active/<bundle>.json`
- Reszta → `dormant/<bundle>.json` (zapisane, ale nie ładowane przez RuleCache)
- User może w Settings "Show experimental shortcuts" → flag łączy oba
- **Plus:** zachowuje dane na przyszłość (jeśli prompt się polepszy)
- **Minus:** więcej kompleksów w storage

**Droga C: Tagging w runtime, decyzja w match()**
- Wszystkie reguły idą do cache jak teraz
- `RuleCache.match()` filtruje per-call używając logiki z A
- **Plus:** mała zmiana, łatwa rollback
- **Minus:** rule data nadal "brudna" w cache — przy zmianach polityki
  wymaga refetch

**Rekomendacja:** **Droga A** (najmniej zmian). Test: bundled.json
dla Slacka — wszystkie reguły działają jak dziś. Świeża discovery Figmy
po deploy — pokazuje 60% mniej reguł, ale wszystkie są poprawne.

**Decyzja do podjęcia:** Co z `medium` z `source: menu_bar`? Akceptujemy
czy odrzucamy? Sugestia: **akceptujemy** (bo Claude widział je w menu, więc
istnieją w apce — tylko mniej pewny shortcutu).

### Sub-cel 1.2: Retry + backoff dla nieudanej discovery

**Problem:** P-2, P-3 (Faza 0) — jedna porażka i koniec. Brak retry w tle,
brak UI feedback.

**Idealny outcome:**
- Discovery failuje (network blip, empty skeleton, rate limit) → automatyczny
  retry z exponential backoff
- Po ostatecznej porażce — user widzi opcję "Retry now" w Settings
- Empty skeleton (apka się jeszcze ładuje) → poczekaj 30s, spróbuj znowu

**Drogi:**

**Droga A: Stateful retry tracker persistowany do dysku**
- Nowy plik: `~/Library/Application Support/SFlow/discovery-state.json`
- Per bundleId: `{attempts: N, lastAttempt: timestamp, nextRetryAt: timestamp,
  lastError: string, status: "pending"|"failed"|"success"}`
- DiscoveryService czyta stan przy starcie, używa do decyzji
- Backoff: 1m, 5m, 1h, 24h, 7d
- **Plus:** Robust, działa przez restart, manualny retry łatwy
- **Minus:** Trochę pisania state machine logic

**Droga B: Simple in-memory z app-restart reset**
- Zostaw obecne `attempted: Set<String>`, ale dodaj timer co 1h resetujący
  failed entries z `attempts < 3`
- **Plus:** Trywialne
- **Minus:** Po SFlow restart traci historię, retry zaczyna od zera

**Droga C: Lazy + reactive**
- Brak proactive retry. Zamiast tego: gdy user **kliknie** w apce bez
  reguł → zmień status na "active needed", odpal `discovery` immediate
- **Plus:** Najmniej wysiłku w tle
- **Minus:** Pierwsze N kliknięć nie ma reguł, słaby UX

**Rekomendacja:** **Droga A**. State persisted = robust. Backoff
exponential = nie zatkamy backendu. UI Settings "Apps without rules"
pokazuje listę + "Retry now" button.

**Empty skeleton edge case:** Pre-check w `DiscoveryService.appActivated`:
jeśli `skeleton.count < 5 && menuBar.count < 3` → zapisz "pending retry
in 30s", nie POSTuj. To znaczy że dla apki która właśnie się ładuje, czekamy
na drugą próbę.

### Sub-cel 1.3: Self-healing przez miss log → `/v1/refresh`

**Problem:** P-8 (Faza 0) — reguły gniją bez mechanizmu odświeżania.

**Idealny outcome:**
- Klient codziennie agreguje miss log
- Jeśli apka X ma ≥20 missów z ≥3 powtórzeniami tego samego tytułu → wywołaj
  refresh
- Backend dostaje current rules + miss examples → Claude generuje
  zaktualizowaną wersję
- Klient zastępuje cache, miss count resetuje

**Drogi:**

**Droga A: Pełny `/v1/refresh` endpoint**
```typescript
POST /v1/refresh
{
  bundleId, appVersion,
  currentRules: [...],     // co teraz mamy
  missExamples: [           // co nie matchuje
    { role: "AXButton", title: "open quick switcher", count: 5 },
    { role: "AXButton", title: "new note", count: 4 },
  ],
  menuBar: [...],           // nowy menu bar (możliwe że się zmienił)
  uiSkeleton: [...]
}
```
Backend: Claude prompt "Update rules to match these unmatched elements".
- **Plus:** Pełne self-healing
- **Minus:** Nowy endpoint, nowy prompt, nowe testy

**Droga B: Rozszerz istniejący `?fresh=1` na `/v1/discover` o miss data
(częściowo zbudowane w v1.1.1)**
- Dziś `?fresh=1` istnieje i omija KV cache (dodane w v1.1.1 dla Reseedera)
- Trzeba dorzucić: opcjonalne `missExamples: [...]` w body + warunkową
  gałąź w prompcie ("here are unmatched elements — fix the rules")
- Klient: scheduler co 24h agreguje misses → POST z `?fresh=1&action=refresh`
- **Plus:** ~30% już zbudowane (`?fresh=1` infra + dedup post-process)
- **Minus:** Spaghetti — handler robi za dużo. `/v1/refresh` byłby czystszy

**Droga C: Periodic full re-discovery (no refresh path)**
- Co 30 dni cache wygasa, klient triggeruje normalną discovery
- Miss log idzie tylko do `sflow-analyze` jako dev tool
- **Plus:** Najprostsze — nie ma nowego endpointu
- **Minus:** Czekamy 30 dni na poprawkę. User może być przez ten czas
  uzależniony od fałszywych reguł.

**Rekomendacja:** **Droga A**. Self-healing jest unikatowym feature'em
SFlow vs konkurencja — warto zrobić porządnie.

**Trigger threshold:** Sugerowany: ≥20 missów w 7 dniach, ≥3 powtarzające
się tytuły (każdy ≥3x). Dane do walidacji na sobie + 3 betę.

### Sub-cel 1.4: False-positive feedback od usera

**Problem:** P-4 (Faza 0) — nie wiemy które toasty są błędne.

**Idealny outcome:**
- User ma natychmiastowy sposób żeby zgłosić "ten toast jest zły"
- Lokalnie: 3 zgłoszenia dla tego samego `(bundleId, shortcutId)` →
  automatyczne wyłączenie reguły
- Globalnie (Faza 2): agregacja przez backend

**Drogi:**

**Droga A: Cmd-klik na toast**
- Wymaga zmiany ToastWindow z `ignoresMouseEvents = true` na conditional
- Cmd-klik: nasłuchuj keyDown stanu Command, pokaż "✕ mark wrong" overlay
- Klik na overlay → zapisz `false_positive` event + lokalnie disable
- **Plus:** Natychmiastowe, w kontekście
- **Minus:** Modyfikuje sposób kliknięcia (potencjalnie idzie do apki też)

**Droga B: Menu bar item "Last shortcut was wrong"**
- W menu bar SFlow dodaj item "✕ Last toast was wrong"
- User klika → wyłącz ostatni emit
- **Plus:** Nie modyfikuje toasta
- **Minus:** Niezbyt odkrywalne (user nie wie że można)

**Droga C: Notification permission + reply**
- macOS notification "Was this shortcut helpful?" z buttonami Yes/No
- **Plus:** Bardzo widoczne
- **Minus:** Inwazyjne, większość userów wyłącza notifications

**Droga D: Settings → "Recent shortcuts" list z disable button**
- Lista ostatnich 50 toastów w Settings
- Per pozycja: "Disable this rule" button
- **Plus:** Retrospektywne, user może wracać
- **Minus:** Kompleks UI, mniej immediate

**Rekomendacja:** **Droga A** (cmd-klik na toast) + **Droga D** (Settings
list) jako fallback dla power-userów. Droga A daje natychmiastowy
feedback, D pozwala wrócić.

**Implementacja A z safety:** Toast pozostaje passthrough domyślnie, ale
gdy keyDown z Command jest aktywne **i toast jest widoczny** —
`ignoresMouseEvents = false` na 2s. Po cmd-kliknięciu: zwykły klik nie idzie
do apki (consume), zapisujemy `false_positive`.

### Sub-cel 1.5: Naprawa bugu w `MenuBarIndex.lookup`

**Problem:** P-5 (Faza 0) — `q.contains($0.key)` powoduje "Copy link" → ⌘C
false positive.

**Uwaga:** Ten bug jest **różny** od fixu `RuleCache.stripHotkeySuffix`
dodanego w v1.1.1. Tamten fix tolerujemy trailing letter w AX title
(`"Edit message E"` matchuje rule `"Edit message"`) — Layer 0.5 matcher.
Tu bug jest w Layer 3 (MenuBarIndex fuzzy lookup) i dotyczy zupełnie
innej ścieżki kodu. v1.1.1 NIE naprawiał tego bugu.

**Idealny outcome:** Albo:
- (a) tylko exact match (zostawić linię 71, usunąć 72-75), albo
- (b) substring w **właściwą** stronę (`$0.key.contains(q)`) z minimum
  3 chars query.

**Drogi:**

**Droga A: Tylko exact match**
- `lookup()` zwraca tylko gdy `titleMap[q] != nil`
- **Plus:** Zero false positives
- **Minus:** Mniej trafień (np. "Open Quick Switcher" nie zmatchuje "Quick Switcher")

**Droga B: Substring `key.contains(q)`**
- "quick switcher" (key) contains "switcher" (query) → match .medium
- **Plus:** Więcej trafień
- **Minus:** Wciąż ryzyko jeśli query jest krótkie/popularne. "set" w "Settings"?

**Droga C: Hybrid z thresholdem**
- Exact match → .high
- Substring (key.contains(q)) ale `q.count ≥ 5` → .medium
- Inaczej brak
- **Plus:** Balans
- **Minus:** Magiczne liczby

**Rekomendacja:** **Droga C** z thresholdem 5 chars. Dlaczego nie A:
straciłbyś trafienia "Open X" → "X" które są przydatne. Dlaczego nie B:
3-char threshold za luźny ("New" → "New issue", "New tab", "New file" —
wszystko matchuje).

**Plus:** Naprawić istniejące testy w `MenuBarIndexTests.swift` które są
flagowane jako failing w `notion-calendar-todo.md`.

### Sub-cel 1.6: 20 zweryfikowanych apek + coverage report

**Problem:** Mamy 4 zweryfikowane apki, potrzebujemy 20 do udowodnienia
"działa skalowalnie".

**Idealny outcome:** `docs/coverage-report.md` z tabelą:

```
| App         | bundleId           | Hit % | False+ % | Rules | Verified   | Notes |
|-------------|--------------------|-------|----------|-------|------------|-------|
| Slack       | com.tinyspeck.slackmacgap | 85% | 2% | 27 | 2026-05-13 | bundled |
| Obsidian    | md.obsidian        | 92%   | 1%       | 31    | 2026-05-13 | bundled |
| Linear      | com.linear         | 78%   | 3%       | 24    | 2026-05-13 | bundled |
| Cursor      | com.todesktop.230313mzl4w4u92 | 80% | 2% | 19 | 2026-05-13 | bundled |
| Notion      | notion.id          | 75%   | 4%       | 35    | 2026-05-16 | bundled (new) |
| Figma       | com.figma.Desktop  | 50%   | 12%      | 14    | needs work | prompt tune |
| VS Code     | com.microsoft.VSCode | 88% | 2%       | 41    | 2026-05-17 | bundled |
| ...         |                    |       |          |       |            |       |
```

**Pipeline per apka (60 min):**
1. Otwórz apkę → SFlow auto-discoveruje (sprawdź "Learning…" w menu bar)
2. Czekaj na completion (≤30s typowo)
3. Klik 10 najpopularniejszych przycisków, notuj hit count
4. Klik 10 losowych przycisków + ad-hoc rzeczy, notuj false-positive count
5. Jeśli hit% <70%:
   - `sflow-analyze` → zobacz top misses
   - Iteruj prompt na backendzie, redeploy
   - Force-refresh tej apki (`--reseed <bundleId>`)
   - Powtórz 3-4
6. Jeśli false+% >5%:
   - Cmd-klik (z 1.4) na każdy fałszywy toast
   - Po sesji: sprawdź czy disable się utrwalił
   - Jeśli systemowy problem (Bug X) → wpisz do issues
7. Wpisz wyniki do `coverage-report.md`
8. Jeśli OK → promote do `bundled.json` (`scripts/promote-to-bundled.sh`)
9. Re-test po 7 dniach żeby sprawdzić degradację

**Lista 20 apek (sugestia po priorytecie ICP):**

Tier 1 (status faktyczny po v1.1.1):
- ✅ **Slack** (com.tinyspeck.slackmacgap) — reseedowana z v1.1.1 promtem, 58 reguł, avg 4.41 wariantów. Manual eval na wideo: 7+ poprawnych toastów, 0 confirmed wrong (po fix'ie Search-bar bug ⌘F→⌘G)
- ✅ **Obsidian** (md.obsidian) — reseedowana z v1.1.1 promtem, 44 reguły, avg 4.05 wariantów. Manual eval: 0 misses w wideo recordingu
- ⚠️ **Terminal** (com.apple.Terminal) — w bundled.json, ale **stary v1.0 prompt** (79 reguł, avg 1.05 wariantów). Wymaga reseedu z v1.1.1.
- ⚠️ **Notion** (notion.id) — w bundled.json, **stary v1.0 prompt** (63 reguły, avg 1.11). Wymaga reseedu.
- ⚠️ **Claude Desktop** (com.anthropic.claudefordesktop) — w bundled.json, **stary v1.0 prompt** (30 reguł, avg 2.13). Wymaga reseedu.
- ❌ **Linear** (com.linear) — **nie zainstalowany** na maszynie deweloperskiej, nigdy nie był reseedowany. Hardcoded w `Reseeder.verifiedApps` ale w praktyce skipowany.
- ❌ **Cursor** (com.todesktop.230313mzl4w4u92) — jak Linear.

**Akcja na pierwszy tydzień Fazy 1.0:** reseed Terminal+Notion+Claude z v1.1.1 promtem.

Tier 2 (priorytet — robić jako pierwsze):
- Notion (notion.id)
- VS Code (com.microsoft.VSCode)
- Figma Desktop (com.figma.Desktop)
- Chrome (com.google.Chrome)
- Arc (company.thebrowser.Browser)
- Raycast (com.raycast.macos)
- Mail (com.apple.mail)
- Finder (com.apple.finder)
- Safari (com.apple.Safari)
- Spotify (com.spotify.client)

Tier 3 (dobrze mieć):
- Notion Calendar (com.cron.electron — uwaga: notion-calendar-todo.md)
- Notion Mail (notion.mail.id)
- Claude Desktop (com.anthropic.claudefordesktop)
- Discord (com.hnc.Discord)
- Zoom (us.zoom.xos)
- 1Password (com.1password.1password)

### Sub-cel 1.8: Video-based quality eval (NOWY, periodic)

**Status:** 🔵 partial — wykonano raz manualnie w sesji 2026-05-13 wieczór
(diagnoza Slack search bar ⌘F vs ⌘G bug). Brakuje strukturyzowanego procesu
i automatyzacji.

**Problem:** Analiza miss log (`sflow-analyze`) wyłapuje "kliknięcie bez
toasta", ale **nie wyłapuje błędnych toastów** — sytuacji gdy SFlow pokazał
shortcut ale **inny niż realnie obowiązujący w apce**. Pierwsza taka
diagnoza wymagała:

1. Filip nagrał 90s screen recording (CleanShot)
2. AI wyciągnął ~200 klatek przez Swift+AVFoundation
3. AI manualnie czytał klatki, krzyżowo z `bundled.json`
4. AI odkrył nakładające się reguły (Slack "Search Slack" w 2 rule'ach
   z różnymi keys)

To **zadziałało**, ale 90% czasu poszło na manualną analizę klatek.
Da się to zautomatyzować.

**Idealny outcome:**
- Raz na N sesji (lub po zmianie promptu / reseedzie apki) Filip nagrywa
  60-90s normalnego użycia 1-2 zweryfikowanych apek
- AI uruchamia `./scripts/sflow-video-eval <video.mp4>` które wyciąga klatki
  i robi raport "co działa / co chybi / co źle"
- Wyniki idą do `docs/coverage-report.md` jako per-apka kolumny
  + jako wpis w session log

**Drogi:**

**Droga A: Pełna automatyzacja (Phase 3 long-term)**
- AppleScript driver dla Slack/Obsidian wykonuje 20 predefiniowanych
  akcji
- SFlow w trybie eval loguje wszystkie toasty + miss events do
  `eval-output.jsonl`
- Skrypt porównuje z expected output (golden file per apka)
- CI-friendly, headless
- **Plus:** Bez Filip-in-the-loop, deterministyczne
- **Minus:** Duża praca początkowa (AppleScript per apka), kruchość
  (każda zmiana UI apki łamie golden file)
- **Kiedy:** Po Fazie 1.7 beta, gdy mamy >10 apek z confirmed coverage

**Droga B: Wideo + LLM vision (Phase 2 medium-term, ~1 dzień pracy)**
- Filip nagrywa MP4 jak teraz
- `sflow-video-eval` wyciąga klatki (Swift+AVFoundation jak w sesji 2026-05-13)
- Co N klatek (np. co 1s) → POST do Claude API z prompt'em
  "Tu jest klatka screen recordingu. Czy widzisz SFlow toast? Jakie keys
  pokazuje? Czy w apce widoczny jest natywny tooltip z innym shortcut'em?
  Odpowiedź JSON: {toastVisible, toastKeys, toastHint, appTooltipKeys, appTooltipHint}"
- Skrypt agreguje per-frame answers, krzyżowo z rules cache
- Output: structured report `docs/video-eval-<timestamp>.md`
- **Plus:** Minimalna manualna praca, działa dla dowolnej apki bez golden file
- **Minus:** Koszt API (~$0.05 per 90s wideo), zależność od Claude vision
- **Kiedy:** Następna sesja (po sub-celu 1.0)

**Droga C: Manualny z lepszymi narzędziami (Phase 1 short-term, ~2h)**
- `sflow-video-eval <mp4>` wyciąga klatki, zapisuje do `/tmp/...` i drukuje
  proste podsumowanie (timestamps + ile klatek)
- Buduje **stripy 3×3** klatek (montaż) żeby AI mogło ogarnąć więcej w jednym Read
- AI manualnie analizuje stripy (10 zamiast 200 klatek)
- **Plus:** Najmniej kodu, najszybsze do zrobienia
- **Minus:** Nadal manualna analiza, ale 10× efektywniejsza

**Rekomendacja:** **Droga C** (now) → **Droga B** (gdy doceni się wartość)
→ **Droga A** (post-beta).

### Implementacja Drogi C (najbliższa sesja po sub-celu 1.0)

**`scripts/sflow-video-eval`** (bash + Swift):
```bash
#!/usr/bin/env bash
# Usage: sflow-video-eval <video.mp4> [interval_sec=1.0]
# Wyciąga klatki, montażuje stripy 3x3, drukuje metadane.
set -euo pipefail

VIDEO="${1:?usage: sflow-video-eval <video.mp4> [interval]}"
INTERVAL="${2:-1.0}"
OUTDIR="/tmp/sflow_video_eval_$(date +%Y%m%dT%H%M%S)"
mkdir -p "$OUTDIR"

# Wyciągnij klatki przez Swift+AVFoundation (skrypt patrz docs/audit-phase-1.md)
swift "$(dirname "$0")/sflow-video-extract.swift" "$VIDEO" "$OUTDIR" "$INTERVAL"

# Zbierz w stripy 3x3 (jeden PNG na 9 klatek)
# Wymaga ImageMagick (montage); fallback: zostaw pojedyncze klatki
if command -v montage >/dev/null; then
    cd "$OUTDIR"
    ls f_*.png | xargs -n9 sh -c 'montage "$@" -tile 3x3 -geometry 800x \
        "strip_$(printf %03d $((${0##*_}-1))).png"' _
fi

echo "Klatki w: $OUTDIR"
echo "Stripy w: $OUTDIR/strip_*.png"
echo "Następny krok: poproś AI 'przeczytaj stripy i znajdź wrong toasts'"
```

**`scripts/sflow-video-extract.swift`** — Swift script (~40 linii) używający
AVFoundation. Patrz template z sesji 2026-05-13 w session log (commit
`ede9c97` / wcześniej w sesji wieczornej).

**Wynik dla AI:** stripy w `/tmp/sflow_video_eval_<ts>/strip_*.png`. AI czyta
~10 stripów (zamiast 200 klatek), porównuje z rules cache, raportuje.

### Proces use'owy (dla Filipa + AI)

1. **Trigger:** AI proaktywnie sugeruje wideo po jednej z sytuacji:
   - Minęła >1 sesja od ostatniego video evalu
   - Zmiana w `backend/src/prompt.ts` lub `dedup.ts` w tej sesji
   - Reseed apki w `bundled.json` w tej sesji
   - Filip zgłasza "coś dziwnie działa"

2. **Filip:**
   - Nagrywa 60-90s screen recording (preferowane CleanShot, ale dowolne MP4)
   - Klika reprezentatywne przyciski w 1-2 zweryfikowanych apkach
   - Drop MP4 do repo root (gitignored: `*.mp4`)
   - Pisze do AI "przeanalizuj ten wideo: <ścieżka>"

3. **AI:**
   - `./scripts/sflow-video-eval <path>` (lub manualny extract jeśli skrypt
     jeszcze nie istnieje)
   - Czyta stripy/klatki
   - Krzyżowo z `SFlow/Resources/bundled.json` i `cache/*.json`
   - Raport markdown: ✅ toasts fired correctly / ❌ misses / ⚠️ wrong toasts
   - Sugeruje konkretne fix'y per finding
   - Dopisuje do `docs/coverage-report.md` (jeśli istnieje) per-app row

4. **Po sesji:**
   - MP4 usunięty (`*.mp4` w `.gitignore` więc nie zaśmieca repo)
   - Klatki w /tmp i tak są ulotne
   - Findings w session log

### Acceptance criteria sub-celu 1.8

- [ ] `scripts/sflow-video-eval` istnieje i działa (Droga C minimum)
- [ ] Wykonano ≥1 video eval z udokumentowanymi findings w session log
- [ ] `.gitignore` zawiera `*.mp4` żeby wideo nie wchodziły do gita
- [ ] (Droga B) `--llm` flag wywołuje Claude vision per klatka

---

### Sub-cel 1.9: Window element improvements — AXKeyShortcutsValue + identifier matching

**Powiązane problemy:** P-6, P-24, P-25 (patrz `audit-phase-0.md`)

**Problem:** Menu bar matching jest aktywne — `checkMenuBar()` odczytuje
prawdziwy skrót z `kAXMenuItemCmdChar`. Window element matching jest pasywne
— `ruleCache.match()` porównuje title z LLM-przewidzianymi wariantami.
Skutek: elementy okna mają systematycznie niższy hit rate niż menu bar items,
szczególnie dla lokalizowanych apek i apek które update'ują UI.

**Idealny outcome:**

1. Layer 0 w ClickWatcher czyta `AXKeyShortcutsValue` — dla Electron apek
   z `aria-keyshortcuts` dostajemy skrót bezpośrednio z elementu, bez reguł
2. `AXIdentifierAttribute` trafia do skeletonu i schematu reguł — backend
   może generować rules z stabilnymi identifierami
3. `RuleCache.match()` sprawdza identifier PRZED titles — bardziej stabilne

**Etap 1 (P-6 AXKeyShortcutsValue, ~2h):**

W `ClickWatcher` przed Layer 0.5:
```swift
var ksRef: AnyObject?
AXUIElementCopyAttributeValue(current, "AXKeyShortcutsValue" as CFString, &ksRef)
if let ks = ksRef as? String, let keys = parseAriaShortcut(ks) {
    emit(...); return
}
```

**Etap 2 (P-25 identifier matching, ~4h):**

Trzy zmiany równoległa:
- `AXSkeletonExtractor.SkeletonItem` + `walk()` → dodaj `identifier: String?`
- `LoadedMatch` → dodaj `identifiers: [String]?` (opcjonalne, backward compat)
- `RuleCache.match()` → sprawdź identifiers przed titles, dodaj parametr `identifier`
- `ClickWatcher` → przekaż `currentIdentifier` do `ruleCache.match()`
- `backend/src/types.ts` → `identifiers` opcjonalne w `MatchSchema`
- `backend/src/prompt.ts` → instrukcja generowania identifiers gdy dostępne

**Atomic plan w sesji 4.5 (powyżej)** zawiera pełny krok-po-kroku z kodem.

**Drogi implementacji:**

**Droga A (oba etapy razem):**
- Jeden commit: AXKeyShortcutsValue + identifier schema
- Plus: atomowa zmiana
- Minus: większy scope, trudniej debug

**Droga B (etap po etapie — rekomendowana):**
- Commit 1: Layer 0 AXKeyShortcutsValue (2h, standalone)
- Commit 2: Identifier w schemacie (4h, niezależny)
- Plus: każdy krok weryfikowalny osobno, łatwy rollback

**Risk:**
- `identifiers` w starych regułach = null → backward compat jest kluczowa.
  `LoadedMatch.identifiers: [String]?` (optional) gwarantuje że stare reguły
  nadal działają — `RuleCache.match()` po prostu skipuje identifier check
  gdy `rule.match.identifiers == nil`
- `AXKeyShortcutsValue` może mieć dziwne formaty w edge cases — `parseAriaShortcut`
  zwraca nil dla nieznanych formatów → fallback do istniejących warstw

---

### Sub-cel 1.7: Beta test z 3-5 osobami

**Problem:** Nie wiemy czy toast w ogóle uczy. Jeśli nie — pivot przed
Fazą 2.

**Idealny outcome:**
- 5 power-userów, 2 tygodnie
- Każdy używa SFlow normalnie + raz na 2 dni wysyła `sflow-analyze` output
- Po tygodniu 1: ankieta "ile fałszywych toastów zobaczyłeś?" (cel: ≤5/tydzień)
- Po tygodniu 2: ankieta "ile **NOWYCH** skrótów teraz używasz częściej
  niż przed instalacją?" (cel: średnia ≥3 per user)

**Drogi rekrutacji:**
- **Droga A:** Power-userzy z bezpośredniego networku Filipa (najszybsze,
  ale biased)
- **Droga B:** Mała ogłoszenie na Twitter/Mastodon "Looking for beta testers"
  (większa baza, dłuższe)
- **Droga C:** Specyficzne community (Indie Mac, Hacker News show post)

**Rekomendacja:** **A** (5 osób). Bias jest do akceptacji w fazie walidacji
core mechaniki.

**Co dostarczyć beta testerom:**
1. DMG z signowanym buildem
2. Onboarding doc (3 strony: instalacja, permissions, co notować)
3. Mechanizm raportowania (1 email lub Slack channel)
4. Discord/email channel do pytań
5. NDA-free — to nie jest sekret, ale prosić o "nie szerz" przed launch'em

**Decyzja blokująca po betie:**
- Średnia "nowych skrótów" ≥3 → toast UCZY → Faza 2 z planem
- Średnia 1-2 → toast SŁABO uczy → Faza 2 ale z agresywniejszą drogą B
- Średnia 0-1 → toast NIE uczy → **PIVOT**:
  - Droga D (blocker) jako core
  - Albo Droga C (drill) jako oddzielna apka
  - Albo całkowite porzucenie B2C → pivot do B2B (Faza 7 wcześniej)

---

## Inne usprawnienia w ramach Fazy 1

### Permissions check dla Input Monitoring (P-15)

Wbudować w `AppDelegate.checkPermissionsAndStart()`:

```swift
// Po AX check, sprawdź też IM
let imGranted = IOHIDCheckAccess(.listenEvent) == .granted  // lub podobne
if !imGranted {
    showAlert("Input Monitoring required", ..., url: "x-apple.systempreferences:...")
    return
}
```

### Bundled.json update path po SFlow update (P-19)

Modyfikacja `RuleStorage.swift`:

```swift
@discardableResult
static func seedBundledIfMissing() throws -> Bool {
    // ... existing code
    
    // NEW: check version mismatch
    if let userBundle = try? readBundle(at: dest),
       let shippingBundle = try? readBundle(at: src),
       shippingBundle.version > userBundle.version {
        try FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: src, to: dest)
        return true
    }
    return false
}
```

Wymaga: bundled.json dostaje pole `version: Int` na poziomie pliku (nie
per rule). Każdy promote-to-bundled bumpuje.

**ALE** — user_overrides muszą być chronione. Bundled.json overwrite OK,
user_overrides.json NIGDY nie nadpisywany.

### Backend observability (P-21)

**Minimum viable observability:**
- CF Workers Logs dla każdego `/v1/discover` request:
  ```ts
  console.log(JSON.stringify({
    type: "discover", 
    bundleId, 
    appVersion, 
    cacheHit: bool,
    rulesGenerated: N, 
    dropped: M, 
    durationMs: T,
    error: errorStr | null
  }));
  ```
- Cloudflare Analytics dashboard (built-in) dla request counts + errors
- Opcjonalnie: Logflare lub Axiom dla queryable storage (jeśli budżet
  pozwala)

**Decyzja:** zaczynamy od czystego `console.log` + CF Analytics. Logflare
dodajemy gdy zaczniemy mieć >100 requestów/dzień.

### AXKeyShortcutsValue + identifier matching (P-6, P-25) → Sub-cel 1.9

**Awansowane z opcjonalnego do "bramki ważne" po analizie kodu (sesja 2026-05-14).**

Pełna implementacja jest opisana w:
- Sub-cel 1.9 (powyżej) — opis problemu + drogi
- Sesja 4.5 Atomic plan (powyżej) — krok-po-kroku z kodem

Skrót dla szybkiej referencji:
- Layer 0 `AXKeyShortcutsValue` → `ClickWatcher` przed L0.5, `parseAriaShortcut()` parser
- Identifier → `AXSkeletonExtractor` + `LoadedMatch.identifiers?` + `RuleCache.match(identifier:)`
- Backend → `types.ts` opcjonalne `identifiers` + `prompt.ts` instrukcja

---

## Decyzje strategiczne do podjęcia przed startem implementacji

### Decyzja D-1: Threshold quality gate

| Opcja | Co przepuszczamy | Co blokujemy | Rekomendacja |
|---|---|---|---|
| Strict | `high + (menu_bar OR web_docs_official)` | wszystko inne | Bezpieczna, ale tracimy ~30% reguł |
| Balanced | `high (any source)` + `medium + menu_bar` | `medium + web_docs_third_party`, `low *` | **REKOMENDOWANE** |
| Loose | wszystko poza `low + inferred_pattern` | tylko `low + inferred_pattern` | Ryzykowne dla auto-discovered |

**Sugerowana:** Balanced. To daje ~70% reguł aktywnych przy zachowaniu
quality.

### Decyzja D-2: Retry strategy

| Opcja | Backoff | Persistence | Manualny retry | Rekomendacja |
|---|---|---|---|---|
| Aggressive | 30s, 2min, 10min | in-memory | nie | Nie — zatka backend |
| Conservative | 1h, 24h, 7d | disk | tak | Dobre dla servera, słabe UX |
| Balanced | 1min, 5min, 30min, 24h, 7d | disk | tak | **REKOMENDOWANE** |

### Decyzja D-3: Self-healing trigger

| Opcja | Threshold | Częstotliwość check | Rekomendacja |
|---|---|---|---|
| Sensitive | ≥10 missów, ≥2 powt. tytuły | co 6h | Za często, dużo Claude calls |
| Strict | ≥50 missów, ≥5 powt. tytuły | co 7 dni | Za rzadko, długi czas reakcji |
| Balanced | ≥20 missów, ≥3 powt. tytuły | co 24h | **REKOMENDOWANE** |

### Decyzja D-4: False-positive UX

| Opcja | Działanie | UX cost | Rekomendacja |
|---|---|---|---|
| Cmd-klik na toast | Toast otrzymuje mouse events | Wymaga małej modyfikacji | **REKOMENDOWANE** |
| Menu bar item | "✕ Last was wrong" | Mało odkrywalne | Backup, nie primary |
| Settings list | Retrospektywne | Power-user only | Backup, nie primary |

**Sugerowana kombinacja:** Cmd-klik + Settings list (jako "ostatnie 50
toastów" z opcją disable).

### Decyzja D-5: Coverage tier — które apki w bundled.json?

| Opcja | Wielkość bundled.json | Hit-rate na start | Update overhead |
|---|---|---|---|
| Minimal (5 apek) | ~30KB | Słaby first impression | Niski |
| Standard (20 apek) | ~150KB | Dobry | Średni, częsty re-test |
| Maximal (50 apek) | ~400KB | Świetny | Wysoki, dużo do utrzymania |

**Sugerowana:** Standard (20 apek). Maximal czeka na Fazę 6+ gdy mamy
zespół do utrzymania.

---

## Sequence implementacji (sugerowana kolejność)

**Tydzień 1: Quality + Feedback (najszybszy win)**
- Naprawa bugu MenuBarIndex (1.5) — 1-2h
- Quality gate (1.1) — 1 dzień
- False-positive cmd-klik (1.4) — 2 dni
- Tests dla obu — 1 dzień
- → spec `docs/superpowers/specs/2026-05-XX-quality-and-feedback-design.md`

**Tydzień 2: Retry + observability**
- Retry persisted state (1.2) — 2 dni
- Backend console.log + CF Analytics (P-21) — pół dnia
- Bundled.json update path (P-19) — 1 dzień
- → spec osobny lub continuation poprzedniego

**Tydzień 3-4: Self-healing**
- `/v1/refresh` endpoint + backend prompt (1.3) — 2-3 dni
- Client scheduler + miss aggregation (1.3) — 2-3 dni
- → spec osobny

**Równolegle przez cały okres: Coverage eval (1.6)**
- 1 apka dziennie (60min): otwórz → wait discovery → 20 kliknięć → notuj
- Update coverage-report.md
- Iteruj prompt gdy potrzeba
- Po 4 tygodniach: 20 apek done

**Tydzień 4-5: Beta z 3-5 osobami (1.7)**
- Build + DMG
- Onboarding doc
- 2 tygodnie pomiarów
- Ankiety pre/post

**Tydzień 5+: Eksperymenty optional**
- AXKeyShortcutsValue probe (P-6) — 1-2h
- Permissions IM check (P-15) — 1-2h
- Inne nice-to-haves

**TOTAL FAZY 1:** 5-6 tygodni (zamiast 2-4 sugerowanych w roadmap — ta
dokładniejsza ocena jest bardziej realistyczna gdy widzimy zakres).

---

## Acceptance criteria (mierzalne!)

Faza 1 jest skończona gdy:

- [ ] **A-1** Quality gate zaimplementowany (test: świeża discovery
      Figmy zwraca ≥X reguł, ale ≤Y z nich oznaczonych `medium+third_party`
      jest aktywnych)
- [ ] **A-2** Retry z backoff działa (test: symuluj failure, sprawdź że
      retry przychodzi po 1min, 5min, 30min)
- [ ] **A-3** Cmd-klik na toast disable'uje regułę lokalnie (test:
      cmd-klik → drugi klik na ten sam element → brak toasta)
- [ ] **A-4** MenuBarIndex test fixes (test: "Copy link" → no match, nie ⌘C)
- [ ] **A-5** `/v1/refresh` działa (test: POST z miss examples zwraca
      zaktualizowane rules)
- [ ] **A-6** Self-healing scheduler triggeruje refresh (test: wstrzyknij
      ≥20 missów do log → po 24h refresh przychodzi)
- [ ] **A-7** Coverage report dla ≥20 apek z ≥70% hit-rate na 17+ z nich
- [ ] **A-8** Beta z 5 osób: ≥3 raportują "nauczyłem się ≥3 nowych skrótów"
- [ ] **A-9** Bundled.json update path (test: upgrade SFlow → user dostaje
      nowe reguły dla bundled apek)
- [ ] **A-10** Permissions IM check (test: bez IM permission → user widzi
      jasny komunikat)
- [ ] **A-11** Backend observability (test: każdy `/v1/discover` request
      jest w logach z bundleId + duration)

Min próg do exit Fazy 1: **A-1, A-2, A-3, A-4, A-7, A-8** (6 z 11). Reszta
może płynąć do Fazy 2 jeśli czas się kończy.

---

## Risks specyficzne dla Fazy 1

### R-Faza1-1: Beta nie pokaże uczenia (toast nie uczy)

**Mitigacja:** Plan B przed startem Fazy 1: spisać "jak pivot wyglądałby"
dla każdego z wyników bety. Wcześniejsza decyzja = mniejszy szok.

### R-Faza1-2: 20 apek to za mało / za dużo do osiągnięcia w 4 tyg.

**Mitigacja:** Minimum 10 apek z Tier 1+2. Tier 3 może być "kontynuacja
w Fazie 2".

### R-Faza1-3: Prompt iteration eats more time than expected

**Mitigacja:** Set time-box per apka (60min). Jeśli po 3 iteracjach nadal
<70% → flaguj jako "needs deeper work" i odłóż. Nie blokuj postępu pozostałych.

### R-Faza1-4: False-positive UX (cmd-klik) ma side effects

**Mitigacja:** Feature flag w settings "Disable cmd-click feedback". Beta-testerzy
mogą wyłączyć jeśli problemowe. Fallback: Settings list.

### R-Faza1-5: Self-healing prompt halucynuje "improvements" które
psują dobre reguły

**Mitigacja:** `/v1/refresh` zachowuje stare reguły jako fallback w
`cache/<bundle>.json.bak`. Klient ma "Revert to previous version" w Settings.
Audit log każdej zmiany.

---

## Wnioski

### Co możemy zrobić bardzo szybko (tydzień 1)

Najwyższa wartość per czas:
1. **Bug fix MenuBarIndex** (1-2h) — natychmiast eliminuje główny vector
   false positives
2. **Quality gate** (1 dzień) — natychmiast poprawia auto-discovery quality
3. **Cmd-klik feedback** (2 dni) — daje nam dane o które apki są
   problematyczne

Te 3 razem (~1 tydzień) dają **ogromny skok jakości**.

### Czego się nie spieszyć

- **AXKeyShortcutsValue probe** — jeśli wyjdzie pusto, marnujemy 2h.
  Może być w Fazie 2.
- **Backend full observability** (Logflare/Axiom) — wystarczy CF Logs do
  100 reqs/dzień.
- **Tier 3 apki** — robić po sprzęcie Tier 1+2.

### Co MUSI być przed Fazą 2

1. Quality gate + retry + false-positive feedback działają u beta
2. 17+ z 20 apek osiąga ≥70% hit rate
3. Beta z 5 osób potwierdza że toast uczy (>=3 average)

Bez tego nie ma sensu budować dróg B i E — będziemy budować na zepsutej
podstawie.

---

*Status: kompletny audyt Fazy 1. Następny krok: napisać spec dla pierwszego
sub-celu (quality gate + false-positive feedback) i zacząć implementację.
Sugerowany plik specu: `docs/superpowers/specs/2026-05-XX-quality-and-feedback-design.md`.*
