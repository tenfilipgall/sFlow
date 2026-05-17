# SFlow — Welcome screen copy

> **Cel:** tekst onboardingu pierwszego uruchomienia (Faza 3.1).
> **Język:** PL + EN (dwujęzyczne, Filip wybiera per locale).
> **Długość:** każdy ekran ~20-40 słów. Zero dłuższych ścian tekstu.

---

## Welcome flow — 5 ekranów

### Ekran 1 — Welcome

**PL:**
> ## Witaj w SFlow
>
> SFlow pokazuje **podpowiedzi skrótów** w momencie, gdy klikasz przycisk
> myszką.
>
> Cel: nauczysz się klawiatury **mimochodem**, podczas normalnej pracy.
>
> *Dwie minuty na konfigurację. Zaczynamy?*
>
> [Dalej]

**EN:**
> ## Welcome to SFlow
>
> SFlow shows **keyboard shortcut hints** the moment you click a button
> with your mouse.
>
> Goal: you'll learn shortcuts **passively**, during normal work.
>
> *Two minutes to set up. Ready?*
>
> [Next]

### Ekran 2 — Permission #1 (Accessibility)

**PL:**
> ## Krok 1 z 2 — Dostęp do AX
>
> SFlow potrzebuje pozwolenia żeby **czytać nazwy klikanych przycisków**
> (np. że właśnie kliknąłeś "Compose" w Slacku).
>
> Treść wiadomości, hasła, dane karty — **nie są czytane**.
>
> [Otwórz System Settings] [Dlaczego to bezpieczne?]

**EN:**
> ## Step 1 of 2 — Accessibility
>
> SFlow needs permission to **read names of buttons you click** (e.g.
> "Compose" in Slack).
>
> Message content, passwords, card data — **not read**.
>
> [Open System Settings] [Why is this safe?]

### Ekran 3 — Permission #2 (Input Monitoring)

**PL:**
> ## Krok 2 z 2 — Monitor kliknięć
>
> SFlow musi wiedzieć **kiedy kliknąłeś**, żeby pokazać toast w
> odpowiednim momencie.
>
> Nie nagrywamy klawiszy. Nie zapisujemy gdzie klikasz w sensie pozycji.
>
> [Otwórz System Settings]

**EN:**
> ## Step 2 of 2 — Input Monitoring
>
> SFlow needs to know **when you click**, to show the toast at the right
> moment.
>
> No keylogging. Click positions are not stored.
>
> [Open System Settings]

### Ekran 4 — Twoje top apki

**PL:**
> ## Z których apek korzystasz najczęściej?
>
> Zaznacz max 5. SFlow pierwsze 5 minut po onboardingu wygeneruje reguły
> właśnie dla nich (cieplejsza pierwsza ekspozycja).
>
> ☐ Slack          ☐ Notion         ☐ Linear
> ☐ VSCode         ☐ Cursor         ☐ Obsidian
> ☐ Mail           ☐ Calendar       ☐ Finder
> ☐ Xcode          ☐ Chrome         ☐ Inne…
>
> [Skip] [Continue]

**EN:**
> ## Which apps do you use most?
>
> Select up to 5. SFlow will generate rules for them first (~5 min) so
> your initial experience is rich.
>
> (same checkboxes)
>
> [Skip] [Continue]

### Ekran 5 — Demo + first toast

**PL:**
> ## Demo
>
> Tak będzie wyglądać każdy toast:
>
> ```
> ┌────────────────────────┐
> │  ⌘K  Quick Switcher    │
> └────────────────────────┘
> ```
>
> Pojawia się obok kursora 1.5s po kliknięciu. Zniknie po 2.5s.
>
> Pierwszy tydzień zobaczysz dużo. Potem SFlow **sam się uciszy** gdy
> nauczysz się skrótów (bo zaczniesz klikać klawiaturą).
>
> [Gotowe — zaczynam pracę]

**EN:**
> ## Demo
>
> Every toast looks like this:
>
> ```
> ┌────────────────────────┐
> │  ⌘K  Quick Switcher    │
> └────────────────────────┘
> ```
>
> Appears 1.5s after click, near cursor. Disappears after 2.5s.
>
> First week you'll see many. Then SFlow **quiets itself** as you master
> shortcuts (because you'll start typing them).
>
> [Done — let me work]

---

## Mikrocopy

### Toast options menu (cmd-klik)

**PL:**
- "Zły skrót? Powiedz nam." (false-positive feedback)
- "Wyłącz dla tego elementu"
- "Ignoruj wszystko z tej apki"
- "Settings →"

**EN:**
- "Wrong shortcut? Let us know."
- "Disable for this element"
- "Mute this app"
- "Settings →"

### Menu bar status

**PL:**
- "Aktywne" (działanie)
- "Pauza" (user-paused)
- "Bez dostępu — kliknij" (permission denied)

**EN:**
- "Active"
- "Paused"
- "Access denied — click"

### Settings — Privacy tab header

**PL:**
> ## Co SFlow zbiera (i czego NIE zbiera)
>
> **TAK:** nazwy klikalnych elementów, pozycje klików (lokalnie)
> **NIE:** treść okien, klawisze, hasła, emaile, imiona
>
> Wszystko lokalne. Telemetry opcjonalna i wyłączona by default.

**EN:**
> ## What SFlow collects (and doesn't)
>
> **YES:** clickable element names, click positions (locally)
> **NO:** window content, keystrokes, passwords, emails, names
>
> Everything local. Telemetry opt-in, off by default.

---

*Welcome copy 2026-05-17 offline. Wymaga UX review + maybe motion designer
dla animacji ekranów.*
