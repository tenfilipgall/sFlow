# Plan — Sesja C: Backend `/v1/discovered` + crowdsource (Sub-cel 1.15 część 2)

> **Status:** DRAFT, ~6-8h. Następuje **po** weryfikacji Sesji B na 4-5
> apkach (Linear/Discord/Slack/Notion main).
>
> **Adresuje:** Sub-cel 1.15 część 2 (audit-phase-1.md), P-37 część 2.
>
> **Pre-requisite:** B.1 zacommitowane (U-1), PrivacyFilter aktywny (musi
> redactować PII przed wysłaniem).

---

## 1. Cel

Otworzyć **crowdsource layer** — jeden user hoveruje tooltip → wszyscy
dostają regułę. Adresuje "cold start" problem: SFlow działa dla apki
**zanim** ktokolwiek zrobił reseed.

## 2. Architektura

```
Client (TooltipObserver / MenuItemObserver)
   ↓ DiscoveredStore.record(...)
   ↓ background flush queue
POST /v1/discovered { bundleId, entries: [{rect, name, keys, source, ts}] }
   ↓ backend
KV: discovered:{bundleId} → list of (anonymous) entries
   ↓ aggregator (cron daily)
   ↓ filter: ≥3 unique anonymousUserIds reporting same (name, keys) → promote
KV: rules:{bundleId} ← merged with crowdsourced
```

## 3. Backend changes

### 3.1. New handler `backend/src/handlers/discovered.ts`

```typescript
const DiscoveredEntrySchema = z.object({
  bundleId: z.string(),
  rect: z.array(z.number()).length(4),
  name: z.string().max(80),
  keys: z.array(z.string()).max(5),
  source: z.enum(["tooltip", "menu_item", "rightclick_menu"]),
  ts: z.string().datetime(),
});

const DiscoveredRequestSchema = z.object({
  anonymousUserId: z.string().uuid(),
  entries: z.array(DiscoveredEntrySchema).max(50),  // batch
});

export async function discoveredHandler(req: Request, env: Env): Promise<Response> {
  const body = await req.json();
  const parsed = DiscoveredRequestSchema.safeParse(body);
  if (!parsed.success) return new Response("Bad request", { status: 400 });

  // Server-side privacy scrub (defense in depth)
  for (const entry of parsed.data.entries) {
    if (containsPII(entry.name)) continue;  // drop entries client missed
    await env.KV.put(
      `discovered:${entry.bundleId}:${parsed.data.anonymousUserId}:${entry.ts}`,
      JSON.stringify(entry),
      { expirationTtl: 60 * 60 * 24 * 30 }  // 30 days
    );
  }
  return new Response("OK");
}
```

### 3.2. Aggregator cron (Cloudflare Workers cron)

Daily — runs at 03:00 UTC:

```typescript
async function aggregateDiscovered(env: Env) {
  const buckets: Record<string, { count: Set<string>; entry: DiscoveredEntry }> = {};

  // Walk discovered:* keys
  const list = await env.KV.list({ prefix: "discovered:" });
  for (const key of list.keys) {
    const entry = JSON.parse(await env.KV.get(key.name) || "{}");
    const bucketKey = `${entry.bundleId}|${entry.name.toLowerCase()}|${entry.keys.join("+")}`;
    if (!buckets[bucketKey]) {
      buckets[bucketKey] = { count: new Set(), entry };
    }
    const userId = key.name.split(":")[2];
    buckets[bucketKey].count.add(userId);
  }

  // Promote when ≥3 unique users reported same (name, keys)
  for (const [bucketKey, data] of Object.entries(buckets)) {
    if (data.count.size >= 3) {
      await promoteToRules(env, data.entry);
    }
  }
}

async function promoteToRules(env: Env, entry: DiscoveredEntry) {
  const rulesKey = `rules:${entry.bundleId}:crowdsourced`;
  const existing = JSON.parse(await env.KV.get(rulesKey) || '{"rules":[]}');
  // Check for dup, append new rule
  // ... transformation to LoadedRule format
  await env.KV.put(rulesKey, JSON.stringify(existing));
}
```

## 4. Client changes

### 4.1. `DiscoveredStore.flushToBackend()`

Co N minut (np. 60 min) lub gdy `entries.count >= 20`:
1. Build batch z 20 ostatnich entries (po PrivacyFilter scrub)
2. POST do `/v1/discovered`
3. Mark uploaded w lokalnym tracking

### 4.2. Settings toggle

"Share anonymous discovered tooltips with SFlow community" — default **OFF**
w beta (per beta-checklist), **ON** post-launch po pozytywnym signalu.

### 4.3. Anonymous user ID

UUID gen at first launch (already planned w Faza 2.1).

## 5. Tests

**Backend (`backend/tests/discovered.test.ts`):**
- Valid batch → 200 OK, KV pisze
- Invalid schema → 400
- PII in entry.name → silently dropped (server-side defense)
- Aggregation: 2 users → no promote, 3 users → promote

**Client (`SFlowTests/DiscoveredStoreFlushTests.swift`):**
- 20+ entries → flush triggered
- HTTP fail → entries zostają lokalnie, retry next interval
- Privacy filter: entry z PII nie trafia do batch

## 6. Acceptance criteria

- [ ] `/v1/discovered` endpoint deployed (Filip explicit yes)
- [ ] Client flush działa w background
- [ ] Aggregator cron uruchamia się daily, promote logs visible w Cloudflare dashboard
- [ ] Manual test: Filip + 2 znajomych hoverują nową apkę → po 24h reguła
      pojawia się w `rules:{bundleId}:crowdsourced`
- [ ] Privacy: zero PII w produkcyjnym KV po review

## 7. Statusy

- `audit-phase-0.md`: P-37 część 2 → 🟢
- `audit-phase-1.md`: Sub-cel 1.15 część 2 → 🟢, sesja C → 🟢

## 8. Decyzja go/no-go

Robić **tylko jeśli** Sesja B (P-37 część 1) generalizuje się na ≥3 z 4
testowanych apek (Linear/Discord/Slack/Notion main). Jeśli B działa
tylko na Notion-rodzinie → C jest niepotrzebna (bardzo wąski TAM).

---

*Plan napisany 2026-05-17 offline. Pełny TDD detail vs. szkic w execution sequence.*
