# SFlow Video Eval — LLM analysis

- Generated: `2026-05-15T14:51:04Z`
- Frames dir: `/tmp/sflow_video_eval_20260515T164056`
- Frames analyzed: **32** (interval 1.0s, ~32.0s of video)
- Model: `claude-haiku-4-5-20251001`
- Toast visible in: **5** frames (15%)
- Native tooltip visible in: **2** frames
- Errors: 0

## Toast hits summary (most frequent first)

| Count | App | Action | Keys |
|---|---|---|---|
| 2 | Xcode | Quick Switcher | `⌘K` |
| 1 | Slack | Remind me | `?` |
| 1 | Slack | Copy link | `L` |
| 1 | Slack | Mark unread | `U` |

## Native tooltip hits

| Count | App | Tooltip |
|---|---|---|
| 1 | Slack | Meet Real-time meetings by Google. Using your browser, share your video, desktop, and presentations with teammates and customers. |
| 1 | Google Chat | meet.google.com Meet Real-time meetings by Google. Using your browser, share your video, desktop, and presentations with teammates and customers. |

## Timeline (consecutive identical states collapsed)

| Start | End | Frames | App | Toast | Cursor | Tooltip |
|---|---|---|---|---|---|---|
| 0:00.00 | 0:00.00 | 0 | Slack | — | Text input field in message composer | — |
| 0:01.00 | 0:06.00 | 1-6 | Slack | — | — | — |
| 0:07.00 | 0:07.00 | 7 | Google Chat | — | Google Meet link preview | meet.google.com Meet Real-time meetings by Google. Using your browser, share your video, desktop, and presentations with teammates and customers. |
| 0:08.00 | 0:08.00 | 8 | Google Chat | — | More actions menu or settings icon | — |
| 0:09.00 | 0:09.00 | 9 | Slack | — | Edit message button | — |
| 0:10.00 | 0:10.00 | 10 | Google Chat | — | Cancel button | — |
| 0:11.00 | 0:11.00 | 11 | Slack | — | Google Meet link preview | Meet Real-time meetings by Google. Using your browser, share your video, desktop, and presentations with teammates and customers. |
| 0:12.00 | 0:12.00 | 12 | Slack | **Remind me** `?` | Remind me menu item | — |
| 0:13.00 | 0:13.00 | 13 | Slack | — | — | — |
| 0:14.00 | 0:14.00 | 14 | Slack | **Mark unread** `U` | Mark unread button | — |
| 0:15.00 | 0:15.00 | 15 | Slack | **Copy link** `L` | Copy link menu item | — |
| 0:16.00 | 0:17.00 | 16-17 | Slack | — | — | — |
| 0:18.00 | 0:18.00 | 18 | Slack | — | More options menu button | — |
| 0:19.00 | 0:21.00 | 19-21 | Slack | — | — | — |
| 0:22.00 | 0:22.00 | 22 | Slack | — | Search bar | — |
| 0:23.00 | 0:23.00 | 23 | Slack | — | Text input field in message composer | — |
| 0:24.00 | 0:24.00 | 24 | Slack | — | Search box | — |
| 0:25.00 | 0:25.00 | 25 | Xcode | **Quick Switcher** `⌘K` | Quick Switcher button | — |
| 0:26.00 | 0:26.00 | 26 | Xcode | **Quick Switcher** `⌘K` | — | — |
| 0:27.00 | 0:27.00 | 27 | Slack | — | Search input field | — |
| 0:28.00 | 0:28.00 | 28 | Slack | — | Sidebar toggle or menu area | — |
| 0:29.00 | 0:31.00 | 29-31 | Slack | — | — | — |

## Next steps (suggested workflow)

1. Open this report side-by-side with `SFlow/Resources/bundled.json` and `cache/*.json`.
2. For each **toast hit** in the summary, find the matching rule in bundled. Confirm keys agree.
3. For each **native tooltip** with shortcut keys, check whether SFlow ever fired a toast for the same cursorAction. If not — that's a coverage hole; consider seeding/refreshing the app.
4. If toast keys disagree with bundled/tooltip — that's a wrong-toast; log as a regression and pick the offending app for re-seed (`./scripts/sflow-reseed <bundleId>`).
5. Append findings to `docs/coverage-report.md` (per-app row) and to the next session log entry.
