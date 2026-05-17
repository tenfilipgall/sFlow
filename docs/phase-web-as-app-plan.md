# Plan: Web-as-app + Semantic Intent Library

> **Strategiczny plan rozszerzenia SFlow na strony www w przeglądarce.**
> Status: **ZAPLANOWANE**, czeka na zamknięcie Fazy 1.5 + Beta (Faza 1.7).
> Spisane: 2026-05-17. Autor: Filip + AI (ultrathink session).
> Adresuje: P-42 (web-as-app), Sub-cel 1.19, oraz nową kategorię globalnych
> reguł semantic-intent (NIE ma jeszcze numeru P-X / sub-celu, ten plan to
> wprowadza).
>
> **Ważne — kolejność:** ten plan nie jest do startu teraz. Najpierw
> dopracowujemy desktop apps (Faza 1.5 + 1.6 + 1.7 Beta). Web zaczyna się
> dopiero po becie z czystym sygnałem „toast po akcji uczy lub nie uczy".
> Sekwencja świętości — patrz product-vision sekcja 0.4.

---

## 0. TL;DR (3 zdania)

Dziś każda strona www w przeglądarce (Gmail, Linear web, Notion web, GitHub)
dostaje `bundleId="ai.perplexity.comet"` — **0% pokrycia web shortcutów** mimo
że power-user spędza tam 4h dziennie. Plan rozwiązania ma dwie warstwy:
**(1) Web-as-app** — czytamy URL z drzewa AX, używamy pseudo-bundleId
`web:gmail.com`, per-domain reguły; oraz **(2) Semantic Intent Library** —
kluczowa innowacja: 30-50 generic intentów (compose / reply / search / bold /
...) z multi-language wariantami i confidence-rated candidate shortcuts,
działających dla apek których SFlow nigdy nie widział. Cel: **~85-90% pokrycia
web po dwóch tygodniach pracy, vs 0% dziś**.

---

## 1. Dlaczego desktop najpierw (sanity-check kolejności)

Pięć powodów żeby NIE startować webu przed Betą desktop:

1. **Sekwencja świętości (vision 0.4).** Nie budujesz Fazy 2 zanim Faza 1 ma
   spełnione kryteria akceptacji. Web = otwarcie ogromnego nowego frontu.
2. **Beta sygnał musi być czysty.** Jeśli puścisz desktop+web naraz i 5 znajomych
   powie „toasty mnie nie uczą" — nie wiesz która warstwa zawiodła. Desktop solo
   = jedna zmienna. To bezpośrednia weryfikacja hipotezy z vision 5a.
3. **Web odziedziczy bugi desktop.** Bug w matching engine (jak P-26..P-30)
   propaguje na wszystkie web apki. Najpierw stabilna baza.
4. **Semantic Intents to ryzykowna idea** (false-positive risk wprost wpływa na
   user trust). Lepiej testować na stabilnej kodbazie niż razem ze świeżym
   konceptem WebAppResolver.
5. **Lekcje z desktop transferują się 1:1.** Layer 0.6, TooltipObserver,
   single-key mode — wszystko działa na tym samym AX framework. Każda godzina
   dopracowywania desktop = darmowa nauka dla web.

---

## 2. Prerequisites — kryteria gotowości DESKTOP zanim startujemy web

Ten plan **nie startuje** dopóki nie są spełnione poniższe (mierzalnie):

- [ ] **Sub-cel 1.6** — ≥10 verified apek desktop z hit-rate ≥70% i FP <15%
      (zniżone z 20 dla beta MVP per roadmap)
- [ ] **Sub-cel 1.7** — Beta z 3-5 znajomymi przez ≥2 tygodnie + ankieta
      pre/post
- [ ] **Sub-cel 1.13 (P-33)** — synthetic Claude self-eval per regule wdrożony
      (krytyczne dla skali jakości web reguł)
- [ ] **Sub-cel 1.20 (P-43)** — i18n / lokalizacja reguł działa dla desktop PL
      (mechanizm potrzebny też dla web)
- [ ] **Beta sygnał** rozstrzygnięty: jeśli „toast nie uczy" → robimy drogę B
      (curriculum) najpierw, web odkładamy o miesiąc; jeśli „uczy" → web staje
      się następną logiczną falą.

