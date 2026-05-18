import { z } from "zod";

export const MenuBarItemSchema = z.object({
  path: z.array(z.string()).min(1).max(10),
  shortcut: z.string().nullable().optional(),
});

export const UISkeletonItemSchema = z.object({
  role: z.string().min(1).max(50),
  title: z.string().min(1).max(80),
  identifier: z.string().max(100).optional(),
});

export const DiscoverRequestSchema = z.object({
  bundleId: z.string().min(1).max(200),
  appName: z.string().min(1).max(100),
  appVersion: z.string().min(1).max(50),
  // Sub-cel 1.20 / P-43: BCP-47-ish locale code (e.g. "pl", "de", "zh-Hans").
  // When non-"en", the prompt instructs Claude to populate localizedTitles
  // for ~60-80% of the rules. nullable+optional so older clients without
  // the field still pass validation.
  appLocale: z.string().max(20).nullable().optional(),
  menuBar: z.array(MenuBarItemSchema).max(500),
  uiSkeleton: z.array(UISkeletonItemSchema).max(500),
  clientVersion: z.string().max(20),
});

export type DiscoverRequest = z.infer<typeof DiscoverRequestSchema>;

export const RuleSchema = z.object({
  match: z.object({
    role: z.string(),
    titles: z.array(z.string()).min(1).max(20),
    identifiers: z.array(z.string()).max(5).optional(),
    // Sub-cel 1.20: per-locale alternate titles. Keyed by normalized locale
    // code; values are AX-exposed strings in that locale (NOT literal
    // translations). Optional — rules without this field are treated as
    // English-only.
    localizedTitles: z.record(z.string(), z.array(z.string()).max(20)).optional(),
  }),
  keys: z.array(z.string()).min(1).max(5),
  hint: z.string().min(1).max(100),
  confidence: z.enum(["high", "medium", "low"]),
  source: z.enum(["menu_bar", "web_docs_official", "web_docs_third_party", "inferred_pattern"]),
  version: z.number().int().default(1),
});

export type Rule = z.infer<typeof RuleSchema>;

export const RuleSetSchema = z.object({
  bundleId: z.string(),
  rulesVersion: z.string(),
  rules: z.array(RuleSchema),
});

export type RuleSet = z.infer<typeof RuleSetSchema>;

export const FeedbackSchema = z.object({
  bundleId: z.string().min(1).max(200),
  keys: z.array(z.string().min(1).max(20)).min(1).max(10),
  reportType: z.enum(["wrong_shortcut"]),
});

export type Feedback = z.infer<typeof FeedbackSchema>;
