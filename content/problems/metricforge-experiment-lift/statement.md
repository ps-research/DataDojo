# A/B Experiment Lift with Assignment Contamination

For every **completed** experiment, compute the conversion rate on its
`primary_metric` for the `control` and `treatment` variants, and the absolute
**lift** = `treatment_rate - control_rate`. A completed experiment is one with
`status = 'completed'` **and** a non-NULL `end_date`.

The assignment log (`experiment_assignments`) is **not** one clean row per user.
The same user can be logged into a variant twice, can land in **both** variants of
one experiment after a client rehydrate, and can be enrolled in several experiments
at once. Two things must therefore be handled before any rate is computed:

**De-duplication.** A user assigned to the same variant twice is still one user.

**Contamination.** A user must be **excluded from an experiment's result** if,
for that experiment, they are contaminated:

- **Both-variant:** they hold both `control` and `treatment` within the experiment; or
- **Multi-experiment overlap:** they are also enrolled in **another** experiment
  whose active interval **overlaps** this one. An experiment is active from
  `start_date` to `end_date`; a **running** experiment (NULL `end_date`) is treated
  as active through the end of the window (2025-03-31), so an overlapping running
  experiment still contaminates. (Two intervals overlap when
  `A.start <= B.end AND B.start <= A.end`.)

Among the surviving (clean, de-duplicated) users, a user **converts** if they
performed the experiment's `primary_metric` event **strictly after** their
assignment time (`event_ts > assigned_ts`). Use each clean user's earliest
`assigned_ts`. Count each user once — do **not** let a join to `events` multiply a
user's conversions by their event count.

## Task

For each completed experiment report:

1. `experiment_key`;
2. `control_users`, `control_conversions`, `control_rate` (`conversions / users`, NULLIF-guarded, 6 dp);
3. `treatment_users`, `treatment_conversions`, `treatment_rate` (same);
4. `lift` = `treatment_rate - control_rate` (6 dp).

A completed experiment with **zero clean users in a variant** still appears; that
variant's rate (and the lift) is NULL.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `experiment_key` | the experiment's key |
| 2 | `control_users` | clean, non-contaminated, de-duplicated control users |
| 3 | `control_conversions` | of those, how many converted after assignment |
| 4 | `control_rate` | `control_conversions / control_users`, NULLIF-guarded, 6 dp |
| 5 | `treatment_users` | clean treatment users |
| 6 | `treatment_conversions` | of those, how many converted |
| 7 | `treatment_rate` | `treatment_conversions / treatment_users`, NULLIF-guarded, 6 dp |
| 8 | `lift` | `treatment_rate - control_rate`, 6 dp, NULL if a variant is empty |

**Order does not matter** — the grader sorts rows before comparing (`lift` may be
NULL, so ordering is not your concern).

## Worked example

On the visible sample fixture the completed experiments are `onboarding_flow` and
`pricing_page`:

| experiment_key | control_users | control_conversions | control_rate | treatment_users | treatment_conversions | treatment_rate | lift |
|---|---|---|---|---|---|---|---|
| onboarding_flow | 1 | 0 | 0.0 | 1 | 0 | 0.0 | 0.0 |
| pricing_page | 0 | 0 | *(NULL)* | 0 | 0 | *(NULL)* | *(NULL)* |

`onboarding_flow` had three assignments, but one of those users is also enrolled in
a **running** experiment that overlaps it, so that user is contaminated and dropped
— leaving one clean control user and one clean treatment user (detecting this
requires treating the running experiment's NULL `end_date` as ongoing). Neither
converted on the primary metric after assignment, so both rates and the lift are
`0.0`. `pricing_page` is completed but has **no assignments at all**, so both
variants are empty and every rate and the lift are NULL (never a divide-by-zero
error). These are exactly the rows the reference produces on the visible sample
fixture.
