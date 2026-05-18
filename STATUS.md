# 📊 SFlow — Status projektu

> **Wizualny dashboard wszystkich faz i sub-celi.** Otwierasz → w 30s wiesz gdzie jesteś.
> Update'owany ręcznie po każdej sesji (end-of-session protocol, `product-vision.md` 0.5).
> Last sync: **2026-05-18 (sesja Finalize Fazy 1: 1.12 closed + 4 sub-cele deferred → Faza 2)**

---

## 📍 Gdzie jesteśmy teraz

**🎯 Aktywna sesja: Finalize Fazy 1 (zamykamy 1.8 + 1.12, formalny defer 1.3/1.11/1.13/1.16 → Faza 2)**
**🎉 2026-05-18 — Faza 1.6 zamknięta (10/10 verified). Próg Fazy 1.7 (beta MVP) SPEŁNIONY.**
**🚧 Następny milestone (po dzisiejszej sesji):** Faza 1.5 i18n (Sub-cel 1.20, P-43) → Faza 1.7 Beta. *Hard-blocker bety = i18n. Resztka Fazy 0 P-19 = krytyczna tylko jeśli iterujemy DMG podczas Bety.*

---

## 🗺️ Mapa drogowa — wszystkie fazy

### ✅ Faza 0 — Fundament  •  **mechanika 100% • operacyjne 90% (3 resztki)**
```
██████████████████░░  90%
```
> **Po co była:** Zbudować silnik, który w ogóle widzi co user robi w apce i potrafi podpowiedzieć skrót. Bez tego nic dalej nie ma sensu.

**Komponenty silnika (co już działa):**

| ✓ | Komponent | Co robi (jak 12-latkowi) | Stan |
|---|---|---|---|
| 🟢 | **Detection engine** (`ClickWatcher.swift`, ~311 LOC + 6 layers L0–L4) | Ucho apki: łapie każdy klik myszką i pyta macOS „w co user trafił" — 7 warstw rozpoznawania jedna po drugiej, pierwsza która zgadnie wygrywa | działa, audyt 2026-05-14 zamknął 5 fundamentalnych bugów (P-26..P-30) |
| 🟢 | **JSON rules cache** (`RuleCache.swift`, bundled.json ~254 reguł) | Książka skrótów: dla 5 popularnych apek mamy gotowe reguły zaszyte w paczce, dla reszty backend dolewa | działa, 5 bundled (Slack/Terminal/Notion/Claude/Obsidian) + 35 auto-discovered cache |
| 🟢 | **LLM backend** (Cloudflare Worker + Claude Sonnet 4.6) | Mózg w chmurze: gdy widzimy nieznaną apkę, dump menu+UI → Claude generuje reguły → KV cache 90 dni | działa, ~600 LOC TS, streaming z max_tokens 32k (P-34 fix) |
| 🟢 | **Auto-discovery flow** (`DiscoveryService.swift`) | Apka sama się uczy: jak user otwiera nową apkę → SFlow pyta backend → reguły lądują w cache | działa z retry+backoff (P-2) + persisted attempted.json + 6 failure reasons |
| 🟢 | **Telemetria v1.1** (`EventLogger.swift` + `Analyzer.swift` + `events.jsonl`) | Dziennik: zapisuje każdy toast i każdy miss z layer-tagiem (L0/L0.5/.../L4) → wiemy która warstwa fire'uje | działa, per-layer telemetry (P-30), PII redact (P-40) |
| 🟢 | **Privacy filter** (`PrivacyFilter.swift`, `TooltipNameFilter.swift`) | Cenzor: nim coś wyśle do chmury wycina emaile/imiona/karty/emoji — chroni prywatność | 13 testów, integracja w EventLogger + TooltipObserver |
| 🟢 | **False-positive feedback** (cmd-klik na toast + `false_positives.jsonl` + `/v1/feedback`) | Przycisk „głupi toast": user klika z cmd → zapisujemy do logów + lokalnie blokujemy po 3 zgłoszeniach | działa lokalnie + backend |
| 🟢 | **Right-click harvester** (`RightClickMenuHarvester.swift`, P-41) | Z prawego kliknięcia: czytamy menu kontekstowe i wyciągamy skróty z atrybutów AX — darmowe pokrycie dla każdej apki | UAT ✅ Finder/Comet/Notion/Slack 2026-05-17 |
| 🟢 | **Tooltip observer + Layer 0.6** (`TooltipObserver.swift`, P-37) | Z dymków pomocy: gdy user najedzie kursorem, czytamy „naciśnij ⌘K aby…" → reguła leci do `DiscoveredStore` (TTL 7 dni) | UAT ✅ Notion Mail/Calendar |
| 🟢 | **Silent mode + DMG export** (`DiagnosticBundleExporter.swift`, Sub-cel 1.30/1.31) | Tryb cichy do bety + paczka diagnostyczna którą tester sam wyeksportuje | kod gotowy 2026-05-17, czeka na build |

