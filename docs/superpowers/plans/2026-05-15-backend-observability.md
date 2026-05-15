# Plan Backend Observability Dashboard (P-21) — SPEC, nie implementacja

**Data:** 2026-05-15
**Adresuje:** P-21 (audit-phase-0.md), sekcja "Backend observability" w audit-phase-1.md
**Status:** ⬜ SPEC ONLY — implementacja **po sesji C** (TooltipObserver), bo C też dotyka backendu
**Szacunkowy czas implementacji (poza scope tej sesji):** ~1 dzień roboczy (4–6h)

> Plan czysto markdownowy. **TYLKO SPEC** — implementacja będzie później,
> w osobnej sesji po sesji C. Tutaj decydujemy *co* zbudujemy i *dlaczego*.

---

## 1. Po co to robimy (analogia jak dla 12-latka)

Wyobraź sobie, że masz fabrykę robiącą cukierki. Maszyna pracuje całą noc. Rano
przychodzisz i widzisz tylko **stos gotowych cukierków na końcu taśmy**. Nie
wiesz: ile się popsuło? ile czasu zajęła każda partia? która maszyna jest wolna?
która zżera za dużo prądu?

Tak teraz wygląda backend SFlow. Cloudflare Worker pracuje — generuje reguły
dla nowych apek. Ale my nie wiemy:
- **Ile** razy dziennie ktoś prosi o nową apkę?
- **Ile** razy Claude zwraca śmieci (parse error)?
- **Ile** sekund trwa średni call?
- **Które** apki są najpopularniejsze (gdzie warto popracować nad jakością)?
- **Czy** coś się wyłożyło wczoraj w nocy?

Robimy **prosty panel kontrolny** — coś jak deska rozdzielcza w aucie. Nic
fancy, nie Grafana z 200 widgetami. Krótka stronka z liczbami: requests/dzień,
error rate, top apki. **5 wykresów, 30 sekund spojrzenia rano**.

To **prerequisite dla launchu** (Faza 6) — bez tego latamy ślepo, userzy
zgłoszą problemy zanim my je zauważymy.

---

## 2. Rationale (jak to się ma do roadmap/vision)

**Z audit-phase-0.md P-21:** Severity WYSOKA gdy zaczniemy mieć userów (Faza 6).
"Quality issues u userów = quality issues których nigdy nie zobaczymy bez
bezpośredniego raportu." Czyli: bez observability, user który ma broken Notion
discovery napisze nam to dopiero gdy mu się znudzi czekanie.

**Z audit-phase-1.md sekcja "Backend observability (P-21)":** Minimum viable —
CF Workers Logs + console.log JSON każdy request + Cloudflare Analytics
dashboard (built-in). Logflare lub Axiom dla queryable storage **gdy >100
requestów/dzień**.

**Z product-vision.md sekcja 5e2:** Synthetic eval (P-33) loguje
`alternative_keys` jako sygnał do iteracji prompta. **Bez observability dashboard
te logi są bezużyteczne** — Filip musi czytać raw logi, łatwo coś przeoczyć.

**Sekwencja:** Sesja C (TooltipObserver) doda nowy endpoint `/v1/discovered`
(tooltip crowd-source). Obs dashboard powinien być po C bo wtedy mamy
**komplet endpointów do monitorowania** (discover, refresh, discovered, eval
metrics).

---

## 3. Co dashboard MA pokazywać (minimum viable)

| Sekcja | Metryka | Granularność |
|---|---|---|
| **Volume** | Requests/dzień per endpoint | last 7 days, line chart |
| **Volume** | Requests/godzina (peak detection) | last 24h, line chart |
| **Quality** | Cache hit rate per endpoint | last 7 days, bar chart |
| **Quality** | Average rules generated per `/v1/discover` | last 7 days, line |
| **Quality** | Synthetic eval avg score per apka | top 20 apek, table |
| **Errors** | Error count per endpoint per dzień | last 7 days, line |
| **Errors** | Top 5 error reasons (parse errors, Zod fails, Claude API fails) | last 7 days, table |
| **Latency** | p50, p95, p99 per endpoint | last 24h, table |
| **Top apps** | Top 20 bundleIds po liczbie requestów | last 7 days, table |
| **Top apps** | Top 10 bundleIds po liczbie misses (gdy `/v1/refresh` ruszy) | last 7 days, table |
| **Health** | "Wczoraj wszystko OK?" — single green/yellow/red badge | aggregate |

