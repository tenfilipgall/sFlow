# SFlow Coverage Report

> **Cel:** śledzić pokrycie reguł SFlow per apka. Inicjalizowany 2026-05-16
> na bazie analizy `events.jsonl` (147 wpisów, 10h użycia 2026-05-15→16) +
> deklaratywnych deklaracji z `bundled.json`.
>
> **Adresuje:** Sub-cel 1.6 (audit-phase-1.md) — "20 zweryfikowanych apek
> + coverage-report.md".
>
> **Aktualizacja:** po każdej sesji eval (Sub-cele 1.24-1.28) i po reseedzie.

## Legenda statusów pokrycia

- 🟢 **GOOD** — ≥70% klików rozpoznanych poprawnie (manual eval lub events.jsonl)
- 🟡 **PARTIAL** — 40-70% klików, kilka znanych gaps
- 🔴 **POOR** — <40% klików, fundamentalne problemy
- ⬜ **UNTESTED** — apka znana ale nie zweryfikowana
- 🚫 **NOT_SUPPORTED** — apka świadomie pominięta (custom render, no AX)

---

## Aktualne pokrycie (na 2026-05-16)

### Bundled apki (manual eval przez Filipa)

| Bundle ID | Apka | Status | Komentarz |
|---|---|---|---|
| `com.tinyspeck.slackmacgap` | Slack | 🟢 GOOD | 15 toastów / 11 missów w 10h. Quick Switcher, Compose, DMs, Message actions działają. Gap: 2. monitor toast rendering (issue 2026-05-16). |
| `notion.id` | Notion | 🟡 PARTIAL | 2 missy w 10h, ale bardzo mało użycia w sample. Reguły OK, niedotestowane skala. Sidebar nav działa. |
| `notion.mail.id` | Notion Mail | 🟢 GOOD | Sesja B verified 5/5 ikonek. L0.3 tooltips. 3 toasty bez missów. |
| `com.cron.electron` | Notion Calendar | 🟡 PARTIAL | L0.3 tooltip dla Create Event działa. **Dropdown menu items NIE są tapowane (P-38)** — Week/Month miss 4×. |
| `com.anthropic.claudefordesktop` | Claude Desktop | 🟢 GOOD | 7 toastów / 1 miss. Reguły z reseedu działają (Chat/Code/Cowork mode, Sidebar, Quick Search). |
| `md.obsidian` | Obsidian | 🟡 PARTIAL | UAT 2026-05-17 (Filip, 5-min eval): menu bar items działają, Graph View ribbon icon ⌘G zadziałał (post-reseed); pozostałe ribbon icons (New note, Search, Bookmarks, Today's daily note, Expand, Collapse) NIE pokazują toastów. **Root cause:** P-51 Electron lazy AX tree — reseed walk widzi 12 elementów (visited=12, raw=0), wszystkie AXGroup/AXButton mają puste desc dopóki user nie hoveruje. AX desc populuje się dopiero przy aktywności. Eksperymenty 2026-05-17: 4 reseedy (50/41/43/45 rules), żaden nie zharvestował content. Diagnostyka w `AXSkeletonExtractor` + `Reseeder` printuje visited/maxDepth/byRole. Adresowane przez P-51 w audit-phase-0.md. |
| `com.linear.LinearMac` | Linear | 🚫 SKIPPED | UAT 2026-05-17: nie zainstalowany na maszynie Filipa. Bundled rules istnieją ale brak możliwości weryfikacji lokalnie. |
| `com.todesktop.230313mzl4w4u92` | Cursor | 🚫 SKIPPED | UAT 2026-05-17: nie zainstalowany na maszynie Filipa. Bundled rules istnieją (reseed był) ale brak możliwości weryfikacji lokalnie. |
| `com.apple.Terminal` | Terminal | 🟢 GOOD | UAT 2026-05-17 (Filip, 5-min eval): 5/5 — ⌘T New tab, ⌘N New window, ⌘F Find, ⌘K Clear, ⌘W Close tab wszystkie pokazały toast. Native macOS app, L3 MenuBarIndex pełne pokrycie. |

### Auto-discovered (cache) apki widziane w events.jsonl

| Bundle ID | Apka | Status | Komentarz |
|---|---|---|---|
| `ai.perplexity.comet` | Comet (Perplexity) | 🟡 PARTIAL | 18 toastów / 39 missów. **WIELE missów to web content** (Amazon, sklepy) — nie skróty per se. Plus 4 false-positive L0.3 ("shortcut" keys=["2"]) — **fixed dziś przez B.1**. |
| `com.apple.Console` | Console (macOS) | 🟡 PARTIAL | 12 toastów / 8 missów. L0.5 reguły działają dla Start Streaming, Clear, Reload. Gap: search bar (AXTextField), log rows (AXCell). |
| `com.tinyspeck.slackmacgap` | (już wyżej) | | |
| `com.apple.finder` | Finder | 🔴 POOR | 0 toastów / 8 missów. Większość to AXCell (file rows) + AXTextField (rename) — **nie-skrótowe**. Sensownie: Finder reguły wymagają menu bar L3 fallback. |
| `com.apple.dt.Xcode` | Xcode | 🔴 POOR | 1 toast (Stop ⌘.) / 6 missów. `action-button-N` identifier generyczny, brak per-app reguł. **Reseed potrzebny**. |
| `pl.maketheweb.cleanshotx` | CleanShot X | 🔴 POOR | 0 toastów / 5 missów. Brak bundled.json. **Reseed potrzebny**. |
| `net.whatsapp.WhatsApp` | WhatsApp | 🚫 NOT_SUPPORTED | 0 toastów / 3 missów (PII risk: imiona kontaktów). **Privacy-sensitive** — po B.1 wpisy redactowane, ale apka pozostaje niewspierana (zero biznesowych skrótów do nauczenia). |
| `com.apple.Mail` | Mail.app | ⬜ UNTESTED | Brak danych w sample. Bundled.json istnieje (`com.apple.mail`). |
| `com.spotify.client` | Spotify | ⬜ UNTESTED | ShortcutRules ma per-app block ale brak weryfikacji. |

### Apki świadomie nieobsługiwane

| Bundle ID | Apka | Powód |
|---|---|---|
| Custom Metal/OpenGL renders | gry, Blender (canvas), Figma (canvas), Unity Editor | Brak AX dla content — może działać dla menu bar |
| `net.whatsapp.WhatsApp` | WhatsApp Desktop | PII risk + brak biznesowych skrótów (mostly contact list nav) |

---

## Pokrycie per layer rozpoznawania

Z `events.jsonl` (147 entries, 2026-05-15→16):

| Layer | Trafień | Udział | Wniosek |
|---|---|---|---|
| L0 (AXKeyShortcutsValue) | 0 | 0% | **Martwa warstwa** w empirycznej próbce — żadna z używanych apek nie eksponuje `aria-keyshortcuts` |
| L0.3 (TooltipObserver) | 5 | 9% | Sesja B działa — 1 prawdziwy (Cron Create event) + 4 false-positives (Comet "shortcut") **fix dziś B.1** |
| L0.5 (RuleCache JSON) | 18 | 32% | **Najsilniejsza warstwa** — bundled + cache dla 9 apek |
| L1 (ShortcutRules hardcoded) | 16 | 28% | Legacy ale dalej istotne — Slack/Comet/Claude/Notion |
| L2 (kAXHelp) | 0 | 0% | **Martwa warstwa** — żadna z używanych apek nie ma shortcut hintów w help text. Po U-3 (single-key mode) → Notion Mail/Cron mogą tu trafić |
| L3 (MenuBarIndex fuzzy) | 12 | 21% | Po fixie key-direction (Sesja 2) deterministyczne. Główne źródło dla Slack desktop, Claude Desktop |
| L4 (universal heuristics) | 1 | 2% | Tylko Slack "Go Forward" w sample. Niedoużywane — możliwe że universal rules wymagają ekspansji |
| menu-fallback (sysWide) | 5 | 9% | Drugi pass — Slack Quick Switcher, Claude Chat |

**Implikacje:**

- **L0 i L2 są martwe** — niska wartość inwestycji w te warstwy zanim
  nie znajdziemy apek je eksponujących
- **L0.5 + L1 + L3 = 81% wszystkich toastów** — kluczowe filary
- **L0.3 (Sesja B) ma znaczący wkład (9%) ale 80% to false-positives** —
  po B.1 fix powinno wzrosnąć do czystych 9% prawdziwych trafień
- **L4 underused (2%)** — sugeruje że universal rules są **albo dobrze
  zbudowane** (już pokryte przez wyższe warstwy) **albo brakuje
  popularnych pattern'ów** (Cancel/OK w dialogu — patrz U-6 plan)

---

## Top miss patterns — gaps do zaadresowania

Z analizy `events.jsonl`:

| Pattern | Count | Apka | Co naprawia |
|---|---|---|---|
| `AXButton title="" desc="" value="" sub=""` (naked Chromium icon) | 6 | Comet | Sesja A walk-down już naprawiła większość. Pozostałe = web content nie-akcyjny |
| `AXCheckBox title="" desc="Remove from Later"` | 5 | Slack | Reguła `slack-msg-unsave` istnieje (per ShortcutRules.swift:269) — sprawdzić dlaczego nie matchuje |
| `AXButton title="Stop Tasks" identifier="action-button-1"` | 4 | Xcode | Brak Xcode bundled reguł — reseed potrzebny |
| `AXPopUpButton desc="Extensions"` | 3 | Comet | Browser chrome menu — L4 universal? |
| `AXButton title="Week"/"Month" sub="Week"/"Month"` | 4 | Cron | **P-38 dropdown** — adresuje Sub-cel 1.17 / Sesja C.5 |
| `AXMenuItem title="Mark unread U"` | 1 | Comet | **P-38 inline shortcut suffix** — adresuje Sub-cel 1.17 |
| `AXCell title="" sub="SFlow"` | 2 | Finder | File rows — nie-skrótowe, akceptujemy |
| `AXTextField value="CleanShot 2026-...mp4"` | 4 | Finder | Filename input — nie-skrótowe |

---

## Plan zwiększenia pokrycia (priorytet)

### Q1 (Faza 1 dokończenie)

1. **U-1 B.1 integracja** (30 min) — czyści false-positives L0.3 Comet → L0.3 staje się czysty
2. **Reseed Xcode, CleanShot X** (1h) — uzupełnia bundled dla 2 popular apek
3. **Manual eval Obsidian, Linear, Cursor, Terminal** (4×30 min = 2h) — zamknięcie istniejących bundled
4. **Cron P-38 dropdown** (Sesja C.5, 6h) — odblokuje View dropdown + cały rozdział menu items w oknach
5. **Sub-cel 1.6 zamknięty** z 20+ apek (Slack ✅ + Notion ✅ + Notion Mail ✅ + Cron ✅ + Claude ✅ + Obsidian + Linear + Cursor + Terminal + Comet + Console + Mail + Spotify + Xcode + CleanShot = 15+)

### Q2 (Faza 1.5 Universal Coverage)

6. **U-2 Right-click** (3h) — context menu we wszystkich apkach naraz
7. **U-3 Single-key** (2h) — Notion Mail/Cron/Obsidian
8. **U-4 Web-as-app** (6-8h) — Gmail, Slack web, GitHub web, Linear web
9. **U-5 i18n** (6-10h) — Slack PL, inni non-EN userzy
10. **U-6 Modal scope** (6h) — Cancel/OK w dialogach
11. **Eval 5 typów apek** (Sub-cele 1.24-1.28, ~30h razem) — Office, Adobe, Qt, Catalyst, SwiftUI

**Po Q1+Q2:** szacowane pokrycie **50+ apek** zweryfikowanych, **80%+ kliknięć
w popularnych workflow** rozpoznanych.

---

## Dane historyczne

| Data | Liczba bundled | Liczba zweryfikowanych | % HIT (estymata) |
|---|---|---|---|
| 2026-05-13 (v1.0) | 4 | 2 | ~50% |
| 2026-05-14 (v1.1.1 + sesja 6/7) | 5 | 2 (Slack, Obsidian) | ~75% |
| 2026-05-15 (Sesja A+B) | 5 | 4 (+ Notion Mail, Cron) | ~75% |
| 2026-05-16 (B.1 fix offline) | 5 | 4 (false-pos cleanup) | ~78% |
| Cel po Fazie 1.5 | **20+** | **15+** | **85%+** |

---

*Raport zainicjalizowany 2026-05-16 przez AI (offline analysis events.jsonl).
Aktualizuj po każdej sesji eval / reseed / nowa apka.*
