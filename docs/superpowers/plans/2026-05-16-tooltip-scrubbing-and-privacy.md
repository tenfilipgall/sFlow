# Plan — Sesja B.1: TooltipObserver scrubbing + MissEvent PII filter

> **Status:** DRAFT, sugerowane jako pierwsza sesja po powrocie Filipa (krótka,
> ~3h, bezpośrednio adresuje 2 znalezione issues).
>
> **Skąd:** `docs/events-jsonl-analysis-2026-05-16.md` §3 (false-positive
> "shortcut") + §5 (PII w events.jsonl).
>
> **Adresuje:** dwa nowe potencjalne problemy do P-39 (TooltipObserver
> false-positive) i P-40 (MissEvent PII scrubbing). Filip decyduje czy promować
> do audit-phase-0.md.

---

## 1. Problem 1 — L0.3 false positive "shortcut" keys=["2"]

**Dane (events.jsonl):**
```
2026-05-16T07:58:06Z  ai.perplexity.comet  hint="shortcut" keys=["2"]
2026-05-16T07:58:08Z  ai.perplexity.comet  hint="shortcut" keys=["2"]
2026-05-16T07:58:14Z  ai.perplexity.comet  hint="shortcut" keys=["2"]
2026-05-16T07:58:20Z  ai.perplexity.comet  hint="shortcut" keys=["2"]
```

**4 false-positives w jednej sesji** Notion/Comet usage — TooltipObserver
zinterpretował element zawierający słowo "shortcut" + "2" jako tooltip akcji.

**Plan fixu:**

### 1.1. Banned name list w `TooltipObserver`

Plik: `SFlow/TooltipObserver.swift` (lub nowy `SFlow/TooltipNameFilter.swift`
dla testability).

Dodać static blacklistę słów-meta:

```swift
private static let bannedNames: Set<String> = [
    "shortcut", "shortcuts", "hotkey", "hotkeys",
    "key", "keys", "keyboard", "kb",
    "press", "click", "tap",
    "help", "info", "tip",
]
```

Reguła w `parseTooltipTexts` (lub gdzie ekstraktujemy name):
```swift
let nameLC = name.lowercased().trimmingCharacters(in: .whitespaces)
if Self.bannedNames.contains(nameLC) { return nil }
```

### 1.2. Multi-word OR single-word-verb-whitelist

Single-word name'y są ryzykowne ("shortcut", "tip", "hint"). Multi-word
imperatives ("Mark unread", "Reply to thread") są bezpieczne. Dla
single-word dodać whitelistę znanych verbów:

```swift
private static let whitelistedSingleWords: Set<String> = [
    "reply", "forward", "compose", "archive", "delete",
    "save", "search", "find", "send", "edit",
    "open", "close", "new", "copy", "paste",
    "undo", "redo", "back", "next", "previous",
    "settings", "help",
]
```

Reguła: jeśli name nie zawiera spacji → musi być w whitelistedSingleWords,
inaczej `return nil`.

### 1.3. Tests (5 nowych w `TooltipShortcutParserTests` lub nowym pliku)

1. name="shortcut" badge="K" → nil (banned)
2. name="hotkey" badge="2" → nil (banned)
3. name="Compose" badge="C" → ok (whitelisted single word)
4. name="Mark unread" badge="U" → ok (multi-word)
5. name="randomword" badge="A" → nil (single-word not whitelisted)

### 1.4. Cleanup `discovered/*.jsonl`

Wyczyścić istniejące fałszywe entries:
```bash
jq -c 'select(.name != "shortcut" and .name != "hotkey")' \
  ~/Library/Application\ Support/SFlow/discovered/ai.perplexity.comet.jsonl \
  > /tmp/clean.jsonl && \
  mv /tmp/clean.jsonl ~/Library/Application\ Support/SFlow/discovered/ai.perplexity.comet.jsonl
```

**Czas: ~1h.**

---

## 2. Problem 2 — MissEvent PII scrubbing

**Dane (events.jsonl):**

PII w `desc`/`value`/`title`/`subtreeLabel` polach MissEvent:
- WhatsApp: imiona kontaktów ("☀️Sade☀️", "Aday"), treść wiadomości
- Notion: tytuły prywatnych notatek
- Comet: dane karty kredytowej ("MasterCard •••• 2534 Filip Gawel 4 2032")

**Aktualnie:** `EventLogger.logMiss` zapisuje wszystkie pola bez filtra.
`AXSkeletonExtractor.shouldEmit` ma już privacy filter — używany TYLKO przy
discovery, nie przy miss-logging.

**Plan fixu:**

### 2.1. Wyekstraktować privacy filter do osobnego helpera

Nowy plik: `SFlow/PrivacyFilter.swift` (~80 LOC).

