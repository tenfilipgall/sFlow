import { env, SELF } from "cloudflare:test";
import { describe, expect, it, beforeEach } from "vitest";

describe("POST /v1/feedback", () => {
  beforeEach(async () => {
    const list = await env.FEEDBACK.list();
    for (const k of list.keys) await env.FEEDBACK.delete(k.name);
  });

  it("returns 405 on GET", async () => {
    const r = await SELF.fetch("https://example.com/v1/feedback");
    expect(r.status).toBe(405);
  });

  it("returns 400 on missing fields", async () => {
    const r = await SELF.fetch("https://example.com/v1/feedback", {
      method: "POST",
      body: JSON.stringify({ bundleId: "com.x" }),
    });
    expect(r.status).toBe(400);
  });

  it("returns 200 and stores count in FEEDBACK KV", async () => {
    const r = await SELF.fetch("https://example.com/v1/feedback", {
      method: "POST",
      body: JSON.stringify({
        bundleId: "com.x",
        keys: ["meta", "k"],
        reportType: "wrong_shortcut",
      }),
    });
    expect(r.status).toBe(200);

    const raw = await env.FEEDBACK.get("feedback:com.x");
    expect(raw).not.toBeNull();
    const counts = JSON.parse(raw!);
    expect(counts["k+meta"]).toBe(1);
  });

  it("increments count on repeated reports", async () => {
    const body = JSON.stringify({
      bundleId: "com.x",
      keys: ["meta", "k"],
      reportType: "wrong_shortcut",
    });
    await SELF.fetch("https://example.com/v1/feedback", { method: "POST", body });
    await SELF.fetch("https://example.com/v1/feedback", { method: "POST", body });
    await SELF.fetch("https://example.com/v1/feedback", { method: "POST", body });

    const raw = await env.FEEDBACK.get("feedback:com.x");
    const counts = JSON.parse(raw!);
    expect(counts["k+meta"]).toBe(3);
  });
});
