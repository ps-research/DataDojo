# MetricForge

| | |
|---|---|
| **Slug** | `metricforge` |
| **Theme** | SaaS product analytics: events, sessions, funnels, retention, feature flags, experiments |
| **Problem budget** | Blue 1, Purple 2, Black 2, Red 1 |
| **Largest fact table** | `events` (5M-10M rows at red scale) |
| **Generator** | `generator.py` (deterministic, seeded, streaming, pure stdlib) |

---

## 1. Narrative

MetricForge is the in-house analytics warehouse of a mid-market SaaS company that
sells a collaborative workspace product. Every click, page load, feature toggle
and checkout attempt in the product emits an event; those events roll up into
sessions, sessions into user journeys, and user journeys into the numbers the
growth, product and finance teams argue over every Monday. The data team owns the
warehouse but not the instrumentation — the events arrive exactly as the client
SDKs send them, which means retries double-fire, mobile clocks drift, sessions are
abandoned mid-funnel and never closed, and a stubborn slice of traffic carries no
geo at all. The warehouse is honest about this: it stores what happened, not what
the dashboard wishes had happened.

The company runs on flags and experiments. Nearly every feature ships behind a
feature flag with a staged rollout, and most flags are wrapped in an A/B
experiment before they graduate. Users are bucketed into a `control` or
`treatment` variant at exposure time and their downstream behaviour is compared.
Reality is messier than the experiment design doc: the same user is sometimes
enrolled in two overlapping experiments at once, occasionally lands in both
variants of the same experiment after a client rehydrate, and now and then gets
logged twice. Some experiments are still running (no end date); some were aborted;
a few have a variant that nobody in that segment ever converted on.

Money enters through subscriptions. An account starts free or on a starter plan,
climbs the tier ladder — free, starter, pro, enterprise — and each change writes a
new row to the billing history, with plan changes and churn conveniently landing
on month-end boundaries. Free accounts pay nothing, which is exactly the zero that
breaks a naive growth-rate query. The simulated world spans **2024-01-01 to
2025-03-31** on purpose: it straddles the leap day 2024-02-29 and the 2024/2025
year boundary, so any analysis that buckets by week, month or year has to survive
a calendar that does not round off cleanly. MetricForge is the universe where the
"obvious" query returns a plausible, confident, wrong number.

---

## 2. Scale sizing

Row counts are driven by the user population; `events` (the largest fact table)
lands in the CONTENT-SPEC band for each belt. Verified counts (generator seed
shown), plus peak generator memory at red:

| Scale | n_users | events | sessions | band rule | observed |
|-------|--------:|-------:|---------:|-----------|----------|
| sample | 24 | ~736 | ~115 | hundreds total | ~920 rows total (seed 42) |
| blue | 1,500 | 30,425 | 5,385 | <= 50k | in band (seed 7) |
| purple | 15,000 | 318,457 | 55,604 | <= 500k | in band (seed 7) |
| black | 90,000 | 1,906,883 | 334,208 | 1M-5M | in band (seed 7) |
| red | 290,000 | 6,150,972 | 1,080,676 | 5M-10M | in band (seed 7), peak RSS 21.8 MB |

The simulation window (2024-01-01 .. 2025-03-31, 456 days) is identical across
scales so the boundary-date landmines are stable. Sessions and events are streamed
row-by-row to CSV; only the small dimension tables (accounts, flags, experiments)
are held in memory, so red generation peaks at ~22 MB.

---

## 3. Table dictionary

Eight tables. Portable DDL in `schema.sql` (INTEGER / BIGINT / DECIMAL / VARCHAR /
DATE / TIMESTAMP only). Foreign keys are documented as comments; loaders
materialise the constraints per engine.

### `accounts` — customer organisations (tenants)
| Column | Type | Meaning / notes |
|--------|------|-----------------|
| `account_id` | INTEGER PK | Tenant id. |
| `account_name` | VARCHAR(120) | Display name (`Account NNNNN`). |
| `plan_tier` | VARCHAR(20) | Current tier: `free`/`starter`/`pro`/`enterprise` (= last subscription row). Not alphabetically ordered by value. |
| `signup_date` | DATE | Account creation date. |
| `region` | VARCHAR(40) | `NA`/`EMEA`/`APAC`/`LATAM`, **NULL ~10%** (geo unknown). |
| `industry` | VARCHAR(40) | Vertical label. |
| `is_active` | INTEGER | 0/1, derived from current subscription status. |

