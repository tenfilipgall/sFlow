# SFlow Video Eval — LLM analysis

- Generated: `2026-05-18T05:29:02Z`
- Frames dir: `/tmp/sflow_video_eval_20260515T164056`
- Frames analyzed: **32** (interval 1.0s, ~32.0s of video)
- Model: `claude-haiku-4-5-20251001`
- Toast visible in: **1** frames (3%)
- Native tooltip visible in: **3** frames
- Errors: 0

## Toast hits summary (most frequent first)

| Count | App | Action | Keys |
|---|---|---|---|
| 1 | Xcode | Quick Switcher | `⌘K` |

## Native tooltip hits

| Count | App | Tooltip |
|---|---|---|
| 1 | Slack | meet.google.com Meet Real-time meetings by Google. Using your browser, share your video, desktop, and presentations with teammates and customers. |
| 1 | Slack | Meet Real-time meetings by Google. Using your browser, share your video, desktop, and presentations with teammates and customers. |
| 1 | Xcode | ⌘K Quick Switcher |

## Timeline (consecutive identical states collapsed)

| Start | End | Frames | App | Toast | Cursor | Tooltip |
|---|---|---|---|---|---|---|
| 0:00.00 | 0:04.00 | 0-4 | Slack | — | — | — |
| 0:05.00 | 0:05.00 | 5 | Slack | — | Send message button | — |
| 0:06.00 | 0:06.00 | 6 | Slack | — | — | — |
| 0:07.00 | 0:07.00 | 7 | Slack | — | Google Meet link preview | meet.google.com Meet Real-time meetings by Google. Using your browser, share your video, desktop, and presentations with teammates and customers. |
| 0:08.00 | 0:08.00 | 8 | Slack | — | More actions menu button | — |
| 0:09.00 | 0:09.00 | 9 | Slack | — | Edit message button | — |
| 0:10.00 | 0:10.00 | 10 | Slack | — | Cancel button | — |
| 0:11.00 | 0:11.00 | 11 | Slack | — | Google Meet link preview | Meet Real-time meetings by Google. Using your browser, share your video, desktop, and presentations with teammates and customers. |
| 0:12.00 | 0:12.00 | 12 | Slack | — | Remind me option in context menu | — |
| 0:13.00 | 0:13.00 | 13 | Slack | — | More actions menu button | — |
| 0:14.00 | 0:14.00 | 14 | Slack | — | Mark unread menu item | — |
| 0:15.00 | 0:15.00 | 15 | Slack | — | Copy link menu item | — |
| 0:16.00 | 0:17.00 | 16-17 | Slack | — | — | — |
| 0:18.00 | 0:18.00 | 18 | Slack | — | More options menu button | — |
| 0:19.00 | 0:19.00 | 19 | Slack | — | — | — |
| 0:20.00 | 0:20.00 | 20 | HubSpot | — | Message compose area | — |
| 0:21.00 | 0:21.00 | 21 | Slack | — | — | — |
| 0:22.00 | 0:22.00 | 22 | Slack | — | Search bar | — |
| 0:23.00 | 0:23.00 | 23 | Slack | — | — | — |
| 0:24.00 | 0:24.00 | 24 | Slack | — | Search field | — |
| 0:25.00 | 0:25.00 | 25 | Xcode | **Quick Switcher** `⌘K` | Quick Switcher button | — |
| 0:26.00 | 0:26.00 | 26 | Xcode | — | — | ⌘K Quick Switcher |
| 0:27.00 | 0:27.00 | 27 | Slack | — | Search field | — |
| 0:28.00 | 0:28.00 | 28 | Slack | — | Sidebar icon | — |
| 0:29.00 | 0:31.00 | 29-31 | Slack | — | — | — |

## Next steps (suggested workflow)

1. Open this report side-by-side with `SFlow/Resources/bundled.json` and `cache/*.json`.
2. For each **toast hit** in the summary, find the matching rule in bundled. Confirm keys agree.
3. For each **native tooltip** with shortcut keys, check whether SFlow ever fired a toast for the same cursorAction. If not — that's a coverage hole; consider seeding/refreshing the app.
4. If toast keys disagree with bundled/tooltip — that's a wrong-toast; log as a regression and pick the offending app for re-seed (`./scripts/sflow-reseed <bundleId>`).
5. Append findings to `docs/coverage-report.md` (per-app row) and to the next session log entry.

---

## Verification result — Sub-cel 1.8 (Droga B / `--llm` flag) ✅

**Cel weryfikacji (2026-05-18):** Sprawdzić że prompt v2 (z explicit negacjami "context menu / command palette / menu bar dropdown / native tooltip / help overlay") eliminuje 4 halucynowane toasty obserwowane w iteracji v1.

**Iteracja v1 (poprzednio):** 4 toast hits — wszystkie z Slack context menu items:
- "Remind me ?" → ❌ halucynacja (to context menu, nie toast SFlow)
- "Mark unread U" → ❌ halucynacja
- "Copy link L" → ❌ halucynacja
- "Quick Switcher ⌘K" → ❌ halucynacja (to było natywne menu Slacka, nie SFlow)

**Iteracja v2 (dziś):** **1 toast hit** — autentyczny:
- Frame 25, Xcode "Quick Switcher" ⌘K → ✅ poprawnie zidentyfikowany jako toast SFlow

**Konfrontacja z menu items:** Claude Haiku 4.5 w iteracji v2 **poprawnie** sklasyfikował wszystkie 3 Slack context menu items jako menu (Toast: —, Cursor: "Remind me option in context menu" / "Mark unread menu item" / "Copy link menu item"), nie jako toast SFlow.

**Wniosek:** Prompt v2 z ścisłą definicją "standalone overlay outside any menu" + 5 negacjami i bias false-negative > false-positive **działa**. Sub-cel 1.8 → 🟢 done.

**Bonus finding (low prio):** Frame 26 — Xcode renderuje swój własny natywny tooltip "⌘K Quick Switcher" zaraz po toaście SFlow z frame 25. Wzorzec: SFlow toast może overlapować się z natywnymi tooltipami niektórych apek (Xcode hover). Decyzja co z tym: zapisać w `docs/coverage-report.md` jako potencjalne UX consideration dla Fazy 2 (np. detect native tooltip i skip nasz toast), niska prio.

**Coverage gap finding:** Frame 22/24/27 — kursor na Slack Search bar/field, ale brak toasta. Slack ⌘K Quick Switcher istnieje w bundled.json (Slack reguły). Możliwy gap w detekcji L0.5 dla Search bar AX element. Plus do listy „missy do follow-upu" dla coverage iteration post-Beta.