**Zamknięte P-X bugi Fazy 0 (24 z 40):** P-1, P-2, P-3, P-4, P-5, P-6, P-15, P-23, P-25, P-26, P-27, P-28, P-29, P-30, P-34, P-36, P-37, P-39, P-40, P-41, P-44, P-49, P-50.

**Resztki Fazy 0 (3 punkty operacyjnej dojrzałości, nie blokują działania mechaniki):**

| ⚠ | P-X | Co robi (cel) | Severity wg audytu | Status |
|---|---|---|---|---|
| 🔴 | **P-19 bundled.json update path** | Po updatcie SFlow z 1.0→1.1 reguły z nowej paczki muszą trafić do usera (dziś `seedBundledIfMissing` ignoruje update bo plik istnieje) | **WYSOKA długoterminowo — krytyczne dla launch'a** | ⬜ otwarte — *jeden z najtrwalszych długów Fazy 0* |
| 🔵 | **P-8 /v1/refresh z miss data** | Backend regeneruje reguły kiedy klient zgłasza powtarzające się missy (≥20 missów/apka) — żeby reguły same się leczyły | ŚREDNIA → WYSOKA z czasem | częściowo: `?fresh=1` ✅, brak miss-driven refresh |
| 🔵 | **P-21 backend observability** | Dashboard metryk: ile reguł per apka, ile timeoutów, p95 czasu Claude calla — żebyśmy nie latali ślepo gdy będą userzy | WYSOKA gdy będą userzy | częściowo: structured JSON log ✅, brak dashboardu |

---

### 🟢 Faza 1 — Jakość pokrycia  •  **scope-Bety 100% (12 🟢 done + 4 ⏸️ deferred do Fazy 2)**
```
████████████████████  100% scope-Bety
```
> **Po co jest:** Sprawdzić, że w popularnych apkach (Slack, Notion...) SFlow naprawdę trafia w skróty często i nie kłamie. Bez tego beta-testerzy się zniechęcą.
> *Sub-cele 1.6 (≥10 verified apek) i 1.7 (Beta) wyodrębnione do osobnych Faz. Sub-cele 1.3/1.13/1.16 + 1.11 część 2 **odroczone do Fazy 2** — wymagają real userów lub ≥200 events do trigger sensownie.*

| ✓ | # | Sub-cel | Co robi (cel) | Status |
|---|---|---|---|---|
| 🟢 | 1.0 | Re-seed Terminal/Notion/Claude | Generuje od nowa reguły skrótów dla 3 apek — żeby były świeże i aktualne | done 2026-05-14 |
| 🟢 | 1.1 | Quality gate | Bramka sprawdzająca wygenerowane reguły przed zapisem — żeby do bazy nie trafiały śmieci | done 2026-05-14 |
| 🟢 | 1.2 | Retry + backoff (P-2/P-3) | Gdy request padnie, próbuje ponownie z coraz większą przerwą — żeby chwilowa awaria sieci nie zabiła apki | done 2026-05-15 |
| ⏸️ | 1.3 | Self-healing /v1/refresh | Apka sama prosi backend o nowsze reguły, gdy stare nie działają — żeby błędy naprawiały się bez updatu | **DEFERRED → Faza 2** — wymaga real userów do triggerów (≥20 missów/apka) |
| 🟢 | 1.4 | False-positive feedback | User klika „głupi toast" i to ląduje w logach — żebyśmy uczyli się z błędów bez ręcznego zgłaszania | done 2026-05-13 |
| 🟢 | 1.5 | MenuBarIndex.lookup fix | Naprawia szukanie poleceń w menu apki (Plik/Edycja na górze ekranu) — żeby znajdować skróty z menu | done 2026-05-14 |
| 🟢 | 1.8 | Video-based eval | Nagrywamy ekran i porównujemy czy SFlow trafia w dobrych momentach — automatyczna ocena jakości | **done 2026-05-18** — Droga C ✅, Droga B `--llm` prompt v2 verified: 32 frames Slack/Xcode → **0 halucynacji** (v1 miał 4 false-positives z Slack context menu), 1 autentyczny toast (Xcode ⌘K). Pełny audit w `docs/video-eval-test.md` sekcja Verification result. |
| 🟢 | 1.9 | Window element wins (P-6+P-25) | Lepsze wykrywanie elementów w oknie (przyciski, listy) — żeby nie gubić rzeczy które system widzi | done 2026-05-14 |
| 🟢 | 1.10 | Matching engine quality (P-26..P-30) | Sprytniejsze dopasowanie „co user kliknął" do „która to reguła" — mniej pomyłek typu kliknął A, dopasowało B | done 2026-05-14 |
| ⏸️ | 1.11 | Coverage iteration (P-31) | Cykliczna analiza luk: gdzie nie podpowiadamy a powinniśmy — żeby systematycznie zwiększać pokrycie | część 1 ✅, część 2 **DEFERRED → post-Beta** (analiza ≥200 events z 5 testerów daje sensowny sygnał) |
| 🟢 | 1.12 | Backend ukierunkowany web research (P-32) | Backend googluje skróty dla nieznanych apek — żeby nie pytać Claude'a o coś co jest w internecie | **done 2026-05-18** — P-34 ✅, P-32 prompt update (explicit STEP 1-3 + max_uses 4→8, commit `57b4935`, backend `ba683371`) + reseed 5 bundled (253→265 reguł, web_docs 56→69 +23%) + P-35 mitigation (client timeout 90→180s, commit `4bf1320`) |
| ⏸️ | 1.13 | Synthetic Claude self-eval (P-33) | Claude testuje sam siebie na wygenerowanych przypadkach — żeby skalować jakość bez 100h pracy Filipa | **DEFERRED → Faza 2** — skaluje quality eval na 100+ apek; przed Betą (5 osób) ręczna analiza wystarczy |
| 🟢 | 1.14 | Chromium AX deep fallback (P-36) | Głębsze grzebanie w drzewie elementów w apkach Chromium/Electron — żeby SFlow działał w Slacku/Notion/Linear | done 2026-05-15 |
| 🟢 | 1.15 | Tooltip observer (P-37) | Czytamy tooltipy typu „naciśnij ⌘K aby…" — żeby dowiadywać się o skrótach prosto z UI apki | część 1 (B) done, część 2 (C backend) pending — defer post-Beta |
| ⏸️ | 1.16 | Dev-mode seed pre-fetch | Tryb dev pobiera reguły wszystkich znanych apek z góry — szybsze testowanie, mniej requestów na żywo | **DROPPED / DEFERRED** — opcjonalne narzędzie internal-only, niska prio, kandydat do całkowitego usunięcia z Fazy 1 |
| 🟢 | 1.17 | Menu-as-discovery (P-38) | Menu apki traktujemy jako darmowe źródło reguł skrótów — zerowy koszt nauki nowej apki | done 2026-05-17 (przez Sub-cel 1.18 + Layer 0.6) |

