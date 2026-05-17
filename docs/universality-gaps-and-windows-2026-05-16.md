# Pełna analiza uniwersalności + Windows port — 2026-05-16

> **Autor:** AI (asystent), z prośby Filipa "co jeszcze trzeba przygotować
> żeby SFlow było uniwersalne dla wszystkich możliwych typów aplikacji?
> Czy to też będzie działać na Windows?". Tryb: `ultrathink` —
> głębokie rozumowanie zamiast podsumowania.
>
> **Powiązane:** `docs/universality-analysis-2026-05-16.md` (stan obecnej
> uniwersalności mechanizmu). Ten dokument idzie dalej i pyta:
> **czego jeszcze brakuje**.

---

## 1. Mapa Mac apek po frameworku UI (co już pokrywamy, co nie)

Ten podział determinuje **czy nasze fix-y AX w ogóle mają na co działać** —
różne frameworki UI inaczej eksponują AX tree.

| Framework UI | Apki typowe | Pokrycie SFlow | Główne źródło danych |
|---|---|---|---|
| **AppKit native** | Mail, Finder, Safari, Xcode, Console, Notes, Reminders, System Settings, Music, Photos, Pages, Numbers, Calendar, FaceTime, Messages, TextEdit, Preview | **DOBRE** | L3 menu bar + L2 help + L4 universal |
| **Catalyst (iPad-on-Mac)** | News, Stocks, Home, Voice Memos, Find My, Books, Messenger (czasem) | **NIETESTOWANE** | UIKit → AppKit translation — różny AX |
| **SwiftUI pure** | Shortcuts.app, Freeform, wiele indie apek | **NIETESTOWANE** | AX automatyczny ale "value" zamiast "title" często |
| **Electron/Chromium** | Slack, Discord, VSCode, Cursor, Linear, Notion (wszystkie), Obsidian, Figma Desktop, GitHub Desktop, Postman, Asana, Trello, Claude Desktop, Spotify, 1Password 8 | **DOBRE** (po Sesji A+B) | L0.5 cache + L0.3 tooltip + walk-down children |
| **Chromium browsers** | Chrome, Edge, Brave, Arc, Opera, Comet, Vivaldi | **CZĘŚCIOWE** | L1 reguły dla chrome UI ale **web content w środku to czarna skrzynka** |
| **Microsoft Office** | Word, Excel, PowerPoint, OneNote, Outlook | **NIETESTOWANE** | Hybrid AppKit + custom ribbon — ribbon nie jest klasycznym menu bar |
| **Adobe stack** | Photoshop, Illustrator, InDesign, Premiere, Lightroom, After Effects | **PRAWDOPODOBNIE SŁABE** | Custom rendering (część Cocoa, część Adobe runtime) — limited AX |
| **JetBrains / Java Swing** | IntelliJ, PyCharm, Android Studio, GoLand, WebStorm, RubyMine | **CZĘŚCIOWE** (Android Studio 93 reguł wygenerowanych) | Menu bar bogate (L3), główna praca |
| **Qt apps** | VLC, Krita, Wireshark, OBS, Audacity, RStudio | **PRAWDOPODOBNIE SŁABE** | Qt eksponuje AX ograniczonie, custom rendered widgets nie |
| **GTK / Tcl/Tk / wxWidgets** | GIMP, Inkscape, niektóre Python tkinter, R | **PRAWDOPODOBNIE BARDZO SŁABE** | Najmniej macOS-friendly AX |
| **Custom Metal/OpenGL renders** | Figma (canvas), Blender, Unity Editor, Unreal Editor, gry | **NIEDOSTĘPNE** | **Zero AX** dla content — tylko menu bar i toolbar |

**Konsekwencja:** SFlow dziś dobrze pokrywa ~6 z 11 frameworków. Pozostałe 5 to
realna luka — szczególnie boli Office, Adobe, Qt, Catalyst, SwiftUI bo to
**popularne, drogie apki dla power-userów** (twój target market z product-vision).

---

## 2. 15 gap-ów uniwersalności — ranked by effort × value

Każdy gap = klasa apek/sytuacji których **dzisiejsze SFlow** nie pokrywa.
Ranking: **wysoka wartość, niski koszt → najpierw**.

### Tier 1 — **DUŻY ROI, mały koszt** (zrobić w Fazie 1.5 lub 2)

#### G-1. Right-click / context menu monitoring

