# Risk register — Faza 1.5

> **Cel:** lista ryzyk implementacyjnych dla sesji U-1..U-10. Każde ryzyko
> ma: prawdopodobieństwo × impact = severity, plus mitigation.
>
> **Update cadence:** per sesja — close zamknięte ryzyka, dodaj nowe.

---

## Legenda

- **P (prawdopodobieństwo):** 1 (rare) — 5 (certain)
- **I (impact):** 1 (kosmetyczny) — 5 (block whole phase)
- **Severity:** P × I

| Severity | Klasa |
|---|---|
| 1-4 | LOW — acceptable, monitor |
| 5-12 | MEDIUM — mitigate before start |
| 13-25 | HIGH — block until resolved |

---

## R-1.5.1 — TooltipNameFilter integration zderza się z WIP TooltipObserver

**Severity:** P=4 × I=3 = **12 MEDIUM**

**Opis:** Filip ma +97 LOC w TooltipObserver (diag mode). Moja edycja 1-linia
B.1 integracji może być w obszarze konfliktującym (sąsiedztwo `f.name` access
w `scanForTooltip`).

**Mitigation:**
- Filip commituje WIP **najpierw**
- Potem U-1 edycja — git diff sprawdza że jest poza diag mode lines
- Build + 285 testów weryfikuje brak regresji

**Status:** Aktywne. Mitigacja w atomic plan U-1.

---

## R-1.5.2 — AXURL nie istnieje empirycznie (U-4 blocker)

**Severity:** P=3 × I=4 = **12 MEDIUM**

**Opis:** Hipoteza 1 (AXURL w `AXWebArea`) może nie być eksponowana przez
Chromium na Mac. Bez tego U-4 (web-as-app) trzeba zbudować na Hipotezie 2
(title parsing) — fragile i lokalizowane.

**Mitigation:**
- Pre-flight probe (`scripts/sflow-probe-ax-url.swift`) **przed** start
- Hipoteza 2 ma fallback whitelist 20 domen → mapping z title fragments
- W najgorszym case: U-4 robi tylko top-5 popularne domeny przez title
  match, nie aspires do generic

**Status:** Aktywne. Pre-flight test required.

---

## R-1.5.3 — Right-click menu znika za szybko

**Severity:** P=3 × I=3 = **9 MEDIUM**

**Opis:** macOS native context menu zamyka się natychmiast po kliknięciu
item-a. 300ms delay scan może chybić w niektórych szybkich workflow.

**Mitigation:**
- Zmniejszyć delay do 150ms (kompromis: AXMenu jeszcze nie zrenderowany?)
- Bonus: zapisywać znalezione items do `DiscoveredStore` z rect → cache
  dla powtórnych otwarć
- Test empiryczny: ile razy `findOpenMenu` zwraca nil mimo prawdziwego
  right-clicku

**Status:** Aktywne. Mitigacja w U-2 plan §3.

---

## R-1.5.4 — Chromium context menu vs natywne

**Severity:** P=4 × I=2 = **8 MEDIUM**

**Opis:** Chrome, Comet, Slack często mają **własne** context menu (Chromium
rendered), nie natywne macOS — nie ma `kAXMenuItemCmdChar`.

**Mitigation:**
- U-2 etap 1 pokrywa natywne (większość: Finder, Notion native, Mail, etc.)
- Chromium context menu = pattern z P-38 (inline shortcut suffix "Mark
  unread U") → łączy się z Sesją C.5 (MenuItemObserver)
- W U-2 zaznaczyć że pewne apki "mają własne menu, czeka na C.5"

**Status:** Aktywne. Dokumentowane jako known limitation.

---

## R-1.5.5 — i18n: Claude generuje literalne tłumaczenia zamiast UI labels

**Severity:** P=4 × I=3 = **12 MEDIUM**

**Opis:** Dla niszowych apek bez oficjalnej PL/DE wersji docs, Claude może
zgadywać literalne tłumaczenie ("Quick Find" → "Szybkie Znajdź" zamiast
"Wyszukaj").

**Mitigation:**
- Prompt v2 dla U-5 explicit: "actual AX exposed strings, not literal
  translation"
- Quality gate (P-33 / Sesja 10) — synthetic eval flag dziwne tłumaczenia
- Empiryczny test: Filip reseed Slack PL, sprawdzi 5 reguł czy matchują
  rzeczywiste UI

**Status:** Aktywne. Sub-cel 1.20 jest świadomie odłożony do non-EN
beta-tester sygnału.

---

## R-1.5.6 — ROI re-ranking nie odpowiada user experience

**Severity:** P=3 × I=4 = **12 MEDIUM**

**Opis:** ROI scoring używa Coverage × Pewność × Wartość / Koszt. Każdy
z 4 wymiarów to **moja subiektywna** ocena. Real-world feedback z bety
może odwrócić ranking (np. U-5 i18n okaże się krytyczne dla PL userów,
ROI=21 było underestimated).

**Mitigation:**
- Re-rankować po pierwszej rundzie bety
- ROI to **rekomendacja**, nie sztywne wymaganie — Filip może swap'ować

**Status:** Akceptowane. Soft commitment do re-rankingu w czerwcu.

---

## R-1.5.7 — Single-key mode false-positives w mainstream apkach

**Severity:** P=3 × I=3 = **9 MEDIUM**

**Opis:** Jeśli `features.singleKeyMode: true` przez przypadek trafi do
auto-discovered cache (Claude prompt nie zna feature), Slack/Mail może
zacząć strzelać single-char toastami.

**Mitigation:**
- Schema flag jest **manual edit only** w bundled.json
- Backend prompt explicit nie dotyka `features` field
- Test: backend nie pisze `features` w response

**Status:** Aktywne. Test verification w U-3 plan §7 ryzyko 1.

---

## R-1.5.8 — Modal scope wprowadzi regresje istniejących reguł

**Severity:** P=2 × I=4 = **8 MEDIUM**

**Opis:** Default `scope=nil = ["main"]` mógł by spowodować że istniejące
reguły **przestaną** odpalać w sheet'ach gdzie wcześniej działały (np. ⌘C
w Save dialog text field).

