import { describe, expect, it } from "vitest";
import { buildSystemPrompt, buildUserPrompt } from "../src/prompt";

describe("buildSystemPrompt", () => {
  it("mentions all four sources", () => {
    const p = buildSystemPrompt();
    expect(p).toContain("menu_bar");
    expect(p).toContain("web_docs_official");
    expect(p).toContain("web_docs_third_party");
    expect(p).toContain("inferred_pattern");
  });
});

describe("buildUserPrompt", () => {
  it("formats menu bar paths with shortcuts", () => {
    const result = buildUserPrompt({
      bundleId: "com.x",
      appName: "X",
      appVersion: "1.0",
      menuBar: [{ path: ["File", "New"], shortcut: "cmd+n" }],
      uiSkeleton: [],
      clientVersion: "1.0",
    });
    expect(result).toContain("File > New [cmd+n]");
  });

  it("handles empty menu bar gracefully", () => {
    const result = buildUserPrompt({
      bundleId: "com.x",
      appName: "X",
      appVersion: "1.0",
      menuBar: [],
      uiSkeleton: [{ role: "AXButton", title: "Send" }],
      clientVersion: "1.0",
    });
    expect(result).toContain("(empty)");
    expect(result).toContain('AXButton: "Send"');
  });
});
