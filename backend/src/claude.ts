import Anthropic from "@anthropic-ai/sdk";
import type { DiscoverRequest, RuleSet, Rule } from "./types";
import { RuleSchema } from "./types";
import { buildSystemPrompt, buildUserPrompt } from "./prompt";
import { dedupOverlappingRules } from "./dedup";

const MODEL = "claude-sonnet-4-6";

export async function generateRules(
  apiKey: string,
  req: DiscoverRequest,
): Promise<RuleSet> {
  const client = new Anthropic({ apiKey });

  // Streaming is required for max_tokens > 8192 (Anthropic SDK rejects non-streaming
  // long-running operations to avoid HTTP timeouts). finalMessage() collects all
  // stream chunks into a regular Message object — rest of the pipeline unchanged.
  const stream = client.messages.stream({
    model: MODEL,
    max_tokens: 32768,
    system: buildSystemPrompt(),
    // TODO: update tool type identifier if SDK version changes
    // max_uses 4→8 (P-32, Sub-cel 1.12): cheatsheet + hotkey list + 6 per-element queries.
    // Cost impact: ~$0.01 extra per discovery. Quality impact: niche/regional apps no longer
    // skipped (Claude was occasionally not searching at all for apps it didn't know).
    tools: [{ type: "web_search_20250305" as const, name: "web_search", max_uses: 8 }],
    messages: [{ role: "user", content: buildUserPrompt(req) }],
  });
  const message = await stream.finalMessage();

  const text = extractFinalText(message);
  const rules = parseRulesJSON(text);

  const parsed: RuleSet = {
    bundleId: req.bundleId,
    rulesVersion: new Date().toISOString(),
    rules,
  };

  const { result: deduped, dropped } = dedupOverlappingRules(parsed);
  if (dropped.length > 0) {
    console.log(`[dedup] ${req.bundleId}: dropped ${dropped.length} overlapping rules:`, dropped);
  }
  return deduped;
}

function extractFinalText(message: Awaited<ReturnType<Anthropic["messages"]["create"]>>): string {
  // With server-side tools (web_search), Claude emits multiple text blocks:
  // a preamble ("I'll search..."), then tool_use blocks, then the final JSON answer.
  // We want the LAST text block — the answer after tool use is complete.
  for (let i = message.content.length - 1; i >= 0; i--) {
    const block = message.content[i];
    if (block.type === "text") return block.text;
  }
  throw new Error("No text block in Claude response");
}

export function parseRulesJSON(text: string): Rule[] {
  const cleaned = extractJSONObject(stripCodeFence(text));
  let parsed: unknown;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    throw new Error(`Claude returned non-JSON: ${text.slice(0, 200)}`);
  }
  if (
    !parsed ||
    typeof parsed !== "object" ||
    !("rules" in parsed) ||
    !Array.isArray((parsed as { rules: unknown }).rules)
  ) {
    throw new Error("Claude JSON missing 'rules' array");
  }
  const out: Rule[] = [];
  for (const raw of (parsed as { rules: unknown[] }).rules) {
    const result = RuleSchema.safeParse(raw);
    if (result.success) out.push(result.data);
  }
  return out;
}

function stripCodeFence(s: string): string {
  return s.replace(/^```(?:json)?\n?/, "").replace(/\n?```\s*$/, "").trim();
}

/// If text contains prose around a JSON object, return the substring from the first
/// `{` to the matching final `}`. If no `{` exists, returns the input unchanged.
function extractJSONObject(s: string): string {
  const first = s.indexOf("{");
  const last = s.lastIndexOf("}");
  if (first === -1 || last === -1 || last < first) return s;
  return s.slice(first, last + 1);
}
