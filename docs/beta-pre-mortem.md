# SFlow Beta — Pre-mortem

> **Cel:** wyobraź sobie że beta SFlow z 5 osobami **całkowicie zawiodła**.
> Co się stało? Dla każdej hipotezy: jak zapobiec teraz.
>
> **Format:** "If we fail, here are 10 things that went wrong."
>
> **Trigger:** Sub-cel 1.7 ~3-4 tygodnie od dziś. Pre-mortem **przed**
> wyborem beta-testerów.

---

## Scenariusz: 2 tygodnie po beta launch

Beta-testerzy raportują:
- 2 wyłączyli SFlow po 3 dniach
- 2 nie używali w ogóle (zapomnieli że jest)
- 1 daje feedback "fajne ale niesinifikujące"

**Conclusion:** product-market fit zero. Decyzja → pivot lub kill.

---

## 10 hipotez "co poszło źle"

### F1 — Toast nie uczy nikogo (najgorszy scenariusz)

**Co:** User widzi toast 100×, dalej klika myszką. Mózg nie zmienia
behaviour bo toast pojawia się **po** kliku.

**Prawdopodobieństwo:** 4/5 (najwyższe).

**Mitigacja:**
- **Mierz keystroke usage** (Faza 2.2, drugi event tap) — wiemy ile razy
  user faktycznie wcisnął skrót klawiaturą
- Jeśli ratio `keyboardUsed/clicked < 5%` po 2 tygodniach → toast jest
  ineffective → potrzeba droga D (force blocker) lub droga C (trener)
- **Pre-beta:** Filip sam dla siebie sprawdza przez tydzień czy uczy się

**Sygnał do pivotu:** mniej niż 2 nowych skrótów per user po 2 tygodniach.

### F2 — Privacy concern blokuje od początku

**Co:** Beta-tester widzi "SFlow czyta nazwy klikalnych elementów" → odmawia
permissions → odinstall.

**Prawdopodobieństwo:** 3/5.

**Mitigacja:**
- Welcome screen explicit "co czytamy, co nie" (Faza 3.1 / welcome-screen-copy.md)
- Privacy tab w Settings: lista konkretnych pól + "Show me everything"
  button → otwiera events.jsonl w Finderze
- "Open source the privacy filter" — GitHub link do PrivacyFilter.swift

### F3 — Performance bug — SFlow spowalnia komputer

**Co:** Electron apka (Slack/Notion) ma ogromne AX tree (5000+ elementów).
Walk po kliknięciu trwa >100ms × każde kliknięcie → laggy UX.

**Prawdopodobieństwo:** 3/5.

**Mitigacja:**
- Profile na realnych apkach przed beta launch (Instruments Time Profiler)
- Hard cap: 6-level parent walk + 500 element skeleton (już zrobione)
- Worst-case detection: jeśli single AX call >50ms → timeout, log warning
- "SFlow działa wolno?" - troubleshooting w FAQ

### F4 — Niespodziewane false-positives w app

**Co:** SFlow pokazuje zły skrót w 20% kliknięć. User traci zaufanie po
3 incydentach. Cmd-klik feedback działa ale wymaga ręcznego action — większość
userów po prostu **odinstalle zamiast korygować**.

**Prawdopodobieństwo:** 3/5.

**Mitigacja:**
- Pre-beta self-test 7 dni, log every toast, manual review każdego
- Quality gate (synthetic Claude self-eval P-33 / Sesja 10) blokuje
  reguły score <3
- Pre-launch: top-20 bundled apek manual eval ≥80% accuracy
- Bias **konserwatywny**: lepiej brak toast niż wrong toast

### F5 — Beta-tester używa apek których nie znamy

**Co:** Filip wybiera 5 znajomych, ale używają niche apek (np. game
streaming software, dziwne CRM-y). SFlow w tych apkach = 0 pokrycia.
Beta-tester widzi "SFlow nic nie robi w moim głównym workflow."

**Prawdopodobieństwo:** 4/5.

