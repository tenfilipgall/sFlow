# SFlow Decision Log

> **Cel:** rejestr wszystkich znaczących decyzji projektowych. Każda
> decyzja zawiera **co**, **dlaczego**, **alternatywy odrzucone**, **kto**.
>
> **Why this exists:** za 3 miesiące AI / Filip nie pamięta dlaczego coś
> wybrano. Bez log'u decyzje się powtarzają lub cofają bez powodu.
>
> **Format:** reverse-chronological (najnowsza decyzja na górze).

---

## D-21 — 2026-05-17 — Sesja C tylko jeśli B generalizuje

**Co:** Sesja C (backend `/v1/discovered` crowdsource) zostaje odłożona
**do empirycznego potwierdzenia** że Sesja B (TooltipObserver) działa na
≥3 z 4 apek (Linear/Discord/Slack/Notion main).

**Dlaczego:** Sesja B działa na Notion-rodzinie (Notion Mail, Notion Calendar).
Jeśli to **wszystkie** apki gdzie React-portal tooltipy są w drzewie AX —
crowdsource jest niepotrzebny (wąski TAM). Jeśli generalizuje się →
crowdsource ma sens.

**Alternatywy odrzucone:**
- "Robimy C niezależnie" — ryzyko że zbudujemy infrastrukturę dla 1
  apki-rodziny
- "Robimy C i sprawdzimy potem" — sequencing wymaga decyzji po danych

**Decyzja:** Filip wykonuje test B na 4 apkach (~15 min eval) → decyzja
go/no-go dla C.

---

## D-20 — 2026-05-17 — Faza 1.5 między Fazą 1 a 2

**Co:** Nowa **Faza 1.5: Universal Coverage** wprowadzona w `roadmap.md`,
między Fazą 1 (jakość pokrycia) a Fazą 2 (infrastruktura nauki).

**Dlaczego:** Po analizie 15 dziur uniwersalności + 5 nieobsługiwanych
typów apek (`universality-gaps-and-windows-2026-05-16.md`), 6 priorytetowych
mechanizmów (G-1..G-4, G-7, G-8) **musi być** przed Fazą 2 — Faza 2
buduje na założeniu szerokiego pokrycia apek.

**Alternatywy odrzucone:**
- "Wszystkie G-X w Fazie 2" — Faza 2 to wymagająca infrastruktura nauki,
  rozpraszanie na 6 nowych warstw spowolniłoby
- "Wszystkie G-X w Fazie 3" — opóźnia drogę B nauki, target market traci
  zainteresowanie
- "Nie robić universal, polegać na manual reseed" — nie skaluje na 100+ apek

---

## D-19 — 2026-05-16 — Sprint order: U-1 → U-2 → U-3 → U-4

**Co:** Kolejność sesji Fazy 1.5 ustalona przez **ROI scoring** (ROI = C×P×W/K):
1. U-1 (B.1 finalize) — ROI 1440
2. U-2 (Right-click) — ROI 270
3. U-3 (Single-key) — ROI 112
4. U-4 (Web-as-app) — ROI 64

**Dlaczego:** ROI scoring uwzględnia koszt, coverage, pewność działania
i wartość dla usera. Pre-flight empirical probe wymagany przed U-4 — bez
probe ROI U-4 spadłby z 64 do <30.

**Alternatywy odrzucone:**
- Kolejność alfabetyczna / chronologiczna — ignoruje ROI
- "U-5 i18n jako #1" — non-EN market jeszcze nie zwalidowany (zero beta-testerów PL)
- "U-7 jako #2" — wartość zależy od U-3 (single-key) preceding

---

## D-18 — 2026-05-16 — B.1: TooltipNameFilter + PrivacyFilter as separate concerns

**Co:** B.1 follow-up rozbity na 2 pure helpery: `TooltipNameFilter`
(odrzucanie "shortcut"/"hotkey") + `PrivacyFilter` (redact PII at
write-time).

**Dlaczego:**
- Dwa różne pipeline'y — TooltipObserver pre-write, EventLogger write-time
- DRY: PrivacyFilter używany **też** w przyszłej Sesji C dla `/v1/discovered`
  upload
- Testability: pure functions, łatwe unit tests (33 nowych testów)

**Alternatywy odrzucone:**
- Single big `ContentFilter` class — zła kohezja, dwa różne purposes
- Refactor istniejącego `containsSensitiveText` w TooltipObserver —
  fragmenting privacy logic across 2+ files

---

## D-17 — 2026-05-16 — Redact-not-skip dla MissEvent PII

**Co:** PII w MissEvent jest **zamazana** (`[REDACTED]`) zamiast **całkowicie
skipowana**.

