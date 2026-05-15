# Plan Sesji 10 — Synthetic Claude self-eval per regule (P-33, sub-cel 1.13)

**Data:** 2026-05-15
**Adresuje:** P-33 (audit-phase-0.md), sub-cel 1.13 (audit-phase-1.md)
**Status:** ⬜ pending — do realizacji po sesjach A/B/C/D (TooltipObserver) i T1 (video eval)
**Szacunkowy czas:** ~1 dzień roboczy (4–6h focused work)

> Plan czysto markdownowy. ZERO kodu — implementacja pisana w sesji 10 z TDD.

---

## 1. Po co to robimy (analogia jak dla 12-latka)

Dziś Claude działa jak pierwszy uczeń który robi zadanie domowe: generuje listę
skrótów dla nowej apki. Nikt tego nie sprawdza, dopóki Filip ręcznie nie obkliknie
apki. To zajmuje **godzinę na apkę**. Przy 4 apkach: ok. Przy 100 apkach: niemożliwe.

Robimy **drugiego ucznia (tańszego)**, który po pierwszym sprawdza każde zadanie
i wystawia ocenę 1–5: "ta reguła brzmi sensownie" albo "ta jest podejrzana, może
powinno być co innego". Reguły z oceną poniżej 3 dostają stempel **"eksperymentalne"**
i klient ich domyślnie nie pokazuje — bo wolimy pominąć podpowiedź niż pokazać złą.

To **bramka jakości skalowalna na nieograniczoną liczbę apek**, bez angażowania
Filipa. Jest to gating issue dla launchu z hasłem "SFlow działa dla każdej apki"
(patrz product-vision.md sekcja 5e2).

---

## 2. Rationale (jak to się ma do roadmap/vision)

**Z roadmap.md Faza 1.5.6:** "Synthetic Claude self-eval per regule — drugi
call po generacji reguł, score 1-5 + alternative suggestion. Score <3 → flag
experimental."

**Z product-vision.md sekcja 5e2:** Bez automatycznego mechanizmu quality eval
SFlow przy 100 supportowanych apkach **uczy userów halucynacji Claude'a** na
nieznanej skali. Razem z P-4 (false-positive feedback od userów) tworzy parę
"pre-flight + post-flight" — synthetic eval łapie błędy zanim trafią do usera,
false-positive feedback łapie te które prześliznęły się przez eval.

**Z audit-phase-1.md sub-cel 1.13:** Acceptance — 5 bundled apek z field `score`
per regule, manual sanity check że `score=5` brzmi poprawnie a `score≤2` jest
oczywiście błędne.

**Z RuleCache quality gate (sesja 4, sub-cel 1.1):** Klient już ma mechanizm
filtrowania low-confidence rules (`showExperimental: false` default). Nowy
field `experimental: true` honorujemy tym samym kodem — minimalna zmiana
klienta.

---

## 3. Decyzje do podjęcia przed startem (Filipie, wybierz)

### Decyzja D-1: Który model robi eval?

| Opcja | Plus | Minus | Koszt na regule |
|---|---|---|---|
| **A. claude-haiku-4-5** (Recommended) | Najtańsze, szybkie | Może być za słaby (dawać score=4 wszystkiemu) | ~$0.0005 |
| B. claude-sonnet-4-6 (ten sam co generator) | Spójna jakość | 10× droższe (~$0.005) | ~$0.005 |
| C. GPT-4o-mini (Anthropic cross-check) | Niezależny "drugi mózg" | Wymaga nowego API key, dodatkowe konto | ~$0.0003 |

**Rekomendacja:** **A — Haiku-4-5.** Eval to prosty rating task (semantic match +
"czy to standardowy skrót?"), Haiku poradzi sobie. Jeśli Risk 1 (Haiku za słaby —
patrz §7) okaże się prawdziwy, możemy w sesji 11 przerzucić się na Sonnet. Koszt
B = $30 na 100 apek vs $3 dla A — różnica niewarta gdy eval może być iterowany.

### Decyzja D-2: Per-rule call czy batch call?

| Opcja | Plus | Minus |
|---|---|---|
| **A. Per-rule call (~30 calli per apka)** | Każda regule ma własne reasoning, łatwo debug | 30× latencja serial; trzeba parallel |
| B. **Batch call (1 call dla całej apki)** (Recommended) | 1 call = ~$0.001 całość, niska latencja | Trudniej debugować pojedyncze reguły |
| C. Hybrid — batch dla score, per-rule tylko dla low-score (alternative suggestion) | Tanio + szczegółowe alternatywy | 2 ścieżki w kodzie |

