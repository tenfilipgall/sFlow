# SFlow Cloud LLM Rule Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hand-written per-app rules with LLM-generated rules from a globally-cached cloud backend, while preserving the existing L1-L4 heuristic fallbacks.

**Architecture:** Swift client loads rules from JSON files at three priority tiers (user overrides > LLM cache > bundled). On first encounter with an unknown app, the client extracts a privacy-filtered AX skeleton + menu bar dump and POSTs to a Cloudflare Worker. The Worker either returns a cached rule set or calls Claude Sonnet with web search, then caches the result globally.

**Tech Stack:**
- Client: Swift, AppKit, ApplicationServices (existing)
- Backend: Cloudflare Worker (TypeScript), KV namespace, Anthropic SDK
- LLM: Claude Sonnet 4.6 with `web_search` tool

**Phases (executable independently):**
- **Phase A:** Backend (Cloudflare Worker + Claude integration) — no Swift dependency
- **Phase B:** Swift JSON rule loader — integrates as Layer 0.5 in `ClickWatcher`
- **Phase C:** Swift discovery client — background trigger, AX skeleton, API call, indicator
- **Phase D:** Bundled rules seed pipeline — build-time generation for 4 verified apps
- **Phase E (deferred):** Pro tier BYOK
- **Phase F (deferred):** Feedback loop

Phases A–D are MVP. Ship as v1, then add E and F.

---

## Phase A: Cloudflare Worker Backend

### Task A1: Initialize Cloudflare Worker project

**Why:** Need a TypeScript project scaffolded with wrangler before any code can run.

**Files:**
- Create: `backend/package.json`
- Create: `backend/wrangler.toml`
- Create: `backend/tsconfig.json`
- Create: `backend/.gitignore`
- Create: `backend/src/index.ts` (placeholder)

- [ ] **Step 1: Install wrangler globally**

Run: `npm install -g wrangler@latest`
Expected: wrangler binary installed; verify with `wrangler --version` showing 3.x or higher.

- [ ] **Step 2: Create backend folder and init project**

```bash
mkdir -p /Users/filip/Claude/Projects/Apps/SFlow/backend
cd /Users/filip/Claude/Projects/Apps/SFlow/backend
npm init -y
npm install --save-dev wrangler@latest typescript @cloudflare/workers-types vitest @cloudflare/vitest-pool-workers
npm install @anthropic-ai/sdk
```

Expected: `node_modules/` and `package-lock.json` exist; no errors.

- [ ] **Step 3: Create wrangler.toml**

```toml
name = "sflow-rules"
main = "src/index.ts"
compatibility_date = "2026-01-01"
compatibility_flags = ["nodejs_compat"]

# KV namespaces (create via: wrangler kv namespace create RULES_CACHE)
# Then paste the returned IDs below.
[[kv_namespaces]]
binding = "RULES_CACHE"
id = "TODO_REPLACE_AFTER_WRANGLER_KV_CREATE"

[[kv_namespaces]]
binding = "FEEDBACK"
id = "TODO_REPLACE_AFTER_WRANGLER_KV_CREATE"

[[kv_namespaces]]
binding = "RATE_LIMIT"
id = "TODO_REPLACE_AFTER_WRANGLER_KV_CREATE"

# Secrets set via: wrangler secret put ANTHROPIC_API_KEY
```

- [ ] **Step 4: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "Bundler",
    "lib": ["ES2022"],
    "types": ["@cloudflare/workers-types"],
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"]
}
```

- [ ] **Step 5: Create .gitignore**

```
node_modules/
.wrangler/
.dev.vars
dist/
*.log
```

- [ ] **Step 6: Create placeholder index.ts**

```typescript
// backend/src/index.ts
export interface Env {
  RULES_CACHE: KVNamespace;
  FEEDBACK: KVNamespace;
  RATE_LIMIT: KVNamespace;
  ANTHROPIC_API_KEY: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return new Response("SFlow Rules Worker", { status: 200 });
  },
};
```

- [ ] **Step 7: Verify local dev works**

Run from `backend/`: `npx wrangler dev`
Expected: starts local dev server on `http://localhost:8787`; visit it shows "SFlow Rules Worker".
Stop with `Ctrl-C`.

- [ ] **Step 8: Commit**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow
git add backend/
git commit -m "feat(backend): scaffold Cloudflare Worker project"
```

---

### Task A2: Create KV namespaces and set Anthropic secret

**Files:**
- Modify: `backend/wrangler.toml`

- [ ] **Step 1: Create three KV namespaces**

From `backend/`:
```bash
npx wrangler kv namespace create RULES_CACHE
npx wrangler kv namespace create FEEDBACK
npx wrangler kv namespace create RATE_LIMIT
```

Expected: each command prints an `id = "..."` value. Copy each into `wrangler.toml` replacing the `TODO_REPLACE_AFTER_WRANGLER_KV_CREATE` placeholders.

- [ ] **Step 2: Create matching preview namespaces (for `wrangler dev`)**

```bash
npx wrangler kv namespace create RULES_CACHE --preview
npx wrangler kv namespace create FEEDBACK --preview
npx wrangler kv namespace create RATE_LIMIT --preview
```

Add `preview_id` to each `[[kv_namespaces]]` block in `wrangler.toml`:
```toml
[[kv_namespaces]]
binding = "RULES_CACHE"
id = "abc123..."
preview_id = "xyz789..."
```

- [ ] **Step 3: Set Anthropic secret**

```bash
npx wrangler secret put ANTHROPIC_API_KEY
```
Paste your Anthropic API key when prompted. (Get one from https://console.anthropic.com if you don't have one.)

- [ ] **Step 4: Commit wrangler.toml (without secret)**

```bash
git add backend/wrangler.toml
git commit -m "chore(backend): bind KV namespaces"
```

---

### Task A3: Request/response types and Zod validation

**Files:**
- Create: `backend/src/types.ts`
- Create: `backend/src/validate.ts`
- Create: `backend/tests/validate.test.ts`

- [ ] **Step 1: Install zod**

```bash
cd backend && npm install zod
```

- [ ] **Step 2: Define types and schemas**

```typescript
// backend/src/types.ts
import { z } from "zod";

export const MenuBarItemSchema = z.object({
  path: z.array(z.string()).min(1).max(10),
  shortcut: z.string().nullable().optional(),
});

export const UISkeletonItemSchema = z.object({
  role: z.string().min(1).max(50),
  title: z.string().min(1).max(80),
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
  }),
  keys: z.array(z.string()).min(1).max(5),
  hint: z.string().min(1).max(100),
  confidence: z.enum(["high", "medium", "low"]),
  source: z.enum(["menu_bar", "web_docs_official", "web_docs_third_party", "inferred_pattern"]),
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
```

- [ ] **Step 3: Write the failing test**

```typescript
// backend/tests/validate.test.ts
import { describe, expect, it } from "vitest";
import { DiscoverRequestSchema, RuleSchema } from "../src/types";

describe("DiscoverRequestSchema", () => {
  it("accepts minimal valid request", () => {
    const result = DiscoverRequestSchema.safeParse({
      bundleId: "com.linear.electron",
      appName: "Linear",
      appVersion: "1.42.0",
      menuBar: [],
      uiSkeleton: [],
      clientVersion: "1.0.0",
    });
    expect(result.success).toBe(true);
  });

  it("rejects empty bundleId", () => {
    const result = DiscoverRequestSchema.safeParse({
      bundleId: "",
      appName: "X",
      appVersion: "1",
      menuBar: [],
      uiSkeleton: [],
      clientVersion: "1.0.0",
    });
    expect(result.success).toBe(false);
  });

  it("rejects skeleton over 500 items", () => {
    const huge = Array.from({ length: 501 }, () => ({ role: "AXButton", title: "X" }));
    const result = DiscoverRequestSchema.safeParse({
      bundleId: "com.x",
      appName: "X",
      appVersion: "1",
      menuBar: [],
      uiSkeleton: huge,
      clientVersion: "1",
    });
    expect(result.success).toBe(false);
  });
});

describe("RuleSchema", () => {
  it("rejects invalid confidence value", () => {
    const result = RuleSchema.safeParse({
      match: { role: "AXButton", titles: ["Send"] },
      keys: ["meta", "enter"],
      hint: "Send",
      confidence: "vague",
      source: "menu_bar",
    });
    expect(result.success).toBe(false);
  });
});
```

- [ ] **Step 4: Create vitest config**

```typescript
// backend/vitest.config.ts
import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: "./wrangler.toml" },
      },
    },
  },
});
```

- [ ] **Step 5: Run tests, expect pass**

```bash
cd backend && npx vitest run
```
Expected: 4 tests passing.

- [ ] **Step 6: Commit**

```bash
git add backend/
git commit -m "feat(backend): add request/response schemas with validation tests"
```

---

### Task A4: Cache lookup with KV

**Files:**
- Create: `backend/src/storage.ts`
- Create: `backend/tests/storage.test.ts`

- [ ] **Step 1: Write failing test**

```typescript
// backend/tests/storage.test.ts
import { env } from "cloudflare:test";
import { describe, expect, it, beforeEach } from "vitest";
import { cacheKey, getCachedRules, putCachedRules } from "../src/storage";

