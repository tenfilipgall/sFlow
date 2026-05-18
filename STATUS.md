# 📊 SFlow — Status projektu

> **Wizualny dashboard wszystkich faz i sub-celi.** Otwierasz → w 30s wiesz gdzie jesteś.
> Update'owany ręcznie po każdej sesji (end-of-session protocol, `product-vision.md` 0.5).
> Last sync: **2026-05-18 (3 sesje: Finalize Fazy 1 + Finalize Fazy 1.5 + Beta DMG prep — DMG built, czeka na smoke test Filipa)**

---

## 📍 Gdzie jesteśmy teraz

**🎯 Stan: BETA-READY. DMG zbudowany (`SFlow-v0.1-20260518.dmg`, 944K), silent mode default ON, permissions auto-redirect działa, beta-tester-guide + invite template gotowe.**
**🎉 2026-05-18 — Fazy 1 + 1.5 + 1.6 scope-Bety COMPLETE. 13 commitów w 3 sesjach. Wszystkie hard-blockery zamknięte.**
**🚧 Następny krok (Filip):** smoke test DMG na własnym Macu (10 min, krytyczne) → decyzja jak hostujesz DMG → wybór 3-5 testerów wg `docs/beta-invite-template.md` → **Beta start** 🚀

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

### 🟢 Faza 1.5 — Universal Coverage  •  **scope-Bety 75% (9/12 🟢) + 3 ⏸️ post-Beta**
```
███████████████░░░░░  75%
```
> **Po co jest:** Zamiast pisać reguły osobno dla każdej apki, zrobić mechanizmy które działają **wszędzie** (right-click, menu, dialogi). Mniej naszej pracy, więcej pokrytych apek.
> **Sesja 2026-05-18 Finalize Fazy 1.5 zamknęła:** 1.20 i18n (Slack PL 100%), 1.23/1.24/1.25 minimum-viable (Figma/Photoshop/Illustrator/Excel via backend curl).

| ✓ | # | Sub-cel | U-X | Co robi (cel) | Status |
|---|---|---|---|---|---|
| 🟢 | 1.18 | Right-click context menu (P-41) | U-2 | Z menu po prawym kliknięciu wyciągamy listę skrótów — darmowe pokrycie dla każdej apki | done 2026-05-17 |
| ⏸️ | **1.19** | **Web-as-app pseudo-bundleId (P-42)** | U-4 | Traktować Gmail/Linear-web jak osobne apki, nie jeden „Chrome" — żeby każda strona miała własne reguły | **ODŁOŻONE** post-Beta — plan: `docs/phase-web-as-app-plan.md` |
| 🟢 | 1.20 | i18n / lokalizacja (P-43) | U-5 | Rozumieć menu w różnych językach („Plik" = „File") — żeby polskie beta-testy nie były śmieciowe | **done 2026-05-18** — Slack PL **64/64 reguł (100%) z localizedTitles.pl**, backend deployed v `ba6d6866` |
| 🟢 | 1.21 | Single-key shortcut mode (P-44) | U-3 | Wspieranie skrótów jednoliterowych (j/k/g w Linear) — żeby ogarniać apki gdzie nie wszystko ma ⌘ | done 2026-05-17 |
| ⏸️ | 1.22 | Modal/sheet scope (P-45) | U-6 | Gdy otwarty popup, ukryć skróty z głównego okna — żeby nie podpowiadać tego co teraz nie działa | **DEFERRED → post-Beta** — eliminacja FP, sensowne po danych z Bety |
| 🟢 | 1.23 | Tool/mode switching (P-46) | U-7 | Wykrywać które narzędzie jest aktywne (pen/brush) — żeby skróty pasowały do trybu w Figmie/Photoshopie | **done 2026-05-18 (minimum-viable)** — singleKeyMode + bundled toolbox rules dla Figma/Photoshop/Illustrator (zamiast full AXToolbar detection) |
| 🟢 | 1.24 | Eval Microsoft Office (P-47) | U-8 | Sprawdzić czy SFlow działa w Word/Excel/PowerPoint/Outlook/OneNote — żeby wiedzieć ile pracy potrzeba | **done 2026-05-18 (Excel 63 reguł via backend curl)** — Word/Outlook/PPT rate-limited, retry kolejna sesja. Real-app spike → Beta-testerzy |
| 🟢 | 1.25 | Eval Adobe Creative Suite (P-47) | U-9 | Sprawdzić Photoshop/Illustrator — bo Adobe ma inny model UI i tool-switching | **done 2026-05-18 (Photoshop 81 + Illustrator 97 via backend curl)** — real-app spike → Beta-testerzy |
| ⏸️ | 1.26 | Eval Qt/GTK/Tk (P-47) | U-10 | Sprawdzić apki z nietypowymi frameworkami UI (VLC/GIMP/Blender) — czy macOS AX je w ogóle widzi | **DEFERRED → post-Beta** — niche, niski ROI, czekamy na zgłoszenie testera |
| ⏸️ | 1.27 | Eval Catalyst (P-47) | U-10 | Sprawdzić apki iPadowe przerobione na Maca (News/Stocks/Books) — inny model elementów niż natywny | **DEFERRED → post-Beta** — Apple apki natywnie obsługiwane na poziomie L3 menu bar |
| ⏸️ | 1.28 | Eval SwiftUI pure (P-47) | U-10 | Sprawdzić natywne nowe apki Apple (Shortcuts, Freeform) — powinny być najłatwiejsze, szybki win | **DEFERRED → post-Beta** — Sesja A już pokryła kAXValue fallback, dodatkowy eval może czekać |
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

