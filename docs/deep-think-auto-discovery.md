# SFlow: Auto-Discovery skrótów — problem, tezy, prompt dla agentów

> **Cel tego dokumentu:** Sformułować problem na tyle precyzyjnie, żeby agenty AI mogły go przemyśleć z wielu stron i zaproponować rozwiązania których sami nie widzieliśmy. Na końcu znajduje się prompt do wklejenia w sesję z agentami.

---

## 1. Co to jest SFlow i jak działa dziś

SFlow to macOS app która:
1. Nasłuchuje kliknięć myszką (CGEventTap)
2. W momencie kliknięcia odczytuje element UI przez macOS Accessibility API (AXUIElement)
3. Próbuje dopasować element do bazy reguł
4. Jeśli znajdzie dopasowanie — pokazuje toast ze skrótem klawiszowym (np. `⌘K  Quick Switcher`)

### Atrybuty odczytywane z AX przy każdym kliknięciu

```
kAXRoleAttribute          → "AXButton", "AXLink", "AXTextField", ...
kAXSubroleAttribute       → "AXSearchField", ...
kAXDescriptionAttribute   → "send message", "" (często puste w Electron)
kAXTitleAttribute         → "Send Message", "Toggle Mute" (aria-label w Electron)
kAXHelpAttribute          → "Quick Find ⌘K" (tooltip ze skrótem)
kAXPlaceholderValueAttribute
kAXIdentifierAttribute    → DOM id lub React key
```

Pętla idzie przez maksymalnie 6 przodków klikniętego elementu (bo użytkownik może trafić w ikonkę SVG wewnątrz przycisku, nie sam przycisk).

### Warstwy dopasowania (w kolejności)

| Warstwa | Mechanizm | Pokrycie |
|---|---|---|
| **L1** | Hardkodowane reguły per `bundleId` | Tylko apki które ręcznie zakodowaliśmy |
| **L2** | Auto-parse `kAXHelpAttribute` (np. "Archive ⌘E" → `["meta","e"]`) | Apki z tooltipami ze skrótami |
| **L3** | Fuzzy match do menu bar index (AXMenuBar skanowany przy starcie apki) | Akcje które mają odpowiednik w menu |
| **L4** | Universal semantic heuristics (AXButton desc=back → ⌘←, AXSearchField → ⌘F) | Wspólne wzorce między apkami |

### Aktualnie zakodowane apki (L1)

- Slack (`com.tinyspeck.slackmacgap`) — ~20 reguł
- Notion (`notion.id`) — ~15 reguł
- Claude Desktop (`com.anthropic.claudefordesktop`) — ~8 reguł
- Notion Calendar (`com.cron.electron`) — WIP
- Linear, Figma, Mail, Safari — różne stany

---

## 2. Problem — co chcemy osiągnąć

**Chcemy żeby SFlow działał dla dowolnej apki którą user zainstaluje, bez konieczności ręcznego kodowania reguł.**

Dwa warianty celu (niekoniecznie wzajemnie wykluczające):

### Wariant A — Zero-config universal detection
SFlow samo wykrywa skróty dla **dowolnej** apki, bez żadnej konfiguracji per apka.
- Działa automatycznie dla każdej apki zainstalowanej przez usera
- Zero pracy maintenance'owej po naszej stronie
- Akceptowalny jest niższy hit rate (np. 40-60% elementów ma toast zamiast 90%)

### Wariant B — Pokrycie top-100 apek, auto-update
SFlow ma wbudowaną bazę dla ~100 popularnych apek, aktualizowaną przez nas.
- 90%+ hit rate dla zakodowanych apek
- Nowe apki dodajemy co jakiś czas przez update
- Discovery procesu pisania reguł jest (semi-)automatyczny — nie spędzamy godzin per apka

**Kluczowe ograniczenie:** User nie powinien nic robić. Reguły pojawiają się same — albo dlatego że SFlow je wykryło, albo dlatego że dostał update.

---

## 3. Co już wiemy i co próbowaliśmy

### 3.1 Electron / web apps — kluczowe odkrycie

