# Analiza `events.jsonl` — 2026-05-16

> **Autor:** AI (asystent), z prośby Filipa o "co mogę robić bezpiecznie gdy
> nie ma mnie przy kompie".
>
> **Źródło:** `~/Library/Application Support/SFlow/events.jsonl` — 147 wpisów,
> okno 2026-05-15 22:11 → 2026-05-16 08:34 (~10h aktywnego użycia).
>
> **Cel:** Dane do **Sesji 8** (P-31 część 2 — data-driven coverage iteration)
> i **Sesji C.5** (P-38 — MenuItemObserver). Tabela rozszerzeń per finding,
> z linkami do propozycji w `audit-phase-1.md`.
>
> **Status:** read-only analiza, **żaden plik kodu nie został zmieniony**.

---

## 1. Statystyki zbiorcze

**Toast vs miss:** 57 toastów (39%), 90 missów (61%).

> "Miss" w nowym schemacie = `MissEvent` z `EventLogger.logMiss` — kliknięcie
> w interaktywny element bez trafienia żadnej warstwy.

### 1.1. Toasts per layer

| Layer | Count | Udział | Komentarz |
|---|---|---|---|
| **L0.5** (JSON rules / cache) | 18 | 32% | Najsilniejsza warstwa po Sesji 9 (reseedy v1.1.1) |
| **L1** (ShortcutRules hardcoded) | 16 | 28% | Legacy ale wciąż istotne — Slack/Comet/Claude |
| **L3** (MenuBarIndex fuzzy) | 12 | 21% | Po fixie key-direction (Sesja 2) działa deterministycznie |
| **menu-fallback** | 5 | 9% | Direct menu bar lookup gdy walk nie znalazł |
| **L0.3** (TooltipObserver) | 5 | 9% | **Sesja B działa** — 1 prawdziwy (Cron "Create event/c") + **4 false-positive (Comet)** ← patrz §3 |
| **L4** (universal heuristics) | 1 | 2% | Slack "Go Forward" |
| L0 (AXKeyShortcuts) | 0 | — | Empirycznie żadna z używanych apek nie eksponuje `aria-keyshortcuts` |
| L2 (kAXHelp) | 0 | — | Help text bez shortcut hintów w tym oknie |

**Wniosek:** L0 i L2 to martwe warstwy w **typowym** użyciu (Slack/Comet/Notion/
Cron/Console). Hipoteza: większa empiryczna wartość przyjdzie z apek "natywnych
macOS" (Xcode/Console mają fragment menu coverage z L3, reszta zero). **Nie
usuwać L0/L2** — defensive coverage dla apek których jeszcze nie widzieliśmy
(Gmail web ma `aria-keyshortcuts`, Excel ma rich `AXHelp`), ale **nie inwestować
w nie więcej zanim nie ma sygnału z bety**.

### 1.2. Misses per app (top 9)

| Bundle | Missy | Udział | Główny pattern |
|---|---|---|---|
| `ai.perplexity.comet` | 39 | 43% | Browser content (linki Amazon, sklepy, embedded UI). **Większość to nie-skrótowe elementy** — patrz §4 |
| `com.tinyspeck.slackmacgap` | 11 | 12% | Message actions (Remove from Later, Save for later, More actions) + close buttons |
| `com.apple.finder` | 8 | 9% | AXCell (file rows) + AXTextField (filename edit). **Nie-skrótowe** — patrz §4 |
| `com.apple.Console` | 8 | 9% | AXTextField (search bar), AXCell (log rows) |
| `com.cron.electron` | 6 | 7% | **Week/Month dropdown buttons** (P-38 confirmed!) + link |
| `com.apple.dt.Xcode` | 6 | 7% | "Stop Tasks", "Cancel" z generycznym `action-button-N` identifier |
| `pl.maketheweb.cleanshotx` | 5 | 6% | Record Video, Restart Recording — bez rules |
| `net.whatsapp.WhatsApp` | 3 | 3% | **Chat list items z PII** — patrz §5 (privacy) |
| `notion.id` | 2 | 2% | "Open in side peek <strona>" — PII w title |

---

## 2. Top miss patterns (uniq na rolę+desc+title+value+subtreeLabel)