**Co celowo POMIJAMY:**
- Per-user analytics (nie mamy userIds, GDPR concern)
- Real-time live tail (overkill, raz dziennie spojrzenie wystarcza)
- Alerts/notifications (na MVP — Filip patrzy ręcznie codziennie 5 min)
- Multi-tenancy (single dev = Filip)

---

## 4. Decyzje do podjęcia (Filipie, wybierz przed implementacją)

### Decyzja D-1: Storage backend dla metryk

| Opcja | Plus | Minus | Koszt/m-c |
|---|---|---|---|
| **A. Cloudflare Workers Analytics Engine (built-in)** (Recommended) | Native CF, free 10M datapoints/dzień, query przez SQL-like, integruje się z Worker | Wymaga `wrangler.toml` config, learning curve | $0 do 10M dp/dzień |
| B. KV-counter — agregat w KV (`stats:requests:2026-05-15:discover` → number) + endpoint `/v1/stats` zwracający JSON | Bardzo proste, każdy CF dev zna KV | Brak time-series (tylko agregaty per dzień), trudno pivot | $0.50/m-c (KV reads) |
| C. Logflare albo Axiom (external) | Pełen ElasticSearch-like search, dashboard out-of-the-box | Wymaga konta, integration, $50+/m-c przy 100 req/dzień | ~$0.50/m-c początkowo (free tier) |
| D. KV-counter + przyszłość: opcja A gdy >100 req/dzień | Najtańsze short-term, easy migration | Dwa fazy implementacji | $0 |

**Rekomendacja:** **A — Cloudflare Workers Analytics Engine.** Powody:
1. **Native do CF stack** który już używamy. Wrangler config + 5 lines kodu.
2. **Free tier 10M datapoints** = ~333k req/dzień. Mamy daleko do tego limitu.
3. **Time-series queries** — możemy pytać "requests w ostatnie 7 dni, group by hour".
4. **Lock-in jest mały** — to po prostu append datapointów, łatwo migrować na
   inny system później.

Opcja D jest backup jeśli Filip nie chce zaczynać od CF AE (steep learning).
Opcja B jest tańsza ale **nie skaluje** na questions typu "p95 latency last
24h" — KV-counter zwraca tylko agregaty per dzień.

### Decyzja D-2: Gdzie hostować dashboard frontend?

| Opcja | Plus | Minus |
|---|---|---|
| **A. Endpoint `/v1/stats` zwraca JSON + statyczna HTML page w Worker** (Recommended) | Zero setup, single repo, dashboard pod sflow-backend.workers.dev/stats | Limited UX (no React, ale na MVP wystarczą plain HTML+JS+canvas) |
| B. Osobny CF Pages site (statyczny React app) | Pełne UX, Chart.js itp. | Nowy repo, więcej setup, oddzielny deploy |
| C. Grafana Cloud free tier | Profesjonalny dashboard | Konfiguracja datasource'a, jak external |
| D. Lokalny CLI tool (`./scripts/sflow-stats`) | Najprostsze | Trzeba mieć terminal otwarty |

**Rekomendacja:** **A — statyczny HTML w Worker.** Powody:
1. **Single artifact** — wszystko w `backend/` repo, deploy jednym `wrangler deploy`.
2. **Auth-friendly** — basic auth przez `WORKER_DASHBOARD_PASSWORD` secret
   w CF env vars. Dashboard dostępny tylko dla Filipa.
3. **Plain HTML + Chart.js z CDN** — 200 linii JS, 5 wykresów. Nie potrzeba
   React.
4. Migracja na CF Pages jest łatwa później jeśli będzie zespół.

### Decyzja D-3: Co loguje Worker (data points)

