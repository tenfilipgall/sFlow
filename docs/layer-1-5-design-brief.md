# SFlow Layer 1.5 — Design Brief for Deep Agent Review

## Kontekst: co to jest SFlow

SFlow to aplikacja macOS menu bar. Gdy użytkownik **kliknie myszką** na element UI w dowolnej aplikacji (Slack, Notion, Figma, itp.), SFlow wykrywa że ten element ma odpowiedni skrót klawiszowy i pokazuje toast z tym skrótem. Cel: uczyć użytkowników używać skrótów zamiast klikać.

**Użytkownicy docelowi (ICP):** graficy, fotografowie, programiści, pracownicy biurowi. Power userzy którzy chcą być szybsi ale zapominają o skrótach.

---

## Problem — sformułowanie precyzyjne

### Co chcemy osiągnąć

Toasty ze skrótami klawiszowymi powinny działać dla **~100 aplikacji** bez:
1. Konieczności pisania per-app kodu Swift dla każdej nowej aplikacji
2. Konieczności manualnego "odkrywania" atrybutów AX przez klikanie i logowanie
3. Stałego utrzymywania kodu gdy aplikacje zmieniają UI

### Obecna architektura (4 warstwy)

Gdy użytkownik kliknie, `ClickWatcher.handleMouseDown()` odpytuje macOS Accessibility API (AX) o atrybuty klikniętego elementu i jego przodków (do 6 poziomów w górę drzewa):

```
Layer 1: Per-app hardcoded Swift rules (ShortcutRules.swift)
         "com.tinyspeck.slackmacgap" → jeśli desc zawiera "compose" → ⌘N
         → PROBLEM: wymaga pisania kodu per-apka, wymaga znajomości AX atrybutów

Layer 2: kAXHelpAttribute auto-parse
         Jeśli element ma help="Quick Find ⌘K" → parsuje → pokazuje ⌘K
         → DZIAŁA ALE: nie wszystkie apki ustawiają kAXHelp

Layer 3: MenuBarIndex fuzzy match
         Indeksuje menu bar aktywnej apki → fuzzy match nazwy elementu z pozycją menu
         "archive" → fuzzy match → "Archive" w menu → ⌘E
         → DZIAŁA ALE: powoduje false positives (np. "copy link" → Edit>Copy → ⌘C)

Layer 4: Universal semantic heuristics (hardcoded Swift)
         AXButton z desc="back" → ⌘←, AXSearchField → ⌘F, itp.
         → DZIAŁA ALE: zbyt ogólne, mało skrótów

Fallback: checkMenuBar()
         Jeśli kliknięto w menu barze apki → odczytuje skrót z AXMenuItemCmdCharAttribute
```

### Konkretne problemy które próbowaliśmy rozwiązać

**Problem A: Skalowanie do 100 apek**
- Obecne Layer 1 reguły to ~600 linii Swift dla 18 apek
- Dodanie nowej apki wymaga: poznania AX atrybutów (NSLog/AXDumper) + napisania kodu + testów
- Dla 100 apek: ~3300 linii Swift, czas × 5 na apkę

**Problem B: AX atrybuty są nieznane bez discovery**
- Electron apps (Slack, Notion, Linear, Figma) eksponują AX przez Chromium accessibility tree
- Faktyczny `desc`/`title` elementu ≠ zawsze widoczny label
- Np. przycisk "Edit" w Slack miał `desc="" ` i dopiero ancestor miał `desc="compose"` → bug

**Problem C: False positives**
- Layer 3 (fuzzy menu match) łapał "copy link" → "copy" w menu → ⌘C zamiast L
- False positive jest GORSZY niż brak toastu — uczy użytkownika złego skrótu

**Problem D: Kolejność reguł jest krucha**
- `desc: "unread"` matchuje "all unreads" (substring) → zły skrót
- Odkryliśmy to przez unit testy, nie podczas używania

### Co już próbowaliśmy

1. **Per-app Swift rules (Layer 1)** — działa ale nie skaluje
2. **NSLog diagnostic** — dodaliśmy logi per-apka, wymaga Console.app + manualnego klikania
3. **AXDumper test** — snapshot AX tree bez klikania, ale tylko statyczne elementy
4. **Unit testy ShortcutRules** — 42 testy, wykrywają błędy reguł bez uruchamiania apek
5. **Generic AXDumper** — narzędzie dla dowolnej apki, ale wymaga 3 snapshoty × manual

---

## Proponowane rozwiązanie: Layer 1.5

### Idea

Zamiast pisać Swift kod per-apka, utrzymywać zewnętrzny **plik JSON** z wiedzą o skrótach. Generic Swift matcher czyta JSON i aplikuje reguły do AX atrybutów.