describe("storage", () => {
  beforeEach(async () => {
    const list = await env.RULES_CACHE.list();
    for (const k of list.keys) await env.RULES_CACHE.delete(k.name);
  });

  it("cacheKey strips patch version", () => {
    expect(cacheKey("com.x", "1.42.7")).toBe("rules:com.x:1.42");
    expect(cacheKey("com.x", "2.0")).toBe("rules:com.x:2.0");
    expect(cacheKey("com.x", "1.0.0-beta")).toBe("rules:com.x:1.0");
  });

  it("returns null for cache miss", async () => {
    const result = await getCachedRules(env.RULES_CACHE, "com.x", "1.0");
    expect(result).toBeNull();
  });

  it("round-trips a cached rule set", async () => {
    const rules = {
      bundleId: "com.x",
      rulesVersion: "2026-05-11T00:00:00Z",
      rules: [
        {
          match: { role: "AXButton", titles: ["Send"] },
          keys: ["meta", "enter"],
          hint: "Send",
          confidence: "high" as const,
          source: "menu_bar" as const,
        },
      ],
    };
    await putCachedRules(env.RULES_CACHE, "com.x", "1.0.5", rules);
    const result = await getCachedRules(env.RULES_CACHE, "com.x", "1.0.9");
    expect(result).toEqual(rules);
  });
});
```

- [ ] **Step 2: Run test, verify FAIL**

```bash
cd backend && npx vitest run tests/storage.test.ts
```
Expected: FAIL, "Cannot find module '../src/storage'".

- [ ] **Step 3: Implement storage.ts**

```typescript
// backend/src/storage.ts
import type { RuleSet } from "./types";

export function cacheKey(bundleId: string, appVersion: string): string {
  const parts = appVersion.split(/[.\-+]/);
  const major = parts[0] ?? "0";
  const minor = parts[1] ?? "0";
  return `rules:${bundleId}:${major}.${minor}`;
}

export async function getCachedRules(
  kv: KVNamespace,
  bundleId: string,
  appVersion: string,
): Promise<RuleSet | null> {
  const raw = await kv.get(cacheKey(bundleId, appVersion));
  if (!raw) return null;
  try {
    return JSON.parse(raw) as RuleSet;
  } catch {
    return null;
  }
}

export async function putCachedRules(
  kv: KVNamespace,
  bundleId: string,
  appVersion: string,
  rules: RuleSet,
): Promise<void> {
  await kv.put(cacheKey(bundleId, appVersion), JSON.stringify(rules), {
    // 90-day TTL — see spec Section 8 "hard refresh after 90 days"
    expirationTtl: 90 * 24 * 60 * 60,
  });
}
```

- [ ] **Step 4: Run test, expect PASS**

```bash
cd backend && npx vitest run tests/storage.test.ts
```
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add backend/
git commit -m "feat(backend): KV cache helpers with version-aware keys"
```

---

### Task A5: Claude prompt and rule extraction

**Files:**
- Create: `backend/src/claude.ts`
- Create: `backend/src/prompt.ts`
- Create: `backend/tests/prompt.test.ts`

- [ ] **Step 1: Write the prompt builder**

```typescript
// backend/src/prompt.ts
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
```

- [ ] **Step 2: Write prompt builder test**

```typescript
// backend/tests/prompt.test.ts
import { describe, expect, it } from "vitest";
import { buildSystemPrompt, buildUserPrompt } from "../src/prompt";

describe("buildSystemPrompt", () => {
  it("mentions all four sources", () => {
    const p = buildSystemPrompt();
    expect(p).toContain("menu_bar");
    expect(p).toContain("web_docs_official");
    expect(p).toContain("web_docs_third_party");
    expect(p).toContain("inferred_pattern");
  });
});

describe("buildUserPrompt", () => {
  it("formats menu bar paths with shortcuts", () => {
    const result = buildUserPrompt({
      bundleId: "com.x",
      appName: "X",
      appVersion: "1.0",
      menuBar: [{ path: ["File", "New"], shortcut: "cmd+n" }],
      uiSkeleton: [],
      clientVersion: "1.0",
    });
    expect(result).toContain("File > New [cmd+n]");
  });

  it("handles empty menu bar gracefully", () => {
    const result = buildUserPrompt({
      bundleId: "com.x",
      appName: "X",
      appVersion: "1.0",
      menuBar: [],
      uiSkeleton: [{ role: "AXButton", title: "Send" }],
      clientVersion: "1.0",
    });
    expect(result).toContain("(empty)");
    expect(result).toContain('AXButton: "Send"');
  });
});
```

- [ ] **Step 3: Run, expect PASS**

```bash
cd backend && npx vitest run tests/prompt.test.ts
```

- [ ] **Step 4: Implement Claude client**

```typescript
// backend/src/claude.ts
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
    tools: [{ type: "web_search_20250305", name: "web_search", max_uses: 4 }],
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

function extractFinalText(message: Anthropic.Messages.Message): string {
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
  } catch (e) {
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
    const parsed = RuleSchema.safeParse(raw);
    if (parsed.success) out.push(parsed.data);
  }
  return out;
}

function stripCodeFence(s: string): string {
  return s.replace(/^```(?:json)?\n?/, "").replace(/\n?```\s*$/, "").trim();
}
```

- [ ] **Step 5: Write parser test**

```typescript
// backend/tests/claude.test.ts
import { describe, expect, it } from "vitest";
import { parseRulesJSON } from "../src/claude";

describe("parseRulesJSON", () => {
  it("parses bare JSON", () => {
    const json = `{"rules":[{"match":{"role":"AXButton","titles":["Send"]},"keys":["meta","enter"],"hint":"Send","confidence":"high","source":"menu_bar"}]}`;
    const result = parseRulesJSON(json);
    expect(result).toHaveLength(1);
    expect(result[0].keys).toEqual(["meta", "enter"]);
  });

  it("strips code fences", () => {
    const text = "```json\n{\"rules\":[]}\n```";
    expect(parseRulesJSON(text)).toEqual([]);
  });

  it("drops malformed rules but keeps valid ones", () => {
    const json = `{"rules":[
      {"match":{"role":"AXButton","titles":["Send"]},"keys":["enter"],"hint":"Send","confidence":"high","source":"menu_bar"},
      {"match":{"role":"AXButton","titles":["X"]},"keys":[],"hint":"X","confidence":"high","source":"menu_bar"}
    ]}`;
    const result = parseRulesJSON(json);
    expect(result).toHaveLength(1);
    expect(result[0].match.titles).toEqual(["Send"]);
  });

  it("throws on non-JSON", () => {
    expect(() => parseRulesJSON("not json at all")).toThrow(/non-JSON/);
  });
});
```

- [ ] **Step 6: Run, expect PASS**

```bash
cd backend && npx vitest run tests/claude.test.ts
```

- [ ] **Step 7: Commit**

```bash
git add backend/
git commit -m "feat(backend): Claude integration with web_search tool and JSON rule parsing"
```

---

### Task A6: Rate limiting

**Files:**
- Create: `backend/src/ratelimit.ts`
- Create: `backend/tests/ratelimit.test.ts`

- [ ] **Step 1: Write failing test**

```typescript
// backend/tests/ratelimit.test.ts
import { env } from "cloudflare:test";
import { describe, expect, it, beforeEach } from "vitest";
import { checkRateLimit } from "../src/ratelimit";

describe("checkRateLimit", () => {
  beforeEach(async () => {
    const list = await env.RATE_LIMIT.list();
    for (const k of list.keys) await env.RATE_LIMIT.delete(k.name);
  });

  it("allows the first 10 requests in an hour", async () => {
    for (let i = 0; i < 10; i++) {
      const result = await checkRateLimit(env.RATE_LIMIT, "1.2.3.4");
      expect(result.allowed).toBe(true);
    }
  });

  it("rejects the 11th request from the same IP", async () => {
    for (let i = 0; i < 10; i++) {
      await checkRateLimit(env.RATE_LIMIT, "1.2.3.4");
    }
    const result = await checkRateLimit(env.RATE_LIMIT, "1.2.3.4");
    expect(result.allowed).toBe(false);
    expect(result.retryAfter).toBeGreaterThan(0);
  });

  it("different IPs are tracked separately", async () => {
    for (let i = 0; i < 10; i++) {
      await checkRateLimit(env.RATE_LIMIT, "1.2.3.4");
    }
    const result = await checkRateLimit(env.RATE_LIMIT, "5.6.7.8");
    expect(result.allowed).toBe(true);
  });
});
```

- [ ] **Step 2: Run, expect FAIL**

```bash
cd backend && npx vitest run tests/ratelimit.test.ts
```

- [ ] **Step 3: Implement**

```typescript
// backend/src/ratelimit.ts
const WINDOW_SECONDS = 3600;
const MAX_PER_WINDOW = 10;

export type RateLimitResult =
  | { allowed: true; remaining: number }
  | { allowed: false; retryAfter: number };

export async function checkRateLimit(
  kv: KVNamespace,
  clientIp: string,
): Promise<RateLimitResult> {
  const now = Math.floor(Date.now() / 1000);
  const bucket = Math.floor(now / WINDOW_SECONDS);
  const key = `rl:${clientIp}:${bucket}`;

  const currentRaw = await kv.get(key);
  const current = currentRaw ? parseInt(currentRaw, 10) : 0;

  if (current >= MAX_PER_WINDOW) {
    const retryAfter = (bucket + 1) * WINDOW_SECONDS - now;
    return { allowed: false, retryAfter };
  }

  await kv.put(key, String(current + 1), { expirationTtl: WINDOW_SECONDS });
  return { allowed: true, remaining: MAX_PER_WINDOW - current - 1 };
}
```

- [ ] **Step 4: Run, expect PASS**

```bash
cd backend && npx vitest run tests/ratelimit.test.ts
```

- [ ] **Step 5: Commit**

```bash
git add backend/
git commit -m "feat(backend): per-IP rate limiting (10 discoveries/hour)"
```

---

### Task A7: Wire up `/v1/discover` endpoint

**Files:**
- Modify: `backend/src/index.ts`
- Create: `backend/src/handlers/discover.ts`
- Create: `backend/tests/discover.test.ts`

- [ ] **Step 1: Write failing integration test**

```typescript
// backend/tests/discover.test.ts
import { env, SELF } from "cloudflare:test";
import { describe, expect, it, beforeEach, vi } from "vitest";
import * as claudeModule from "../src/claude";