| Endpoint | Datapoint fields | Sample rate |
|---|---|---|
| `/v1/discover` | `{type, bundleId, appVersion, cacheHit, rulesGenerated, dropped, durationMs, error, evalAvgScore, experimentalCount}` | 100% |
| `/v1/refresh` (sesja 11) | `{type, bundleId, missCount, rulesGenerated, durationMs, error}` | 100% |
| `/v1/discovered` (sesja C) | `{type, bundleId, tooltipsAdded, durationMs, error}` | 100% |
| `/v1/feedback` (sesja 5) | `{type, bundleId, shortcutId, eventType}` | 100% |

**Rekomendacja:** **100% sampling** dla wszystkich endpointów. Mamy <1000
req/dzień obecnie, mieszczemy się daleko poniżej 10M/dzień limit CF AE.
Sampling dodajemy gdy zaczniemy widzieć koszty.

### Decyzja D-4: Auth dla dashboard

| Opcja | Plus | Minus |
|---|---|---|
| **A. Basic auth przez nagłówek (single password w env var)** (Recommended) | Najprostsze, działa w 5 min | Password w plain text przez HTTPS |
| B. CF Access (zero-trust SSO przez Google) | Profesjonalne | Wymaga CF Access plan (free tier ok) |
| C. Brak — dashboard publiczny | Brak setup | **NIE** — leak metryk biznesowych |
| D. Cloudflare Worker secrets + URL token | Średnie | Wymaga generowania tokenów |

**Rekomendacja:** **A — basic auth.** Powody:
1. Single user (Filip), single dev environment.
2. CF Access (opcja B) jest superior ale wymaga konfiguracji Zero Trust, OAuth
   setup — overkill na MVP.
3. Hasło w env var (Cloudflare Worker secret) jest bezpieczne — nie jest w repo,
   nie jest w logach.

Migracja na CF Access jest łatwa (1h pracy) gdy się pojawi multi-user use case.

### Decyzja D-5: Retention metryk

| Opcja | Retention | Plus | Minus |
|---|---|---|---|
| **A. 90 dni** (Recommended) | 90d window | Zgodne z innymi TTL w SFlow (cache TTL też 90d) | Wymaga rotation |
| B. Nieograniczone (CF AE trzyma) | All time | Dane do retrospektywy | Może być drogie >1 rok |
| C. 7 dni | 7d | Tanio | Brak trendów >tydzień |

**Rekomendacja:** **A — 90 dni.** CF AE default retention to 90 dni w free
tier. Spójne z innymi systemami w SFlow. Po 90d dane są aggregated do
miesięcznych snapshot'ów w KV (manualne, optional).

---

## 5. Files to touch (gdy implementacja ruszy — NIE w tej sesji)

| Akcja | Plik | Zmiana |
|---|---|---|
| Modify | `backend/wrangler.toml` | Dodaj `analytics_engine_datasets` binding |
| Modify | `backend/src/handlers/discover.ts` | Po Claude call: `env.METRICS.writeDataPoint({...})` |
| Modify | `backend/src/handlers/refresh.ts` | Analogiczne logowanie (sesja 11 może to zrobić jednocześnie) |
| Modify | `backend/src/handlers/discovered.ts` | Analogiczne (sesja C może zrobić jednocześnie) |
| Modify | `backend/src/handlers/feedback.ts` | Analogiczne (jeśli już istnieje — sesja 5) |
| New | `backend/src/handlers/stats.ts` | `/v1/stats` endpoint — queries do CF AE, return JSON |
| New | `backend/src/dashboard.html` | Plain HTML+JS dashboard, Chart.js z CDN |
| New | `backend/src/handlers/dashboard.ts` | Serwuje `dashboard.html`, basic auth check |
| Modify | `backend/src/index.ts` | Wire routes `/v1/stats`, `/dashboard` |
| Modify | `backend/src/auth.ts` (new lub existing) | Basic auth helper |
| New | `backend/test/stats.test.ts` | Tests for stats endpoint |

---

## 6. Task breakdown (gdy implementacja ruszy)

Numerowane atomic taski. Każdy 1–3 commity. Razem ~1 dzień roboczy.

### Task 1 — `wrangler.toml` config CF AE

