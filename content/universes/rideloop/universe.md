# RideLoop — universe design

| | |
|---|---|
| **Slug** | `rideloop` |
| **Theme** | Ride-hailing: trips, drivers, riders, surge pricing, geozones, cancellations |
| **Problem budget** | 7 — Blue 1, Purple 3, Black 2, Red 1 |
| **Reds** | 1 (prerequisite-locked; chain documented below) |
| **Tables** | 9 (5 dimensions, 4 fact/feed) |

---

## 1. Narrative

RideLoop is a metropolitan ride-hailing marketplace. A rider opens the app and
requests a trip; the platform tries to match a nearby driver; a price is quoted
using a per-zone base fare, distance, and a live **surge multiplier** that rises
when demand outstrips supply. Most requests end in a completed ride, but a large
minority do not: the rider cancels while waiting, a matched driver cancels, or no
driver is ever found. Those unhappy paths are not noise — they are the core of
the business. A rider whose first request finds no driver will usually re-request
within a couple of minutes, so a single *intent to travel* can leave several
rows in the trip log. Confusing a request with an intent is the fastest way to
report a fulfillment rate that is quietly wrong.

The city is carved into **geozones** — downtown grids, residential belts,
airports. Airport zones behave differently: longer trips, stickier surge, more
no-driver events at peak. Demand follows the clock (morning and evening rush,
weekend late nights) and the calendar (a gentle seasonal ramp), and popularity is
sharply power-law: a handful of downtown zones and a small cohort of power-riders
account for most of the volume, while a long tail of zones and riders barely
appears. Money flows through **fares**, **tips**, **promotions** (multiple codes
can stack on one trip), and a published **surge feed** that is not always tidy —
events arrive late and occasionally duplicate.

This universe is built to reward analysts who respect grain and semantics. Fares
live at trip grain but promotions fan out below it; ratings are optional and
sometimes submitted twice; a "no tip" is not the same as a zero tip; a cancelled
trip has no dropoff zone at all. The problems below are designed so that the
obvious query returns a confident, wrong number, and only a careful one survives
the hidden fixture.

---

## 2. Table dictionary

### Dimensions

**geozones** — service areas within cities.

| Column | Type | Meaning |
|--------|------|---------|
| `zone_id` | INTEGER PK | surrogate key |
| `zone_code` | VARCHAR(8) | external code, **zero-padded** (e.g. `'013'`) — a type-coercion trap |
| `zone_name` | VARCHAR(64) | e.g. "Northgate Market" |
| `city` | VARCHAR(48) | city the zone belongs to |
| `is_airport` | INTEGER | 0/1 flag; airport zones have distinct dynamics |
| `area_km2` | DECIMAL(8,2) | zone area |
| `base_fare` | DECIMAL(6,2) | fixed component of a fare originating in this zone |

**riders** — passengers.

| Column | Type | Meaning |
|--------|------|---------|
| `rider_id` | INTEGER PK | surrogate key |
| `signup_date` | DATE | account creation (always before the trip window) |
| `home_zone_id` | INTEGER → geozones | nullable (~4% have none) |
| `rider_tier` | VARCHAR(16) | `basic`/`plus`; nullable for legacy accounts |
| `referral_source` | VARCHAR(24) | acquisition channel; nullable |

**drivers** — drivers.

| Column | Type | Meaning |
|--------|------|---------|
| `driver_id` | INTEGER PK | surrogate key |
| `onboard_date` | DATE | when the driver joined |
| `home_zone_id` | INTEGER → geozones | base zone |
| `status` | VARCHAR(16) | `active`/`suspended`/`churned` |
| `rating` | DECIMAL(3,2) | rolling average; **nullable** for drivers with no rated trips |

**vehicles** — a driver may register more than one vehicle over time (1:N).