| # | Count | Role | Title | Desc | Sub | Klasa |
|---|---|---|---|---|---|---|
| 1 | 6 | AXButton | "" | "" | "" | **Naked Chromium icon** — pełna pustka (web pages) |
| 2 | 5 | AXCheckBox | "" | "Remove from Later" | "" | Slack toggle button |
| 3 | 4 | AXButton | "Stop Tasks" | "" | "" | Xcode action-button-N |
| 4 | 3 | AXPopUpButton | "" | "Extensions" | "" | Chromium browser chrome |
| 5 | 2 | AXPopUpButton | "" | "More actions" | "" | Slack message hover |
| 6 | 2 | AXLink | "" | "27 items in shopping basket" | "" | Browser content link |
| 7 | 2 | AXCheckBox | "" | "Save for later" | "" | Slack toggle button |
| 8 | 2 | AXCell | "" | "" | "SFlow" | Finder file cell |
| 9 | 2 | AXButton | "Week" | "" | "Week" | **Cron dropdown** (P-38) |
| 10 | 2 | AXButton | "Restart Recording" | "" | "" | CleanShot |
| 11 | 2 | AXButton | "Month" | "" | "Month" | **Cron dropdown** (P-38) |
| 12 | 2 | AXButton | "Load unpacked" | "" | "Load unpacked" | Chromium extensions page |
| 13 | 2 | AXButton | "Cancel" | "" | "" | Xcode |

---

## 3. **FALSE POSITIVE: L0.3 TooltipObserver w Comet** ← natychmiastowa akcja

**Dane:**
```
ai.perplexity.comet | hint="shortcut" keys=["2"] ts=2026-05-16T07:58:06Z
ai.perplexity.comet | hint="shortcut" keys=["2"] ts=2026-05-16T07:58:08Z
ai.perplexity.comet | hint="shortcut" keys=["2"] ts=2026-05-16T07:58:14Z
ai.perplexity.comet | hint="shortcut" keys=["2"] ts=2026-05-16T07:58:20Z
```

**Diagnoza:** TooltipObserver złapał gdzieś w Comet element z dwoma AXStaticText:
jeden = "shortcut" (słowo dosłowne), drugi = "2" (jeden znak → parser uznał za
keys=["2"]). To może być:

- **Hipoteza A:** keyboard shortcut help overlay (Comet ma `?` → cheatsheet z
  listą "Action / Shortcut" — header "Shortcut" mógł być zinterpretowany jako
  akcja, "2" obok jako badge)
- **Hipoteza B:** floating React tooltip w Comet który zawiera dosłowne słowo
  "shortcut" jako tekst informacyjny ("press 2 for shortcut")
- **Hipoteza C:** browser content (np. forum post z tabelką skrótów)

**Wszystkie 3 hipotezy = pasywne zbieranie zaszumionych danych z fragmentów UI
które nie są tooltipami.**

**Sugerowany fix (TooltipObserver):**

1. **Blacklist słowa "shortcut" jako name kandydata.** Tooltipy mówią *jaką
   akcję* przycisk wykonuje ("Compose", "Reply", "Forward"), a nie "shortcut".
   Słowa-meta ("shortcut", "hotkey", "key", "keyboard", "press") = sygnał że
   to **help overlay**, nie tooltip akcji.

2. **Sanity check na length name:** odrzucać name'y krótsze niż 3 znaki lub
   bez żadnego verbu/rzeczownika. "shortcut" pass'uje (8 znaków), ale to nie
   przypadek dla single-word filtra — wymagałoby NLP. Lepiej:

3. **Pattern check:** name musi mieć **co najmniej 1 spację** (multi-word
   imperative jak "Mark unread", "Reply to message") **lub** być w whitelistie
   single-word verbów ("Reply", "Forward", "Compose", "Archive", "Delete",
   "Save", "Search", etc.). To eliminuje "shortcut"/"hotkey" jako single-word
   non-verb.

4. **Alternatywnie / dodatkowo:** keys=["2"] (single character bez modifierów)
   to słaby kandydat — **wymagać co najmniej 1 modifier ALBO whitelista pojedynczych
   liter w kontekście znanych akcji** (Notion-style "c", "r", "f"). Comet
   "2" bez "Mark unread"/"Reply"/"Compose" → odrzucić.

