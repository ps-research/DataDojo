# Retention-Qualified Experiment Uplift Ranking

The company will greenlight the single experiment with the strongest uplift **among
its genuinely engaged users**, and needs a defensible, deterministic ranking. This
composes two earlier results: the cohort/week-offset arithmetic and the experiment
contamination handling.

Work over **completed** experiments only (`status = 'completed'` and non-NULL
`end_date`). For each, first reduce the assignment log to a **clean** set exactly as
in the lift problem:

- drop **contaminated** users — a user who holds both variants of the experiment,
  **or** who is also enrolled in any other experiment whose active interval overlaps
  it (a **running** experiment, NULL `end_date`, counts as active through
  2025-03-31);
- drop **internal** users (`is_internal = 1`);
- **de-duplicate** repeat assignment rows to one row per user, keeping their single
  variant and earliest `assigned_ts`.

Now keep only the **retention-qualified** clean users. Weeks are Monday-anchored
7-day buckets on a monotonic index (starting Monday 2024-01-01, no reset at the
year boundary). Let `assign_week` be the week containing the user's `assigned_ts`.
The user is qualified only if they have **at least one session in each of the first
K = 2 consecutive weeks following** their assignment week — that is, a session in
**both** `assign_week + 1` **and** `assign_week + 2`. This is an **unbroken island**:
a user active in `+1` and `+3` but not `+2` has a gap and does **not** qualify. Count
session weeks as **distinct** weeks so duplicates and late-delivered sessions cannot
fabricate a week.

Among the qualified users of each variant, a user **converts** if they performed the
experiment's `primary_metric` event with `event_ts > assigned_ts`. The variant's
rate is `conversions / qualified_users`; the experiment's **uplift** is
`treatment_rate - control_rate`.

**Exclude** any experiment that has **zero qualified users in either variant** (its
uplift is undefined) — it does not appear in the ranking.

Rank the surviving experiments by:

1. `uplift` **descending**, then
2. `qualified_size` (control + treatment qualified users) **descending**, then
3. `experiment_key` **ascending**.

`rank_pos` is the 1-based position in that total order. Because uplift ties are real,
the full multi-key tie-break is mandatory: ranking on uplift alone gives tied
experiments an arbitrary order.

## Task / output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `rank_pos` | 1-based rank in the ordering above |
| 2 | `experiment_key` | the experiment's key |
| 3 | `control_qualified` | retention-qualified clean control users |
| 4 | `treatment_qualified` | retention-qualified clean treatment users |
| 5 | `qualified_size` | `control_qualified + treatment_qualified` |
| 6 | `control_rate` | `control_conversions / control_qualified`, NULLIF-guarded, 6 dp |
| 7 | `treatment_rate` | `treatment_conversions / treatment_qualified`, NULLIF-guarded, 6 dp |
| 8 | `uplift` | `treatment_rate - control_rate`, 6 dp |

**Order matters.** `ORDER BY rank_pos` (i.e. the ranking above).

## Worked example

The visible sample fixture has only 24 users, and **no** experiment ends up with
qualified users in *both* variants, so the reference returns an **empty** result on
it. The mechanics are best shown on a small illustrative scenario.

One completed experiment `exp_alpha` (`primary_metric = purchase`), with clean,
de-duplicated assignments all made in the same week `W`:

- **control** `u1`: sessions in `W+1` and `W+2` (island intact) -> qualified; buys
  after assignment -> converts.
- **control** `u2`: sessions in `W+1` and `W+2` -> qualified; never buys -> no convert.
- **treatment** `u3`: sessions in `W+1` and `W+2` -> qualified; buys -> converts.
- **treatment** `u4`: sessions in `W+1` and `W+3` — **gap at `W+2`** -> **not
  qualified** (a total-count rule would wrongly admit it).
- one control user also enrolled in an overlapping running experiment -> **contaminated, dropped**.
- one treatment user with `is_internal = 1` -> **dropped**.

Qualified control = `{u1, u2}` (rate `1/2 = 0.5`); qualified treatment = `{u3}`
(rate `1/1 = 1.0`); `uplift = 0.5`. Expected output:

| rank_pos | experiment_key | control_qualified | treatment_qualified | qualified_size | control_rate | treatment_rate | uplift |
|---|---|---|---|---|---|---|---|
| 1 | exp_alpha | 2 | 1 | 3 | 0.5 | 1.0 | 0.5 |

The reference reproduces exactly this row on that micro-scenario. Admitting the
gapped user `u4` (a total-active-week count instead of a consecutive island) would
report `treatment_qualified = 2` and `treatment_rate = 0.5`, collapsing the uplift
to `0.0` — the divergence this problem is built to catch.