**Jeśli wszystkie ✅ → start Sesji A poniżej.**

---

## 3. Cel mierzalny

Po ukończeniu wszystkich Sesji A-D:

- ≥**50%** web apek deterministic-coverage (zielony toast, false-positive <5%)
- +**25-35%** experimental-coverage (żółty toast z `?`, false-positive <15%)
- ≥**85%** ogólne pokrycie web na hold-out zestawie 15 apek
- ≥**6** seeded web apek w `bundled.json` (Gmail, Linear web, GitHub, Notion
  web, Slack web, Google Calendar web)
- ≥**30** generic intentów w `bundled-web-intents.json`
- ≥**75%** semantic intent rules ma confidence ≥0.6 (z self-eval)
- Hold-out test: 10 web apek których SFlow „nie zna" → ≥40% hit rate first-touch

---

## 4. Architektura 7-warstwowa uniwersalności

Warstwy od najbezpieczniejszej (zero false-positive) do najryzykowniejszej:

| # | Warstwa | Co | Pokrycie | Status dziś |
|---|---|---|---|---|
| **W1** | `aria-keyshortcuts` via AX | Strona ustawia `aria-keyshortcuts="c"` → Chromium wystawia jako AX atrybut → SFlow czyta deterministic | +5-15% | nieznane (probe potrzebny) |
| **W2** | Inline shortcut hints w label | Element ma title `"Compose (C)"` → parsuj | — | mamy (Layer 0.6) |
| **W3** | TooltipObserver w DOM | Apka renderuje tooltip → mamy go w AX tree | +30-50% | mamy (Sesja B) |
| **W4** | **Semantic Intent Library** ⭐ | 30-50 generic intentów (compose/reply/...) z confidence-rated candidates | +20-40% | **NOWE — Sesja D** |
| **W5** | Cross-domain transfer | (zawarte w W4 jako candidates) | — | — |
| **W6** | LLM per-element on-demand | Cache miss → Claude w tle, drugi raz instant | +long tail | po becie |
| **W7** | Crowdsource z keystroke | Click→key correlation = uczenie | continuous | Faza 2+ |

**Teoretyczny sufit przy W1-W4 sumarycznie: ~85-90% pokrycia web bez per-app
bundled.**

---

## 5. Semantic Intent Library — kluczowa innowacja (W4)

### 5.1. Co to jest

Plik `bundled-web-intents.json` zawierający 30-50 generic intentów. Każdy
intent to:

```json
{
  "intent": "compose_message",
  "match": {
    "role": "AXButton",
    "labelContainsAny": [
      "compose", "new email", "new message", "write",
      "napisz", "nowa wiadomość", "redaguj",
      "verfassen", "neue nachricht",
      "nouveau message", "rédiger",
      "redactar", "comporre"
    ]
  },
  "candidates": [
    {"keys": ["c"],   "confidence": 0.70, "evidence": "Gmail, Hey, FastMail, Yahoo"},
    {"keys": ["n"],   "confidence": 0.20, "evidence": "Outlook web, ProtonMail"},
    {"keys": ["meta","n"], "confidence": 0.10, "evidence": "Skiff"}
  ],
  "scope": "web:*",
  "scopeExclude": ["web:slack.com", "web:discord.com"]
}
```

