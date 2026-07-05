# PulseStream — universe design

| | |
|---|---|
| **Slug** | `pulsestream` |
| **Theme** | Music / video streaming: artists, tracks, listeners, plays, subscriptions, royalties |
| **Problem budget** | 7 — Blue 2, Purple 3, Black 2, Red 0 |
| **Largest fact table** | `plays` (streamed to CSV; 480 rows at sample up to ~6M at red) |
| **Generator** | `generator.py` — pure stdlib, single seeded PRNG, byte-deterministic |

---

## 1. Narrative

PulseStream is a global on-demand audio and video service. Two sides of a
marketplace meet inside it: on one side, tens of millions of **listeners** who
open the app on a phone, a laptop, or a smart speaker and press play; on the
other, a **catalog** of artists whose tracks live inside albums, singles, and
compilations. Every time a listener presses play, PulseStream writes one row to
the `plays` firehose — the beating heart of the company and the source of both
its product analytics and its financial obligations. Plays are logged as they
arrive from clients, which means the firehose is *not* in chronological order:
an offline listen on a subway ride syncs hours later, a flaky client retries and
double-logs the same stream, and a backfill job drops week-old events in behind
today's.

Money flows the other way. Listeners pay through **subscriptions** — a free
tier, time-boxed trials, and paid student / family / premium plans — and each
paid stream accrues a micro-royalty to the artist who owns the track. The rate a
stream earns is not a constant: it depends on the listener's plan, the
listener's consumption market (country), and *when* the stream happened, because
the finance team revised the whole rate card on 1 January 2024. Every month the
payouts system totals what each artist earned and issues a statement in
`artist_payouts`. Reality being reality, those statements drift from the ledger:
some months are overpaid, some are quietly still pending, a few newly-signed
artists have accrued royalties but no statement yet, and the occasional
unattributed manual adjustment lands with no artist at all.

That tension — a clean-looking schema sitting on top of a firehose full of
late events, overlapping plan histories, ties, boundary dates, and a rate card
that changes mid-stream — is what the PulseStream problems are built to probe.
The easy belts ask honest business questions of clean slices; the hard belts
force the solver to survive the firehose.

---

## 2. Table dictionary

Eight tables. Column order below is exactly the CSV column order emitted by the
generator. Foreign keys are documented as comments in `schema.sql`; loaders
materialize them per engine.

### `artists` — rights holders
| Column | Type | Notes |
|---|---|---|
| `artist_id` | INTEGER PK | 1..N |
| `name` | VARCHAR(120) | synthetic two-word name |
| `country` | VARCHAR(2) | ISO-2 home market; **NULL ≈ 7%** (unknown) |
| `primary_genre` | VARCHAR(40) | **NULL ≈ 6%** (uncategorized) |
| `signed_date` | DATE | roster join date (before the play window) |
| `monthly_listeners_est` | BIGINT | denormalized log-scaled stat; **NULL ≈ 5%** (stale) |

### `albums` — release groupings
| Column | Type | Notes |
|---|---|---|
| `album_id` | INTEGER PK | |
| `artist_id` | INTEGER | FK → `artists` |
| `title` | VARCHAR(160) | |
| `release_date` | DATE | |
| `album_type` | VARCHAR(20) | album / ep / single / compilation |

### `tracks` — the streamable unit
| Column | Type | Notes |
|---|---|---|
| `track_id` | INTEGER PK | |
| `artist_id` | INTEGER | FK → `artists` |
| `album_id` | INTEGER | FK → `albums`; **NULL ≈ 18%** (non-album single) |
| `title` | VARCHAR(200) | |
| `genre` | VARCHAR(40) | **NULL ≈ 6%** (uncategorized) |
| `duration_sec` | INTEGER | length in **seconds**; **NULL ≈ 2%** (legacy) |
| `release_date` | DATE | |
| `is_explicit` | INTEGER | 0 / 1 |
| `isrc` | VARCHAR(15) | alphanumeric code, e.g. `USRC0700123`; **never numeric** |

### `users` — listener accounts
| Column | Type | Notes |
|---|---|---|
| `user_id` | INTEGER PK | |
| `display_name` | VARCHAR(80) | |
| `country` | VARCHAR(2) | consumption market; **NULL ≈ 5%** → royalty falls back to global rate |
| `birth_year` | INTEGER | **NULL ≈ 12%** (undisclosed) |
| `signup_date` | DATE | skewed early; a play can never precede it |
| `referral_source` | VARCHAR(30) | **NULL ≈ 15%** (organic/unknown) |