**Mitigation:**
- Default `scope=nil` = "any context" (sekcja 7 ryzyko U-6 plan) zamiast "main only"
- Strict scoping (`scope=["sheet"]`) jest **opt-in** dla nowych reguł
- Regression test: existing rules w cache/bundled bez scope dalej matchują

**Status:** Aktywne. Decyzja design w U-6 plan §7.

---

## R-1.5.9 — Slack toast outstanding blocker nie zostanie rozwiązany

**Severity:** P=3 × I=5 = **15 HIGH**

**Opis:** Toast nie renderuje na 2. monitor + fullscreen Slack. Outstanding
blocker dla drogi A (intro) i drogi B (nauka).

**Mitigation:**
- Sesja deep-dive H1-H5 (50 min) — w 80% przypadków diagnoza pozwoli fix
- Fallback Alt A (NSStatusBar animation) gdy NSPanel zawodzi specificnie
  dla fullscreen Spaces — partial coverage
- Worst case Alt B (Quartz layer) — niezachęcające ale działa

**Status:** Aktywne. **HIGH severity** — blokuje walidacja drogi A/B w
realistycznym workflow.

---

## R-1.5.10 — Backend rate limit przy reseed 20+ apek

**Severity:** P=2 × I=2 = **4 LOW**

**Opis:** Reseed wszystkich bundled apek (Sub-cel 1.6) + manual eval 30+
może hit rate limit Cloudflare lub Anthropic billing.

**Mitigation:**
- Backend rate limit 10/h per IP (już)
- Reseed batchowo: max 5 apek na godzinę
- Filip ma >$5 budget na Anthropic, ~$0.05/apka × 30 = $1.50

**Status:** Aktywne. Monitorować podczas U-8..U-10.

---

## R-1.5.11 — Beta feedback nie dotrze w terminie

**Severity:** P=4 × I=4 = **16 HIGH**

**Opis:** 3-5 beta-testerów obiecuje feedback po 2 tygodniach. Empirycznie
~60% nigdy nie odpowiada bez pushu. Bez feedback'u nie wiemy czy Faza 2+
ma sens.

**Mitigation:**
- 30-min call **scheduled at invite** (nie "jak będziesz miał czas")
- Strukturalny feedback form Google Form / Typeform z 5-7 pytaniami
- Lemur incentive: "premium licencja bezpłatna dla pierwszej 5"
- Pre-call 15 min "co testujesz" reset focus

**Status:** Aktywne. HIGH severity bo brak feedback'u → ślepa Faza 2.

---

## R-1.5.12 — Privacy regression przy rapid changes

**Severity:** P=2 × I=5 = **10 MEDIUM**

**Opis:** Faza 1.5 ma 6+ nowych warstw dotykających danych klikowych.
Łatwo wprowadzić bug który omija PrivacyFilter (np. nowy code path nie
przechodzi przez `EventLogger.logMiss`).

**Mitigation:**
- PrivacyFilter test coverage extending z każdym new pipeline path
- Code review checklist: "czy ta zmiana dotyka content/title/desc?
  → PrivacyFilter call wymagany?"
- Post-build regression: parse latest events.jsonl, grep dla emoji /
  email patterns; alert jeśli znajduje

**Status:** Aktywne. Process discipline.

---

## Summary

| Severity tier | Count | Open |
|---|---|---|
| HIGH (13-25) | 2 | 2 |
| MEDIUM (5-12) | 7 | 7 |
| LOW (1-4) | 1 | 1 |

**Top priorities to monitor:**
1. R-1.5.11 — beta feedback timeline (HIGH)
2. R-1.5.9 — Slack toast outstanding blocker (HIGH)
3. R-1.5.1, R-1.5.5, R-1.5.6 — wszystkie MEDIUM-12

---

*Risk register napisany 2026-05-17 offline. Update per sesja.*