**Rekomendacja:** **B — batch call.** Przy generacji już mamy ~90s latencji
(Android Studio streaming). Dodanie 30 serial calli to dalej 30–60s. Batch call
z prompt "oceń te 30 reguł" zwraca array score'ów w ~3s. Debugowanie pojedynczej
reguły jest możliwe ad-hoc przez ręczne odpalenie evala na cache/<bundleId>.json.

### Decyzja D-3: Threshold dla "experimental" flag

| Opcja | Threshold | % reguł flagowanych (szacunek dla Slack) | Plus | Minus |
|---|---|---|---|---|
| **A. Score < 3 = experimental** (Recommended) | strict | ~20% | Konserwatywne, mniej halucynacji u userów | Tracimy część edge-case'owych ale poprawnych reguł |
| B. Score < 2 = experimental | loose | ~5% | Prawie nic nie filtrujemy | Słaby filtr — po co eval skoro nic nie blokuje |
| C. Score < 4 = experimental | extra-strict | ~50% | Maksymalna ostrożność | Ucinamy też reguły "ok ale niepewne" które są lepsze niż nic |

**Rekomendacja:** **A — score < 3.** Zgodne z audit-phase-1.md sub-cel 1.13.
Ten sam threshold który już rekomendujemy w roadmap. Można iterować po pierwszym
reseedzie 5 bundled apek (sanity check) — jeśli Filip uzna że za dużo reguł
flagowanych, podnieść do <2.

### Decyzja D-4: Kiedy uruchamiać eval — przy każdym discovery czy tylko fresh?

| Opcja | Plus | Minus |
|---|---|---|
| **A. Tylko gdy generujemy nowe reguły (cache miss albo ?fresh=1)** (Recommended) | Jednorazowy koszt, cache'owany | Stare cached reguły nie dostają score |
| B. Także retroactive na istniejące cache | Wszystkie reguły mają score | Wymaga migracji + reseedu wszystkich bundled |
| C. Tylko on-demand z CLI script | Maksymalna kontrola | Filip musi pamiętać uruchomić |

**Rekomendacja:** **A — przy generacji.** Reguły są niezmienne aż do następnego
reseedu, więc score też. Bundled apki dostaną score przy następnym sesji reseedu
(sesja 9c lub równoważnik). Cache *.json automatycznie po wygaśnięciu TTL (90d)
albo `?fresh=1` z DiscoveryService.

### Decyzja D-5: Co z polem `alternative_keys`?

| Opcja | Plus | Minus |
|---|---|---|
| **A. Logować do backend observability, nie używać klient-side** (Recommended) | Sygnał do iteracji prompta, brak zmiany klienta | Filip musi czytać logi żeby skorzystać |
| B. Auto-zamiana `keys` na `alternative_keys` jeśli score >= 4 | Reguły "naprawiają się" automatycznie | Ryzyko — eval może być błędny i pogorszyć regułę |
| C. Pokazywać oba toasty (oryginalny + alternative) | User decyduje | UX chaos, podwójne toasty |

**Rekomendacja:** **A — log only.** Eval jest *świeży*, możemy mu nie ufać do
auto-rewrite reguł. Logujemy `alternative_keys` w response (P-21 observability),
po 2 tygodniach Filip patrzy w logi i decyduje czy iterować prompt generation
ręcznie. Bezpieczna ścieżka.

---

## 4. Files to touch (pliki dotykane w tej sesji)

| Akcja | Plik | Zmiana |
|---|---|---|
| New | `backend/src/eval.ts` | Cała logika eval call do Haiku — funkcja `evaluateRules(rules, appName)` zwracająca array `{score, reason, alternative_keys}` |
| Modify | `backend/src/claude.ts` | Po `generateRules()` wołamy `evaluateRules()`, mergujemy `score` i `experimental` do rule objects |
| Modify | `backend/src/types.ts` | Dodaj `score?: number` i `experimental?: boolean` do `RuleSchema`; Zod walidacja |
| Modify | `backend/src/handlers/discover.ts` | Przekaż score+experimental do response (już idą bo `RuleSchema` to obsłuży automatycznie) |
| Modify | `backend/test/eval.test.ts` | Nowe testy — kalibracja Haiku, edge cases |
| Modify | `SFlow/LoadedRule.swift` | Dodaj opcjonalne pola `score: Int?` i `experimental: Bool?` w `Codable` |
| Modify | `SFlow/RuleCache.swift` | W `match()` filtruj `rule.experimental == true && !showExperimental` |
| Modify | `SFlowTests/RuleCacheTests.swift` | Test: experimental rule ukryta domyślnie, widoczna po toggle |
| Modify | `bundled.json` (po reseedzie 5 apek) | Bundled apki dostają `score` per regule |
| Modify | `docs/audit-phase-0.md` | P-33 status ⬜ → 🟡 (in progress) → 🟢 po sesji |
| Modify | `docs/audit-phase-1.md` | Sub-cel 1.13 status ⬜ → 🟢 |

