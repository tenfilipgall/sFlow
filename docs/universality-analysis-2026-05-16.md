# Co działa uniwersalnie, co per-apka — analiza 2026-05-16

> **Autor:** AI (asystent), na prośbę Filipa "czy fix-y wdrażane na Comet/Slack/
> Notion Mail/Notion/Notion Calendar są uniwersalne".
>
> **Cel:** mapować każdy mechanizm rozpoznawania SFlow po wymiarach
> **uniwersalny vs per-app** oraz **z regułami vs bez**, żeby decydować dokąd
> inwestować dalej.

---

## 1. TL;DR (2 zdania)

**Wszystkie 7 warstw rozpoznawania + wszystkie fix-y AX są pod spodem uniwersalne** —
mechanizm działa na każdej apce. **Per-apka są tylko *dane*** (reguły hardcoded
w `ShortcutRules` i JSON cache w `RuleCache`); 4 warstwy w ogóle nie potrzebują
reguł (L0, L0.3, L2, L4) — działają same na atrybutach AX.

---

## 2. Mapa warstw — uniwersalność mechanizmu vs dane

Każdy klik przechodzi przez tę sekwencję w `ClickWatcher.handleMouseDown`:

| # | Warstwa | Mechanizm | Skąd dane | Bez reguł? |
|---|---|---|---|---|
| L0.3 | TooltipObserver | **UNIWERSALNY** — skanuje drzewo AX na hoverze, łapie React-portal tooltipy | Każda apka renderująca tooltipy z parą (nazwa, skrót) — Notion Mail, Cron, Notion Calendar (zweryfikowane) | **✅ TAK** — żadnych reguł, tylko hover |
| L0 | `AXKeyShortcutsValue` | **UNIWERSALNY** — czyta atrybut `aria-keyshortcuts` z elementu | Apka musi sama ustawić aria-keyshortcuts. Gmail, Notion czasem | **✅ TAK** — atrybut zawiera skrót wprost |
| L0.5 | `RuleCache.match` (JSON) | **UNIWERSALNY** matcher | **Per-app** — `bundled/{bundleId}.json` (manual) lub `cache/{bundleId}.json` (LLM Claude) | ❌ NIE |
| L1 | `ShortcutRules.match` | **UNIWERSALNY** matcher | **Per-app** — hardcoded dict 10 apek (Slack/Notion/Linear/Claude/Comet/Mail/Finder/Cron/NotionMail/Spotify) | ❌ NIE |
| L2 | `kAXHelp` + `parseShortcut` | **UNIWERSALNY** — parsuje help text 3 strategiami ("⌘K", "e", "(E)") | Apka musi mieć skrót w help text | **✅ TAK** — heurystyka tekstu |
| L3 | `MenuBarIndex.lookup` | **UNIWERSALNY** matcher fuzzy | Menu bar bieżącej apki (read na żywo) | **✅ TAK** (jeśli menu bar ma akcję z tym samym tytułem) |
| L4 | `universalRules` | **UNIWERSALNE reguły** — ~30 heurystyk semantycznych | Hardcoded, ale dla **każdej apki** ("AXSearchField → ⌘F", "AXButton desc='back' → ⌘←") | **✅ TAK** — reguły same są uniwersalne |
| fallback | `checkMenuBar` sysWide | **UNIWERSALNY** — drugi pass jeśli app-level walk nic nie złapał. Czyta `kAXMenuItemCmdChar` natywnie | Menu items o ile macOS je eksponuje | **✅ TAK** — atrybut native |

**Wniosek:** 6 z 8 warstw to **mechanizmy zero-reguł** — działają z dnia 0 na nowej apce. Tylko L0.5 i L1 wymagają wcześniejszej wiedzy o apce.

---

## 3. Fix-y AX z `ClickWatcher` — wszystkie uniwersalne