**Co dziś:** `CGEventTap` mask = `leftMouseDown` only. Right-click context menu
**nigdy** nie jest obserwowany.

**Co przegapiamy:** WIELE skrótów żyje w context menu — "Copy link", "Open in
new tab", "Reveal in Finder", "Save image", "Inspect". Każde z tych ma
literę access-key.

**Koszt:** ~3h. Dodać `rightMouseDown` do eventMask + special-case handler.
Context menu po right-clicku jest natychmiast widoczne jako `AXMenu` z
`AXMenuItem` children — **i te elementy mają `kAXMenuItemCmdChar` ustawione
natywnie!** Czyli nie trzeba żadnej heurystyki, AX podaje skróty wprost.

**Wartość:** ogromna — pokrywa coverage hole obecny we wszystkich apkach na raz.

#### G-2. Web-as-app: pseudo-bundleId per domain

**Co dziś:** Klikam w Gmailu w Comet → `bundleId = ai.perplexity.comet`.
Gmail i Slack web mają własne, kompletnie inne shortcuts. **SFlow widzi
oba jako "Comet"**.

**Co przegapiamy:** Gmail (j/k navigation, c compose), Slack web, Notion web,
Linear web, GitHub web, Figma web, Google Docs/Sheets/Slides. To
**ogromny rozdział** użytkowania — power-user w przeglądarce 4h/dzień.

**Koszt:** ~5-8h. Mechanizm:
- W Chromium AX tree jest `AXWebArea` z atrybutem `AXURL` (do potwierdzenia
  empirycznie — Mac AX docs niejasne)
- Alternatywa: ekstrakcja domeny z `AXTitle` okna ("Inbox — Gmail" → `gmail.com`)
- Reguły: nowy klucz `web:gmail.com` w `rules` dictionary
- Sesja podobna do "browser-context-detection"

**Wartość:** wysoka. Otwiera całą klasę web-apek bez konieczności obsługi
każdej osobno (Gmail.app, Slack Desktop) — wykrywa **logical app** w przeglądarce.

#### G-3. i18n / lokalizacja reguł

**Co dziś:** Reguły matchują angielskie stringi. "Compose" w Slack PL =
"Skomponuj". Reguła `desc: "compose"` nie matchuje.

**Co przegapiamy:** każdą lokalizację non-EN. Polski/niemiecki/francuski/
hiszpański/japoński/chiński user widzi 0% pokrycia dopóki menu bar nie zawiera
skrótu (L3 i menu bar są lokalizowane, ale to fallback nie main path).

**Koszt:** ~6-10h. Mechanizm:
- Czytać `AXLanguage` z `frontmostApplication` lub z `kAXLanguageAttribute`
  drzewa AX
- Backend prompt z explicit `userLocale: "pl"` → Claude generuje wariant
  PL + EN dla każdej reguły
- Per-locale cache: `cache/{bundleId}:pl.json`
- Albo: dodać `localizedTitles: { pl: [...], de: [...] }` do schema reguł

**Wartość:** wysoka dla non-US market (większość świata).

#### G-4. Single-key shortcut detection (Gmail/Vim mode)

**Co dziś:** Notion Mail ma single-key skróty ("C" compose). Działa **tylko
dlatego** że TooltipObserver łapie badge "C" + name "Compose". Bez tego —
Layer 2 (kAXHelp) wymaga `count > 1 || isInteractive` żeby zaakceptować
single char, co ogranicza single-key flow.

**Co przegapiamy:** Gmail jkn-navigation, Vim-style w wielu apkach (Obsidian
Vim, VSCode Vim), niektóre productivity apek.

**Koszt:** ~2h. Mechanizm:
- Whitelist apek single-key-friendly: Gmail/Notion Mail/Linear/Obsidian-vim/
  Notion (slash-menu)
- Per-app feature flag w bundled.json: `"singleKeyMode": true`
- W tych apkach Layer 2 akceptuje single char nawet na non-interactive