**Legenda:** 🟢 done • 🎯 close today (Filip-local run) • ⏸️ deferred (sensowny defer, nie blocker bety)

**Wyniki sesji 2026-05-18 (Finalize Fazy 1):**
- **Sub-cel 1.12 zamknięty** — backend prompt v1.1.2 (explicit web_search STEP 1-3 + max_uses 4→8), 5 bundled apek reseedowanych (Slack 58→63, Terminal 69→73, Notion 57→59, Claude Desk 26→24 z +2 web_docs_official, Obsidian 43→46). Każda apka ma ≥1 web_docs reguła (Terminal i Claude Desk poprzednio 0).
- **P-35 mitigation** — DiscoveryClient timeout 90→180s (Obsidian pierwszy raz timeout >90s, retry zadziałał; po fixie Slack reseed 67s na 1. próbie). Commit `4bf1320`.
- **Sub-cel 1.8 zamknięty** — `sflow-video-llm.swift` uruchomiony na 32 klatkach Slack/Xcode, **prompt v2 zweryfikowany: 0 halucynacji** (v1 miał 4 false-positives z Slack context menu), 1 autentyczny toast (Xcode Quick Switcher ⌘K). 10.1s analizy przez Claude Haiku 4.5 vision. Raport: `docs/video-eval-test.md`.
- **4 sub-cele formalnie odroczone do Fazy 2** (1.3, 1.11 część 2, 1.13, 1.16) — uzasadnienie w `audit-phase-1.md` sekcja "Defer rationale" + `roadmap.md` sekcja 2.0 "Carryover z Fazy 1". Commit `249ab24`.

**Audyt dzisiejszy (2026-05-18):** Z 11 acceptance criteria Fazy 1 (`audit-phase-1.md`) próg MIN to A-1..A-4, A-7, A-8 (6 z 11). Mamy **5/6 spełnione** (A-1✅ A-2✅ A-3✅ A-4✅ A-7✅ — 10/10 verified z Fazy 1.6), pozostaje A-8 który **DEFINICYJNIE = Faza 1.7 Beta**. **Wniosek:** Faza 1 jest scope-complete dla bety. 4 deferred sub-cele to skalowanie post-Beta, nie blokery.

#### 🤔 Dlaczego 4 sub-cele odroczone do Fazy 2 (wytłumaczenie jak 12-latkowi)

> **Wszystkie 4 mają wspólny mianownik:** wymagają **danych z prawdziwych userów** lub są **zastąpione lepszym rozwiązaniem**. Robienie ich przed Betą = praca w ciemno albo ryzyko zepsucia czegoś co działa.

