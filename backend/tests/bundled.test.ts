import { env, SELF } from "cloudflare:test";
import { describe, expect, it, beforeEach } from "vitest";

describe("GET /v1/bundled", () => {
  beforeEach(async () => {
    await env.RULES_CACHE.delete("bundled:version");
    await env.RULES_CACHE.delete("bundled:latest");
  });

  it("returns 404 when not uploaded yet", async () => {
    const r = await SELF.fetch("https://example.com/v1/bundled");
    expect(r.status).toBe(404);
  });

  it("returns 405 on POST", async () => {
    const r = await SELF.fetch("https://example.com/v1/bundled", { method: "POST" });
    expect(r.status).toBe(405);
  });

  it("returns 200 with version and rules when uploaded", async () => {
    await env.RULES_CACHE.put("bundled:version", "2026-05-14T00:00:00Z");
    await env.RULES_CACHE.put(
      "bundled:latest",
      JSON.stringify([
        {
          bundleId: "com.x",
          appVersion: "1.0",
          fetchedAt: "2026-05-14T00:00:00Z",
          source: "bundled",
          rulesVersion: "2026-05-14T00:00:00Z",
          rules: [],
        },
      ]),
    );
    const r = await SELF.fetch("https://example.com/v1/bundled");
    expect(r.status).toBe(200);
    const body = (await r.json()) as any;
    expect(body.version).toBe("2026-05-14T00:00:00Z");
    expect(body.rules).toHaveLength(1);
    expect(body.rules[0].bundleId).toBe("com.x");
  });
});
