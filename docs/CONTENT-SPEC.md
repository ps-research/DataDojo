# DataDojo — Content Specification

| | |
|---|---|
| **Document** | Content Specification (governs all problem authoring) |
| **Version** | 1.0 |
| **Status** | Approved |
| **Authority** | This spec governs every authoring agent. Output that violates it is rejected at review gates. |

---

## 1. Belt ladder

| Belt | Tier | Definition | Data scale (hidden fixture) |
|------|------|-----------|------------------------------|
| **White** | Tutorial | Direct re-skin of one cookbook recipe. Guided drills with a Learn panel (technique + PostgreSQL docs links). Standalone — not part of universes. | ~1k rows (mild anti-hardcode variant) |
| **Blue** | Easy | Real business scenario, one core technique, clean data. A genuine problem, not a drill. | <= 50k rows |
| **Purple** | Medium | Composition of 2-3 techniques, mild landmines, first TLE pressure. | <= 500k rows |
| **Black** | Hard | Full landmines, multi-table schemas, real TLE pressure — naive solutions must fail. | 1M-5M rows |
| **Red** | Extreme | Quant-grade. Original scenario design, adversarially verified, prerequisite-locked. Near-unsolvable but objectively solvable. | 5M-10M rows |

## 2. Launch counts (v1) — total 80

| Belt | Count | Source |
|------|-------|--------|
| White | 40 | easiest runnable recipes (ch 1-3 + gentle 6/7/9) via re-skin pipeline |
| Blue | 8 | universes |
| Purple | 16 | universes |
| Black | 12 | universes |
| Red | 4 | universes (2 in the exchange universe) |

Universe problems: 40, matching the approved 20/40/30/10 distribution.

## 3. Universe roster

| # | Universe | Slug | Theme | Problem budget | Reds |
|---|----------|------|-------|----------------|------|
| 1 | PulseStream | `pulsestream` | Music/video streaming: users, tracks, plays, subscriptions, royalties | 7 (B2 P3 Bk2) | 0 |
| 2 | CartHive | `carthive` | E-commerce: catalog, orders, returns, funnels, cohorts | 7 (B2 P3 Bk2) | 0 |
| 3 | RideLoop | `rideloop` | Ride-hailing: trips, drivers, surge pricing, geozones | 7 (B1 P3 Bk2 R1) | 1 |
| 4 | MediCore | `medicore` | Hospital ops: admissions, wards, staffing rosters, readmissions | 6 (B1 P3 Bk2) | 0 |
| 5 | MetricForge | `metricforge` | SaaS analytics: events, sessions, funnels, retention, feature flags | 6 (B1 P2 Bk2 R1) | 1 |
| 6 | TickForge | `tickforge` | Exchange/order-book: orders, fills, quotes, positions, PnL — the quant crown jewel | 7 (B1 P2 Bk2 R2) | 2 |

Ladder rule (enforced in-app): a Red is locked until >= 1 Black in the same
universe is AC'd; a Black until >= 1 Purple. Every universe with a Red MUST
contain that chain.

## 4. Dataset rules

1. **Agents write generators, never rows.** Each universe ships `generator.py`:
   deterministic from a seed (`python generator.py --seed N --scale <belt>`),
   emitting one CSV per table. Raw data typed by an LLM is forbidden.
2. **CSV is the interchange.** Loaders build per-engine fixtures (SQLite file,
   Postgres schema, etc.) from the same CSVs — one dataset, seven engines.
3. **Two fixtures per problem.** A small *visible sample* (shown in the
   statement, part of the docs) and a large *hidden judge fixture* (different
   seed + scale). Hardcoding the visible sample's answer must fail the hidden
   fixture.
4. **Hidden fixtures are pre-built and read-only.** Built once at content-build
   time; submissions get read-only access + rollback. Nothing is loaded
   per-submission.
5. **Portable DDL only** in `schema.sql`: INTEGER, BIGINT, DECIMAL(p,s),
   VARCHAR(n), DATE, TIMESTAMP. No vendor types; loaders map per engine.

## 5. Landmine doctrine (Black and Red; mild for Purple)

A landmine is a **provable** data/semantics trap, not flavor text. Each Black/Red
problem ships:

- `landmines[]` — the trap list, each with the naive query it kills. Canonical
  families: NULL-in-NOT-IN; ranking ties (ROW_NUMBER vs RANK vs DENSE_RANK);
  join fan-out double-counting; empty/one-row groups; boundary dates (leap
  years, month ends, week 53); duplicate rows; type-coercion traps; gaps vs
  islands off-by-one; late/out-of-order events; division by zero in rates.
- `naive_solutions[]` — plausible expert-looking attempts. **The farm must prove
  each one fails** (WA or TLE) while the reference passes. Unproven landmines
  are rejected.

## 6. TLE calibration rule (automated, per engine)

For every Purple+ problem, per engine: run the reference and the designated
naive-slow solution against the hidden fixture. Set the time limit so that
`reference_time <= 0.5 * limit` and `naive_slow_time > limit`. If no limit
separates them by >= 2x, the problem returns to design. Engines are calibrated
independently (SQLite vs Postgres runtimes differ by an order of magnitude).

## 7. Verification gates (all machine-checked)

| Gate | Applies to | Pass criterion |
|------|-----------|----------------|
| G1 reference correctness | all | reference runs on every declared engine; outputs agree across engines after normalization |
| G2 anti-hardcode | all | visible-sample answer hardcoded as SELECT literals fails hidden fixture |
| G3 landmine proof | Purple+ | every naive solution fails as designed |
| G4 TLE calibration | Purple+ | section 6 rule holds per engine |
| G5 adversarial solve | Red only | 2 independent Opus 4.8 solver agents attempt blind; both must converge to the reference answer or the problem returns to design |
| G6 provenance | all | problem row links universe/recipe + concepts + pipeline run id |

## 8. Problem artifact format

One directory per problem: `content/problems/<slug>/`

```
problem.json      # id, universe, belt, title, concepts[], engines[],
                  # orderMatters, points, prerequisites[], provenance
statement.md      # authored narrative + task + visible sample + output spec
reference/<eng>.sql|py|R     # verified reference per engine family
naive/<n>_<kind>.sql         # naive solutions (landmine proofs)
fixtures.json     # generator seed/scale for visible + hidden fixtures
calibration.json  # per-engine time limits (written by the farm, not agents)
```

`calibration.json` and all gate results are farm-generated — agents never write
verification artifacts.

## 9. Agent + audit policy

- All authoring agents run as **Opus 4.8** (`model: "opus"`). No other model.
- Orchestration is a **phased Workflow** with review gates between phases:
  - **Phase A** — universe design (6 agents, one per universe): schema.sql,
    generator.py, universe.md (narrative + landmine inventory + problem plan).
  - **Gate A** — human/lead review of all 6 designs; generators smoke-run.
  - **Phase B** — problem authoring (per universe, from the approved plan).
  - **Gate B** — farm runs G1-G4 on every problem; failures return to authors.
  - **Phase C** — Red adversarial verification (G5) + White tutorial re-skins.
  - **Gate C** — final farm sweep, gold export, seed to MongoDB.
- **Audit trail:** the workflow journal, every gate report (JSON in
  `kb/reports/`), and every artifact are git-committed. Every problem is
  traceable: statement -> universe/recipe -> generator seed -> verification runs
  -> engine versions.