Większość nowoczesnych produktywnych apek to Electron (Discord, Slack, Notion, Linear, Figma Desktop, VS Code, Cron/Notion Calendar, etc.).

**W Chromium/Electron mapowanie ARIA → AX wygląda tak:**

```
aria-label="Toggle Mute"  →  AXTitle = "Toggle Mute"   ✅
                          →  AXDescription = ""          ❌ zawsze puste
aria-keyshortcuts="..."   →  AXKeyShortcutsValue = ?    ❓ nieprzetestowane
role="button"             →  AXRole = AXButton           ✅
role="link"               →  AXRole = AXLink             ✅
```

**Implikacja:** W Electron `desc:` reguły nigdy nie matchują. Trzeba używać `title:`.

### 3.2 Próba: Gmail web shortcuts (nieukończona)

Zbudowaliśmy:
- `BrowserURLReader` — działa, idzie w górę drzewa AX szukając `AXWebArea`, odczytuje URL
- `ShortcutRules.webRules` — reguły keyowane domeną (np. `"mail.google.com"`)

Dlaczego nie działało:
1. Reguły miały `desc: "compose"` — ale Gmail ustawia `title: "utwórz"` (polska lokalizacja)
2. Nie przetestowaliśmy `AXKeyShortcutsValue` — Gmail ustawia `aria-keyshortcuts="c"` na przycisku Compose

**Plik:** `docs/wip-web-shortcuts.md`

### 3.3 Próba: Notion Calendar (WIP)

- AX działa (`result=0`, mamy elementy)
- Przycisk "New Event": AX zwraca atrybuty, ale nie wiemy dokładnie jakie
- Przyciski nawigacji (prev/next week): `role=AXButton, desc='', title='', id=''` — całkowicie puste

**Wniosek:** Część elementów Electron ma puste AX atrybuty — żaden mechanizm nie pomoże jeśli apka nie ustawia aria-label.

### 3.4 Layer 2 — auto-parse help text — działa

Apki które wkładają skróty w tooltipach (np. Slack: "Quick Switcher ⌘K") → L2 matchuje automatycznie. To najskuteczniejszy "free lunch" mechanizm. Problem: mało apek tak robi.

### 3.5 Layer 3 — menu bar scanner — działa dla natywnych

Skanujemy menu bar przy każdej zmianie apki. Dobre pokrycie dla natywnych macOS apek. Electron często ma ubogi menu bar (nie odzwierciedla wszystkich akcji w UI).

### 3.6 `AXKeyShortcutsValue` — NIEPRZETESTOWANE, obiecujące

Atrybut który Chromium eksponuje z HTML `aria-keyshortcuts`. Jeśli Discord ustawia:
```html
<button aria-label="Mute" aria-keyshortcuts="Meta+Shift+M">
```
To SFlow może odczytać `AXKeyShortcutsValue = "Meta+Shift+M"` i automatycznie pokazać toast bez żadnej hardkodowanej reguły.

**Nie wiemy:** Czy Discord (ani inne apki) w ogóle używają `aria-keyshortcuts`. Większość apek tego nie robi. Gmail TAK (ma `aria-keyshortcuts="c"` na Compose).

---

## 4. Aktualna architektura — czego brakuje

```
Kliknięcie
    │
    ▼
AX lookup (role, title, desc, help, id)
    │
    ├─ L1: bundleId rules      ← ręczne, nieeskalowalne
    ├─ L2: help text parse     ← automatyczne, mało pokrycia
    ├─ L3: menu bar match      ← automatyczne, natywne apki
    └─ L4: universal heuristics← automatyczne, bardzo ogólne
    │
    ▼
Brak dopasowania → nic się nie dzieje
```

**Brakuje:**
- **L0: AXKeyShortcutsValue** — zero-config dla apek które to ustawiają
- **L1.5: Background AX scan** — proaktywne skanowanie apki po załadowaniu
- **L1.x: Shortcut DB match** — baza skrótów per apka + matching do element names

---

## 5. Tezy i hipotezy

