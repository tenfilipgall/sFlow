# Plan — Sesja U-5: i18n / lokalizacja reguł (Sub-cel 1.20 / P-43)

> **Status:** DRAFT, ~6-10h. Obejmuje też **Robotę 2** (backend prompt v2
> dla locale-aware research).
>
> **Adresuje:** Sub-cel 1.20 (audit-phase-1.5.md), P-43 (audit-phase-0.md),
> G-3 z `universality-gaps-and-windows-2026-05-16.md`.
>
> **Pre-requisite:** U-1 (B.1) + ideally U-4 (web-as-app) for web rule
> lokalizacja. Można zrobić wcześniej, ale efektywność spadnie.

---

## 1. Problem

Slack PL renderuje "Skomponuj wiadomość" zamiast "Compose". Reguła
`desc:"compose"` matchuje case-insensitive **literalny string** — fail w PL.

**Skala problemu:**
- ~10% non-EN userów na świecie (PL/DE/FR/ES/IT/PT/JP/ZH/KR)
- Backend prompt mówi Claude'owi "include localizations only when confident"
- Empirycznie — bundled.json po reseedzie generuje ~80% reguł EN-only

**Konsekwencja:** non-EN user widzi tylko menu bar (L3) skróty. L0.5/L1
window elements pomijane.

---

## 2. Rozwiązanie — 3 warstwowe

### Warstwa A: Detekcja locale apki (~2h)

W `ClickWatcher.handleMouseDown`, po `AXManualAccessibility`:

```swift
// Read app locale — empirically AXLanguage may be on AXApplication root or on focused window
var langRef: AnyObject?
AXUIElementCopyAttributeValue(axApp, "AXLanguage" as CFString, &langRef)
let appLocale = (langRef as? String)?.lowercased() ?? preferredSystemLanguage()
```

**Fallback:** `AppleLocale` w `NSLocale.preferredLanguages.first` — to lokalizacja **systemu**, nie konkretnej apki, ale dobry default gdy apka nie eksponuje AXLanguage.

**Edge case:** Slack po angielsku na systemie po polsku → `AXLanguage="en"` (jeśli wystawia), `preferredLanguages="pl"` → user faktycznie używa angielskiego Slacka. Cache key musi rozróżniać.

**Cache key extension:** `cache/{bundleId}:{locale}.json` zamiast `cache/{bundleId}.json`. Bundled.json bez locale = fallback dla wszystkich.

### Warstwa B: Multi-locale rules schema (~2h)

Rozszerzenie `LoadedRule.match.titles` o opcjonalne lokalizacje:

```typescript
// backend/src/types.ts
const MatchSchema = z.object({
  role: z.string(),
  titles: z.array(z.string()),                    // EN, default
  localizedTitles: z.record(                       // per-locale alternatives
    z.string(),  // locale code "pl", "de", etc.
    z.array(z.string())
  ).optional(),
  identifiers: z.array(z.string()).optional(),
});
```

Przykład:
```json
{
  "role": "AXButton",
  "titles": ["compose", "new message"],
  "localizedTitles": {
    "pl": ["skomponuj", "nowa wiadomość"],
    "de": ["verfassen", "neue nachricht"],
    "fr": ["composer", "nouveau message"]
  }
}
```

**RuleCache.match update:** próbuje najpierw `localizedTitles[currentLocale]`, fallback do `titles` (EN).

### Warstwa C: Backend prompt v2 — locale-aware research (~3-4h)

**To jest Robota 2 z 5 robót bez kompa.** Patch `backend/src/prompt.ts`:

#### C.1. Sygnatura `DiscoverRequest`

W `backend/src/types.ts`:

```typescript
const DiscoverRequestSchema = z.object({
  bundleId: z.string(),
  appName: z.string(),
  appVersion: z.string().optional(),
  appLocale: z.string().optional(),  // NEW: "pl", "de", etc.
  menuBar: z.array(...),
  uiSkeleton: z.array(...),
  clientVersion: z.string().optional(),
});
```

#### C.2. System prompt — nowa sekcja LOCALIZATION

Dodać po sekcji "Rules" w `buildSystemPrompt()`:

```text
LOCALIZATION:
- If the user's app locale is non-English (provided as appLocale, e.g. "pl", "de", "fr"), include translations for the most common 60-80% of rules as the "localizedTitles" field on each rule's match.
- Localized titles must match the actual AX exposed strings in that locale — not literal translations. For example, Slack PL button is "Wyszukaj kanał" not "Wyszukaj Slack" (literal "Search Slack"). Use web_search to verify localized strings on official docs or community references for that locale.
- Prioritize locales: pl, de, fr, es, it, pt, ja, zh-Hans. For other locales, omit localizedTitles unless explicitly asked.
- Schema:
  "localizedTitles": {
    "pl": ["skomponuj", "nowa wiadomość"],
    "de": ["verfassen", "neue nachricht"]
  }
- If appLocale is "en" or missing, you may skip localizedTitles entirely — the titles array is treated as English by default.
```