| # | Po co był pomyślany | Dlaczego nie teraz | Analogia 12-latkowi |
|---|---|---|---|
| **1.3** Self-healing | Apka sama prosi backend o nowsze reguły gdy widzi że często się myli w apce X (≥20 missów + ≥3 powt. tytuły) | Filip solo (n=1) generuje 20 missów per apka **w tygodnie**. 5 testerów × 2 tygodnie = realny sygnał w **dni**. Mechanizm bez sygnału nigdy nie odpali. | Pułapka na 100 muszek w lesie gdzie jest 5 muszek — działa, ale nigdy nic nie złapie |
| **1.11 cz.2** Coverage iteration | Analiza per-warstwa (L0/L0.5/L1...) — gdzie luki, którą warstwę dolepić | Sensowna analiza = ≥200 events per warstwa. Dziś mamy ~150 events Filipa solo (n=1) — **statystycznie szum**. Beta dostarczy ~1000-2000 events w tydzień | Ankieta „która lodowa najlepsza" pytając 1 osobę — odpowiedź niereprezentatywna |
| **1.13** Synthetic self-eval | Drugi Claude (Haiku) ocenia każdą regułę w skali 1-5 — skalowanie quality eval na 100+ apek bez Filipa-ręcznie | (1) Cel = 100 apek; dziś mamy 10 — **ręcznie wystarczy do Bety**. (2) Bez ground truth (real FP od userów, P-4) Haiku może halucynować eval → **ryzyko zatrucia bundled.json przed Betą** | Kupujesz wagę kuchenną — najpierw ważysz klocek 1kg żeby sprawdzić czy waga nie kłamie. Bez wzorca = nie ufasz |
| **1.16** Dev seed pre-fetch | Symulowany hover wszystkich AXButton w apce → zbiera tooltipy do bundled.json przed releasem | Wartość **zastąpiona** przez Layer 0.6 + DiscoveredStore TTL 7d (commit `d8f6224`) — hover raz → instant przez 7 dni. Plus sztuczny hover triggeruje analytics/animacje w apkach (Slack/Notion liczą hovery). **Kandydat do dropu**. | Wymyśliłeś specjalny młotek, ale ktoś już pokazał że zwykły młotek + worek na śmieci robi to samo i bezpieczniej |

**Kiedy te 4 wracają:**
- **Po Becie (1-2 tygodnie):** mamy sygnał z 5 testerów → 1.3 + 1.11 cz.2 + 1.13 mają dane do pracy
- **Decyzja go/no-go o 1.16:** patrzymy czy L0.6+TTL pokrywa wszystkie case'y; jeśli tak → drop, jeśli są luki → robimy jako internal-only narzędzie

**Pełna techniczna wersja** uzasadnień: [`docs/audit-phase-1.md`](docs/audit-phase-1.md) sekcja „Defer rationale" + [`docs/roadmap.md`](docs/roadmap.md) sekcja 2.0 „Carryover z Fazy 1".

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
| 🔵 | 1.21 | Single-key shortcut mode (P-44) | U-3 | Wspieranie skrótów jednoliterowych (j/k/g w Linear) — żeby ogarniać apki gdzie nie wszystko ma ⌘ | code done 2026-05-17 — UAT pending |
| ⬜ | 1.22 | Modal/sheet scope (P-45) | U-6 | Gdy otwarty popup, ukryć skróty z głównego okna — żeby nie podpowiadać tego co teraz nie działa | eliminuje FP w dialogach |
| ⬜ | 1.23 | Tool/mode switching (P-46) | U-7 | Wykrywać które narzędzie jest aktywne (pen/brush) — żeby skróty pasowały do trybu w Figmie/Photoshopie | odblokowuje creative apps eval |
| ⬜ | 1.24 | Eval Microsoft Office (P-47) | U-8 | Sprawdzić czy SFlow działa w Word/Excel/PowerPoint/Outlook/OneNote — żeby wiedzieć ile pracy potrzeba | ~10h, 5 apek — **plan: `docs/phase-5-categories-eval-plan.md` E-4** |
| ⬜ | 1.25 | Eval Adobe Creative Suite (P-47) | U-9 | Sprawdzić Photoshop/Illustrator — bo Adobe ma inny model UI i tool-switching | ~10h, czeka na U-7 — **odłożone post-Beta** |
| ⬜ | 1.26 | Eval Qt/GTK/Tk (P-47) | U-10 | Sprawdzić apki z nietypowymi frameworkami UI (VLC/GIMP/Blender) — czy macOS AX je w ogóle widzi | ~6h, **plan E-3** |
| ⬜ | 1.27 | Eval Catalyst (P-47) | U-10 | Sprawdzić apki iPadowe przerobione na Maca (News/Stocks/Books) — inny model elementów niż natywny | ~4h, **plan E-2** |
| ⬜ | 1.28 | Eval SwiftUI pure (P-47) | U-10 | Sprawdzić natywne nowe apki Apple (Shortcuts, Freeform) — powinny być najłatwiejsze, szybki win | ~2h, **najwyższe ROI** — **plan E-1** |
| 🟢 | 1.29 | TooltipNameFilter + PrivacyFilter (P-39/P-40) | U-1 | Czyszczenie PII (imiona, emaile) z elementów zanim coś polecimy w chmurę — żeby chronić prywatność usera | done 2026-05-17 |

---