### Teza 1: AXKeyShortcutsValue to potencjalny game-changer
Jeśli popularne apki (Discord, Notion, Linear, GitHub Desktop) używają `aria-keyshortcuts`, to implementacja jednej warstwy w SFlow da nam zero-config coverage dla dziesiątek apek. Prawdopodobieństwo że to działa i jest szeroko adoptowane: **nieznane, ~20-40%**.

### Teza 2: Lokalizacja to najpoważniejszy problem dla Electron apps
Nawet jeśli mamy tytuły przycisków przez AX, polska wersja Discorda powie "Wycisz" zamiast "Mute". Reguły per język skalują się źle. Jedyne language-agnostic podejścia:
- `AXKeyShortcutsValue` (jeśli jest)
- `kAXIdentifierAttribute` (DOM id, zwykle angielski/programistyczny)
- Pozycja elementu w UI (kruche)

### Teza 3: Background AX tree scan jest wykonalny ale ograniczony
Przy każdym wejściu apki na foreground: skanuj wszystkie `AXButton` + `AXLink` z tytułem. Dla każdego elementu: sprawdź czy tytuł matchuje do naszej bazy skrótów. Problemy:
- AX tree Electron app może mieć tysiące nodów — scan może trwać sekundy
- Trzeba skanować leniwie / inkrementalnie
- Skróty z bazy nadal muszą być ręcznie zebrane

### Teza 4: Dla top-100 apek wystarczy półautomatyczny pipeline
1. Odpal apkę z SFlow diagnostic mode → klikaj przez 5 min → wszystkie atrybuty zalogowane
2. Claude analizuje logi → generuje reguły
3. Wklejasz reguły do `ShortcutRules.swift`
Koszt: ~15 min per apka. 100 apek = ~25 godzin jednorazowo, potem update per wersja.

### Teza 5: SFlow może skanować AX tree w tle zaraz po odpaleniu nowej apki
Trigger: `NSWorkspace.shared.notificationCenter` + `NSWorkspace.didActivateApplicationNotification`.
Skan: shallow walk (głębokość 3-4) tylko dla interaktywnych ról.
Wynik: cache `[bundleId: [ElementSignature: Keys]]` na dysku.
Problem: skąd wiemy jakie keys przypisać do znalezionego elementu bez zewnętrznej bazy?

### Teza 6: Apki Electron mają DevTools — to daje dostęp do pełnego DOM
W trybie debug Electrona można otworzyć DevTools i odpalić:
```js
document.querySelectorAll('[aria-label]').map(el => ({
  tag: el.tagName, label: el.getAttribute('aria-label'),
  ks: el.getAttribute('aria-keyshortcuts'), role: el.getAttribute('role')
}))
```
Ale: Discord w produkcji nie ma DevTools. Można to zrobić przez remote debugging (`--remote-debugging-port`) ale wymaga restartu Discorda z flagą.

### Teza 7: Crowdsourcing reguł między userami (z opt-in) rozwiązuje skalę
SFlow zbiera lokalnie `{bundleId, elementTitle, role}` dla każdego kliknięcia bez toastu. User który opt-in wysyła te dane na serwer. Claude generuje reguły. Wszyscy userzy dostają reguły przez update. Privacy: metadane UI, nie content — ale wymaga jasnej komunikacji.

---

## 6. Otwarte pytania techniczne

1. **Czy Discord używa `aria-keyshortcuts`?** — Kluczowe. Można sprawdzić przez DevTools w przeglądarce na discord.com (wersja web), zakładając że desktop = ta sama codebase.

2. **Jak szybki jest shallow AX tree scan dla Electron app?** — Nie wiemy. Może 50ms, może 2s.

3. **Czy `kAXIdentifierAttribute` w Electron jest stabilny i angielski?** — Jeśli tak, jest lepszy niż `title` do matchowania (nie zależy od języka UI).

4. **Czy można odczytać wszystkie atrybuty elementu bez wiedzenia jakie istnieją?** — Tak: `AXUIElementCopyAttributeNames` zwraca tablicę nazw wszystkich atrybutów. Nieużywane w SFlow.

5. **Czy AppleScript może odczytać więcej niż AX API?** — Nie. AppleScript to wrapper na AX API.

