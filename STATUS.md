# 📊 SFlow — Status projektu

> **Wizualny dashboard wszystkich faz i sub-celi.** Otwierasz → w 30s wiesz gdzie jesteś.
> Update'owany ręcznie po każdej sesji (end-of-session protocol, `product-vision.md` 0.5).
> Last sync: **2026-05-17**

---

## 📍 Gdzie jesteśmy teraz

**🎯 Aktywna faza: 1.5 Universal Coverage**
**🚧 Następny milestone: Faza 1.7 Beta** (blocked: 1.6 ≥10 verified apek + 1.7 setup)

---

## 🗺️ Mapa drogowa — wszystkie fazy

### ✅ Faza 0 — Fundament  •  **100% DONE**
```
████████████████████  100%
```
> **Po co była:** Zbudować silnik, który w ogóle widzi co user robi w apce i potrafi podpowiedzieć skrót. Bez tego nic dalej nie ma sensu.

- Detection engine (CGEventTap + AX), 7 warstw rozpoznawania
  → *Ucho apki: nasłuchuje kliknięć/skrótów i czyta z macOS co user kliknął.*
- LLM backend (Cloud Worker + Claude)
  → *Mózg w chmurze: gdy nie znamy apki, pyta Claude'a o jej skróty.*
- Auto-discovery flow
  → *Apka sama uczy się nowych programów — wykrywa, pyta backend, zapisuje reguły.*
- Telemetria v1.1 (miss log + analyzer)
  → *Dziennik pomyłek: zapisujemy gdy coś nie wyszło, by to potem naprawić.*
- **P-1..P-30 + P-34..P-37 + P-39..P-41 + P-44 + P-49..P-50 zamknięte**
  → *Lista bugów/zadań ponumerowanych P-X — te już naprawione.*

---

### 🟡 Faza 1 — Jakość pokrycia  •  **~70% (10/17 sub-celi 🟢, 3 🔵, 4 ⬜)**
```
██████████████░░░░░░  70%
```
> **Po co jest:** Sprawdzić, że w popularnych apkach (Slack, Notion...) SFlow naprawdę trafia w skróty często i nie kłamie. Bez tego beta-testerzy się zniechęcą.