### `subscriptions` — plan periods
| Column | Type | Notes |
|---|---|---|
| `subscription_id` | INTEGER PK | |
| `user_id` | INTEGER | FK → `users` |
| `plan` | VARCHAR(20) | free / trial / student / family / premium |
| `started_at` | DATE | |
| `ended_at` | DATE | **NULL = still active** (meaningful NULL) |
| `price_usd` | DECIMAL(6,2) | monthly price (0.00 for free/trial) |
| `is_auto_renew` | INTEGER | 0 / 1 |

A user has several rows over time (free → paid → churn → resubscribe). About 9%
of paying users carry a **second paid row that overlaps** an existing paid
period (a migration/data-entry glitch). Active-on-day semantics:
`started_at <= day <= COALESCE(ended_at, +∞)`. When several plans are active at
once, the highest-precedence plan wins — `premium > family > student > trial >
free`, ties broken by later `started_at`.

### `plays` — the event firehose (largest fact)
| Column | Type | Notes |
|---|---|---|
| `play_id` | BIGINT PK | surrogate; **NOT chronological** |
| `user_id` | INTEGER | FK → `users` |
| `track_id` | INTEGER | FK → `tracks` |
| `played_at` | TIMESTAMP | event wall-clock; order ≠ `play_id` order |
| `ms_played` | BIGINT | **milliseconds** listened; **NULL ≈ 4%** (telemetry missing) |
| `device` | VARCHAR(20) | ios / android / web / desktop / smart_speaker; **NULL ≈ 3%** |
| `source` | VARCHAR(20) | search / playlist / album / radio / artist_page / daily_mix |
| `is_offline` | INTEGER | 0 / 1 (offline plays often sync late) |

### `royalty_rates` — the rate card
| Column | Type | Notes |
|---|---|---|
| `rate_id` | INTEGER PK | |
| `plan` | VARCHAR(20) | matches `subscriptions.plan` |
| `country` | VARCHAR(2) | consumption market; **NULL = global fallback** |
| `effective_from` | DATE | **inclusive** |
| `effective_to` | DATE | **exclusive**; NULL = open-ended |
| `per_play_usd` | DECIMAL(10,6) | USD per qualifying stream; **0.000000 for free/trial** |

Two epochs per `(plan, market)` split at `2024-01-01`. Lookup precedence:
country-specific row first, else the global (`country IS NULL`) row.

### `artist_payouts` — what finance actually paid
| Column | Type | Notes |
|---|---|---|
| `payout_id` | INTEGER PK | |
| `artist_id` | INTEGER | FK → `artists`; **NULL = unattributed adjustment** |
| `period_month` | DATE | first day of the accounting month |
| `amount_usd` | DECIMAL(12,2) | |
| `status` | VARCHAR(20) | paid / pending / reversed |

Payouts are derived from the generator's own royalty accrual, then deliberately
perturbed (see landmine L11). A top slice of artist ids (~1.5%, min 1) is
**withheld entirely** — accrued but never issued a statement.

**Referential integrity:** every FK resolves except the two documented,
intentional NULL cases — `tracks.album_id` (singles) and `artist_payouts.artist_id`
(adjustments). The sample-fixture smoke reports **0 orphans** on all other joins.

---

## 3. Landmine inventory

Every landmine below is planted by `generator.py` and verified present in the
sample fixture (counts in parentheses are from `--seed 42 --scale sample`;
populations grow at hidden-fixture scale). Family names follow CONTENT-SPEC §5.

