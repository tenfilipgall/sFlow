# SFlow — Privacy Policy (DRAFT)

> **Status:** ROBOCZY draft, NIE prawne stanowisko. Wymaga review przez
> radcę prawnego przed publikacją. Filip prefers concise transparent
> language over corporate-legalese.
>
> **Wersja:** 0.1-draft, 2026-05-17
>
> **Język wersji finalnej:** PL + EN dwujęzyczne na sflow.app/privacy

---

## Krótka wersja (executive summary)

SFlow to aplikacja działająca **lokalnie na twoim Macu**. **Domyślnie** nic
nie wysyła na serwer. Jedyne dane które opcjonalnie wychodzą poza twój
komputer to **anonimowe statystyki** (jeśli włączysz telemetrię) oraz
**zapytania do AI** o reguły dla nowych apek (bez treści okien).

---

## 1. Co SFlow zbiera lokalnie (na twoim Macu)

### 1.1. Nazwy klikalnych elementów

Gdy klikasz w aplikacji, SFlow czyta **publicznie dostępne nazwy**
elementów UI przez macOS Accessibility API (np. "Compose", "Reply",
"Settings"). To są te same dane które VoiceOver odczytuje na głos osobom
niewidomym.

**Nie czytamy:**
- Treści wiadomości / dokumentów / kodu
- Haseł, danych karty kredytowej (wykrywane przez `PrivacyFilter` i
  redactowane jako `[REDACTED]`)
- Imion kontaktów (emoji + długie stringi auto-redactowane)
- Zawartości pól tekstowych (kAXValue dla AXTextField pomijany dla
  pól wpisanych przez usera)

### 1.2. Pozycje kliknięć

Współrzędne (x, y) kliknięcia myszki w sekundach. **Pozycje są używane
tylko do hit-testu** AX element pod kursorem — nie do trackowania ruchu
myszy.

### 1.3. Skróty klawiszowe użyte (opcjonalne, Faza 2)

W przyszłej wersji SFlow będzie wykrywał **kombinacje z modyfikatorami**
(⌘K, ⇧⌥A, etc.). **Pojedyncze klawisze nie są monitorowane** — żaden
keylogging.

### 1.4. Aktywna aplikacja

`bundleId` aplikacji w której kliknąłeś (np. `com.tinyspeck.slackmacgap`).

### 1.5. Metadane diagnostyczne

- Czy SFlow rozpoznał kliknięcie i pokazał toast (typ: `toast`)
- Czy nie rozpoznał (typ: `miss`)
- Czy zgłosiłeś false-positive (typ: `false_positive`)
- Layer rozpoznawania (L0..L4)

## 2. Gdzie te dane są przechowywane

Wszystkie lokalne dane SFlow w jednym folderze:

```
~/Library/Application Support/SFlow/
├── events.jsonl              ← wszystkie eventy
├── false_positives.jsonl     ← false-positive zgłoszenia
├── discovered/                ← tooltipy zaobserwowane
├── rules/                     ← cache reguł
├── attempted.json             ← discovery retry state
└── user.json                  ← anonimowy UUID (jeśli włączysz telemetry)
```

**Możesz przejrzeć:** Open Finder → ⌘⇧G → wklej powyższą ścieżkę.

**Możesz skasować:** zamknij SFlow → usuń folder → uruchom SFlow ponownie
(nowy start, zero historii).

## 3. Co opcjonalnie wysyłamy na zewnątrz

### 3.1. Zapytania do AI o nowe reguły (zawsze aktywne, opcja off)

Gdy aktywujesz nową apkę po raz pierwszy, SFlow wysyła do naszego
serwera (Cloudflare Worker):
- `bundleId` apki (np. `com.example.app`)
- `appName` (np. "Example App")
- `appVersion`
- **Menu bar dump** — lista pozycji menu bar tej apki + ich skróty
  (te same dane co VoiceOver czyta)
- **UI skeleton** — uproszczone drzewo widocznych elementów (max 500
  pozycji): role + title + identifier per element. **PrivacyFilter
  redactuje pola z PII** przed wysłaniem.

Serwer wysyła to do Anthropic Claude API, który **generuje** reguły.
Wynik (reguły JSON) wraca do twojego Maca i jest cache'owany lokalnie.

