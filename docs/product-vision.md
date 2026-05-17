# SFlow — wizja produktu (purpose, problem, możliwe drogi)

> Dokument myślowy, nie spec implementacyjny. Spisany 2026-05-13 po sesjach nad
> Layer 1.5, LLM rules engine, miss log. Cel: nazwać co właściwie budujemy,
> żeby było jasne czemu klient miałby zapłacić $X.

---

## 0. Jak współpracujemy w sesjach AI (READ FIRST — instrukcje dla AI)

**Te zasady są nadrzędne nad domyślnym zachowaniem AI w SFlow. Czytaj je
na początku KAŻDEJ sesji, zanim zaczniesz cokolwiek robić w tym repo.**

### 0.1. Obowiązkowy kontekst na start sesji

Zanim odpowiesz na cokolwiek (nawet "cześć"), MUSISZ przeczytać:

1. `docs/product-vision.md` ← ten plik (zwłaszcza sekcję 0 i 6)
2. `docs/roadmap.md` (zwłaszcza "Proces ciągły" + "Najbliższy krok")
3. `docs/audit-phase-0.md` (lista zrobione/nie-zrobione z statusami)
4. `docs/audit-phase-1.md` (lista sub-celów z statusami)

Zrób to **w jednym tool call** (4 równoległe Reads). Bez tego nie wiesz na
jakim etapie produktu jesteśmy i ryzykujesz że zaproponujesz rzeczy które
są już zrobione albo poza scope'em.

### 0.2. Jak tłumaczyć i pytać — "12-latek + product designer"

Filip uczy się programowania i product designu jednocześnie. Tłumacz mu
wszystko **jak 12-latkowi który właśnie zaczyna**:

- **Analogie przed żargonem.** Zamiast "musimy zaimplementować idempotency
  na endpointcie", powiedz: "trzeba dodać zabezpieczenie żeby ta sama
  operacja wykonana 2 razy nie zrobiła dwóch zapisów — jak przycisk windy
  który już wciśniesz raz i nieważne ile razy go pukniesz".
- **Termin techniczny? Wytłumacz go w nawiasie po polsku.** np.
  "KV store (tabela klucz-wartość na serwerze Cloudflare, jak słownik)".
- **Polski język domyślnie** (Filip pisze po polsku).
- **Nie infantylnie — chodzi o jasność, nie o ton.** Filip jest mądry,
  po prostu nie ma 10 lat doświadczenia w branży.

Gdy pytasz Filipa o decyzję przed implementacją:

- **Zawsze daj 2-4 opcje** z plusami i minusami każdej (use `AskUserQuestion`).
- **Zawsze masz rekomendację.** Wskaż którą wybrałbyś i **WHY** —
  konkretne uzasadnienie odniesione do roadmap/vision. Nigdy nie pytaj
  "co wolisz?" bez własnej opinii — to przerzucanie decyzji.
- **Recommendation w pierwszej opcji** z dopiskiem "(Recommended)".
- **Pytaj tylko o decyzje strategiczne** — nie o "czy nadać zmiennej nazwę
  X czy Y". Drobne rzeczy decyduj sam, idź dalej.

### 0.3. Rekomendacje muszą odnosić się do vision/roadmap

Każda rekomendacja MUSI być uzasadniona przez:

