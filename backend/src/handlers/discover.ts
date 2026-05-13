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

  const url = new URL(request.url);
  const skipCache = url.searchParams.get("fresh") === "1";

  // Cache lookup first — does not consume rate limit. Bypassed via ?fresh=1 (re-seed tool).
  if (!skipCache) {
    const cached = await getCachedRules(env.RULES_CACHE, req.bundleId, req.appVersion);
    if (cached) {
      return jsonResponse(cached);
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
