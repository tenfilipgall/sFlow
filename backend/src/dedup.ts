import type { Rule, RuleSet } from "./types";

/**
 * Detects rules sharing any title (case-insensitive) within the same RuleSet,
 * and drops the loser per conflict. Winner selection:
 *   1) Rule with source === "menu_bar" wins over others.
 *   2) If both/neither are menu_bar, the rule with higher confidence wins (high > medium > low).
 *   3) If still tied, the rule with FEWER total titles wins (more specific).
 *   4) If still tied, the FIRST rule (lower index) wins.
 * Returns the dedup'd RuleSet and an array of dropped-rule descriptions for telemetry.
 */
export function dedupOverlappingRules(set: RuleSet): { result: RuleSet; dropped: string[] } {
  const dropped: string[] = [];
  const survivors: Rule[] = [];
  const titleToIndex = new Map<string, number>(); // lowercased title -> index in survivors

  const confidenceRank = (c: string) =>
    c === "high" ? 3 : c === "medium" ? 2 : 1;

  const winsAgainst = (incoming: Rule, existing: Rule): boolean => {
    if (incoming.source === "menu_bar" && existing.source !== "menu_bar") return true;
    if (existing.source === "menu_bar" && incoming.source !== "menu_bar") return false;
    const ci = confidenceRank(incoming.confidence);
    const ce = confidenceRank(existing.confidence);
    if (ci !== ce) return ci > ce;
    if (incoming.match.titles.length !== existing.match.titles.length) {
      return incoming.match.titles.length < existing.match.titles.length;
    }
    return false; // tie → keep existing (it came first)
  };

  for (const rule of set.rules) {
    const overlaps = new Set<number>();
    for (const t of rule.match.titles) {
      const key = t.toLowerCase();
      const idx = titleToIndex.get(key);
      if (idx !== undefined) overlaps.add(idx);
    }

    if (overlaps.size === 0) {
      const newIdx = survivors.length;
      survivors.push(rule);
      for (const t of rule.match.titles) {
        titleToIndex.set(t.toLowerCase(), newIdx);
      }
      continue;
    }

    // Compare against each overlapping existing rule.
    let winner = true;
    for (const idx of overlaps) {
      if (!winsAgainst(rule, survivors[idx])) {
        winner = false;
        break;
      }
    }

    if (winner) {
      // Replace all overlapping survivors with this rule.
      for (const idx of overlaps) {
        dropped.push(`replaced [${idx}] ${survivors[idx].hint} (${survivors[idx].keys.join("+")})`);
      }
      // Remove old survivors and their title indices.
      const newSurvivors: Rule[] = [];
      const oldIndexToNew = new Map<number, number>();
      survivors.forEach((s, i) => {
        if (!overlaps.has(i)) {
          oldIndexToNew.set(i, newSurvivors.length);
          newSurvivors.push(s);
        }
      });
      // Rebuild titleToIndex from scratch for cleanliness.
      survivors.length = 0;
      survivors.push(...newSurvivors);
      titleToIndex.clear();
      survivors.forEach((s, i) => {
        for (const t of s.match.titles) titleToIndex.set(t.toLowerCase(), i);
      });
      // Append the winner.
      const winnerIdx = survivors.length;
      survivors.push(rule);
      for (const t of rule.match.titles) {
        titleToIndex.set(t.toLowerCase(), winnerIdx);
      }
    } else {
      dropped.push(`dropped ${rule.hint} (${rule.keys.join("+")}) — overlaps with ${overlaps.size} existing rule(s)`);
    }
  }

  return {
    result: { ...set, rules: survivors },
    dropped,
  };
}