- **Cel z roadmap.md** ("To realizuje sub-cel 1.0 z fazy 1")
- **Wartość biznesową** ("To zmniejsza false-positive rate, co jest
  blokujące dla bety w Fazie 1.7")
- **Decyzję z vision** ("Idziemy drogą B, więc curriculum > drill")

Jeśli nie potrafisz uzasadnić — to znak że propozycja może być
feature-creep'em. Zatrzymaj się i zapytaj Filipa o priorytet.

### 0.4. Sekwencja świętości jest święta

Z sekcji "Założenie kierunkowe" w roadmap.md: **nie budujemy Fazy 2
zanim Faza 1 nie ma kryteriów akceptacji spełnionych**. Dotyczy też mniejszych
poziomów — sub-celów. Jeśli Filip prosi o coś poza sekwencją, pokaż mu
co to znaczy ("to jest faza 4 — wymagamy faza 1.7 beta wyników najpierw")
i zapytaj czy ma jakiś nowy kontekst który zmienia priorytet.

### 0.5. Każda sesja kończy się aktualizacją checklist'y

Patrz `docs/roadmap.md` sekcja "Proces ciągły / End-of-session protocol".
Skrót: po skończonej pracy MUSISZ:

1. Zaktualizować statusy w `audit-phase-0.md` (problemy P-X) i `audit-phase-1.md`
   (sub-cele) — ⬜→🟡 lub 🟡→🟢 lub 🟢→cofnięcie jeśli regresja.
2. Dopisać entry w `roadmap.md` "Session log" sekcji.
3. Scommitować razem z kodem jednym commitem ("docs: session log + status update").

### 0.6. Video eval — okresowy proces jakościowy

Patrz `docs/audit-phase-1.md` sub-cel 1.8 (Video-based eval). Skrót: raz
na N sesji proś Filipa o screen recording 60-90s normalnego użycia
1-2 zweryfikowanych apek. Wyciągnij klatki przez Swift+AVFoundation,
przeanalizuj każdy klik → toast → tooltip. Raport: poprawne /
chybione / błędne. Wyniki zasilają sub-cel 1.6 coverage report.

### 0.7. Co AI MA prawo zrobić bez pytania

- Edytować pliki dokumentacji (specy, plany, audyty)
- Pisać i uruchamiać testy
- Commit + push do main branch (Filip pracuje solo na main)
- Reseedować apki przez `./scripts/sflow-reseed`
- Wyciągać klatki z wideo do `/tmp/`

### 0.8. Co AI MUSI zapytać przed zrobieniem

- Deploy backendu (`wrangler deploy`) — produkcyjna zmiana widoczna
  światu, Filip musi explicit yes każdy deploy
- Usunięcie plików z trackowanej historii (`git rm`, `git filter-branch`)
- Zmiana modelu cenowego, prosting nowych userów
- Cokolwiek poza scope obecnego sub-celu z roadmap.md

---

## 1. Po co w ogóle istnieje SFlow

**Jednym zdaniem:** SFlow ma sprawić, że ludzie tracą mniej czasu w swoich
aplikacjach na komputerze.

**Analogia.** Wyobraź sobie kierowcę który całe życie wciska "włącz/wyłącz światła"
nogą — przyciskiem na podłodze. Działa. Ale jest dźwignia przy kierownicy która
robi to samo, jednym ruchem palca. On o niej **wie** że istnieje. Po prostu nie
wyrobił nawyku. Każdego dnia traci sekundę. W skali roku — godziny.

Tak wygląda praca z apkami. Każdy klik myszką który mógłby być skrótem
klawiszowym to mikro-strata: 1–2 sekundy + reset uwagi + przeniesienie ręki
między klawiaturą i myszką. Pojedynczo nic. W skali dnia roboczego — 30 minut.

**Dlaczego ludzie nie używają skrótów choć je znają?**
- Nigdy się nie nauczyli (nikt im nie pokazał)
- Wiedzieli, zapomnieli (cheatsheet zniknął z biurka)
- Wiedzą o jednym ale nie pamiętają w momencie kliknięcia
- Apka, którą używają codziennie, nigdy nie ujawnia swoich skrótów
  (Slack/Notion/Linear nie pokazują ich w UI poza menu bar)

SFlow rozwiązuje **dokładnie tę lukę**: wykrywa moment "kliknąłeś coś co ma
skrót" i przypomina o nim w czasie rzeczywistym, w kontekście tej konkretnej
akcji. Nie cheatsheet w PDF. Nie tutorial na YouTubie. Przypomnienie wtedy
kiedy jest potrzebne.

**Kto to kupi?**
- Power-userzy którzy chcą być szybsi: programiści, designerzy, copywriterzy,
  konsultanci, projekt-menedżerowie, prawnicy w doc-heavy pracy
- Ludzie po onboardingu w nowej firmie (nowy stack apek = chaos przez 2 miesiące)
- Zespoły które chcą mieć szybszych pracowników (B2B płaci za pakiet licencji)

---

## 2. Problem — jak go widzimy dziś

### 2a. Problem usera (powierzchnia)

> "Wiem że istnieją skróty ale nie umiem ich zapamiętać. A jak ktoś mi podsuwa
> listę 200 skrótów dla Notion, to ją zamykam po 10 sekundach."

Typowy user **nie chce się uczyć**. Chce **żeby się nauczyło samo, niewidzialnie**.
Skróty trzeba dawkować — pokazywać w kontekście, po jeden naraz, i to dokładnie
te które user faktycznie używa.

### 2b. Problem techniczny (głębsza warstwa)

To co zrobiliśmy w v1 to **detektor mocy**: SFlow umie ustalić "co właśnie
zostało kliknięte" i "jaki ma odpowiadający skrót". To trudna część (4 warstwy
matchowania, AX API, Electron, false positives, ~80% pokrycia po LLM seed dla
4 apek). Ale to dopiero **infrastruktura** — nie produkt.