**Pliki NIETYKANE w tej sesji** (lock — inne terminale):
- `ClickWatcher.swift`, `TooltipObserver.swift`, `ShortcutRules.swift`,
  `AXSkeletonExtractor.swift`, `scripts/sflow-video-*`

---

## 5. Task breakdown (TDD-style, atomic)

Każde zadanie ma 1–3 commity. Numeracja determinuje kolejność.

### Task 1 — Kalibracja Haiku eval prompt (manual research, brak kodu)

- Wybierz 10 reguł known-good z `bundled.json` (Slack ⌘K, ⌘N, ⌘F, Obsidian ⌘O,
  Cursor ⌘P, etc.)
- Wybierz 10 reguł known-bad (manually wymyślone halucynacje: "Compose ⌘Q",
  "Settings ⌘W", absurdalne keys+title pairs)
- Ręcznie odpal prompt z §6 na Haiku przez Anthropic Console
- Sprawdź: czy known-good średnio dostają score ≥4? Czy known-bad średnio ≤2?
- **Acceptance:** distribution rozjeżdża się (good vs bad). Jeśli wszystko 4,
  Haiku za słaby → patrz Risk 1, fallback na Sonnet (D-1 opcja B)

**Czas:** 30 min. Output: jedna notatka markdown z wynikami kalibracji w
`docs/superpowers/plans/2026-05-15-synthetic-self-eval.md` jako Appendix A.

### Task 2 — Test `evaluateRules()` failing (TDD red)

- Plik: `backend/test/eval.test.ts`
- Test 1: dostaje 1 known-good regułę → zwraca `{score: ≥4, experimental: false}`
- Test 2: dostaje 1 known-bad regułę → zwraca `{score: ≤2, experimental: true}`
- Test 3: dostaje pustą tablicę → zwraca pustą tablicę
- Mock Anthropic SDK fetch — fixture response z hardcoded score'ami
- Test fails (no impl)

**Acceptance:** 3 testy czerwone, `npm test` exit code != 0

### Task 3 — Implement `evaluateRules()` (TDD green)

- Plik: `backend/src/eval.ts` (new)
- Funkcja `evaluateRules(rules, appName, apiKey)`: batch call do Haiku z prompt z §6
- Parsuje JSON response (`{evaluations: [{idx, score, reason, alt}]}`)
- Mapuje na rule objects: `{ ...rule, score, experimental: score < 3 }`
- Error handling: jeśli call fails → wszystkie rules dostają `score: 3, experimental: false` (neutralne, nie blokujemy)
- Test zielony

**Acceptance:** 3 testy z Task 2 zielone

### Task 4 — Schema update `types.ts` + zod walidacja

- Plik: `backend/src/types.ts`
- Dodaj `score: z.number().min(1).max(5).optional()`
- Dodaj `experimental: z.boolean().optional()`
- Zaktualizuj dependent types
- Test: `RuleSchema.parse({...minimum_rule, score: 4})` works; `{score: 6}` rzuca

**Acceptance:** unit test schema passes

### Task 5 — Integracja w `claude.ts`

- Po `parseRulesJSON()` wywołaj `evaluateRules(rules, appName)`
- Merge score+experimental do każdego rule
- Log do console: `{ type: "eval", bundleId, total: N, experimental: M, avgScore: X }`
- Test E2E (z mockiem Anthropic SDK): generate + eval → response zawiera score
  per regule

**Acceptance:** integration test passes

### Task 6 — Klient: `LoadedRule` Codable

- Plik: `SFlow/LoadedRule.swift`
- Dodaj `score: Int?`, `experimental: Bool?` jako optional w Codable
- Zaktualizuj `coverage-report.md` lub equivalent jeśli istnieje (lista pól)
- Backward compat: stare `bundled.json` bez tych pól nadal działa (optional)

**Acceptance:** kompiluje się, nie łamie istniejących testów (198 powinno
nadal przechodzić)

### Task 7 — Klient: `RuleCache.match()` honoruje `experimental`

- Plik: `SFlow/RuleCache.swift`
- W `match()` po check `!showExperimental && rule.confidence == .low` dodać
  analogiczny check `!showExperimental && rule.experimental == true`
