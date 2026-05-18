# 📩 Beta invite template — copy do wysłania znajomym

> Trzy warianty zaproszenia: **short DM** (Slack/Discord/iMessage), **medium**
> (znajomy mniej znający kontekst), **long email** (formal z kimś z pracy).
> Personalizuj imię + wybierz wariant pasujący do relacji.

---

## 🎯 Short (Slack/Discord/iMessage)

> Wariant dla **bliskich znajomych** którzy wiedzą że robisz produkty.
> 4 linijki, max 30 sekund czytania.

```
Hej {imię}!

Robię małą apkę na Maca która podpowiada skróty
klawiaturowe gdy klikasz myszką. Szukam 3-5 osób
na 3-dniową betę (silent mode, 7 min Twojego czasu).
Chętny? 🙌
```

**Follow-up po „tak":** link do `beta-tester-guide.md` + DMG.

---

## 🎯 Medium (znajomy z mniejszym kontekstem)

> Trochę więcej kontekstu — co to robi i dlaczego warto. ~1 minuta czytania.

```
Hej {imię}! 👋

Robię małą apkę na Maca — SFlow. W skrócie: gdy klikasz
coś myszką (np. „Compose" w Slacku), apka pokazuje toast
ze skrótem klawiszowym („⌘N"), żebyś następnym razem mogł
nacisnąć skrót zamiast szukać przycisku.

Cel długofalowo: oszczędzić Ci ~10-30 sek/dzień, plus
nauczyć skrótów których nie znałeś.

Szukam 3-5 testerów na 3-dniową betę:
• Instalujesz apkę (~5 min)
• Włączasz „silent mode" (apka działa w tle, NIE pokazuje
  Ci toastów — zbieramy tylko dane)
• Używasz normalnie Maca 2-3 dni
• Eksportujesz zip z logami (~1 min)
• DMujesz mi plik

Łącznie ~7 min Twojego czasu. Dane lokalne, **nic nie idzie
do chmury**.

Chętny? 🚀
```

---

## 🎯 Long (formal, kolega z pracy / network)

> Wariant dla osób spoza bliskiego kręgu. Build kontekst + transparentność
> + opt-out. ~2 min czytania.

**Temat:** SFlow — beta-test (3 dni, 7 min Twojego czasu)

```
Cześć {imię},

Pracuję nad produktem SFlow — małą apką na Maca która
podpowiada skróty klawiaturowe gdy klikasz coś myszką
(np. klikasz „Send" → toast „⌘Enter").

Cel: zbudować dowód że ludzie faktycznie uczą się skrótów
przez ten mechanizm. Beta z 3-5 testerami da mi pierwszy
realny sygnał.

Co bym potrzebował od Ciebie:
1. Instalacja apki (.dmg do pobrania, ~5 min)
2. Włączenie „silent mode" — apka działa w tle ALE NIE
   pokazuje Ci toastów. Zbieramy tylko dane „co klikasz
   gdzie", żeby zmierzyć ile skrótów byśmy mogli Ci
   podpowiedzieć w wersji v1.
3. Używanie Maca normalnie 2-3 dni (NIE musisz nic zmieniać
   w swoim workflow)
4. Eksport ZIP-a z logami (1 min, button w Settings)
5. Przesłanie pliku do mnie (DM/email)

Razem: ~7 min Twojego czasu w sumie.

Co znajdziesz w ZIP-ie (czyste pliki tekstowe, możesz
obejrzeć przed wysłaniem):
- events.jsonl — co kliknąłeś + w jakiej apce + kiedy
- false_positives.jsonl — jeśli zauważysz że SFlow pokazał
  zły toast, klikniesz cmd+klik
- discovered/*.jsonl — tooltipy które apka zaobserwowała
- system-info.txt — wersja macOS + język UI (BEZ Twojej
  nazwy użytkownika, hostname, IP)

Czego TAM NIE BĘDZIE:
- ❌ Treść Twoich wiadomości / dokumentów
- ❌ Lista zainstalowanych apek
- ❌ Imiona, emaile, dane karty (filtr PrivacyFilter
  redactuje to wszystko PRZED zapisem)

Pełny przewodnik (5 min czytania): {link do beta-tester-guide.md}

Jeśli na którymś etapie się rozmyślisz — po prostu odinstaluj
apkę (drag-to-trash), żadnych zobowiązań.

Dzięki za rozważenie!

Filip
filip@gocamping.tv
```

---

## 📋 Lista do rekrutacji (Filip wypełnia)

> Wybierz 3-5 osób. Mix profili daje najlepszy sygnał.

| # | Imię | Rola/Profil | Wariant | Status |
|---|---|---|---|---|
| 1 | _____ | dev/designer power-user | short | ⬜ |
| 2 | _____ | dev/designer power-user | short | ⬜ |
| 3 | _____ | knowledge worker, Slack-heavy | medium | ⬜ |
| 4 | _____ | knowledge worker, Office/Excel | medium | ⬜ |
| 5 | _____ | senior/non-techie, gentle test | long | ⬜ |

**Kryterium wyboru:**
- Pracują na Macu **codziennie** (laptop, nie incydentalnie)
- Używają ≥3 z naszych verified apek: Slack/Notion/Mail/Calendar/Terminal/Cron/Music/Obsidian/Claude
- **Polacy z PL UI** = priorytet (testuje i18n PL Sub-cel 1.20 najnowsza)
- ≥1 osoba używa **Excel/Word codziennie** (testuje Office rules — Sub-cel 1.24)
- ≥1 osoba używa **Figma/Photoshop** (testuje creative bundled — Sub-cel 1.23/1.25)
- Faktycznie zwrócą logi w 3-7 dni (nie ghosting)

**Czego NIE chcemy:** osoby które dawno nie miały Maca, lub które będą za bardzo „testować" zamiast po prostu pracować.

---

## 🔁 Follow-up po wysłaniu

| Sytuacja | Akcja |
|---|---|
| „tak, dawaj" | Wyślij DMG + link do `beta-tester-guide.md` |
| „brzmi ciekawie, kiedy?" | „Możesz zacząć dziś/jutro, zajmuje 5 min + 3 dni w tle" |
| „a co dokładnie zbiera?" | Wyślij sekcję „🔒 Co dokładnie wysyłasz" z guide |
| Cisza po 3 dniach | Jeden gentle ping „hej, dasz radę spróbować?" |
| „nie mam czasu" | OK, podziękuj, nie naciskaj |

---

## 🎯 Po 3 dniach od wysłania DMG

Ping do testerów którzy nie zgrali ZIP-a:

```
Hej, jak SFlow Cię traktuje? :) Jeśli masz chwilę 1 min
żeby zeksportować ZIP (Settings → Advanced → Export
diagnostic bundle), będę wdzięczny. Po tym czyścisz
ze swojego Maca jednym dragiem do kosza.
```

---

*Template: 2026-05-18, dla Fazy 1.7 Beta MVP.*