### `users` — end users within an account
| Column | Type | Meaning / notes |
|--------|------|-----------------|
| `user_id` | INTEGER PK | User id. |
| `account_id` | INTEGER | FK -> `accounts`. Power-law: a few whale accounts hold many users. |
| `signup_ts` | TIMESTAMP | Cohort anchor (defines retention cohorts). Sits just before the user's first session. |
| `country` | VARCHAR(40) | ISO-ish code, **NULL ~8%** (geo-IP miss). |
| `referral_channel` | VARCHAR(30) | `organic`/`paid_search`/`social`/`referral`/`email`/`partner`, **NULL ~5%**. |
| `device_type` | VARCHAR(20) | `desktop`/`mobile`/`tablet`. |
| `is_internal` | INTEGER | 0/1. **Staff / QA / test users (~4%)** that real metrics must exclude. |

### `feature_flags` — feature-flag catalogue
| Column | Type | Meaning / notes |
|--------|------|-----------------|
| `flag_id` | INTEGER PK | Flag id. |
| `flag_key` | VARCHAR(60) | Human key, e.g. `bulk_export`. |
| `description` | VARCHAR(200) | Free text. |
| `created_date` | DATE | When the flag was created. |
| `rollout_pct` | INTEGER | 0..100 staged rollout. |
| `is_deprecated` | INTEGER | 0/1. Deprecated flags still appear (sparsely) in events. |

Flag popularity follows a Zipf law by creation order (earlier flags used more).

### `experiments` — A/B experiments
| Column | Type | Meaning / notes |
|--------|------|-----------------|
| `experiment_id` | INTEGER PK | Experiment id. |
| `experiment_key` | VARCHAR(60) | Human key, e.g. `checkout_redesign`. |
| `flag_id` | INTEGER | FK -> `feature_flags`, **NULL ~60%** (not all experiments are flag-backed). |
| `start_date` | DATE | Enrolment start. |
| `end_date` | DATE | **NULL == still running** (~25%). |
| `status` | VARCHAR(20) | `running`/`completed`/`aborted`. |
| `primary_metric` | VARCHAR(40) | Event type that defines conversion (`purchase`, `start_checkout`, `view_plans`, `feature_used`, `activation`). |

### `experiment_assignments` — variant bucketing (bridge/fact)
| Column | Type | Meaning / notes |
|--------|------|-----------------|
| `assignment_id` | INTEGER PK | Row id. |
| `experiment_id` | INTEGER | FK -> `experiments`. |
| `user_id` | INTEGER | FK -> `users`. |
| `variant` | VARCHAR(20) | `control`/`treatment`. |
| `assigned_ts` | TIMESTAMP | When bucketed (near experiment start). |

**Not one row per user.** A user may be enrolled in multiple experiments, may be
duplicated within one experiment, and may appear in **both** variants of the same
experiment (contamination). Joining events to this table naively fans out.

### `subscriptions` — billing history
| Column | Type | Meaning / notes |
|--------|------|-----------------|
| `subscription_id` | INTEGER PK | Row id. |
| `account_id` | INTEGER | FK -> `accounts`. **1-3 rows per account** (plan history). |
| `plan_tier` | VARCHAR(20) | Tier for this period. |
| `started_date` | DATE | Period start. |
| `ended_date` | DATE | **NULL == currently active**; otherwise a **month-end** boundary date. |
| `mrr_amount` | DECIMAL(10,2) | Monthly recurring revenue; **exactly 0.00 on free** (zero denominator). |
| `status` | VARCHAR(20) | `active`/`upgraded`/`churned`/`paused`. |

### `sessions` — user sessions
| Column | Type | Meaning / notes |
|--------|------|-----------------|
| `session_id` | BIGINT PK | Session id. |
| `user_id` | INTEGER | FK -> `users`. |
| `started_ts` | TIMESTAMP | Session start. |
| `ended_ts` | TIMESTAMP | **NULL ~12%** (abandoned / still open). |
| `device_type` | VARCHAR(20) | Device for the session. |
| `app_version` | VARCHAR(15) | Text version (`8.9`,`9.2`,`9.10`,`10.0`,`10.12`,`11.0`); **lexical order != numeric order**. |
| `is_bounce` | INTEGER | 0/1. **Bounce sessions carry zero events** (empty groups). |

