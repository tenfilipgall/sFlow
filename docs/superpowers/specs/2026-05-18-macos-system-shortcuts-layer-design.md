# macOS System Shortcuts Layer (L0.7)

**Status:** approved, design ready for plan
**Date:** 2026-05-18
**Author:** SFlow team

## Problem

SFlow today only knows about shortcuts that appear in `bundled.json` per `bundleId`
(or in cache / user_overrides). Standard macOS-wide shortcuts (Cmd+M, Cmd+W, Cmd+Q,
Cmd+H, Cmd+,, Cmd+Z, Cmd+S, Cmd+F, etc.) must be redundantly entered for every app.

Worse, many surfaces that trigger these standard actions are **not** menu items
and therefore are not covered by the existing `.menuItem` layer that reads
`AXMenuItemCmdChar` directly:

- Window chrome traffic lights (red/yellow/green) — close / minimize / zoom
- Toolbar buttons named "Minimize", "Close", "Save", "Print", etc.
- Custom in-app buttons that wrap a standard AppKit action

## Goal

Add a **parallel** recognition layer for standard macOS shortcuts that:

1. Lives **alongside** existing per-app rules — never replaces or mutates them.
2. Only fires when no per-app rule matched (app-specific wins).
3. Costs zero maintenance for the common case (live AX read).
4. Has a small, curated static fallback for non-menu surfaces (traffic lights +
   common toolbar names) with EN+PL localization.

## Non-goals

- No changes to `bundled.json`, cache, or `user_overrides.json`.
- No new cloud-fetched rule source.
- No attempt to cover non-standard, app-specific shortcuts that happen to look
  standard (those keep going through per-app rules).
- No regression in existing layers (L0 / L0.5 / L0.6 / L1..L4 / menuItem).

## Architecture — layered, side-by-side

```
              ┌──────────────────────────────────────┐
ClickWatcher  │  L0 AXKeyShortcuts                   │
              │  L0.3 Tooltip                        │
              │  L0.5 RuleCache.match (per-app)      │  ← per app, untouched
              │  L0.6 Inline children                │
   NEW →      │  L0.7 SystemShortcuts (this spec)    │  ← parallel, app-agnostic
              │  L1..L4 …                            │
              │  menuItem (AXMenuItem direct read)   │
              └──────────────────────────────────────┘
```

The new layer **sits after** the per-app rule cache. The flow:

1. `RuleCache.match(bundleId:…)` runs as today.
2. If it returns a match → emit, done. (App wins.)
3. Else SFlow asks the new `SystemShortcuts` resolver.
4. If resolver returns a match → emit with layer `.systemShortcuts`.
5. Else fall through to existing later layers.

## Components

### 1. `SystemShortcuts.swift` (new)

A small resolver with two backends:

#### Backend A — AX-subrole shortcut

Looks at `kAXSubroleAttribute` of the clicked element. macOS marks window-chrome
buttons explicitly:

| Subrole                | Action            | Shortcut    |
| ---------------------- | ----------------- | ----------- |
| `AXCloseButton`        | Close window      | ⌘W          |
| `AXMinimizeButton`     | Minimize          | ⌘M          |
| `AXZoomButton`         | Zoom              | (no key)    |
| `AXFullScreenButton`   | Toggle fullscreen | ⌃⌘F         |

Zero locale work — subroles are stable across languages.

#### Backend B — Title-based lookup (`Resources/macosSystemShortcuts.json`)

Static JSON with one entry per shortcut, each entry listing English + Polish
titles. Reuses the existing `LoadedRule` / title-match machinery for consistency.
Examples:

```json
[
  {
    "titles": ["Minimize", "Minimize Window"],
    "localizedTitles": { "pl": ["Minimalizuj", "Zminimalizuj"] },
    "keys": ["meta", "m"],
    "hint": "Minimize"
  },
  {
    "titles": ["Close Window", "Close", "Close Tab"],
    "localizedTitles": { "pl": ["Zamknij okno", "Zamknij", "Zamknij kartę"] },
    "keys": ["meta", "w"],
    "hint": "Close"
  },
  …
]
```

Initial coverage (~20 entries):

- File: New, Open, Close, Save, Save As, Print
- Edit: Undo, Redo, Cut, Copy, Paste, Select All, Find
- View: Enter Full Screen
- Window: Minimize, Zoom, Hide
- App: Preferences/Settings, Hide app, Hide Others, Quit

### 2. `RuleCache` integration

`RuleCache.load()` gains a second source — `macosSystemShortcuts.json` — loaded
into a **separate** array `systemRules: [LoadedRule]`. Per-app `rulesByBundle`
is **not** touched.

A new method:

```swift
func matchSystem(role: String, subrole: String,
                 title: String, desc: String, help: String,
                 identifier: String, roleDescription: String,
                 customActions: [String], locale: String) -> MatchResult?
```

Tries Backend A (subrole map, hard-coded constants) first, then Backend B
(title match against `systemRules` using existing `titleMatches` logic).

### 3. `ClickWatcher` wiring

After the existing `ruleCache.match(...)` fails (Layer 0.5) and before the
inline-shortcut path (Layer 0.6) is entered, call `ruleCache.matchSystem(...)`.
On match, emit with new layer enum case `.systemShortcuts` (raw value `L0.7`).

We deliberately place it *after* L0.5 (per-app wins) and *before* L0.6 so that a
clear standard action ("Close Window" button in a Notion-style sidebar) beats an
inline-text false-positive.

### 4. `RecognitionLayer`

Add:

```swift
case systemShortcuts = "L0.7"  // macOS standard shortcuts (subrole + universal titles)
```

## Resource bundling

Add `Resources/macosSystemShortcuts.json` to the app target via `project.yml`
(SFlow already drives Xcode via xcodegen — `project.yml` is the source of truth).
`RuleStorage.seedBundledIfMissing()` is untouched; this file is read straight
from the bundle every launch (never written to Application Support).

## Telemetry & UAT

- `events.jsonl` will show layer `L0.7` for new matches — easy to count.
- Manual UAT after build:
  - Click red traffic-light button on any window → toast `⌘W Close`.
  - Click yellow traffic-light → toast `⌘M Minimize`.
  - Click "Save" toolbar button in a TextEdit/Notes window → toast `⌘S Save`.
  - Click "Preferences…" in any app menu → existing L0.5 / menu still wins
    (verify per-app rule untouched).

## What's explicitly NOT changing

- `bundled.json` — not opened, not parsed differently, not extended.
- Cloud discovery / `cache/*.json` — unchanged.
- `user_overrides.json` — unchanged and still highest priority for per-app.
- Menu-bar direct click (`.menuItem` layer) — unchanged; still reads
  `AXMenuItemCmdChar` directly from the AX element.

## Risks & mitigations

- **False positive on generic word "Close"** in an app where Close ≠ Cmd+W
  (e.g., a dialog "Close" button that triggers app-specific behavior). Mitigation:
  L0.5 (per-app) runs *first*, so any app that registers a rule for "Close" wins.
  Static list uses high-precision titles ("Close Window", "Close Tab") rather
  than the bare word where possible.
- **Subrole detection at depth > 0.** Backend A only runs at `depth == 0` (the
  hit-tested element) — traffic lights are always the direct hit target.
- **Locale drift.** Backend A is locale-agnostic. Backend B ships EN + PL only
  at v1; other locales fall through (acceptable — per-app rules already exist
  for the active beta surface).

## Rollout

Single PR. Behind no feature flag — additive layer that only fires when nothing
else does. Bumped JSON files ship in DMG; no schema migration.