### 🟢 Faza 1.6 — 10 verified apps  •  **100% (10/10) ✅ GATE MET 2026-05-18**
```
████████████████████  100%
```
> **Po co jest:** Mieć 10 apek gdzie SFlow podpowiada poprawnie ≥70% razy i myli się <15%. Minimum żeby beta-testerzy nie wyrzucili apki po godzinie.
> **Status:** próg beta MVP (≥10) spełniony 2026-05-18 batch UAT 5+5 min eval per app.

| ✓ | App | Po co ta apka w zestawie | Status |
|---|---|---|---|
| 🟢 | Slack | Komunikator Electron — sprawdza czy działamy w popularnym czacie z dużą ilością shortcutów | GOOD — 15 toastów / 11 missów w 10h |
| 🟢 | Notion Mail | Web-app w Electronie z keyboard-first UX — flagowy test dla apek „od skrótów" | GOOD — Sesja B verified 5/5 |
| 🟢 | Claude Desktop | Apka AI Anthropic — naturalny test bo Filip jej używa codziennie | GOOD — 7 toastów / 1 miss |
| 🟢 | Terminal | Natywna apka Apple — minimalne UI, głównie menu bar | **GOOD — UAT 2026-05-17 5/5** (⌘T/⌘N/⌘F/⌘K/⌘W) |
| 🟢 | Mail.app | Natywny klient pocztowy AppKit — top użytkownik macOS | **GOOD — UAT 2026-05-18 5/5** (⌘N/⌘R/⌘⇧F/⌫/⌘⌥F) |
| 🟢 | Calendar | Natywny kalendarz AppKit — codzienny workflow | **GOOD — UAT 2026-05-18 5/5** (⌘N/⌘T/⌘2/⌘F/⌘,) |
| 🟡 | Notion | Edytor dokumentów — sprawdzian na bardzo rozbudowanym Chromium UI | PARTIAL — reguły OK, mało użycia w sample |
| 🟡 | Notion Calendar | Kalendarz Electron — sprawdza dropdown menus i daty | PARTIAL — dropdown menu missy |
| 🟡 | Obsidian | Edytor markdown Electron — natywna apka z mocnym keyboard-first community | **PARTIAL — UAT 2026-05-17** menu bar + Graph View OK, ribbon content miss (P-51 Electron lazy AX) |
| 🟡 | Music | Natywny odtwarzacz AppKit + media keys | **PARTIAL — UAT 2026-05-18** Search/View OK, Spacja/⌘→/⌘← media keys nieprzechwytywane (G-6 Faza 2.2) |
| 🚫 | ~~Cursor~~ | Edytor kodu (fork VSCode) — sprawdzian na narzędziu dev | **SKIPPED 2026-05-17** — nie zainstalowany lokalnie, kandydat do beta-tester verify |
| 🚫 | ~~Linear desktop~~ | Tracker tasków z single-key skrótami (j/k/g) — test dla Sub-celu 1.21 | **SKIPPED 2026-05-17** — nie zainstalowany lokalnie, kandydat do beta-tester verify |

---

### ⬜ Faza 1.7 — Beta z 3-5 osobami  •  **planowane**
```
░░░░░░░░░░░░░░░░░░░░  0%
```
> **Po co jest:** Pierwszy realny sygnał *„czy toast po akcji uczy"*. Bez tego cała strategia drogi B (curriculum) wiszi w powietrzu.

**Prerequisites (6 rzeczy do zamknięcia):**
- 🟢 Faza 1.6 → ≥10 verified apek — **DONE 2026-05-18** *(10/10 verified, 6 🟢 + 4 🟡)*
- 🟢 Silent mode toggle (Sub-cel 1.30, data collection bez UI noise) — **done 2026-05-17** *(czeka na xcodegen + build Filipa)*
- 🟢 DMG export bundle (Sub-cel 1.31, kolega eksportuje dane po 2-3 dniach) — **done 2026-05-17** *(`DiagnosticBundleExporter.swift` + button w Advanced tab; `docs/beta-tester-guide.md` 1-pager dla kolegi)*
- ⬜ **i18n / lokalizacja (Sub-cel 1.20, P-43)** — *bez tego polscy testerzy z PL UI dają śmieciowy sygnał. **HIGH priority — jedyny blocker po 1.6.***
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
- Sub-cel 1.32 (NOWY) Semantic Intent Library (W4) — *30-50 ogólnych intencji („wyślij wiadomość", „nowy task") rozpoznawanych w wielu apkach*
- Sub-cel 1.33 (NOWY) Confidence-based toast UI — *toast pokazuje 2-3 kandydatów ze stopniem pewności, gdy nie jesteśmy w 100%*

> *Uwaga: numery 1.30 i 1.31 zajęte przez Silent mode toggle i DMG export bundle (prereqs Fazy 1.7) — patrz commit `9453362`.*

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

## 🚧 Plan sesji na DZIŚ — **Finalize Fazy 1** (2026-05-18, ~4-5h)