**Mitigacja:**
- Pre-beta survey: "Wymień top 5 apek z których korzystasz codziennie"
- Filter beta-testerów: tylko jeśli ≥3 z top-5 są w bundled.json
- Reseed niszowych apek przed beta start jeśli to <5 apek

### F6 — Onboarding zbyt długi/agresywny

**Co:** 5 ekranów welcome + 2 permissions + 4-min eval app selection →
beta-tester poddaje się przed użyciem.

**Prawdopodobieństwo:** 3/5.

**Mitigacja:**
- Welcome **minimum 3 ekrany** (welcome / permission #1 / permission #2)
- Top-apps selection — **skippable**, default = empty (auto-discovery)
- Demo z toastem — w pierwszym kliknięciu, nie w setup

### F7 — Multi-monitor / fullscreen toast nie renderuje

**Co:** Beta-tester (designer) używa external monitor + Slack fullscreen.
Outstanding blocker `2026-05-16-slack-toast-not-rendering.md` nie został
fixowany. SFlow **wygląda na nieaktywne**.

**Prawdopodobieństwo:** 4/5 (3 z 5 testerów multi-monitor).

**Mitigacja:**
- **PRZED BETA** zaadresować outstanding blocker (deep-dive H1-H5)
- Fallback Alt A (NSStatusBar animation) jako worst-case
- W onboardingu: "Czy używasz wielu monitorów? Test toast na każdym."

### F8 — Pricing expectation mismatch

**Co:** Beta-tester zakłada że SFlow będzie darmowe forever. Gdy pytamy
o feedback "ile zapłaciłbyś" → "nic". Brak walidacji willingness-to-pay.

**Prawdopodobieństwo:** 3/5.

**Mitigacja:**
- Briefing pre-beta: "to są **3 miesiące do paid product**, twój feedback
  decyduje pricing model"
- W debrief'ie pytania **wprost** o pricing: "$25 one-time vs $5/mc — co
  wybierasz, dlaczego?"
- Lemur incentive: "wczesni testerzy = pierwsza paid licencja gratis"

### F9 — Filip nie ma czasu na bug fixing podczas bety

**Co:** Beta zaczyna, bug zgłoszony, Filip pracuje dla klienta inny weekend,
nie naprawia, beta-tester odpuszcza.

**Prawdopodobieństwo:** 4/5 (Filip solo, ma inne projekty).

**Mitigacja:**
- **Pre-commit 1-week dedicated time** przed beta launch
- Bug triage SLA: HIGH inside 24h, MEDIUM inside 72h, LOW post-debrief
- Communicate "responsywność uczę się" w briefingu

### F10 — Lack of "moment of joy"

**Co:** SFlow działa technicznie, ale user nie ma **pamiętnej** chwili
"wow, ten toast nauczył mnie czegoś nowego dziś". Wszystko zlewa się w
neutralny pasek info.

**Prawdopodobieństwo:** 3/5.

**Mitigacja:**
- Większy/bardziej widoczny pierwszy toast (Faza 3.2 intro toast)
- Po pierwszym `shortcut_used` event: rare celebratory animacja
  (subtle confetti? lub 2s "+1 minute saved" badge)
- Tygodniowy in-app raport (Faza 5) — "zaoszczędziłeś 12 minut" jako
  highlight moment

---

## Summary — top 3 najprawdopodobniejsze failure modes

1. **F1 — Toast nie uczy** (4/5) — fundamentalny PMF risk
2. **F5 — Niche apek beta-testerów** (4/5) — łatwy do mitygacji
3. **F7 — Multi-monitor toast bug** (4/5) — outstanding technical blocker
4. **F9 — Filip czas** (4/5) — process discipline

**Top 3 mitigations to implement:**
1. **Keystroke monitoring** (Faza 2.2) — measure F1 empirically
2. **Resolve outstanding toast blocker** PRZED beta (mitigates F7)
3. **Filter beta-testerów po top-apps overlap** (mitigates F5)

---

*Pre-mortem napisany 2026-05-17 offline. Re-read przed wyborem testerów +
re-read 1 tydzień po beta launch (mid-flight correction).*
