# SFlow Cloud LLM Rule Engine — Design Spec

**Status:** Approved by user via brainstorming session 2026-05-11
**Author:** Filip + Claude (Opus 4.7)
**Supersedes parts of:** `docs/layer-1-5-design-brief.md`, `docs/deep-think-auto-discovery.md`

---

## 1. Problem

SFlow shows toast notifications with keyboard shortcuts when the user clicks a UI element in any macOS app. Today shortcuts come from hardcoded per-app rules in `ShortcutRules.swift` (Layer 1) + heuristics (Layers 2-4).

**Reality check after empirical testing:**
- Repo claims rules for 18 apps; only ~3-4 (Slack, Terminal, Notion, Claude Desktop) are realistically verified to work.
- Each verified app required hours of manual AX attribute inspection.
- Manual rule-writing does not scale beyond a handful of apps, and rules rot when apps change UI between versions.

**Goal:** SFlow must work for ~any app the user installs, without the developer hand-writing rules per app. Target product: sellable macOS utility (~$25 one-time, with optional Pro tier for privacy-focused users).

## 2. Strategic Choice

After evaluating four families of knowledge sources (manual rules, free signals from the app itself, crowdsourcing, LLM generation), we are committing to:

**Cloud LLM rule engine with per-app background discovery, globally shared cache, and a filtered privacy-preserving payload.**