- Symmetric do existing quality gate

**Acceptance:** patrz Task 8

### Task 8 — Testy klient-side

- Plik: `SFlowTests/RuleCacheTests.swift`
- Test 1: rule with `experimental: true` jest ukryta gdy `showExperimental: false`
- Test 2: ta sama rule pokazana gdy `showExperimental: true`
- Test 3: rule bez pola `experimental` (legacy) działa jak normalna
- Test 4: `experimental: true` w bundled.json (nie tylko cache/) też działa

**Acceptance:** 4 testy zielone, łącznie 202 testy passing

### Task 9 — Reseed 5 bundled apek z eval

- Apki: Slack, Obsidian, Linear, Cursor, Notion (lub te które są aktualnie
  bundled — sprawdzić `bundled.json` przed startem)
- Per apka: `./scripts/sflow-reseed <bundleId>` (wywołuje backend, dostaje
  rules + score)
- Manual review: czy `experimental: true` jest na regułach które Filip uznałby
  za "niepewne"?
- Promote do `bundled.json`
- Commit "feat: bundled apki przeseed'owane z synthetic eval"

**Acceptance:** 5 bundled apek ma `score` per regule w `bundled.json`,
distribution oczekiwana (większość 4-5, ~10-20% <3)

### Task 10 — Update audit + roadmap + session log

- `audit-phase-0.md` P-33 → 🟢 closed
- `audit-phase-1.md` sub-cel 1.13 → 🟢 done
- `roadmap.md` Session log entry "Sesja 10: Synthetic eval"
- Commit "docs: session 10 log + status update P-33/1.13"

**Acceptance:** wszystkie 3 dokumenty zaktualizowane, status zsynchronizowany

---

## 6. Prompt template do eval (do dopracowania w Task 1)

> Nie jest to kod tylko draft promtu. Finalna wersja w `backend/src/eval.ts`.

**System:** "Jesteś evaluatorem reguł skrótów klawiszowych dla aplikacji macOS.
Twoje zadanie: ocenić czy reguła trafnie wiąże tytuł elementu UI ze skrótem
klawiszowym standardowym dla danej apki. Bądź konserwatywny — gdy nie jesteś
pewien, daj score niższe."

**User template:**
```
Apka: {appName} (bundleId: {bundleId})

Oceń następujące reguły. Dla każdej zwróć score 1-5:
- 5 = pewny match (skrót standardowy dla tej apki + title pasuje)
- 4 = prawdopodobnie poprawny
- 3 = niepewny (możliwe ale nieoczywiste)
- 2 = wątpliwy (skrót nieznany dla tej apki lub title niepasujący)
- 1 = błędny (halucynacja, nie istniejący skrót)

Reguły:
1. titles=['Compose'], keys=['meta','n'], source='menu_bar'
2. titles=['Settings'], keys=['meta','comma'], source='inferred_pattern'
...

Zwróć JSON:
{
  "evaluations": [
    { "idx": 1, "score": 5, "reason": "...", "alternative_keys": null },
    { "idx": 2, "score": 3, "reason": "...", "alternative_keys": ["meta","shift","comma"] }
  ]
}
```

---

## 7. Acceptance criteria (mierzalne)

- [ ] 5 bundled apek z `score` field per regule w `bundled.json` po reseedzie
- [ ] Distribution score'ów na bundled.json: średnia ≥ 3.8, ≥80% reguł ≥ 4,
      <30% reguł flagowanych jako experimental
- [ ] Manual sanity check: dla 10 losowych reguł z `experimental: true` Filip
      sprawdza ręcznie → ≥7/10 to faktycznie reguły "niepewne" (precision ≥70%)
- [ ] 202 testy passing (198 baseline + 4 nowe RuleCacheTests + 4 backend tests)
- [ ] Backend log w CF: każdy `/v1/discover` loguje `{eval: {total, experimental, avgScore}}`
- [ ] Koszt: <$1 łączny dla 5 reseedów (Haiku ~$0.005 per apka)

---

## 8. Risks

### Risk 1 — Haiku za słaby do eval (score=4 dla wszystkiego)

**Symptom:** distribution score'ów ma std-dev <0.5, wszystkie ≥4. Niezależnie od
known-bad reguł, Haiku ich nie wyłapuje.

**Mitigacja:**
- Task 1 (kalibracja) ma to wyłapać przed implementacją
- Fallback: switch na Sonnet (decyzja D-1 → B), koszt rośnie do $30 na 100 apek
- Alternatywa: stronger prompt z explicit examples known-bad w system message