| ✓ | # | Sub-cel | Co robi (cel) | Status |
|---|---|---|---|---|
| 🟢 | 1.0 | Re-seed Terminal/Notion/Claude | Generuje od nowa reguły skrótów dla 3 apek — żeby były świeże i aktualne | done 2026-05-14 |
| 🟢 | 1.1 | Quality gate | Bramka sprawdzająca wygenerowane reguły przed zapisem — żeby do bazy nie trafiały śmieci | done 2026-05-14 |
| 🟢 | 1.2 | Retry + backoff (P-2/P-3) | Gdy request padnie, próbuje ponownie z coraz większą przerwą — żeby chwilowa awaria sieci nie zabiła apki | done 2026-05-15 |
| 🔵 | 1.3 | Self-healing /v1/refresh | Apka sama prosi backend o nowsze reguły, gdy stare nie działają — żeby błędy naprawiały się bez updatu | partial — fundament jest |
| 🟢 | 1.4 | False-positive feedback | User klika „głupi toast" i to ląduje w logach — żebyśmy uczyli się z błędów bez ręcznego zgłaszania | done 2026-05-13 |
| 🟢 | 1.5 | MenuBarIndex.lookup fix | Naprawia szukanie poleceń w menu apki (Plik/Edycja na górze ekranu) — żeby znajdować skróty z menu | done 2026-05-14 |
| ⬜ | **1.6** | **≥10 verified apek + coverage report** | Ręczne sprawdzenie 10 popularnych apek czy SFlow naprawdę w nich działa — minimum jakości przed betą | **5/10 done** — UAT checklist gotowy dla Obsidian/Terminal/Linear/Cursor |
| ⬜ | **1.7** | **Beta z 3-5 osobami** | Wpuścić znajomych do testów i zbierać feedback — żeby się dowiedzieć czy toast w ogóle uczy ludzi | **blocker fazy 2+** — czeka na 1.6 + silent mode |
| 🔵 | 1.8 | Video-based eval | Nagrywamy ekran i porównujemy czy SFlow trafia w dobrych momentach — automatyczna ocena jakości | Droga C ✅, Droga B `--llm` flag — 2 TODO Filipa |
| 🟢 | 1.9 | Window element wins (P-6+P-25) | Lepsze wykrywanie elementów w oknie (przyciski, listy) — żeby nie gubić rzeczy które system widzi | done 2026-05-14 |
| 🟢 | 1.10 | Matching engine quality (P-26..P-30) | Sprytniejsze dopasowanie „co user kliknął" do „która to reguła" — mniej pomyłek typu kliknął A, dopasowało B | done 2026-05-14 |
| 🔵 | 1.11 | Coverage iteration (P-31) | Cykliczna analiza luk: gdzie nie podpowiadamy a powinniśmy — żeby systematycznie zwiększać pokrycie | część 1 done, część 2 czeka na ≥200 events |
| 🔵 | 1.12 | Backend ukierunkowany web research (P-32) | Backend googluje skróty dla nieznanych apek — żeby nie pytać Claude'a o coś co jest w internecie | P-34 ✅, P-32/P-35 verify pending |
| ⬜ | 1.13 | Synthetic Claude self-eval (P-33) | Claude testuje sam siebie na wygenerowanych przypadkach — żeby skalować jakość bez 100h pracy Filipa | prerequisite dla 100+ apek |
| 🟢 | 1.14 | Chromium AX deep fallback (P-36) | Głębsze grzebanie w drzewie elementów w apkach Chromium/Electron — żeby SFlow działał w Slacku/Notion/Linear | done 2026-05-15 |
| 🟢 | 1.15 | Tooltip observer (P-37) | Czytamy tooltipy typu „naciśnij ⌘K aby…" — żeby dowiadywać się o skrótach prosto z UI apki | część 1 (B) done, część 2 (C backend) pending |
| ⬜ | 1.16 | Dev-mode seed pre-fetch | Tryb dev pobiera reguły wszystkich znanych apek z góry — szybsze testowanie, mniej requestów na żywo | opcjonalne, niska prio |
| 🟢 | 1.17 | Menu-as-discovery (P-38) | Menu apki traktujemy jako darmowe źródło reguł skrótów — zerowy koszt nauki nowej apki | done 2026-05-17 (przez Sub-cel 1.18 + Layer 0.6) |

---

### 🟡 Faza 1.5 — Universal Coverage  •  **25% (3/12 sub-celi 🟢)**
```
█████░░░░░░░░░░░░░░░  25%
```
> **Po co jest:** Zamiast pisać reguły osobno dla każdej apki, zrobić mechanizmy które działają **wszędzie** (right-click, menu, dialogi). Mniej naszej pracy, więcej pokrytych apek.
> Wzbogaca Fazę 1.6 (więcej apek pokrytych) i Fazę 1.7 (beta sygnał wiarygodny).

