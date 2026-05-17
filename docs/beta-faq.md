# SFlow Beta — FAQ

> **Dla:** 3-5 beta-testerów (Sub-cel 1.7). Wersja krótka, możliwa do
> wkleinia w welcome email.
>
> **Update cadence:** po pierwszym tygodniu bety dodać pytania które
> faktycznie się pojawiły.

---

## Q1. Co SFlow właściwie robi?

Pokazuje **podpowiedzi skrótów klawiszowych** w momencie, gdy klikasz
przycisk myszką w apce. Cel: nauczyć cię używać klawisza zamiast myszki —
żebyś był szybszy.

## Q2. Czy moje dane są bezpieczne?

**Tak.** SFlow:
- Czyta tylko **nazwy** klikalnych elementów (np. "Compose", "Reply") —
  nie treść wiadomości
- Lokalne pliki w `~/Library/Application Support/SFlow/` — możesz je
  obejrzeć
- Imiona, emaile, treść wiadomości → zamazywane jako `[REDACTED]` przed
  zapisem
- **Nie wysyła nic** na serwer dopóki sam nie włączysz telemetrii w
  Settings (default OFF w beta)

## Q3. Apka pyta o 2 uprawnienia (Accessibility + Input Monitoring) —
       dlaczego?

- **Accessibility:** żeby czytać nazwy klikalnych elementów (jak Cmd+klik
  identyfikuje co klikasz)
- **Input Monitoring:** żeby wiedzieć **kiedy** kliknąłeś (bez tego nie
  ma triggeru)

Bez obu nic nie działa. Możesz wyłączyć w System Settings kiedy chcesz.

## Q4. Dlaczego nie widzę toastu chociaż kliknąłem coś co MA skrót?

Możliwe powody:
1. **Apka nie jest jeszcze pokryta** — sprawdź listę w `Settings → Apps`
2. **AX tree empty** — niektóre Electron apki (Slack/Notion) wymagają 5s
   po starcie żeby się "rozgrzać"
3. **Toast nie chce się renderować na 2. monitorze fullscreen** —
   znany bug (issue 2026-05-16), pracujemy nad fix'em
4. **Skrót zna tylko menu bar** (np. ⌘C/⌘V) — sprawdź `events.jsonl` że
   klik został zarejestrowany

## Q5. Apka pokazuje **zły** skrót — co zrobić?

**Cmd-klik na toast** → SFlow zapamiętuje "to było źle" + wyłącza tę regułę
po 3 zgłoszeniach lokalnie. Plus zgłoszenie idzie na serwer (anonim), żeby
globalny model nauczył się że to wrong.

## Q6. Apka której używam nie ma żadnych toastów — jak ją dodać?

Otwórz apkę normalnie. SFlow w tle uruchamia auto-discovery (Claude AI
generuje reguły ~30s). Następnie klikaj — powinny pojawić się toasty.

Jeśli po 5 minutach żadnych reguł:
- `Settings → Apps → Failed` może pokazać "co poszło źle"
- Spróbuj "Try again" — odpala discovery ponownie

## Q7. Jak wyłączyć SFlow na chwilę?

Menu bar (ikona SFlow) → "Quit". Restart przez Spotlight ⌘Space → SFlow.

## Q8. Czy SFlow spowalnia komputer?

Nie zauważalnie. SFlow konsumuje ~50 MB RAM i <1% CPU w idle. Przy każdym
kliku robi 1-2 zapytania AX (typowo <10 ms).

## Q9. Czy mogę dostać zwrot pieniędzy?

Beta jest **darmowa**. Pricing pojawi się dopiero w Fazie 6 (~3-4 miesiące).
Wczesni beta-testerzy mogą dostać licencję bezpłatną / zniżkę — zdecydujemy
po debrief'ie.

## Q10. Co się stanie z moimi danymi gdy odinstaluję?

Wszystko lokalne — usuń folder `~/Library/Application Support/SFlow/`.
Backend nie ma żadnych identyfikujących cię danych (chyba że włączyłeś
telemetrię z anonimowym UUID).

## Q11. Skróty pokazują się w błędnym języku — jak naprawić?

SFlow obecnie głównie zna **angielskie** nazwy akcji. Lokalizacja (PL/DE/FR)
jest w planie Sub-cel 1.20 (Faza 1.5). Jeśli twoja apka jest po polsku,
SFlow może gubić część skrótów dopóki tego nie zaimplementujemy.

## Q12. Czy zna **wszystkie** skróty mojej apki?

Nie. Pokrycie zależy od:
- Czy apka jest na liście zweryfikowanych (patrz `coverage-report.md`)
- Czy element jest "klikalny" (klawiatura-only akcje pomijamy)
- Czy skrót jest w docs Apple / oficjalnych docs apki

## Q13. Niektóre toasty nie pasują do mojego workflow — mogę je wyłączyć?

Tak. Cmd-klik → 3× pod rząd dezaktywuje regułę lokalnie. Albo otwórz
`Settings → Recent Shortcuts` i zaznacz "Hide" przy konkretnej regule.

## Q14. Apka mnie irytuje — kiedy przestanie pokazywać?

3 scenariusze:
- **Wyłącz całkowicie:** Quit z menu bar
- **Wyłącz dla konkretnej apki:** Settings → Apps → wyłącz toggle
- **Wyłącz na konkretną akcję:** cmd-klik na toast (3× → dezaktywuje)

## Q15. Co zgłaszać do Filipa? (beta feedback)

**TAK zgłaszaj:**
- Złe skróty (toast pokazuje ⌘C ale faktycznie jest ⌘V) — cmd-klik **i**
  email do Filipa
- Brakujące apki które używasz codziennie
- Crashe (jeśli SFlow nagle znika z menu bar)
- UI confusing (np. Settings okno nieczytelne)
- Performance (jeśli komputer się rwie)

**NIE musisz zgłaszać:**
- Apki które rzadko używasz (focus na top-5)
- Pomysły na nowe features (mamy długą listę)

---

## Kontakt

- Email: filip@gocamping.tv
- (TBD: dedicated Slack/Discord channel)

## Pełna dokumentacja

- Co SFlow zbiera: `docs/beta-pre-release-checklist.md` §3
- Co działa: `docs/coverage-report.md`
- Co planujemy: `docs/roadmap.md`

---

*FAQ napisany 2026-05-17 offline. Update po pierwszym beta tygodniu.*