```swift
enum PrivacyFilter {
    /// Returns true if the string contains personal/sensitive data and should
    /// NOT be logged or transmitted. Liberal — false positives (drops safe data)
    /// preferred over false negatives (leaks PII).
    static func containsPII(_ s: String) -> Bool {
        if s.isEmpty { return false }
        // Emails
        if s.range(of: #"[\w.-]+@[\w.-]+\.\w+"#, options: .regularExpression) != nil { return true }
        // ISO dates
        if s.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil { return true }
        // Credit card patterns (masked or not)
        if s.range(of: #"[•*]{4}\s*\d{4}"#, options: .regularExpression) != nil { return true }
        if s.range(of: #"\d{4}\s?\d{4}\s?\d{4}\s?\d{4}"#, options: .regularExpression) != nil { return true }
        // Phone-like
        if s.range(of: #"\+?\d{2,3}\s?\d{3}\s?\d{3}\s?\d{3}"#, options: .regularExpression) != nil { return true }
        // Emoji (heuristic for user-generated content / contact names)
        if s.unicodeScalars.contains(where: { $0.properties.isEmoji && $0.value > 0x1F000 }) { return true }
        // Very long string (likely content, not UI label)
        if s.count > 80 { return true }
        // Currency markers in middle of string
        if s.range(of: #"[$€£¥]\s?\d"#, options: .regularExpression) != nil { return true }
        return false
    }

    /// Returns string with PII redacted to "[REDACTED]" or empty if completely PII.
    /// Use for fields where we still want SOMETHING in the log for debug context.
    static func redact(_ s: String) -> String {
        if containsPII(s) { return "[REDACTED]" }
        return s
    }
}
```

### 2.2. Zastosować w `EventLogger.logMiss`

W `SFlow/EventLogger.swift` (sprawdzić obecne):

```swift
func logMiss(...) {
    let event = MissEvent(
        // ... niezmienione pola
        desc: PrivacyFilter.redact(desc),
        value: PrivacyFilter.redact(value),
        title: PrivacyFilter.redact(title),
        subtreeLabel: PrivacyFilter.redact(subtreeLabel),
        // identifier zostaje — to DOM id, nie PII
    )
    // ... reszta
}
```

Alternatywa **bardziej liberalna**: skip CAŁY miss event jeśli **jakikolwiek**
pole zawiera PII — to oszczędza dyskowe zapisy ale gubi context dla legit
buttons w apkach które mają jeden kontaminowany element.

**Rekomenduję redact-not-skip** — zachowujemy ślad że miss miał miejsce, ale
nie pokazujemy treści.

### 2.3. Tests (8 nowych w `PrivacyFilterTests.swift`)

1. `containsPII("filip@example.com")` → true (email)
2. `containsPII("2026-05-16")` → true (date)
3. `containsPII("MasterCard •••• 2534")` → true (card)
4. `containsPII("☀️Sade☀️")` → true (emoji)
5. `containsPII("This is a very long string that exceeds eighty characters because it represents user content not a UI label")` → true (length)
6. `containsPII("Compose")` → false
7. `containsPII("Quick Switcher")` → false
8. `containsPII("Mark unread")` → false

Plus 2 testy `redact`:
9. `redact("Compose")` → "Compose"
10. `redact("filip@example.com")` → "[REDACTED]"

### 2.4. Cleanup istniejącego events.jsonl

```bash
# Re-process istniejący log z nowym filtrem (1-off)
swift run sflow-redact-log \
  ~/Library/Application\ Support/SFlow/events.jsonl \
  > /tmp/events-clean.jsonl && \
  mv /tmp/events-clean.jsonl ~/Library/Application\ Support/SFlow/events.jsonl
```

Albo prostszy: archive obecny + start fresh.

**Czas: ~1.5h.**

---

## 3. Acceptance criteria

- [ ] `TooltipNameFilter` (lub modified `TooltipObserver`) odrzuca "shortcut",
      "hotkey" jako name → 5 testów
- [ ] `PrivacyFilter` ma 10 testów (8 detection + 2 redaction)
- [ ] `EventLogger.logMiss` używa `PrivacyFilter.redact` na desc/value/title/sub
- [ ] **Świeży events.jsonl po 1 dniu** nie zawiera imion z WhatsApp, danych
      karty, content z Notion — manual verify Filipa
- [ ] **Świeży discovered/ai.perplexity.comet.jsonl** nie zawiera wpisów z
      name="shortcut"
- [ ] Wszystkie 256+ testów passing

---

## 4. Co NIE robimy

- **Nie tworzymy P-39/P-40 w audyt** bez decyzji Filipa — to są kandydat
  problemy, decyzja czy promować po code review
- **Nie zmieniamy** AXSkeletonExtractor.shouldEmit — działa od dawna, ten
  plan dodaje EQUIVALENT filter dla MissEvent osobno
- **Nie ruszamy** DiscoveredStore filter (Sesja B miała własny privacy filter
  dla discovered entries) — sprawdzić tylko że jest spójny z nowym
  `PrivacyFilter` (refaktor opcjonalny, nie blokujący)

---

## 5. Pre-flight

- [ ] git status clean (lub explicit "wiem co commit'uję")
- [ ] Backup `events.jsonl` przed cleanup: `cp events.jsonl events.jsonl.bak`
- [ ] Filip OK z założeniem "log nie zawiera content stringów dłuższych niż
      80 znaków" — to znaczy że nie zobaczymy w log'u "Open in side peek
      <długi tytuł>", co może być stratą dla debug coverage gap

---

## 6. Statusy do zaktualizowania

- `audit-phase-0.md`: dodać P-39 (TooltipObserver false positives) i P-40
  (MissEvent PII) z statusem 🟢 jeśli sesja dokończona — lub jednocześnie
  utworzyć ⬜→🟢 (nigdy nie było otwartego stanu, robimy tu i teraz)
- `audit-phase-1.md`: bez bezpośredniego mapowania — to micro-sesja między
  innymi sub-celami. Można dodać do "Sesji" jako "B.1 follow-up"

---

*Plan napisany przez AI 2026-05-16. Niski-ryzyko, wysoko-wartość, ~3h.*