| Column | Type | Meaning |
|--------|------|---------|
| `vehicle_id` | BIGINT PK | surrogate key |
| `driver_id` | INTEGER → drivers | owning driver |
| `vehicle_class` | VARCHAR(16) | `economy`/`xl`/`lux` — drives per-km rate |
| `make`, `model` | VARCHAR(24) | vehicle make/model |
| `model_year` | INTEGER | model year |
| `seats` | INTEGER | seat count (6 for `xl`) |
| `active_from` | DATE | registration date |
| `active_to` | DATE | retirement date; **NULL = currently active** |

**promotions** — promo codes.

| Column | Type | Meaning |
|--------|------|---------|
| `promo_id` | INTEGER PK | surrogate key |
| `promo_code` | VARCHAR(24) | human code |
| `promo_type` | VARCHAR(16) | `percent`/`flat`/`first_ride` |
| `discount_value` | DECIMAL(6,2) | percent (0..100) or flat amount, per type |
| `valid_from`, `valid_to` | DATE | validity window |

### Facts and feeds

**trips** — the central fact table (one row per request, any outcome). This is
the belt-scaled table (up to ~7M rows at red).

| Column | Type | Meaning |
|--------|------|---------|
| `trip_id` | BIGINT PK | surrogate key; **not** monotonic with request time |
| `rider_id` | INTEGER → riders | requester |
| `driver_id` | INTEGER → drivers | **NULL when `no_driver`**; sometimes NULL for `cancelled_rider` |
| `vehicle_id` | BIGINT → vehicles | NULL when no vehicle was assigned |
| `request_ts` | TIMESTAMP | when the ride was requested |
| `pickup_ts` | TIMESTAMP | NULL unless a pickup happened |
| `dropoff_ts` | TIMESTAMP | NULL unless completed |
| `pickup_zone_id` | INTEGER → geozones | origin zone (always present) |
| `dropoff_zone_id` | INTEGER → geozones | **NULL unless completed** |
| `distance_km` | DECIMAL(7,2) | NULL unless completed |
| `duration_s` | INTEGER | NULL unless completed |
| `fare_amount` | DECIMAL(8,2) | rider-charged fare; **NULL unless completed** |
| `surge_multiplier` | DECIMAL(4,2) | applied surge (≥1.00); NULL on some non-completed rows |
| `status` | VARCHAR(20) | `completed`/`cancelled_rider`/`cancelled_driver`/`no_driver` |
| `payment_type` | VARCHAR(16) | `card`/`cash`/`wallet`; NULL on many non-completed rows |

**surge_events** — the published surge feed; one row each time a zone's
multiplier changes.

| Column | Type | Meaning |
|--------|------|---------|
| `surge_id` | BIGINT PK | surrogate key |
| `zone_id` | INTEGER → geozones | affected zone |
| `effective_ts` | TIMESTAMP | when the multiplier took effect; **late arrivals mean this is not sorted** |
| `multiplier` | DECIMAL(4,2) | published multiplier (≥1.00) |
| `reason` | VARCHAR(24) | `demand`/`weather`/`event`/`manual`; nullable |

**trip_ratings** — post-trip ratings. Only some completed trips are rated; a trip
may (rarely) carry a duplicate rating from a double submission.

| Column | Type | Meaning |
|--------|------|---------|
| `rating_id` | BIGINT PK | surrogate key |
| `trip_id` | BIGINT → trips | rated trip (**not unique** — duplicates exist) |
| `rider_stars` | INTEGER | rider's rating of the driver (1..5); nullable |
| `driver_stars` | INTEGER | driver's rating of the rider (1..5); nullable |
| `tip_amount` | DECIMAL(6,2) | **NULL = no tip info; 0.00 = explicit zero tip** |
| `rated_ts` | TIMESTAMP | when the rating was left |

**trip_promotions** — bridge (M:N). A trip can carry several promos; a
`(trip_id, promo_id)` pair may appear twice (double application).

| Column | Type | Meaning |
|--------|------|---------|
| `application_id` | BIGINT PK | surrogate key |
| `trip_id` | BIGINT → trips | discounted trip (**fans out** trip-grain measures) |
| `promo_id` | INTEGER → promotions | applied promo |
| `discount_amount` | DECIMAL(6,2) | actual currency discount |
| `applied_ts` | TIMESTAMP | application time |