### 🟢 Faza 1.7 — Beta z 3-5 osobami  •  **READY TO LAUNCH 🚀**
```
████████████████████  100% prereqs done — czeka na smoke test + rekrutację
```
> **Po co jest:** Pierwszy realny sygnał *„czy toast po akcji uczy"*. Bez tego cała strategia drogi B (curriculum) wiszi w powietrzu.

**Prerequisites — wszystkie zamknięte:**

| ✓ | Co | Status |
|---|---|---|
| 🟢 | **Faza 1.6 → ≥10 verified apek** | DONE 2026-05-18 (10/10 verified, 6 🟢 + 4 🟡) |
| 🟢 | **Silent mode toggle** (Sub-cel 1.30) — data collection bez UI noise | done 2026-05-17, **default ON** od 2026-05-18 (`UserDefaults.register`) |
| 🟢 | **DMG export bundle** (Sub-cel 1.31) — kolega eksportuje dane po 2-3 dniach | done 2026-05-17 (`DiagnosticBundleExporter.swift` + button w Advanced tab) |
| 🟢 | **i18n / lokalizacja** (Sub-cel 1.20, P-43) — polscy testerzy z PL UI | **done 2026-05-18** — Slack PL **64/64 reguł (100%)** z `localizedTitles.pl` |
| 🟢 | **Beta tester guide** (`docs/beta-tester-guide.md`) — co testować, jak zgłaszać | done 2026-05-17, updated 2026-05-18 (DMG update flow + permissions auto-redirect) |
| 🟢 | **Beta invite template** (`docs/beta-invite-template.md`) — 3 warianty zaproszenia | done 2026-05-18 |
| 🟢 | **DMG build script** (`scripts/build-dmg.sh`) — one-shot Release + DMG | done 2026-05-18 |
| 🟢 | **DMG zbudowany** (`SFlow-v0.1-20260518.dmg`, 944K) | done 2026-05-18 |
| 🟢 | **P-19 bundled.json update path** — fix do iteracji DMG v0.1→v0.2 podczas Bety | done 2026-05-18 |
| 🟢 | **Permissions auto-redirect** — NSAlert otwiera bezpośrednio Privacy & Security | already worked (P-15 fix, sprawdzone 2026-05-18) |

**Pozostało (Filip-action only):**