**Wartość:** średnia, ale **bardzo czysty mental model dla usera** ("ta apka
ma jednoznakowe skróty, ucz mnie ich").

#### G-5. AXMenu w window (P-38) — MenuItemObserver

**Status:** plan istnieje (`docs/superpowers/plans/2026-05-16-menu-item-observer.md`).
**Koszt:** ~6h. **Wartość:** wysoka — pokrywa P-38 we wszystkich apkach.

(Już wymienione w `audit-phase-1.md` Sub-cel 1.17 — wymieniam tu dla kompletności.)

---

### Tier 2 — **WYSOKA wartość, średni koszt** (Faza 2)

#### G-6. Keystroke monitoring — wykrywanie "user się nauczył"

**Co dziś:** SFlow widzi tylko kliki myszką. Jeśli user opanował ⌘K
w Slack — SFlow **dalej pokazuje toast** przy każdym kliku w search.
Spam-friendly.

**Co przegapiamy:** sygnał "ten user już używa ⌘K — przestań przypominać".
Bez tego nie ma "progress mode" (droga B w product-vision).

**Koszt:** ~10-15h. Mechanizm:
- Drugi CGEventTap z mask `keyDown` (wymaga **drugiej** Input Monitoring
  permission)
- Per-shortcutId license: zwiększa licznik gdy klawiatura, gdy kliknięcie
  pokazuje toast (lub spada do mniejszego badge'a)
- Wymaga **stanu pamięci** (UserDefaults / SQLite per shortcutId × frequency)

**Wartość:** krytyczna dla product-vision drogi B. Bez tego SFlow jest
**diagnostykiem**, nie **trenerem**.

**Risk:** druga permission — user może odmówić; cały feature degraduje
gracefully (jeśli nie ma keystroke monitoring, SFlow działa jak dziś).

#### G-7. Modal/sheet/dialog context detection

**Co dziś:** Klik w przycisk "Open" w dialogu Save — SFlow widzi tylko
przycisk, nie wie że jesteśmy w dialogu. Reguła może odpalić niewłaściwie.

**Co przegapiamy:** scoping reguł. "Bold" w edytorze ≠ "Bold" w dialogu
formatowania.

**Koszt:** ~6h. Mechanizm:
- Czytać `AXFocusedWindow` w czasie kliku
- Sprawdzać `AXRole` na window: `AXSheet`/`AXFloatingWindow`/`AXSystemDialog`
- Dodać `scope: ["AXSheet", "AXTextField"]` do schema reguł
- Reguły filtrowane przez scope match

**Wartość:** średnia — eliminuje false-positives w specific case'ach.

#### G-8. Tool/mode switching w kreatywnych apkach

**Co dziś:** Figma toolbar ma narzędzia (move/rectangle/text/pen) z literami
V/R/T/P. Klik w ikonkę narzędzia → SFlow pokazuje toast tylko **jeśli ma
regułę** dla Figmy. Reguł dla Figmy dziś **nie ma**.

**Co przegapiamy:** całe creative tools. Photoshop B (brush), V (move),
M (marquee). Każde to single key. Linear, Asana, Trello mają boards z
narzędziami selekcji.

**Koszt:** ~5h dla mechanizmu uniwersalnego:
- AXToolbar role detection w drzewie
- Toolbar children to AXButton z desc = nazwa narzędzia
- Per-toolbar tooltip scan (L0.3 + single-key whitelist)

**Wartość:** wysoka dla creative power-userów (Figma/Sketch/PS user
to często $50+/mc pricing tier).

#### G-9. URL-based version detection per apka

**Co dziś:** Cache key = `bundleId:major.minor`. Notion zmienia UI w patch
(0.0.x) i reguły psują się cicho.

**Co przegapiamy:** automatic re-discovery po zmianie struktury UI.

**Koszt:** ~4h. Mechanizm:
- Hash UI skeleton (top-50 elements role+title) jako fingerprint apki
- Jeśli fingerprint zmienił się o >30% od ostatniego discovery → trigger
  refresh
- Notification dla usera "Notion looks different — re-detecting"

**Wartość:** wysoka **długofalowo** — bez tego reguły dziedziczone z 2 miesięcy
temu są coraz bardziej nieaktualne.

#### G-10. Drag detection (Photoshop/Figma)

**Co dziś:** SFlow widzi tylko mouseDown. Drag (mousedown → move → mouseup)
nie generuje toastu.

**Co przegapiamy:** drag operations — przesuwanie warstwy, resize, marquee
selection. Część z nich ma keyboard alternative (np. arrow keys
move 1px / shift-arrow 10px).

**Koszt:** ~8h (event handling, ale klawiatura alternative complex).

**Wartość:** średnia — drag operations często **nie mają** dobrego klawiatura
zamiennika, więc edukacja może być uciążliwa.

---

### Tier 3 — **Wysoki koszt, niche value** (Faza 3+)

#### G-11. User-customized shortcuts

VSCode user może przemapować ⌘P na ⌘O. SFlow nadal pokazuje ⌘P.

**Koszt:** ~15h. Wymaga app-specific integracji (VSCode keybindings.json,
Sublime config, etc).

#### G-12. Team/admin overrides (B2B)

Z product-vision droga F. Wymaga osobnej infrastruktury (server-side rules
per organization).

**Koszt:** projekt wieloosobowy.

#### G-13. Gesture monitoring

Swipe, pinch, force-touch. NSEvent.gestureEvent.

**Koszt:** ~6h. **Wartość:** niska — gesty są dobrym UX, nie warto je
"degradować" toastami.

#### G-14. AppleScript-based discovery

`/usr/bin/osascript` może wyciągnąć skróty z scriptable apek (Mail, Finder,
OmniFocus, etc).

**Koszt:** ~10h. **Wartość:** średnia — pokrywa subset native apek lepiej
niż menu bar.

#### G-15. Active probing / synthetic hover

Sesja D w istniejącym roadmapie — `--seed-app` dev tool. Już zaplanowane.

---

## 3. Mapa pokrycia po popularnych Mac apkach (2026)

Subiektywny ranking "ile twojego targetu (knowledge worker)" + "jak dobrze
SFlow działa dziś" + "co trzeba dodać".

| Apka | Target % | Pokrycie dziś | Co trzeba |
|---|---|---|---|
| Slack | 90% | DOBRE | nic / Discord-friendly messageActions reuse |
| Chrome/Arc/Edge | 85% | CZĘŚCIOWE | **G-2** web-as-app krytyczne |
| Notion | 75% | DOBRE | **G-1** right-click + **G-4** single-key |
| VSCode/Cursor | 70% | NIETESTOWANE | reseed + G-7 modal context |
| Mail.app | 65% | DOBRE | G-3 i18n |
| Figma (web/desktop) | 60% | SŁABE | **G-8** tool switching + G-2 web |
| Linear | 60% | CZĘŚCIOWE | **G-5** dropdown + reseed |
| Discord | 55% | NIETESTOWANE | reseed (messageActions helper ready) |
| Obsidian | 50% | NIETESTOWANE | reseed + G-4 single-key Vim mode |
| Spotify | 50% | CZĘŚCIOWE | reseed |
| WhatsApp | 50% | NIE WIEMY | privacy crucial (B.1 robi) |
| Excel/Numbers | 45% | NIETESTOWANE | ribbon detection? |
| Word/Pages | 45% | NIETESTOWANE | reseed |
| Photoshop | 40% | PRAWDOPODOBNIE SŁABE | **G-8** + custom AX investigation |
| GitHub Desktop | 35% | NIETESTOWANE | reseed (Electron) |
| Xcode | 35% | CZĘŚCIOWE | reseed + scope rules dla edytora |

**Rekomendacja priorytetów (z pespektywy "uniwersalność"):**
1. **G-1 (right-click)** — pokrywa coverage hole we WSZYSTKICH apkach na raz
2. **G-2 (web-as-app)** — odblokowuje cały rozdział web-apek
3. **G-3 (i18n)** — odblokowuje cały rozdział non-EN userów
4. **G-5 (P-38 MenuItemObserver)** — już zaplanowane
5. **G-4 (single-key)** — niski koszt, czysty mental model
6. **G-6 (keystroke monitoring)** — fundament dla drogi B w product-vision

Te 6 to ~30-50h pracy. Po nich SFlow pokrywa **dramatycznie więcej**
realnych use case'ów bez per-app pracy.

---

## 4. Windows port — analiza wykonalności

### 4.1. Czy logicznie ma sens?

**TAK** — SFlow conceptually transcends platformę. Cały biznes value
("przypominanie skrótów w kontekście") jest niezależny od OS. Windows ma
więcej userów niż Mac w korporacjach (>70% rynku enterprise), więc port to
**~3× większy adresowalny market**.

### 4.2. Co z obecnego kodu działa na Windows?

**Niezmiennie:**
- Logika reguł (`RuleCache`, `ShortcutRules` patterns, `LoadedMatch`)
- Backend Cloudflare Worker — bez zmian (Claude API i18n, OS-agnostic)
- Schema JSON reguł
- Universal heuristics (różne klawisze: `Ctrl` zamiast `Meta`, ale logika OK)
- Dedup, prompt, dane szkoleniowe — wszystko zostaje

**Wymaga przepisania (per-platform code):**
- `CGEventTap` → `SetWindowsHookEx(WH_MOUSE_LL, ...)` + `RegisterHotKey`
- `AXUIElement` → **UI Automation (UIA)** — Microsoft framework analogiczny
  do macOS AX. Drzewo elementów, role, properties (`AutomationProperties.Name`
  ≈ `kAXTitle`), `AcceleratorKey` (≈ `kAXMenuItemCmdChar`)
- `NSWorkspace.frontmostApplication` → `GetForegroundWindow` + `GetWindowThreadProcessId`
- `NSScreen` → `EnumDisplayMonitors` + `MonitorFromPoint`
- `NSPanel` (toast) → WPF/WinUI `Window` lub WinAPI `CreateWindowEx` z
  `WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST`
- `Bundle ID` → `AppUserModelID` (Modern apps) lub `ProcessName.exe` (legacy)
- AppleScript → PowerShell + UIA scripting (ograniczone)

### 4.3. Architektura wieloplatformowa — 3 podejścia

**A. Re-write per platform (osobny codebase)**
- Mac: Swift (jak teraz)
- Windows: C# + .NET (najbardziej native UIA support)
- **Wadą:** dwa codebase'y w sync; backend i reguły shared
- **Zaletą:** każda platforma optymalna, najszybszy ship

**B. Rust + native bindings**
- Core w Rust (logika + IPC + persistence)
- Per-platform UI w Swift/Cocoa (Mac) i C#/WinUI (Win) lub w Rust+egui
  (mniej polished)
- `core-foundation-rs` na Mac dla AX, `windows-rs` crate na Win dla UIA
- **Wadą:** stroma krzywa nauki, początkowy slowdown
- **Zaletą:** jeden codebase 80%, najtańsza utrzymywalnie długofalowo
- **Real-world precedensy:** Linear core podobno Rust, Notion experimentuje

**C. Electron / Tauri**
- Cross-platform z jednego TS/JS codebase
- **Wadą:** Electron na Mac = nasi własni wrogowie (Sesja A/B fix-y są
  właśnie dlatego że Electron apek mają AX problems). Sami być Electronem
  to ironiczne i ciężkie performance-wise
- **Tauri** lepszy (Rust backend + webview frontend), ale **brak access do
  niskiego poziomu CGEventTap/UIA** — wymagałby plugins per-platform i tak

**Rekomendacja:** **B (Rust core)** dla długofalowości. Inwestycja 1-2
miesiąca na refaktor → potem 80% kodu shared, ship'owanie Windows 3-4
miesiące zamiast 6-9.

### 4.4. Co empirycznie różne między Mac AX a Windows UIA

| Aspekt | Mac AX | Windows UIA |
|---|---|---|
| Element role | `kAXRoleAttribute` (~30 ról) | `ControlType` enum (~50 typów) |
| Element title | `kAXTitle` | `AutomationProperties.Name` |
| Element desc | `kAXDescription` | `AutomationProperties.HelpText` |
| Hit-test position | `AXUIElementCopyElementAtPosition` | `IUIAutomation::ElementFromPoint` |
| Menu shortcut | `kAXMenuItemCmdChar`+`Modifiers` | `AcceleratorKey` property |
| Tree walk | `kAXParentAttribute` recurse | `TreeWalker` interface |
| Permission | TCC "Accessibility" | UAC w niektórych przypadkach (UIA dostępne bez admin) |
| Electron support | wymaga `AXManualAccessibility` flag | Chromium na Win również ma podobny gate |
| Tooltip detection | Floating AXGroup w drzewie | `ToolTip` control pattern (UIA Pattern) |

**Wniosek:** Mapping 1:1 możliwy dla ~85% funkcji. **Pattern Mode** w UIA
(zwracający tylko visible elements) jest **lepszy** niż macOS AX w niektórych
przypadkach — Windows ma cleaner separation.

### 4.5. Co byłoby **łatwiejsze** na Windows

- **Office Ribbon** — UIA dobrze go eksponuje, Office ma rich semantyczne metadane
- **Win32 native apek** — solid UIA z dnia 1
- **Steam / gaming overlay integration** — Steam ma swój SDK + Windows ma
  Game Bar API (Mac nie ma analogu)
- **Power-user pricing** — Windows enterprise/dev gotów płacić więcej za narzędzia

### 4.6. Co byłoby **trudniejsze** na Windows

- **Legacy Win32 dialogi** (np. classic Control Panel, niektóre installery)
  — ograniczona UIA, czasem trzeba MSAA (starsza warstwa)
- **WPF vs WinForms vs WinUI 3** — trzy różne XAML frameworki z różnym AX
  level (WPF najlepszy, WinForms najgorszy)
- **JetBrains na Windows** — używają JNA do natywnego AX, podobnie nieco
  pokrytego jak na Mac
- **Virtual Desktops** — inny mechanizm niż macOS Spaces, separation jest
  nieco bardziej "miękka", co może wpływać na overlay rendering
- **Modifier convention** — Mac ⌘ → Win Ctrl, Mac ⌥ → Win Alt; user trzeba
  przyzwyczaić do nowych symboli ⊞ (Win key) i Ctrl/Alt
- **WSL / Linux containers** — niektórzy power-userzy używają Linux apek
  via WSL2 z X server / WSLg → UIA tego nie widzi (jak Mac SFlow nie widzi
  remote desktop)

### 4.7. Time estimate

**MVP Windows (read-only port):**
- Refaktor core do Rust: 4-6 tygodni
- UIA bindings + click watcher: 2-3 tygodnie
- Tray icon + toast (WinUI lub WinForms): 1-2 tygodnie
- Per-app reguł reseed (Slack/Notion/VSCode dla Windows): 1 tydzień
- Testing + polish: 2 tygodnie
- **Total: ~3-4 miesiące** dla 1 dev pracującego full-time

**Pełny port (parity z Mac):**
- Wszystkie warstwy L0-L4 + tooltipy + menu items: +2-3 miesiące
- **Total: 5-7 miesięcy**

### 4.8. Czy warto teraz?

**NIE** — z perspektywy strategicznej:

1. **Faza 1 nie zamknięta.** Beta testing 5 osób na Mac (Sub-cel 1.7)
   nie była. Dopiero ona zwaliduje czy core hypothesis (toast uczy) jest
   prawda. **Bez tego port to budowanie 3× czego nie wiemy że działa.**

2. **Mac userzy → "more keyboard-friendly"** — empirycznie design/dev
   community na Macu już ceni klawisze. Windows enterprise użytkownicy
   mogą być **mniej keyboard-power** by default. Trzeba zwalidować ICP
   tam osobno.

3. **Pricing assumption** — $25-50 w product-vision. Mac users zostawiają
   pieniądze. Windows enterprise często bezpłatnie z corporate licenses.
   Może wymaga innego modelu (B2B sales).

4. **Tech debt** — obecna baza Swift jest opinion'owana macOS. Refactor
   na Rust to **inwestycja** która opóźni inne fix-y o ~2 miesiące. Robić
   to **po** udowodnieniu PMF (product-market fit) na Mac.

**Kiedy warto:** po Sesji 1.7 (beta 5 osób) + osiągnięciu 100 paying
Mac userów + min. 60% conversion z trial. To **earliest realistic
timeline: koniec 2026, Q1 2027**.

---

## 5. Najważniejsze decyzje strategiczne (synteza)

Z punktu widzenia "uniwersalność" — następne 6 miesięcy powinno dać:

1. **Zamknąć Fazę 1** (beta + 20 zweryfikowanych apek) — Sub-cele 1.6, 1.7
2. **G-1 right-click** w Faza 1.5 — najszybszy uniwersalny win
3. **G-2 web-as-app** w Faza 1.5 lub 2 — odblokowuje browser-as-platform
4. **G-3 i18n** w Faza 2 — odblokowuje non-US market
5. **G-5 MenuItemObserver** (P-38) — zaplanowane
6. **G-4 single-key** — bonus, ~2h, robić przy okazji
7. **G-6 keystroke monitoring** — fundament drogi B w product-vision,
   bez tego "personalized learning" się nie zbuduje

Te 7 pokrywa **większość uniwersalnego coverage gap** bez per-app pracy.

**Windows port:** odłożyć do końca 2026, po Fazie 1.7 beta + jakichś
przychodach na Macu jako sygnał PMF.

**B2B (G-12):** odłożyć do Fazy 4 albo gdy pojawi się explicit inbound od
firmy chętnej do zapłaty.

---

*Dokument napisany w trybie ultrathink — głębokie rozumowanie zamiast
podsumowania. 2026-05-16. Czeka na review Filipa.*
