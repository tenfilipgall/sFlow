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
