# Plan — Sesja 9b: Ukierunkowany web research w backend prompt (P-32)

> **Status:** DRAFT, czeka na zaplanowanie. Adresuje P-32 (audit-phase-0.md) +
> dokończenie Sub-cel 1.12 (audit-phase-1.md).
>
> **Czas szacunkowy:** ~3-4h (zmiana promptu + testy + reseed 5 bundled apek +
> deploy backendu).
>
> **Pre-requisites:** brak twardych, ale optymalnie po Sesji 9a (P-34 streaming
> ✅ done) i przed Sesją 10 (synthetic self-eval).
>
> **Adresuje:** P-32 web research nieukierunkowany, P-35 timeout verification
> dla DisplayTuner, Sub-cel 1.12 dokończenie.

---

## 1. Problem (skrót)

Dziś `backend/src/prompt.ts` mówi Claude'owi (linia 60):

> *"Use the web_search tool to verify shortcuts that are not visible in the menu bar (e.g. hidden shortcuts like Slack ⌘K)."*

To jedno zdanie. Claude sam decyduje **kiedy, jak, czego szukać**. Empiryczne
obserwacje (P-32 w audycie):

- **Generic queries**: Claude często wyszukuje "<appName> keyboard shortcuts" —
  trafia w wiki/forum, ale **bez per-element queries** dla konkretnych przycisków
  z UI skeleton.
- **Brak ranking'u źródeł**: Claude może wziąć cheatsheet z 2018 roku przed
  oficjalnymi docs.
- **Trace gubienia ścieżki**: na wielkich apkach (Android Studio: 93 reguł,
  patrz P-34) Claude poświęca web_search budget (max 4) na **pierwsze 4 generic
  queries** i już go nie ma na hidden shortcuts.

**Konsekwencja:** Niska confidence na auto-discovered rules → quality gate (P-1)
odrzuca je → user widzi tylko menu_bar shortcuts → SFlow gubi hidden shortcuts
(⌘K w Slack, /-menu w Notion, etc).

---

## 2. Cele sesji

1. **Strukturyzowany 2-fazowy research** w promptie:
   - Faza 1: 1 generic query `"{appName} keyboard shortcuts cheatsheet"` →
     znajduje officialne źródło (preferuje URL `{appName}.com/shortcuts`,
     `{appName}.com/help`, `support.{appName}.com`)
   - Faza 2: per-element queries DLA elementów których nie ma w menu_bar
     ale **są** w UI skeleton (`compose-button`, `quick-switcher`, etc.) —
     `"{appName} <element name> keyboard shortcut"`
2. **Source ranking**: officialne docs > cheatsheets > forum/blog.
   Po znalezieniu official → **zatrzymuje web_search** (oszczędza budget).
3. **Deterministyczny budget**: hard cap 1 generic + 3 targeted = 4 use.
4. **Empiryczne verification dla DisplayTuner (P-35)**: po deploycie reseed
   `com.benderbureau.displaytuner` i sprawdzić czy timeout znika.
5. **Reseed 5 bundled apek** nowym promptem (Slack, Obsidian, Linear, Cursor,
   Terminal/Notion/Claude) — porównać przed/po jakości.

---

## 3. Zmiany w `backend/src/prompt.ts`

### 3.1. System prompt — nowa sekcja "RESEARCH PROTOCOL"

Dodać po sekcji "Rules" w `buildSystemPrompt()`:

```
RESEARCH PROTOCOL (web_search tool):
- Phase 1 (mandatory, 1 query): Search "{appName} keyboard shortcuts site:{appName}.com OR site:support.{appName}.com OR site:help.{appName}.com". If you get an official source (URL contains the app's own domain), READ it via web_fetch and DO NOT issue more generic queries.
- Phase 1 fallback: If no official source, run ONE additional query "{appName} keyboard shortcuts cheatsheet" — accept top result from a reputable source (Notion, GitHub wiki, dedicated cheatsheet sites like keyboardshortcuts.com).
- Phase 2 (optional, up to 3 queries): For elements in the UI skeleton whose shortcut is NOT covered by Phase 1 sources, run targeted "{appName} {element-name} keyboard shortcut" queries. Reserve these for high-value buttons (compose, send, reply, search, save, undo) — do not waste budget on minor elements.
- Source priority for confidence:
  - Phase 1 official source → confidence "high", source "web_docs_official"
  - Phase 1 reputable third-party → confidence "medium", source "web_docs_third_party"
  - Phase 2 targeted query result → confidence determined by the URL (official → high, third-party → medium)
- Hard budget: 4 web_search uses total. After 4, generate rules from menu_bar + UI skeleton + your training knowledge only (no more searches).
```

### 3.2. User prompt — explicit element list

