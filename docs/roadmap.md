# SFlow — roadmap budowy (drogi B + E z dodatkiem A)

> Plan kierunkowy. Dokument ma odpowiedzieć: **co po kolei robimy, żeby dojść
> z obecnego stanu do produktu który uczy userów skrótów i da się sprzedawać**.
>
> Dokument decyzyjny — nie spec implementacyjny. Każda faza zostanie potem
> rozpisana na osobny spec + plan (jak v1.0, v1.1).
>
> **Druga wersja** (2026-05-13 wieczór) — po sprawdzeniu kodu okazało się że
> auto-discovery jest już zbudowane, a "tryb cichy" toasta sam się rozwiązuje.
> Skrócone Fazy 1 i 3.

---

## Założenie kierunkowe

Z `product-vision.md`: budujemy **drogę B (personalizowana nauka)** jako core
produktu. **Droga E (raport/heatmap)** jako naturalne uzupełnienie. **Droga A
(intro toast + onboarding)** jako warstwa wejścia — pierwsze 1–2 tygodnie usera.

**Sekwencja jest święta.** Nie buduj B zanim nie zadziała Faza 1 (jakość
pokrycia). Nie buduj E zanim nie ma danych z B. Nie sprzedaj nikomu nic
zanim nie ma A+B+E zaprojektowanych jako jedna historia.

---

## Proces ciągły (rituals i workflow)

> **AI: Przeczytaj tę sekcję na początku każdej sesji. Stosuj się.**

### A. Czytanie kontekstu na start każdej sesji

Pierwsza czynność każdej nowej sesji = **przeczytać 4 pliki równolegle**:

```
docs/product-vision.md       ← zasady współpracy + wizja produktu
docs/roadmap.md              ← plan fazowy + ta sekcja
docs/audit-phase-0.md        ← stan kodu + lista problemów (P-X)
docs/audit-phase-1.md        ← sub-cele Fazy 1 + statusy
```

Cel: AI ma wiedzieć **na jakim etapie jesteśmy**, **co zrobione**, **co
następne**, zanim cokolwiek zaproponuje. Bez tego ryzykuje że poleci robić
rzecz która już jest zrobiona albo poza obecnym scope'em.

### B. End-of-session protocol (po każdej sesji)

Kiedy sesja kończy się ze zmianami w kodzie, AI MUSI:

1. **Zaktualizować statusy** w `audit-phase-0.md` (problemy P-X) oraz
   `audit-phase-1.md` (sub-cele). Symbole:
   - ⬜ pending (nie zaczęte)
   - 🟡 in-progress (zaczęte, niedokończone — opisać czego brakuje)
   - 🔵 partial (działa częściowo — opisać co działa a co nie)
   - 🟢 done (zrobione + zweryfikowane)
   - 🔴 regression (cofnięte z poprzedniego statusu — opisać dlaczego)

2. **Dopisać wpis do "Session log"** (sekcja niżej) — reverse-chronological,
   najnowszy na górze.

3. **Scommitować razem** z kodem jednym dodatkowym commitem o nazwie
   `docs: session log + status update [v.X.Y.Z]` lub w osobnym jeśli
   commit kodu już istnieje.

### C. Video-based quality eval (okresowo)

Patrz `docs/audit-phase-1.md` Sub-cel 1.8. AI **proaktywnie sugeruje**
Filipowi nagranie 60-90s screen recordingu jeśli:

- Minęła >1 sesja od ostatniego video evalu
- Wprowadzono zmianę w `backend/src/prompt.ts` lub `dedup.ts`
- Reseedowano apkę w `bundled.json`

Filip nagrywa MP4 (CleanShot), wrzuca do repo (gitignored), AI uruchamia
analizę klatek (Swift+AVFoundation), raportuje:

- ✅ toasty które wystrzeliły poprawnie
- ❌ kliknięcia bez toasta (chybienia) — porównać z `events.jsonl`
- ⚠️ toasty z błędnymi keys/hintami (jeśli widać hover-tooltip w klatce)

Wyniki idą do `docs/coverage-report.md` (jeśli istnieje) i jako wpis
w session log.

### D. Rekomendacje + decyzje

Zasady w `product-vision.md` sekcja 0.2-0.3. Skrót:

- Każda rekomendacja uzasadniona przez cel z roadmap albo decyzję z vision
- Pytania zawsze multi-choice (`AskUserQuestion`) z rekomendacją w pierwszej opcji
- Tłumacz jak 12-latkowi (analogie, polski, technika w nawiasach)

### E. Co AI robi samodzielnie vs co pyta

Patrz `product-vision.md` sekcje 0.7-0.8. Najważniejsze:

- **Robi sam:** edycje, testy, commit do main, reseed, eksperymenty
- **Pyta:** deploy backendu, kasowanie historii, zmiany cenowe,
  rzeczy poza scope obecnego sub-celu

---

## Session log

> **Reverse-chronological — najnowsza sesja na górze.**
> AI dodaje nową sekcję po każdej sesji ze zmianami w kodzie.

### 2026-05-14 (wieczór) — Sesja 2: Bug squashing

**Co:** 3 bugi naprawione: (1) MenuBarIndex.lookup — zmiana kierunku substring + próg 5 znaków, naprawiono 2 failing testy + 2 nowe. (2) Input Monitoring permission check w AppDelegate — `CGPreflightListenEventAccess()` + alert z linkiem. (3) Structured JSON log w `/v1/discover` — `bundleId`, `cacheHit`, `rulesGenerated`, `durationMs` w każdym request.

**Dlaczego:** P-5 (fałszywy ⌘C dla "Copy link") był głównym wektorem false-positives. P-15 (milczący brak IM permission) powodował że user nie wiedział dlaczego nic nie działa. P-21 (brak logów) — lataliśmy ślepo.