6. **Czy macOS Screen Recording permission daje dostęp do więcej danych UI?** — Nie bezpośrednio, ale daje pixel access (screenshot) z którego można robić OCR.

7. **Ile apek ze sklepów (Setapp, MAS) faktycznie używa `aria-keyshortcuts`?** — Nieznane. Podejrzewamy że mało — to stosunkowo niszowy atrybut.

---

## 7. Znane ograniczenia podejść

| Podejście | Ograniczenie |
|---|---|
| AXKeyShortcutsValue | Apki muszą to ustawiać (mało robi) |
| title: matching | Localization problem — apka po polsku, reguły po angielsku |
| Menu bar scan | Electron apki mają ubogie menu bar |
| Help text parse | Mało apek daje skróty w tooltipach |
| Background AX scan | Skąd wiemy jakie skróty przypisać do znalezionych elementów? |
| DevTools DOM dump | Wymaga debug mode lub remote debugging w Electron |
| OCR/screenshot | Nierzetelne, resource-intensive, privacy-wrecking |
| Pozycja ekranowa | Kruche po zmianie layoutu/okna |

---

## 8. Co SFlow robi a czego nie robi (ważne dla agentów)

**Robi:**
- Nasłuchuje kliknięć, nie zmienia żadnego inputu (listenOnly tap)
- Pokazuje overlay toast przez ≈1.5s, znika sam
- Czyta AX metadane UI (role, title, desc, help) — to same dane co VoiceOver
- Menu bar skan przy aktywacji apki

**NIE robi (i nie chcemy):**
- Nie wysyła żadnych danych na zewnątrz (lokalny, offline-first)
- Nie klika ani nie steruje innymi apkami
- Nie czyta treści (wiadomości, dokumentów)
- Nie monitoruje co piszesz

**Dostępne permissions na macOS:**
- Accessibility (AX API) — wymagane, user musi dać
- Input Monitoring (CGEventTap) — wymagane, user musi dać
- Screen Recording — NIE mamy, nie prosimy

---

## 9. PROMPT DLA AGENTÓW — Deep Thinking Session

> **Instrukcja:** Wklej poniższy prompt do sesji z agentem (np. Opus). Niech to będzie długa sesja. Agenci mają ze sobą dyskutować, kwestionować założenia, proponować nieoczywiste podejścia.

---

