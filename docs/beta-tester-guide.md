# 🧪 SFlow — przewodnik dla testera

> **Cześć!** Pomagasz mi (Filip) testować SFlow. Ten dokument tłumaczy w **5 minut** co masz robić.
> Każde pytanie do mnie — pisz po prostu na DM.

---

## Co to jest SFlow

Mała apka która **podpowiada Ci skróty klawiaturowe** w momencie gdy klikasz myszką coś co ma skrót. Działa w tle, nie wymaga uwagi.

**Przykład:** klikasz „Compose" w Slacku → SFlow pokazuje toast „⌘N" → wiesz że następnym razem nie musisz szukać przycisku myszką, wystarczy nacisnąć skrót.

---

## Co masz robić — 4 kroki

### Krok 1 — Instalacja (~5 min)

1. Pobierz `.dmg` od Filipa (link na DM)
2. Otwórz, przeciągnij **SFlow.app** do `/Applications/`
3. Uruchom z Launchpada lub Spotlight
4. **System Settings → Privacy & Security:**
   - **Accessibility** → włącz SFlow ✅
   - **Input Monitoring** → włącz SFlow ✅
   - (oba są wymagane, SFlow Ci o nich przypomni)

### Krok 2 — Włącz „silent mode" (~30 sek)

To **najważniejszy krok dla testu.** Silent mode oznacza:
- SFlow **dalej zbiera dane** o Twoich kliknięciach
- Ale **nie pokazuje toastów** — nie wkurza Cię UI

**Jak:**
1. Klik na ikonkę SFlow w pasku menu (na górze ekranu)
2. **Settings…** → zakładka **Advanced**
3. Zaznacz **„Hide toasts (collect data only)"** ✅
4. (Opcjonalnie) zaznacz też „Show developer features" — pokazuje dodatkową zakładkę „Apps" gdzie widać które apki SFlow już zna

Po włączeniu **ikona w menu barze dostaje małe „🔇"** — wizualne potwierdzenie że silent jest WŁ.

### Krok 3 — Używaj normalnie 2-3 dni

**Najprostsza część.** Po prostu pracuj normalnie:
- Slack, Notion, Gmail, przeglądarka, Excel, IDE — cokolwiek używasz
- Nie zmieniaj nawyków, nie staraj się specjalnie „testować"
- SFlow w tle obserwuje co klikasz i zapisuje to do lokalnego pliku

**Co dzieje się w tle:**
- SFlow rozpoznaje co kliknąłeś
- Jeśli wie że to ma skrót → zapisuje że „pokazałby toast"
- Jeśli nie wie → zapisuje miss (analiza późniejsza)
- **Nic nie idzie do internetu** — wszystko zostaje na Twoim komputerze

### Krok 4 — Eksport po 2-3 dniach (~1 min)

Gdy zbierzesz dane (najlepiej **48-72h** używania):

1. Ikonka SFlow → **Settings… → Advanced**
2. Klik **„Export diagnostic bundle…"**
3. Wybierz lokalizację (domyślnie Desktop)
4. Powstanie plik: **`sflow-diagnostic-YYYYMMDD-HHMMSS.zip`** (~kilka KB - 1 MB)
5. **DMnij plik do Filipa** (Slack/Discord/email)

I to wszystko! 🎉

---

## 🔒 Co dokładnie wysyłasz Filipowi

Plik ZIP zawiera:

| Plik | Co tam jest |
|---|---|
| `events.jsonl` | Lista Twoich kliknięć z czasem, apką, identyfikatorem elementu |
| `false_positives.jsonl` | Twoje cmd-klik na toast (jeśli były) |
| `attempted.json` | Które apki SFlow próbował się nauczyć i jak poszło |
| `discovered/*.jsonl` | Tooltipy które SFlow zobaczył (hint o skrótach) |
| `system-info.txt` | macOS version, język UI, ilość monitorów, NIC więcej |

**Czego TAM NIE MA (gwarancja):**
- ❌ Twoja nazwa użytkownika / hostname / IP
- ❌ Lista zainstalowanych apek
- ❌ Tytuły maili, treść wiadomości, prywatne dokumenty
- ❌ Imiona/email adresów z Twoich kontaktów (filtr PrivacyFilter redactuje to przed zapisem do pliku)

Jeśli chcesz mieć pewność, **otwórz `events.jsonl` w TextEditcie przed wysłaniem** — to czysty tekst.

---

## 🛟 Pomoc / problemy

| Problem | Co zrobić |
|---|---|
| SFlow nie pokazuje ikony w menu barze | Sprawdź czy Accessibility jest WŁ. w System Settings |
| Toast pokazał się mimo silent mode | Restart SFlow (ikonka → Quit → uruchom ponownie) |
| Export bundle się nie otwiera | Sprawdź czy masz dość miejsca na Desktop. Spróbuj zapisać do innej lokalizacji. |
| SFlow zwolnił Mac | Rzadkie, ale możliwe. Wyłącz toggle „Enabled" w menu ikony. Daj znać Filipowi. |
| Coś dziwnego się zdarzyło | DM do Filipa z screenshotem + krótkim opisem |

---

## ❓ Czego od Ciebie nie potrzebuję

- ❌ **Nie zmieniaj swojego stylu pracy** — chcemy widzieć **prawdziwe** kliknięcia, nie sztucznie wymuszone
- ❌ **Nie testuj specjalnie skrótów** które już znasz — celem nie jest sprawdzenie czy skróty działają, tylko czy SFlow je rozpoznaje
- ❌ **Nie usuwaj `events.jsonl`** ręcznie podczas testu — to zniweczy dane

---

## 📞 Kontakt

Filip GoCamping — DM na Slack/Discord/Signal.
Email: filip@gocamping.tv

---

## ⏱️ Timeline

| Dzień | Co | Twoja akcja |
|---|---|---|
| 0 | Instalacja + silent mode WŁ. | 5 min |
| 1-2 | Normalna praca | 0 min, SFlow działa w tle |
| 3 | Export bundle + DM | 2 min |
| 3+ | Filip analizuje, może wrócić z pytaniami | — |

Razem **~7 minut Twojego czasu** żeby pomóc rozwojowi produktu. Dziękuję! 🙏

---

*Wersja przewodnika: 2026-05-17, dla SFlow v0.x (pre-Beta).*