### `events` — primary fact table (largest)
| Column | Type | Meaning / notes |
|--------|------|-----------------|
| `event_id` | BIGINT PK | Event id (monotonic, but **not** aligned to `event_ts`). |
| `session_id` | BIGINT | FK -> `sessions`. |
| `user_id` | INTEGER | FK -> `users` (denormalised). |
| `event_ts` | TIMESTAMP | Event time. **May be earlier than the session start** (late / clock-skew). |
| `event_type` | VARCHAR(30) | `page_view`, `feature_used`, funnel steps `view_plans`->`start_checkout`->`enter_payment`->`purchase`, `search`, `error`. |
| `flag_id` | INTEGER | FK -> `feature_flags`, **NULL unless `feature_used`**. |
| `event_value` | DECIMAL(12,2) | Revenue on `purchase` (discrete price points `29/49/99/199/499` -> exact ties); **NULL otherwise, and NULL on ~3% of purchases** (dirty). |
| `page_path` | VARCHAR(80) | Path for page/funnel events; NULL for others. |

**Referential integrity:** every non-NULL foreign key resolves to a parent row
(verified: 0 orphans on the sample). All "missingness" is expressed as NULLs, not
as dangling keys, so `NOT IN` / anti-join traps are genuine NULL traps rather than
orphan-row accidents.

---

## 4. Landmine inventory

Every family from CONTENT-SPEC section 5 is planted and was verified present on
the seed-42 `sample` fixture (representative counts in parentheses) and confirmed
to scale.

| # | CONTENT-SPEC family | Where it lives | How it is planted | Sample evidence |
|---|---------------------|----------------|-------------------|-----------------|
| L1 | **NULL-in-NOT-IN** | `users.country`/`referral_channel`, `accounts.region`, `experiments.flag_id`/`end_date`, `subscriptions.ended_date`, `events.flag_id`, `sessions.ended_ts` | Meaningful NULLs in filterable columns | country NULL (2), region NULL (2), running exp end NULL (2), active sub NULL (5), event flag NULL (518) |
| L2 | **Ranking ties** (ROW_NUMBER vs RANK vs DENSE_RANK) | `events.event_value` (discrete `29/49/99/199/499`), per-user purchase counts, tail feature usage | Discrete price points guarantee exact revenue ties; small integer counts collide by pigeonhole | 2 exact-revenue tie groups; users tied on purchase count (1 group); tied feature distinct-user count |
| L3 | **Join fan-out double-counting** | `experiment_assignments` (multi-experiment, both-variant, duplicate rows); `subscriptions` (1-3 rows/account) | User enrolled in >1 experiment and/or both variants; account has multiple billing rows | users in >1 experiment (1), user+exp in both variants (2), accounts with >1 sub (4) |
| L4 | **Empty / one-row groups** | bounce `sessions` (0 events); (experiment, variant) cells with 0 conversions; zero-entrant funnel segments | Bounces emit no events; sparse conversion leaves empty cells | bounce sessions (13); zero-conversion exp-variant cells (5 of 6) |
| L5 | **Boundary dates** (leap year, month end, year/week boundary) | `events.event_ts`, `subscriptions.ended_date`, window spans 2024-02-29 and 2024/2025 boundary | Forced activity on 2024-02-29 and 2024-12-31; churn/upgrade end dates snapped to month-end | leap-day events (8), year-end events (15), month-end sub endings (5) |
| L6 | **Duplicate rows** | `events` double-fires; `experiment_assignments` re-logs | ~2.5% of sessions double-fire one event (identical business columns, new id); assignments occasionally re-logged | duplicate event business-key groups (2) |
| L7 | **Type-coercion traps** | `sessions.app_version` (text), `plan_tier` (ordinal-as-text) | Versions chosen so `"10.0" < "9.0"` and `"9.10" < "9.2"` lexically; tier order is business, not alphabetic | 8 distinct versions where text sort != semantic version sort |
| L8 | **Gaps vs islands off-by-one** | per-user active weeks/days from `sessions`/`events` | Heavy-tailed, sparse activity leaves gaps between active weeks | streak/gap structure present across the 456-day window |
| L9 | **Late / out-of-order events** | `events.event_ts` vs `sessions.started_ts`; `event_id` not time-ordered | ~4% of sessions push one event before the session start | events before their session start (3) |
| L10 | **Division by zero in rates** | funnel conversion rates, experiment lift, MRR growth | zero-entrant funnel cells, zero-conversion variants, `mrr_amount = 0.00` on free | zero-conversion cells (5); free subs with MRR 0.00 (1) |