| Fix | Co robi | Sesja | Dla kogo działa |
|---|---|---|---|
| `AXManualAccessibility + AXEnhancedUserInterface` | Wymusza Chromium/Electron żeby eksponował drzewo AX | wcześnie | **wszystkie** Chromium/Electron apps (no-op na native) |
| 6-poziomowy walk po rodzicach | Klik w SVG → znajdź pierwszy klikalny rodzic | wcześnie | wszystkie |
| Multi-monitor coord (`NSScreen.screens[0]`) | Współrzędne AX z menu-bar-screen, nie main | wcześnie | wszystkie multi-monitor |
| `AXPress` probe | Element z akcją AXPress → klikalny niezależnie od role | Sesja 7 | wszystkie (Chromium szczególnie) |
| `extractFallbackTitleFromChildren` (1-level recurse) | Pusty title/desc → schodzi do dzieci po pierwszą niepustą labelkę | Sesja A | wszystkie (Chromium szczególnie) |
| `kAXValue` fallback dla static-text-like | AXStaticText/AXLink/AXImage trzymają tekst w `value`, nie `title` | Sesja A | wszystkie |
| Word-boundary matching (RuleCache) | "search" nie matchuje w "research" | Sesja 6 | wszystkie |
| Depth gate (L0.5/L1 nie strzelają na rodzicach) | Eliminuje fałszywe matche na AXWindow/AXScrollArea | Sesja 6 | wszystkie |
| MenuBarIndex deterministyczność | Sort longest-key-first | Sesja 6 | wszystkie |
| AX-tap re-enable + heartbeat | Tap nie umiera po timeout | wcześnie | wszystkie |
| Cap 100 znaków na kAXValue jako label | Nie wciągamy textarea content | Sesja A | wszystkie |
| Cap 500 elementów menuBar/skeleton | Backend Zod max — Android Studio fit | Sesja 8 | wszystkie |
| `kAXMenuItemCmdChar/CmdModifiers` native parsing | Skrót z menu items macOS | wcześnie | wszystkie z natywnymi menu |
| **TooltipNameFilter** (banned + whitelist) | Odrzuca "shortcut"/"hotkey" jako nazwy | dziś (B.1) | wszystkie |
| **PrivacyFilter** (redact at write-time) | Imiona/karty/emaile zamazane przed dyskiem | dziś (B.1) | wszystkie |

**Wniosek:** **wszystkie fix-y są bundle-agnostic**. Nie ma żadnego `if bundleId == "..."` w pipeline'ie rozpoznawania. Jedynie **dane** są per-app.

---

## 4. Pokrycie empiryczne — co testowaliśmy na czym

| Apka | Bundle ID | Główny typ | Co empirycznie potwierdza |
|---|---|---|---|
| **Slack** | `com.tinyspeck.slackmacgap` | Electron | L1 reguły (30+), menu bar L3, AXManualAccessibility, P-5 (MenuBarIndex direction), P-23 (within-rule dedup), `slack-msg-*` desc-based |
| **Notion Mail** | `notion.mail.id` | Electron Chromium | **Sesja A** (kAXValue fallback, walk-down children, depth=0 gate usunięty) + **Sesja B** (TooltipObserver — 5/5 ikonek) |
| **Notion main** | `notion.id` | Electron Chromium | L1 sidebar nav, L0.5 cache, fallback children Chromium |
| **Notion Calendar (Cron)** | `com.cron.electron` | Electron Chromium | **Sesja B** split-badge parser ("⌘", "\\" jako 2 osobne static-text), **P-38** dropdown items niewidoczne |
| **Comet (Perplexity)** | `ai.perplexity.comet` | Chromium browser | L1 reguły (browser nav), L0.3 false-positive "shortcut" odkryty (dziś B.1 naprawiony) |

**Co wynika z tego pokrycia:**

- **Chromium/Electron** (4 z 5) — większość fix-ów Sesji A i B była robiona empirycznie na tych apkach
- **Browser** (Comet) — pokrywa "web content as click target" use case
- **Brak testów native macOS** — w danych mamy missy z Xcode/Console/Finder/CleanShot ale **nie robiliśmy targetowanych sesji**. To luka empiryczna.

---

## 5. Co inne apki dostają "za darmo"

Skoro mechanizmy są uniwersalne, każdy nowy bundle ID dostaje:

### 5.1. Bez żadnej pracy ze strony SFlow