| # | Landmine | Family | Where planted | Sample count |
|---|---|---|---|---|
| L1 | Meaningful NULL `ended_at` = "still active" | NULL semantics | `subscriptions` | 17 active |
| L2 | NULL in an anti-join key + artists absent from payouts | **NULL-in-NOT-IN** | `artist_payouts.artist_id` NULL rows + withheld artists | 1 NULL row, 2 absent artists |
| L3 | NULL `genre` / `country` must not silently drop rows | NULL semantics | `tracks.genre`, `users.country`, `artists.country` | 1 / 4 / 1 |
| L4 | NULL `ms_played` must be excluded from rate denominators, not counted as 0 | NULL semantics | `plays.ms_played` | 11 |
| L5 | Ranking ties across equal play counts | **ranking ties** | aggregated `plays` | 10 shared counts |
| L6 | Overlapping paid subscription periods → join fan-out | **join fan-out double-count** | `subscriptions` | 1 overlap pair |
| L7 | Tracks that exist but were never played → LEFT JOIN 0 → divide-by-zero | **division by zero / empty groups** | `tracks` (zero play-weight slice) | 5 dark tracks |
| L8 | Leap day `2024-02-29`, year boundary, month ends | **boundary dates** | `plays.played_at` (guaranteed injection) | 4 leap-day plays |
| L9 | Rate-card revision on `2024-01-01`; `[from, to)` half-open ranges | **boundary dates** | `royalty_rates` epochs | 2 epochs × card |
| L10 | Duplicate events (same natural key, new `play_id`) from client retries | **duplicate rows** | `plays` | 1 dup group |
| L11 | Payout ≠ computed royalty (over/under/pending/reversed/missing) | reconciliation / empty groups | `artist_payouts` | 2 pending, 2 reversed |
| L12 | `ms_played` is **milliseconds**, `duration_sec` is **seconds** | **type / unit coercion** | `plays` vs `tracks` | boundary `ms=30000` ×14 |
| L13 | `isrc` is alphanumeric with leading-zero segments — never numeric | **type coercion** | `tracks.isrc` | all rows |
| L14 | `play_id` order ≠ `played_at` order (late / out-of-order events) | **late / out-of-order events** | `plays` | 237 backward adjacencies |
| L15 | Zero-value plays (free/trial rate 0.000000) accrue nothing | division / zero-value | `royalty_rates` + free plays | 16 zero-rate rows |

---

## 4. Problem plan

Ladder rule (CONTENT-SPEC §3): no Red in this universe, so no Red→Black lock is
required; both Blacks are unlocked by the three Purples that precede them. The
intended prerequisite chain is **Blue → Purple → Black**, and each Black names a
Purple prerequisite below.

Difficulty budget honored: **Blue 2, Purple 3, Black 2**.

### BLUE-1 — "Breakout Tracks of the Month"
**Scenario.** The editorial team wants the ten most-played tracks in a single
named month (e.g. June 2024) to feature on a "Breakout" shelf, shown with track
title and artist name. Data for this problem is a clean slice — one month, inner
joins only.
**Techniques.** `WHERE` date-range filter · `JOIN` plays→tracks→artists ·
`GROUP BY` · `COUNT(*)` · `ORDER BY … DESC` · `LIMIT`.
**Landmines stepped on (mild).** L5 (ties at the 10th/11th boundary — the
statement fixes a deterministic tie-break so the answer is unique).
**Naive it kills.** None expected to fail at Blue; this is the honest baseline
that later belts build on. The only trap is forgetting the artist join and
returning `track_id` instead of a human-readable title.

### BLUE-2 — "Listening Minutes by Genre"
**Scenario.** Marketing wants total listening **minutes** per genre for the
catalog, ranked, to size genre campaigns. Minutes = `SUM(ms_played)` converted
from milliseconds; uncategorized tracks (NULL genre) form their own labeled
bucket.
**Techniques.** `JOIN` plays→tracks · `SUM` with unit conversion · `GROUP BY`
genre · `COALESCE` for the NULL-genre bucket · `ORDER BY`.
**Landmines stepped on (mild).** L4 (SQL `SUM` ignores NULL `ms_played` — correct
by default, but the solver must *not* treat NULL as 0 elsewhere), L3 (NULL genre
must appear as a bucket, not vanish), L12 (divide ms by 60000, not 60).
**Naive it kills.** A solution that computes minutes as `SUM(ms_played)/60`
(treating ms as seconds) or drops NULL-genre rows via an inner condition returns
the wrong totals — but at Blue scale this is a teaching miss, not a TLE.

### PURPLE-1 — "Monthly Active Listeners and Growth"
**Scenario.** Report, per calendar month across the two-year window, the number
of **distinct** active listeners and the month-over-month growth rate. The
firehose contains duplicate events and out-of-order timestamps; the metric is
distinct users by the month of `played_at`, not by ingestion order.
**Techniques.** month truncation on `played_at` · `COUNT(DISTINCT user_id)` ·
window `LAG()` for prior month · growth ratio with divide-by-zero guard ·
ordering by month.
**Landmines.** L10 (duplicate events inflate a naive `COUNT(*)` — must use
`COUNT(DISTINCT user_id)`), L14 (must bucket by `played_at`, never `play_id`),
L8 (December→January and the leap-February boundaries must land in the right
month), L15 (first month has no prior → LAG NULL, growth undefined not zero).
**Naive it kills.** `COUNT(*)` per month (double-counts retries and heavy
listeners) and any month-over-month join that assumes contiguous months with no
LAG guard.
**Prerequisite for:** BLACK-2.