Guaranteed-presence guards (independent of seed luck): user 1 always has active
sessions on the leap day **and** the year-end boundary (each reaching `purchase`);
user 2 is always contaminated (both variants + a duplicate of one experiment);
user 3 is always enrolled in two experiments; user 4 is always internal. This
keeps the traps visible even in the tiny sample fixture.

---

## 5. Problem plan

Ladder within the universe (enforced): **Blue -> Purple -> Black -> Red.** The Red
requires both Blacks as prerequisites (it composes retention and experiment
analysis); each Black requires a Purple that introduces its core technique.

```
Blue  Feature Adoption Leaderboard
  |
Purple A  Session Upgrade-Funnel Conversion by Channel   ---> Black B
Purple B  Weekly Active Users & Week-over-Week Growth     ---> Black A
  |                                                             |
Black A  Cohort Retention Matrix (W0-W8)  --------------\       |
Black B  A/B Experiment Lift with Contamination  -------- +--> Red  Retention-Qualified Experiment Uplift Ranking
```

---

### Blue 1 — "Feature Adoption Leaderboard"

**Scenario.** The product team is preparing a launch review. For a given calendar
month they want, for every feature flag, how many **distinct** users triggered a
`feature_used` event for it, ranked from most- to least-adopted, with the feature
key as a deterministic tie-break. The result feeds a simple bar chart, so it must
be one clean row per feature.

**Techniques.** INNER JOIN `events` -> `feature_flags`; filter by `event_type =
'feature_used'` and a month range on `event_ts`; `GROUP BY flag_key`;
`COUNT(DISTINCT user_id)`; `ORDER BY adopters DESC, flag_key ASC`.

**Landmines it steps on.** L6 duplicate/double-fired events and repeat usage by
the same user (a user who uses a feature ten times, plus a double-fire, is still
one adopter); L1 `events.flag_id` NULL for every non-`feature_used` row (must not
leak into the join/count); L2 tie-break discipline in the ordering.

**Naive solution it kills.** `COUNT(*)` (or `COUNT(user_id)`) instead of
`COUNT(DISTINCT user_id)` — it inflates every feature by repeat usage and by the
double-fired duplicates, changing both the numbers and the ranking. Clean at blue
scale otherwise (single core technique), which is what makes it a Blue.

---

### Purple A — "Session Upgrade-Funnel Conversion by Channel"

**Scenario.** Growth wants the in-session upgrade funnel
`view_plans -> start_checkout -> enter_payment -> purchase` broken down by the
user's `referral_channel`. For each channel, report how many sessions entered the
funnel (reached `view_plans`) and the step-to-step conversion rate down to
`purchase`. A session counts for a step only if it reached that step **after** the
previous step in event-time order.

**Techniques.** Per-session conditional aggregation with time ordering
(`MIN(CASE WHEN event_type = ... THEN event_ts END)` per step and comparing the
monotonic sequence, or ordered window functions); JOIN to `users` for channel;
`GROUP BY channel`; rate = step_n / step_(n-1) using `NULLIF`/`CASE` to avoid
divide-by-zero.

**Landmines.** L9 late/out-of-order events (`event_id` order != time order — the
funnel must be established on `event_ts`, and an event that arrives before its
session start must not manufacture a phantom step ordering); L1 NULL
`referral_channel` (a real segment, not droppable silently, and not
`NOT IN`-safe); L10 channels/steps with zero entrants -> division by zero; L4
one-row/no-funnel sessions.

**Naive solution it kills.** Ordering the funnel by `event_id` (or by insertion
order) instead of `event_ts`, and computing `converted / entered` as a bare
division. The `event_id` assumption silently reorders steps for the out-of-order
sessions; the bare division errors (or returns NULL and drops the row) for a
channel with zero funnel entrants.

---