```
bundleId: "notion.mail.id"
actions:
  compose: { keys: ["c"], hint: "Compose", match: ["compose", "new email", "write"] }
  archive: { keys: ["e"], hint: "Archive", match: ["archive", "done"] }
```

### Klucz: match lista = przewidywane wartości AX atrybutów

Dla każdej akcji: lista stringów które sprawdzamy przeciw `desc`, `title`, `help`, `placeholder`, `id` elementu. Jeśli którykolwiek atrybut zawiera któregokolwiek z match stringów → shortcut.

### Confidence levels

- Exact match na `desc` lub `title` → `.high` → pokaż toast
- Match na `id` lub `help` → `.medium` → pokaż toast (opcjonalnie inny styl)
- Poniżej progu → nic

### Skąd dane dla 100 apek

**Źródło 1:** Istniejące Layer 1 reguły → automatyczna konwersja do JSON (seed data)
**Źródło 2:** Oficjalne shortcut pages każdej apki (web research)
**Źródło 3:** Passive discovery mode — SFlow loguje AX atrybuty do pliku gdy użytkownik używa apek normalnie, bez żadnej akcji z jego strony

### Plik zewnętrzny (updatable bez release)

`~/Library/Application Support/SFlow/rules.json`

Aktualizowany przez SFlow automatycznie z CDN lub GitHub, bez App Store release.

---

## Tezy i założenia (do weryfikacji przez agentów)

**Teza 1:** Dla Electron apps, `kAXDescription` ≈ `aria-label` ≈ widoczny label przycisku. Prawdopodobieństwo ~65-80%. Wystarczy do działania Layer 1.5.

**Teza 2:** kAXHelpAttribute jest NIEDOSTATECZNIE wykorzystany. Wiele apek już tam ma "Compose (C)" lub "Quick Find ⌘K" — to gotowy shortcut. Layer 2 powinien być silniejszy.

**Teza 3:** Menu bar (Layer 3) jest najdokładniejszym źródłem skrótów — apka nie może kłamać w swoim własnym menu. Problem to fuzzy matching, nie samo źródło.

**Teza 4:** Single-key shortcuts (E, C, R) pokazywać toast TYLKO gdy focus NIE jest w text field. Inaczej toast pojawia się kiedy użytkownik wpisuje "compose" w search.

**Teza 5:** False positive > brak toastu pod względem szkodliwości UX. Threshold confidence powinien być konserwatywny.

**Teza 6:** Crowd-sourced / community JSON rules są możliwe. Użytkownicy mogą reportować błędy/brakujące reguły, plik aktualizowany centralnie.

---

## Rzeczy które mogliśmy pominąć (do krytycznej weryfikacji)

1. **Layer 2 (kAXHelp) może już rozwiązywać dużo więcej niż myślimy** — czy warto najpierw zbadać ile apek faktycznie tam ma shortcut info zanim budujemy Layer 1.5?

2. **Menu bar jako ground truth** — zamiast fuzzy match (Layer 3), czy można go użyć lepiej? Apka MUSI zadeklarować skrót w menu → mamy gwarancję poprawności. Problem: jak zmapować label elementu → pozycja menu bez false positives?

3. **Confidence aggregation** — jeśli Layer 1.5 I Layer 3 obydwa mówią to samo → wysoka pewność. Aktualnie zwracamy pierwszy match i wracamy. Może powinniśmy zbierać głosy ze wszystkich warstw?

4. **Context: single-key shortcuts działają TYLKO gdy fokus nie jest w text field** — czy to w ogóle sprawdzamy? Może toasty dla skrótów jednoklawiszowych powinny być wygaszane gdy cursor jest w input?

5. **Lokalizacja** — "Senden" zamiast "Send" dla niemieckiego użytkownika. Match listy musiałyby być wielojęzyczne albo trzeba innego podejścia.

6. **App version sensitivity** — Slack zmienił labels między wersjami. JSON rules starzeją się. Potrzeba versioning + auto-update mechanism.

7. **Privacy** — passive discovery mode loguje WSZYSTKO co klikasz (AX atrybuty). To może być wrażliwe. Jak to projektować privacy-first?

8. **Native macOS apps vs Electron** — strategia może być inna. Native apps mają AXButton, AXMenuItem bardzo dobrze zdefiniowane. Electron przez AXWebArea. Czy jedna architektura obsługuje obie?

9. **Istniejące bazy danych skrótów** — czy istnieje już jakaś baza (ShortcutMapper, cheatsheet.zip, podobne projekty) którą moglibyśmy zaimportować zamiast scrapować od zera?