---

## 3. Landmine inventory

Each landmine is planted by `generator.py` and maps to a canonical family in
CONTENT-SPEC §5. Intensity scales with the belt: **`blue` data is kept clean**
(harsh traps are gated behind `purple`/`black`/`red` via the `harsh` flag);
purple gets mild versions; black and red get the full set.

| # | Family (CONTENT-SPEC §5) | How it is planted | Belts | Which problem steps on it |
|---|--------------------------|-------------------|-------|---------------------------|
| L1 | **NULL-in-NOT-IN** | `dropoff_zone_id`, `driver_id`, `payment_type` are NULL on non-completed trips. `WHERE zone_id NOT IN (SELECT dropoff_zone_id FROM trips …)` collapses to empty. | all | Bk1, P1 |
| L2 | **Ranking ties** | Many trips share an exact `request_ts` second; many drivers share the same max streak length; equal completed-trip counts across zones. ROW_NUMBER vs RANK vs DENSE_RANK diverge. | purple+ | P2, Bk2, R1 |
| L3 | **Join fan-out double-counting** | `trip_promotions` is M:N; joining trips→promotions multiplies `fare_amount`. `vehicles` is 1:N per driver. | all | Bk1 |
| L4 | **Empty / one-row groups & division by zero** | Zones with zero completed trips; riders with a single (or zero) trip; payment types / cities with a zero denominator for a rate. | all | P1, P3, Bk1, R1 |
| L5 | **Boundary dates** | Windows straddle month ends, the **2024-02-29 leap day**, and the **2023-12-31 year boundary** (reached at black/red, where streak/session logic uses them). | black, red | Bk2, R1 |
| L6 | **Duplicate rows** | ~1.2% of ratings are submitted twice (same `trip_id`); ~2% of promo applications duplicate a `(trip_id, promo_id)` pair; the surge feed occasionally duplicates `(zone_id, effective_ts)`. | purple+ | Bk1, Bk2, R1 |
| L7 | **Type-coercion traps** | `geozones.zone_code` is a zero-padded string (`'013'`); comparing/sorting it as a number drops the padding and reorders. | all | Bk1 (join key hygiene), P3 |
| L8 | **Gaps vs islands off-by-one** | Consecutive vs non-consecutive active days per driver (streaks); consecutive vs gapped requests per rider (sessions). Classic `date − row_number` island keys are off by one if days aren't deduped. | black, red | Bk2, R1 |
| L9 | **Late / out-of-order events** | `trip_id` order ≠ `request_ts` order (requests are time-random); some re-request follow-ups are back-dated a few seconds; surge events arrive late. Anything assuming id-order = time-order breaks. | all (surge/backdate: purple+) | Bk1, Bk2, R1 |
| L10 | **NULL vs zero semantics** | `tip_amount` NULL (no info) is distinct from `0.00` (explicit zero). `AVG(tip_amount)` and `COUNT(tip_amount)` silently exclude NULLs; `COALESCE(...,0)` changes the answer. | all | P3-adjacent, Bk1 |
| L11 | **Re-request sessionization** | An unfulfilled request (`no_driver`/`cancelled_driver`) spawns follow-up requests by the same rider within a few minutes (sometimes the same second, sometimes back-dated). One *intent* ⇒ several trip rows. | all | R1 |

Verified present by the self-checks (see §5 of this doc): 0 referential orphans;
NULL `driver_id`/`dropoff_zone_id`/`fare`; NULL-vs-zero tips; multi-promo fan-out;
duplicate ratings and promo pairs; NULL surge on non-completed rows; `request_ts`
ties; leap-day and year-boundary requests; out-of-order rows; sub-5-minute rider
re-requests.

---

## 4. Problem plan

Ladder rule satisfied. Two chains lead to the crown Red:

- **P2 (window ranking) → Bk2 (gaps & islands streaks) → R1 (sessionization).**
- **P1 / P3 (ratios, time buckets) → Bk1 (grain-safe net revenue).**