- **L0** AXKeyShortcutsValue — jeśli apka ma `aria-keyshortcuts` (zachodnie web apki, Gmail, Google Docs)
- **L0.3** TooltipObserver — jeśli apka renderuje React-portal tooltipy z parą (nazwa, klawisz) i te tooltipy żyją w drzewie AX
- **L2** kAXHelp parsing — jeśli apka ma skróty w pomocy
- **L3** MenuBarIndex — jeśli apka ma standardowe menu bar
- **L4** universal rules — search/back/forward/new/print/settings/send/compose/reply

### 5.2. Po reseedzie przez backend Claude

- **L0.5** JSON rules — Claude generuje ~20-60 reguł per apka, ~$0.05 i 30 sekund

### 5.3. Tylko po manual editing

- **L1** ShortcutRules.swift — wymaga ręcznego dopisania bloku per-bundleId

---

## 6. Wnioski dla różnych klas apek

### 6.1. Inne Electron/Chromium apki

**Discord, Linear, VSCode, Cursor, GitHub Desktop, Postman, Obsidian, Claude Desktop:**

Powinny dostać **za darmo** (zero dodatkowej pracy):
- AXManualAccessibility forcing → drzewo AX dostępne
- Walk-down children + kAXValue → ikonki bez aria-label rozpoznawane
- TooltipObserver → jeśli renderują React tooltipy z parą (nazwa, klawisz)
- L4 universal heuristics → search/back/forward działa

**Zostaje do sprawdzenia empirycznie:**
1. **Czy renderują tooltipy w drzewie AX?** — Linear, Discord nie były testowane. Cron+Notion Mail TAK.
2. **Czy mają dropdowny inline-shortcut?** — P-38 (Cron Week/Month, Comet AXMenuItem) confirmed. Discord context menu, Linear ⌘K też.

**Ryzyko:** **L1 reguły dla Slack-msg-* mogą NIE działać dla Discord** mimo identycznego patternu hover-toolbar. Bo Slack ma `kAXDescription="save for later"`, Discord może mieć inny string. Dlatego mamy `messageActions(...)` helper który ułatwia DRY dopisanie reguł per-app.

### 6.2. Inne Chromium-based browsers

**Chrome, Edge, Brave, Arc, Safari (jeszcze):**

- L1 reguły **Comet** (`comet-back`, `comet-new-tab`, `comet-forward`) **NIE działają** w innych browserach (per-bundle scoping). Trzeba osobne reguły lub:
- **Universal browser rules dropping bundle prefix** — można rozszerzyć L4 o "AXButton desc='reload' → ⌘R" jeśli to nie jest już tam. (Sprawdzam: `universal-reload` JEST w L4 — czyli browsers DZIAŁAJĄ).
- AXKeyShortcutsValue powinien czasem zadziałać (web pages z `aria-keyshortcuts`)

**Wniosek:** L4 universal rules **już dziś** pokrywa większość przeglądarkowych skrótów. Slack/Notion specific nie potrzebują dopisania per-browser.

### 6.3. Native macOS apki (NIETESTOWANE)

**Xcode, Mail, Finder, Safari, Console, CleanShot X, Notes, Reminders, System Settings:**

W danych `events.jsonl` mamy missy z **Finder (8), Console (8), Xcode (6), CleanShot (5)** ale **nie była robiona targetowana sesja**.

**Co działa za darmo:**
- L3 MenuBarIndex — apple apki mają bogate menu bary
- `checkMenuBar` sysWide fallback — wyłącznie dla AXMenuItem
- L4 universal — search/back/forward działają

**Co NIE działa:**
- TooltipObserver — natywne tooltipy są w `kAXHelp` (już używamy w L2), **nie** w floating AXGroup
- Walk-down children — natywne apki dobrze eksponują labelki, fix nie ma co znaleźć
- AXManualAccessibility — no-op (już mają dostępne drzewo)

**Wniosek:** native apki powinny **być pokryte przez L2 (kAXHelp) + L3 (menu bar) + L4 (universal)**. Jeśli nie są — to znaczy że apka **NIE umieszcza skrótu w żadnym z tych miejsc**, czyli używa np. niestandardowego sposobu (Xcode `action-button-N` identifier — generyczne).