Produkt to dopiero: **co robimy z informacją że user właśnie kliknął element
który ma skrót**.

### 2c. Problem biznesowy (najgłębsza warstwa)

Trzy pytania których nie odpowiedzieliśmy:

1. **Czy user faktycznie nauczy się skrótu po zobaczeniu toasta?**
   Niewykluczone że nie — toast pojawia się 1.5s **po** kliknięciu. User już
   wykonał akcję. Nie powtarza jej skrótem. Nie utrwala. Może to być po prostu
   "fajne ale nieskuteczne".

2. **Jak udowodnić wartość 30 dni po instalacji?**
   Jeśli user nie widzi że jest szybszy, nie zapłaci za drugi miesiąc.
   Potrzebujemy mierzalnego efektu: "w tym tygodniu używałeś skrótów 142 razy,
   zaoszczędziłeś 8 minut".

3. **Co odróżnia SFlow od CheatSheet (⌘-hold), Mouseless, KeyCue?**
   Tamte pokazują pełną listę skrótów. SFlow pokazuje **jeden, kontekstowy**.
   To jest pomysł. Ale czy to wystarczy żeby user zapłacił $25 zamiast wziąć
   freeware?

---

## 3. Gdzie jesteśmy dziś (snapshot)

**Co działa:**
- Wykrywanie kliknięć (CGEventTap)
- 7 warstw rozpoznawania (L0/L0.5/L1/L2/L3/L4 + direct menu bar): AXKeyShortcuts +
  bundled LLM rules + hardcoded ShortcutRules + tooltip auto-parse + menu bar fuzzy match
  + universal heuristics + direct AXMenuItem
- Backend CF Worker + Claude generuje reguły dla nowych apek na żądanie
- ~70–80% pokrycia dla 4 zweryfikowanych apek (Slack, Obsidian, Linear, Cursor)
- Miss log + analyzer (v1.1) — wiemy które kliknięcia "uciekły"

**Audyt 2026-05-14 + sesje 6-7 — fundament naprawiony + coverage rozszerzona:**

**Sesja 6 (matching engine quality):** Pełna analiza trybu rozpoznawania
wykryła 4 fundamentalne bugi (P-26..P-30 w `audit-phase-0.md`): matchowanie
reguł na rodzicach niezwiązanych z klikiem, substring zamiast word-boundary,
niedeterministyczny MenuBarIndex, agresywny filtr skeletonu. **Wszystkie
naprawione** — 9 commitów. Plus dodana **per-layer telemetria** w
`events.jsonl` (pole `"layer"`) która odblokowuje data-driven iteracje.

**Sesja 7 (coverage quick wins — P-31 część 1):** 3 niezależne fixy
rozszerzające detection surface bez czekania na dane:
- `AXUIElementCopyActionNames` probe — element z akcją AXPress = klikalny
  niezależnie od role (catches Chromium widgets)
- Walk-down z klikalnego rodzica — gdy puste title+desc → szukamy w dzieciach
- AXRoleDescription + AXCustomActions czytane i przekazane do RuleCache.match

**198 testów passing po sesji 7.** Szacunkowy wzrost coverage ~30-50%.

