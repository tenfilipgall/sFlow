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
  bundleId: z.string(),
  rulesVersion: z.string(),
  ruleIndex: z.number().int().min(0),
  reportType: z.enum(["wrong_shortcut", "wrong_match", "spam"]),
});

export type Feedback = z.infer<typeof FeedbackSchema>;