**Probability:** ŚREDNIA. Haiku zazwyczaj radzi sobie z rating tasks ale tu
jest specyficzny domain (znajomość skrótów per-apka).

### Risk 2 — Eval rozjeżdża się z reality

**Symptom:** Po 2 tygodniach user feedback (P-4 false positives) pokazuje że
reguły z score=5 też są błędne, a niektóre experimental są w rzeczywistości OK.

**Mitigacja:**
- Faza 2: korelujemy `score` z real `false_positive_rate` po userach
- Jeśli korelacja słaba (<0.5) → eval jest theatrical, wyłączamy/rebuild
- Mierzymy przez analyzer w sesji 12+ (post-beta)

**Probability:** NISKA-ŚREDNIA. Eval może być theatrically dobry ale praktycznie
neutralny — to ryzyko strukturalne.

### Risk 3 — Latencja generacji rośnie

**Symptom:** Discovery time z 90s (Android Studio streaming) idzie do 120s+.
Klient timeout'uje (`DiscoveryClient.swift`).

**Mitigacja:**
- Batch call dla całej apki (decyzja D-2) — dodaje ~3s
- Klient timeout już zwiększony do 120s w sesji 9a — wystarczy
- Jeśli problem: parallel eval podczas streaming generation (zaawansowane, do sesji 11)

**Probability:** NISKA. Eval to ~3s, generation to dominanta.

### Risk 4 — Backward compat dla starych cache/*.json

**Symptom:** Klient z nowym `RuleCache.swift` ładuje stare cache (bez score)
i nie wie jak je traktować.

**Mitigacja:**
- `score: Int?` jako optional — nil traktujemy jak `score: nil → experimental: false`
- Stara reguła jest zawsze pokazywana, jak teraz
- Migracja "soft" — nowe cache nadpisuje stare po 90d TTL albo `?fresh=1`

**Probability:** NISKA. Codable optional handles this.

### Risk 5 — Filip nie ma czasu na manual sanity check (Acceptance §7 punkt 3)

**Symptom:** Sesja 10 zamknięta bez precision check, nie wiemy czy eval ma
sens.

**Mitigacja:**
- Acceptance #3 jest **blocking** dla zamknięcia sesji
- Jeśli Filip nie ma czasu, ZOSTAWIAMY sesję jako 🟡 i czekamy na sanity check
- Zalecane: zrobić sanity check w sesji 10 zaraz po Task 9 (15 min)

**Probability:** ŚREDNIA. Real-life constraint.

---

## 9. Out of scope (NIE robimy w tej sesji)

- ❌ Eval retroactive na istniejące cache (decyzja D-4 opcja B) — separatna sesja jeśli potrzebne
- ❌ Auto-rewrite reguł na `alternative_keys` (decyzja D-5 opcja B) — zbyt ryzykowne
- ❌ Korelacja `score` z false-positive rate od userów — wymaga real userów (Faza 2)
- ❌ Eval prompt tuning na bazie >10 apek — wystarczy 5 bundled na początek
- ❌ UI w Settings dla `showExperimental` toggle — już istnieje z sesji 4 (sub-cel 1.1)

---

## 10. Po sesji 10 — co dalej

Po zamknięciu sesji 10:
- **Sesja 11** (sub-cel 1.3, P-8): self-healing scheduler. Plan: `2026-05-15-self-healing-scheduler.md`
- **P-21 dashboard:** spec gotowy w `2026-05-15-backend-observability.md`, implementacja po C
- Faza 2: jeśli beta z 3-5 osobami pokaże dane, weryfikujemy korelację score
  vs real false-positive rate (Risk 2)

---

## Appendix A — Kalibracja Haiku (do uzupełnienia w Task 1)

> Wypełniane podczas Task 1 sesji 10.

**Known-good reguły (oczekiwany score ≥ 4):**
1. Slack: titles=['Search'], keys=['meta','k']
2. Obsidian: titles=['Open quick switcher'], keys=['meta','o']
3. ...

**Known-bad reguły (oczekiwany score ≤ 2):**
1. Slack: titles=['Send message'], keys=['meta','q'] (Q = quit, nieprawda)
2. Obsidian: titles=['Settings'], keys=['meta','w'] (W = close window)
3. ...

**Wyniki kalibracji:**
- Mean score known-good: ___
- Mean score known-bad: ___
- Std-dev: ___
- Decyzja: Haiku OK / fallback na Sonnet / iterować prompt

---

*Plan v1.0. Po sesji A/B/C/D + T1 zaktualizować jeśli coś z tych sesji wymusi
zmiany w schemacie (np. score per layer).*