**Następny krok (sesja 8):** użycie SFlow 1-2 dni → analiza `events.jsonl`
per-layer per-apka → **pełny plan coverage iteration** (P-31 część 2, sub-cel
1.11) — wybór 2-3 z 12 brainstormowanych źródeł (AppleScript sdef parser,
GitHub code-search dla OSS apek, Help→Shortcuts auto-scrape, szersze Electron
regex, prompt rework, etc.) — wybór **na bazie danych Filipa**, nie zgadywanie.

**Sesja 2026-05-15 — diagnoza Notion Mail i nowa droga: tooltip-as-discovery.**
Empiryczna analiza pokazała że w Electron/Chromium apkach (Notion Mail,
prawdopodobnie też Linear/nowe Slack/Discord) ikonkowe `AXButton` mają puste
accessible names — Chromium nie generuje labelek bez `aria-label`. Tekst
siedzi w `kAXValue` dzieci AXStaticText, 1–2 poziomy głębiej. To problem
**fundamentalny** dla obecnego stosu warstw — bez labelki żadna z warstw
0.5/1/3/4 nie ma czego dopasować. Rozwiązanie idzie w dwóch wymiarach:

1. **Sesja A** (~1.5h, P-36) — pogłębić istniejący fallback dzieci (czytać
   `kAXValue`, schodzić rekurencyjnie 1 poziom, nie blokować depth=0).
2. **Sesje B+C** (P-37) — **tooltip-as-discovery**: React apki renderują
   własne tooltipy z parą `(akcja, skrót)` — np. "Compose a new email / C".
   `TooltipObserver` pasywnie zbiera te dane na hoverze + crowdsource przez
   backend `/v1/discovered`. Jeden user hoveruje → wszyscy dostają regułę.

To **nowa, asymetryczna droga zdobywania reguł** — niezależna od Claude'a,
działa dla apek których jeszcze nikt nie eval'ował, samonapędzający się
ekosystem.

