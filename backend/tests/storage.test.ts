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