describe("POST /v1/discover", () => {
  beforeEach(async () => {
    for (const ns of [env.RULES_CACHE, env.RATE_LIMIT]) {
      const list = await ns.list();
      for (const k of list.keys) await ns.delete(k.name);
    }
    vi.restoreAllMocks();
  });

  it("returns 400 on missing bundleId", async () => {
    const r = await SELF.fetch("https://example.com/v1/discover", {
      method: "POST",
      body: JSON.stringify({}),
    });
    expect(r.status).toBe(400);
  });

  it("returns 405 on GET", async () => {
    const r = await SELF.fetch("https://example.com/v1/discover");
    expect(r.status).toBe(405);
  });

  it("returns cached rules immediately on cache hit", async () => {
    await env.RULES_CACHE.put(
      "rules:com.x:1.0",
      JSON.stringify({
        bundleId: "com.x",
        rulesVersion: "2026-05-11T00:00:00Z",
        rules: [
          {
            match: { role: "AXButton", titles: ["Send"] },
            keys: ["meta", "enter"],
            hint: "Send",
            confidence: "high",
            source: "menu_bar",
          },
        ],
      }),
    );

    const r = await SELF.fetch("https://example.com/v1/discover", {
      method: "POST",
      body: JSON.stringify({
        bundleId: "com.x",
        appName: "X",
        appVersion: "1.0.7",
        menuBar: [],
        uiSkeleton: [],
        clientVersion: "1.0",
      }),
    });
    expect(r.status).toBe(200);
    const body = await r.json();
    expect(body.rules).toHaveLength(1);
  });

  it("calls Claude on cache miss and caches the result", async () => {
    const spy = vi.spyOn(claudeModule, "generateRules").mockResolvedValue({
      bundleId: "com.x",
      rulesVersion: "2026-05-11T00:00:00Z",
      rules: [
        {
          match: { role: "AXButton", titles: ["Go"] },
          keys: ["g"],
          hint: "Go",
          confidence: "high",
          source: "menu_bar",
        },
      ],
    });

    const r = await SELF.fetch("https://example.com/v1/discover", {
      method: "POST",
      body: JSON.stringify({
        bundleId: "com.x",
        appName: "X",
        appVersion: "1.0",
        menuBar: [],
        uiSkeleton: [],
        clientVersion: "1.0",
      }),
    });

    expect(r.status).toBe(200);
    expect(spy).toHaveBeenCalledOnce();
    const cached = await env.RULES_CACHE.get("rules:com.x:1.0");
    expect(cached).toBeTruthy();
  });

  it("returns 429 when rate limit exceeded", async () => {
    // 11 unique bundle IDs from same IP
    for (let i = 0; i < 11; i++) {
      const r = await SELF.fetch("https://example.com/v1/discover", {
        method: "POST",
        headers: { "CF-Connecting-IP": "9.9.9.9" },
        body: JSON.stringify({
          bundleId: `com.app${i}`,
          appName: "X",
          appVersion: "1.0",
          menuBar: [],
          uiSkeleton: [],
          clientVersion: "1.0",
        }),
      });
      if (i < 10) {
        expect(r.status).not.toBe(429);
      } else {
        expect(r.status).toBe(429);
      }
    }
  });
});
```

- [ ] **Step 2: Implement handler**

```typescript
// backend/src/handlers/discover.ts
import { DiscoverRequestSchema } from "../types";
import { getCachedRules, putCachedRules } from "../storage";
import { generateRules } from "../claude";
import { checkRateLimit } from "../ratelimit";
import type { Env } from "../index";

export async function handleDiscover(
  request: Request,
  env: Env,
): Promise<Response> {
  if (request.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonError(400, "Invalid JSON");
  }

  const parsed = DiscoverRequestSchema.safeParse(body);
  if (!parsed.success) {
    return jsonError(400, `Invalid request: ${parsed.error.message}`);
  }
  const req = parsed.data;

  // Cache lookup first — does not consume rate limit.
  const cached = await getCachedRules(env.RULES_CACHE, req.bundleId, req.appVersion);
  if (cached) {
    return jsonResponse(cached);
  }

  const clientIp = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const rl = await checkRateLimit(env.RATE_LIMIT, clientIp);
  if (!rl.allowed) {
    return new Response("Rate limit exceeded", {
      status: 429,
      headers: { "Retry-After": String(rl.retryAfter) },
    });
  }

  let rules;
  try {
    rules = await generateRules(env.ANTHROPIC_API_KEY, req);
  } catch (e) {
    return jsonError(502, `LLM error: ${(e as Error).message}`);
  }

  await putCachedRules(env.RULES_CACHE, req.bundleId, req.appVersion, rules);
  return jsonResponse(rules);
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function jsonError(status: number, message: string): Response {
  return jsonResponse({ error: message }, status);
}
```

- [ ] **Step 3: Update index.ts router**

```typescript
// backend/src/index.ts
import { handleDiscover } from "./handlers/discover";

export interface Env {
  RULES_CACHE: KVNamespace;
  FEEDBACK: KVNamespace;
  RATE_LIMIT: KVNamespace;
  ANTHROPIC_API_KEY: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/v1/discover") {
      return handleDiscover(request, env);
    }

    if (url.pathname === "/" || url.pathname === "/health") {
      return new Response("SFlow Rules Worker", { status: 200 });
    }

    return new Response("Not Found", { status: 404 });
  },
};
```

- [ ] **Step 4: Run, expect PASS**

```bash
cd backend && npx vitest run tests/discover.test.ts
```

- [ ] **Step 5: Commit**

```bash
git add backend/
git commit -m "feat(backend): /v1/discover endpoint with cache, rate limit, Claude fallback"
```

---

### Task A8: Deploy to Cloudflare and smoke test

- [ ] **Step 1: Deploy**

```bash
cd backend && npx wrangler deploy
```
Expected: output prints worker URL like `https://sflow-rules.<your-subdomain>.workers.dev`.

- [ ] **Step 2: Note the worker URL**

Save the URL — you'll hardcode it into the Swift client (Task C3). For example: `https://sflow-rules.filip-gocamping-tv.workers.dev`.

- [ ] **Step 3: Smoke test with curl**

Replace `YOUR_WORKER_URL` below:
```bash
curl -X POST "YOUR_WORKER_URL/v1/discover" \
  -H "Content-Type: application/json" \
  -d '{
    "bundleId": "com.example.smoketest",
    "appName": "Smoke Test",
    "appVersion": "1.0.0",
    "menuBar": [{"path":["File","New"],"shortcut":"cmd+n"}],
    "uiSkeleton": [{"role":"AXButton","title":"Save"}],
    "clientVersion": "1.0.0"
  }'
```
Expected: ~15-45s wait, then JSON response with `rules` array containing entries for File>New (cmd+n).
Cost: ~$0.05 of your Anthropic credit.

- [ ] **Step 4: Repeat request, verify cache hit (fast response)**

Same curl. Expected: <500ms response, same body.

- [ ] **Step 5: Commit deployment note**

```bash
cd /Users/filip/Claude/Projects/Apps/SFlow
echo "Worker deployed: YOUR_WORKER_URL" > backend/DEPLOYED.md
git add backend/DEPLOYED.md
git commit -m "docs(backend): record deployed worker URL"
```

---

## Phase B: Swift Rule Loading

### Task B1: Define `LoadedRule` and `RuleSet` data types

**Why:** The Swift client needs Codable types matching the JSON response from the backend, plus a corresponding on-disk format.

**Files:**
- Create: `SFlow/LoadedRule.swift`
- Create: `SFlowTests/LoadedRuleTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// SFlowTests/LoadedRuleTests.swift
import XCTest
@testable import SFlow

final class LoadedRuleTests: XCTestCase {
    func testDecodesBackendResponseFormat() throws {
        let json = #"""
        {
          "bundleId": "com.x",
          "rulesVersion": "2026-05-11T10:00:00Z",
          "rules": [
            {
              "match": { "role": "AXButton", "titles": ["Send", "Wyślij"] },
              "keys": ["meta", "enter"],
              "hint": "Send",
              "confidence": "high",
              "source": "menu_bar"
            }
          ]
        }
        """#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(BackendRuleSet.self, from: json)
        XCTAssertEqual(decoded.bundleId, "com.x")
        XCTAssertEqual(decoded.rules.count, 1)
        XCTAssertEqual(decoded.rules[0].match.titles, ["Send", "Wyślij"])
        XCTAssertEqual(decoded.rules[0].keys, ["meta", "enter"])
        XCTAssertEqual(decoded.rules[0].confidence, .high)
        XCTAssertEqual(decoded.rules[0].source, .menuBar)
    }

    func testDecodesOnDiskFormat() throws {
        let json = #"""
        {
          "bundleId": "com.x",
          "appVersion": "1.42",
          "fetchedAt": "2026-05-11T10:00:00Z",
          "source": "cloud",
          "rulesVersion": "2026-05-11T10:00:00Z",
          "rules": []
        }
        """#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(StoredRuleSet.self, from: json)
        XCTAssertEqual(decoded.source, .cloud)
    }
}
```

- [ ] **Step 2: Run, expect FAIL** (Cannot find `BackendRuleSet`)

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' -only-testing:SFlowTests/LoadedRuleTests 2>&1 | tail -30
```

- [ ] **Step 3: Implement**

```swift
// SFlow/LoadedRule.swift
import Foundation

enum LoadedConfidence: String, Codable {
    case high
    case medium
    case low
}

enum LoadedSource: String, Codable {
    case menuBar = "menu_bar"
    case webDocsOfficial = "web_docs_official"
    case webDocsThirdParty = "web_docs_third_party"
    case inferredPattern = "inferred_pattern"
}

struct LoadedMatch: Codable {
    let role: String
    let titles: [String]
}

struct LoadedRule: Codable {
    let match: LoadedMatch
    let keys: [String]
    let hint: String
    let confidence: LoadedConfidence
    let source: LoadedSource
}

/// Wire format: what the backend returns from /v1/discover.
struct BackendRuleSet: Codable {
    let bundleId: String
    let rulesVersion: String
    let rules: [LoadedRule]
}

enum StoredSource: String, Codable {
    case bundled
    case cloud
    case user
}