**Inne planowane intenty (lista wstępna do generacji):**
`reply` (r), `reply_all` (a), `forward` (f), `archive` (e), `delete` (#/Del),
`search_global` (⌘K vs /), `search_inpage` (⌘F), `bold` (⌘B), `italic` (⌘I),
`underline` (⌘U), `link` (⌘K), `send_message` (⌘↩), `settings` (,), `help` (?),
`next_item` (j vs ↓), `prev_item` (k vs ↑), `new_window`, `close_tab` (⌘W),
`refresh` (⌘R), `go_back`, `copy/paste/undo/redo` (standard), `star` (s),
`mark_read/unread`, `mute`, `snooze`, `move_to`, `label_as`, `important`,
`open_item` (o), `goto_inbox` (g→i), `goto_sent` (g→t), `goto_drafts` (g→d),
`spam` (!), `select_all` (⌘a), `toggle_sidebar`, `zoom_in` (⌘+)...

### 5.2. Skąd biorą się intenty

**Źródła danych dla generacji:**
1. **333 reguł starej extension** (`Shortcut Flow/packages/extension/src/content/slowWayRules.ts`) — gotowy katalog akcji z 29 domen × multi-language
2. **Obecny `bundled.json` SFlow** — desktop ground truth (Slack, Notion, Linear, Cursor, Obsidian, Terminal, Claude)
3. **Claude `web_search`** — best practices dla web app keyboard shortcuts patterns
4. **Filip review** — manual filtering dla polskich wariantów, intent naming, edge cases

### 5.3. Pipeline generacji

```
[stara extension 333 reguł]  ──┐
[bundled.json SFlow ~150 reguł]──┼─► Claude (gen pass)
[web_search top 20 web apek]   ──┘    ↓
                                bundled-web-intents-raw.json
                                      ↓
                                Claude (self-eval pass)
                                      ↓
                                each intent scored 1-5
                                      ↓
                                ≥3 → bundled-web-intents.json
                                <3 → rejected.json + Filip review
                                      ↓
                                Hold-out test (10 apek)
                                      ↓
                                hit-rate ≥40% → deploy
                                hit-rate <40% → rework prompt
```

### 5.4. Test hold-out (decyzyjny moment przed deploymentem)

**Hold-out set: 10 web apek których NIE używaliśmy do generacji:**
Hey, FastMail, ProtonMail, Skiff, Pitch, Coda, Cron, Vercel dashboard,
Sentry, PostHog.

**Acceptance criteria dla deploymentu W4:**
- Hit rate ≥40% first-touch (semantic intent matchuje co najmniej 4/10 typowych
  akcji per apka)
- False-positive rate <15% (rzadko strzelamy złym skrótem)
- Polish lokalizacja działa na ≥3 apkach z polskim UI

**Decyzja po hold-out:**
- ≥40% hit, FP <15% → **deploy całość**
- 25-40% hit, FP <15% → deploy tylko intentów confidence ≥0.7 (mniej coverage,
  więcej trust)
- <25% lub FP ≥15% → **W4 nie działa**, zostaje per-domain bundled + auto-discovery

---

## 6. Dwustopniowy toast UI (confidence-based)

Krytyczne dla user trust:

| Confidence | Toast wizualizacja | Co user widzi |
|---|---|---|
| ≥0.7 lub W1-W3 deterministic | **Zielony** (standard), bez ikony | „⌘K Compose" |
| 0.5-0.7 | **Żółty** z ikoną `~` (tilde) | „~⌘K Compose · zgaduję" + tooltip „SFlow zgaduje na bazie podobnych apek — cmd-klik jeśli błędnie" |
| <0.5 | nie pokazujemy | — |

**Dlaczego dwustopniowy:** false-positive psuje trust mocniej niż brak toasta
uczy. Bez wizualnego sygnału „zgaduję" user traci wiarę po 3-4 nieudanych
strzałach i odinstalowuje. Z wizualnym sygnałem — user wie kiedy ufać, kiedy
weryfikować.

**Feedback loop:** cmd-klik na żółtym toaście → ratowuje confidence danego
intentu dla danej domeny (lokalnie). Po 3 cmd-klikach lokalnie wyłączamy ten
intent dla tej domeny.

---

## 7. Sekwencja sesji A-D (po zamknięciu prerequisites)

### Sesja A — Probe + decyzja architektoniczna (~3h)

**Cel:** zweryfikować empirycznie 3 hipotezy zanim piszemy kod.

1. Rozszerzyć `scripts/sflow-probe-ax-url.swift` (już istnieje, e8e51b4) o
   dodatkowy dump `AXKeyShortcuts` na każdym elemencie pod kursorem
2. Filip uruchamia probe na:
   - Comet + Gmail (test Hipotezy 1: AXURL dostępne)
   - Comet + Linear web (test Hipotezy 2: czy AXKeyShortcuts faktycznie
     istnieje na popularnych web apkach)
   - Comet + Notion web (test Hipotezy 3: czy TooltipObserver łapie tooltipy
     Notion web podobnie do desktop Notion)
3. Decyzja na bazie wyników:
   - **AXURL działa** → idziemy Hipotezą 1 (czyste, deterministyczne)
   - **AXURL puste** → Hipoteza 2 (parsing domeny z tytułu okna)
   - **AXKeyShortcuts wystawiane** → wzmacniamy Layer 0 (już istniejący) o
     dump per element pod kursorem
   - **TooltipObserver łapie Gmail** → mniej manual portu potrzebne

**Output:** notatka decyzyjna w `docs/web-as-app-probe-results.md` z konkretnymi
liczbami (np. „AXURL = `https://mail.google.com/u/0/`, 3 elementów z
AXKeyShortcuts w drzewie Gmaila").

### Sesja B — `WebAppResolver.swift` + integracja (~4h)

**Cel:** SFlow rozpoznaje pseudo-bundleId `web:gmail.com` zamiast
`ai.perplexity.comet`.

Pliki:
- `SFlow/WebAppResolver.swift` (NEW, ~150 LOC, TDD)
  - Input: `AXUIElement` aplikacji + frontmost window
  - Output: `web:<host>` albo `nil`
  - White-list browser bundleIds: Comet, Chrome, Safari, Arc, Brave, Firefox
  - Strip subdomen: `mail.google.com` → `gmail.com`, `app.slack.com` → `slack.com`
  - Edge cases: `localhost`, `file://`, `chrome://`, `about:blank`
- `SFlow/ClickWatcher.swift` (modyfikacja, ~30 LOC)
  - Wczesny check w `handleMouseDown`: jeśli WebAppResolver daje `web:X` →
    użyj jako efektywny bundleId
- `SFlow/RuleCache.swift` (modyfikacja, ~20 LOC)
  - Cascade match: `web:gmail.com` (primary) → `ai.perplexity.comet` (fallback
    dla browser-level skrótów typu ⌘T new tab)
- `SFlow/ShortcutEvent.swift` (modyfikacja)
  - Dodaje pole `webHost: String?` w events.jsonl dla telemetrii

Testy: ~20 testów (URL parsing, subdomain stripping, edge cases, cascade match,
events.jsonl format).

### Sesja C — Gmail manual port (~3h, **warunkowa po Sesji A**)

**Trigger:** wykonujemy TYLKO jeśli Sesja A pokazała że TooltipObserver NIE
łapie Gmaila wystarczająco dobrze. Jeśli W3 załatwia ≥60% Gmail przycisków
sama z siebie → **pomijamy Sesję C** i idziemy od razu do D.

Pliki:
- `scripts/migrate-extension-rules.js` (NEW, ~80 LOC, jednorazowy)
  - Czyta `Shortcut Flow/packages/extension/src/content/slowWayRules.ts`,
    sekcja Gmail (linie 331-1534)
  - Filtr: bierz tylko reguły gdzie ≥1 selector to `aria-label` (te
    portują się 1:1 na AX)
  - Output: ~60 reguł w formacie SFlow `bundled.json` pod kluczem
    `web:gmail.com`
- `SFlow/Resources/bundled.json` (modyfikacja) — wklejka 60 reguł
- Manual review wszystkich 60 (Filip + AI) — czy multi-language warianty
  zachowane (PL/EN/DE/FR), czy keys poprawnie zmapowane

### Sesja D — Semantic Intent Library Eksperyment ⭐ (~8-10h)

**Najważniejszy strategiczny krok w całym planie.** Decyzyjny.

**D.1 (~2h) — Claude generation:**
- `scripts/gen-semantic-intents.swift` (NEW, ~100 LOC, jednorazowy)
- Input: stara extension data + bundled.json + web_search
- Prompt: „Generate 30-50 generic web intents covering common actions
  (compose/reply/search/bold/...) with multi-language labels (EN/PL/DE/FR/ES)
  and confidence-rated candidate shortcuts. Each candidate must cite evidence
  (which apps use this shortcut for this intent)."
- Output: `bundled-web-intents-raw.json`

**D.2 (~1h) — Self-eval:**
- Drugi Claude call score'uje każdy intent 1-5
- Score 4-5 → on by default (confidence ≥0.6)
- Score 3 → experimental (yellow toast)
- Score <3 → rejected, dump do `intents-rejected.json` dla Filipa review

**D.3 (~2h) — Hold-out test:**
- Manual eval na 10 hold-out apkach (Hey, FastMail, ProtonMail, Skiff, Pitch,
  Coda, Cron, Vercel dashboard, Sentry, PostHog)
- Dla każdej: Filip wykonuje 10-15 typowych akcji, notuje (hit / miss / wrong)
- Output: `docs/semantic-intents-holdout-eval.md` z hit-rate per intent

**D.4 (~3h) — Layer 0.7 integration:**
- `SFlow/SemanticIntentMatcher.swift` (NEW, ~200 LOC, TDD, ~25 testów)
- `SFlow/ClickWatcher.swift` — wstawić Layer 0.7 między L0.6 i L1
- `SFlow/ToastView.swift` — dwustopniowy UI (zielony vs żółty z `~`)
- Telemetria: pole `semanticConfidence` w events.jsonl

**D.5 (~1h) — UAT i decyzja go/no-go:**
- Filip puszcza Layer 0.7 na 3-5 prawdziwych apek przez kilka dni
- Mierzy hit rate i FP rate w events.jsonl
- Decyzja:
  - ≥40% hit, FP <15% → **deploy całość**, ogłaszamy w product-vision
  - 25-40% hit → deploy tylko intentów score 4-5
  - <25% lub FP ≥15% → **rollback**, W4 wraca do laboratoryjnej fazy

---

## 8. Ryzyka i mitigations

| # | Ryzyko | Prawdopodobieństwo | Mitigation |
|---|---|---|---|
| R1 | Aria-label w Chromium nie idzie do AXTitle (nie sprawdzone empirycznie) | średnie | Probe Sesja A rozstrzyga przed jakimkolwiek kodem |
| R2 | Semantic intents false-positive rate >15% — psuje user trust | wysokie | Dwustopniowy toast UI (żółty `~` dla experimental) + cmd-klik feedback + auto-disable po 3 cmd-klikach na domenę |
| R3 | Lokalizacja PL/DE/FR/ES za wąska — japoński/węgierski miss | średnie | Start z 5 językami (ICP Filipa), rozszerzaj per-apka gdy beta-tester z innego kraju zgłosi |
| R4 | Skróty zmieniają się over time (Gmail update zmienia `e` na `y` dla archive) | niskie ale long-term | Telemetria: intent z >20% cmd-klików tygodniowo → auto-degradowany do experimental |
| R5 | Web crowdsource Sesja C (oryginalna z desktop) nie skala dla web bo każdy URL inny | wysokie | Świadomie **NIE** robimy crowdsource web w tym planie — czekamy na Phase 2.7 |
| R6 | Browser auto-update łamie AXWebArea AXURL | niskie | Smoke test w CI: hold-out apka raz na 2 tygodnie, alert jeśli AXURL nagle puste |
| R7 | Zatkanie SFlow przez „web wszędzie" — toasty co kilka sekund podczas web browsing | średnie | Per-tab rate limit (max 1 toast / 10s na tym samym `web:X`); dodać do W1-W4 jak działa dziś dla desktop |

---

## 9. Co świadomie NIE robimy (out-of-scope)

- **Crowdsource backend `/v1/discovered` dla web** — czekamy do Phase 2.7
  (po becie + walidacji desktop crowdsource)
- **Per-page scope** (np. `web:notion.so/<page-id>`) — domain wystarczy
- **Iframes** (embedded YouTube w Notion) — edge case, pomijamy
- **W6 (LLM per-element on-demand)** — drogo + 2s latency, po becie
- **W7 (keystroke correlation crowdsource)** — Phase 2+
- **Native browser extension fallback** — Filip miał już raz extension,
  porzucił dla natywnej apki, nie wracamy

---

## 10. Acceptance criteria — kiedy „Faza Web done"

- [ ] Sub-cel 1.19 (P-42) Web-as-app → 🟢
- [ ] Nowy sub-cel (TBD numer, „Semantic Intent Library W4") → 🟢
- [ ] `WebAppResolver.swift` + testy w main branch
- [ ] `bundled-web-intents.json` w `Resources/` z ≥30 intentami
- [ ] Hold-out eval `docs/semantic-intents-holdout-eval.md` zlinkowany w
      roadmap.md session log
- [ ] ≥6 seeded web apek w bundled.json (`web:gmail.com`, `web:linear.app`,
      `web:github.com`, `web:notion.so`, `web:slack.com`, `web:calendar.google.com`)
- [ ] Beta-testerzy używali web feature przez ≥1 tydzień, ankieta:
      „SFlow uczył mnie skrótów web?" — średnia >3.5/5

---

## 11. Otwarte decyzje (do rozstrzygnięcia przed startem Sesji A)

1. **Naming experimental toast.** Propozycja: ikona `~` (tilde) + żółty kolor.
   Alternatywy: `?` (znak zapytania), `≈` (approx), kolor pomarańczowy zamiast
   żółtego. **Filip decyduje przed Sesją D.4.**
2. **Confidence threshold default.** Domyślnie ≥0.6 dla green, 0.5-0.6 dla
   yellow. Alternatywy: ≥0.7 (bardziej konserwatywne — mniej toastów ale wyższy
   trust). **Filip decyduje przed Sesją D.4.**
3. **Multi-language scope dla W4.** Start z EN/PL/DE/FR/ES. Alternatywy:
   tylko EN/PL (mniej praca dla AI), albo +IT/PT/JA. **Filip decyduje przed
   Sesją D.1.**
4. **Gmail manual port — robimy czy pomijamy?** Decyzja po Sesji A. Kryterium:
   jeśli TooltipObserver+W4 łapią ≥60% Gmail samodzielnie → pomiń manual port.
5. **Czy wciągamy dane z PRAWDZIWYCH użytkowników do generacji intentów?**
   Tj. czy bierzemy events.jsonl od beta-testerów jako dodatkowy input dla
   Claude? Plus: realne dane. Minus: privacy concerns. **Filip decyduje po
   becie.**

---

## 12. Powiązania z istniejącymi planami i fazami

**Gdzie wpisać to w roadmap.md po decyzji „start":**

Propozycja: nowa **Faza 1.8** (po 1.7 Beta, przed 2.0 Infrastructure) — „Web
Coverage + Semantic Intents". Trwa ~2-3 tygodnie. Wymaga zamkniętej bety.

**Sub-cele do dodania (po decyzji startu):**
- 1.19 Web-as-app (P-42) — już planowany, ten plan to konkretyzuje
- 1.30 (NOWY) — Semantic Intent Library (W4)
- 1.31 (NOWY) — Confidence-based toast UI

**Powiązane istniejące sub-cele:**
- 1.13 (P-33) synthetic self-eval — prerequisite (mechanizm score'owania
  semantic intentów)
- 1.20 (P-43) i18n — prerequisite (mechanizm multi-language matchowania)
- 1.15 część 2 Sesja C (crowdsource desktop) — może dostarczyć patternów
  re-usable dla W7 (web crowdsource Phase 2.7)

**Powiązane dokumenty:**
- `product-vision.md` — sekcja 6 (rekomendacja drogi B) — web rozszerza
  drogę B na większą powierzchnię nauki
- `audit-phase-1.5.md` — sub-cele 1.19 i 1.20 wymienione, dodatkowe sub-cele
  doprecyzowane w tym planie
- `audit-phase-0.md` — P-42 (web-as-app) i P-43 (i18n) wymienione, status
  pozostaje ⬜ do startu

**Powiązane assety zewnętrzne:**
- `/Users/filip/Claude/Projects/Apps/Shortcut Flow/packages/extension/src/content/slowWayRules.ts`
  — 333 reguł × 29 domen z multi-language wariantami. Input dla generacji
  Semantic Intents. **Nie tracimy tego źródła — to roczna praca Filipa.**
- `scripts/sflow-probe-ax-url.swift` (e8e51b4) — już istnieje, czeka na
  Sesję A.

---

## 13. Następne kroki

**Teraz:** zostawiamy ten plan zapisany. Filip wraca do dopracowywania
desktop (Fazy 1.5 + 1.6 + 1.7 Beta).

**Kiedy prerequisites zielone:** odpalamy Sesję A (probe + decyzja
architektoniczna). Plan w tym pliku jest startem — może wymagać aktualizacji
po wynikach probe'a.

**Po Sesji D (decyzja go/no-go):** jeśli W4 działa → dopisanie sukcesu do
product-vision sekcja 3 jako USP („SFlow działa na każdej apce którą
otworzysz, nawet jeśli nikt jej wcześniej nie eval'ował"). Marketing
differentiator.

---

*Status pliku: roboczy plan strategiczny. Aktualizacja: po zamknięciu Bety
desktop (Sub-cel 1.7) lub po istotnej zmianie kontekstu.*
