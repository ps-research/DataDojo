# Signup-Cohort Retention Matrix (W0-W8)

Build the classic signup-cohort retention triangle. Every user belongs to the
**cohort** defined by the week they signed up (`users.signup_ts`); for each cohort
you measure how many of its users are still **active** in each of the following
weeks, out to eight weeks after signup.

As in the weekly-active problem, a week is a **Monday-anchored 7-day bucket** and
the window starts on Monday 2024-01-01, so weeks form a **monotonic index that does
not reset** at the 2024/2025 boundary. The **week offset** of an activity week is
its week index minus the cohort's signup-week index:

```
week_offset = active_week_index - signup_week_index
```

Because the index is monotonic, this offset is correct across the leap day and the
year boundary — a raw `(week_of_year - week_of_year)` subtraction is not (it goes
negative or 53-off around New Year and conflates the same week number in 2024 and
2025).

A user is **active** in a week if they fired at least one event in it. Count each
user's activity weeks as **distinct** weeks, so duplicate / double-fired events
never inflate activity, and a user active in W0 and W3 but not W1/W2 contributes to
**W0 and W3 only** (no smoothing over the gap). **Internal** users
(`is_internal = 1`) are excluded from the whole analysis.

## Task

For every cohort (signup week) and every week offset **W0 through W8**, report:

1. `cohort_week` — the cohort's signup-week Monday (`YYYY-MM-DD`);
2. `week_offset` — integer 0..8;
3. `cohort_size` — the number of non-internal users in the cohort (the W0 base);
4. `active_users` — non-internal cohort users active in that offset week
   (`COUNT(DISTINCT user_id)`), **0 if none**;
5. `retention_rate` — `active_users / cohort_size`, `NULLIF`-guarded, 6 dp.

**Emit all nine offsets for every cohort**, filling empty cells with `active_users
= 0` (and `retention_rate = 0`). Do not let an empty offset vanish.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `cohort_week` | signup-week Monday (`YYYY-MM-DD`) |
| 2 | `week_offset` | 0..8 |
| 3 | `cohort_size` | non-internal users in the cohort |
| 4 | `active_users` | non-internal cohort users active in offset week |
| 5 | `retention_rate` | `active_users / cohort_size`, NULLIF-guarded, 6 dp |

**Order matters.** `ORDER BY cohort_week, week_offset`.

## Worked example

The first cohort on the visible sample fixture (the user who signed up in the week
of 2024-01-01):

| cohort_week | week_offset | cohort_size | active_users | retention_rate |
|---|---|---|---|---|
| 2024-01-01 | 0 | 1 | 1 | 1.0 |
| 2024-01-01 | 1 | 1 | 0 | 0.0 |
| 2024-01-01 | 2 | 1 | 0 | 0.0 |
| 2024-01-01 | 3 | 1 | 0 | 0.0 |
| 2024-01-01 | 4 | 1 | 1 | 1.0 |
| 2024-01-01 | 5 | 1 | 1 | 1.0 |
| 2024-01-01 | 6 | 1 | 1 | 1.0 |
| 2024-01-01 | 7 | 1 | 0 | 0.0 |
| 2024-01-01 | 8 | 1 | 0 | 0.0 |

This cohort's single user is active at W0, silent at W1-W3, active again at W4-W6,
then silent — an **island of activity with a gap**, which the distinct-week
counting preserves exactly (W1-W3 read 0, they do not "carry forward" the W0
activity). Every offset 0..8 is present even where `active_users = 0`. These are the
first nine rows the reference produces on the visible sample fixture.
