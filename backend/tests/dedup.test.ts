import { describe, it, expect } from "vitest";
import { dedupOverlappingRules } from "../src/dedup";
import type { RuleSet, Rule } from "../src/types";

function r(
  title: string,
  keys: string[],
  source: Rule["source"] = "inferred_pattern",
  confidence: Rule["confidence"] = "medium",
  extraTitles: string[] = []
): Rule {
  return {
    match: { role: "AXButton", titles: [title, ...extraTitles] },
    keys,
    hint: title,
    confidence,
    source,
    version: 1,
  };
}

function makeSet(rules: Rule[]): RuleSet {
  return { bundleId: "test", rulesVersion: "v1", rules };
}

describe("dedupOverlappingRules", () => {
  it("returns unchanged set when no overlaps", () => {
    const set = makeSet([r("A", ["meta", "a"]), r("B", ["meta", "b"])]);
    const { result, dropped } = dedupOverlappingRules(set);
    expect(result.rules.length).toBe(2);
    expect(dropped).toEqual([]);
  });

  it("drops second rule when titles overlap and confidences equal", () => {
    const set = makeSet([r("Search", ["meta", "g"]), r("Search", ["meta", "f"])]);
    const { result, dropped } = dedupOverlappingRules(set);
    expect(result.rules.length).toBe(1);
    expect(result.rules[0].keys).toEqual(["meta", "g"]);
    expect(dropped.length).toBe(1);
  });

  it("prefers menu_bar source over inferred_pattern", () => {
    const set = makeSet([
      r("Foo", ["meta", "a"], "inferred_pattern", "high"),
      r("Foo", ["meta", "b"], "menu_bar", "high"),
    ]);
    const { result } = dedupOverlappingRules(set);
    expect(result.rules.length).toBe(1);
    expect(result.rules[0].keys).toEqual(["meta", "b"]);
    expect(result.rules[0].source).toBe("menu_bar");
  });

  it("prefers higher confidence when sources tie", () => {
    const set = makeSet([
      r("Foo", ["meta", "a"], "inferred_pattern", "low"),
      r("Foo", ["meta", "b"], "inferred_pattern", "high"),
    ]);
    const { result } = dedupOverlappingRules(set);
    expect(result.rules.length).toBe(1);
    expect(result.rules[0].confidence).toBe("high");
  });

  it("matches titles case-insensitively", () => {
    const set = makeSet([
      r("Search Slack", ["meta", "f"]),
      r("search slack", ["meta", "g"]),
    ]);
    const { result, dropped } = dedupOverlappingRules(set);
    expect(result.rules.length).toBe(1);
    expect(dropped.length).toBe(1);
  });

  it("handles partial title overlap (rule shares one of several titles)", () => {
    const set = makeSet([
      r("Search", ["meta", "f"], "inferred_pattern", "medium", ["Find"]),
      r("Search", ["meta", "g"], "inferred_pattern", "medium", ["Look up"]),
    ]);
    const { result, dropped } = dedupOverlappingRules(set);
    expect(result.rules.length).toBe(1);
    expect(dropped.length).toBe(1);
  });

  it("preserves rulesVersion and bundleId in result", () => {
    const set: RuleSet = { bundleId: "x", rulesVersion: "abc", rules: [r("A", ["meta", "a"])] };
    const { result } = dedupOverlappingRules(set);
    expect(result.bundleId).toBe("x");
    expect(result.rulesVersion).toBe("abc");
  });
});