**Wyłącz w Settings:** "Auto-discover new apps" toggle off → SFlow przestaje
robić zapytania do AI.

### 3.2. Anonimowa telemetria (default OFF)

Jeśli włączysz toggle "Share usage stats" w Settings:
- Co 24h SFlow wysyła **anonimowy zagregowany raport**:
  - Twój anonimowy UUID (NIE związany z apple ID / email)
  - Liczby toastów per aplikacja (np. "Slack: 47 toastów dziś")
  - Liczby false-positives per reguła (do globalnego ulepszania)
- **Nie wysyłamy:** poszczególnych eventów, treści okien, pozycji
  kliknięć, czasów

**Możesz wyłączyć** w każdej chwili. Możesz też **zażądać usunięcia**
twoich danych z serwera (`/v1/forget` endpoint, planowany).

### 3.3. Crowdsource tooltipów (planowane, opcja off)

Jeśli włączysz toggle "Share discovered tooltips":
- TooltipObserver wysyła **nazwy akcji + skrótów** które zaobserwował na
  hoverze (np. `{name: "Compose", keys: ["c"]}`) razem z anonimowym UUID
- Cel: jeden user hoveruje → wszyscy dostają regułę
- **PrivacyFilter zawsze redactuje** zanim cokolwiek wyjdzie

## 4. Dane których SFlow **nigdy** nie zbiera

- Klawisze (z wyjątkiem znanych skrótów z modyfikatorami w Fazie 2.2)
- Treść okien
- Hasła
- Dane karty / numery telefonu / SSN
- Imiona kontaktów z apek (auto-redactowane przez emoji detector)
- Adresy email (auto-redactowane)
- URL twoich stron (z wyjątkiem **domeny** dla web-as-app w przyszłej
  Fazie — `mail.google.com` jako pseudo-bundleId, **bez** path/query)
- Geolokalizacja
- Apple ID / email / numer telefonu

## 5. Twoje prawa (GDPR / CCPA)

Jeśli mieszkasz w UE / Kalifornii (lub gdziekolwiek z prawami danych):

- **Prawo do wglądu:** wszystkie dane są w `~/Library/Application Support/SFlow/` — możesz je odczytać sam.
- **Prawo do usunięcia:** usuń folder lub kliknij "Clear all data" w
  Settings.
- **Prawo do przenoszenia:** dane są w czytelnym formacie JSON.
- **Prawo do wniesienia skargi:** UODO (PL) lub odpowiednik w innym kraju.

Jeśli włączyłeś telemetrię, te same prawa dotyczą danych po stronie
serwera — `mailto:filip@gocamping.tv` z prośbą "Forget me", odpowiemy
w 30 dni.

## 6. Zewnętrzni dostawcy

- **Cloudflare Workers** — hostuje nasz backend. Cloudflare ma własną
  privacy policy.
- **Anthropic** — używamy ich Claude API do generowania reguł. NIE
  wysyłamy żadnych danych z konkretnych userów do Anthropic, tylko
  zapytania o reguły dla apek (bundle ID + menu structure).

## 7. Bezpieczeństwo

- Wszystkie zapytania do backendu przez HTTPS
- Backend nie ma żadnego ID identyfikującego usera (jedynie anonymous UUID
  jeśli włączysz telemetrię)
- Dane lokalne nie są szyfrowane (`events.jsonl` jest plain text) — jeśli
  ktoś ma fizyczny dostęp do twojego Maca, może je przeczytać. Twój
  system encryption (FileVault) chroni je gdy Mac jest zalogowany.

## 8. Zmiany tej polityki

Każda zmiana w privacy policy → notification w SFlow ("Privacy policy
updated") + force-read-and-acknowledge przed dalszym użyciem.

## 9. Kontakt

- **Email:** filip@gocamping.tv
- **GitHub Issues:** github.com/[org]/sflow/issues
- **Privacy concern hot-line:** "privacy@" + email above

---

*Privacy policy draft 2026-05-17. Wymaga: (a) legal review przez radcę,
(b) translation do EN finalnej, (c) publication na sflow.app/privacy
przed beta launch.*
