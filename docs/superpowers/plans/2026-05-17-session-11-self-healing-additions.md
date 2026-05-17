# Plan additions — Sesja 11: Self-healing /v1/refresh z miss data (Sub-cel 1.3)

> **Status:** uzupełnienie istniejącego `2026-05-15-self-healing-scheduler.md`.
> Dodaje konkretne mechanizmy: kiedy refresh trigger, jak agregować miss data
> client-side, jak prompt Claude'a z miss context.
>
> **Adresuje:** Sub-cel 1.3, P-8 dokończenie.

---

## 1. Recap

Dziś `?fresh=1` (cache bypass) działa. **Brakuje:**
- Mechanizmu trigger'u "ta apka ma za dużo missów, czas refresh"
- Send miss data w POST `/v1/discover` body
- Backend prompt z miss data context: "user kliknął te elementy, ale brak
  reguły — wygeneruj"

## 2. Client-side miss aggregation

`SFlow/MissAggregator.swift` (NEW):

```swift
struct MissAggregate {
    let bundleId: String
    let role: String
    let title: String
    let desc: String
    let count: Int        // times user clicked this without toast
    let firstSeen: Date
    let lastSeen: Date
}

enum MissAggregator {
    static func aggregate(daysBack: Int = 7) -> [MissAggregate] {
        // Walk events.jsonl, filter type=miss, last N days
        // Group by (bundleId, role, normalizedTitle, normalizedDesc)
        // Return sorted by count DESC
    }

    static func candidatesForRefresh() -> [String] {  // bundleIds
        // Per app: if total miss count >= 10 AND ratio miss/(miss+toast) >= 0.5
        //   → candidate for refresh
        // Return list of bundleIds
    }
}
```

## 3. Refresh scheduler

`SFlow/RefreshScheduler.swift` (NEW):

```swift
final class RefreshScheduler {
    static let shared = RefreshScheduler()
    private var timer: Timer?

    func start() {
        // Run every 24h
        timer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            self.runRefreshCycle()
        }
    }

    private func runRefreshCycle() {
        let candidates = MissAggregator.candidatesForRefresh()
        for bundleId in candidates.prefix(3) {  // max 3 per day to avoid rate limit
            let misses = MissAggregator.aggregate().filter { $0.bundleId == bundleId }
            DiscoveryClient.refresh(bundleId: bundleId, missData: misses) { result in
                NSLog("Refresh \(bundleId): \(result)")
            }
        }
    }
}
```

## 4. Backend prompt extension

Update `backend/src/prompt.ts`:

```text
USER-REPORTED MISSES (when provided):
If the request body includes "missData", these are clickable UI elements
that the user clicked but for which we had no rule. Use these as PRIORITY
research targets:
- Each miss has {role, title, desc, count}. Higher count = more important.
- Generate a rule for the top 10 misses (by count) IF you can identify
  a plausible shortcut.
- It's better to omit a rule than guess wrong — but always TRY for missData
  entries.
```

## 5. Backend `/v1/refresh` endpoint

```typescript
// backend/src/handlers/refresh.ts
export async function refreshHandler(req: Request, env: Env): Promise<Response> {
  const body = await req.json();
  const parsed = RefreshRequestSchema.safeParse(body);  // includes missData
  if (!parsed.success) return new Response("Bad", { status: 400 });

  // Always cache-bypass (like ?fresh=1)
  // Plus inject missData into prompt
  const rules = await claudeGenerate({
    ...parsed.data,
    missData: parsed.data.missData,
    forceFresh: true,
  });

  await env.KV.put(`rules:${parsed.data.bundleId}:${majorMinor(parsed.data.appVersion)}`,
                    JSON.stringify(rules), { expirationTtl: 86400 * 90 });
  return Response.json(rules);
}
```

## 6. Acceptance criteria

- [ ] `MissAggregator.candidatesForRefresh()` zwraca listę gdy są dane
- [ ] Scheduler runs daily, max 3 refresh per cycle
- [ ] Backend `/v1/refresh` accepts missData + generuje rules with bias
      toward addressing misses
- [ ] Manual eval: apka z 20+ missów → /v1/refresh → nowe reguły adresują
      top-5 missów empirycznie

## 7. Statusy

- `audit-phase-0.md`: P-8 🔵 → 🟢
- `audit-phase-1.md`: Sub-cel 1.3 🔵 → 🟢

---

*Plan additions 2026-05-17 offline. Łączy z istniejącym 2026-05-15-self-healing-scheduler.md.*