| ✓ | # | Sub-cel | U-X | Co robi (cel) | Status |
|---|---|---|---|---|---|
| 🟢 | 1.18 | Right-click context menu (P-41) | U-2 | Z menu po prawym kliknięciu wyciągamy listę skrótów — darmowe pokrycie dla każdej apki | done 2026-05-17 |
| ⬜ | **1.19** | **Web-as-app pseudo-bundleId (P-42)** | U-4 | Traktować Gmail/Linear-web jak osobne apki, nie jeden „Chrome" — żeby każda strona miała własne reguły | **ODŁOŻONE** post-Beta — plan: `docs/phase-web-as-app-plan.md` |
| ⬜ | **1.20** | **i18n / lokalizacja (P-43)** | U-5 | Rozumieć menu w różnych językach („Plik" = „File") — żeby polskie beta-testy nie były śmieciowe | **HIGH** — krytyczny dla polskich beta-testerów |
| 🟢 | 1.21 | Single-key shortcut mode (P-44) | U-3 | Wspieranie skrótów jednoliterowych (j/k/g w Linear) — żeby ogarniać apki gdzie nie wszystko ma ⌘ | done 2026-05-17 |
| ⬜ | 1.22 | Modal/sheet scope (P-45) | U-6 | Gdy otwarty popup, ukryć skróty z głównego okna — żeby nie podpowiadać tego co teraz nie działa | eliminuje FP w dialogach |
| ⬜ | 1.23 | Tool/mode switching (P-46) | U-7 | Wykrywać które narzędzie jest aktywne (pen/brush) — żeby skróty pasowały do trybu w Figmie/Photoshopie | odblokowuje creative apps eval |
| ⬜ | 1.24 | Eval Microsoft Office (P-47) | U-8 | Sprawdzić czy SFlow działa w Word/Excel/PowerPoint/Outlook/OneNote — żeby wiedzieć ile pracy potrzeba | ~10h, 5 apek — **plan: `docs/phase-5-categories-eval-plan.md` E-4** |
| ⬜ | 1.25 | Eval Adobe Creative Suite (P-47) | U-9 | Sprawdzić Photoshop/Illustrator — bo Adobe ma inny model UI i tool-switching | ~10h, czeka na U-7 — **odłożone post-Beta** |
| ⬜ | 1.26 | Eval Qt/GTK/Tk (P-47) | U-10 | Sprawdzić apki z nietypowymi frameworkami UI (VLC/GIMP/Blender) — czy macOS AX je w ogóle widzi | ~6h, **plan E-3** |
| ⬜ | 1.27 | Eval Catalyst (P-47) | U-10 | Sprawdzić apki iPadowe przerobione na Maca (News/Stocks/Books) — inny model elementów niż natywny | ~4h, **plan E-2** |
| ⬜ | 1.28 | Eval SwiftUI pure (P-47) | U-10 | Sprawdzić natywne nowe apki Apple (Shortcuts, Freeform) — powinny być najłatwiejsze, szybki win | ~2h, **najwyższe ROI** — **plan E-1** |
| 🟢 | 1.29 | TooltipNameFilter + PrivacyFilter (P-39/P-40) | U-1 | Czyszczenie PII (imiona, emaile) z elementów zanim coś polecimy w chmurę — żeby chronić prywatność usera | done 2026-05-17 |

---

### 🔴 Faza 1.6 — 10 verified apps  •  **30% (3/10)**
```
██████░░░░░░░░░░░░░░  30%
```
> **Po co jest:** Mieć 10 apek gdzie SFlow podpowiada poprawnie ≥70% razy i myli się <15%. Minimum żeby beta-testerzy nie wyrzucili apki po godzinie.

| ✓ | App | Po co ta apka w zestawie | Status |
|---|---|---|---|
| 🟢 | Slack | Komunikator Electron — sprawdza czy działamy w popularnym czacie z dużą ilością shortcutów | GOOD — 15 toastów / 11 missów w 10h |
| 🟢 | Notion Mail | Web-app w Electronie z keyboard-first UX — flagowy test dla apek „od skrótów" | GOOD — Sesja B verified 5/5 |
| 🟢 | Claude Desktop | Apka AI Anthropic — naturalny test bo Filip jej używa codziennie | GOOD — 7 toastów / 1 miss |
| 🟡 | Notion | Edytor dokumentów — sprawdzian na bardzo rozbudowanym Chromium UI | PARTIAL — reguły OK, mało użycia w sample |
| 🟡 | Notion Calendar | Kalendarz Electron — sprawdza dropdown menus i daty | PARTIAL — dropdown menu missy |
| ⬜ | Obsidian | Edytor markdown — natywna apka z mocnym keyboard-first community | UNTESTED — **UAT checklist gotowy** |
| ⬜ | Terminal | Natywna apka Apple — minimalne UI, głównie menu bar — test dla menu-as-discovery | UNTESTED — UAT czeka, tylko menu bar coverage |
| ⬜ | Linear desktop | Tracker tasków z single-key skrótami (j/k/g) — test dla Sub-celu 1.21 | brak reguł — najpierw discovery |
| ⬜ | Cursor | Edytor kodu (fork VSCode) — sprawdzian na narzędziu dev którego Filip używa | brak w cache — najpierw discovery |
| ⬜ | +1 nowa (TBD) | Dziesiąta apka do osiągnięcia progu bety — TBD po danych | wymagany dla bety |

