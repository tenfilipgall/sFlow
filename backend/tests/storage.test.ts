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

  describe("cacheKey locale suffix (Sub-cel 1.20)", () => {
    it("omits suffix for English / null / undefined locale", () => {
      expect(cacheKey("com.x", "1.2.3")).toBe("rules:com.x:1.2");
      expect(cacheKey("com.x", "1.2.3", null)).toBe("rules:com.x:1.2");
      expect(cacheKey("com.x", "1.2.3", undefined)).toBe("rules:com.x:1.2");
      expect(cacheKey("com.x", "1.2.3", "en")).toBe("rules:com.x:1.2");
      // case-insensitive EN check
      expect(cacheKey("com.x", "1.2.3", "EN")).toBe("rules:com.x:1.2");
    });

    it("appends locale suffix for non-English", () => {
      expect(cacheKey("com.x", "1.2.3", "pl")).toBe("rules:com.x:1.2:pl");
      expect(cacheKey("com.x", "1.2.3", "de")).toBe("rules:com.x:1.2:de");
      expect(cacheKey("com.x", "1.2.3", "zh-Hans")).toBe("rules:com.x:1.2:zh-Hans");
    });

    it("keeps EN and PL caches separate end-to-end", async () => {
      const rulesEn = {
        bundleId: "com.x", rulesVersion: "v1",
        rules: [{ match: { role: "AXButton", titles: ["Compose"] },
                  keys: ["meta", "n"], hint: "Compose",
                  confidence: "high" as const, source: "menu_bar" as const }],
      };
      const rulesPl = {
        bundleId: "com.x", rulesVersion: "v1",
        rules: [{ match: { role: "AXButton", titles: ["Compose"],
                          localizedTitles: { pl: ["Skomponuj"] } },
                  keys: ["meta", "n"], hint: "Compose",
                  confidence: "high" as const, source: "menu_bar" as const }],
      };
      await putCachedRules(env.RULES_CACHE, "com.x", "1.0", rulesEn);
      await putCachedRules(env.RULES_CACHE, "com.x", "1.0", rulesPl, "pl");
      const en = await getCachedRules(env.RULES_CACHE, "com.x", "1.0");
      const pl = await getCachedRules(env.RULES_CACHE, "com.x", "1.0", "pl");
      expect(en).toEqual(rulesEn);
      expect(pl).toEqual(rulesPl);
    });
  });
});