**Diagnoza 2026-05-16 — znana luka w pokryciu: dropdown menu w oknach (P-38).**
Po Sesji B Filip zauważył że w Notion Calendar dropdowny otwarte po kliku
w przycisk (Week → Day/Week/Month z badge'ami "1 or D", "0 or W", "M") nadal
nie emit'ują toastów. To **trzecia osobna ścieżka discovery**, niezależna
od dwóch obecnych:

| Źródło skrótu | Obsługa dziś |
|---|---|
| Menu bar (File/Edit/View) | `MenuBarWatcher` przez `kAXMenuItemCmdChar` ✅ |
| Window button tooltips (Compose, Reply) | `TooltipObserver` L0.3 ✅ (Sesja B) |
| **Window dropdown menus** (View→Week) | **brak** — `MenuItemObserver` (Sub-cel 1.17) |

Powody techniczne: rola `AXMenu`/`AXMenuItem` poza białą listą `walk()`,
heurystyka rozmiaru tooltipa odrzuca pionowe menu, format "X or Y" (dwa
skróty na jedną akcję) nie mieści się w obecnym schemacie `[String]`.
Skala: każda apka z dropdownami w UI (Linear ⌘K, Slack apps, Figma context
menu, Notion slash-menu). Decyzja go/no-go po teście Sesji B na Linear/
Discord/Slack — patrz `audit-phase-1.md` Sub-cel 1.17 + `audit-phase-0.md` P-38.

**Czym są toasty dziś:**
> Toasty służą mi do testowania czy SFlow faktycznie "łapie" elementy które
> mają skróty.

To trafna obserwacja. Obecny toast jest **diagnostyczny** ("zobacz, wykryłem"),
nie **edukacyjny** ("naucz się tego"). To trzeba zmienić — albo zostawić toast
w roli diagnostyki i dobudować nową warstwę edukacyjną nad spodem.

---

## 4. Możliwe drogi rozwoju (propozycje)

Nie są wzajemnie wykluczające. Można połączyć 2–3. Ułożone od najbliższej
obecnemu stanowi do najambitniejszej.

### Droga A: Lepszy toast (status quo+)

**Pomysł:** zostawiamy toast, ale podnosimy jego skuteczność edukacyjną.
- Toast pojawia się **przed** kliknięciem dotrze do apki (delay 200ms) z opcją
  "naciśnij skrót teraz zamiast kliknięcia, klik się nie wykona"
- Albo: toast po klinięciu pokazuje **przegląd statystyk** ("to 5. raz w tym
  tygodniu kiedy klikasz to zamiast ⌘K — chcesz quiz?")
- Albo: progresywne ukrywanie podpowiedzi — pierwszy raz pełna, dziesiąty raz
  tylko symbol, dwudziesty raz znika ("user się nauczył").

**Plusy.** Minimalna zmiana architektury. Toast już działa. Sygnał o postępie
można dać natychmiast.

**Minusy.** Toast po akcji jest słabym uczeniem — psychologia mówi że ucząc
skrótu trzeba go **wykonać**, nie przeczytać. Sam toast może być na granicy
"miły ale nieskuteczny".

**Ryzyko biznesowe.** Najmniejsze. Ale też najmniejsze odróżnienie się od
darmowej konkurencji (KeyCue itp.).

### Droga B: Personalizowana ścieżka nauki (twój pomysł)

**Pomysł:** SFlow obserwuje pasywnie który element user klika i jak często.
Buduje **profil użytkownika**: top 30 akcji × top 5 apek = lista 50–150 skrótów
które ten konkretny user **faktycznie** używa codziennie. To jest jego osobisty
program nauki. Resztę skrótów (te których nie klika) ignoruje — nie zaśmieca
głowy.

Warstwy:
1. **Discovery (2 tygodnie pasywne).** Toast nadal pokazuje skróty, miss-log
   zbiera dane. Po 2 tygodniach SFlow wie czego user używa.
2. **Curriculum.** Algorytm rankuje skróty wg częstości × łatwości × oszczędzonego
   czasu. Buduje listę "Twoje top 20 skrótów na ten miesiąc".
3. **Lekcje.** Codziennie rano (lub na żądanie) okno SFlow: "dziś ćwiczymy ⌘K
   w Slacku — to twoje #1 najczęstsze kliknięcie. Otwórz Slacka i wciśnij 5 razy".
   Albo gamified: "wykonaj akcję X razy klawiaturą zanim zrobisz myszką".
4. **Progress dashboard.** "Opanowałeś 12/20 skrótów. Zaoszczędziłeś 27 minut
   w tym tygodniu."

**Plusy.** To jest **wartość produktu**, nie tylko gadżet. Można mierzyć ROI.
Można pokazać przed/po. Realny powód żeby zapłacić.

**Minusy.** Duża praca: nowy UI (lekcje, dashboard), nowa logika (curriculum
generator), wszystkie zagadnienia psychologii nauki (spaced repetition,
forgetting curve). Sama "lekcja codzienna" wymaga decyzji projektowych:
notyfikacja? Pełnoekranowa? Krótki quiz? Zmiana behawioru user'a.

**Ryzyko biznesowe.** Średnie. Ale jest tu **prawdziwy produkt** — to co
ludzie kupują w aplikacjach typu Duolingo/Anki, tylko że SFlow nie wymaga
od usera "siadania do nauki" — uczy się przy okazji jego normalnej pracy.

**Krytyczne pytanie do tej drogi:** czy user **chce** żeby SFlow rozumiał co
robi? Pomimo że dane są lokalne — fakt że apka "wie że klikam Compose 20 razy
dziennie" może mu się wydawać creepy. Trzeba dobrze zakomunikować
("wszystko lokalnie, możesz wyczyścić jednym przyciskiem").

### Droga C: Daily Drill (mini-Duolingo dla skrótów)

**Pomysł:** wariant B uproszczony. Rezygnujemy z pasywnego tracking, dajemy
**oddzielną aplikację-trainer**. SFlow nadal pokazuje toasty (free tier). Drugi
moduł: "SFlow Coach" — codziennie 60-sekundowy drill: pokazuje akcję graficznie
("kliknij Compose w Slacku"), user wykonuje skrót, dostaje feedback ("good,
0.4s reaction time").

**Plusy.** Łatwiejsze do tłumaczenia ("Duolingo dla skrótów"). Możliwy
free → paid model. Nie wymaga inwazyjnej pasywnej obserwacji.

**Minusy.** Wymusza na userze "siadanie do nauki" — to ekstra friction. Większość
ludzi nie ma 60s dziennie na lekcję, a Duolingo trzyma się tylko bo ma streaki.

**Krytyczna ocena.** Możliwe że to ślepy zaułek — SFlow ma USP w tym, że
**uczy mimochodem**. Robiąc oddzielną apkę-drill tracimy ten USP.

### Droga D: Blocker / Force-Learning

**Pomysł najradykalniejszy.** Gdy user kliknie myszką coś co ma skrót, SFlow
**przerywa kliknięcie** — pokazuje overlay "naciśnij ⌘K żeby kontynuować".
Klik nie idzie do apki. User musi wykonać skrót.

**Plusy.** Najszybsza nauka — Pavlov. User **zmuszony** wykonać skrót,
utrwala nawyk natychmiast. Dla power-userów którzy świadomie chcą się
przełamać — może być sprzedażowym hitem ("install for 1 week, become a
keyboard warrior").

**Minusy.** Bardzo agresywne UX. Łatwo zepsuć user-flow. Potrzebny on/off per
apka, per dzień, per typ akcji. Może irytować w sytuacjach gdzie skrót się
nie nadaje (np. ad-hoc kliknięcie).
Techniczna trudność: CGEventTap z `defaultTap` zamiast `listenOnly` — wymaga
silniejszych permissions i może być filtrowane przez macOS Privacy & Security.

**Ryzyko biznesowe.** Najwyższe — niche product. Ale niche może być
**wystarczające** (5000 power-userów × $50/rok = $250k ARR). Świetne marketingowo
("the brutal keyboard trainer").

### Droga E: Heatmap + retrospektywa (gentle)

**Pomysł:** żadnych przerywników, żadnych lekcji. Tylko tygodniowy raport:
- "klikałeś `Compose` w Slacku 47 razy (skrót: ⌘N)"
- "klikałeś `Search` w Notion 23 razy (skrót: ⌘P)"
- "**Oszczędność potencjalna: 12 minut tygodniowo** gdybyś zaczął używać skrótów"

User otwiera raport raz w tygodniu (mail/in-app). Zero ingerencji w pracę.
Decyzja co z tym robić — jego.

**Plusy.** Najmniej inwazyjne. Dane są same w sobie wartością (corporate
buyers lubią raporty). Łatwo dodać team dashboards dla B2B ("zespół Filipa
oszczędził 4h w tym tygodniu").

**Minusy.** Sama informacja rzadko zmienia zachowanie (waga widzi cyfrę, je
mniej? Rzadko). Brak feedback loop'u w momencie akcji.

**Ryzyko biznesowe.** Niskie, ale wartość per-user też niska. Lepiej działa
jako **dodatek** do drogi B niż samodzielny produkt.

### Droga F: B2B / Team Skills

**Pomysł:** każdy user ma swoje skróty, ale firma chce żeby cały zespół
używał konkretnego workflow. SFlow Enterprise pozwala:
- Adminowi: zdefiniować "Slack: top 15 skrótów na onboarding" jako curriculum
- Userowi: zobaczyć "twój menedżer rekomenduje te skróty"
- Adminowi: dashboard "team adoption: 78% używa ⌘K"

**Plusy.** B2B płaci więcej. Pivot z $25 jednorazowo do $5/user/miesiąc.
Onboarding sprzedawany jako use-case (nowy pracownik → 2 tygodnie SFlow →
od razu szybki w stacku firmowym).

**Minusy.** B2B sprzedaż jest długa, wymaga CRM, prezentacji, integracji
SSO/admin/security audit. Bardzo daleko od obecnego stanu.

**Ryzyko biznesowe.** Większy upside niż B2C, ale dłuższa droga.
**Sensowne tylko po udowodnieniu B-cwartości u indywiduali.**

---

## 5. Co kwestionuję (krytyczne spojrzenie)

### 5a. "Toast po akcji uczy" — niepewne

Cała teza apki opiera się na założeniu że pokazanie skrótu ⌘K w momencie
kliknięcia myszką sprawi że user następnym razem wciśnie ⌘K. To może być
nieprawda.

**Hipoteza alternatywna:** user przeczyta toast 100 razy a i tak będzie klikał
myszką — bo mózg już wykonał akcję, mięśniowa pamięć utrwala klikanie a nie
czytanie. To znaczy że bez **mechanizmu wymuszenia powtórki** (droga B lekcje,
droga D blocker) sam toast jest mało skuteczny.

**Sposób weryfikacji:** A/B test gdzie połowa userów dostaje toasty, połowa
nie — i mierzymy adoption skrótów (np. przez `kAXCharacterEncoding` keyboard
event monitoring) po miesiącu.

### 5b. "Wszystkie skróty są równie wartościowe" — fałsz

Niektóre skróty zyskują userowi 5s (otwieranie pliku → ⌘O), inne 0.3s
(↑/↓ vs klikanie scroll). Skupianie się na "ucz wszystkiego" rozprasza. Lepiej
**ranking po oszczędności czasu × częstości × łatwości**. To znowu wskazuje na
drogę B (curriculum).

### 5c. "Skróty są uniwersalnie pożądane" — fałsz dla części branż

Designerzy w Figmie używają **bardzo dużo myszki** (pixel-precision). Skrót
nie zastąpi przeciągania. Dla nich SFlow ma mniejszą wartość niż dla
programisty czy copywritera.
**Implikacja:** ICP do zwężenia. Zacząć od programistów / knowledge workerów,
gdzie >80% akcji można zrobić klawiaturą.

### 5d. "User chce iść do nauki" — fałsz w 90% przypadków

Większość ludzi nie zainstaluje "appki do nauki skrótów". Zainstaluje "appkę
która sprawi że jestem szybszy" — pasywnie. To wzmocnienie dla drogi B
(transparent learning) i argument przeciw drodze C (explicit drill).

### 5e. "Privacy będzie ok bo lokalnie" — niepewne marketingowo

To że dane są lokalne nie znaczy że user się nie wystraszy. Sama myśl
"appka wie co klikam" odstrasza. Trzeba **zaprojektować komunikację**
i widoczność: w menu bar zawsze pokazywać "loguję X kliknięć dziś", przycisk
"wyczyść wszystko" w widocznym miejscu, raport co user wie o sobie.

### 5e2. "Jakość pokrycia da się zweryfikować dla 100+ apek" — fałsz bez automatyki

Auto-discovery przez Claude'a generuje reguły dla **dowolnej apki**. To
fundament wartości SFlow. **ALE:** manual eval (Filip + 5 beta-testerów)
fizycznie nie obklika 100+ apek żeby sprawdzić czy każda reguła jest
poprawna. To znaczy że bez **automatycznego mechanizmu quality eval** SFlow
przy 100 supportowanych apkach **uczy userów halucynacji Claude'a** na
nieznanej skali.

**Implikacja:** zanim ogłosimy "SFlow działa dla każdej apki", musimy mieć
mechanizm sprawdzający każdą wygenerowaną regułę automatycznie.

**Plan w fazie 1:**
- **P-33 / Sub-cel 1.13** — synthetic Claude self-eval per regule (drugi
  call, ~$0.001/regule, score 1-5 + alternative suggestion). Pre-flight check.
- **P-4 / Sub-cel 1.4** ✅ — false-positive feedback od userów (cmd-klik
  na toast). Post-flight signal po pojawieniu się userów.
- **P-32 / Sub-cel 1.12** — ukierunkowany web research w backend prompt
  żeby reguły miały lepszą bazę source'ową przed eval.

Bez tych 3 elementów hasła "auto-discovery dla wszystkich apek" są obietnicą
której nie utrzymamy. To **gating issue** dla launch'a.

### 5f. "Konkurencja jest słaba" — nieprawdziwe

KeyCue, CheatSheet, KeyCombiner, Mouseless — kilka apek już istnieje. Część
darmowa. Trzeba precyzyjnie zdefiniować **co tylko SFlow robi**:
- KeyCue/CheatSheet: pokazują listę po ⌘-hold, **nie** wykrywają konkretnej
  akcji
- KeyCombiner: cheatsheet builder, off-line
- Mouseless: focusuje na browserach
- **SFlow USP:** in-context detection ("klikasz Compose → znasz ⌘N?"), działa
  globalnie, nie wymaga przełączania trybu

To USP musi być **w pierwszej linii pitchu**.

---

## 6. Moja rekomendacja (krótko)

Najsensowniejszy kierunek to **droga B (personalizowana nauka)** jako
core produktu, z drogami A (lepszy toast) i E (heatmap raport) jako
naturalnymi rozszerzeniami. Drogi C/D/F traktować jako warianty na później
gdy będzie pierwszych userów.

**Sekwencja:**
1. **Najpierw mierz.** Skończ v1.1 (miss log + analyzer). Dodaj keyboard
   event monitoring — wiemy nie tylko "user kliknął X" ale i "user nie wcisnął
   skrótu Y choć go znamy". Zbieraj te dane lokalnie przez 2 tygodnie testów na sobie i 3–5 znajomych beta-testerach.
2. **Sprawdź hipotezę toasta.** Zanim zbudujesz drogę B, **sprawdź** czy sam
   toast w ogóle uczy. Beta-testerów: po 2 tygodniach pytaj "ile skrótów teraz
   używasz których nie używałeś przed instalacją?". Jeśli odpowiedź "0–1" →
   toast jest niewystarczający → idziemy w stronę B (z elementem
   wymuszenia/lekcji). Jeśli odpowiedź "5+" → toast wystarczy i można dobudować
   E (raport).
3. **Wtedy zaprojektuj drogę B 1.0.** Minimalna wersja: codzienny push
   "dziś ćwicz ⌘K w Slacku" + dashboard "twoje top 10 skrótów × postęp".
   Spróbuj sprzedać $25–50 jednorazowo wczesnym 50 userom.
4. **Jeśli to działa** → droga F (B2B / team) jako naturalny scale-up.

**Czego NIE robić jeszcze:**
- Drogi D (blocker) — za inwazyjna na obecny etap
- Pełnej drogi C (osobna apka-drill) — to inny produkt
- Premium tier BYOK przed udowodnieniem core value

---

## 7. Otwarte pytania do następnej sesji

1. Czy zrobić beta-test sam na sobie + 5 znajomych przed jakąkolwiek decyzją
   kierunkową? (najtańszy sposób żeby uniknąć budowania nie tego produktu)
2. Czy keyboard event monitoring (wiedza "który skrót został wciśnięty")
   jest technicznie wykonalny przy obecnych permissions? (sprawdzić w
   CGEventTap docs)
3. Czy lekcja codzienna musi być w SFlow, czy może być pojedynczy email/push?
   (najprostsza forma = najprostsza walidacja)
4. Czy do drogi B trzeba własnego ML/modeli, czy wystarczą prosty algorytm
   "top-N by frequency × time-saved"? (zaczynamy od prostego, ML tylko jeśli
   user-research powie że to za mało)
5. Pricing: $25 jednorazowo (jak teraz w roadmapie) vs $5/mies subskrypcja vs
   freemium (free toasty, paid lekcje)? Każdy z tych modeli generuje inny
   produkt — trzeba zdecydować przed B1.

---

*Status dokumentu: roboczy, do iteracji. Następna sesja: zdecydować czy
robimy beta-test (krok 1 z rekomendacji) czy idziemy bezpośrednio w drogę B 1.0.*

---

## Outstanding blockers (do rozwiązania)

- **2026-05-16 — Toast nie renderuje wizualnie dla Slacka na 2. monitorze.**
  Krytyczne dla wartości produktu: jeśli toast nie jest widoczny, **droga A
  (intro/onboarding) i droga B (nauka) tracą sens** dla użytkowników
  multi-monitor. Diagnoza techniczna w
  [`issues/2026-05-16-slack-toast-not-rendering.md`](./issues/2026-05-16-slack-toast-not-rendering.md).
  Reguły `slack-msg-*` (Save→A, Reply→T, Forward→F itd.) zostały dodane
  i działają na poziomie eventów — czekają na fix renderera.
