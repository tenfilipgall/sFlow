# SFlow — Audyt Fazy 1: Jakość pokrycia w skali

> Idealny stan po Fazie 1, problemy do rozwiązania (z odniesieniami do
> `audit-phase-0.md`), sub-cele z opcjami implementacji, decyzje, kryteria
> akceptacji. Spisany 2026-05-13.

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

### AXKeyShortcutsValue eksperyment (P-6)

**Małe zadanie (1-2h):**
1. W `ClickWatcher.handleMouseDown`, przed Layer 0.5 dodaj:
   ```swift
   var ksRef: AnyObject?
   AXUIElementCopyAttributeValue(current, "AXKeyShortcutsValue" as CFString, &ksRef)
   if let ks = ksRef as? String, let parsed = parseAriaShortcut(ks) {
       emit(...)
       return
   }
   ```
2. Implementuj `parseAriaShortcut`: "Meta+K" → `["meta", "k"]`
3. Test na Gmail (web), Notion (znane że eksperymentują), Discord
4. Jeśli żadna z testowanych nie ma — wyłącz feature flagą i wrócimy do
   tego w Fazie 2

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