**Severity:** WYSOKA — user widzi wrong toast "shortcut" 4× w tej samej sesji,
bezpośrednio podważa zaufanie. Plus to się propaguje do `discovered/*.jsonl`
i potem do crowdsource backendu (Sesja C).

**Akcja:** Sesja "B.1 follow-up — TooltipObserver false-positive scrubbing"
(nowa, ~1h):
- Dodać `Self.bannedNames = ["shortcut", "hotkey", "keyboard", "keys", "press"]`
- Dodać multi-word OR single-word-whitelist check
- Wyczyścić `~/Library/Application Support/SFlow/discovered/ai.perplexity.comet.jsonl`
  z entries `name="shortcut"` (lub re-process w plenrym formacie)
- Dodać 3 testy: "shortcut as name → rejected", "Mark unread as name → accepted",
  "single-letter key without modifier and without whitelisted name → rejected"

---

## 4. Nie-skrótowe missy (informational, nie wymagają fixu)

**~40% missów** (ai.perplexity.comet + finder cells + console rows) to elementy
**bez sensownych skrótów**:

- Browser content links (Amazon "Returns & Orders", "27 items in shopping
  basket", "Continue to checkout") — to są **dynamiczne linki strony**, nie UI
  akcje apki
- Finder AXCell ("Desktop", "SFlow", filenames) — to są dane, nie akcje
- Finder AXTextField z filename edit value — wprowadzanie tekstu nie ma
  skrótu
- Console AXCell (log rows, w tym sama wiadomość log'a SFlow!) — dane

**Implikacja:** **filter out** te kliknięcia z miss-log jeszcze klient-side
(przed zapisem do `events.jsonl`), żeby nie zaśmiecać danych dla Sesji 8/9.

**Proponowany filtr (nowy `EventLogger.shouldLogMiss`):**

```swift
// Skip elements that semantically aren't actions:
// - AXCell w przeglądarce plików/log'ów (rola "row")
// - AXLink z desc dłuższym niż 60 znaków (probably content link, not UI)
// - AXTextField z value będącym filename (kropka + extension)
// - AXLink/AXButton w bundleId in {browser bundles}
//   gdy desc zawiera URL/cenę/liczbę zakupów
```

**Albo lżejszy fix:** dodać do `EventLogger.MissEvent` pole `isLikelyContent: Bool`
i grupować je osobno w `Analyzer.swift` raport — niech zostają w log'u dla
debug'u, ale nie liczą się jako "coverage gap".

**Severity:** ŚREDNIA. Nie blokuje funkcji, ale brudzi dane do analiz P-31.

---

## 5. **Privacy / PII concerns** ← uwaga przed Sesją C

W `events.jsonl` widać dane wrażliwe **w nieprzetworzonej formie**:

| Linia | Bundle | Pole | Wartość | Klasa PII |
|---|---|---|---|---|
| 71 | WhatsApp | desc | "☀️Sade☀️" | Imię kontaktu (emoji + nazwa) |
| 71 | WhatsApp | value | "‎Missed video call, 00:35, ‎Received from ☀️Sade☀️, ‎Pinned" | Treść wiadomości + kontakt |
| 88 | notion.id | title+subtreeLabel | "Open in side peek Virginity pg 83" | Tytuł prywatnej notatki |
| 89 | notion.id | title+subtreeLabel | "Open in side peek Solo sex 84" | Tytuł prywatnej notatki |
| 103 | WhatsApp | desc | "Català - Sade, Filip, Aday, ‎6 unread messages" | Imiona członków grupy + status |
| 103 | WhatsApp | value | "‎Message from Aday, Bona nit!, 00:16..." | Treść wiadomości |
| 51 | Comet | desc | "MasterCard •••• 2534 Filip Gawel 4 2032" | **Dane karty (masked, ale imię+rok widoczny)** |

**Implikacja:**

1. **Sesja C (backend `/v1/discovered`) musi mieć agresywny privacy scrubber
   PRZED uploadem.** AXSkeletonExtractor już ma scrubbing — patrz
   `AXSkeletonExtractor.shouldEmit`. **MissEvent / DiscoveredEntry nie ma.**
   Bez tego crowdsource'ujemy dane prywatne userów na serwer.

2. **EventLogger powinien stosować ten sam filtr co AXSkeletonExtractor**
   (emails, ISO daty, długi tekst, hasła karty, imiona z białych list nie
   działają — privacy musi być inkluzywny: "jeśli widzisz znak waluty, cyfry
   karty, datę, długi text → drop").

3. **`~/Library/Application Support/SFlow/events.jsonl` jest plain text na
   dysku.** Filip ma "Privacy: log miss events" toggle w Settings (Sesja 3).
   **Aktualnie OFF byłoby bezpieczniejszym defaultem dla beta** — przed Sesją 1.7
   (beta z 3-5 osób) trzeba zdecydować czy default → OFF.

**Severity:** WYSOKA dla Sesji C, ŚREDNIA dla Sesji 1.7 beta.

**Akcja:** dodać do planu Sesji C explicit "Privacy scrubbing pipeline" jako
pierwsze zadanie, **PRZED** wszystkim innym.

---

## 6. P-38 confirmation (Sesja C.5 / Sub-cel 1.17)

**Direct evidence w danych:**

```
com.cron.electron | AXButton title="Week" sub="Week"     (2×)
com.cron.electron | AXButton title="Month" sub="Month"   (2×)
ai.perplexity.comet | AXMenuItem title="Mark unread U" sub="Mark unread"
ai.perplexity.comet | AXMenuItem desc="Testing"
ai.perplexity.comet | AXMenuItem desc="Camping"
```

**Co to mówi:**

1. **Cron Week/Month** — to są przyciski w dropdown'ie "View" w Notion Calendar
   (alias com.cron.electron). Mają nazwę = title, ale brakuje skrótu w atrybutach.
   Skrót jest gdzieś indziej w dropdown'ie ("1 or D", "0 or W", "M"). Wymaga
   `MenuItemObserver` który czyta `AXMenu`/`AXMenuItem` po hover-otwarciu.

2. **Comet "Mark unread U"** — to **WŁAŚNIE TEN WZÓR P-38**! title kończy się
   spacją + jedną literą. AXMenuItem w Comet (Chromium context menu) podaje
   nazwę akcji **i** skrót w jednym title-string'u. Parser powinien:
   - rozpoznać format `"<words> <SINGLE_KEY>"` na końcu
   - wyciąć skrót: `"Mark unread"` + `"U"` (potencjalnie z modyfikatorem jak
     "Mark unread ⌘U")

3. **Comet "Testing" / "Camping"** — to różne dropdownowe bookmark folders.
   **Nie** mają skrótów inline. Te są **TRUE NEGATIVES** — dobrze że ich
   nie tapujemy.

**Implikacja dla Sesji C.5:**
- **Strategia 1 — pattern "title kończy się single-letter":** prosty parser,
  ~50 LOC, działa dla Chromium AXMenuItem z inline shortcut na końcu nazwy.
- **Strategia 2 — `kAXMenuItemCmdChar`/`kAXMenuItemCmdModifiers`:** dla
  natywnych macOS dropdownów. AppKit eksponuje wprost.
- **Strategia 3 — pozycyjne parsowanie 2 StaticText'ów wewnątrz AXMenuItem:**
  dla Notion-style dropdownów z badge'em po prawej (jak Sesja B tooltipy).

**Wszystkie 3 strategie są niezależne i można je dodać sukcesywnie.**

Patrz plan: `docs/superpowers/plans/2026-05-16-menu-item-observer.md`.

---

## 7. Inne ważne obserwacje

### 7.1. Slack message-action checkboxy (5+ missów)

```
AXCheckBox | t="" d="Remove from Later" v="" sub="" (5×)
AXCheckBox | t="" d="Save for later" v="" sub="" (2×)
```

Slack message hover toolbar ma `Remove from Later` / `Save for later` /
`More actions`. Są w `ShortcutRules.swift` `slack-msg-*`? Sprawdzić.

Jeśli **nie**: dodać `slack-msg-save` ("Save for later" → s), `slack-msg-unsave`
("Remove from Later" → s, toggle), `slack-msg-more` ("More actions" → meta+
shift+m, jeśli istnieje). Te tłumaczenia trzeba sprawdzić w Slack docs.

Jeśli **tak**: bug — reguły są ale `desc` nie matchuje. Patrz `RuleCache.match`
— czy wspiera desc lookup dla AXCheckBox? Z audytu wiem że `slack-msg-*` zostały
dodane w sesji niedawnej (patrz wpis w outstanding-blockers product-vision).

### 7.2. Xcode "action-button-N" (6 missów)

```
AXButton | t="Stop Tasks" identifier="action-button-1" (4×)
AXButton | t="Cancel" identifier="action-button-2" (2×)
```

Xcode UI buttons z generycznymi identifier'ami. **Stop Tasks** w Xcode to
⌘. (cmd-period). **Cancel** — bez skrótu uniwersalnego (Escape jako alternatywa).

**Brakuje reguł dla `com.apple.dt.Xcode`** — sprawdzić `bundled/cache/com.apple.dt.Xcode.json`.
Jeśli nie istnieje → reseed (Sesja 9b). Jeśli istnieje → reguła nie ma title
"Stop Tasks" w `titles` array.

### 7.3. CleanShot X — brak reguł

`pl.maketheweb.cleanshotx` ma 5 missów (Record Video, Restart Recording).
Apka popularna, native macOS, prawdopodobnie ma skróty.

**Akcja:** dodać do Sesji 9b (P-32 reseed) — lub przed nią uruchomić
`./scripts/sflow-reseed pl.maketheweb.cleanshotx` (jeśli backend istnieje).

### 7.4. Notion main app — bardzo mało missów (2)

`notion.id` ma tylko 2 missy ("Open in side peek X"). To znaczy że albo:
- Notion main jest dobrze pokryty regułami L0.5 (sprawdzić cache)
- **Albo** Filip nie używał aktywnie Notion w tym oknie 10h

Z timeline'a: pierwsze trafienie Notion ~2026-05-16 07:35, dwa missy w ciągu
3 min. Możliwe że to było jednorazowe testowanie po Sesji B.

---

## 8. Rekomendacje dla następnych sesji

### Priorytet WYSOKA (blokuje user trust):

1. **Sesja B.1 follow-up (TooltipObserver scrubbing)** — patrz §3.
   Dropuje 4 fałszywe toasty / 10h użycia. **~1h pracy.**

2. **Privacy scrubber dla MissEvent** — patrz §5. WhatsApp PII w log'u, Notion
   PII w title. Przed Sesją C **must-have**, przed Sesją 1.7 beta **must-have**.
   **~2h.**

### Priorytet ŚREDNIA (data quality):

3. **Filter content-like missy klient-side** — patrz §4. Czyści dane dla
   Sesji 8 analiz. **~1h.**

4. **Sesja C.5 (MenuItemObserver / P-38)** — patrz §6 i osobny plan.
   Dane potwierdzają wartość. **Strategia 1 (title-trailing-letter parser)
   to ~3h**, strategie 2+3 razem ~6h.

### Priorytet NISKA (incremental coverage):

5. **Slack message-action rules audit** — patrz §7.1. Sprawdzić istniejące
   `slack-msg-*` reguły, dopisać brakujące. **~1h.**

6. **Reseed CleanShot X + Xcode** — patrz §7.2-7.3. **~30 min.**

---

## 9. Akcje wykonane przez AI w tej sesji

- **Nie zmodyfikowano** żadnego pliku kodu (poza tym dokumentem).
- **Nie zacommitowano** niczego.
- Dane czytane: `~/Library/Application Support/SFlow/events.jsonl` (read-only).
- Dokumenty stworzone:
  - `docs/events-jsonl-analysis-2026-05-16.md` (ten plik)
  - `docs/superpowers/plans/2026-05-16-menu-item-observer.md` (osobno)
  - `docs/superpowers/plans/2026-05-16-prompt-web-research.md` (osobno)

Decyzja Filipa: czy któryś z findingów chce promować do `audit-phase-0.md` jako
P-39 (TooltipObserver false-positive) i P-40 (MissEvent PII scrubbing) — albo
zostawić jako TODO w tym dokumencie.