**Dlaczego:** zachowujemy `bundleId` + `role` + `identifier` (debug context)
ale ukrywamy `desc`/`title`/`value`/`subtreeLabel`. Pozwala diagnozować
coverage gaps bez wycieku PII.

**Alternatywy odrzucone:**
- Skip cały event — straci sygnał coverage gap dla apek z PII (WhatsApp,
  Notion z prywatnymi notatkami)
- No redaction — wycieki PII w events.jsonl unacceptable

---

## D-16 — 2026-05-16 — Windows port odłożony do Q1 2027

**Co:** Windows port **świadomie odłożony** do końca 2026 / Q1 2027.

**Dlaczego:** 3 strategiczne powody:
1. Faza 1 beta nie zamknięta — nie wiemy czy core hypothesis działa
2. Refactor Swift→Rust to ~2 miesiące opóźnienia innych fix-ów
3. Mac power-userzy płacą; Windows enterprise często bezpłatnie z corporate
   licenses — wymaga innego modelu sprzedaży

**Alternatywy odrzucone:**
- "Robimy parity Mac+Win od razu" — wątpliwy PMF, podwojony koszt
- "Tylko Windows" — Filip nie ma Windows expertise
- "Electron cross-platform" — ironicznie SFlow walczy z Electron AX
  problems, sami być Electron = bad UX

---

## D-15 — 2026-05-16 — Eval Adobe **po** U-7 (tool/mode)

**Co:** Manual eval Adobe Creative Suite (Photoshop, Illustrator, Premiere)
zostanie **odłożony** do zaimplementowania U-7 (tool/mode switching, G-8).

**Dlaczego:** Toolbox Adobe = ~70% wartości skrótów w tych apkach. Bez
U-7 eval da sztucznie słabe wyniki (Sub-cel 1.25 → POOR niezależnie od
reality).

**Alternatywy odrzucone:**
- Eval przed U-7, "wiedzieć baseline" — koszt ~10h na test który wiemy że
  zwróci POOR, marginalny information gain
- Skip Adobe całkowicie — zbyt wąski (Adobe to power-userzy z payment power)

---

## D-14 — 2026-05-15 — Sesja A+B chosen over reseed strategy

**Co:** Empiryczny problem Notion Mail Chromium → rozwiązany przez Sesję A
(walk-down children + kAXValue fallback) + Sesję B (TooltipObserver),
NIE przez per-app rules generated by Claude.

**Dlaczego:** Per-app reguły dla Notion Mail wymagałyby manualnego mapowania
"icon → action name → shortcut" dla każdej z ~30 ikonek. Niezskalowalne na
inne Chromium apki. Sesja A+B działają **automatycznie** dla wszystkich
Chromium apek razem.

**Alternatywy odrzucone:**
- "Backend Claude generuje reguły z screenshot" — vision API drogie + zawodne
- "Manual mapping per Chromium app" — nie skaluje

---

## D-13 — 2026-05-15 — Sesja B priorytet nad A5

**Co:** Po Sesji A nie zrobiono A5 (rich parent-log dla deep diagnostics).
Bezpośrednio przeskoczono do Sesji B.

**Dlaczego:** Sesja A dała "minimum viable" pokrycie Notion Mail; A5 miał
być **diagnostyką jeśli A nie wystarczy**. A wystarczyła + Sesja B jest
**bardziej generic** mechanism.

**Alternatywy odrzucone:**
- A5 najpierw — większy info gain ale nie unblock'uje nowych use case'ów

---

## D-12..D-1 — pre-2026-05-16

Decyzje przed dziś (B.1 + Phase 1.5 formalized). Patrz git log + session log
w `roadmap.md` dla rekonstrukcji historycznej.

Kluczowe wcześniejsze decyzje (parafrazowane):
- D-12: Layer architecture L0..L4 — kolejność prioritet od najbardziej
  authoritative (AXKeyShortcuts) do najmniej (universal heuristics)
- D-11: Backend Cloudflare Workers + Claude API zamiast lokalnego LLM
- D-10: Cache key `bundleId:major.minor` — pozwala patch updates dzielić cache
- D-9: TCC permissions (AX + Input Monitoring) wymagane — alternatywy
  (np. private API hooking) odrzucone jako fragile
- D-8: Manual eval baseline > auto eval — bez human-in-loop nie wiemy czy
  reguły są poprawne
- D-7: Beta dla 3-5 osób zaufanych przed public launch — minimize early
  PR risk
- ... (do uzupełnienia retrospektywnie jeśli potrzebne)

---

*Decision log napisany 2026-05-17 offline jako reverse-chronological
inwentaryzacja. Update **dopisując D-N+1 na górę** po każdej znaczącej
decyzji.*