---

### ⬜ Faza 1.7 — Beta z 3-5 osobami  •  **planowane**
```
░░░░░░░░░░░░░░░░░░░░  0%
```
> **Po co jest:** Pierwszy realny sygnał *„czy toast po akcji uczy"*. Bez tego cała strategia drogi B (curriculum) wiszi w powietrzu.

**Prerequisites (5 rzeczy do zamknięcia):**
- ⬜ Faza 1.6 → ≥10 verified apek — *bez tego beta-testerzy nie zobaczą sensu apki*
- 🟢 Silent mode toggle (data collection bez UI noise) — **done 2026-05-17** *(czeka na xcodegen + build Filipa)*
- 🟢 DMG export bundle (kolega eksportuje dane po 2-3 dniach) — **done 2026-05-17** *(`DiagnosticBundleExporter.swift` + button w Advanced tab; `docs/beta-tester-guide.md` 1-pager dla kolegi)*
- ⬜ Onboarding doc dla testerów — *instrukcja: co testować i jak zgłaszać uwagi*
- ⬜ Anon user ID (Sub-cel 2.1 fragment) — opcjonalnie. *Anonimowy identyfikator — odróżnia dane od różnych testerów.*

---

### ⬜ Faza 1.8 — Web Coverage + Semantic Intents  •  **planned, post-Beta**
```
░░░░░░░░░░░░░░░░░░░░  0%
```
> **Po co jest:** Większość pracy ludzie robią w przeglądarce (Gmail, Linear-web, Figma, Docs). Dziś tam mamy 0% pokrycia. Cel: ~85-90%.
> Plan szczegółowy: **`docs/phase-web-as-app-plan.md`** (400+ linii, 13 sekcji). Czeka na zamknięcie Bety.

**Sub-cele do dodania po decyzji startu:**
- Sub-cel 1.19 (P-42) Web-as-app — *odróżniać strony www jak osobne apki*
- Sub-cel 1.30 (NOWY) Semantic Intent Library (W4) — *30-50 ogólnych intencji („wyślij wiadomość", „nowy task") rozpoznawanych w wielu apkach*
- Sub-cel 1.31 (NOWY) Confidence-based toast UI — *toast pokazuje 2-3 kandydatów ze stopniem pewności, gdy nie jesteśmy w 100%*

---

### ⬜ Faza 2 — Infrastruktura nauki  •  **planowane**
```
░░░░░░░░░░░░░░░░░░░░  0%
```
> **Po co jest:** Zbudować rurociąg danych: kto, co, jak często — żeby później pokazać userowi „w tym tygodniu nauczyłeś się 5 skrótów". Bez tych liczb nie udowodnimy wartości.

- 2.1 Anonymous user ID — *anonimowy znacznik usera, żeby liczyć metryki per osoba bez ujawniania kto to*
- 2.2 EventLogger keyboard events (jaki skrót user wcisnął) — *zapis: user faktycznie wcisnął ⌘K po toaście — czyli się nauczył*
- 2.3 Daily aggregator — *raz dziennie sumuje wszystkie eventy do statystyk*
- 2.4 Endpoint `/v1/agg` — *backend przyjmuje agregaty od apki i je przechowuje*
- 2.5 Privacy UI w Settings — *user widzi i kontroluje co o nim wysyłamy*
- 2.6 False-positive global aggregation — *zbieramy globalnie błędy od wielu userów, żeby poprawiać reguły dla wszystkich*

---

### ⬜ Faza 3 — Droga A (intro toast + onboarding)  •  **1 tydzień, planowane**
> **Po co jest:** Pierwsze 5 minut z apką — user musi zrozumieć „o co chodzi" zanim się zniechęci. Sama detekcja nie wystarczy, trzeba też dobrego intro.

