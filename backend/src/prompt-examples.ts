// backend/src/prompt-examples.ts
//
// Few-shot examples used by buildSystemPrompt(). Each pair shows:
//   1. A small AX skeleton fragment Claude might encounter.
//   2. The ideal rule that would match clicks anywhere in that fragment.
// The "titles" arrays demonstrate the 3-5 variant requirement.

export const FEW_SHOT_EXAMPLES: string = [
  'Example 1 — Slack:',
  'Skeleton fragment:',
  '  AXButton: "Jump to channel or person"',
  '  AXButton: "compose new message"',
  'Ideal rules:',
  '{',
  '  "match": { "role": "AXButton", "titles": ["Jump to", "Jump to channel or person", "Quick Switcher", "channel switcher", "open quick switcher"] },',
  '  "keys": ["meta", "k"], "hint": "Quick Switcher", "confidence": "high", "source": "menu_bar", "version": 1',
  '}',
  '{',
  '  "match": { "role": "AXButton", "titles": ["Compose", "New message", "Compose new message", "compose button"] },',
  '  "keys": ["meta", "n"], "hint": "New message", "confidence": "high", "source": "menu_bar", "version": 1',
  '}',
  '  AXMenuItem: "Edit message E"',
  'Ideal rule:',
  '{',
  '  "match": { "role": "AXMenuItem", "titles": ["Edit message", "Edit message E", "edit message", "Edit this message"] },',
  '  "keys": ["e"], "hint": "Edit message", "confidence": "high", "source": "menu_bar", "version": 1',
  '}',
  '',
  'Example 2 — Obsidian:',
  'Skeleton fragment:',
  '  AXButton: "open quick switcher"',
  '  AXButton: "New note"',
  'Ideal rules:',
  '{',
  '  "match": { "role": "AXButton", "titles": ["Quick Switcher", "Open Quick Switcher", "open quick switcher", "switcher", "quick switcher button"] },',
  '  "keys": ["meta", "o"], "hint": "Quick Switcher", "confidence": "high", "source": "menu_bar", "version": 1',
  '}',
  '{',
  '  "match": { "role": "AXButton", "titles": ["New note", "Create note", "new note button", "create new note"] },',
  '  "keys": ["meta", "n"], "hint": "New note", "confidence": "high", "source": "menu_bar", "version": 1',
  '}',
  '',
  'Example 3 — Generic verb/noun variants:',
  'A button labelled "Open Settings" should match titles: ["Settings", "Open Settings", "settings button", "Preferences"].',
  'A button labelled "Save" should match titles: ["Save", "Save document", "save button"].',
].join('\n');