/// On-disk format under ~/Library/Application Support/SFlow/rules/.
struct StoredRuleSet: Codable {
    let bundleId: String
    let appVersion: String?
    let fetchedAt: String
    let source: StoredSource
    let rulesVersion: String?
    let rules: [LoadedRule]
}
```

- [ ] **Step 4: Run, expect PASS**

- [ ] **Step 5: Commit**

```bash
git add SFlow/LoadedRule.swift SFlowTests/LoadedRuleTests.swift
git commit -m "feat: LoadedRule/StoredRuleSet Codable types for JSON-loaded rules"
```

---

### Task B2: `RuleCache` — load and prioritize rule files

**Why:** Single source of truth for rules at runtime. Loads from three locations in priority order: user_overrides > cache > bundled.

**Files:**
- Create: `SFlow/RuleCache.swift`
- Create: `SFlowTests/RuleCacheTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// SFlowTests/RuleCacheTests.swift
import XCTest
@testable import SFlow

final class RuleCacheTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func write(_ filename: String, _ rules: [LoadedRule], source: StoredSource) throws {
        let set = StoredRuleSet(
            bundleId: "com.x",
            appVersion: "1.0",
            fetchedAt: "2026-05-11T00:00:00Z",
            source: source,
            rulesVersion: nil,
            rules: rules
        )
        let data = try JSONEncoder().encode(set)
        try data.write(to: tempDir.appendingPathComponent(filename))
    }

    private func rule(_ title: String, keys: [String]) -> LoadedRule {
        LoadedRule(
            match: LoadedMatch(role: "AXButton", titles: [title]),
            keys: keys,
            hint: title,
            confidence: .high,
            source: .menuBar
        )
    }

    func testLoadsBundledRulesWhenNothingElseExists() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("Send", keys: ["meta", "enter"])], source: .bundled)
        // bundled.json sits at the top level; cache/ stays empty
        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        let result = cache.match(bundleId: "com.x", role: "AXButton", title: "Send", desc: "", help: "")
        XCTAssertEqual(result?.keys, ["meta", "enter"])
    }

    func testCacheRuleOverridesBundled() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("Send", keys: ["meta", "enter"])], source: .bundled)

        let cacheSet = StoredRuleSet(
            bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-11T00:00:00Z",
            source: .cloud, rulesVersion: nil,
            rules: [rule("Send", keys: ["meta", "s"])]   // different keys
        )
        let data = try JSONEncoder().encode(cacheSet)
        try data.write(to: tempDir.appendingPathComponent("cache/com.x.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        let result = cache.match(bundleId: "com.x", role: "AXButton", title: "Send", desc: "", help: "")
        XCTAssertEqual(result?.keys, ["meta", "s"], "cache overrides bundled")
    }

    func testUserOverridesWinOverEverything() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try write("bundled.json", [rule("Send", keys: ["meta", "enter"])], source: .bundled)

        let cacheSet = StoredRuleSet(
            bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-11T00:00:00Z",
            source: .cloud, rulesVersion: nil,
            rules: [rule("Send", keys: ["meta", "s"])]
        )
        let cacheData = try JSONEncoder().encode(cacheSet)
        try cacheData.write(to: tempDir.appendingPathComponent("cache/com.x.json"))

        let userSet = StoredRuleSet(
            bundleId: "com.x", appVersion: nil, fetchedAt: "2026-05-11T00:00:00Z",
            source: .user, rulesVersion: nil,
            rules: [rule("Send", keys: ["meta", "x"])]
        )
        let userData = try JSONEncoder().encode(userSet)
        try userData.write(to: tempDir.appendingPathComponent("user_overrides.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()
        let result = cache.match(bundleId: "com.x", role: "AXButton", title: "Send", desc: "", help: "")
        XCTAssertEqual(result?.keys, ["meta", "x"], "user overrides win")
    }

    func testMatchesAgainstAnyTitleInArray() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)

        let set = StoredRuleSet(
            bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-11T00:00:00Z",
            source: .cloud, rulesVersion: nil,
            rules: [LoadedRule(
                match: LoadedMatch(role: "AXButton", titles: ["Send", "Wyślij", "Senden"]),
                keys: ["meta", "enter"], hint: "Send",
                confidence: .high, source: .menuBar
            )]
        )
        let data = try JSONEncoder().encode(set)
        try data.write(to: tempDir.appendingPathComponent("cache/com.x.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()

        XCTAssertNotNil(cache.match(bundleId: "com.x", role: "AXButton", title: "Wyślij", desc: "", help: ""))
        XCTAssertNotNil(cache.match(bundleId: "com.x", role: "AXButton", title: "Senden", desc: "", help: ""))
        XCTAssertNil(cache.match(bundleId: "com.x", role: "AXButton", title: "Cancel", desc: "", help: ""))
    }

    func testRoleMustMatch() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)

        let set = StoredRuleSet(
            bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-11T00:00:00Z",
            source: .cloud, rulesVersion: nil,
            rules: [rule("Send", keys: ["meta", "enter"])]
        )
        let data = try JSONEncoder().encode(set)
        try data.write(to: tempDir.appendingPathComponent("cache/com.x.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()

        XCTAssertNotNil(cache.match(bundleId: "com.x", role: "AXButton", title: "Send", desc: "", help: ""))
        XCTAssertNil(cache.match(bundleId: "com.x", role: "AXLink", title: "Send", desc: "", help: ""))
    }

    func testFiltersLowConfidenceByDefault() throws {
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cache"), withIntermediateDirectories: true)

        let lowRule = LoadedRule(
            match: LoadedMatch(role: "AXButton", titles: ["Maybe"]),
            keys: ["m"], hint: "Maybe",
            confidence: .low, source: .inferredPattern
        )
        let set = StoredRuleSet(
            bundleId: "com.x", appVersion: "1.0", fetchedAt: "2026-05-11T00:00:00Z",
            source: .cloud, rulesVersion: nil,
            rules: [lowRule]
        )
        let data = try JSONEncoder().encode(set)
        try data.write(to: tempDir.appendingPathComponent("cache/com.x.json"))

        let cache = RuleCache(rootDir: tempDir)
        try cache.load()

        XCTAssertNil(cache.match(bundleId: "com.x", role: "AXButton", title: "Maybe", desc: "", help: ""),
                     "low-confidence rules are hidden by default")
    }
}
```

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement RuleCache**

```swift
// SFlow/RuleCache.swift
import Foundation

final class RuleCache {
    struct MatchResult {
        let rule: LoadedRule
        var keys: [String] { rule.keys }
        var hint: String { rule.hint }
    }

    private let rootDir: URL
    private var rulesByBundle: [String: [LoadedRule]] = [:]
    var showExperimental: Bool = false

    init(rootDir: URL) {
        self.rootDir = rootDir
    }

    func load() throws {
        rulesByBundle.removeAll()
        // Layer 1: bundled (lowest priority)
        loadFile(rootDir.appendingPathComponent("bundled.json"))
        // Layer 2: cache files (override bundled)
        let cacheDir = rootDir.appendingPathComponent("cache")
        if let entries = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for entry in entries where entry.pathExtension == "json" {
                loadFile(entry)
            }
        }
        // Layer 3: user overrides (highest)
        loadFile(rootDir.appendingPathComponent("user_overrides.json"))
    }

    private func loadFile(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        if let set = try? JSONDecoder().decode(StoredRuleSet.self, from: data) {
            rulesByBundle[set.bundleId] = set.rules
            return
        }
        // bundled.json may contain multiple apps wrapped in an array
        if let sets = try? JSONDecoder().decode([StoredRuleSet].self, from: data) {
            for set in sets {
                if rulesByBundle[set.bundleId] == nil {
                    rulesByBundle[set.bundleId] = set.rules
                }
            }
        }
    }

    func match(bundleId: String, role: String, title: String, desc: String, help: String) -> MatchResult? {
        guard let rules = rulesByBundle[bundleId] else { return nil }
        let titleLC = title.lowercased()
        let descLC = desc.lowercased()
        let helpLC = help.lowercased()

        for rule in rules {
            if !showExperimental, rule.confidence == .low { continue }
            if rule.match.role != role { continue }
            let titleMatches = rule.match.titles.contains { candidate in
                let c = candidate.lowercased()
                return titleLC == c || descLC == c || helpLC == c
                    || titleLC.contains(c) || descLC.contains(c)
            }
            if titleMatches { return MatchResult(rule: rule) }
        }
        return nil
    }

    func hasRules(bundleId: String) -> Bool {
        rulesByBundle[bundleId]?.isEmpty == false
    }
}
```

- [ ] **Step 4: Run tests, expect PASS**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' -only-testing:SFlowTests/RuleCacheTests 2>&1 | tail -30
```

- [ ] **Step 5: Commit**

```bash
git add SFlow/RuleCache.swift SFlowTests/RuleCacheTests.swift
git commit -m "feat: RuleCache with priority-ordered loading (user > cache > bundled)"
```

---

### Task B3: Define the rules root directory and bundled.json discovery

**Why:** `RuleCache` needs a real on-disk path at runtime. Bundled JSON ships inside the app bundle; cache and user files live in `~/Library/Application Support/SFlow/rules/`.

**Files:**
- Create: `SFlow/RuleStorage.swift`
- Create: `SFlowTests/RuleStorageTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// SFlowTests/RuleStorageTests.swift
import XCTest
@testable import SFlow

final class RuleStorageTests: XCTestCase {
    func testApplicationSupportDirectoryPath() {
        let url = RuleStorage.userRulesDirectory()
        XCTAssertTrue(url.path.contains("Application Support/SFlow/rules"),
                      "Got: \(url.path)")
    }

    func testEnsureDirectoryCreatesNestedFolders() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try RuleStorage.ensureDirectory(tmp.appendingPathComponent("cache"))
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("cache").path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }
}
```

- [ ] **Step 2: Implement**