- Dodaj `[[analytics_engine_datasets]]` z bindingiem `METRICS`
- Test: `wrangler deploy --dry-run` przechodzi

### Task 2 — Logging w `/v1/discover`

- Po istniejącym console.log dorzuć `env.METRICS.writeDataPoint({...})`
- Fields per Decyzja D-3
- Test: integration test z mock env.METRICS

### Task 3 — `/v1/stats` endpoint

- Query CF AE przez Workers SQL API
- Zwraca JSON z preparowanym aggregatami: `{requests7d, errors7d, latencyP95, topApps}`
- Basic auth check

### Task 4 — `dashboard.html` + Chart.js

- 5 wykresów: requests/dzień, error rate, latency p95, top apps, eval avg score
- Fetch `/v1/stats`, render canvas
- Mobile responsive (Filip patrzy z telefonu czasem)

### Task 5 — Basic auth helper

- Env var `DASHBOARD_PASSWORD`
- Middleware sprawdza `Authorization: Bearer <pwd>` lub Basic auth header
- Wire w `/v1/stats` i `/dashboard`

### Task 6 — Deploy + manual verify

- `wrangler deploy` (Filip authorize)
- Otwórz `https://sflow-backend.workers.dev/dashboard`, wprowadź hasło
- Sprawdź czy 5 wykresów renderuje, czy dane wyglądają sensownie
- Czeka 24h na narastanie danych, sprawdza ponownie

### Task 7 — Update audit + roadmap

- `audit-phase-0.md` P-21 🔵 → 🟢
- `audit-phase-1.md` sekcja "Backend observability" → 🟢
- `roadmap.md` Session log
- Commit "docs: backend observability dashboard"

---

## 7. Acceptance criteria (mierzalne)

- [ ] Dashboard dostępny pod `https://sflow-backend.workers.dev/dashboard` (auth-protected)
- [ ] 5 wykresów renderuje w Chrome + mobile Safari
- [ ] Dane z CF AE — minimum 24h granularity (nie tylko agregat dzienny)
- [ ] `/v1/stats` JSON endpoint zwraca odpowiedź <500ms p95
- [ ] Logging do CF AE pokrywa: `/v1/discover`, `/v1/refresh`, `/v1/discovered`,
      `/v1/feedback` (te które istnieją w momencie implementacji)
- [ ] Basic auth blokuje publiczny dostęp (test: curl bez auth = 401)
- [ ] Manual sanity check: 24h po deployu Filip widzi że requests pojawiają się
      w dashboard, latency wykres ma sensowne wartości, error rate <5%

---

## 8. Risks

### Risk 1 — CF AE free tier nie wystarczy

**Symptom:** Po publicznym launch dostajemy >10M datapointów/dzień, billing
spike.

**Mitigacja:**
- 10M/dzień = ~115 req/sekundę, sustained. Far away od SFlow scale.
- Jeśli się zdarzy: dodaj sampling (`if (Math.random() < 0.1) writeDataPoint(...)`)
- Worst case: CF AE płatne — $0.25/M datapoints, manageable

**Probability:** BARDZO NISKA. To problem dla "good problem to have" stage'u.

### Risk 2 — Dashboard "działa" ale dane są zmiotne (Claude czasami zwraca, czasami nie)

**Symptom:** Wykres "requests/dzień" wygląda OK ale "rules generated" ma dziury
— niektóre requesty nie zostały zalogowane.

**Mitigacja:**
- Idempotency check w handlerach: `writeDataPoint` w finally bloku, zawsze
  wykonywany
- Test: forced error scenarios (mock Claude fail) — datapoint nadal zapisany
  z `error: "claude_timeout"`

**Probability:** ŚREDNIA jeśli logging w try block. NISKA jeśli w finally.

### Risk 3 — Dashboard sam jest źródłem awarii (recursive logging)

**Symptom:** `/v1/stats` endpoint loguje swoje requesty do CF AE → dashboard
co minute pyta `/v1/stats` → infinite loop.

**Mitigacja:**
- `/v1/stats` **nie loguje sam siebie** — explicit exclude w `dashboard.ts`
- `/dashboard` (HTML) nie loguje (statyczna stronka)
- Polling rate dashboardu: 1× minutowo, nie 1× sekundowo