**Wpływ:** Wyeliminowany główny wektor false-positives w Layer 3. Onboarding nie wymaga zgadywania co jest nie tak z permissions. Backend zaczyna zbierać dane.

**Commits:** `3a960be` (MenuBarIndex), `22ec8e2` (Input Monitoring), `5844285` (backend logs)

### 2026-05-14 (wieczór) — Sesja 1: Sweet wins

**Co:** 3 zadania: (1) Re-seed Terminal/Notion/Claude z v1.1.1 promptem — Terminal avg 3.4, Notion avg 4.3, Claude avg 4.4 wariantów per regule (było 1.05–2.13). (2) Fix P-23 w `dedup.ts` — deduplikacja tytułów within-rule + test. (3) Nowe skrypty `sflow-video-eval` + `sflow-video-extract.swift` (droga C sub-cel 1.8).

**Dlaczego:** Najszybszy ROI: 3 apki w bundled.json miały stary v1.0 prompt z minimalną liczbą wariantów. Teraz wszystkie 5 bundled apek jest na v1.1.1.

**Wpływ:** bundled.json wyrównany (wszystkie apki 3-5 wariantów per regule). P-23 zamknięty. Narzędzie do analizy wideo gotowe.

**Commits:** `0f14e92` (reseed), `28dd50b` (P-23 fix), `c2b171f` (video-eval)

### 2026-05-14 — Process & context rules dodane (ta sesja)

**Co:** Dodano sekcję "Proces ciągły" do roadmap, "Jak współpracujemy"
do product-vision (sekcja 0), sub-cel 1.8 do audit-phase-1 (video eval),
mechanizm status-tracking dla problemów P-X i sub-celów.

**Dlaczego:** Filip zauważył że bez tego każda sesja AI zaczyna się od
zera, zapomina poprzedni kontekst, czasem buduje rzeczy już zrobione.
Plus: video eval z poprzedniej sesji okazał się bardzo wartościowy
(wykrył Slack search ⌘F vs ⌘G bug) — warto sformalizować.

**Wpływ:** Każda następna sesja zaczyna się od **wymuszonej dawki kontekstu**.
AI musi czytać 4 pliki na start. Decyzje są łatwiejsze (rekomendacje
z uzasadnieniem). Postęp jest mierzalny (statusy w audytach).