### Purple B — "Weekly Active Users & Week-over-Week Growth"

**Scenario.** Report weekly active users (distinct users with >= 1 non-internal
event in an ISO week) across the whole window, and the week-over-week percentage
change. The finance deck needs the year-boundary weeks handled correctly and the
first populated week to show a defined (not error) growth value.

**Techniques.** ISO-week bucketing of `event_ts`; `COUNT(DISTINCT user_id)` per
week; `LAG(...)` window function for the prior week; growth =
`(wau - prev) / prev` guarded with `NULLIF`; exclude `is_internal = 1`.

**Landmines.** L5 boundary dates — naive `strftime('%Y')||strftime('%W')` (or
`YEAR()*100 + WEEK()`) mis-buckets the 2024/2025 turn and the leap-year week
count, splitting or merging weeks; L10 the first week has no predecessor -> WoW
division by zero; L1/L7 internal users must be excluded, and `is_internal` is a
0/1 flag not a truthy string.

**Naive solution it kills.** Bucketing weeks with year-agnostic week numbers so
week 1 of 2025 collides with or is dropped relative to the tail of 2024, plus a
raw `/prev` that errors on the first week. Also kills solutions that count
sessions or rows instead of distinct users, and that forget to drop internal
traffic.

---

### Black A — "Cohort Retention Matrix (W0-W8)"  *(prereq: Purple B)*

**Scenario.** Build the classic signup-cohort retention triangle. Group users by
the ISO week of `signup_ts` (the cohort). For each cohort and each week offset
`W0..W8`, report the number of users from that cohort who were active (>= 1
non-internal event) in that offset week, and the retention rate versus the cohort
size (W0). Output one row per (cohort_week, week_offset).

**Techniques.** Cohort assignment by signup week; per-user activity weeks;
offset = weeks between activity week and signup week; pivot/conditional
aggregation across offsets; `COUNT(DISTINCT user_id)`; rate over cohort size with
`NULLIF`; correct week arithmetic across the year boundary and leap day. Real TLE
pressure at ~1.9M events: the reference must aggregate to a per-user-per-week grain
before the cohort cross-join rather than self-joining events to events.

**Landmines.** L5 leap-year/year-boundary week math (offset computed by naive
`week - signup_week` integer arithmetic breaks across 2024->2025); L8 gaps vs
islands off-by-one (a user active in W0 and W3 but not W1/W2 must contribute to
W0 and W3 only — an inclusive/exclusive off-by-one silently shifts the whole
triangle); L1 internal users excluded; L4 small/late cohorts with one active week
(empty offset cells must read 0, not vanish); L6 duplicate events must not inflate
distinct-user activity.

**Naive solution it kills (correctness).** Computing the week offset as raw
`(iso_week_active - iso_week_signup)` without year-normalisation — it produces
negative or 53-off offsets around the boundary and misassigns entire cohorts.
**Naive solution it kills (TLE).** A correlated self-join of `events` to `events`
(one side for signup week, one for activity week) that is quadratic on the large
fixture and blows the time limit while the set-based reference stays well under it.

---

### Black B — "A/B Experiment Lift with Assignment Contamination"  *(prereq: Purple A)*

**Scenario.** For every completed experiment, compute the conversion rate on its
`primary_metric` for `control` vs `treatment` and the absolute lift
(treatment_rate - control_rate), counting a user as converted if they performed
the primary-metric event **after** their assignment time. Only clean assignments
count: a user who was contaminated (enrolled in both variants of that experiment,
or in more than one experiment overlapping in time) must be excluded from that
experiment's result, and duplicate assignment rows must not double-count a user.

**Techniques.** De-duplicate/qualify `experiment_assignments` (identify and drop
contaminated users via `GROUP BY ... HAVING COUNT(DISTINCT variant) > 1` and
multi-experiment overlap); anti-join for exclusion done NULL-safely; join surviving
assignments to conversion events with an `assigned_ts` time predicate; per
(experiment, variant) conversion rate with `NULLIF`; only `status = 'completed'`
and `end_date IS NOT NULL`.

**Landmines.** L3 join fan-out — a naive `assignments JOIN events` multiplies
conversions for users in several experiments/variants and for duplicated rows;
L1 running experiments (`end_date` NULL) and the `NOT IN (contaminated_users)`
anti-join going empty when the subquery contains a NULL; L10 a variant with zero
qualified users -> divide-by-zero lift; L2 exact ties when ranking experiments by
lift; L4 one-variant experiments after contamination removal.