10. **Czy w ogóle potrzeba Layer 1.5?** — co jeśli naprawimy Layer 3 (menu bar match) żeby nie robił false positives? Menu bar JUŻ MA wszystkie skróty. Problem to złe mapowanie kliknięty-element → menu-item. Czy rozwiązanie menu-bar-first byłoby prostsze i dokładniejsze?

---

## Lista Top 30 apek (ICP: graficy, fotografowie, programiści, biurowi)

### Już zaimplementowane (18 apek)
Slack, Notion, Figma, VS Code, Linear, Claude Desktop, WhatsApp, Perplexity Comet, Chrome, Arc, Mail, Safari, Xcode, Terminal, Finder, Notion Calendar, Notion Mail, Spotify

### Brakujące — do zbadania i dodania
| Apka | Kategoria | Bundle ID |
|------|-----------|-----------|
| Figma (web) | Design | — |
| Adobe Photoshop | Design/Photo | com.adobe.Photoshop |
| Adobe Illustrator | Design | com.adobe.illustrator |
| Adobe Lightroom | Photo | com.adobe.lightroom |
| Sketch | Design | com.bohemiancoding.sketch3 |
| Affinity Designer | Design | com.seriflabs.affinitydesigner2 |
| Affinity Photo | Photo | com.seriflabs.affinityphoto2 |
| Capture One | Photo | com.phaseone.captureone |
| Final Cut Pro | Video | com.apple.FinalCutPro |
| DaVinci Resolve | Video | com.blackmagicdesign.resolve |
| JetBrains (IntelliJ/WebStorm/PyCharm) | Dev | com.jetbrains.* |
| Zed | Dev | dev.zed.Zed |
| Cursor | Dev | com.todesktop.230313mzl4w4u92 |
| GitHub Desktop | Dev | com.github.GitHubDesktop |
| Sourcetree | Dev | com.torusknot.SourceTreeNotMAS |
| TablePlus | Dev | com.tinyapp.TablePlus |
| Postman | Dev | com.postmanlabs.mac |
| Microsoft Word | Office | com.microsoft.Word |
| Microsoft Excel | Office | com.microsoft.Excel |
| Google Chrome (web apps) | Browser | com.google.Chrome |
| 1Password | Utility | com.1password.1password |
| Raycast | Utility | com.raycast.macos |
| Obsidian | Notes | md.obsidian |
| Bear | Notes | net.shinyfrog.bear |
| Things | Tasks | com.culturedcode.ThingsMac |
| Superhuman | Email | com.superhuman.electron |
| Loom | Video/Collab | com.loom.desktop |
| Miro | Collab | de.miro.app |
| Zoom | Meetings | us.zoom.xos |
| Teams | Meetings | com.microsoft.teams2 |

---

## Prompt dla agentów: Deep Thinking Session

