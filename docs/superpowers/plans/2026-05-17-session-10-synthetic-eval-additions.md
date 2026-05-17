# Plan additions — Sesja 10: Synthetic Claude self-eval (P-33)

> **Status:** uzupełnienie istniejącego `2026-05-15-synthetic-self-eval.md`.
> Dodaje konkretne prompts, scoring rubric, integration z RuleCache.
>
> **Adresuje:** Sub-cel 1.13, P-33.

---

## 1. Recap problem

Auto-discovery przez Claude zwraca reguły. Manual eval (Filip + 5 osób)
nie skaluje na 100+ apek. Potrzebujemy **automatic quality eval per rule**.

## 2. Synthetic self-eval pipeline

```
backend `/v1/discover` flow:
  1. Generate rules (existing)
  2. NEW: for each rule, call Claude self-eval (parallel, max 10 concurrent)
  3. Annotate rule.qualityScore + rule.qualityReason
  4. Filter: score < 3 → rule.confidence = "low" (will be filtered by client)
```

## 3. Eval prompt

```
You are reviewing a keyboard-shortcut rule that another AI generated. Score
the rule on a 1-5 scale based on TWO criteria:

A. Plausibility: Does this shortcut actually exist in this app?
B. Specificity: Does the rule's titles array uniquely identify ONE UI
   element, not multiple?

App: {appName} ({bundleId} v{appVersion})
Rule:
  Match: { role: "{role}", titles: {titles}, identifiers: {identifiers} }
  Keys: {keys}
  Hint: {hint}
  Source: {source}

Scoring:
  5 — Plausible AND specific. Shortcut documented officially OR matches
      menu_bar source from the same app version. Titles describe exactly
      ONE button.
  4 — Plausible AND mostly specific. Some title variants might be too generic
      ("settings" could match multiple settings buttons).
  3 — Plausible but specificity unclear. Cheatsheet source, no official docs.
  2 — Implausible OR misleading. Shortcut might exist for a different action.
  1 — Definitely wrong. Shortcut doesn't exist OR will trigger destructive
      action by mistake.

If score < 5, suggest correction:
  alternativeKeys: what the correct shortcut actually is
  alternativeHint: better hint text
  reason: 1-sentence why score < 5

Output JSON only:
{
  "score": 1-5,
  "alternativeKeys": [...] | null,
  "alternativeHint": "..." | null,
  "reason": "..." | null
}
```

## 4. Schema extension

`backend/src/types.ts`:

```typescript
const RuleSchema = z.object({
  // ... existing fields
  qualityScore: z.number().int().min(1).max(5).optional(),
  qualityReason: z.string().optional(),
});
```

## 5. Cost analysis

- Each eval ≈ 200 tokens input + 100 tokens output
- Claude Sonnet pricing: ~$0.0003 per eval
- Average app: ~40 rules
- Cost per app: ~$0.012 (vs $0.05 for initial gen → eval is 24% overhead)
- 1000 apps total: ~$12

**Acceptable.** No major financial constraint.

## 6. RuleCache integration

```swift
// In RuleCache.match
if !showExperimental {
    if let score = rule.qualityScore, score < 3 { continue }  // filter low quality
}
```

## 7. Telemetry loop

Post-launch:
- User cmd-clicks toast (false-positive feedback, P-4 done)
- false_positive event includes ruleId
- Aggregate: ruleId with ≥5 false-positives across users → flag for re-eval
- Re-eval cycle: call self-eval again with extra context ("user reports this
  shortcut is wrong"). Often score drops 5→2, filter triggers.

## 8. Acceptance criteria

- [ ] Backend `/v1/discover` runs self-eval per rule
- [ ] Average eval latency adds <30s to `/v1/discover` (parallelism 10×)
- [ ] Manual eval: 5 reseed apks → spot-check 10 random rules per app →
      synthetic score matches manual judgment ≥80%
- [ ] Quality gate in RuleCache filters score < 3 (default)
- [ ] Settings toggle "Show experimental shortcuts" disables filter
- [ ] 50/50 backend tests passing post-add

## 9. Statusy

- `audit-phase-0.md`: P-33 ⬜ → 🟢
- `audit-phase-1.md`: Sub-cel 1.13 → 🟢

---

*Plan additions 2026-05-17 offline. Łączy z istniejącym 2026-05-15-synthetic-self-eval.md.*