```swift
// SFlow/RuleStorage.swift
import Foundation

enum RuleStorage {
    static func userRulesDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("SFlow/rules", isDirectory: true)
    }

    static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Copies the bundled.json shipped inside the app bundle into the user's rules dir on first launch.
    /// Returns true if the file was just copied.
    @discardableResult
    static func seedBundledIfMissing() throws -> Bool {
        let userDir = userRulesDirectory()
        try ensureDirectory(userDir)
        try ensureDirectory(userDir.appendingPathComponent("cache"))

        let dest = userDir.appendingPathComponent("bundled.json")
        if FileManager.default.fileExists(atPath: dest.path) { return false }

        guard let src = Bundle.main.url(forResource: "bundled", withExtension: "json") else {
            return false
        }
        try FileManager.default.copyItem(at: src, to: dest)
        return true
    }
}
```

- [ ] **Step 3: Run, expect PASS**

- [ ] **Step 4: Commit**

```bash
git add SFlow/RuleStorage.swift SFlowTests/RuleStorageTests.swift
git commit -m "feat: RuleStorage utilities for rules directory paths"
```

---

### Task B4: Integrate `RuleCache` as Layer 0.5 in `ClickWatcher`

**Why:** New rule source should match before Layer 1 hardcoded rules so LLM-generated rules can override them.

**Files:**
- Modify: `SFlow/ClickWatcher.swift`
- Modify: `SFlow/AppDelegate.swift`

- [ ] **Step 1: Add RuleCache property and initializer parameter**

In `SFlow/ClickWatcher.swift`, replace lines 5-21 with:

```swift
private var sharedWatcher: ClickWatcher?

final class ClickWatcher {
    typealias Handler = (ShortcutEvent) -> Void

    private let onEvent: Handler
    private let menuBarWatcher = MenuBarWatcher()
    private let ruleCache: RuleCache
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastShortcutId: String = ""
    private var lastShortcutTime: Date = .distantPast

    init(ruleCache: RuleCache, onEvent: @escaping Handler) {
        self.onEvent = onEvent
        self.ruleCache = ruleCache
        sharedWatcher = self
        setup()
    }
```

- [ ] **Step 2: Insert Layer 0.5 matching BEFORE Layer 1**

In `SFlow/ClickWatcher.swift`, in `handleMouseDown()`, find the Layer 1 block (around line 90, starts with `// Layer 1: hardcoded per-app rules`). Insert this BEFORE it:

```swift
                // Layer 0.5: JSON-loaded rules (bundled / LLM cache / user overrides)
                if let result = ruleCache.match(
                    bundleId: bundleId,
                    role: currentRole,
                    title: currentTitle,
                    desc: currentDesc,
                    help: currentHelp.lowercased()
                ) {
                    let autoId = "json:\(bundleId):\(result.keys.joined(separator: "+"))"
                    emit(bundleId: bundleId, shortcutId: autoId,
                         keys: result.keys, hint: result.hint, loc: nsLoc)
                    return
                }
```

- [ ] **Step 3: Wire `RuleCache` into `AppDelegate`**

In `SFlow/AppDelegate.swift`, replace lines 1-12 with:

```swift
import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var clickWatcher: ClickWatcher?
    private var ruleCache: RuleCache!

    private var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "enabled") }
    }
```

Replace `startWatcher()` (around line 89) with:

```swift
    private func startWatcher() {
        do {
            try RuleStorage.seedBundledIfMissing()
            ruleCache = RuleCache(rootDir: RuleStorage.userRulesDirectory())
            try ruleCache.load()
        } catch {
            NSLog("SFlow: RuleCache load failed: \(error). Continuing without JSON rules.")
            ruleCache = RuleCache(rootDir: RuleStorage.userRulesDirectory())
        }
        clickWatcher = ClickWatcher(ruleCache: ruleCache) { event in
            ToastWindow.show(event: event)
            EventLogger.log(event: event)
        }
    }
```

- [ ] **Step 4: Build, verify no compile errors**

```bash
xcodebuild build -scheme SFlow -destination 'platform=macOS' 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Run existing tests, verify they still pass**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' 2>&1 | tail -20
```
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add SFlow/ClickWatcher.swift SFlow/AppDelegate.swift
git commit -m "feat: integrate RuleCache as Layer 0.5 in ClickWatcher"
```

---

## Phase C: Swift Discovery Client

### Task C1: `AXSkeletonExtractor` — filtered AX tree dump

**Why:** Produces the privacy-filtered list of buttons/links sent to the backend. Implements the filter rules from Spec Section 6.

**Files:**
- Create: `SFlow/AXSkeletonExtractor.swift`
- Create: `SFlowTests/AXSkeletonFilterTests.swift`

- [ ] **Step 1: Write failing tests (filter logic, no AX dependency)**

```swift
// SFlowTests/AXSkeletonFilterTests.swift
import XCTest
@testable import SFlow

final class AXSkeletonFilterTests: XCTestCase {
    func testAcceptsStaticButton() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXButton", title: "New Message"),
            RawAXItem(role: "AXButton", title: "New Message"),  // appears 2x → static
        ])
        XCTAssertEqual(items.count, 1)  // deduped
        XCTAssertEqual(items[0].title, "New Message")
    }

    func testRejectsTextField() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXTextField", title: "Search"),
        ])
        XCTAssertEqual(items.count, 0)
    }

    func testRejectsHashPrefixed() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXLink", title: "#general"),
            RawAXItem(role: "AXLink", title: "#general"),
            RawAXItem(role: "AXLink", title: "#general"),
        ])
        XCTAssertEqual(items.count, 0)
    }

    func testRejectsLongTitles() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXButton", title: String(repeating: "x", count: 100)),
            RawAXItem(role: "AXButton", title: String(repeating: "x", count: 100)),
        ])
        XCTAssertEqual(items.count, 0)
    }

    func testRejectsLikelyHumanNames() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXLink", title: "Anna Kowalska"),
            RawAXItem(role: "AXLink", title: "Anna Kowalska"),
        ])
        XCTAssertEqual(items.count, 0)
    }

    func testRejectsEmail() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXLink", title: "user@example.com"),
            RawAXItem(role: "AXLink", title: "user@example.com"),
        ])
        XCTAssertEqual(items.count, 0)
    }

    func testAcceptsSingletonVerbLed() {
        // Appears once, but starts with a verb → likely static UI label
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXButton", title: "Add channel"),
        ])
        XCTAssertEqual(items.count, 1)
    }

    func testRejectsSingletonNonVerbLed() {
        // Appears once, doesn't look like a verb
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXButton", title: "Foo Bar"),
        ])
        XCTAssertEqual(items.count, 0)
    }

    func testAllowedRoles() {
        let items = AXSkeletonExtractor.filter(rawItems: [
            RawAXItem(role: "AXButton", title: "Send Message"),
            RawAXItem(role: "AXLink", title: "Open Settings"),
            RawAXItem(role: "AXMenuItem", title: "Save File"),
            RawAXItem(role: "AXCheckBox", title: "Show Notifications"),
            RawAXItem(role: "AXRadioButton", title: "Use Light Theme"),
            RawAXItem(role: "AXPopUpButton", title: "Choose Language"),
            RawAXItem(role: "AXStaticText", title: "Hello world"),   // rejected
            RawAXItem(role: "AXWindow", title: "Main"),               // rejected
        ])
        XCTAssertEqual(items.count, 6)
    }

    func testCapsTotalCount() {
        let many = (0..<700).map { RawAXItem(role: "AXButton", title: "Button \($0)") }
        let items = AXSkeletonExtractor.filter(rawItems: many)
        XCTAssertLessThanOrEqual(items.count, 500)
    }
}
```

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement filter (no AX dependency in this file)**

```swift
// SFlow/AXSkeletonExtractor.swift
import Foundation
import ApplicationServices

struct RawAXItem: Hashable {
    let role: String
    let title: String
}

struct SkeletonItem: Codable, Hashable {
    let role: String
    let title: String
}

enum AXSkeletonExtractor {
    private static let allowedRoles: Set<String> = [
        "AXButton", "AXLink", "AXMenuItem",
        "AXCheckBox", "AXRadioButton", "AXPopUpButton",
    ]
    private static let maxTitleLen = 50
    private static let maxItems = 500

    static func filter(rawItems: [RawAXItem]) -> [SkeletonItem] {
        // Count occurrences before filtering
        var counts: [RawAXItem: Int] = [:]
        for item in rawItems where allowedRoles.contains(item.role) {
            counts[item, default: 0] += 1
        }

        var result: [SkeletonItem] = []
        var seen: Set<RawAXItem> = []

        for item in rawItems {
            if !allowedRoles.contains(item.role) { continue }
            if seen.contains(item) { continue }
            seen.insert(item)

            let title = item.title.trimmingCharacters(in: .whitespaces)
            if title.isEmpty || title.count > maxTitleLen { continue }
            if startsWithSensitivePrefix(title) { continue }
            if looksLikeEmail(title) { continue }
            if looksLikeISODate(title) { continue }
            if looksLikePureDigits(title) { continue }
            if looksLikeHumanName(title) { continue }

            let count = counts[item] ?? 1
            if count < 2 && !looksVerbLed(title) { continue }

            result.append(SkeletonItem(role: item.role, title: title))
            if result.count >= maxItems { break }
        }

        return result
    }

    private static let sensitivePrefixes: [Character] = ["#", "@"]
    private static func startsWithSensitivePrefix(_ s: String) -> Bool {
        guard let first = s.first else { return false }
        if sensitivePrefixes.contains(first) { return true }
        return s.hasPrefix("https://") || s.hasPrefix("http://")
    }