**Commits:** *(ten — uzupełnij SHA przy commit'cie)*

### 2026-05-13 (wieczór) — v1.1.1: wrong-toast fix + audyt dokumentacji

**Co:** 4 fixy: prompt anti-overlap, backend dedup, Swift hotkey-suffix
tolerance, reseed Slack/Obsidian. Plus update 3 dokumentów (roadmap,
audyty) z poprawkami fakt'ualnymi.

**Dlaczego:** Wideo Filipa pokazało wrong toast (Slack search bar
hover ⌘G, toast pokazał ⌘F). Diagnoza: 2 reguły Claude'a z nakładającymi
się tytułami, hint+keys przemieszane. Plus odkryto pattern "Edit message E"
(Electron hotkey suffix w AX title).

**Wpływ:** Sub-cel 1.1 (quality gate) częściowo zrealizowany (backend dedup).
Sub-cel 1.5 (MenuBarIndex bug) NADAL pending — to inny matcher. Bundled.json
ma teraz Slack+Obsidian w v1.1.1 promtem (avg 4+ wariantów), pozostałe 3
apki w starym.

**Commits:** `c2c690c` (prompt), `72a4bb2` (dedup), `1f8891c` (Swift),
`cea1828` (reseed), `ede9c97` (docs).

### 2026-05-13 (popołudnie) — v1.1: miss log + better prompt + auto-reseed

**Co:** 21 commitów. EventLogger.logMiss + Analyzer + sflow-analyze CLI.
Backend prompt v1.1 z 3-5 wariantami tytułów + few-shot examples. Forward-compat
`version: 1` field. Auto-reseeder (`SFlow --reseed-all`) z backup'em.

**Dlaczego:** v1.0 manual eval pokazał ~50% hit rate. Cel: 70%+ przez
multi-variant tytuły. Plus narzędzie do mierzenia (miss log) żeby
v1.2 mógł być data-driven.

**Wpływ:** Hit rate po reseedzie ~99% w testach na Slack/Obsidian.
Linear/Cursor skipowane (not installed). Pre-existing 3 MenuBarIndex test
failures pozostały (nie z tej sesji).

**Commits:** Tag `pre-v1.1-misslog-prompt-2026-05-13` na początku + 21 feat
commitów. Główne: `ee9bd1c` (EventLogger), `556fe58` (ClickWatcher logMiss),
`1f0bc12` (Analyzer), `55e3e36` (prompt v1.1), `5666ddb` (reseed result).

---

## Faza 0: Co już mamy — pełna inwentaryzacja

Zaktualizowana lista (sprawdzona w kodzie, nie z pamięci):

### Detekcja i matching ✅

- `ClickWatcher` — CGEventTap nasłuchuje kliknięć (`SFlow/ClickWatcher.swift`)
- 4 warstwy reguł L0.5–L4 (LLM bundled, tooltip auto-parse, menu bar fuzzy,
  universal heuristics)
- `MatchConfidence` + filtrowanie wg confidence
- AXSkeletonExtractor — zbiera atrybuty AX z drzewa elementu

### LLM rules engine ✅

- Backend Cloudflare Worker (`backend/`) z endpointem `/v1/discover`
- Claude API generuje reguły dla **dowolnej** apki (menu bar + skeleton → rules)
- KV cache na backendzie (per bundleId+version)
- Production URL: `https://sflow-rules.shortcutflow.workers.dev`
- `SFlow/Resources/bundled.json` zaszyty z 5 apkami: **Slack, Obsidian** (regenerowane w v1.1.1 promtem, 3–5 wariantów tytułów per regule, average 4+), **Terminal, Notion, Claude Desktop** (regenerowane starym v1.0 promtem, ~1.05–2.13 wariantów per regule — do re-seedu w pierwszej kolejności). Linear i Cursor są na liście `Reseeder.verifiedApps`, ale w praktyce nie są zainstalowane na maszynie deweloperskiej, więc nigdy nie trafiły do bundled.

### Auto-discovery flow ✅ (to było moje wcześniejsze przegapienie)

- `DiscoveryService.observeAppActivation()` nasłuchuje
  `NSWorkspace.didActivateApplicationNotification`
- Gdy user aktywuje apkę bez reguł → automatyczny POST do `/v1/discover`
- Menu bar pokazuje **"✨ Learning [AppName]…"** podczas pracy
- Wynik trafia do `cache/<bundleId>.json`, `ruleCache.load()` przeładowuje
- **Czyli flow działa automatycznie dla setek apek już dziś** — to się może
  popsuć na jakości, ale nie na zasięgu

### Telemetria + diagnostyka v1.1 ✅

- `EventLogger` loguje `toast` i `miss` events do `events.jsonl`
- `Analyzer` (`SFlow --analyze`) agreguje miss log do raportu
- `Reseeder` (`SFlow --reseed-all` / `--reseed <bundleId>`) — narzędzie dev do
  ręcznego odświeżenia hardcoded listy 4 apek. **Skipuje apki nie-zainstalowane**
  (Linear/Cursor na devsie Filipa). Wymaga ubicia GUI SFlow przed odpaleniem.
  Tworzy backup `bundled.json.bak.<ts>` przed pierwszym zapisem
- Backend `?fresh=1` query param na `/v1/discover` — pozwala obejść 90-dniowy
  KV cache. Reseeder używa tego od v1.1.1 (poprzednio cache zwracał stare reguły
  generowane przed deployem nowego promptu)

### Co **nie** jest zbudowane (czyli prawdziwa kolejka Fazy 1)

- ❌ Quality gate dla auto-discovered rules (przyjmujemy każdy wynik LLM)
- ❌ Retry logic dla nieudanych discovery (jedna porażka = no rules forever)
- ❌ Self-healing przez miss log (`/v1/refresh` endpoint)
- ❌ Wykrywanie **false positives** (toast pokazany dla błędnego skrótu)
- ❌ `AXKeyShortcutsValue` jako Layer 0 (zero-config dla apek z aria-keyshortcuts)
- ❌ Manualnie zweryfikowane coverage report dla 20 apek

---

## Lokalne vs serwer — decyzja architekturalna

To pytanie zadałeś — odpowiadam zanim wejdziemy w fazy.

### Co musi być lokalnie (zawsze)

- **Raw clicks** (każdy klik z atrybutami AX) — `events.jsonl`. Nigdy nie wysyłamy.
  To dane wrażliwe ("user kliknął element o tytule «Salary 2026»").
- **Per-element matching** (decyzja czy pokazać toast). Działa offline.
- **Bundled rules** (zaszyte w apce na start, bez internetu).

### Co musi być na serwerze (uzasadnione)

- **Rules database** (już mamy: CF Worker + KV). Bez serwera nie da się generować
  reguł dla nowych apek przez Claude. Lokalny LLM odpada (model ~10GB).
- **Curriculum generator** (droga B) — Faza 4. LLM raz w tygodniu układa
  userowi plan. Wysyłamy **agregaty**, nie raw events.
- **Cross-device sync** (mobile/web companion w przyszłości). Opcjonalne.

### Co może być oba

- **Heatmap/raporty** (droga E). Lokalnie wystarcza dla MVP. Serwer potrzebny
  gdy user chce sync lub porównanie z avg user.
- **Postęp nauki** (droga B). Lokalnie dla MVP, serwer dla multi-device.

### Rekomendacja architektury

**Hybrid privacy-first.**

```
        Lokalne (SFlow.app)              |          Serwer (CF Worker)
                                          |
[raw clicks]──────────────────────────────|  (nigdy nie opuszcza Maca)
       │                                  |
       ▼                                  |
[lokalny profil: top-N akcje]─────────────|──[agregat: bundleId + akcja + freq]
       │                                  |       │
       ▼                                  |       ▼
[matching + toast]                        |  [curriculum LLM call (raz/tydz.)]
       │                                  |       │
       ▼                                  |       ▼
[lokalny dashboard E]◄────────────────────|──[lesson plan JSON]
```

**Co wysyłamy do serwera (z Fazy 2):**
```json
{
  "anonymousUserId": "uuid-na-zawsze-na-tym-macu",
  "weekISO": "2026-W19",
  "aggregates": [
    {"bundleId": "com.tinyspeck.slackmacgap", "shortcutId": "slack-compose", "clicks": 47, "shortcutsUsed": 3}
  ]
}
```

**Czego NIE wysyłamy:** treści, dokładnych timestampów, pozycji kursora, raw
AX atrybutów (poza `/v1/discover` skeleton — tam już są filtrowane).

**User toggle "Disable telemetry":** od pierwszej wersji.

---

## Faza 1: Jakość pokrycia (2–4 tygodnie)

**Cel:** SFlow działa "dobrze" dla **dowolnej apki którą user zainstaluje**.
"Dobrze" = ≥70% hit rate, **<5% false positives**, samonaprawia się gdy
reguły się starzeją.

**Nie budujemy auto-discovery** (jest). Budujemy **jakość, retry,
samonaprawianie, eval**.

**Kryterium wyjścia (musimy to mieć przed Fazą 2):**
- 20 apek z confirmed hit rate ≥70% i false-positive rate <5%
- Quality gate filtruje błędne reguły z auto-discovery
- Retry mechanism naprawia nieudane discovery
- `/v1/refresh` endpoint + scheduler działają
- Zero blocking issues z beta-testów (3–5 osób, 1 tydzień)

### 1.1 Quality gate dla auto-discovered rules

**Problem:** dziś `DiscoveryService` (linia 60) zapisuje cokolwiek backend
zwróci. Jeśli Claude zhalucynuje "Notion: ⌘Z = Toggle Sidebar", toast będzie
fałszywie pokazywany przez wieki.

**Rozwiązanie:**
- Filtr przy zapisie: tylko `confidence: high` z `source: menu_bar` lub
  `web_docs_official` ląduje w aktywnym cache
- `medium` zapisany ale wyłączony (toast nie pokazuje) do czasu user-feedback
- `low` (`source: inferred_pattern`) całkowicie ignorowany dla auto-discovery
- Bundled rules (4 zweryfikowane apki) — bez filtra, są już sprawdzone

**Wpływ na UX:** auto-discoverowana apka pokazuje **mniej** toastów ale
prawie **żadnych fałszywych**. Lepiej cisza niż uczenie złego skrótu.

### 1.2 Retry logic dla failed discovery

**Problem:** `DiscoveryService` linia 42: `attempted.insert(bundleId)` — jedna
porażka, koniec. Jeśli apka jeszcze nie wczytała AX tree (pierwsze 5s po
launch) → discovery z pustym skeleton → backend zwraca puste lub błędne reguły
→ użytkownik forever bez reguł.

**Rozwiązanie:**
- `attempted` zapisany na dysku z timestampem (`attempted.json`)
- Backoff: po 1. failure czekamy 1h, po 2. — 24h, po 3. — 7 dni
- Trzymanymy info o przyczynie (HTTP error / pustay skeleton / rate limited)
- Settings: "Try again" button per apka (force retry now)
- Pre-check przed POST: jeśli `skeleton.count < 3` → poczekaj 30s, odpal jeszcze
  raz (apka się ładuje)

### 1.3 Self-healing przez miss log → `/v1/refresh`

**Problem:** reguły starzeją się gdy apka zmienia UI (Notion update'uje labels
co 2 tygodnie). Dziś nic się nie dzieje — reguły są stale do następnego
manualnego reseed'u.

**Rozwiązanie:**
- Nowy endpoint backendu `/v1/refresh`:
  - Wejście: `{bundleId, currentRules, recentMisses: [...]}`
  - Backend prosi Claude: "Te reguły są niedopasowane do tych elementów —
    wygeneruj zaktualizowane wersje"
  - Wyjście: nowy zestaw reguł
- Klient: scheduler (`NSBackgroundActivityScheduler`, niskopriorytetowy)
  - Raz dziennie patrzy na `events.jsonl` z ostatnich 7 dni
  - Dla każdej apki: jeśli ≥20 missów, ≥3 tytuły powtarzające się 3x → POST `/v1/refresh`
  - Nowy zestaw reguł zastępuje cache po passowaniu quality gate (1.1)

### 1.4 False-positive detection — to było moje przegapienie

**Problem:** miss log łapie "kliknięcie nie zmatchowane" ale **nie łapie**
"kliknięcie zmatchowane do błędnego skrótu". A to drugie jest **gorsze** —
uczy usera złego nawyku.

**Rozwiązanie (proste):** cmd-klik na toast (lub corner X) = "to jest źle".
Zapisuje do `events.jsonl` event `false_positive` z bundleId + shortcutId.
W Fazie 2.5 jeśli ≥3 razy ten sam shortcutId → automatycznie wyłączony
lokalnie. Dla bundled rules — agregat na backendzie (po Fazie 2): jeśli ≥5
unikalnych userów raportuje ten sam shortcutId → globalne wyłączenie.

**Wpływ:** użytkownik dostaje **kontrolę** nad SFlow, system uczy się szybciej.

### 1.5 AXKeyShortcutsValue jako Layer 0

**Z `deep-think-auto-discovery.md`:** Chromium eksponuje `aria-keyshortcuts`
jako AX atrybut `AXKeyShortcutsValue`. Gmail to ustawia (`c` = compose).
Niektóre inne apki też.

**Co dostajemy:** zero-config, language-agnostic toast dla apek które ten
atrybut ustawiają. Nawet bez backend call.

**Zadanie minimum:** dodać Layer 0 w `ClickWatcher`:
```swift
if let ks = readAttribute(element, "AXKeyShortcutsValue") as? String,
   let parsed = parseAriaShortcut(ks) {
    emit(parsed)
    return
}
```

**Risk:** nieznane jak szeroko adoptowane. Sprawdzić empirycznie podczas
1.6 (beta) — jeśli żadna apka tego nie używa, możemy odpiąć. Koszt
implementacji niski (~1h), warto spróbować.

### 1.6 Coverage eval — 20 zweryfikowanych apek

Pipeline (powtórzony 16 razy, bo Slack/Obsidian/Linear/Cursor już są):
1. Otwórz apkę → SFlow auto-discoveruje (sprawdzić menu bar status "Learning")
2. Czekaj na completion
3. Manual eval: 10 najpopularniejszych kliknięć, hit rate?
4. Jeśli <70% → iteruj prompt na backendzie, redeploy, force-refresh tej apki
5. Sprawdź false-positive rate (klikaj rzeczy random, czy fałszywe toasty?)
6. Jeśli OK → promote do `bundled.json` (`scripts/promote-to-bundled.sh`)

**Output:** `docs/coverage-report.md`:

```
| App         | Hit % | False+ % | Verified | Notes               |
|-------------|-------|----------|----------|---------------------|
| Slack       | 85%   | 2%       | 2026-05-13 | bundled           |
| Notion      | 78%   | 4%       | 2026-05-15 | bundled (new)     |
| Figma       | 45%   | 12%      | 2026-05-16 | needs prompt tune |
```

Ten plik **publicznie** na landing page'u — pokazuje "supported apps" z
konkretnymi liczbami.

### 1.7 Beta z 3–5 znajomymi (decyzyjne!)

**To jest najważniejszy krok Fazy 1.** Wszystko poprzednie to przygotowanie.

- 5 power-userów, 2 tygodnie
- Build z 20 zweryfikowanymi apkami + auto-discovery dla reszty
- Codzienny `sflow-analyze` raport → email do Filipa
- Po tygodniu 1: ankieta "ile fałszywych toastów zobaczyłeś?" (cel: ≤5)
- Po tygodniu 2: ankieta "ile **NOWYCH** skrótów teraz używasz częściej niż
  przed instalacją?" (cel: ≥3 średnio na osobę)

**Decyzja blokująca:**
- Jeśli średnia ≥3 → toast uczy → idziemy w Fazę 2 z planem
- Jeśli średnia 1–2 → toast trochę uczy → idziemy ale agresywniej w drogę B
  (więcej forced practice, mniej "subtle hint")
- Jeśli średnia 0–1 → toast nie uczy → **kompletny pivot**, droga D (blocker)
  lub C (drill) jako core

**Risk:** ta odpowiedź zmienia cały produkt. Lepiej dostać teraz niż po
6 miesiącach.

---

## Faza 2: Infrastruktura nauki (3–4 tygodnie)

**Cel:** mamy serwer + lokalne hooki potrzebne do drogi B i E.

**Kryterium wyjścia:**
- Anonymous user ID działa
- `shortcut_used` events się logują (drugi event tap dla klawiatury)
- Lokalne agregaty raz dziennie liczone z `events.jsonl`
- Endpoint `/v1/agg` przyjmuje agregaty + opt-out toggle działa
- Privacy UI w Settings

### 2.1 Anonymous user ID

UUIDv4 generowany przy pierwszym uruchomieniu, zapisany w
`~/Library/Application Support/SFlow/user.json`. Bez nazwiska, bez emaila, bez
konta. User może go wyczyścić ("Reset SFlow identity").

### 2.2 Rozbudowa EventLogger o nowe typy

Dziś:
- `toast` (SFlow pokazał toast)
- `miss` (kliknięcie nie zmatchowało)

Dodajemy:
- **`shortcut_used`** (user wcisnął klawiaturą skrót który jest w bazie)
- **`false_positive`** (już opisane w 1.4 — cmd-klik na toast)
- **`clicked_despite_known`** (user kliknął myszką akcję dla której pokazaliśmy
  toast w ostatnich N dniach — najcenniejszy event dla drogi B)

**Implementacja `shortcut_used`:** drugi CGEventTap na keyDown z filtrem **tylko
kombinacje z modifierami** (⌘/⌥/⌃/⇧). Raw keypresses NIE są logowane.
Cross-reference z aktywnym bundleId + rules cache.

**Risk:** drugi event tap = potencjalny perf hit + privacy concern. Filtr
modifier-only ogranicza to do ~50 eventów/dzień zamiast tysięcy.

### 2.3 Daily aggregator

Raz dziennie (NSBackgroundActivityScheduler):
1. Czytaj `events.jsonl` z ostatnich 24h
2. Agreguj per `(bundleId, shortcutId)`: `{clicked, used, missed, falsePos}`
3. Zapisz w `daily-aggregates.jsonl` (już agregat, nie raw)
4. Jeśli telemetry włączone → POST `/v1/agg` (batch jeśli były offline dni)
5. Rotate `events.jsonl` (zachowaj 30 dni)

### 2.4 Endpoint `/v1/agg`

Cloudflare Worker przyjmuje agregaty, zapisuje do D1 (sqlite na CF) lub KV.
Schema prosta: `(userId, date, bundleId, shortcutId, clicked, used, missed, falsePos)`.
Rate limit per IP, max 10KB payload, walidacja Zod.

### 2.5 Privacy UI w Settings

Nowe okno SwiftUI:
- "Telemetry: ON/OFF" toggle (default decyzja przy launch)
- Lista konkretnych pól które są wysyłane (z przykładem JSON)
- Lista pól które NIGDY nie są wysyłane
- Przycisk "Pokaż mi wszystko co o mnie wiecie" (otwiera `daily-aggregates.jsonl`
  w Finderze)
- Przycisk "Skasuj moje dane lokalne + zdalne" (POST `/v1/forget`)

**Powiązany endpoint `/v1/forget`** — RODO-friendly.

### 2.6 False-positive global aggregation

Z 1.4: lokalne wyłączenie po 3 zgłoszeniach. Tu dokładamy globalne agregaty
na backendzie. `/v1/agg` zlicza `false_positive` events. Jeśli ≥5 unikalnych
userów (różne `anonymousUserId`) zgłosi ten sam `(bundleId, shortcutId)` →
backend automatycznie ustawia `disabled: true` w rules KV → następne
`/v1/discover` zwraca rules bez tej.

To jest **droga #2 z `v1.1-roadmap.md` (Phase F feedback loop)** — naturalnie
trafia tutaj.

---

## Faza 3: Droga A — intro toast + onboarding (1 tydzień)

**Cel:** pierwsze 7–14 dni usera ma głośniejszy onboarding. Później system się
sam ucisza (przez naturalny mechanizm: nauczył się → klika klawiaturą → toast
się nie pojawia).

**Krytyczna uwaga (z dyskusji):** "tryb cichy" nie wymaga budowania. Gdy user
naprawdę opanuje skrót, przestaje klikać → toast się nie pojawia. **System
sam siebie wycisza.** Wystarczy zająć się **głośnym wejściem**.

### 3.1 Welcome sequence (jednorazowa)

Pierwsze uruchomienie:
1. Welcome screen: "SFlow pokazuje skróty gdy klikasz przyciski. Pierwszego
   tygodnia zobaczysz dużo toastów. Apka się sama uciszy gdy nauczysz się
   skrótów (bo będziesz klikać klawiaturą zamiast myszki)."
2. Permissions: AX + Input Monitoring (pierwsza prośba)
3. "Z których apek korzystasz najczęściej?" (lista top-20 wg bundled.json,
   checkbox)
4. Wynik: SFlow priorytetuje auto-discovery dla wskazanych (rozgrzewa cache
   w pierwszych 5 minutach po onboardingu)
5. Pokaż demo toast ("teraz wygląda to tak")

### 3.2 Intro toast — pierwsza ekspozycja jest mocniejsza

Liczone per `(userId, shortcutId)` w `learning-state.json`:
- Pierwsze 1–3 ekspozycje (`clickedCount < 3`) → **intro toast**: większy
  font (15pt zamiast 12), dłuższy timeout (4s zamiast 1.5s), lekka animacja
  fade-in z pulsem. Tekst: `⌘K  Quick Switcher — try this next time!`
- Kolejne (`clickedCount >= 3`) → **standardowy toast** jak dziś

**Counter store** (per shortcutId):
```json
{
  "slack-compose": {
    "clickedCount": 27,
    "shortcutUsedCount": 5,
    "lastClicked": "2026-05-13T...",
    "lastShortcutUsed": "2026-05-12T..."
  }
}
```

To wystarcza. Bez trybu "silent" (samoreguluje się).

### 3.3 Reinforcement w toaście dla curriculum (preview Fazy 4)

Krótki preview: gdy w Fazie 4 user dostanie tygodniowy plan, toast dla
skrótów **z planu** dostaje gwiazdkę:
```
⭐ ⌘K  Quick Switcher (cel tygodnia: 5/10)
```

Mała zmiana w renderze, big psychological win — user widzi że jego praca
łączy się z planem.

**Implementacja w Fazie 3 wstępna:** flaga w counter store `isCurriculum: true`
zmienia rendering. Logika "co jest w planie" przychodzi z Fazy 4.

---

## Faza 4: Droga B 1.0 — personalizowane lekcje (4–6 tygodni)

**Cel:** SFlow raz w tygodniu mówi "ćwicz te 5 skrótów, oto plan na 7 dni",
dashboard pokazuje postęp.

**Kryterium wyjścia:**
- Tygodniowy curriculum generowany przez Claude (lub prosty algorytm — patrz 4.1)
- Dashboard z aktualnym planem + postępem (`shortcut_used` count)
- Po 4 tygodniach z 5 beta-testerami: ≥3 osoby raportują "nauczyłem się
  N nowych skrótów dzięki SFlow"

### 4.1 Curriculum generator — wybór: algorytm vs LLM

**Wariant A (prosty algorytm, zero LLM cost):**
Lokalnie. Dla każdego skrótu policz `score = clickedCount × timesSaved × easeOfLearning`.
- `timesSaved`: predefiniowana sekunda zaoszczędzona per użycie (w bazie reguł,
  np. ⌘K w Slacku → 3s; ⌘Z → 1s)
- `easeOfLearning`: heurystyka (1-key vs 3-key combo)
Top 5 z najwyższym score (wykluczając te już opanowane, gdzie
`shortcutUsedCount > 10`).

**Wariant B (LLM curation):**
Endpoint `/v1/curriculum`. Backend dostaje aggregaty, woła Claude z promptem
"Ułóż userowi plan tygodniowy uwzględniając jego pattern usage, prioritize
skróty które dadzą mu najwięcej oszczędności czasu, dodaj ludzki opis".
Zwrot: lesson plan + krótkie uzasadnienie ("zaczynamy od ⌘K bo to twoje #1
najczęstsze kliknięcie w Slacku").

**Decyzja:** zacząć od **A**. Tańsze, deterministyczne, łatwiej debugować.
Dodać **B** później jako "Pro feature" jeśli userzy poproszą o personality.
Koszt B: ~$0.01 per user per week. Akceptowalne.

### 4.2 Lokalna lesson view (SwiftUI window)

Otwiera się:
- Po pierwszym logowaniu (powitalne curriculum po 3 dniach zbierania danych)
- W poniedziałek rano (NSUserNotification "Twój plan na ten tydzień jest gotowy")
- Z menu bar (klik na ikonkę SFlow → "Show this week's plan")

Zawartość:
- 5 kart skrótów (apka + akcja + skrót + statystyki "kliknięcia: 47x,
  użyłeś klawiatury: 2x")
- Progress bar per skrót ("opanowanie: ▓▓░░░░ — uderz 10x klawiaturą żeby
  zaliczyć")
- Tygodniowy heatmap (mini-wykres z miesięcznym kontekstem)
- "Ćwicz teraz" button przy każdej karcie → otwiera odpowiednią apkę

### 4.3 Reinforcement w toaście (pełna implementacja)

Z 3.3 — toast dla skrótów z curriculum dostaje gwiazdkę + progres. Pełna
integracja: lesson view ↔ counter store ↔ toast renderer.

### 4.4 Mierzenie postępu

Co tydzień raport "tydzień zamknięty":
- Skróty z planu: opanowane (`used ≥ 10`) / pominięte
- Łączny czas zaoszczędzony (`sum(used × timesSaved)`)
- Comparison z poprzednim tygodniem (+/- minuty)

To naturalnie pływa w drogę E.

---

## Faza 5: Droga E — raporty + dashboard (2–3 tygodnie)

**Cel:** user widzi konkretną wartość liczbową. "Zaoszczędziłeś 27 minut
w tym miesiącu używając skrótów dzięki SFlow."

**Kryterium wyjścia:**
- Tygodniowy raport (in-app + opcjonalny email)
- Lifetime dashboard
- Eksport CSV

### 5.1 SavingsCalculator

Lokalny moduł:
- Input: `daily-aggregates.jsonl` + tabela `timesSaved` per skrót
- Output: `weekly-savings.json`:
  - `totalMinutesSaved`
  - `topShortcuts: [...]`
  - `improvementVsPrevWeek: +X%`
  - `comparisonToFirstWeek: +Y%`

### 5.2 Weekly Report Window

Pełnoekranowy widok (raz w tygodniu, w sobotę rano):
- "Tydzień 19, 2026"
- Big number: "Zaoszczędziłeś **27 minut** dzięki skrótom"
- Wykres: dni tygodnia × skróty użyte
- Lista top-10 skrótów których użyłeś
- "Następny tydzień" link → curriculum (droga B)

### 5.3 Menu bar icon updates

Mała liczba "27" obok ikony oznacza "27 minut zaoszczędzonych w tym tygodniu".
Resetuje się w poniedziałek. Mały dopaminowy reward stale widoczny.

### 5.4 Email raport (opt-in)

Tylko jeśli user da email. Tygodniowy mailing z najlepszymi cytatami.
Marketingowo silne ("share your savings").

---

## Faza 6: Pricing + launch (2–3 tygodnie)

**Cel:** ludzie kupują.

### 6.1 Decyzja modelu

- **A. $25 one-time forever.** Najprostszy. Dobry dla walidacji
  willingness-to-pay. Brak revenue retention.
- **B. $5/mies subscription.** Free: 5 apek + raporty E. Paid: nielimitowane
  apki, drogi B, curriculum LLM, email raport.
- **C. Free fully (B2B only).** Pricing przez team license (Faza 7).

**Sugestia:** wariant **A** dla pierwszych 100 userów (Gumroad, prosta
sprzedaż). Po 100 → przejście na **B** z grandfathered pricing.

### 6.2 Onboarding paywall

Po Phase 3 onboarding sequence dodać:
- 14-dniowy free trial counter
- Po 14 dniach okno "Twój darmowy okres się kończy. Już zaoszczędziłeś X minut.
  Kup pełną wersję żeby kontynuować."
- Pricing card $25 one-time, link do Gumroad

### 6.3 Landing page

`sflow.app` (lub podobna). Sekcje:
- Hero: 10-sec wideo "klikasz → toast → uczysz się"
- **Lista 20 supportowanych apek** z `coverage-report.md` (faza 1.6)
- "Twoje pierwsze 14 dni za darmo"
- Testimonials z bety
- Privacy: pełny opis
- FAQ

### 6.4 Distribution

- Product Hunt launch
- HN Show (opcjonalnie)
- Twitter/X — Filip + 5 friendly accounts
- Newsletter dla power-userów (DenseDiscovery, Refind, Hacker Newsletter)
- Reddit r/macapps (ostrożnie, czytają regulamin)

---

## Faza 7: B2B / Team (długoterminowo)

**Cel:** sprzedaż pakietów licencji firmom.

Wymaga: SSO, admin dashboard, "company-wide curriculum", security audit.

**Decyzja:** otwierać dopiero po **udowodnieniu B2C** (Faza 6 dostarcza
ARR $50k+). Sprzedaż B2B jest 6–12-miesięcznym wysiłkiem.

---

## Risk register

### R1: Toast nie uczy (najwyższy risk)

**Mitigacja:** beta z 3–5 osobami w Fazie 1.7. Pytanie "ile NOWYCH skrótów
używasz częściej". Jeśli wynik 0–1 → pivot do drogi D lub C. **Decyzja
blokująca Fazy 2–4.**

### R2: Auto-discovery zwraca niskiej jakości reguły dla wielu apek

**Mitigacja:** quality gate (1.1) filtruje. Beta (1.7) ujawni które apki są
problematyczne. Iteracja prompta + bundled overrides dla TOP 20.

### R3: Privacy odstrasza userów

**Mitigacja:** Faza 2.5 dostarcza widoczne UI. Default OFF dla telemetry
**przy launchu**, default ON dla bety. Wyraźne opt-in CTA z konkretnym
benefit ("włącz żeby dostać personalizowane lekcje").

### R4: Konkurencja (KeyCue) wypuści podobną feature

**Mitigacja:** prędkość. Każda faza kończona, decyzja go/no-go, kolejna
zaczynana. Nie utknąć w "perfekcjonizacji" jednej fazy.

### R5: macOS update łamie AX API lub CGEventTap

**Mitigacja:** sprawdzaj betę macOS. Wbudowany "diagnostic mode" żeby user
mógł wysłać raport jednym klikiem. Hotfix w ciągu 48h.

### R6: Coraz większa baza = większe koszty Claude API

**Mitigacja:** Claude tylko dla `/v1/discover` (raz per apka per user) i
`/v1/curriculum` (raz/tydzień per user, **jeśli wariant B**). Łączny koszt:
~$0.10/user/miesiąc przy wariancie B, ~$0.02 przy A. Akceptowalne nawet
przy 10k userów.

### R7: False positives nie są wykrywane bez user feedback

**Mitigacja:** mechanizm cmd-klik z 1.4 jest **obowiązkowy** w pierwszym
releasie. Beta-testerzy świadomie szukają fałszywych toastów.

---

## Sequence pictorial

```
Phase 1: Jakość pokrycia (2-4 tyg.)
  ├── 1.1 Quality gate dla auto-discovery
  ├── 1.2 Retry + backoff
  ├── 1.3 /v1/refresh self-healing
  ├── 1.4 False-positive detection (cmd-klik)
  ├── 1.5 AXKeyShortcutsValue L0
  ├── 1.6 20 zweryfikowanych apek (coverage-report.md)
  └── 1.7 Beta z 3-5 osobami      ← DECYZJA: idziemy dalej?
                │
                ▼
Phase 2: Infra (3-4 tyg.)
  ├── 2.1 Anonymous user ID
  ├── 2.2 shortcut_used + false_positive + clicked_despite_known events
  ├── 2.3 Daily aggregator
  ├── 2.4 /v1/agg endpoint
  ├── 2.5 Privacy UI + /v1/forget
  └── 2.6 Global false-positive aggregation
                │
                ▼
Phase 3: Droga A (1 tydzień)
  ├── 3.1 Welcome sequence
  ├── 3.2 Intro toast (pierwsze 3 ekspozycje)
  └── 3.3 Curriculum hook w toaście (preview Fazy 4)
                │
                ▼
Phase 4: Droga B 1.0 (4-6 tyg.)
  ├── 4.1 Curriculum generator (algorytm A → ew. LLM B później)
  ├── 4.2 Lesson view
  ├── 4.3 Reinforcement w toaście
  └── 4.4 Postęp tygodniowy
                │
                ▼
Phase 5: Droga E (2-3 tyg.)
  ├── 5.1 SavingsCalculator
  ├── 5.2 Weekly Report
  ├── 5.3 Menu bar updates
  └── 5.4 Email raport (opt-in)
                │
                ▼
Phase 6: Launch (2-3 tyg.)
  ├── 6.1 Pricing decyzja
  ├── 6.2 Paywall
  ├── 6.3 Landing page
  └── 6.4 Distribution
                │
                ▼
Phase 7: B2B (długoterminowo)
```

**Łączny czas do launch (Fazy 1–6):** **14–22 tygodnie** (3.5–5.5 miesięcy)
przy pracy part-time. Krótszy niż w v1 dokumentu dzięki rozpoznaniu że Faza 1
jest mniejsza.

---

## Najbliższy krok (tydzień 1)

Konkretny, do zrobienia jutro. Kolejność zmieniona po sesji v1.1.1, w której
ukończono częściowo Fazę 1.1 (dedup na backendzie) oraz dodano tolerancję
hotkey-suffix w `RuleCache.match` (klient akceptuje "Edit message E" gdy
reguła ma tylko "Edit message"):

1. **Faza 1.0 (NOWA, najszybszy ROI) — re-seed pozostałych bundled apek
   z v1.1.1 promtem.** Terminal, Notion, Claude Desktop nadal mają reguły
   starego v1.0 promptu (avg 1.05–2.13 wariantów tytułów per regule,
   versus 4+ w nowych). 5–10 minut: dla każdej `./scripts/sflow-reseed <bundleId>`
   → review → `promote-to-bundled.sh` → commit. **Robić PIERWSZE** zanim
   ruszamy resztę.

2. **Faza 1.4 + 1.5 — false-positive feedback (cmd-klik) + naprawa bugu
   MenuBarIndex.lookup.** To dwie rzeczy nietknięte przez v1.1.1 a kluczowe
   dla jakości pokrycia. Backend dedup (zrobiony w v1.1.1) odpowiada za
   "rule conflicts before client" — ale **false-positives które przeszły
   przez dedup** wymagają user feedback. Spec:
   `docs/superpowers/specs/2026-05-XX-quality-and-feedback-design.md`

3. **Równolegle Faza 1.6 (rozpoczęcie) — coverage eval dla 5 nowych apek.**
   Wybierz: Notion (po re-seedzie z #1!), Figma, VS Code, Chrome, Raycast.
   Po jednej dziennie: otwórz apkę z SFlow, czekaj na auto-discovery (powinno
   się stać automatycznie!), klikaj 10 popularnych przycisków, notuj hit% i
   false+%. Wynik wpisuj do `docs/coverage-report.md` (nowy plik).

4. **W tle Faza 1.7 (rozpoczęcie) — zaprosić 3 znajomych do bety.** Daj im
   bieżący build, instrukcję "używaj normalnie 7 dni, raz na 2 dni odpal
   `sflow-analyze` i wyślij output". Nie wymagaj jeszcze żadnych ankiet —
   po prostu zbierz baseline data.

Co zostało **częściowo wykonane** w v1.1.1 (a co nadal trzeba w Fazie 1.1
quality gate):
- ✅ Backend post-process dedup overlapping rules (zapobiega lottery toasts
  jak Slack "Search Slack" ⌘F vs ⌘G)
- ✅ Client-side tolerance "Edit message E" → match "Edit message"
- ❌ Client-side filtr `confidence: medium + source: inferred_pattern`
  (nadal pokazujemy te toasty)
- ❌ Mechanizm "experimental" toggle dla low-confidence reguł
- ❌ Quality gate przy zapisie do cache (`DiscoveryService`)

**Czego NIE robić w tym tygodniu:**
- Nie projektuj curriculum (Faza 4) — za wcześnie
- Nie pisz landing page'u (Faza 6) — nie ma czego sprzedawać
- Nie integruj telemetry z serwerem (Faza 2) — Faza 1 musi być solidna
- Nie poleruj toasta wizualnie (Faza 3) — to 1 tydzień pracy później, nie teraz

---

*Status: roboczy roadmap, v2. Każda faza dostanie osobny spec + plan przed
implementacją. Następny krok: spec Fazy 1.1+1.4 (quality gate + false-positive
detection).*