**Probability:** NISKA. Standardowy patterns.

### Risk 4 — CF AE writeDataPoint dodaje latencję do `/v1/discover`

**Symptom:** Critical path `/v1/discover` rośnie z 90s do 91s.

**Mitigacja:**
- `writeDataPoint` jest fire-and-forget w CF AE (background)
- W praktyce dodaje <5ms
- Test: porównaj p95 latency przed/po deployu

**Probability:** BARDZO NISKA.

### Risk 5 — Implementacja koliduje z sesją C (TooltipObserver dotyka backendu)

**Symptom:** Sesja C dodaje endpoint `/v1/discovered`. Nasza sesja
obs-dashboard też modyfikuje `backend/src/handlers/`. Merge conflict.

**Mitigacja:**
- **Czekamy aż sesja C zostanie zmerge'owana** — explicit w nagłówku tego
  planu ("po sesji C")
- Sesja C może być świadoma żeby dodać `env.METRICS.writeDataPoint` w nowym
  endpoincie od razu (preempt, prosty 1-liner)
- Plan z tej sesji to opcja, nie obligation w sesji C

**Probability:** NISKA jeśli zachowamy kolejność.

---

## 9. Out of scope (NIE w tym dashboardzie)

- ❌ Real-time live tail (overkill)
- ❌ Alerts/email notifications na anomalie (manual check 5 min/dzień wystarcza)
- ❌ Per-user analytics (privacy concern, nie mamy userIds)
- ❌ A/B testing infrastructure (Faza 4+)
- ❌ Cost tracking ($/regule) — można dorzucić v2 po launch
- ❌ Multi-tenancy (single Filip, single SFlow)

---

## 10. Co dashboard ODBLOKUJE (downstream value)

Po wdrożeniu:
- **Sesja 12+ iteracje promptów:** dashboard pokazuje "apki z avg eval score
  <3.5" — natychmiast wiemy gdzie prompt jest słaby
- **Faza 1.6 coverage report:** dashboard daje "top 20 apek po requests" =
  priority list do manual eval
- **Faza 2 telemetria:** infrastruktura już istnieje (CF AE), dorzucamy event
  types z klienta
- **Faza 6 launch:** mamy data do raportu "SFlow zrobił 50k discoveries w
  pierwszym miesiącu" — marketing material

---

## 11. Alternatywy które rozważyliśmy i odrzuciliśmy

**Alternatywa: Sentry/Datadog APM.** Profesjonalne, ale $50+/m-c, overkill
dla SFlow scale + lock-in. Może w przyszłości gdy zespół ma >3 osoby.

**Alternatywa: Prometheus + Grafana self-hosted.** Wymagałoby osobnego VPS,
~$10/m-c + 1 dzień setupu. CF AE jest natywne i tańsze.

**Alternatywa: Build nothing, czytaj wrangler tail.** Wystarcza dla 10 req/dzień,
nie skaluje na 100+. Wszystkie metryki "po wrażeniu" zamiast danych.

---

## 12. Sequencing — kiedy implementujemy?

**NIE w tej sesji (2026-05-15).** Czekamy na:
1. ✅ Sesja A/B/C/D (TooltipObserver) — zakończone
2. ✅ Sesja T1 (video eval scripts) — zakończone
3. ⬜ Sesja 10 (synthetic self-eval) — chcemy żeby eval score były logowane w dashboard
4. ⬜ Sesja 11 (self-healing scheduler) — chcemy żeby `/v1/refresh` była w dashboard

**Optimalna kolejność:**
- Sesja 10 — synthetic eval
- Sesja 11 — self-healing scheduler
- **Sesja 12 — backend observability** (ten plan)
- Sesja 13+ — analiza danych z dashboard, iteracja promptów

Łącznie ~2 tygodnie od dziś.

---

*Plan v1.0 — SPEC ONLY. Implementacja w osobnej sesji ~2 tygodnie od dziś.
Po sesji C i sesji 11 ewentualnie zaktualizować decyzje D-1/D-3 jeśli scope
się zmienił.*
