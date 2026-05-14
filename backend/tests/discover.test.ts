import { env, SELF } from "cloudflare:test";
import { describe, expect, it, beforeEach, vi } from "vitest";
import * as claudeModule from "../src/claude";

describe("POST /v1/discover", () => {
  beforeEach(async () => {
    for (const ns of [env.RULES_CACHE, env.RATE_LIMIT, env.FEEDBACK]) {
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
    const body = await r.json() as any;
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
    vi.spyOn(claudeModule, "generateRules").mockResolvedValue({
      bundleId: "com.app",
      rulesVersion: "2026-05-11T00:00:00Z",
      rules: [],
    });

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

  it("filters out rules flagged with count >= 3 from cached response", async () => {
    await env.RULES_CACHE.put(
      "rules:com.x:1.0",
      JSON.stringify({
        bundleId: "com.x",
        rulesVersion: "2026-05-14T00:00:00Z",
        rules: [
          {
            match: { role: "AXButton", titles: ["Send"] },
            keys: ["meta", "enter"],
            hint: "Send",
            confidence: "high",
            source: "menu_bar",
          },
          {
            match: { role: "AXButton", titles: ["New Issue"] },
            keys: ["meta", "k"],
            hint: "New Issue",
            confidence: "high",
            source: "menu_bar",
          },
        ],
      }),
    );
    await env.FEEDBACK.put(
      "feedback:com.x",
      JSON.stringify({ "k+meta": 3 }),
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
    const body = await r.json() as any;
    expect(body.rules).toHaveLength(1);
    expect(body.rules[0].keys).toEqual(["meta", "enter"]);
  });

  it("does not filter rules with count < 3", async () => {
    await env.RULES_CACHE.put(
      "rules:com.y:1.0",
      JSON.stringify({
        bundleId: "com.y",
        rulesVersion: "2026-05-14T00:00:00Z",
        rules: [
          {
            match: { role: "AXButton", titles: ["Save"] },
            keys: ["meta", "s"],
            hint: "Save",
            confidence: "high",
            source: "menu_bar",
          },
        ],
      }),
    );
    await env.FEEDBACK.put(
      "feedback:com.y",
      JSON.stringify({ "meta+s": 2 }),
    );

    const r = await SELF.fetch("https://example.com/v1/discover", {
      method: "POST",
      body: JSON.stringify({
        bundleId: "com.y",
        appName: "Y",
        appVersion: "1.0.7",
        menuBar: [],
        uiSkeleton: [],
        clientVersion: "1.0",
      }),
    });
    const body = await r.json() as any;
    expect(body.rules).toHaveLength(1);
  });
});