Rationale:
- Per-app rule generation by Claude scales infinitely — no developer hours per app.
- Globally shared cache makes the economics trivial: each app is "discovered" once for the entire user base. Estimated total LLM cost across all popular apps: $10-50 one-time, plus $10-30/year for version refreshes.
- User is open to sending non-content metadata to a backend, in good faith. Privacy-sensitive users get a Pro tier with BYOK.

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  macOS App (SFlow)                                  │
│                                                     │
│  Local Rule Engine (load priority, high → low):     │
│    1. user_overrides.json     (user-edited)         │
│    2. cache/*.json            (LLM-generated, authoritative) │
│    3. bundled.json            (bootstrap for 4 verified apps) │
│    4. L1-L4 heuristics        (existing fallback)   │
│                                                     │
│  Discovery Trigger:                                  │
│    bundleId not in cache → collect AX skeleton +    │
│    menu bar dump → POST to backend                  │
└──────────────────────────┬──────────────────────────┘
                           │ HTTPS
                           ▼
┌─────────────────────────────────────────────────────┐
│  Backend: Cloudflare Worker + KV                    │
│    POST /v1/discover                                │
│      1. Check KV cache by {bundleId, appVersion}    │
│      2. Hit → return rules immediately              │
│      3. Miss → call Claude (Sonnet) with web_search │
│           tool, store result, return                │
│    POST /v1/feedback                                │
│      User-reported wrong rules (rate-limited)       │
└──────────────────────────┬──────────────────────────┘
                           │
                           ▼
              Anthropic API (Claude Sonnet)
```

Three principles:
- **Bundled-first, cloud-fallback** — app works offline at install for 4 verified apps; LLM kicks in for everything else.
- **Cache is global, public, anonymous** — no userId is stored with rules. One user's discovery serves all future users.
- **LLM-generated rules override bundled rules** — once `cache/com.tinyspeck.slackmacgap.json` exists, it takes precedence over `bundled.json`.

## 4. User-Facing Flow

**First install:**
1. Onboarding: grant Accessibility permission.
2. Bundled rules load → Slack, Terminal, Notion, Claude Desktop shortcuts work immediately.
3. All other apps fall back to L1-L4 heuristics until discovery runs.

**User opens an unknown app (e.g. Linear) for the first time:**
1. SFlow detects `bundleId = "com.linear.electron"` not in cache.
2. SFlow collects menu bar dump + filtered AX skeleton in the background.
3. SFlow POSTs to backend, shows subtle menu-bar indicator: `✨ Learning Linear...`.
4. Backend responds (typical: <1s on cache hit, 15-45s on cache miss while Claude works).
5. Rules saved to `~/Library/Application Support/SFlow/rules/cache/com.linear.electron.json`.
6. Indicator disappears. User clicks anything in Linear → toast shows correct shortcut.

**Offline:**
- Bundled rules + local cache continue working.
- New-app discovery silently queued; runs when network returns.

**Pro tier (BYOK):**
- Settings → "Anthropic API key" field, stored in macOS Keychain.
- If present, discovery routes through user's own key. Our backend sees nothing.
- Bundled rules and local cache still work as normal.

## 5. Backend API Contract

### `POST /v1/discover`

**Request:**
```json
{
  "bundleId": "com.linear.electron",
  "appName": "Linear",
  "appVersion": "1.42.0",
  "menuBar": [
    { "path": ["File", "New Issue"], "shortcut": "cmd+n" },
    { "path": ["Edit", "Find"], "shortcut": "cmd+f" }
  ],
  "uiSkeleton": [
    { "role": "AXButton", "title": "New issue" },
    { "role": "AXButton", "title": "Inbox" }
  ],
  "clientVersion": "1.0.0"
}
```

**Response (200):**
```json
{
  "bundleId": "com.linear.electron",
  "rulesVersion": "2026-05-11T10:00:00Z",
  "rules": [
    {
      "match": { "role": "AXButton", "titles": ["New issue", "Nowy issue"] },
      "keys": ["meta", "c"],
      "hint": "New Issue",
      "confidence": "high",
      "source": "menu_bar"
    }
  ]
}
```

**Cache key:** `rules:{bundleId}:{appVersion.major}.{appVersion.minor}`. Patch version ignored.

**Rate limiting:** Anonymous, per source IP, 10 new-app discoveries per hour. Cache hits unlimited.

### `POST /v1/feedback`

```json
{
  "bundleId": "com.linear.electron",
  "rulesVersion": "2026-05-11T10:00:00Z",
  "ruleIndex": 5,
  "reportType": "wrong_shortcut"
}
```

Aggregated server-side. If ≥5 unique IPs report the same rule as wrong within 30 days, the rule is auto-disabled globally and re-discovery is triggered with an updated prompt that mentions the false-positive history.

## 6. Privacy Model — The Filtered Skeleton

### What we send

For each new app discovery, the client sends:
1. **App identity:** `bundleId`, `appName`, `appVersion`
2. **Menu bar dump:** structural paths (`File > New Issue`) and shortcuts (`cmd+n`) — no user content lives here
3. **UI skeleton:** filtered list of interactive elements

### Skeleton filter rules (client-side, before sending)

Only include AX nodes where ALL of these hold:
- `role ∈ {AXButton, AXLink, AXMenuItem, AXCheckBox, AXRadioButton, AXPopUpButton}`
- `title` is non-empty, ≤ 50 chars
- `title` does not start with `#`, `@`, `https://`
- `title` does not match patterns: pure digits, email regex, "First Last" capitalized 2-word names, ISO dates
- `title` appears ≥ 2 times in the AX tree, OR matches a static UI pattern (verb-led, like "Send", "Archive", "New ...")

Exclude entirely:
- `AXTextField`, `AXTextArea`, `AXStaticText` — these contain user-typed content
- The `value` and `placeholder` attributes of any node
- Any node inside an `AXWindow` whose title contains likely-content keywords (e.g. "Inbox - filip@..." → drop window subtree)

### Bundle ID blacklist

For these apps, send menu bar only (no UI skeleton at all), because too much of their UI is content:
- `com.apple.mail`
- `com.apple.MobileSMS`
- `com.1password.1password`, `com.agilebits.onepassword*`
- `net.whatsapp.WhatsApp`
- `com.tinyspeck.slackmacgap` — Slack channel list contains content (`#channel-name`). Use menu bar + extra-strict skeleton (buttons/links only, must appear ≥3 times in tree). This applies both at user-runtime discovery and at developer-seed time (Section 9) — same code path.

### What we never send
- AX node `value` attributes
- AX node `description` if it's > 50 chars (likely a long sentence, not a UI label)
- Any text from focused text fields
- Window titles past the app name
- Screen recordings, screenshots, document contents
- User identity, account info, machine identifiers

### User-facing privacy copy
> "SFlow never sends your messages, channels, files, or anything you type. When you open an app for the first time, SFlow sends a list of public button names (like 'New message', 'Search') so we can fetch keyboard shortcuts for you. Pro users can route this through their own Anthropic API key for zero telemetry."

## 7. Confidence and Anti-Hallucination

Claude generates each rule with a `source` and `confidence`:

| Source | Confidence | Reason |
|---|---|---|
| `menu_bar` | high | App declared it in its own menu — ground truth |
| `web_docs_official` | high | Web search found it on the app's official docs |
| `web_docs_third_party` | medium | Found on cheatsheet site, forum, blog |
| `inferred_pattern` | low | Claude inferred from a similar app — not verified |

**Display policy:**
- Default: SFlow shows `high` + `medium`.
- `low` rules hidden behind Settings → "Show experimental shortcuts".

**Feedback loop:**
- Each toast has a tiny "wrong?" affordance (cmd-click on toast, or a corner ✗).
- Local override: stored in `user_overrides.json`.
- Anonymous report: POSTed to `/v1/feedback`, aggregated for global auto-disable.

## 8. Local Rule Storage

```
~/Library/Application Support/SFlow/rules/
├── bundled.json              # ships with the app
├── cache/
│   ├── com.linear.electron.json
│   ├── com.figma.Desktop.json
│   └── …
└── user_overrides.json       # user-edited
```

Per-file format:
```json
{
  "bundleId": "com.linear.electron",
  "appVersion": "1.42",
  "fetchedAt": "2026-05-11T10:00:00Z",
  "source": "cloud",
  "rules": [ /* see API response */ ]
}
```

**Bundled.json contents (ship-day):** only the 4 hand-verified apps — Slack, Terminal, Notion, Claude Desktop. All other rules are LLM-generated at user runtime.

**Cache invalidation:**
- On app version bump (major.minor change): trigger background re-discovery.
- Manual refresh in Settings → "Refetch shortcuts for this app".
- TTL: hard refresh after 90 days regardless.

## 9. Bundled Rules — Build-Time Generation

Bundled rules are NOT hand-written for the 4 apps — they are generated by the production backend, then frozen into the app at build time.

Build script (`scripts/seed-bundled.sh`):
1. For each of the 4 bundleIds, ensure the app is running on the developer's Mac.
2. SFlow in seeding mode dumps menu bar + skeleton.
3. Calls production `/v1/discover` (developer pays ~$0.05 per app × 4 = $0.20).
4. Writes `bundled.json` containing all 4 rule sets.
5. Committed to the repo as part of the release.

This ensures bundled = same code path as runtime, no drift.

## 10. Pro Tier (BYOK)

**Settings UI:**
- "Use my own Anthropic API key" toggle
- Key field (stored in macOS Keychain via `Security.framework`)
- "Disable all telemetry" toggle (separate)

**When enabled:**
- Discovery flow bypasses our backend entirely.
- The app constructs the same Claude request and calls Anthropic directly.
- Web search tool requires Claude Sonnet with tool use; cost on user's key is ~$0.05 per new app.

**Price proposal:** $10 surcharge on top of base $25, or included free as a "you bring your own infra" perk. Decide at launch.

## 11. Failure Modes and Fallbacks

| Failure | Behavior |
|---|---|
| No network | Local cache + bundled + L1-L4 heuristics. Discovery queued for retry. |
| Backend 5xx | Retry with exponential backoff, max 3 attempts, then give up for this session. |
| Backend returns malformed JSON | Drop, log, fall back to heuristics for this app. Surface in Settings → "Diagnostics". |
| Claude hallucinates `keys: ["meta", "x"]` for an app where ⌘X means something else | User-feedback loop catches it; ≥5 reports → auto-disable. Single-user can override locally. |
| App has no menu bar (rare Electron) | Skeleton-only request to Claude. Lower confidence overall. |
| App is electron with localized UI ("Wycisz" vs "Mute") | LLM-generated rule includes BOTH titles in the `titles` array (Claude is asked to consider localization). Matcher checks against all. |

## 12. Testing Strategy

- **Unit tests:** existing `ShortcutRulesTests.swift` continue to pass. New tests for: skeleton filter logic, response parser, cache loader priority order.
- **Integration tests:** mock backend serving fixture JSON responses; verify load order, override, and merge behavior.
- **E2E manual checklist:** for the 4 bundled apps, click 10 known elements each and verify toast accuracy.
- **Backend tests:** mock Anthropic API, verify caching, rate limiting, feedback aggregation.

## 13. Out of Scope (for v1)

- Crowdsourcing user-submitted rules (no v1; only auto-feedback "wrong" reports).
- Multi-device sync of `user_overrides.json` (later).
- Native-app deep AX scanning for non-Electron native macOS apps — existing L3 menu bar scan stays the L3 mechanism; LLM discovery applies the same skeleton+menu approach uniformly.
- Replacing L1-L4 entirely — they remain as last-resort fallback when no rule from any source matches.
- iOS / iPadOS support.

## 14. Risk Register

| Risk | Mitigation |
|---|---|
| LLM hallucinates wrong shortcuts → user learns wrong key | Confidence tiers (only show high+medium by default), feedback loop with global auto-disable threshold |
| Privacy leak via skeleton (some content slips through filter) | Conservative allowlist (only buttons/links), bundle ID blacklist for sensitive apps, dedup test, user-readable disclosure |
| Backend cost runs away | Globally shared cache (1 LLM call per unique app, not per user) — math shows total ongoing cost is <$50/yr at thousands of users |
| Anthropic API outage | Bundled rules + L1-L4 keep app useful for known apps; new-app discovery degrades gracefully |
| App version churn invalidates cache constantly | Cache by major.minor only, ignore patch versions; 90-day hard refresh |
| Localized app titles don't match English rules | Prompt Claude to include localized variants in `titles` array; expand matcher to check all entries |

## 15. Open Decisions (deferred to implementation)

- Exact wording of the Pro tier paywall.
- Precise CSS-like styling of the "Learning [App]..." indicator.
- Whether to add a "shared community" tier where rules contributed by users with BYOK keys are merged back into the global cache (would require additional consent flow).
- Whether to publish the backend source code openly to bolster the privacy story.