```
Jesteś zespołem ekspertów analizujących problem techniczny. Masz do dyspozycji:
- Architekta systemów macOS (zna AX API, Electron internals, macOS permissions)
- Specjalistę od product design (myśli o UX, privacy, onboarding)
- Inżyniera od performance (myśli o CPU, memory, battery)
- Sceptyka (kwestionuje każde założenie)
- Innowatora (proponuje nieoczywiste podejścia)

## Kontekst

SFlow to macOS app która pokazuje toast ze skrótem klawiszowym gdy user kliknie element UI 
(np. klikasz przycisk "Mute" w Discordzie → toast pokazuje "⌘⇧M"). 
Mechanizm: CGEventTap na kliknięcia + AXUIElement API do identyfikacji elementu.

AX atrybuty odczytywane z każdego klikniętego elementu:
- kAXRoleAttribute (AXButton, AXLink, AXTextField, ...)
- kAXTitleAttribute (z aria-label w Electron/web apps)  
- kAXDescriptionAttribute (zawsze puste w Chromium/Electron)
- kAXHelpAttribute (tooltip, czasem zawiera skrót: "Quick Find ⌘K")
- kAXIdentifierAttribute (DOM id lub React component key)
- kAXSubroleAttribute, kAXPlaceholderValueAttribute

## Problem do rozwiązania

Cel: SFlow powinien działać dla DOWOLNEJ apki którą user zainstaluje — bez konfiguracji.
Alternatywnie: działać dla top-100 apek bez konieczności spędzania godzin na ręcznym kodowaniu reguł per apka.

Obecne podejście (nieeskalowalne):
- Ręcznie hardkodowane reguły per bundleId w ShortcutRules.swift
- np. dla Slacka: `.init(desc: "search", id: "slack-quick-switcher", keys: ["meta","k"], hint: "Quick Switcher")`
- Napisanie reguł dla jednej apki = 1-3h ręcznej inspekcji

Warstwy automatyczne które już istnieją (ale mają ograniczenia):
- L2: auto-parse kAXHelpAttribute → działa gdy apka daje skróty w tooltipach (mało robi)
- L3: menu bar scan → działa dla natywnych apek (Electron ma ubogi menu bar)
- L4: universal heuristics (AXButton desc=back → ⌘←) → ogólne, mało trafień

## Kluczowe fakty techniczne

1. LOKALIZACJA: Największy problem. Electron apki pokazują aria-label w języku UI.
   Discord po polsku: button title = "Wycisz" zamiast "Mute". 
   Reguły po angielsku nie matchują.

2. AXKeyShortcutsValue: Chromium eksponuje HTML aria-keyshortcuts jako AXKeyShortcutsValue.
   Jeśli apka ustawia <button aria-keyshortcuts="Meta+Shift+M">, SFlow może odczytać skrót 
   BEZ żadnej hardkodowanej reguły. Language-agnostic. 
   ALE: nieznane jak szeroko adoptowane. Większość apek tego nie ustawia.
   Gmail TAK używa aria-keyshortcuts. Discord — nieznane.

3. AXUIElementCopyAttributeNames: Nieużywane w SFlow. Pozwala pobrać WSZYSTKIE atrybuty 
   elementu, w tym niestandardowe. Może być klucz do odkrycia nieznanych atrybutów.

4. Electron AX tree: Gdy aplikacja z AX permissions (jak SFlow) jest uruchomiona, 
   Electron automatycznie włącza swój AX tree. Nie wymaga VoiceOver.

5. Background scan: SFlow może skanować AX tree dowolnej apki w tle (NSWorkspace 
   notification + AXUIElementCreateApplication). Nie wiemy jak szybko to działa dla 
   dużych Electron app z tysiącami nodów.

6. Onboarding jako okazja: Przy pierwszym uruchomieniu SFlow mógłby prosić usera o 
   "przejście" przez ulubione apki podczas guided setup — i zbierać AX dane wtedy.

7. Shortcut databases: Istnieją bazy skrótów (defkey.com, cheatsheets) dla setek apek.
   Można je scrapeować/embedować. Problem: jak zmatchować "Toggle Mute" z bazy do 
   "Wycisz" z AX tree danego usera?

## Co NIE jest akceptowalne

- Wysyłanie treści (wiadomości, dokumentów) na serwer — ABSOLUTNIE NIE
- Screen Recording permission — nie chcemy prosić o to
- Klikanie/sterowanie innymi apkami — tylko listenOnly
- Rozwiązania które wymagają od usera kilkugodzinnego setup per apka
- Rozwiązania które rozładowują baterię (ciągłe skanowanie w pętli)

## Co jest akceptowalne (z opt-in i jasną komunikacją)

- Wysyłanie anonimowych metadanych UI (bundleId, elementTitle, role) na serwer jeśli 
  user świadomie się zgodzi i rozumie co to znaczy
- Jednorazowy onboarding scan przy instalacji
- Lazy background scan (tylko gdy apka jest bezczynna)
- Pobieranie reguł z internetu (update mechanizm)

## Pytania do głębokiej analizy

Podejdź do każdego z tych pytań z kilku stron — za, przeciw, edge cases:

### Q1: AXKeyShortcutsValue jako główna strategia
Czy implementacja L0 (sprawdzaj AXKeyShortcutsValue na każdym klikniętym elemencie i 
jego przodkach) jest wystarczająca jako główny mechanizm? Jakie jest realne pokrycie 
popularne apek? Jak sprawdzić without running the apps? Jakie są edge cases 
(nieprawidłowe wartości, kolizje klawiszy, OS-level shortcuts)?

### Q2: Lokalizacja vs. identyfikatory
Skoro tytuły przycisków są w języku UI, czy kAXIdentifierAttribute (DOM id) jest 
stabilnym, language-agnostic alternatywem? Jak stabilne są DOM identyfikatory między 
wersjami apki? Czy Electron apki w ogóle ustawiają sensowne identyfikatory?

### Q3: Background AX scan — wykonalność i performance
Czy shallow scan (głębokość 3-4, tylko interaktywne role) całego AX tree Electron app 
jest wykonalny w <200ms? Jak to skaluje się dla apek jak Discord (bardzo złożony DOM)?
Czy jest lepszy trigger niż "app comes to foreground"?

### Q4: Hybrid approach — match po elemencie + baza skrótów
Pipeline: (1) user klika, (2) SFlow widzi "AXButton title=Wycisz", (3) SFlow tłumaczy 
"Wycisz" na "Mute" przez on-device embedding similarity, (4) matchuje "Mute" do 
shortcut DB która mówi Discord:Mute → ⌘⇧M. 
Czy to jest feasible? Jak dobry musi być model embeddingów żeby to działało? 
Czy można to zrobić z Apple's on-device ML bez internetu?

### Q5: Onboarding jako discovery mechanism
Zamiast background scan — guided onboarding: "Pokaż mi swoje ulubione apki. Otwórz 
każdą z nich i poklikaj po głównych przyciskach przez 2 minuty." SFlow loguje co widzi.
Potem: local processing lub (opt-in) cloud AI generuje reguły. 
Jakie są za i przeciw? Czy użytkownicy to zrobią? Czy 2 minuty wystarczy?

### Q6: Crowdsourcing z privacy-preserving federated learning
Każdy user SFlow widzi inne apki, inne języki. Czy da się zbudować system gdzie:
- Lokalne modele uczą się na lokalnych danych
- Wysyłają tylko "diff" (encrypted, anonymized) a nie surowe dane
- Agregowane modele wracają jako update
Czy to overkill dla produktu tej skali? Jaki jest minimalny viable version?

### Q7: Czy nie ma już gotowego rozwiązania którego nie rozważamy?
Istniejące narzędzia: Accessibility Inspector (Xcode), AXorcist, pyax, Hammerspoon, 
macapptree. Czy któreś z nich ma mechanizm który możemy zaadaptować lub zintegrować?
Czy jest jakiś macOS private API który daje więcej niż public AX API?

### Q8: Inne platformy jako referencja
Jak robią to inne apki które "uczą skrótów"?
- CheatSheet (macOS) — jak działa? Tylko menu bar?
- Mouseless, Shortcat — jak identyfikują elementy?
- KeyCombiner — skąd ma bazę skrótów?
Czy któreś z tych podejść jest adaptowalne dla SFlow?

## Format odpowiedzi agentów

Prowadźcie dialog — jeden agent podnosi pomysł, drugi kwestionuje, trzeci rozbudowuje.
Nie spieszcie się. Eksplorujcie edge cases. Kwestionujcie założenia (np. "czy na pewno 
aria-keyshortcuts jest rzadkie? sprawdźmy...").

Na końcu dojdźcie do:
1. **Rekomendacja główna** — jedno konkretne podejście do implementacji jako pierwsze
2. **Quick wins** — co można zaimplementować w <1 dzień i da natychmiastową wartość
3. **Długoterminowa architektura** — jak docelowo powinien wyglądać system w v2/v3
4. **Czerwone flagi** — co absolutnie NIE zadziała choć wygląda atrakcyjnie

Bądźcie konkretni: kod, atrybuty AX, API calls, przykłady z Discord/Slack/Notion.
Nie generalizujcie. Kwestionujcie każde założenie które nie jest potwierdzone przez 
faktyczne uruchomienie kodu.
```

---

## 10. Pliki źródłowe do kontekstu dla agentów

Jeśli agent ma dostęp do kodu, kluczowe pliki:

```
SFlow/ClickWatcher.swift     — główna pętla: CGEventTap → AX lookup → layer matching
SFlow/ShortcutRules.swift    — baza reguł L1 + L4, parser skrótów
SFlow/MenuBarIndex.swift     — L3: menu bar scanner
SFlow/MatchConfidence.swift  — system pewności dopasowania
docs/wip-web-shortcuts.md    — poprzednia próba: Gmail, co działało co nie
```

---

*Dokument wygenerowany: 2026-05-11*
*Status: aktywne pytanie badawcze, brak implementacji*