**Naive solution it kills.** `SELECT experiment_id, variant, AVG(converted) FROM
assignments JOIN events ...` with no de-duplication and no contamination filter:
the fan-out double-counts contaminated and duplicated users, and
`WHERE user_id NOT IN (SELECT user_id FROM contaminated)` returns zero rows the
moment the contaminated set includes a NULL user_id path — both yield a
confidently wrong lift. Also kills `WHERE end_date < today`-style filters that
mis-handle the NULL running experiments.

---

### Red 1 — "Retention-Qualified Experiment Uplift Ranking"  *(prereqs: Black A + Black B)*

**Scenario.** The company will greenlight the single experiment with the strongest
uplift among **engaged** users, and needs a defensible ranking. For each completed
experiment, restrict to users who were *continuously engaged* after assignment —
they must have at least one session in **each** of the first `K` consecutive weeks
following their assignment week (an unbroken island of activity, no gap). Among
those retention-qualified users, and excluding all contaminated users (both-variant
or multi-experiment overlap) and internal users, compute the treatment-vs-control
uplift on the experiment's `primary_metric` (conversion measured strictly after
`assigned_ts`). Rank experiments by uplift descending; break ties by qualified
sample size descending, then `experiment_key` ascending. Handle experiments where
a variant has zero qualified users. Return the ranked table with rank position.

**Techniques.** Gaps-and-islands streak qualification per user (consecutive active
weeks with no gap) built on top of a per-user-per-week activity grid; the Black B
contamination/de-duplication logic; the Black A week-offset arithmetic across the
leap day and year boundary; NULL-safe anti-joins; conversion with an `assigned_ts`
predicate; per-variant rate with `NULLIF`; multi-key ranking with an explicit
deterministic tie-break (`RANK`/`DENSE_RANK` vs `ROW_NUMBER` matters because
uplift ties are real). Severe TLE pressure at ~6.15M events: everything must be
driven off pre-aggregated per-user-per-week islands, never event-level self-joins.

**Landmines.** Composes L8 (streak off-by-one — "each of the first K weeks" is an
inclusive island; an off-by-one either admits users with a one-week gap or rejects
qualified ones), L5 (offset weeks across 2024/2025 and the leap day), L3 (fan-out
from contamination and duplicate assignments), L1 (NULL-in-NOT-IN on the
contaminated/internal exclusion), L10 (zero-qualified variant -> divide-by-zero
uplift, must survive as a defined result or documented exclusion), L2 (uplift ties
requiring the full multi-key deterministic ordering), L6 (duplicate events not
inflating weekly activity), L9 (late events not fabricating an active week).

**Naive solution it kills.** Any attempt that (a) qualifies "engaged" users by a
**total** active-week count (`HAVING COUNT(DISTINCT week) >= K`) instead of a
**consecutive** island — this admits users with gaps and changes the qualified
cohort, hence the ranking; (b) reuses the fan-out-prone `assignments JOIN events`
from a naive Black B attempt; (c) ranks by `ROW_NUMBER` so tied uplifts get an
arbitrary order that disagrees with the reference; or (d) self-joins events at 6M+
rows and exceeds the time limit. The problem is prerequisite-locked behind Black A
(retention/week math) and Black B (contamination handling); a solver who has not
internalised both will not converge.

---

## 6. Generator notes (for the farm)

* CLI: `python3 generator.py --seed N --scale {sample|blue|purple|black|red} --out DIR`.
* Deterministic: one `random.Random(seed)`, fixed generation order, no
  `datetime.now()`, no reliance on set/dict iteration for output. Same seed +
  scale is byte-identical (verified).
* Streaming: `sessions` and `events` are written row-by-row; only dimensions are
  in memory (red peak RSS ~22 MB).
* NULLs are emitted as empty CSV fields (RFC4180, `QUOTE_MINIMAL`), which loaders
  map to SQL NULL. Free-tier MRR is written as `0.00` (a real zero, not NULL).
* Visible sample vs hidden fixture: use a different `--seed` and the belt `--scale`
  for the hidden fixture so hardcoding the visible-sample answer fails (G2).
