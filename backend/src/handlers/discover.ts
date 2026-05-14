import { DiscoverRequestSchema } from "../types";
import { getCachedRules, putCachedRules } from "../storage";
import { generateRules } from "../claude";
import { checkRateLimit } from "../ratelimit";
import type { Env } from "../index";

async function loadFlaggedKeys(
  feedback: KVNamespace,
  bundleId: string,
): Promise<Set<string>> {
  const raw = await feedback.get(`feedback:${bundleId}`);
  if (!raw) return new Set();
  const counts: Record<string, number> = JSON.parse(raw);
  return new Set(
    Object.entries(counts)
      .filter(([, count]) => count >= 3)
      .map(([key]) => key),
  );
}

function applyFeedbackFilter(
  ruleSet: { bundleId: string; rulesVersion: string; rules: Array<{ keys: string[]; [key: string]: unknown }> },
  flaggedKeys: Set<string>,
): typeof ruleSet {
  if (flaggedKeys.size === 0) return ruleSet;
  return {
    ...ruleSet,
    rules: ruleSet.rules.filter(
      (rule) => !flaggedKeys.has([...rule.keys].sort().join("+")),
    ),
  };
}

export async function handleDiscover(
  request: Request,
  env: Env,
): Promise<Response> {
  const start = Date.now();

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

  const url = new URL(request.url);
  const skipCache = url.searchParams.get("fresh") === "1";

  // Cache lookup first — does not consume rate limit. Bypassed via ?fresh=1 (re-seed tool).
  if (!skipCache) {
    const cached = await getCachedRules(env.RULES_CACHE, req.bundleId, req.appVersion);
    if (cached) {
      const flaggedKeys = await loadFlaggedKeys(env.FEEDBACK, req.bundleId);
      const filtered = applyFeedbackFilter(cached as any, flaggedKeys);
      const c = filtered as { rules?: unknown[] };
      console.log(JSON.stringify({
        type: "discover", bundleId: req.bundleId, appVersion: req.appVersion,
        cacheHit: true, fresh: false, rulesGenerated: c.rules?.length ?? 0,
        flaggedFiltered: flaggedKeys.size,
        durationMs: Date.now() - start,
      }));
      return jsonResponse(filtered);
    }
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
    console.log(JSON.stringify({
      type: "discover", bundleId: req.bundleId, appVersion: req.appVersion,
      cacheHit: false, fresh: skipCache, error: (e as Error).message,
      durationMs: Date.now() - start,
    }));
    return jsonError(502, `LLM error: ${(e as Error).message}`);
  }

  await putCachedRules(env.RULES_CACHE, req.bundleId, req.appVersion, rules);
  console.log(JSON.stringify({
    type: "discover", bundleId: req.bundleId, appVersion: req.appVersion,
    cacheHit: false, fresh: skipCache, rulesGenerated: rules.rules.length,
    durationMs: Date.now() - start,
  }));
  const flaggedKeys = await loadFlaggedKeys(env.FEEDBACK, req.bundleId);
  const filtered = applyFeedbackFilter(rules as any, flaggedKeys);
  return jsonResponse(filtered);
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