#### C.3. User prompt — locale hint

Modify `buildUserPrompt` to include:

```typescript
const localeLine = req.appLocale && req.appLocale !== "en"
  ? `App locale: ${req.appLocale} — provide localizedTitles for primary 60-80% of rules in this locale.`
  : `App locale: en (default — localizedTitles optional).`;

return `App: ${req.appName} (${req.bundleId} v${req.appVersion})

${localeLine}

Menu bar:
${menuLines || "  (empty)"}

... reszta tak jak teraz
`;
```

#### C.4. Cache key extension w `backend/src/storage.ts`

```typescript
function cacheKey(bundleId: string, version: string, locale?: string): string {
  const v = majorMinor(version);
  const l = locale && locale !== "en" ? `:${locale}` : "";
  return `rules:${bundleId}:${v}${l}`;
}
```

Backward compat: brak locale = default EN = istniejące klucze działają.

---

## 3. Test-driven kroki

### 3.1. Client side

**Nowy plik:** `SFlow/LocaleDetector.swift` (~50 LOC):

```swift
enum LocaleDetector {
    static func detect(for axApp: AXUIElement) -> String {
        // Try AXLanguage from app
        var langRef: AnyObject?
        AXUIElementCopyAttributeValue(axApp, "AXLanguage" as CFString, &langRef)
        if let lang = langRef as? String, !lang.isEmpty {
            return normalize(lang)
        }
        // Fallback to system preferred language
        return systemLocale()
    }

    static func normalize(_ raw: String) -> String {
        // "en-US" → "en", "pl-PL" → "pl", "zh-Hans" → "zh-Hans"
        // Keep complex codes for CJK (zh-Hans vs zh-Hant matters)
        let lc = raw.lowercased()
        let parts = lc.split(separator: "-")
        if parts.count >= 2 && (lc.contains("zh") || lc.contains("yue")) {
            return raw  // keep zh-Hans / zh-Hant as-is
        }
        return String(parts.first ?? Substring(lc))
    }

    static func systemLocale() -> String {
        normalize(Locale.preferredLanguages.first ?? "en")
    }
}
```

**Tests:** `SFlowTests/LocaleDetectorTests.swift` (~6 testów):
- `normalize("en-US")` → "en"
- `normalize("pl-PL")` → "pl"
- `normalize("zh-Hans-CN")` → "zh-Hans"
- `normalize("zh-Hant-TW")` → "zh-Hant"
- `normalize("EN")` → "en"
- `normalize("")` → "" (caller handles fallback)

### 3.2. LoadedRule schema

W `SFlow/LoadedRule.swift` dodać `localizedTitles`:

```swift
struct LoadedMatch: Codable {
    let role: String
    let titles: [String]
    let localizedTitles: [String: [String]]?   // NEW
    let identifiers: [String]?
}
```

### 3.3. RuleCache.match locale-aware

```swift
func match(bundleId: String, locale: String, role: String, title: String, ...) -> MatchResult? {
    // ... existing logic ...
    for rule in rules {
        // First try localized titles for the active locale
        if let local = rule.match.localizedTitles?[locale], !local.isEmpty {
            if local.contains(where: { wordBoundaryContains(title, $0) }) {
                return MatchResult(rule: rule)
            }
        }
        // Fallback to EN titles
        if rule.match.titles.contains(where: { wordBoundaryContains(title, $0) }) {
            return MatchResult(rule: rule)
        }
    }
    return nil
}
```

**Test cases** w `RuleCacheTests.swift`:
- Rule has `titles: ["compose"]` + `localizedTitles: {"pl": ["skomponuj"]}`.
  Click in Slack PL with title="Skomponuj" + locale="pl" → matches via PL.
- Same rule, click with title="Compose" + locale="en" → matches via EN.
- Same rule, click with title="Skomponuj" + locale="en" → matches via PL
  fallback (loose mode). Sub-decision: czy locale="en" próbuje też PL? **NIE** —
  to wprowadza false-positives. Tylko aktywny locale.

### 3.4. ClickWatcher integration

Cache `appLocale` per click. Pass do `ruleCache.match(locale: appLocale, ...)`.

### 3.5. DiscoveryClient extension

W `SFlow/DiscoveryClient.swift` dodać `appLocale` do body POST `/v1/discover`.

### 3.6. Backend tests

W `backend/tests/prompt.test.ts`:
- `buildUserPrompt(req with appLocale="pl")` → output zawiera "App locale: pl"
- `buildUserPrompt(req without appLocale)` → "App locale: en (default — ...)"

### 3.7. Cache key tests

W `backend/tests/storage.test.ts`:
- `cacheKey("slack", "1.2", "pl")` → `"rules:slack:1.2:pl"`
- `cacheKey("slack", "1.2", undefined)` → `"rules:slack:1.2"`
- `cacheKey("slack", "1.2", "en")` → `"rules:slack:1.2"` (en = default, no suffix)