> **Cel sesji:** zamknąć Fazę 1 scope-complete dla Bety. Po sesji wszystkie sub-cele Fazy 1 są w stanie 🟢 (done) lub ⏸️ (świadomie odroczone do Fazy 2 z uzasadnieniem). Następna sesja zaczyna Fazę 1.5 i18n (P-43) — jedyny hard-blocker przed Betą.

### Krok 1 — **Sub-cel 1.8 finalize** (~30 min, głównie Filip)

> **Po co (12-latkowi):** Mamy skrypt który nagrywa wideo z ekranu i pyta Claude'a „widzisz tu toast SFlow?". W poprzedniej sesji wykryliśmy że Claude halucynował 4 fałszywe toasty (mylił natywne menu z naszym). Napisaliśmy lepszy prompt v2. Teraz tylko musimy uruchomić skrypt i sprawdzić że halucynacje zniknęły.

**Kroki:**
1. **Filip** (lokalnie):
   ```bash
   ./scripts/sflow-video-llm.swift /tmp/sflow_video_eval_20260515T164056 docs/video-eval-test.md
   ```
   → sprawdza że 4 halucynowane toasty z Slack context menu znikają w raporcie
2. **Filip** (opcjonalnie, dla pewności): nagrać 60-90s screencast Notion Mail (compose/archive/reply) → `./scripts/sflow-video-eval <video.mp4> --llm`
3. **AI** czyta raport markdown, weryfikuje 0 wrong-toasts, flip status 1.8 → 🟢 w `audit-phase-1.md` + STATUS.md
4. **Commit:** `docs(sub-cel 1.8): video eval verified — prompt v2 eliminates 4 halucynacji`

**Acceptance:** raport `.md` z 0 hallucinated toasts dla Slack klatek.

---

### Krok 2 — **Sub-cel 1.12 finalize** (~3-4h, główna praca sesji)

> **Po co (12-latkowi):** Backend pyta Claude'a „jakie są skróty w tej apce". Dziś Claude sam decyduje czy googlać (`web_search` tool) — czasem omija dla niche apek. Dziś każemy mu explicite: „najpierw szukaj `{appName} keyboard shortcuts cheatsheet`, potem per-element". Plus zwiększamy budżet z 4 do 8 searchy. Potem reseedujemy nasze 5 bundled apek żeby zobaczyć efekt.

**Kroki:**

**2a. P-32 — Backend prompt update (~45 min):**
1. Otworzyć `backend/src/prompt.ts`, dodać do system prompt:
   ```
   STEP 1 (REQUIRED): Use web_search with these queries IN ORDER:
   1. "{appName} keyboard shortcuts cheatsheet"
   2. "{appName} hotkey list"
   3. For each visible UI element without obvious shortcut from menu_bar:
      "{appName} {elementTitle} shortcut"
   Use STRATEGIC searches — prioritize cheatsheets before per-element queries.
   ```
2. W `backend/src/claude.ts`: zwiększyć `max_uses` web_search z 4 → 8
3. Test: `cd backend && npm test` — wszystkie istniejące testy zielone
4. Deploy: `npx wrangler deploy` (zanotować nową version ID)
5. Commit: `feat(backend): explicit web_search step ordering + max_uses 4→8 (P-32, Sub-cel 1.12)`

**2b. Reseed 5 bundled apek z nowym promptem (~1.5h):**
```bash
osascript -e 'tell application "SFlow" to quit'
./scripts/sflow-reseed com.tinyspeck.slackmacgap
./scripts/sflow-reseed com.apple.Terminal
./scripts/sflow-reseed notion.id
./scripts/sflow-reseed com.anthropic.claudefordesktop
./scripts/sflow-reseed md.obsidian
```
Dla każdej apki:
- `jq '.rules | length' "$HOME/Library/Application Support/SFlow/rules/cache/{bundleId}.json"` — sprawdzić liczbę reguł
- `jq '.rules | map(select(.source | startswith("web_docs"))) | length' ...` — sprawdzić % źródeł `web_docs_*`
- **Acceptance:** ≥ ta sama liczba reguł co dziś (Slack 58, Obsidian 44, Terminal ?, Notion ?, Claude ?) i ≥2× więcej `web_docs_*` źródeł

**2c. Promote → bundled.json:**
```bash
./scripts/promote-to-bundled.sh com.tinyspeck.slackmacgap com.apple.Terminal notion.id com.anthropic.claudefordesktop md.obsidian
git diff SFlow/Resources/bundled.json | head -100  # sanity check
```

**2d. P-35 verify — DisplayTuner Try again (~15 min):**
1. Build SFlow w Xcode
2. Otworzyć Settings → Advanced → Apps tab
3. Znaleźć `com.benderbureau.displaytuner` (failed wcześniej z timeoutem >90s)
4. Klik „Try again"
5. Sprawdzić czy reguły się generują (streaming P-34 fix powinien rozwiązać)
6. Flip P-35 status: 🔵 partial → 🟢 done (lub ostać 🔵 jeśli nadal timeout)

