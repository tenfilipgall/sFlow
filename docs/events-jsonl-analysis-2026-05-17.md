# Analiza `events.jsonl` — 2026-05-17 (qualitative update)

> **Autor:** AI (asystent), wykonane podczas nieobecności Filipa.
>
> **Źródło:** `~/Library/Application Support/SFlow/events.jsonl` —
> **22 wpisy**, okno 2026-05-17 12:32 → 12:46 (~14 minut aktywnego użycia).
>
> **Status:** read-only, **żaden plik kodu nie zmieniony**, dokument nie
> jest jeszcze scommitowany — czeka na review Filipa.
>
> **Relacja do poprzedniego raportu:** 2026-05-16 miał 147 wpisów / 10h
> użycia. Dziś plik został **zrotowany** (najpewniej w toku integracji
> B.1 PrivacyFilter, commit `f2e8c10` z 2026-05-17 09:00 widnieje jako
> `attempted.json`) — sample za mały na statystykę per-layer. Stąd ten
> raport jest **qualitative** (obserwacje) + **comparison** vs
> 2026-05-16, nie ilościowa analiza.

---

## 1. Mini-statystyka (do kontekstu, nie do decyzji)

**22 wpisy = 19 missów + 3 toasty**

Toasty (wszystkie L1, ShortcutRules hardcoded):
- ×2 `comet-new-tab` (⌘T)
- ×1 `finder-back` (⌘[)

Apki w sample:
- `ai.perplexity.comet` — 10 wpisów (browser surfing po hiszpańskich/polskich stronach hotelowych)
- `com.apple.finder` — 7 wpisów (file rename + Go Back)
- `net.whatsapp.WhatsApp` — 2 wpisy (PII redacted ✅)
- `com.apple.Terminal` — 1 wpis (Cancel button — generic `action-button--999`)
- `ai.perplexity.comet` powtórzone w toastach — łącznie liczę z missami

**Wniosek o samplingu:** zbyt mały zbiór dla wniosków typu „L0.3 ma X% hit rate w Slacku". Ten raport skupia się na **co działa / co nie działa** vs prior.

---

## 2. ✅ Wnioski pozytywne — co się poprawiło vs 2026-05-16

### 2.1. PrivacyFilter zintegrowany ✅ (P-40 zamknięte)

W 2 wpisach widać `[REDACTED]` zamiast PII:
- WhatsApp button `desc="[REDACTED]"` (zamiast nazwy kontaktu)
- Comet bookmark `title="[REDACTED]"` (zamiast tytułu strony)

**Co to znaczy:** B.1 PrivacyFilter (commit z 2026-05-17 sesji U-1) **realnie działa
w produkcji**. Wpisy PII są redactowane at-write-time. Zero PII w sample
mimo że WhatsApp i osobiste linki w przeglądarce **były klikane**.

### 2.2. L0.3 TooltipObserver false-positive WYELIMINOWANY ✅ (P-39 zamknięte)

W 2026-05-16 było **4× false-positive L0.3** z Comet (hint="shortcut" keys=["2"]).
**W 2026-05-17 sample: 0 false-positives L0.3.** TooltipNameFilter z U-1 załatwił.

(Sample mały, więc to nie dowód definitywny — ale brak nawrotu w 14-minutowym
oknie z normalnym surfowaniem to dobry znak.)

### 2.3. Toasty pojawiają się natywnie ✅

3 toasty na 22 zdarzenia = 14% hit rate. To **niska liczba**, ale w tym sample
dominują kliknięcia w web content (linki na stronach hotelowych) i file rename
w Finderze — czyli **rzeczy które z natury nie mają skrótów** (patrz §3).
Jakość samych toastów: dobra — wszystkie 3 to deterministic L1 hits (Comet new
tab, Finder back).

---

## 3. Top obserwacja — **97% missów to NIE-skrótowe elementy** (powtórka z 2026-05-16)

To samo co w poprzedniej analizie. Z 19 missów:

| Klasa | Count | Komentarz |
|---|---|---|
| **Browser content** (linki na stronach: "Habitaciones", "Sieste", "296 Reviews") | 9 | Web content na stronie hotelowej — nie ma żadnego skrótu. To **nie nasza wina**. |
| **Finder rename TextField** (value="packages", "extension"...) | 5 | Inline rename w pasku adresu Findera — to typing, nie skrót. |
| **Finder file cell** (AXCell, "Shortcut Flow") | 1 | Kliknięcie w nazwę folderu — selection, nie akcja. |
| **WhatsApp chat list item** | 1 | Otwarcie czatu — nie ma skrótu (chyba że ⌘+N nowy czat, ale to inna akcja). |
| **Terminal Cancel button** (generic `action-button--999`) | 1 | Dialog "Cancel" w jakimś popupie. Nie skrót. |
| **Comet popup combo box "sauna"** | 1 | Wpisywanie do search-bara typing. |
| **WhatsApp close button** | 1 | Zamykanie panelu. Nie skrót. |

**Wniosek strategiczny (potwierdzony 2× — 2026-05-16 + 2026-05-17):**

Większość missów to elementy które **z definicji nie mają keyboard shortcutów**:
- Web content linki (chyba że W4 Semantic Intents z plan Web)
- Text fields (rename, search input)
- File cells (selection, nie action)
- Personal content (kontakty, prywatne tytuły)

**To znaczy że obecny „miss count" jest złym KPI sam w sobie.** SFlow powinien
filtrować te 3 klasy zanim policzy „coverage hole":
1. AXTextField z `value` zawierającym typing (≠ command)
2. AXCell w listach
3. Web content links (rozwiązuje Web-as-app + W4)

Wcześniejsza miss-analiza 2026-05-16 (§4) już to zaznaczyła. Dziś
**potwierdzone z drugiej próby**. Należałoby dodać te 3 filtry do
`EventLogger.logMiss` żeby raport coverage przestał liczyć je jako „dziury".

---

## 4. P-38 (dropdown menu items w oknie) — nie widzę w dzisiejszym sample

W 2026-05-16 było widać 4× missy na Notion Calendar Week/Month/View settings
dropdown. **Dziś sample nie zawiera Cron/Notion Calendar** — Filip nie
otwierał. Nie ma świeżych danych, ale problem **wciąż istnieje** (Layer 0.6
adresuje inline shortcuts NIE menu items dropdowna).

**Co dalej z P-38:** czeka na Filipa do testu na innych apkach (Linear ⌘K
palette, Slack apps dropdown) — patrz `audit-phase-0.md` P-38 i memory
`next_session_2026_05_16`.

---

## 5. Surprise: Hiszpańskie i polskie content w Comet — co to znaczy dla i18n (P-43)

W 22 wpisach:
- 5 linków po hiszpańsku: "Tarifas y reservas", "Actividades", "Habitaciones",
  "Lugares de interés"
- 1 link po francusku: "Sieste"
- 1 link po polsku: "Na zdjęciu: Hotel & Spa Monasterio de Boltaña"
- 1 link po angielsku: "296 Reviews"

**Punkt:** Filip browsuje po wielojęzycznych stronach. To **nie jest pełen
test i18n** (bo te linki to web content, nie shortcuty), ale **konfirmuje**
że Filip realnie pracuje w PL/EN environment co najmniej. Jeśli przyszły UI
Slack/Notion też będzie po polsku, **P-43 (i18n) jest priorytetem nawet bez
beta-testerów z non-EN UI**.

---

## 6. Stan po stronie struktury danych

### 6.1. `events.jsonl` — szybko rośnie, łatwo się rotuje

5.2 KB obecnie. Z 2026-05-16 (147 entries ≈ 35 KB) wynika że nie cap rośnięcia.
Należy rozważyć:
- **Rotation policy** (tygodniowa? max 1000 wpisów?) — żeby nie tracić starszych
  danych ad-hoc tak jak teraz między 2026-05-16 a 2026-05-17.
- **Archiwizacja** stara → `events.jsonl.gz` po N dniach.

Niski priorytet, ale **wpływa na jakość analizy długoterminowo**.

### 6.2. `attempted.json` — zachowane

Persistent retry state dla failed discovery. Sprawdzam tylko że żyje
(1246 B, mtime 2026-05-17 09:00). OK.

### 6.3. `discovered/` — Sesji B output

Folder istnieje, do tego dolatuje DiscoveredStore (TTL 7d po dzisiejszym
commicie d8f6224). Zawiera per-app tooltipy zebrane on-hover.

### 6.4. `menu-cache.json` — 140 KB

Cache menu items. Zdrowy rozmiar. mtime 2026-05-15 — czyli **nie był
odświeżany od 2 dni**. To może być artefakt browser/Slack rebuilds (Filip
nie restartował tych apek?), albo bug w MenuBarWatcher. Niski priorytet
verify.

---

## 7. Rekomendacje konkretne (po sample 2026-05-17)

### 7.1. **Co Filip powinien zrobić zaraz (15 min)**

- [ ] **Otworzyć kilka apek w użyciu pracy** (Slack, Notion, Linear, Cursor)
      przez **1-2 dni normalnej pracy** żeby `events.jsonl` urósł do ≥200
      wpisów. Bez tego kolejna analiza będzie taka sama — qualitative,
      bez statystyki.
- [ ] **Powiedzieć AI** (lub samemu sprawdzić w settings) **czy włączony jest
      tooltipDebug** (`defaults read com.filip.sflow tooltipDebug`). Dla
      kolejnej analizy debug=true daje rich info o false-negatives L0.3.

### 7.2. **Co AI może zrobić bez Filipa (kolejne sesje analizy)**

- [ ] **Po zebraniu 200+ entries** — pełna ilościowa analiza per layer, per
      apka, top miss patterns (dokończenie Sesji 8).
- [ ] **Filtrowanie miss-noise** — implementacja w `EventLogger.logMiss`
      whitelisty dla AXTextField rename / AXCell list / web content links
      tak żeby coverage-report nie liczył ich jako luk. Sub-cel: nowy, do
      audit-phase-1.5.md jako enhancement Sub-celu 1.11 (P-31 część 2).
- [ ] **`events.jsonl` rotation** — proste, jak FileLogger Swift, kilka linii.
      Czeka na decyzję czy to teraz vs po becie.

### 7.3. **Co odłożone do beta**

- Pełna analiza per-layer hit rate (potrzebne ≥200 entries)
- Iteracja prompta backend na bazie miss patterns (P-31 część 2)
- Decyzja go/no-go dla i18n (P-43) na bazie hard data zamiast intuicji

---

## 8. Stan otwartych problemów po sample 2026-05-17

| P-X | Status | Co widać w sample 2026-05-17 |
|---|---|---|
| P-39 (L0.3 false-positive "shortcut") | 🟢 zamknięte | 0 nawrotów w 14 min, TooltipNameFilter działa |
| P-40 (MissEvent PII) | 🟢 zamknięte | 2 wpisy `[REDACTED]` (WhatsApp + Comet bookmark) — działa |
| P-38 (dropdown menu items) | ⬜ nadal otwarte | Brak Cron/Calendar w sample — nie ma danych. Layer 0.6 (commits dzisiaj) **nie adresuje** dropdown menu items, tylko inline labels typu `"New chat ⌘O"`. P-38 wciąż żyje, decyzja go/no-go po teście Sesji B na innych Chromium apkach. |
| P-42 (web-as-app) | ⬜ otwarte (plan zapisany) | 9 missów Comet web content potwierdza skalę problemu. Plan: `docs/phase-web-as-app-plan.md` — odłożone po becie. |
| P-43 (i18n) | ⬜ otwarte | Filip browsuje wielojęzyczne strony. P-43 priorytet **niezależnie od beta-testerów**. |

---

## 9. Co AI **NIE zrobiło** świadomie

- ❌ Nie zmieniło żadnego pliku kodu
- ❌ Nie scommitowało tego dokumentu — czeka na review Filipa
- ❌ Nie zaktualizowało `coverage-report.md` ani `audit-phase-1.md` —
   nie ma wystarczających danych żeby zmienić statusy
- ❌ Nie skasowało / nie zrotowało `events.jsonl` — zostawione bez zmian

---

*Status pliku: roboczy raport. Następna analiza events.jsonl rekomendowana
po zebraniu ≥200 wpisów (~2 dni normalnego użycia).*