### PURPLE-2 — "Each Listener's Signature Genre"
**Scenario.** For every listener, find the single genre they played most (their
"signature"), with a deterministic tie-break (most plays, then alphabetical
genre). Listeners whose top genre is uncategorized are excluded.
**Techniques.** `GROUP BY user, genre` · per-user window ranking
(`ROW_NUMBER`/`RANK`/`DENSE_RANK`) · tie-break in the `ORDER BY` of the window ·
NULL-genre exclusion · filtering to rank = 1.
**Landmines.** L5 (choosing `RANK`/`DENSE_RANK` returns *multiple* signatures on
a tie; only `ROW_NUMBER` with a full deterministic order key yields one row per
user), L3 (NULL genre must be excluded before ranking, not ranked as a genre),
L10 (duplicates inflate per-genre counts and can flip the winner — statement
defines whether duplicates count).
**Naive it kills.** A `RANK() = 1` filter (returns two rows for tied users →
wrong cardinality) and a correlated `MAX` subquery that breaks on ties.
**Prerequisite for:** BLACK-1.

### PURPLE-3 — "Track Skip-Rate Leaderboard"
**Scenario.** A "skip" is a play with `ms_played < 30000` (under 30 seconds).
For every track with at least 50 qualifying plays, compute
`skip_rate = skips / plays` and return the worst offenders. Plays with NULL
`ms_played` are excluded from both numerator and denominator.
**Techniques.** conditional aggregation (`CASE WHEN ms_played < 30000`) · ratio
with float cast · `HAVING count >= 50` · `JOIN` for titles · `ORDER BY` rate.
**Landmines.** L7 (a LEFT JOIN from all tracks yields never-played tracks with 0
plays → divide-by-zero; the `HAVING` threshold must gate the ratio), L4 (NULL
`ms_played` counted as "not a skip" wrongly inflates the denominator), L12 (the
30-second threshold is in ms: comparing `ms_played < duration_sec` or `< 30`
mixes units), L5 (ties in skip rate at the cutoff).
**Naive it kills.** `skips / plays` computed over a LEFT JOIN without the count
guard (RE/NaN on zero-play tracks), and a threshold written as
`ms_played < duration_sec` (unit-mixing) or `ms_played < 30` (ms vs s).
**Prerequisite for:** BLACK-1, BLACK-2.

### BLACK-1 — "Royalty Attribution and Payout Reconciliation"
**Scenario.** Recompute what each artist *should* have earned per month from the
play firehose, then reconcile against `artist_payouts` to surface every
discrepancy: artists overpaid or underpaid beyond a tolerance, months still
pending, and artists who accrued royalties but were **never paid at all**. A
stream's royalty is the `per_play_usd` for the listener's **active plan at the
moment of the play**, in the listener's **market** (country-specific rate, else
global), under the **rate epoch** covering `played_at`; free/trial plans earn
nothing. Attribute each stream to the track's artist and total by
`(artist, month)`.
**Techniques.** temporal ("as-of") join of `plays` to `subscriptions` on the
active-plan predicate · plan-precedence resolution when periods overlap ·
temporal join to `royalty_rates` with `[from, to)` half-open ranges and
country→global fallback (`COALESCE`) · `SUM` to `(artist, month)` grain ·
anti-join / full reconciliation against `artist_payouts` · `NOT EXISTS` for the
"never paid" set.
**Landmines.** L6 (overlapping paid subscriptions — a naive
`plays JOIN subscriptions ON user_id AND played_at BETWEEN started_at AND ended_at`
matches **two** rows and double-counts royalties; the precedence rule must pick
one), L2 (`artist_id NOT IN (SELECT artist_id FROM artist_payouts)` returns
**empty** because of the NULL adjustment rows — must be `NOT EXISTS`), L9
(the 2024-01-01 rate revision and half-open ranges — a `BETWEEN` on `[from, to]`
double-counts the boundary day), L8 (leap-day and month-end streams must fall in
the correct accounting month), L15 (free/trial 0.000000 rate; and users with no
active sub earn nothing — must not be dropped from counts of *plays* while
earning nothing), L1 (open-ended active subs with NULL `ended_at`), L14 (bucket
by `played_at`), L11 (the reconciliation itself: pending/reversed/missing rows).
**TLE pressure (§6).** At 3M+ plays the temporal join must be expressed so the
engine can hash/merge on `user_id` with a range filter; the naive
per-play correlated subquery to find the active plan (and again for the rate) is
O(plays × subs) and blows the limit.
**Naive it kills.** (a) the `BETWEEN`-on-`user_id` join that fans out on
overlapping subs (WA — overstated royalties); (b) `NOT IN` for "never paid" (WA —
empty result from the NULL); (c) a correlated-subquery plan resolver (TLE).
**Prerequisite:** PURPLE-2, PURPLE-3.