```
KONTEKST:
Jesteś jednym z agentów w multi-agent design session. Zadanie to krytyczna analiza 
i projektowanie architektury dla SFlow — macOS aplikacji która pokazuje toasty 
ze skrótami klawiszowymi gdy użytkownik kliknie przycisk myszką.

Pełny brief w dokumencie powyżej (przeczytaj całość przed odpowiedzią).

TWOJA ROLA:
Będziesz debatować z innymi agentami. Każdy agent ma inną perspektywę:
- Agent A: Sceptyk / Advocatus Diaboli — szukaj dziur, kwestionuj założenia
- Agent B: Pragmatyk / Inżynier — "co jest najszybsze do zaimplementowania i działa"  
- Agent C: Idealista / Architekt — "co jest właściwe długoterminowo"
- Agent D: User advocate — "co jest najlepsze dla użytkownika końcowego"

PYTANIA DO GŁĘBOKIEJ ANALIZY:

1. CORE QUESTION: Czy Layer 1.5 (JSON knowledge base) to właściwe rozwiązanie?
   Czy jest prostsze / lepsze podejście które pominęliśmy?
   
2. MENU BAR AS GROUND TRUTH: Menu bar aplikacji już zawiera skróty klawiszowe 
   z gwarancją poprawności. Obecny Layer 3 używa go ale z fuzzy match który powoduje 
   false positives. Czy naprawienie Layer 3 (lepsza logika mapowania element → menu item)
   byłoby prostsze i dokładniejsze niż cały Layer 1.5?

3. kAXHELP UNDERUTILIZATION: Wiele aplikacji już ma w kAXHelpAttribute informacje 
   o skrócie ("Compose (C)", "Quick Find ⌘K"). Layer 2 to parsuje ale może to być
   GŁÓWNE rozwiązanie a nie fallback. Jak to wyeksploatować lepiej?

4. FALSE POSITIVES: Toast z błędnym skrótem uczy użytkownika ZŁEGO skrótu.
   Jaki próg confidence jest właściwy? Czy lepiej nie pokazać nic niż pokazać źle?
   Jak projektować system który preferuje precision nad recall?

5. ELECTRON vs NATIVE: Dwie fundamentalnie różne strategie mogą być potrzebne.
   Electron apps mają AXWebArea z Chromium accessibility (aria-label → desc).
   Native apps mają pełne AX API. Czy jedna architektura obsługuje obie?

6. SINGLE-KEY SHORTCUTS CONTEXT: Skróty E, C, R działają tylko gdy focus NIE jest 
   w text field. Czy SFlow to sprawdza? Czy powinien?

7. PRYWATNOŚĆ: Passive discovery mode musi logować AX atrybuty wszystkich kliknięć
   we wszystkich aplikacjach. To potencjalnie bardzo wrażliwe dane. Jak projektować
   to privacy-first? Czy w ogóle budować?

8. MAINTENANCE: JSON rules starzeją się gdy aplikacje zmieniają UI. 
   Jak projektować system który sam się waliduje / wykrywa nieaktualne reguły?

9. ALTERNATYWY KTÓRYCH NIE ROZWAŻYLIŚMY:
   - Screen OCR: zamiast AX API, czytać tekst z ekranu optycznie → matchować do bazy
   - Keyboard event monitoring: obserwować NIEUŻYTE skróty i uczyć tylko tych
   - ML classification: trenować model który klasyfikuje elementy UI na semantic actions
   - Crowdsourcing: użytkownicy reportują skróty, centralny JSON, community-maintained
   - Integracja z OS Shortcuts / Accessibility Inspector Apple

10. PRIORYTETYZACJA: Gdybyś miał zaimplementować JEDNO ulepszenie które daje 
    największy bang-for-buck dla 100 aplikacji — co by to było?

FORMAT ODPOWIEDZI:
1. Każdy agent odpowiada po kolei ze swojej perspektywy (300-500 słów)
2. Agenci mogą bezpośrednio odnosić się do argumentów innych agentów
3. Po debacie: wspólna lista WNIOSKÓW i REKOMENDACJI z priorytetami
4. Na końcu: lista rzeczy które AGENCI NIE WIEDZĄ i powinny być zbadane empirycznie

WAŻNE: Nie zgadzaj się ze wszystkim. Kwestionuj założenia. 
Szukaj rozwiązań które są o rząd wielkości prostsze od Layer 1.5 jeśli takie istnieją.
Myśl nieszablonowo. Czas na myślenie — nie spiesz się.
```

---

## Aktualny stan kodu (snapshot dla agentów)

### Pliki kluczowe
- `SFlow/ClickWatcher.swift` — 272 linii, core detection logic
- `SFlow/ShortcutRules.swift` — 737 linii, Layer 1 + Layer 4 rules
- `SFlow/MenuBarIndex.swift` — ~130 linii, Layer 3 (fuzzy menu match)
- `SFlowTests/ShortcutRulesTests.swift` — 42 testy unit
- `SFlowTests/AXDumper.swift` — diagnostic tool

### Znane bugi / ograniczenia
- `desc: "unread"` matchowało "all unreads" (substring) — naprawione przez kolejność reguł
- "copy link" → false positive Layer 3 → ⌘C zamiast L — naprawione Layer 1 regułą
- "edit" button w Slack → ancestor "compose" → ⌘N zamiast E — naprawione Layer 1 regułą
- Brak testów które uruchamiają real Slack/Notion — tylko unit testy z mock danymi

### Architektura detection flow (pseudokod)
```
handleMouseDown():
  element = AXUIElementCopyElementAtPosition(click_position)
  for depth in 0..6:
    attrs = read_all_ax_attributes(element)
    
    // Layer 1: per-app hardcoded
    if match = ShortcutRules.match(bundleId, attrs): emit(match); return
    
    // Layer 2: kAXHelp parse
    if attrs.help has shortcut: emit(parsed_shortcut); return
    
    // Layers 3+4: only on interactive roles
    if attrs.role is interactive:
      // Layer 3: menu bar fuzzy
      if match = menuBarIndex.lookup(attrs.text): emit(match); return
      // Layer 4: universal semantic
      if match = universalRules.first(matching: attrs): emit(match); return
    
    element = element.parent
  
  // Fallback: check if click was in app's menu bar itself
  checkMenuBar()
```