Every Black has a Purple prerequisite; the Red has a Black prerequisite.

### Blue — B1 · "Busiest pickup zones in a city"

- **Belt:** Blue (clean data; harsh landmines off at blue scale).
- **Scenario:** Operations wants, for one named city, its pickup zones ranked by
  the number of **completed** trips, returning zone name and the completed count,
  highest first, top 10.
- **Techniques:** single-table→dimension JOIN, `WHERE` on city and status,
  `GROUP BY`, `ORDER BY … DESC`, `LIMIT`.
- **Landmines stepped on:** none material (Blue is deliberately clean). The only
  discipline is filtering to `status='completed'` rather than counting all rows.
- **Naive it kills:** nothing is designed to fail here; it is a genuine easy
  problem, not a drill. (It does gently teach that "trips" ≠ "completed trips".)

### Purple — P1 · "Driver acceptance rate by pickup zone"

- **Belt:** Purple (mild landmines).
- **Scenario:** For each pickup zone with at least *K* requests, compute the
  **acceptance rate** = completed trips ÷ total requests, and list zones from
  worst to best. Zones below the request threshold are excluded.
- **Techniques:** conditional aggregation (`SUM(CASE WHEN status='completed' …)`),
  JOIN to `geozones`, `GROUP BY`, `HAVING COUNT(*) >= K`, safe division with
  `NULLIF`/`CAST`.
- **Landmines:** L4 (division by zero for zero-completed zones; empty groups),
  L1 (NULL `driver_id` tempts `COUNT(driver_id)` as a proxy for "matched"),
  integer-division pitfall.
- **Naive it kills:** `COUNT(driver_id)*1.0/COUNT(*)` — miscounts because
  `driver_id` is NULL for `no_driver` *and* some `cancelled_rider` rows, so it
  measures "was a driver ever assigned", not "completed"; also integer division
  truncating to 0.

### Purple — P2 · "First completed trip and time-to-first-ride by cohort"

- **Belt:** Purple (mild landmines).
- **Scenario:** For each rider, find their **first completed trip**; compute days
  from `signup_date` to that trip; bucket riders by signup **month** cohort and
  report the average days-to-first-ride per cohort. Riders who never completed a
  trip are excluded (and that exclusion must be correct, not accidental).
- **Techniques:** window functions (`ROW_NUMBER() OVER (PARTITION BY rider_id
  ORDER BY request_ts, trip_id)`), filtering to the first row, date truncation to
  month, `DATE`/timestamp difference, cohort `GROUP BY`.
- **Landmines:** L2 (ties on `request_ts` — the tiebreak on `trip_id` must be
  explicit and deterministic or the "first" trip is arbitrary), L4 (riders with
  zero completed trips), L9 (id-order ≠ time-order, so `MIN(trip_id)` ≠ first
  trip).
- **Naive it kills:** `MIN(request_ts)` per rider without the `status='completed'`
  filter (counts a cancelled request as "first ride"), and picking the first trip
  by `MIN(trip_id)` (wrong because ids aren't time-ordered).

### Purple — P3 · "Hourly demand and surge profile by city"

- **Belt:** Purple (mild landmines).
- **Scenario:** For each city and **hour of day** (0–23), report total requests,
  the average **applied** surge multiplier, and the share of requests that
  happened under surge (multiplier > 1.0). Order by city, then hour.
- **Techniques:** hour extraction from `request_ts`, JOIN to `geozones`,
  `GROUP BY city, hour`, conditional aggregation for the surged share, average
  over a nullable measure.
- **Landmines:** L10 (`surge_multiplier` is NULL on some non-completed rows —
  `AVG` must decide whether those count), L7 (hour extraction / timestamp
  handling across engines), L4 (hours with no requests), correlation structure
  (rush-hour surge) that punishes averaging the wrong denominator.
- **Naive it kills:** averaging `surge_multiplier` including cancelled rows with
  NULL surge but counting them in the denominator (mixing `AVG(col)` semantics
  with `SUM(col)/COUNT(*)`), producing an understated average.

### Black — Bk1 · "Promotion-adjusted net revenue by zone and vehicle class"

- **Belt:** Black (full landmines). **Prerequisite:** P1 (and P3).
- **Scenario:** Compute **net revenue** = fare minus total applied discount, for
  completed trips only, aggregated by **pickup zone** and **vehicle class**. Also
  report each zone's discount penetration (share of completed trips that used at
  least one promo). Exclude zones that never served as a dropoff via a supplied
  exclusion list.