- 3.1 Welcome sequence — *pierwsze uruchomienie: krótki tutorial co to jest*
- 3.2 Intro toast — pierwsza ekspozycja mocniejsza — *pierwszy toast większy/wyraźniejszy, żeby user zauważył*
- 3.3 Reinforcement w toaście — *toast nie tylko mówi co user kliknął, ale też pomaga zapamiętać („3 raz w tym tygodniu, prawie to znasz")*

---

### ⬜ Faza 4 — Droga B (curriculum)  •  **4-6 tygodni, kluczowa decyzja po Becie**
> **Po co jest:** Zamiast losowych toastów — program nauki dopasowany do tego co user robi. To największe „wow" SFlow vs konkurencja.

- 4.1 Curriculum generator (algorithm vs LLM) — *silnik układający kolejność lekcji: co user powinien się dziś nauczyć*
- 4.2 Lokalna lesson view — *małe okienko z lekcją (np. „dziś 3 skróty Slacka")*
- 4.3 Reinforcement w toaście (pełna) — *toast = mikro-przypomnienie z lekcji, w idealnym momencie*
- 4.4 Mierzenie postępu — *liczymy ile skrótów user opanował i ile sekund oszczędza dziennie*

---

### ⬜ Faza 5 — Droga E (raporty + dashboard)  •  **2-3 tygodnie**
> **Po co jest:** „Co mi to dało po 30 dniach?" — pokazać konkretne liczby (zaoszczędzony czas, opanowane skróty). Główny argument żeby user nie odinstalował.

- 5.1 SavingsCalculator — *przelicznik: ile sekund/minut oszczędziłeś używając skrótów zamiast myszki*
- 5.2 Weekly Report Window — *tygodniowy ekran podsumowania z metrykami*
- 5.3 Menu bar updates — *ikonka na górze ekranu pokazuje krótki status („3 nowe skróty w tym tygodniu")*
- 5.4 Email raport (opt-in) — *raz w tygodniu mail z postępami, jeśli user się zgodzi*

---

## 🚧 Aktualnie zaplanowane (next 1-2 sesje)

1. ✅ **STATUS.md** (ten plik) — *dashboard projektu*
2. ✅ **Silent mode toggle** — Settings → Advanced "Hide toasts (collect data only)" + 🔇 indikator w menu barze + EventLogger pisze `silent: true` w events.jsonl
3. ✅ **DMG export bundle** — Settings → Advanced "Export diagnostic bundle…" + `DiagnosticBundleExporter.swift` + `docs/beta-tester-guide.md` 1-pager dla kolegi
4. ⏸️ **xcodegen + build + UAT przez Filipa** — sprawdzić w żywej apce czy silent mode + export działają poprawnie
5. ⏸️ **Sesja E-1 SwiftUI** (~2h, Filip) — Shortcuts.app + Freeform, najwyższe ROI z 5 kategorii
6. ⏸️ **UAT 4 untested apek** (Obsidian/Terminal/Linear/Cursor, ~30-40 min, Filip)
7. ⏸️ **Wyślij DMG do kolegi-testera** — silent mode WŁ., 2-3 dni zbierania, potem export bundle
8. ⏸️ **(Po danych) P-51** miss event categorization decyzja

---

## 🔥 Otwarte blokery (top problemy)

| # | P-X | Co to (cel) | Blokuje | Status |
|---|---|---|---|---|
| 1 | ~~brak silent mode~~ | Tryb cichy: zbieraj dane bez wyświetlania toastów beta-testerom | ~~Beta~~ | 🟢 **zamknięte 2026-05-17** (kod gotowy, czeka na build) |
| 2 | ~~brak DMG export~~ | Paczka z logami którą tester sam zgrywa i wysyła Filipowi | ~~Beta~~ | 🟢 **zamknięte 2026-05-17** (kod gotowy, czeka na build) |
| 3 | P-38 dropdown menu items | Wykrywanie elementów wewnątrz rozwijanych menu (palette ⌘K, popupy) | Cron, Linear ⌘K palette | czeka test |
| 4 | P-43 i18n | Wsparcie języków: rozumieć menu po polsku/niemiecku/itd. | beta-testerzy z PL UI = śmieciowy sygnał | HIGH prio przed Beta |
| 5 | P-19 bundled.json update path | Mechanizm dostarczania nowych reguł do userów po update apki | release do userów | sprawdzone w sesjach 3f85be6/a50264c — w sumie DONE? |
| 6 | P-32 web research backend | Backend googluje skróty dla nieznanych apek — wyższa jakość reguł | jakość auto-discovered reguł | sesja 9b |

---

## 📊 Statystyki projektu

| Metryka | Wartość |
|---|---|
| **Pierwszy commit** | 2026-05-08 |
| **Czas projektu** | ~9 dni |
| **Commitów total** | 209 |
| **Linijek Swift kodu** | ~5,800 |
| **Testów passing** | 248 (w `SFlowTests/`) |
| **Plików .swift w SFlow/** | sprawdź `find SFlow -name *.swift` |
| **Bundled apek z regułami** | 5 (Slack, Terminal, Notion, Claude, Obsidian) |
| **Bundled apek total** | 8 (3 puste: Notion Mail, Linear, Cron) |
| **Cached apek (auto-discovered)** | 35 |
| **Reguł w bundled.json** | ~254 (58+69+57+26+44) |
| **P-X problemów total** | 38 |
| **P-X zamkniętych** | ~23 (60%) |
| **P-X otwartych** | 10 |
| **P-X partial / in-progress** | 5 |
| **Sub-celi Fazy 1** | 17 (10 done, 3 partial, 4 pending) |
| **Sub-celi Fazy 1.5** | 12 (3 done, 9 pending) |

---

## 🗂️ Powiązane dokumenty (mapa)

| Plik | Co tam jest |
|---|---|
| **`docs/roadmap.md`** | Pełna roadmapa, session log, atomic plans |
| **`docs/product-vision.md`** | Wizja produktu, opcje rozwoju (drogi A-F), rekomendacja drogi B |
| **`docs/audit-phase-0.md`** | Lista wszystkich P-X problemów z statusami |
| **`docs/audit-phase-1.md`** | Sub-cele Fazy 1 (1.0-1.17) |
| **`docs/audit-phase-1.5.md`** | Sub-cele Fazy 1.5 (1.18-1.29) Universal Coverage |
| **`docs/coverage-report.md`** | Per-app coverage matrix |
| **`docs/decision-log.md`** | Decyzje strategiczne projektu |
| **`docs/phase-web-as-app-plan.md`** | Plan Fazy 1.8 (Web + Semantic Intents) |
| **`docs/events-jsonl-analysis-2026-05-17.md`** | Najnowsza analiza telemetrii |
| **`docs/uat-checklist-untested-bundled.md`** | UAT na 4 untested apek |
| **`docs/phase-5-categories-eval-plan.md`** | Plan zamykania 5 kategorii apek (Sub-cele 1.24-1.28) |
| **`docs/risk-register-phase-1.5.md`** | Risk register |
| **`docs/beta-pre-mortem.md`** | Pre-mortem Bety |
| **`docs/beta-faq.md`** | FAQ dla beta-testerów |

---

## 🎬 Co śledzimy długoterminowo (3 wielkie pytania)

Z `product-vision.md` sekcja 5 — pytania których odpowiedzi zmienią produkt:

1. **Czy toast po akcji UCZY?** — odpowiedź po Becie (Faza 1.7)
2. **Jak udowodnić wartość 30 dni po instalacji?** — Faza 5 (raporty)
3. **Co odróżnia SFlow od KeyCue/CheatSheet/Mouseless?** — Faza 1.8 Web (Semantic Intents) odpowiada „działamy wszędzie"

---

## 🔄 Legenda

| Symbol | Znaczenie |
|---|---|
| 🟢 | done + verified |
| 🟡 | in-progress / partial |
| 🔵 | partial — fundament jest, dokończyć |
| 🔴 | poor / blocked |
| ⬜ | pending — nie tknięte |
| ✅ | hard-confirmed milestone (np. UAT przez Filipa) |
| ❌ | rejected / out of scope |

---

*Aktualizacja: AI po każdej sesji z kodem. Manualnie: Filip gdy chce zmienić priorytety.*
