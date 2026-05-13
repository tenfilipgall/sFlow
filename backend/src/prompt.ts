import type { DiscoverRequest } from "./types";

export function buildSystemPrompt(): string {
  return `You are a macOS keyboard-shortcut expert. Given an app's bundle ID, menu bar dump, and UI skeleton, you produce a JSON list of keyboard shortcut rules in this exact schema:

{
  "rules": [
    {
      "match": { "role": "AXButton", "titles": ["English label", "Localized label"] },
      "keys": ["meta", "k"],
      "hint": "Quick Find",
      "confidence": "high" | "medium" | "low",
      "source": "menu_bar" | "web_docs_official" | "web_docs_third_party" | "inferred_pattern"
    }
  ]
}

Rules:
- "keys" must use these tokens only: meta, shift, alt, ctrl, plus a single letter/digit or a named key (enter, escape, space, tab, up, down, left, right, delete, backspace, f1..f12, /, ?, [, ]).
- "titles" should include the English label first, and add common localizations only when you are confident (e.g. for major apps in pl/de/fr/es).
- Confidence rules:
  - "high" iff source is "menu_bar" (you saw the shortcut in the dumped menu bar) OR "web_docs_official" (you found it on the app's own published docs).
  - "medium" iff source is "web_docs_third_party" (cheatsheets, forums, blogs).
  - "low" iff source is "inferred_pattern" (you guessed from similar apps; not directly verified).
- Do not invent shortcuts. If you cannot find evidence for a shortcut, omit the rule.
- Cover the most-used 20-60 actions. Don't dump every keystroke ever — focus on what a user is likely to click.
- The "title" in a rule must match what would appear in kAXTitleAttribute or kAXDescriptionAttribute of the clickable element — not a verbose menu path.
- Output JSON only, no prose.`;
}

export function buildUserPrompt(req: DiscoverRequest): string {
  const menuLines = req.menuBar
    .map((m) => `  ${m.path.join(" > ")}${m.shortcut ? ` [${m.shortcut}]` : ""}`)
    .join("\n");
  const skeletonLines = req.uiSkeleton
    .map((s) => `  ${s.role}: "${s.title}"`)
    .join("\n");
  return `App: ${req.appName} (${req.bundleId} v${req.appVersion})

Menu bar:
${menuLines || "  (empty)"}

UI skeleton (interactive elements):
${skeletonLines || "  (empty)"}

Generate the JSON rule list. Use the web_search tool to verify shortcuts that are not visible in the menu bar (e.g. hidden shortcuts like Slack ⌘K). Always favor shortcuts from the menu bar as "high" confidence with source "menu_bar".`;
}
