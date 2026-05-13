/// <reference types="@cloudflare/workers-types" />
import type { RuleSet } from "./types";

export function cacheKey(bundleId: string, appVersion: string): string {
  const parts = appVersion.split(/[.\-+]/);
  const major = parts[0] ?? "0";
  const minor = parts[1] ?? "0";
  return `rules:${bundleId}:${major}.${minor}`;
}

export async function getCachedRules(
  kv: KVNamespace,
  bundleId: string,
  appVersion: string,
): Promise<RuleSet | null> {
  const raw = await kv.get(cacheKey(bundleId, appVersion));
  if (!raw) return null;
  try {
    return JSON.parse(raw) as RuleSet;
  } catch {
    return null;
  }
}

export async function putCachedRules(
  kv: KVNamespace,
  bundleId: string,
  appVersion: string,
  rules: RuleSet,
): Promise<void> {
  await kv.put(cacheKey(bundleId, appVersion), JSON.stringify(rules), {
    // 90-day TTL — spec Section 8 "hard refresh after 90 days"
    expirationTtl: 90 * 24 * 60 * 60,
  });
}
