/// <reference types="@cloudflare/workers-types" />
import type { RuleSet } from "./types";

/// Sub-cel 1.20: cache key includes locale suffix when non-English.
/// "en" or undefined → bare key (backward-compat with pre-i18n cache entries).
/// "pl"             → `rules:bundle:1.2:pl`
/// "zh-Hans"        → `rules:bundle:1.2:zh-Hans`
export function cacheKey(bundleId: string, appVersion: string, locale?: string | null): string {
  const parts = appVersion.split(/[.\-+]/);
  const major = parts[0] ?? "0";
  const minor = parts[1] ?? "0";
  const loc = locale && locale.toLowerCase() !== "en" ? `:${locale}` : "";
  return `rules:${bundleId}:${major}.${minor}${loc}`;
}

export async function getCachedRules(
  kv: KVNamespace,
  bundleId: string,
  appVersion: string,
  locale?: string | null,
): Promise<RuleSet | null> {
  const raw = await kv.get(cacheKey(bundleId, appVersion, locale));
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
  locale?: string | null,
): Promise<void> {
  await kv.put(cacheKey(bundleId, appVersion, locale), JSON.stringify(rules), {
    // 90-day TTL — spec Section 8 "hard refresh after 90 days"
    expirationTtl: 90 * 24 * 60 * 60,
  });
}