### BLACK-2 — "Listening-Session Reconstruction"
**Scenario.** Reconstruct each listener's **sessions** from the raw firehose. A
new session starts when the gap since that listener's previous play exceeds 30
minutes. Report, per listener, their number of sessions and the length (in
plays) of their **longest** session, plus flag sessions that cross a calendar-day
boundary. Events arrive out of order and include duplicates and exact-timestamp
ties.
**Techniques.** per-user ordering by `played_at` (never `play_id`) · window
`LAG(played_at)` · timestamp difference in minutes · gaps-and-islands: mark
session starts, cumulative `SUM` to assign session ids · aggregate per session,
then per user · a second window pass or `MAX` for the longest · day-boundary
comparison on session start vs end.
**Landmines.** L14 (ordering by `play_id` scrambles sessions — must order by
`played_at`), L10 (duplicate events at the same timestamp create zero-minute
gaps and inflate session length — the statement defines whether to dedupe on
natural key), L5 (exact-timestamp ties need a stable secondary sort key or the
session-start flag is nondeterministic), the classic **gaps-and-islands
off-by-one** (a gap of exactly 30 minutes: is it a new session? statement fixes
`> 30` strictly), L8 (a session spanning midnight, month-end, or 2024-02-29 must
be counted once and correctly flagged).
**TLE pressure (§6).** The reference is a two-window-pass linear scan; the
designated naive-slow is a self-join
`plays p1 JOIN plays p2 ON p1.user_id = p2.user_id AND p2.played_at < p1.played_at`
to find each row's predecessor, which is O(n²) per user and dies on the 3M-row
hidden fixture.
**Naive it kills.** (a) the self-join predecessor lookup (TLE); (b) ordering by
`play_id` (WA — wrong session boundaries); (c) a `>= 30` gap test (WA —
off-by-one on the boundary case).
**Prerequisite:** PURPLE-1, PURPLE-3.

---

## 5. Semantics the reference solutions must reproduce

So Phase B can reproduce the generator's ground truth exactly:

1. **Active plan at a play** = among subscriptions of that user with
   `started_at <= played_at::date <= COALESCE(ended_at, DATE '9999-12-31')`, the
   one with the greatest `PLAN_PRECEDENCE` (premium 5 … free 1), tie broken by
   the latest `started_at`. If none is active, treat as free (earns nothing).
2. **Rate for a play** = the `royalty_rates` row for `(plan, user.country)` whose
   `[effective_from, effective_to)` covers `played_at::date`; if no
   country-specific row exists, the `(plan, NULL)` global row; else 0.
3. **Royalty of a play** = that rate (free/trial = 0). Attributed to
   `tracks.artist_id`, summed by `(artist_id, first-of-month(played_at))`.
4. **Duplicate events count** toward both play counts and royalties (finance saw
   the retries) unless a problem statement says to dedupe on the natural key
   `(user_id, track_id, played_at)`.
5. **`artist_payouts`** is the perturbed image of (3): most `(artist, month)`
   totals appear as `paid` at the exact rounded amount; ~8% are over/underpaid,
   ~8% `pending`, ~3% `reversed`, ~6% missing, plus withheld artists (no rows),
   a few "paid but not owed" rows, and NULL-artist adjustments.

---

## 6. Self-verification results

Run with `--seed 42`:

- **Sample generates, exit 0**, all eight table CSVs present with headers
  matching `schema.sql` column order.
- **Determinism**: two runs at `--scale sample` are byte-identical (md5 match on
  all eight files); a different seed produces different output.
- **Referential integrity** (sample loaded into in-memory SQLite via a naive
  DDL translation): 0 orphans on `plays→users`, `plays→tracks`,
  `tracks→artists`, `albums→artists`, `subscriptions→users`,
  non-NULL `tracks→albums`, non-NULL `artist_payouts→artists`. The only
  unresolved FKs are the two documented intentional NULLs.
- **Landmine spot-checks**: every family L1–L15 present at sample scale and
  scales up (black `--scale`: 75 artists absent from payouts, 2226 never-played
  tracks, 2926 users with overlapping subs, 5205 leap-day plays, 17 927
  duplicate-event groups, 6 NULL-artist payout rows).
- **Scale & memory**: sample <1k rows; blue 47,001 rows (<50k); purple 494,286
  rows (<500k); black 3.43M rows (1M–5M) in 13 s; red 6.04M `plays`
  (5M–10M) in 28 s at **154 MB peak RSS** — streaming keeps it memory-safe.

`generator_smoke = pass`.