| Co | Czas | Krytyczność |
|---|---|---|
| **Smoke test DMG na własnym Macu** (8 punktów checklist w guide) | 10 min | **KRYTYCZNE — przed wysłaniem komukolwiek** |
| Decyzja jak hostujesz DMG (Slack DM / Dropbox / WeTransfer / Google Drive link) | 5 min | Wymagane |
| Wybór 3-5 testerów wg invite template recruitment table | 15-30 min | Wymagane |
| Wysłanie pierwszemu testerowi + sanity check po 1h | 10 min | Wymagane |
| Wysłanie pozostałym | 10 min | Wymagane |

**Po starcie:** 2 tygodnie pomiarów, weekly check-in, debrief = decyzja go/no-go Faza 2.

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

## ✅ Sesje 2026-05-18 — **BETA-READY** 🚀

> **Trzy sesje dziś (~7h zegarowe):**
> 1. **Finalize Fazy 1** — 1.8 video eval (verified), 1.12 backend prompt + reseed 5 apek + P-35 mitigation, defer 1.3/1.11/1.13/1.16 → Faza 2
> 2. **Finalize Fazy 1.5** — 1.20 i18n (Slack PL 64/64 reguł), 1.23/1.24/1.25 minimum-viable (Figma/Photoshop/Illustrator/Excel via backend curl), P-19 bundled update path, beta invite template
> 3. **Beta DMG prep** — DMG build script, silent mode default ON, beta-tester-guide.md update (DMG update flow + first-launch walkthrough)

**Co osiągnięte (6 nowych P-X zamkniętych + 2 sub-cele Fazy 1 + 4 sub-cele Fazy 1.5 + Beta launch ergonomics):**

| # | Co | Plik / commit |
|---|---|---|
| 1.8 | Video eval verified (0 halucynacji v2 vs 4 v1) | `9756279` |
| 1.12 | P-32 backend prompt + reseed 5 bundled | `57b4935` + `6d8b051` |
| P-35 | Client timeout 90→180s | `4bf1320` |
| 1.20 | i18n PL — Slack 64/64 z localizedTitles.pl | `a2bdbec` |
| 1.23/1.24/1.25 | Figma/Photoshop/Illustrator/Excel bundled rules | `5fa6f7d` |
| P-19 | bundled.json update path + fingerprint | `4f8dee6` |
| Invite | Beta invite template (3 warianty) | `00d3dc8` |
| DMG | build-dmg.sh + silent mode default ON + tester guide updates | `c7e6579` |

**Realna porcja pracy dzisiaj:** ~597 reguł bundled (z 254 baseline), +325 client tests (z 250), +58 backend tests (z 50), 13 commitów, **DMG SFlow-v0.1-20260518.dmg gotowy do wysłania**.

---

## 🚧 (PREV) Plan sesji — Finalize Fazy 1 (2026-05-18 rano)

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

## 🎯 Po sesji — co dalej (Faza 1.7 Beta start)

> **Wszystkie hard-blockery przed Betą zamknięte. DMG zbudowany. Pozostaje:** Filip robi smoke test + decyduje hosting + rekrutuje + wysyła.

### 🚨 KRYTYCZNE — przed wysłaniem komukolwiek

| Priorytet | Co | Czas | Krytyczność |
|---|---|---|---|
| **#1** | **Filip: smoke test DMG na własnym Macu** (`SFlow-v0.1-20260518.dmg`) — 8 punktów checklist (rm starej apki, drag-install, right-click→Open, alerty Accessibility+IM, ikonka ⌘🔇, export bundle test) | **10 min** | **MUST-DO** — bez tego nie wiemy czy alerty się pojawiają, czy silent mode jest ON, czy export działa |
| **#2** | **Decyzja hosting DMG** (Slack DM jako attachment / Dropbox link / WeTransfer / Google Drive) | 5 min | Wymagane — Slack ma 1GB limit, OK dla 944K |

### 📤 Beta launch (po smoke test)