Zmienić linie 60-61 z generic instrukcji na **lista konkretnych elementów**:

```typescript
export function buildUserPrompt(req: DiscoverRequest): string {
  const menuLines = req.menuBar
    .map((m) => `  ${m.path.join(" > ")}${m.shortcut ? ` [${m.shortcut}]` : ""}`)
    .join("\n");
  const skeletonLines = req.uiSkeleton
    .map((s) => `  ${s.role}: "${s.title}"${s.identifier ? ` [id=${s.identifier}]` : ""}`)
    .join("\n");

  // List skeleton items NOT covered by menu bar (heuristic: title not in menu paths)
  const menuTitles = new Set(
    req.menuBar.flatMap((m) => m.path.map((p) => p.toLowerCase()))
  );
  const uncoveredSkeleton = req.uiSkeleton
    .filter((s) => s.title && !menuTitles.has(s.title.toLowerCase()))
    .slice(0, 10); // cap at 10 high-value buttons
  const uncoveredLines = uncoveredSkeleton.length > 0
    ? uncoveredSkeleton.map((s) => `  - ${s.title}`).join("\n")
    : "  (none)";

  return `App: ${req.appName} (${req.bundleId} v${req.appVersion})

Menu bar:
${menuLines || "  (empty)"}

UI skeleton (interactive elements):
${skeletonLines || "  (empty)"}

UI elements NOT in menu bar (these likely have hidden shortcuts — prioritize for Phase 2 targeted research):
${uncoveredLines}

Generate the JSON rule list. Follow the RESEARCH PROTOCOL strictly. Always favor shortcuts from the menu bar as "high" confidence with source "menu_bar".`;
}
```

### 3.3. Niezmienione

- Few-shot examples — bez zmian.
- Schema rules (DISJOINT TITLES, HOTKEY-SUFFIX VARIANTS, IDENTIFIERS, TITLE
  VARIANTS) — bez zmian.

---

## 4. Test-driven plan

### 4.1. Backend tests

**Nowy plik:** `backend/tests/prompt.test.ts` (rozszerzyć istniejący jeśli jest).

Tests:
1. `buildSystemPrompt()` zawiera frazę "RESEARCH PROTOCOL" — sanity check że
   sekcja jest w outputcie
2. `buildSystemPrompt()` zawiera frazę "Hard budget: 4 web_search uses total"
3. `buildUserPrompt(req)` z menu_bar empty, skeleton 3 elem → output zawiera
   sekcję "UI elements NOT in menu bar" z wszystkimi 3 elementami
4. `buildUserPrompt(req)` z menu_bar pokrywającym wszystkie skeleton → output
   zawiera sekcję "UI elements NOT in menu bar: (none)"
5. `buildUserPrompt(req)` z skeleton 15 elementów (cap 10) → output ma tylko
   pierwsze 10

### 4.2. End-to-end test (po deploy)

Nie automated — manual przez `./scripts/sflow-reseed`. Sprawdzić:
- Output reguł zawiera **per-element** sourced shortcuts (np. Slack Compose
  ma jasno "menu_bar" jako source — bo jest w menu — ale Quick Switcher ma
  "web_docs_official" z `slack.com/help/...`)
- Confidence distribution: więcej "high" niż przed, mniej "low"
- Liczba reguł: nie spadła znacząco (cel: ≥90% poprzedniej liczby per apka)

---

## 5. Reseed plan (po deploy)

Sekwencja:
1. `wrangler deploy` (CZEKAJ NA EXPLICIT FILIPA, patrz product-vision §0.8)
2. `./scripts/sflow-reseed com.tinyspeck.slackmacgap` → porównać avg titles
   per rule vs poprzedni
3. `./scripts/sflow-reseed md.obsidian` → ditto
4. `./scripts/sflow-reseed com.linear.LinearMac` → ditto
5. `./scripts/sflow-reseed com.todesktop.230313mzl4w4u92` (Cursor) → ditto
6. `./scripts/sflow-reseed com.apple.Terminal` → ditto
7. Diff `bundled.json` rules count, source distribution
8. **Verify P-35**: `./scripts/sflow-reseed com.benderbureau.displaytuner` —
   nie powinien timeoutować (90s+); jeśli nie ma backend logów → P-35 ✅
9. Promote do `bundled.json` przez `./scripts/promote-to-bundled.sh`

---

## 6. Acceptance criteria

- [ ] System prompt zawiera nową sekcję RESEARCH PROTOCOL
- [ ] User prompt zawiera listę "UI elements NOT in menu bar"
- [ ] Wszystkie backend testy passing (50+)
- [ ] Po reseedzie 5 bundled apek:
  - Avg titles per rule: ≥3.5 (jak dziś)
  - Avg sources: ≥30% "high" + "menu_bar"
  - Nowe hidden shortcuts pojawiają się w outputcie (sprawdzić: Slack ⌘K
    ma source "menu_bar" lub "web_docs_official", Notion ⌘P ma cokolwiek
    sourcowanego)
