# SFlow Beta — pre-release checklist (Sub-cel 1.7)

> **Cel:** lista wszystkiego co musi być gotowe **przed** wpuszczeniem 3-5
> beta-testerów. Sub-cel 1.7 w `audit-phase-1.md`.
>
> **Pre-requisite:** zamknięte Fazy 1 + 1.5 priorities (U-1..U-6). Coverage
> 20+ apek z `coverage-report.md`.
>
> **Cel czasowy:** 2 tygodnie od dziś (~koniec maja 2026), zakładając
> tempo 2-3 sesji/tydzień.

---

## 1. Code & build readiness

- [ ] **U-1 (B.1) zacommitowane** — TooltipNameFilter + PrivacyFilter
      aktywne. Bez tego false-positives + PII w events.jsonl beta-testerów.
- [ ] **Wszystkie 285+ testy passing** w `xcodebuild test -scheme SFlow`
- [ ] **`xcodegen generate` clean** — projekt regenerowalny z `project.yml`
- [ ] **Code signing OK** — `codesign -dv --verbose=4 SFlow.app` zwraca
      poprawny Developer ID (nie tylko Apple Development) **lub** plan
      "rozdajemy `xattr -dr com.apple.quarantine SFlow.app` instructions"
- [ ] **Notarization** (opcjonalne, ale rekomendowane) — `xcrun notarytool`
      submit + staple
- [ ] **DMG zbudowany** z `create-dmg` lub manual — `SFlow-0.1.0-beta.dmg`
- [ ] **Crash reporter** — minimum dziennika w `Application Support/SFlow/crashes/`
      lub integracja z PLCrashReporter (do zdecydowania)

---

## 2. Onboarding flow

- [ ] **Welcome screen** (Sub-cel z Fazy 3 — może być prostsza forma w beta):
      - Tłumaczenie "co to SFlow"
      - Granty: AX permission + Input Monitoring
      - Możliwość włączenia telemetry (default OFF dla bety)
- [ ] **Permission alerts działają** — jak user odmówi AX, jasny alert z
      link do System Settings. Sub-cel P-15 closed, sprawdzić że still OK.
- [ ] **First-run experience** — pierwsze 3 klika user widzi **wyraźny**
      toast (nie standardowy mini-pill). Edukacyjny.
- [ ] **Quit confirmation** — żeby nie zamknąć przez przypadek
- [ ] **"Help" menu** — gdzie zobaczyć licznik kliknięć, gdzie wyłączyć
      apke, gdzie zgłosić bug

---

## 3. Privacy & data

- [ ] **Privacy disclosure w Settings** — explicit lista co SFlow zbiera:
      - "Mouse click position" — TAK, lokalnie
      - "Element labels (title/desc)" — TAK, lokalnie + crowdsource opt-in
      - "Email/contact names" — NIE (PrivacyFilter redactuje)
      - "Window content" — NIE
- [ ] **Toggle "Log miss events"** w Settings (Sesja 3 dodała) — default ON
      w beta dla diagnostics, ale **disclosure że to robi**
- [ ] **Toggle "Telemetry"** — default OFF w beta. Można włączyć po onboarding.
- [ ] **"Clear all my data"** w Settings — usuwa `events.jsonl`,
      `false_positives.jsonl`, `discovered/`, `attempted.json`
- [ ] **PrivacyFilter live test** — beta tester ma WhatsApp/Notion z PII;
      eksport `events.jsonl` przed dystrybucją; sprawdź że `[REDACTED]`
      jest tam gdzie powinno być

---

## 4. Coverage baseline

- [ ] **20+ zweryfikowanych apek w bundled.json** — patrz `coverage-report.md`.
      Minimum: Slack, Notion, Notion Mail, Notion Calendar, Claude Desktop,
      Obsidian, Linear, Cursor, Terminal, Mail, Finder (10 apek z ekosystemu
      Filipa) + 10 wybranych z eval (Office cherry-pick: Excel, Word, Outlook,
      Catalyst: News, Stocks, SwiftUI: Shortcuts, plus reseed Xcode, Console,
      CleanShot, Spotify).
- [ ] **Coverage report opublikowany** w GitHub README lub osobnej stronie —
      lista wspieranych apek z procentowymi HIT rates
- [ ] **"Not supported" lista** — Blender, gry, niektóre Adobe canvas —
      jawnie zakomunikowane

---

## 5. Feedback infrastruktura

- [ ] **Cmd-klik na toast = false-positive** (P-4 closed) — sprawdzić że
      działa w beta
- [ ] **"Report an issue" link w Settings** — otwiera mailto: lub
      GitHub Issues (Filip decyduje gdzie zbiera bugi)
- [ ] **Discord/Slack kanał dla bety** lub group email — sposob comunikacji
- [ ] **Beta-tester onboarding email/doc** — co testować, jak zgłaszać,
      kiedy następna iteracja
