# KeystrokeWatcher — shortcut-only keyboard logging

**Status:** approved, design ready for plan
**Date:** 2026-05-18

## Problem & motivation

To enable future practice-drill features (and to learn from beta-tester
behaviour right now), SFlow needs to know **which keyboard shortcuts users
actually press** and on which UI element the focus was when they pressed them.

Today SFlow only sees mouse clicks. A user who clicks "Save" and a user who
hits `⌘S` look identical: invisible. We need the latter to be observable.

## Hard requirements

1. **Privacy floor — non-negotiable.** SFlow MUST NOT see anything a user types
   that isn't a shortcut. No keystrokes without a `Cmd` / `Ctrl` / `Option`
   modifier are read past the filter stage. Passwords, message contents,
   document text — all invisible.
2. **No extra OS permission prompts.** Reuse the existing Input Monitoring
   grant from `ClickWatcher`'s `CGEventTap`.
3. **No new storage location.** Append to the existing `events.jsonl` as a new
   `type: "keystroke"` entry so diagnostic export picks it up automatically.
4. **Toggleable.** UserDefaults key `recordKeystrokes`, default `true` (apka
   sprzedawana z practice drills wymaga tego on by default), surfaced in the
   Privacy tab of Settings.

## Architecture

```
                      ┌─────────────────────────────┐
CGEventTap            │   kCGEventKeyDown only      │
(separate from        │   tap.callback ──┐          │
 ClickWatcher's tap)  └───────────────────┼──────────┘
                                          ▼
                       ┌──────────────────────────────┐
                       │  KeystrokeWatcher.handle     │
                       │                              │
                       │  1. Read modifier flags      │
                       │     guard cmd|ctrl|opt set   │  ← HARD GATE
                       │     else { return; nothing   │
                       │     read or logged }         │
                       │                              │
                       │  2. Resolve key string from  │
                       │     event keycode (modifier  │
                       │     letters, arrows, F-keys) │
                       │                              │
                       │  3. AX read focused element  │
                       │     - kAXFocusedApplication  │
                       │     - kAXFocusedUIElement    │
                       │     redact via PrivacyFilter │
                       │                              │
                       │  4. EventLogger.logKeystroke │
                       └──────────────────────────────┘
```

The keyboard tap is **separate** from `ClickWatcher`'s mouse tap so a slow AX
read on one path can't disable the other. Both taps share the same permission.

## Privacy gate — exact behaviour

```swift
let flags = event.flags
let hasMeta  = flags.contains(.maskCommand)
let hasCtrl  = flags.contains(.maskControl)
let hasAlt   = flags.contains(.maskAlternate)
guard hasMeta || hasCtrl || hasAlt else { return }
```

`Shift` alone is NOT enough — `Shift+a` is just `A`. We require a "true"
modifier (Cmd/Ctrl/Opt) to consider the press a shortcut. Shift can be
*present* in addition (`⇧⌘N` etc.) — we record it then.

We also drop:

- Auto-repeat events (`event.getIntegerValueField(.keyboardEventAutorepeat) != 0`)
  — holding `⌘V` should not flood the log
- F-keys without modifier (`F1-F12` alone are volume / brightness)

## Logged shape

```jsonl
{"type":"keystroke","timestamp":"2026-05-18T11:25:33Z",
 "bundleId":"com.tinyspeck.slackmacgap",
 "keys":["meta","k"],
 "focusedRole":"AXTextField",
 "focusedTitle":"search",        // redacted via PrivacyFilter
 "focusedRoleDesc":"search field",
 "focusedIdentifier":"","windowTitle":"Slack — #general"}  // redacted
```

Fields are best-effort — when AX can't read the focused element (denied access
or none) the row still logs with `focusedRole: ""`. That's still useful for
"what shortcut was used in which app, when".

What we **never** log:
- Raw key event flags beyond the `keys` array
- `kAXValue` of the focused element (would contain typed text)
- Clipboard or selection contents

## Settings UI

Privacy tab gains one row:

```
☑ Record keyboard shortcuts you use (helps SFlow learn)
    Records only Cmd/Ctrl/Opt combinations. Never plain typing,
    text, or passwords. Stored locally in events.jsonl.
```

Default ON. Flipping it off disables the tap (resource freed).

## AppDelegate wiring

`startWatcher()` instantiates a `KeystrokeWatcher` alongside `ClickWatcher` when
`recordKeystrokes` is true and Input Monitoring is granted. The watcher honours
runtime toggling via `UserDefaults.didChangeNotification` (same notification
already wired for `silentMode` / `showExperimental`).

## What's explicitly out of scope

- Backend upload of keystrokes — separate PR if/when we add `/v1/keystrokes`
- Practice drills UI — this PR is purely the data layer
- Per-app on/off — global toggle is enough for now
- Correlation analyses (keystroke ↔ click on same element within Xs) — done in
  `Analyzer.swift` later, the data is enough

## Risks & mitigations

- **CGEventTap timeout under load.** Mirror ClickWatcher's health-check timer
  + tapDisabledByTimeout handler. AX reads must be capped.
- **Permission already granted but tap creation fails.** Log + retry-on-startup,
  match ClickWatcher's behaviour.
- **Non-Latin keyboards.** Use `event.charactersIgnoringModifiers` when
  available; fall back to `keycode → KeySymbols` mapping. UTF-8 letters are
  fine in `keys` array (e.g. `["meta","ł"]`).
- **Dead keys / IME composition.** macOS sends `kCGEventKeyDown` for the trigger
  key; SFlow records that and moves on. Composition state is not our concern.

## Rollout

Single PR. Default ON in beta. If users complain about logging, we flip the
default to OFF via a hotfix and surface the toggle more prominently in
onboarding.