    private static let emailRegex = try! NSRegularExpression(pattern: #"^[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}$"#)
    private static func looksLikeEmail(_ s: String) -> Bool {
        emailRegex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    private static let isoDateRegex = try! NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}"#)
    private static func looksLikeISODate(_ s: String) -> Bool {
        isoDateRegex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    private static func looksLikePureDigits(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { $0.isNumber || $0.isPunctuation || $0.isWhitespace }
    }

    /// Approximate "First Last" pattern: exactly 2 words, each starts with uppercase + lowercase.
    private static let humanNameRegex = try! NSRegularExpression(pattern: #"^[A-ZŁŚŻŹĆŃÓ][a-ząęłśżźćń]+ [A-ZŁŚŻŹĆŃÓ][a-ząęłśżźćń]+$"#)
    private static func looksLikeHumanName(_ s: String) -> Bool {
        humanNameRegex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    private static let verbs: Set<String> = [
        "new", "add", "create", "delete", "remove", "edit", "save", "open", "close",
        "send", "reply", "forward", "archive", "star", "pin", "mute", "unmute",
        "search", "find", "go", "show", "hide", "toggle", "switch", "select",
        "copy", "paste", "cut", "undo", "redo", "view", "share", "export", "import",
        "download", "upload", "refresh", "reload", "sign", "log", "join", "leave",
    ]
    private static func looksVerbLed(_ s: String) -> Bool {
        guard let first = s.lowercased().split(separator: " ").first else { return false }
        return verbs.contains(String(first))
    }

    // MARK: - Live AX walk (used at runtime, not in tests)

    static func extract(for app: NSRunningApplication, maxNodes: Int = 5000) -> [SkeletonItem] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var raw: [RawAXItem] = []
        walk(axApp, depth: 0, maxDepth: 6, count: &raw, max: maxNodes)
        return filter(rawItems: raw)
    }

    private static func walk(_ element: AXUIElement, depth: Int, maxDepth: Int,
                              count raw: inout [RawAXItem], max: Int) {
        if raw.count >= max { return }
        if depth > maxDepth { return }

        var roleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""

        if allowedRoles.contains(role) {
            var titleRef: AnyObject?
            var descRef: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
            AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
            let title = (titleRef as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? (descRef as? String) ?? ""
            if !title.isEmpty {
                raw.append(RawAXItem(role: role, title: title))
            }
        }

        var childrenRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        if let children = childrenRef as? [AXUIElement] {
            for child in children {
                walk(child, depth: depth + 1, maxDepth: maxDepth, count: &raw, max: max)
            }
        }
    }
}

import AppKit
```

- [ ] **Step 4: Run tests, expect PASS**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' -only-testing:SFlowTests/AXSkeletonFilterTests 2>&1 | tail -30
```

- [ ] **Step 5: Commit**

```bash
git add SFlow/AXSkeletonExtractor.swift SFlowTests/AXSkeletonFilterTests.swift
git commit -m "feat: AXSkeletonExtractor with privacy filter (deny content, allow static UI)"
```

---

### Task C2: Menu bar dumper for discovery requests

**Why:** Backend needs a flat list of `[{path, shortcut}]`. Existing `MenuBarIndex` builds `titleMap` but the path is lost. We need a separate dump that preserves paths.

**Files:**
- Create: `SFlow/MenuBarDumper.swift`
- Create: `SFlowTests/MenuBarDumperTests.swift`

- [ ] **Step 1: Write a test for shortcut formatting (pure function)**

```swift
// SFlowTests/MenuBarDumperTests.swift
import XCTest
@testable import SFlow

final class MenuBarDumperTests: XCTestCase {
    func testFormatShortcutCmdN() {
        let s = MenuBarDumper.formatShortcut(cmdChar: "n", rawMods: 0)
        XCTAssertEqual(s, "cmd+n")
    }

    func testFormatShortcutCmdShiftK() {
        // bit 0 = shift
        let s = MenuBarDumper.formatShortcut(cmdChar: "k", rawMods: 0x01)
        XCTAssertEqual(s, "cmd+shift+k")
    }

    func testFormatShortcutNoCmd() {
        // bit 3 (0x08) set = cmd NOT used
        let s = MenuBarDumper.formatShortcut(cmdChar: "f", rawMods: 0x08)
        XCTAssertEqual(s, "f")
    }

    func testFormatShortcutAllModifiers() {
        let s = MenuBarDumper.formatShortcut(cmdChar: "a", rawMods: 0x01 | 0x02 | 0x04)
        XCTAssertEqual(s, "cmd+shift+alt+ctrl+a")
    }

    func testFormatShortcutEmpty() {
        XCTAssertNil(MenuBarDumper.formatShortcut(cmdChar: "", rawMods: 0))
    }
}
```

- [ ] **Step 2: Implement**

```swift
// SFlow/MenuBarDumper.swift
import AppKit
import ApplicationServices

struct MenuBarDumpEntry: Codable {
    let path: [String]
    let shortcut: String?
}

enum MenuBarDumper {
    static func dump(for app: NSRunningApplication) -> [MenuBarDumpEntry] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var menuBarRef: AnyObject?
        guard AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString,
                                            &menuBarRef) == .success,
              let menuBar = menuBarRef else { return [] }
        var out: [MenuBarDumpEntry] = []
        walk(menuBar as! AXUIElement, path: [], out: &out, depth: 0)
        return out
    }

    private static func walk(_ element: AXUIElement, path: [String],
                              out: inout [MenuBarDumpEntry], depth: Int) {
        guard depth < 5 else { return }
        var childrenRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        guard let children = childrenRef as? [AXUIElement] else { return }

        for child in children {
            var roleRef: AnyObject?
            var titleRef: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef)
            let role = roleRef as? String ?? ""
            let title = titleRef as? String ?? ""

            if role == "AXMenuItem" {
                var cmdCharRef: AnyObject?
                var cmdModsRef: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXMenuItemCmdCharAttribute as CFString, &cmdCharRef)
                AXUIElementCopyAttributeValue(child, kAXMenuItemCmdModifiersAttribute as CFString, &cmdModsRef)
                let cmdChar = (cmdCharRef as? String) ?? ""
                let rawMods = (cmdModsRef as? Int) ?? 0
                let shortcut = formatShortcut(cmdChar: cmdChar, rawMods: rawMods)

                if !title.isEmpty {
                    out.append(MenuBarDumpEntry(path: path + [title], shortcut: shortcut))
                }
            }

            let newPath = title.isEmpty ? path : (depth == 0 ? [title] : path + [title])
            walk(child, path: newPath, out: &out, depth: depth + 1)
        }
    }

    /// Returns "cmd+shift+k" form. nil if no shortcut character.
    static func formatShortcut(cmdChar: String, rawMods: Int) -> String? {
        let key = cmdChar.lowercased()
        guard !key.isEmpty else { return nil }
        var parts: [String] = []
        if rawMods & 0x08 == 0 { parts.append("cmd") }
        if rawMods & 0x01 != 0 { parts.append("shift") }
        if rawMods & 0x02 != 0 { parts.append("alt") }
        if rawMods & 0x04 != 0 { parts.append("ctrl") }
        parts.append(key)
        return parts.joined(separator: "+")
    }
}
```

- [ ] **Step 3: Run, expect PASS**

- [ ] **Step 4: Commit**

```bash
git add SFlow/MenuBarDumper.swift SFlowTests/MenuBarDumperTests.swift
git commit -m "feat: MenuBarDumper preserves full menu paths for discovery payload"
```

---

### Task C3: `DiscoveryClient` — POST to backend

**Why:** Single class responsible for the network call, request building, retry logic.

**Files:**
- Create: `SFlow/DiscoveryClient.swift`
- Create: `SFlowTests/DiscoveryClientTests.swift`

- [ ] **Step 1: Write failing test (request body shape)**

```swift
// SFlowTests/DiscoveryClientTests.swift
import XCTest
@testable import SFlow

final class DiscoveryClientTests: XCTestCase {
    func testBuildsCorrectRequestBody() throws {
        let body = DiscoveryClient.buildRequestBody(
            bundleId: "com.x",
            appName: "X",
            appVersion: "1.0.5",
            menuBar: [MenuBarDumpEntry(path: ["File", "New"], shortcut: "cmd+n")],
            skeleton: [SkeletonItem(role: "AXButton", title: "Send")],
            clientVersion: "1.0.0"
        )
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        XCTAssertEqual(json["bundleId"] as? String, "com.x")
        XCTAssertEqual(json["appVersion"] as? String, "1.0.5")
        XCTAssertEqual((json["menuBar"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((json["uiSkeleton"] as? [[String: Any]])?.count, 1)
    }

    func testParsesBackendResponse() throws {
        let json = #"""
        {
          "bundleId": "com.x",
          "rulesVersion": "2026-05-11T00:00:00Z",
          "rules": [
            {
              "match": {"role": "AXButton", "titles": ["Send"]},
              "keys": ["meta", "enter"],
              "hint": "Send",
              "confidence": "high",
              "source": "menu_bar"
            }
          ]
        }
        """#.data(using: .utf8)!
        let result = try DiscoveryClient.parseResponse(json)
        XCTAssertEqual(result.bundleId, "com.x")
        XCTAssertEqual(result.rules.count, 1)
    }
}
```

- [ ] **Step 2: Implement**

```swift
// SFlow/DiscoveryClient.swift
import Foundation

enum DiscoveryClientError: Error {
    case http(Int, String)
    case malformedResponse(String)
    case rateLimited(retryAfterSeconds: Int)
}

final class DiscoveryClient {
    private let baseURL: URL
    private let clientVersion: String
    private let session: URLSession

    init(baseURL: URL, clientVersion: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.clientVersion = clientVersion
        self.session = session
    }

    /// Default for production. Replace before shipping with the URL from Task A8.
    static let productionURL = URL(string: "https://sflow-rules.YOUR-SUBDOMAIN.workers.dev")!

    func discover(
        bundleId: String,
        appName: String,
        appVersion: String,
        menuBar: [MenuBarDumpEntry],
        skeleton: [SkeletonItem]
    ) async throws -> BackendRuleSet {
        let url = baseURL.appendingPathComponent("v1/discover")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = DiscoveryClient.buildRequestBody(
            bundleId: bundleId, appName: appName, appVersion: appVersion,
            menuBar: menuBar, skeleton: skeleton, clientVersion: clientVersion
        )
        req.timeoutInterval = 90  // backend may spend up to ~45s talking to Claude

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw DiscoveryClientError.malformedResponse("not HTTP")
        }
        if http.statusCode == 429 {
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init) ?? 3600
            throw DiscoveryClientError.rateLimited(retryAfterSeconds: retry)
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw DiscoveryClientError.http(http.statusCode, bodyText)
        }
        return try DiscoveryClient.parseResponse(data)
    }

    static func buildRequestBody(
        bundleId: String, appName: String, appVersion: String,
        menuBar: [MenuBarDumpEntry], skeleton: [SkeletonItem],
        clientVersion: String
    ) -> Data {
        struct Payload: Encodable {
            let bundleId: String
            let appName: String
            let appVersion: String
            let menuBar: [MenuBarDumpEntry]
            let uiSkeleton: [SkeletonItem]
            let clientVersion: String
        }
        let payload = Payload(
            bundleId: bundleId, appName: appName, appVersion: appVersion,
            menuBar: menuBar, uiSkeleton: skeleton, clientVersion: clientVersion
        )
        return try! JSONEncoder().encode(payload)
    }

    static func parseResponse(_ data: Data) throws -> BackendRuleSet {
        do {
            return try JSONDecoder().decode(BackendRuleSet.self, from: data)
        } catch {
            throw DiscoveryClientError.malformedResponse(error.localizedDescription)
        }
    }
}
```

**Note:** Before shipping, replace `YOUR-SUBDOMAIN` in `productionURL` with the real URL from Task A8.

- [ ] **Step 3: Run, expect PASS**

- [ ] **Step 4: Commit**

```bash
git add SFlow/DiscoveryClient.swift SFlowTests/DiscoveryClientTests.swift
git commit -m "feat: DiscoveryClient with request builder and response parser"
```

---

### Task C4: `DiscoveryService` — orchestrate background discovery on app activation

**Why:** Glues everything together. When a new app becomes frontmost and we don't have rules for it, kick off discovery, save the result, and reload the rule cache.

**Files:**
- Create: `SFlow/DiscoveryService.swift`

- [ ] **Step 1: Implement**

```swift
// SFlow/DiscoveryService.swift
import AppKit
import Foundation

/// Status changes emitted to the UI indicator.
enum DiscoveryStatus {
    case idle
    case running(appName: String)
    case completed(appName: String)
    case failed(appName: String, message: String)
}

final class DiscoveryService {
    private let client: DiscoveryClient
    private let ruleCache: RuleCache
    private let rulesDir: URL
    private var inFlight: Set<String> = []
    private var attempted: Set<String> = []
    private let queue = DispatchQueue(label: "com.filip.sflow.discovery", qos: .utility)
    var onStatusChange: ((DiscoveryStatus) -> Void)?

    init(client: DiscoveryClient, ruleCache: RuleCache, rulesDir: URL) {
        self.client = client
        self.ruleCache = ruleCache
        self.rulesDir = rulesDir
    }

    func observeAppActivation() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
        guard let bundleId = app.bundleIdentifier else { return }
        if ruleCache.hasRules(bundleId: bundleId) { return }
        if attempted.contains(bundleId) { return }
        if inFlight.contains(bundleId) { return }
        attempted.insert(bundleId)
        inFlight.insert(bundleId)

        let appName = app.localizedName ?? bundleId
        let appVersion = readAppVersion(app) ?? "unknown"
        onStatusChange?(.running(appName: appName))

        queue.async { [weak self] in
            guard let self else { return }
            let menuBar = MenuBarDumper.dump(for: app)
            let skeleton = AXSkeletonExtractor.extract(for: app)
            Task { [weak self] in
                guard let self else { return }
                do {
                    let result = try await self.client.discover(
                        bundleId: bundleId, appName: appName, appVersion: appVersion,
                        menuBar: menuBar, skeleton: skeleton
                    )
                    try self.writeToCache(bundleId: bundleId, appVersion: appVersion, result: result)
                    try self.ruleCache.load()
                    await MainActor.run { self.onStatusChange?(.completed(appName: appName)) }
                } catch {
                    await MainActor.run {
                        self.onStatusChange?(.failed(appName: appName, message: "\(error)"))
                    }
                }
                self.inFlight.remove(bundleId)
            }
        }
    }

    private func writeToCache(bundleId: String, appVersion: String, result: BackendRuleSet) throws {
        let cacheDir = rulesDir.appendingPathComponent("cache")
        try RuleStorage.ensureDirectory(cacheDir)
        let stored = StoredRuleSet(
            bundleId: bundleId,
            appVersion: appVersion,
            fetchedAt: ISO8601DateFormatter().string(from: Date()),
            source: .cloud,
            rulesVersion: result.rulesVersion,
            rules: result.rules
        )
        let data = try JSONEncoder().encode(stored)
        try data.write(to: cacheDir.appendingPathComponent("\(bundleId).json"))
    }

    private func readAppVersion(_ app: NSRunningApplication) -> String? {
        guard let url = app.bundleURL else { return nil }
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: plistURL) else { return nil }
        return (dict["CFBundleShortVersionString"] as? String) ?? (dict["CFBundleVersion"] as? String)
    }
}
```

- [ ] **Step 2: Verify build**

```bash
xcodebuild build -scheme SFlow -destination 'platform=macOS' 2>&1 | tail -10
```

- [ ] **Step 3: Commit**

```bash
git add SFlow/DiscoveryService.swift
git commit -m "feat: DiscoveryService triggers background discovery on app activation"
```

---

### Task C5: Menu bar "Learning [App]..." indicator

**Why:** User feedback. Subtle status while LLM is generating rules.

**Files:**
- Modify: `SFlow/AppDelegate.swift`

- [ ] **Step 1: Add status-tracking properties and indicator update method**

In `SFlow/AppDelegate.swift`, just below the `clickWatcher` property (line 6 area):

```swift
    private var discoveryService: DiscoveryService?
    private var statusIndicatorText: String = ""
```

Add this method anywhere in the class:

```swift
    private func updateStatusItemTitle(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.statusItem?.button else { return }
            self.statusIndicatorText = text
            if text.isEmpty {
                button.title = ""
            } else {
                button.title = " " + text   // small offset from the ⌘ icon
            }
        }
    }
```

- [ ] **Step 2: Wire `DiscoveryService` into `startWatcher()`**

Replace the `startWatcher()` body with:

```swift
    private func startWatcher() {
        do {
            try RuleStorage.seedBundledIfMissing()
            ruleCache = RuleCache(rootDir: RuleStorage.userRulesDirectory())
            try ruleCache.load()
        } catch {
            NSLog("SFlow: RuleCache load failed: \(error)")
            ruleCache = RuleCache(rootDir: RuleStorage.userRulesDirectory())
        }

        let client = DiscoveryClient(
            baseURL: DiscoveryClient.productionURL,
            clientVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        )
        discoveryService = DiscoveryService(
            client: client,
            ruleCache: ruleCache,
            rulesDir: RuleStorage.userRulesDirectory()
        )
        discoveryService?.onStatusChange = { [weak self] status in
            switch status {
            case .idle:
                self?.updateStatusItemTitle("")
            case .running(let name):
                self?.updateStatusItemTitle("✨ Learning \(name)…")
            case .completed:
                self?.updateStatusItemTitle("")
            case .failed:
                self?.updateStatusItemTitle("")
            }
        }
        discoveryService?.observeAppActivation()

        clickWatcher = ClickWatcher(ruleCache: ruleCache) { event in
            ToastWindow.show(event: event)
            EventLogger.log(event: event)
        }
    }
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -scheme SFlow -destination 'platform=macOS' 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add SFlow/AppDelegate.swift
git commit -m "feat: menu-bar 'Learning [App]…' indicator during discovery"
```

---

### Task C6: Plug real worker URL and manual E2E test

**Files:**
- Modify: `SFlow/DiscoveryClient.swift`

- [ ] **Step 1: Replace placeholder URL**

In `SFlow/DiscoveryClient.swift`, change `productionURL` to the URL from Task A8:

```swift
static let productionURL = URL(string: "https://sflow-rules.YOUR-ACTUAL-SUBDOMAIN.workers.dev")!
```

- [ ] **Step 2: Build and run the app**

```bash
xcodebuild build -scheme SFlow -configuration Debug -derivedDataPath /tmp/sflow-build 2>&1 | tail -10
open /tmp/sflow-build/Build/Products/Debug/SFlow.app
```

- [ ] **Step 3: Manual E2E test — discover a new app**

1. Grant SFlow Accessibility + Input Monitoring permissions if prompted.
2. Open an app SFlow has never seen — e.g. **Cursor**, **Zed**, or **Obsidian**.
3. Within ~10 seconds the menu bar shows `✨ Learning <AppName>…`.
4. After 15-45 seconds the indicator disappears.
5. Click a button you know has a shortcut (e.g. the search button in Obsidian).
6. Verify toast appears with the correct shortcut.
7. Check the cache file exists:
   ```bash
   ls -la ~/Library/Application\ Support/SFlow/rules/cache/
   ```
   You should see a JSON file for the bundle id you tested.
8. Click `cat` on the file to inspect generated rules.

- [ ] **Step 4: Commit URL change**

```bash
git add SFlow/DiscoveryClient.swift
git commit -m "chore: point DiscoveryClient at deployed production worker"
```

---

## Phase D: Bundled Rules Seed Pipeline

### Task D1: Add a `--seed` CLI mode to SFlow

**Why:** Build-time generation of `bundled.json` uses the same code path as runtime discovery, eliminating drift.

**Files:**
- Modify: `SFlow/main.swift`
- Create: `SFlow/SeedMode.swift`

- [ ] **Step 1: Modify main.swift to branch on `--seed` arg**

```swift
// SFlow/main.swift
import AppKit

if CommandLine.arguments.contains("--seed") {
    let args = CommandLine.arguments.filter { $0 != "--seed" }
    let bundleId = args.last
    SeedMode.run(bundleIdArg: bundleId)
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 2: Implement SeedMode**

```swift
// SFlow/SeedMode.swift
import AppKit
import Foundation

enum SeedMode {
    static func run(bundleIdArg: String?) {
        guard let bundleId = bundleIdArg else {
            print("usage: SFlow --seed <bundleId>")
            return
        }

        // Find the running app
        let running = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleId }
        guard let app = running else {
            print("error: app \(bundleId) is not running. Launch it first.")
            return
        }

        let appName = app.localizedName ?? bundleId
        let appVersion = readVersion(app) ?? "unknown"
        let menuBar = MenuBarDumper.dump(for: app)
        let skeleton = AXSkeletonExtractor.extract(for: app)

        print("Seeding \(appName) (\(bundleId) v\(appVersion)) — \(menuBar.count) menu items, \(skeleton.count) UI items")

        let client = DiscoveryClient(baseURL: DiscoveryClient.productionURL, clientVersion: "seed")
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<BackendRuleSet, Error>!

        Task {
            do {
                let r = try await client.discover(
                    bundleId: bundleId, appName: appName, appVersion: appVersion,
                    menuBar: menuBar, skeleton: skeleton
                )
                result = .success(r)
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()

        switch result! {
        case .success(let rs):
            let stored = StoredRuleSet(
                bundleId: rs.bundleId,
                appVersion: appVersion,
                fetchedAt: ISO8601DateFormatter().string(from: Date()),
                source: .bundled,
                rulesVersion: rs.rulesVersion,
                rules: rs.rules
            )
            // Output to stdout — caller redirects to a file.
            let data = try! JSONEncoder().encode(stored)
            FileHandle.standardOutput.write(data)
            print("")
        case .failure(let err):
            print("error: \(err)")
        }
    }

    private static func readVersion(_ app: NSRunningApplication) -> String? {
        guard let url = app.bundleURL else { return nil }
        let dict = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist"))
        return (dict?["CFBundleShortVersionString"] as? String) ?? (dict?["CFBundleVersion"] as? String)
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -scheme SFlow -destination 'platform=macOS' 2>&1 | tail -10
```

- [ ] **Step 4: Commit**

```bash
git add SFlow/main.swift SFlow/SeedMode.swift
git commit -m "feat: --seed CLI mode for generating bundled rules"
```

---

### Task D2: Seed script for the 4 verified apps

**Files:**
- Create: `scripts/seed-bundled.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# scripts/seed-bundled.sh
# Build SFlow, then call --seed for each of the 4 verified apps.
# Each target app MUST be running before this script runs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="/tmp/sflow-seed-build"

APPS=(
  "com.tinyspeck.slackmacgap"
  "com.apple.Terminal"
  "notion.id"
  "com.anthropic.claudefordesktop"
)

echo "Building SFlow (debug)…"
xcodebuild build \
  -scheme SFlow -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS' >/dev/null

BIN="$BUILD_DIR/Build/Products/Debug/SFlow.app/Contents/MacOS/SFlow"
if [ ! -x "$BIN" ]; then
  echo "error: SFlow binary not found at $BIN" >&2
  exit 1
fi

OUT="$ROOT/SFlow/Resources/bundled.json"
mkdir -p "$(dirname "$OUT")"
echo "[" > "$OUT"

FIRST=1
for BUNDLE in "${APPS[@]}"; do
  if ! pgrep -lf "$BUNDLE" >/dev/null 2>&1; then
    if ! osascript -e "exists application id \"$BUNDLE\"" >/dev/null 2>&1; then
      echo "skip $BUNDLE (not installed)"
      continue
    fi
    echo "warning: $BUNDLE is not currently running; AX dump will be empty"
  fi
  echo "Seeding $BUNDLE …"
  TMP="$(mktemp)"
  if "$BIN" --seed "$BUNDLE" > "$TMP" 2>/dev/null; then
    if [ "$FIRST" -eq 0 ]; then echo "," >> "$OUT"; fi
    cat "$TMP" >> "$OUT"
    FIRST=0
  else
    echo "  failed (see error output)"
  fi
  rm -f "$TMP"
done

echo "" >> "$OUT"
echo "]" >> "$OUT"
echo "Wrote $OUT"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/seed-bundled.sh
```

- [ ] **Step 3: Smoke test against one app**

Launch Slack manually first, then:
```bash
./scripts/seed-bundled.sh
```
Expected: `SFlow/Resources/bundled.json` exists with at least the Slack entry.

- [ ] **Step 4: Commit**

```bash
git add scripts/seed-bundled.sh SFlow/Resources/bundled.json
git commit -m "feat: seed script generates bundled.json from production worker"
```

---

### Task D3: Embed `bundled.json` as a bundled resource

**Why:** The Swift app needs to find `bundled.json` inside its own `.app` bundle. Currently `RuleStorage.seedBundledIfMissing()` already looks for it via `Bundle.main.url(forResource: "bundled", withExtension: "json")`.

**Files:**
- Modify: `SFlow.xcodeproj/project.pbxproj` (via Xcode UI, not by hand-editing)

- [ ] **Step 1: Add `bundled.json` to the app target**

Open Xcode → SFlow project → SFlow target → Build Phases → Copy Bundle Resources → `+` → Add Other → select `SFlow/Resources/bundled.json`.

- [ ] **Step 2: Verify it ships**

```bash
xcodebuild build -scheme SFlow -destination 'platform=macOS' -derivedDataPath /tmp/sflow-bundled 2>&1 | tail -5
find /tmp/sflow-bundled -name bundled.json
```
Expected: file exists inside `.app/Contents/Resources/bundled.json`.

- [ ] **Step 3: Manual sanity test**

Delete `~/Library/Application Support/SFlow/rules/bundled.json`, relaunch app, check the file gets recreated automatically and contains the 4 apps.

```bash
rm -f ~/Library/Application\ Support/SFlow/rules/bundled.json
open /tmp/sflow-bundled/Build/Products/Debug/SFlow.app
sleep 2
cat ~/Library/Application\ Support/SFlow/rules/bundled.json | head -5
```

- [ ] **Step 4: Commit (project.pbxproj change)**

```bash
git add SFlow.xcodeproj/project.pbxproj
git commit -m "build: ship bundled.json as app resource"
```

---

## Phase E (deferred): Pro Tier with BYOK

*Out of scope for v1 ship. Sketch only — implement later when there's paying demand.*

### Task E1: Settings window with API key field
### Task E2: Keychain storage for the key
### Task E3: Branch in DiscoveryClient to use direct Anthropic API when key present
### Task E4: "Disable telemetry" toggle

---

## Phase F (deferred): Feedback Loop

*Out of scope for v1 ship.*

### Task F1: Backend `/v1/feedback` endpoint with aggregation
### Task F2: Toast "wrong?" affordance (cmd-click)
### Task F3: Local override storage in `user_overrides.json`
### Task F4: Server-side auto-disable threshold (≥5 reports → remove rule, trigger re-discovery)

---

## Post-Phase: Cleanup and Ship

### Task Z1: Remove temporary NSLog debug statements

**Files:**
- Modify: `SFlow/ClickWatcher.swift`

- [ ] **Step 1: Remove the three `// tmp` NSLog lines** around `ClickWatcher.swift:86-88`.

- [ ] **Step 2: Build, run full test suite**

```bash
xcodebuild test -scheme SFlow -destination 'platform=macOS' 2>&1 | tail -10
```

- [ ] **Step 3: Commit**

```bash
git add SFlow/ClickWatcher.swift
git commit -m "chore: remove diagnostic NSLog statements"
```

### Task Z2: Update user-facing privacy doc

**Files:**
- Create: `docs/PRIVACY.md`

- [ ] **Step 1: Write the privacy doc** (use the user-facing copy from Spec Section 6).

```markdown
# SFlow Privacy

SFlow never sends your messages, channel names, document contents, or anything you type.

When you open an app SFlow has not seen before, SFlow sends to our backend:
- The app's bundle identifier (e.g. `com.linear.electron`)
- The app's name and version
- The app's menu bar structure (e.g. `File > New Issue [cmd+n]`)
- A list of public button and link labels visible in the UI (e.g. `New issue`, `Inbox`) — filtered to exclude likely content such as channel names (`#…`), usernames (`@…`), email addresses, and human-name patterns

We never send:
- Text from any text field, message, or document you are editing
- Window titles, file names, or URLs you have open
- Telemetry tied to a user identity — discovery requests are anonymous

For apps where the UI is mostly content (Mail, Messages, 1Password, WhatsApp), SFlow only sends the menu bar.

Pro users can supply their own Anthropic API key in Settings; in that mode, discovery requests bypass our backend entirely.
```

- [ ] **Step 2: Commit**

```bash
git add docs/PRIVACY.md
git commit -m "docs: add user-facing privacy summary"
```

---

## Self-Review Notes

The plan covers spec sections 1-14 as follows:

| Spec Section | Implementation Tasks |
|---|---|
| §3 Architecture overview | A1-A8, B1-B4, C1-C5 |
| §4 User-facing flow | C4-C6 |
| §5 Backend API contract | A3, A7 |
| §6 Privacy filter | C1 |
| §7 Confidence model | A5 (prompt), B2 (matcher hides low) |
| §8 Local rule storage | B2, B3 |
| §9 Bundled-rules build pipeline | D1-D3 |
| §10 Pro tier BYOK | Phase E (deferred) |
| §11 Failure modes | A6 (rate limit), C4 (in-flight tracking), B4 (fallback to L1-L4) |
| §12 Testing | Embedded TDD steps in each task |

**Deferred but tracked:** §10 (Pro BYOK) and the feedback loop in §7 are explicitly Phase E/F.

**Open decisions still to make at implementation time** (per Spec §15): exact Pro pricing, exact indicator styling, community-shared-cache program, whether to open-source the backend.
