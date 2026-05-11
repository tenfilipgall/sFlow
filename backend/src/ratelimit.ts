/// <reference types="@cloudflare/workers-types" />

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