- [ ] P-35 (DisplayTuner timeout) verified: status 🔵 → 🟢 albo 🔵 → 🔴 (jeśli
  dalej timeoutuje, znaczy że to inny problem niż streaming)
- [ ] Backend deployed (po confirmacji Filipa)

---

## 7. Co NIE robimy w tej sesji

- **Web research dla user-uploadowanych apek** (1-off discovery przez Apps
  tab) — wszystko działa już automatycznie, sesja 9b zmienia tylko prompt
  rozumiany przez Claude'a
- **Cache invalidation** — istniejące cache pliki nadal valid, reseed je
  nadpisuje
- **Schema changes** w types.ts — dodajemy tekst do promptu, schemat reguł
  bez zmian
- **Sesja 10 (synthetic self-eval / P-33)** — to osobna sesja, NIE łączymy

---

## 8. Ryzyka i mitigacje

### Ryzyko 1: Claude ignoruje protokół, robi 4 generic queries

**Diagnoza:** Claude ma tendencję ignorować dyrektywy gdy są ukryte w długim
prompcie. RESEARCH PROTOCOL będzie ~250 słów w prompcie — to dużo.

**Mitigacja:** dodać explicit instruction na koniec user promptu (linia 60):
*"Before producing rules, summarize your research plan: which queries you will
run and what budget remains. Stop after 4 web_search uses."*

To wymusza meta-cognitive checkpoint, który empirycznie podnosi compliance.

### Ryzyko 2: "UI elements NOT in menu bar" heuristic gubi elementy

`menuTitles.has(s.title.toLowerCase())` to płaski lookup. Element AX "Compose"
nie pasuje do menu path `["Message", "New Message"]`, więc trafia do listy
uncovered. To prawidłowo — ale **może być za szerokie**, listujemy też
elementy które są w menu ale pod inną nazwą.

**Mitigacja:** **zostawić** szeroki filtr, Claude sam ranguje co jest
high-value. Cap 10 elementów chroni przed eksplozją. Jeśli okaże się że
gubimy reguły — zwiększyć cap do 20 w przyszłej iteracji.

### Ryzyko 3: P-35 (DisplayTuner timeout) nie jest streaming-related

**Diagnoza:** P-34 streaming fix prawdopodobnie pomógł, ale `com.benderbureau.displaytuner`
może mieć inny problem (e.g. brak any UI skeleton, anti-AX defense).

**Mitigacja:** sprawdzić w `events.jsonl` lub `attempted.json` jaki był ostatni
`DiscoveryFailureReason` dla DisplayTuner. Jeśli `emptySkeleton` → fix to
NIE streaming, to AX permissions / app design.

### Ryzyko 4: Reseed zmienia istniejące reguły dla bundled apek

**Diagnoza:** mając nowe sourced shortcuts, Claude może wygenerować różne
keys dla tych samych akcji niż w obecnym bundled.json.

**Mitigacja:** **diff przed promote**. `promote-to-bundled.sh` musi mieć
manual review (już ma). Filip checkuje że nie ma regresji — zwłaszcza dla
Slack i Obsidian które były w v1.1.1 dawno zweryfikowane.

---

## 9. Statusy do zaktualizowania po sesji

- `audit-phase-0.md`:
  - P-32 ⬜ → 🟢 (jeśli reseed pokazuje per-element research)
  - P-35 🔵 → 🟢 (jeśli DisplayTuner przeszedł) lub 🔴 (jeśli nie, eskalować)
- `audit-phase-1.md`:
  - Sub-cel 1.12 🔵 → 🟢
  - Execution sequence: Sesja 9b ⬜ → 🟢
- `roadmap.md`: Session log + decyzja czy promote'ujemy nowe bundled.json

---

## 10. Pre-flight check (przed startem)

- [ ] Backend tests w `backend/tests/` przechodzą (50/50)
- [ ] `wrangler --version` działa, mam dostęp do `sflow-rules.shortcutflow.workers.dev`
- [ ] `ANTHROPIC_API_KEY` jest aktywny i ma >$5 budget (reseed 5 apek to
      ~$0.05 totally)
- [ ] Mam kopię obecnego `bundled.json` (`git status` clean lub git stash)
      żeby cofnąć regresję jeśli reseed pogorszy
- [ ] Filip explicit yes na `wrangler deploy` (per product-vision §0.8)

---

*Plan napisany przez AI 2026-05-16. Czeka na review.*
