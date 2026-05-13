import { describe, expect, it } from "vitest";
import { parseRulesJSON } from "../src/claude";

describe("parseRulesJSON", () => {
  it("parses bare JSON", () => {
    const json = `{"rules":[{"match":{"role":"AXButton","titles":["Send"]},"keys":["meta","enter"],"hint":"Send","confidence":"high","source":"menu_bar"}]}`;
    const result = parseRulesJSON(json);
    expect(result).toHaveLength(1);
    expect(result[0].keys).toEqual(["meta", "enter"]);
  });

  it("strips code fences", () => {
    const text = "```json\n{\"rules\":[]}\n```";
    expect(parseRulesJSON(text)).toEqual([]);
  });

  it("drops malformed rules but keeps valid ones", () => {
    const json = `{"rules":[
      {"match":{"role":"AXButton","titles":["Send"]},"keys":["enter"],"hint":"Send","confidence":"high","source":"menu_bar"},
      {"match":{"role":"AXButton","titles":["X"]},"keys":[],"hint":"X","confidence":"high","source":"menu_bar"}
    ]}`;
    const result = parseRulesJSON(json);
    expect(result).toHaveLength(1);
    expect(result[0].match.titles).toEqual(["Send"]);
  });

  it("throws on non-JSON", () => {
    expect(() => parseRulesJSON("not json at all")).toThrow(/non-JSON/);
  });
});