- **Techniques:** grain-safe aggregation (collapse `trip_promotions` to trip
  grain *before* joining, or aggregate fare and discount on separate grains),
  M:N join control, JOIN through nullable `vehicle_id`→`vehicles`, `NULLIF`,
  NULL-safe set exclusion.
- **Landmines:** L3 (fan-out: a naive `SUM(fare_amount − discount_amount)` over
  the trips⋈trip_promotions join counts fare once per promo row), L6 (duplicate
  `(trip_id, promo_id)` over-discounts), L1 (the "exclude zones not in the
  dropoff set" step uses `NOT IN` over a column containing NULL → empty result),
  L4 (penetration denominator zero for zones with no completed trips), L7 (join
  hygiene), L10 (discount NULL handling).
- **Naive it kills:**
  1. `SELECT pickup_zone_id, SUM(t.fare_amount - tp.discount_amount) FROM trips t
     JOIN trip_promotions tp …` — **fare double-counted** on multi-promo trips (WA).
  2. A correlated per-trip subquery for the discount total — **TLE** at 3M trips.
  3. `… WHERE pickup_zone_id NOT IN (SELECT dropoff_zone_id FROM trips)` — NULLs
     in the subquery yield an empty result (WA).

### Black — Bk2 · "Longest streak of consecutive active days per driver"

- **Belt:** Black (full landmines). **Prerequisite:** P2.
- **Scenario:** An "active day" is a calendar day on which a driver **completed**
  at least one trip. For each driver, find the longest run of consecutive active
  days; return the drivers with the longest streaks, including **all** drivers
  tied at the maximum.
- **Techniques:** reduce trips to distinct (driver, active-day) grain, classic
  **gaps-and-islands** (`active_day − ROW_NUMBER() OVER (PARTITION BY driver
  ORDER BY active_day)` island key), `MAX` streak length per driver, tie-aware
  top ranking (`RANK`/`DENSE_RANK`, not `ROW_NUMBER`).
- **Landmines:** L8 (island off-by-one if days aren't deduped first), L6
  (multiple completed trips per day must collapse to one day), L5 (streaks must
  survive month ends and **2024-02-29**; day arithmetic, not day-of-month), L2
  (many drivers tie on the max streak — `ROW_NUMBER` silently drops them), L9
  (order by day, not by `trip_id`).
- **Naive it kills:**
  1. `COUNT(DISTINCT active_day)` as "streak" — counts total active days, not
     consecutive (WA).
  2. `DATEDIFF(MAX(day), MIN(day)) + 1` — overcounts across gaps (WA).
  3. Not deduping days before the island key → island math corrupted (WA).
  4. `ROW_NUMBER()` for the top list → drops tied drivers (WA).

### Red — R1 · "True request fulfillment via re-request sessionization"

- **Belt:** Red (quant-grade, adversarially verified). **Prerequisite:** Bk2.
- **Scenario:** A rider's consecutive requests separated by **at most 5 minutes**
  form one **intent session**. A session is *fulfilled* if **any** trip in it is
  `completed`. For each city, report the number of sessions, the session-level
  fulfillment rate, and the **median** minutes from session start to the first
  completion within fulfilled sessions. Sessions may span midnight and month
  ends; they must not be split by calendar day.
- **Techniques:** event ordering per rider (`request_ts, trip_id`), **sessionized
  gaps-and-islands with a time threshold** (new session when the gap to the prior
  request exceeds 5 minutes), boundary handling at exactly 5:00, per-session
  fulfillment via `MAX(status='completed')`, per-city aggregation with a
  zero-session guard, and an exact **median** (not `AVG`) over a derived
  distribution.
- **Landmines:** L11 (the whole problem — treating each trip as an independent
  request inflates the denominator and reports the wrong fulfillment rate), L8
  (session-boundary off-by-one; the 5:00 boundary is inclusive/exclusive and must
  match the spec), L9 (requests must be sorted; back-dated follow-ups break
  `LAG` if it isn't ordered by time), L5 (a session crossing midnight or a month
  end must not be split by day), L6 (duplicate trip rows must not create phantom
  sessions), L4 (cities with zero sessions — division guard), L2 (median
  tie-handling on even-sized groups), power-law heavy riders that dominate the
  session distribution.
- **Naive it kills:**
  1. `SUM(status='completed') / COUNT(*)` per city — a per-trip rate, wrong
     denominator entirely (WA).
  2. Sessionizing with `PARTITION BY rider, DATE(request_ts)` — splits sessions
     that cross midnight (WA on boundary days).
  3. `LAG(request_ts) OVER (PARTITION BY rider ORDER BY trip_id)` — wrong order,
     since `trip_id` is not time-ordered (WA).
  4. Median approximated by `AVG` of time-to-first-completion (WA).
  5. A per-rider correlated/self-join sessionization at 7M rows — TLE.

---

## 5. Generator design notes and self-verification

**Determinism.** One `random.Random(seed)` drives everything; control flow is a
function of the seed alone. Dimensions are built first (fixed RNG draw order),
then the surge feed, then trips with their child ratings/promotions streamed in
the same pass. No global `random`, no `datetime.now()`, no set/dict iteration in
output order. Same `(seed, scale)` ⇒ byte-identical CSVs (verified by diff).

**Scale targets** (largest fact table = `trips`): sample 220 · blue 40k · purple
400k · black 3M · red 7M. Child facts are proportional; dimensions are small.

**Memory safety.** Fact tables are written row-by-row to open CSV writers; only
the (small) dimensions live in memory. Measured peak RSS: **99 MB at black (3M
trips)**, **183 MB at red (7M trips, 3.0M ratings, 1.7M promo apps)** — flat in
the fact-row count, confirming streaming.

**Referential integrity.** By construction all foreign keys point to existing
rows; the only "missing" references are intentional NULLs (unmatched drivers,
non-completed dropoff zones, tier-less riders). The sqlite load check reports
**0 orphans** across all 10 FK relationships. There are **no orphan-key
landmines** in this universe — the traps are NULLs, fan-out, grain, ordering and
boundaries, not dangling keys.

**Self-verification performed (all pass):**

1. `python3 generator.py --seed 42 --scale sample --out /tmp/uv_rideloop` exits 0
   and emits all 9 table CSVs; every header matches `schema.sql` column order.
2. Two runs at the same seed diff **byte-identical**; a different seed differs.
3. Sample CSVs load into an in-memory sqlite built from `schema.sql`; 10
   referential checks report **0 orphans**; sanity joins (completed trips by
   city, status distribution) are sensible.
4. Landmine spot-checks confirmed at the relevant belts: NULL
   `driver_id`/`dropoff_zone_id`/`fare`; NULL-vs-zero tips; multi-promo fan-out;
   duplicate ratings and duplicate promo pairs (purple+); NULL surge on
   non-completed rows; `request_ts` ties; leap-day (2024-02-29) and year-boundary
   (2023-12-31) requests (black/red); out-of-order rows; sub-5-minute rider
   re-requests.

**Deviations from spec:** none. Portable DDL only; 9 tables (within 5–9); pure
stdlib; scale bands within the CONTENT-SPEC §1 envelope. One deliberate design
choice worth flagging for Gate A: **Blue is kept clean by gating harsh landmines
behind a `harsh` flag** (`purple`/`black`/`red`), so the same generator produces
belt-appropriate difficulty — clean for Blue, mild for Purple, full for
Black/Red — while remaining a single deterministic program.