**2e. Commit + status update:**
```bash
git add SFlow/Resources/bundled.json
git commit -m "feat(rules): reseed 5 bundled apps with P-32 explicit web_search (Sub-cel 1.12)"
```
Update statusów w `audit-phase-0.md` (P-32 ⬜→🟢, P-35 🔵→🟢/🔵) + `audit-phase-1.md` (Sub-cel 1.12 🔵→🟢).

**Acceptance Kroku 2:**
- [ ] Backend deployed z nowym promptem
- [ ] 5 bundled apek reseedowanych, ≥ same liczba reguł, ≥2× więcej `web_docs_*` źródeł
- [ ] DisplayTuner Try again zwraca reguły lub świadoma decyzja o pozostawieniu 🔵
- [ ] Bundled.json zaktualizowany, commit

---

### Krok 3 — **Formalny defer 1.3 + 1.13 + 1.16 + 1.11 część 2 → Faza 2** (~30 min, doc-only)

> **Po co (12-latkowi):** 3 (4) niedokończone sub-cele Fazy 1 nie są blokerami bety, tylko feature'ami skalowania kiedy będą prawdziwi userzy. Zamiast przeciągać Fazę 1 — formalnie zapisujemy że robimy je w Fazie 2. Czysta granica = wiemy gdzie jesteśmy.

**Kroki:**
1. W `audit-phase-1.md` Aktualne statusy sub-celów: zmienić 1.3, 1.11, 1.13, 1.16 z 🔵/⬜ → ⏸️ DEFERRED + dopisać sekcję „Defer rationale" na końcu pliku z uzasadnieniem każdego:
   - **1.3** — wymaga real userów do triggerów (≥20 missów/apka, ≥3 powt. tytuły) — sensowny test dopiero po Becie
   - **1.11 część 2** — sensowna analiza dopiero przy ≥200 events per layer; dziś mamy ~150 i są to events Filipa (n=1), nie populacji
   - **1.13** — skaluje quality eval na 100+ apek; przed Betą (5 testerów) ręczna analiza events.jsonl wystarczy. Plus halucynacje Haiku eval mogą zniekształcić bundled.json
   - **1.16** — internal-only dev tool, opcjonalny, kandydat do całkowitego dropu (zastąpiony Layer 0.6 + DiscoveredStore TTL 7d, które dają hover-once → instant flow)
2. W `roadmap.md` sekcja Faza 2: dodać nowy bucket „Carryover z Fazy 1 (4 sub-cele)" z linkami
3. Update STATUS.md (już zrobione w tej sesji — krok skomplikowany jest w tabeli)
4. **Commit:** `docs: formally defer Sub-cele 1.3/1.11/1.13/1.16 from Faza 1 to Faza 2`

**Acceptance:** każdy z 4 sub-celów ma jednolinijkowe uzasadnienie defera w `audit-phase-1.md`.

---

### Krok 4 — **Session wrap-up** (~15 min)

1. Update `STATUS.md` „Last sync" → dziś, status Fazy 1 → 100% scope-Bety
2. Update statystyk: P-X otwartych ↓ (P-32 → done), commitów +N
3. Update `roadmap.md` session log: „2026-05-18 — sesja Finalize Fazy 1: 1.8 verified, 1.12 closed (backend prompt + reseed 5 bundled), 1.3/1.11/1.13/1.16 formally deferred → Faza 2. Faza 1 scope-Bety complete."
4. **Commit:** `docs: session 2026-05-18 — Faza 1 scope-Bety complete`

---

## 🎯 Po sesji — co dalej

| Priorytet | Co | Czas | Po co |
|---|---|---|---|
| **#1** | Sub-cel 1.20 (P-43) **i18n / lokalizacja** | ~6-10h, jedna sesja | **JEDYNY hard-blocker przed Betą.** Polski user z PL menu = 0% pokrycia okien, beta-test śmieciowy |
| **#2** | P-19 bundled.json update path | ~2h | Resztka Fazy 0. Krytyczne **TYLKO** jeśli planujemy wysłać >1 wersję DMG do tych samych testerów (iteracja v0.1→v0.2 podczas Bety) |
| **#3** | Onboarding doc + rekrutacja | ~3h | co testować, jak zgłaszać → builduje na `docs/beta-tester-guide.md` |
| **#4** | Faza 1.7 Beta start | — | wysłanie DMG do 3-5 znajomych, 2 tygodnie pomiarów |
| **#5** *(opcjonalne)* | Sub-cel 1.6 → 15 verified | ~45 min | margines: VSCode/Spotify/Discord reseed |
| **#6** *(post-Beta)* | P-51 fix decyzja | — | runtime collection vs mouseover symulacja |

---

## 🔥 Otwarte blokery (top problemy)

