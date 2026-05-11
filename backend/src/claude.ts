import Anthropic from "@anthropic-ai/sdk";
import type { DiscoverRequest, RuleSet, Rule } from "./types";
import { RuleSchema } from "./types";
import { buildSystemPrompt, buildUserPrompt } from "./prompt";

const MODEL = "claude-sonnet-4-6";

export async function generateRules(
  apiKey: string,
  req: DiscoverRequest,
): Promise<RuleSet> {
  const client = new Anthropic({ apiKey });

  const message = await client.messages.create({
    model: MODEL,
    max_tokens: 8192,
    system: buildSystemPrompt(),
    // TODO: update tool type identifier if SDK version changes
    tools: [{ type: "web_search_20250305" as const, name: "web_search", max_uses: 4 }],
    messages: [{ role: "user", content: buildUserPrompt(req) }],
  });

  const text = extractFinalText(message);
  const rules = parseRulesJSON(text);

  return {
    bundleId: req.bundleId,
    rulesVersion: new Date().toISOString(),
    rules,
  };
}

function extractFinalText(message: Awaited<ReturnType<Anthropic["messages"]["create"]>>): string {
  for (const block of message.content) {
    if (block.type === "text") return block.text;
  }
  throw new Error("No text block in Claude response");
}

export function parseRulesJSON(text: string): Rule[] {
  const cleaned = stripCodeFence(text);
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