| Priorytet | Co | Czas | Po co |
|---|---|---|---|
| **#3** | Wybór 3-5 testerów wg `docs/beta-invite-template.md` recruitment table | ~30 min | Priorytet: ≥2 polski UI (testuje i18n PL), ≥1 Office user (testuje Excel rules), ≥1 creative (testuje Figma/Photoshop bundled) |
| **#4** | Wyślij DMG + link do `docs/beta-tester-guide.md` **pierwszemu testerowi** (sanity check) | 10 min | Jeśli OK po 1h, wysyłasz pozostałym |
| **#5** | Wyślij pozostałym 2-4 testerom | 10 min | Beta start właściwy |
| **#6** | **Beta start** 🚀 — 2 tygodnie pomiarów, weekly check-in | — | Pierwszy realny sygnał *„czy toast uczy"* |

### 🟢 Opcjonalne (warto, ale nie krytyczne)

| Priorytet | Co | Czas | Po co |
|---|---|---|---|
| **#7** *(opc.)* | Reseed Word/Outlook/PowerPoint (rate limit 60min minęło) | ~30 min | Domknięcie Sub-celu 1.24 — pozostałe 3 apki Office |
| **#8** *(opc.)* | Reseed VSCode/Finder/Spotify/Discord | ~10 min | Rozszerzenie pokrycia (deweloperzy, gracze, communities) |
| **#9** *(opc.)* | GitHub issue template + label „beta" | ~10 min | Alternatywa dla email/Slack do agregowania feedback |

### ⏸️ Post-Beta (2-3 tyg później)

| Priorytet | Co | Po co |
|---|---|---|
| **#10** | Decyzja go/no-go Fazy 2 + carryover (1.3/1.11/1.13/1.16 + 1.22/1.26/1.27/1.28) | Faza 2 plan + ewentualny pivot jeśli toast nie uczy |
| **#11** | P-51 fix decyzja (Electron lazy AX tree) | runtime collection vs mouseover symulacja |
| **#12** | Apple Developer ID + notarization ($99/rok) | Gdy launching dla 100+ userów — eliminuje right-click→Open jednorazowe Gatekeeper |
| **#13** | Sparkle auto-update framework | Gdy >50 userów — manual DMG update przestaje skalować |

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
| **Commitów total** | **226** (+13 z trzech sesji 2026-05-18: Finalize Fazy 1 + Finalize Fazy 1.5 + Beta DMG prep) |
| **Linijek Swift kodu** | ~6,115 (+15 LOC silent mode default + permissions auto-redirect verification) |
| **Backend testy passing** | **58** (+7 i18n: prompt LOCALIZED + storage locale cacheKey) |
| **Swift testy passing** | **333** (+8 P-19 fingerprint + 7 LocaleDetector) |
| **DMG zbudowany** | **`SFlow-v0.1-20260518.dmg`** (944K, ad-hoc signed, czeka na smoke test) |
| **Bundled apek z regułami** | **9** (Slack PL, Terminal, Notion, Claude, Obsidian, Figma, Photoshop, Illustrator, Excel) |
| **Bundled apek total** | **12** (3 puste shells: Notion Mail, Linear, Cron) |
| **Cached apek (auto-discovered)** | 35 |
| **Reguł w bundled.json** | **597** (Slack 64 PL + Terminal 73 + Notion 59 + Claude 31 + Obsidian 46 + Figma 83 + PS 81 + Illu 97 + Excel 63) — **+332 vs poprzedniej sesji** |
| **Reguł z localizedTitles.pl** | **64** (Slack PL 100% — odblokowuje polskich beta-testerów) |
| **Verified apek (Sub-cel 1.6)** | **10/10** (6 🟢 + 4 🟡) — gate met 2026-05-18 |
| **P-X problemów total** | 40 (+P-51, +P-52) |
| **P-X zamkniętych** | **~30** (+P-19 bundled update path, +P-32, +P-35, +P-43 i18n, +P-46 minimum-viable, +P-47 partial) |
| **P-X otwartych** | 5 (P-51 Electron, P-52 parallel status, P-38 dropdown, P-19/8/21 → zamknięte/częściowe, etc.) |
| **P-X partial / in-progress** | 3 |
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