- [ ] **Feedback form** (Google Form / Typeform) z 5-7 strukturalnymi
      pytaniami zamkniętymi (po 1 tygodniu i po 2 tygodniach)

---

## 6. Telemetry (beta-specific)

- [ ] **Auto-prompt po 7 dniach** "Wszystko OK? Chcesz wysłać raport bug?"
- [ ] **Anonymous user ID** — UUID per beta-tester w `~/Library/.../user.json`
- [ ] **Aggregates upload** (Faza 2.4 — może być **uproszczona** wersja
      w beta: tylko per-day rough metrics, bez per-app)

---

## 7. Documentation dla bety

- [ ] **README.md / Welcome doc** — co to SFlow, dlaczego, jak działa
- [ ] **Known issues** — lista znanych bugów (Slack 2. monitor toast,
      Blender unsupported, etc.)
- [ ] **Roadmap dla bety** — co planujemy w następnych 2 tygodniach (żeby
      tester wiedział że feedback wpłynie na priorytety)
- [ ] **"How to give feedback"** — gdzie, kiedy, w jakim formacie
- [ ] **FAQ** — top 10 oczekiwanych pytań:
      - "Dlaczego nie widzę toastu?" → AX permission, cache hot, etc.
      - "Apka nie jest wspierana — co zrobić?" → auto-discovery działa
      - "Mogę dostać zwrot pieniędzy?" → free beta, brak płatności
      - "Jak wyłączyć?" → menu bar → Quit
      - "Czy moje dane idą na serwer?" → tylko jeśli włączysz telemetry
      - "Apka crashuje" → quit + restart, send crash log
      - "Skróty są w złym języku" → SFlow nie ma jeszcze i18n (Sub-cel 1.20)
      - "Toast pokazuje zły skrót" → cmd-klik na toast (false-positive)
      - "Niektóre apki nie działają" → patrz "Known issues"
      - "Kiedy będzie wersja Windows?" → "Może 2027, focus na Mac"

---

## 8. Tech infrastruktura (beta)

- [ ] **Hosting backendu** — `sflow-rules.shortcutflow.workers.dev` aktywny,
      KV cache OK, rate limit OK
- [ ] **Monitoring backendu** — minimum Cloudflare dashboard (logs, errors)
- [ ] **`/v1/discover` healthy** — sanity check dla 5 random bundle IDs
      przed dystrybucją
- [ ] **Update channel** — gdzie beta-tester dowie się o nowej wersji?
      Plan: ręczny email + DMG link. Auto-update (Sparkle) w Fazie 6.

---

## 9. Selection beta-testerów

- [ ] **Lista 3-5 osób** — kim? Filipa zaufani znajomi, mix:
      - 1-2 developerów (Slack/VSCode power-userzy)
      - 1-2 knowledge workers (Notion/Linear)
      - 1 designer (Figma) — optymalnie po U-7
- [ ] **Briefing** każdej osoby — pre-call 15 min "co testujesz, co zgłaszać"
- [ ] **Consent form** — explicit "wiem że SFlow zbiera X danych lokalnie,
      może wysyłać Y jeśli włączę telemetry" — bardzo prosty (~3 zdania)

---

## 10. Po-beta debrief (po 2 tygodniach)

- [ ] **30-min call z każdym tester** — open-ended pytania
- [ ] **Aggregate feedback** — top 3 wishes, top 3 bugs
- [ ] **Decision checkpoint** (z `audit-phase-1.md` execution sequence
      sesja 16): jeśli toast nie uczy (<2 nowych skrótów per user) →
      PIVOT, sesje 13+ nie istnieją w obecnej formie.
- [ ] **Update product-vision** — sekcja 7 "Otwarte pytania" po danych
      bety

---

## Łączny status

| Sekcja | Status | Czas do dokończenia |
|---|---|---|
| 1. Code & build | ⬜ (U-1 done, reszta wymaga U-2..U-6 + DMG) | ~10h |
| 2. Onboarding | 🔵 (welcome partial w SettingsWindow) | ~6h |
| 3. Privacy | 🔵 (PrivacyFilter dziś done, dyskusja UI partial) | ~3h |
| 4. Coverage | 🔵 (5 zweryfikowanych z 20+ cel) | ~30h (Sub-cele eval) |
| 5. Feedback | 🔵 (cmd-klik dziala, reszta brak) | ~4h |
| 6. Telemetry | ⬜ (czeka na Fazę 2) — może uproszczona w beta | ~6h |
| 7. Docs | ⬜ | ~6h |
| 8. Backend | 🟢 (działa od miesięcy) | 0 |
| 9. Tester selection | ⬜ | ~2h |

**Suma:** ~60h od dziś do beta. **Realistic timeline 3-4 tygodnie** (Filip
~15h/tydzień solo development).

**Critical path:** U-1 → U-2 → U-6 → eval 5 apek → bundled cleanup → DMG → tester invite.

---

*Checklist napisany 2026-05-16 offline. Aktualizuj per sesja w miarę
zamykania checkboxów.*
