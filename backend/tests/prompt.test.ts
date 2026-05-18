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

  it("includes [id=…] tag when skeleton item has identifier", () => {
    const result = buildUserPrompt({
      bundleId: "com.x",
      appName: "X",
      appVersion: "1.0",
      menuBar: [],
      uiSkeleton: [{ role: "AXButton", title: "Send", identifier: "send-btn" }],
      clientVersion: "1.0",
    });
    expect(result).toContain("[id=send-btn]");
  });
});

describe("buildSystemPrompt v1.1 prompt", () => {
  const prompt = buildSystemPrompt();

  it("instructs Claude to produce 3-5 title variants per rule", () => {
    expect(prompt).toMatch(/3[-–]5 variant/i);
    expect(prompt.toLowerCase()).toContain("verb-led");
    expect(prompt.toLowerCase()).toContain("noun-only");
  });

  it("includes few-shot examples block", () => {
    expect(prompt).toContain("Example 1");
    expect(prompt).toContain("Quick Switcher");
  });

  it("documents the version field in the schema", () => {
    expect(prompt).toContain('"version": 1');
  });

  it("instructs Claude to avoid overlapping titles across rules", () => {
    const prompt = buildSystemPrompt();
    expect(prompt).toMatch(/DISJOINT TITLES/);
    expect(prompt.toLowerCase()).toContain("merge");
  });

  it("instructs Claude on hotkey-suffix variants for Electron menu items", () => {
    const prompt = buildSystemPrompt();
    expect(prompt).toMatch(/HOTKEY[- ]SUFFIX/i);
    expect(prompt).toContain("Edit message E");
  });

  it("instructs Claude on explicit web_search step order (P-32)", () => {
    const prompt = buildSystemPrompt();
    expect(prompt).toMatch(/WEB_SEARCH STRATEGY/);
    expect(prompt).toContain("keyboard shortcuts cheatsheet");
    expect(prompt).toContain("hotkey list");
    expect(prompt).toMatch(/STEP 1/);
    expect(prompt).toMatch(/STEP 2/);
    expect(prompt).toMatch(/STEP 3/);
  });

  it("instructs Claude on localizedTitles for non-EN locales (P-43, Sub-cel 1.20)", () => {
    const prompt = buildSystemPrompt();
    expect(prompt).toMatch(/LOCALIZED TITLES/);
    expect(prompt).toContain("localizedTitles");
    expect(prompt).toMatch(/actual AX-exposed strings/);
    expect(prompt).toMatch(/NOT a literal translation/);
    // Supported locales mentioned
    expect(prompt).toContain("pl");
    expect(prompt).toContain("zh-Hans");
  });
});

describe("buildUserPrompt locale hint (Sub-cel 1.20)", () => {
  it("emits PL hint when appLocale=pl", () => {
    const result = buildUserPrompt({
      bundleId: "com.tinyspeck.slackmacgap",
      appName: "Slack",
      appVersion: "4.0.0",
      appLocale: "pl",
      menuBar: [],
      uiSkeleton: [],
      clientVersion: "1.0",
    });
    expect(result).toContain("App locale: pl");
    expect(result).toContain('localizedTitles.pl');
    expect(result).toMatch(/NOT literal translations/);
  });

  it("emits default EN hint when appLocale missing", () => {
    const result = buildUserPrompt({
      bundleId: "com.x",
      appName: "X",
      appVersion: "1.0",
      menuBar: [],
      uiSkeleton: [],
      clientVersion: "1.0",
    });
    expect(result).toContain("App locale: en");
    expect(result).toContain("localizedTitles optional");
  });

  it("emits default EN hint when appLocale=en", () => {
    const result = buildUserPrompt({
      bundleId: "com.x",
      appName: "X",
      appVersion: "1.0",
      appLocale: "en",
      menuBar: [],
      uiSkeleton: [],
      clientVersion: "1.0",
    });
    expect(result).toContain("App locale: en");
  });
});
