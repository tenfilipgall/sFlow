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

describe("RuleSchema version normalization", () => {
  it("defaults missing version to 1", () => {
    const parsed = RuleSchema.parse({
      match: { role: "AXButton", titles: ["x"] },
      keys: ["meta", "k"],
      hint: "h",
      confidence: "high",
      source: "menu_bar",
    });
    expect(parsed.version).toBe(1);
  });

  it("preserves an explicit version", () => {
    const parsed = RuleSchema.parse({
      match: { role: "AXButton", titles: ["x"] },
      keys: ["meta", "k"],
      hint: "h",
      confidence: "high",
      source: "menu_bar",
      version: 1,
    });
    expect(parsed.version).toBe(1);
  });
});