**Akcja zalecana:** dodać Xcode/Mail/Finder do bundled.json przez reseed (Sesja 9b). Backend Claude wygeneruje L0.5 reguły, manual eval potwierdzi.

### 6.4. Apki z dropdown menu (P-38) — uniwersalne ALE niepokryte

**Każda apka z dropdownem otwieranym z okna:**
- Notion Calendar Week/Month (confirmed miss)
- Comet AXMenuItem "Mark unread U" (confirmed)
- Linear ⌘K command palette
- Slack message context menu
- Notion slash-menu
- Chrome context menu

**Mechanizm potrzebny:** MenuItemObserver (Sesja C.5, plan istnieje). **Uniwersalny** — działa wszędzie gdzie jest AXMenu/AXMenuItem z inline-shortcut suffixem.

---

## 7. Czego brakuje (luki w uniwersalności)

### 7.1. Pattern matching tylko po stringach

`RuleCache.match` i `ShortcutRules.match` matchują **`title.contains(needle)` / `desc.contains(needle)`**. Word-boundary check pomógł (Sesja 6) ale dalej:

- Lokalizacja: Slack po polsku ma "Skomponuj" zamiast "Compose" → rule `desc: "compose"` nie matchuje. Backend prompt v1.1.1 dodaje "common localizations only when confident", ale to wymaga reseedowania.
- Identifier-based matching (P-25) dodany, ale **większość Chromium apek nie ustawia stabilnych `data-testid`** — patrz `events.jsonl`: prawie wszystkie missy mają `identifier=""` lub generyczne (`action-button-1`).

**Wniosek:** **język nie jest jeszcze prawdziwie uniwersalny.** Apki w innych językach niż angielski są pokryte tylko jeśli Claude wygenerował lokalizowane reguły.

### 7.2. TooltipObserver wymaga określonego patternu UI

- Działa tylko gdy tooltip = floating AXGroup z 2 AXStaticText (name + badge).
- **Nie działa** dla:
  - Natywnych macOS tooltipów (w `kAXHelp` — pokryte przez L2)
  - Tooltipów które renderują się **poza** drzewem AX (rzadkie, ale spotykane w niektórych React libs które używają portal-out-of-AX-tree)
  - Tooltipów które nie zawierają badge'a (tylko nazwa) — bezużyteczne dla SFlow

### 7.3. Brak warstwy "active probing"

Wszystkie warstwy są **reactive** — czekają na klik. Jedyna proaktywna to TooltipObserver na hoverze.

**Lukę pokrywa Sesja D (`--seed-app`)** — internal team only, hover-symulowany dla nowych apek. To "dev-mode" do bootstrapu bundled rules.

---

## 8. Recap — Twoja mental model

Trzymaj w głowie:

1. **Pipeline rozpoznawania jest jeden dla wszystkich apek**. Żaden `if bundleId == "slack"` w mechanizmie.
2. **Reguły są per-app**. Słownik `ShortcutRules.rules[bundleId]` + JSON cache.
3. **4 warstwy są data-free** (L0, L0.3, L2, L4) — działają dnia 0 na nieznanej apce.
4. **3 warstwy potrzebują danych** (L0.5 + L1 + L3) — odpalają tylko jeśli mamy reguły lub menu bar.
5. **Wszystkie fix-y AX z Sesji A/B/6/7/8** są uniwersalne — pomagają wszędzie, częściej w Chromium niż w native.
6. **Inne Chromium/Electron apki dziedziczą fix-y za darmo** — Discord, Linear, VSCode, Cursor.
7. **Native macOS apki** mają inne źródło danych (menu bar + kAXHelp), tam L0.3/walk-down są no-op'ami.
8. **P-38 (dropdowny) to luka uniwersalna** — niezależna od bundle ID, mechanizm jeszcze niezbudowany.

---

*Dokument zaplanowany jako odpowiedź na pytanie "co universal vs co per-app".
2026-05-16.*