---

## 4. Acceptance criteria

- [ ] `LocaleDetector` + 6 testów
- [ ] `LoadedMatch.localizedTitles` schema extension, backward-compat
- [ ] `RuleCache.match` locale-aware z testami
- [ ] Backend `DiscoverRequest.appLocale` opcjonalny
- [ ] Backend prompt v2 zawiera sekcję LOCALIZATION
- [ ] Cache key per locale
- [ ] Manual eval: reseed Slack PL z `appLocale="pl"` → wygenerowane reguły
      mają `localizedTitles.pl`
- [ ] Manual test: użytkownik z systemem PL klika "Wyszukaj kanał" w Slack PL
      → toast pokazuje ⌘K (matching przez `localizedTitles.pl`)
- [ ] Backend tests (50+) passing po dodaniu nowych
- [ ] Client testy 290+ passing

---

## 5. Plik manifest

**Nowe pliki:**
- `SFlow/LocaleDetector.swift`
- `SFlowTests/LocaleDetectorTests.swift`

**Zmienione pliki:**
- `SFlow/LoadedRule.swift` — `localizedTitles` field
- `SFlow/RuleCache.swift` — `match(locale:...)` signature
- `SFlow/ClickWatcher.swift` — przekazuje locale do RuleCache
- `SFlow/DiscoveryClient.swift` — `appLocale` w POST body
- `backend/src/types.ts` — `DiscoverRequestSchema.appLocale`, `MatchSchema.localizedTitles`
- `backend/src/prompt.ts` — sekcja LOCALIZATION + user prompt locale line
- `backend/src/storage.ts` — `cacheKey(...locale)`
- `backend/src/handlers/discover.ts` — przekazuje locale do cacheKey
- `backend/tests/prompt.test.ts` — 2 nowe testy
- `backend/tests/storage.test.ts` — 3 nowe testy
- (po reseedzie) `bundled/com.tinyspeck.slackmacgap.json` itp. — dodać
  `localizedTitles` dla top apek

---

## 6. Reseed strategy

Po deployu backendu, reseed apek z aktywnymi locale userami:

1. Filip ma system PL → reseed wszystkich bundled apek z `appLocale="pl"`
   → otrzymuje reguły z `localizedTitles.pl`
2. Merge do `bundled/*.json` (te same pliki, tylko z dodanym
   localizedTitles dla PL)
3. Inne locale (DE, FR, ...) — czekamy aż user beta test je dorzuci
   organicznie z systemu

---

## 7. Ryzyka

### Ryzyko 1: AXLanguage nie istnieje na większości apek

**Diagnoza:** atrybut `AXLanguage` jest formalnie dostępny w macOS AX API,
ale często nieustawiany przez apki.

**Mitigacja:** fallback do `Locale.preferredLanguages.first` jest zawsze
działa. System locale prawie zawsze pokrywa się z app locale dla typowego
usera.

### Ryzyko 2: Claude wygeneruje słabe tłumaczenia

**Diagnoza:** dla niszowych apek, oficjalne docs po PL/DE mogą nie istnieć.
Claude może zgadnąć, generując **literalne tłumaczenie** ("Quick Find" →
"Szybkie Znajdź") zamiast faktycznego label-a w apce ("Szukaj pełnotekstowo").

**Mitigacja:** prompt wymusza "actual AX exposed strings, not literal
translation" + ranking source: `web_docs_official` > `web_docs_third_party`.
Plus quality gate w RuleCache odrzuca `confidence=low`.

### Ryzyko 3: Mieszane apki (UI angielski, treść PL)

**Diagnoza:** Slack UI po angielsku **ale** treść wiadomości po polsku.
SFlow `appLocale="pl"` (z system), reguły PL ale UI EN — fail.

**Mitigacja:** **AXLanguage z apki** (gdy dostępne) > system locale. Plus
fallback z PL na EN w `RuleCache.match` — jeśli PL nie matchuje, próbujemy
EN.

### Ryzyko 4: Cache invalidation

Reguły wygenerowane dla `appLocale="en"` w cache → user zmienia system na PL
→ użycie EN cache zamiast PL fresh. Confusing.

**Mitigacja:** cache key per locale (sekcja 2.C.4) rozwiązuje to. Każdy
locale ma własną entry w KV.

---

## 8. Statusy po sesji

- `audit-phase-0.md`: P-43 ⬜ → 🟢
- `audit-phase-1.5.md`: Sub-cel 1.20 ⬜ → 🟢, sesja U-5 → 🟢
- `roadmap.md`: Session log

---

*Plan napisany przez AI 2026-05-16 (offline). Obejmuje Robotę 2 (backend
prompt v2) jako sekcję 2.C. Backend tests napisane wprost, deploy wymaga
explicit yes Filipa.*