| # | P-X | Co to (cel) | Blokuje | Status |
|---|---|---|---|---|
| 1 | ~~brak silent mode~~ | Tryb cichy: zbieraj dane bez wyświetlania toastów beta-testerom | ~~Beta~~ | 🟢 **zamknięte 2026-05-17** (kod gotowy, czeka na build) |
| 2 | ~~brak DMG export~~ | Paczka z logami którą tester sam zgrywa i wysyła Filipowi | ~~Beta~~ | 🟢 **zamknięte 2026-05-17** (kod gotowy, czeka na build) |
| 3 | ~~Faza 1.6 ≥10 verified~~ | Próg beta MVP wymaga 10 zweryfikowanych apek | ~~Beta~~ | 🟢 **zamknięte 2026-05-18** (10/10) |
| 4 | **P-43 i18n** | Wsparcie języków: rozumieć menu po polsku/niemiecku/itd. | beta-testerzy z PL UI = śmieciowy sygnał | **HIGH prio — JEDYNY hard-blocker przed Betą** |
| 5 | **P-19 bundled.json update path** | Po updatcie SFlow do nowej wersji shipping reguł nie nadpisują starych w `~/Library/Application Support/SFlow/rules/bundled.json` | release do userów (gdy v1.1 nigdy nie dotrze, beta-testerzy 1.0 utkną na starych regułach) | ⬜ **otwarte — resztka Fazy 0, fix przed pierwszym update'em DMG do testerów** (~2h: shipping version > user version → overwrite, user_overrides protected) |
| 6 | P-51 Electron lazy AX tree | Chromium/Electron eksponują shell AX tree podczas reseed — content desc puste do user activity | Notion/Obsidian/Linear/Cursor/Discord/VSCode/Slack desktop pełne pokrycie | **NEW 2026-05-17** mitigations w main (AXGroup w allowedRoles, settle 3s), fix decision po Becie |
| 7 | P-52 Parallel discovery status menu bar | DiscoveryStatus.running(appName) shows only last-started app gdy 2 apki uczą się naraz | UX, nie blocker | **NEW 2026-05-18** Faza 2 polish — plan: runningCount + tooltip |
| 8 | P-38 dropdown menu items | Wykrywanie elementów wewnątrz rozwijanych menu (palette ⌘K, popupy) | Cron, Linear ⌘K palette | czeka test |
| 9 | P-8 /v1/refresh z miss data | Backend regeneruje reguły gdy klient zgłasza ≥20 missów/apka — żeby reguły leczyły się same | jakość reguł długoterminowo | 🔵 częściowo (`?fresh=1` jest, miss-driven nie) — resztka Fazy 0 |
| 10 | P-21 backend observability dashboard | p95 latency, drop rate, rules-per-app — żebyśmy nie latali ślepo gdy będą userzy | quality regression invisible | 🔵 częściowo (structured JSON log ✅, dashboard ⬜) — resztka Fazy 0 |
| 11 | ~~P-32 web research backend~~ | Backend googluje skróty dla nieznanych apek — wyższa jakość reguł | jakość auto-discovered reguł | 🟢 **zamknięte 2026-05-18** (explicit STEP 1-3 + max_uses 8, reseed +12 reguł) |

---

## 📊 Statystyki projektu

| Metryka | Wartość |
|---|---|
| **Pierwszy commit** | 2026-05-08 |
| **Czas projektu** | ~10 dni |
| **Commitów total** | 219 (+4 z sesji Finalize Fazy 1 2026-05-18) |
| **Linijek Swift kodu** | ~5,910 (+9 LOC P-35 timeout fix) |
| **Backend testy passing** | 51 (+1 WEB_SEARCH STRATEGY test) |
| **Swift testy passing** | 250 |
| **Bundled apek z regułami** | 5 (Slack, Terminal, Notion, Claude, Obsidian) |
| **Bundled apek total** | 8 (3 puste: Notion Mail, Linear, Cron) |
| **Cached apek (auto-discovered)** | 35 |
| **Reguł w bundled.json** | **265** (63+73+59+24+46) — **+12 vs baseline po reseed 2026-05-18** |
| **Web_docs sources w bundled.json** | **69** (vs 56 baseline, +23%) — każda apka ma ≥1 web_docs reguła |
| **Verified apek (Sub-cel 1.6)** | **10/10** (6 🟢 + 4 🟡) — **gate met 2026-05-18** |
| **P-X problemów total** | 40 (+P-51, +P-52) |
| **P-X zamkniętych** | **~26** (+P-32 done, +P-35 mitigated) |
| **P-X otwartych** | 9 (+P-51 Electron + P-52 parallel status) |
| **P-X partial / in-progress** | 4 |
| **Sub-celi Fazy 1** | 16 — **po sesji 2026-05-18:** **12 🟢 done** (10 wcześniej + 1.8 + 1.12) + **4 ⏸️ deferred do Fazy 2** (1.3/1.11 cz.2/1.13/1.16). *1.6/1.7 wyodrębnione jako Fazy.* **Faza 1 scope-Bety COMPLETE.** |
| **Sub-celi Fazy 1.5** | 12 (2 done, 1 partial UAT, 9 pending) |
| **Sub-celi Fazy 1.6** | **10 verified ✅ (gate met 2026-05-18)** |
| **Sub-celi Fazy 1.7 prereq (1.30, 1.31)** | 2 done (silent mode + DMG export, czekają na build) |

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
