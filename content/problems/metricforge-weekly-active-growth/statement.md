# Weekly Active Users and Week-over-Week Growth

The finance deck needs the **weekly active user** (WAU) time series across the whole
simulation window (2024-01-01 through 2025-03-31), plus the week-over-week percent
change. A week is *active* for a user if that user fired **at least one event** in
it; **internal** staff / QA / test users (`users.is_internal = 1`) must be excluded
from the metric.

The hard part is the calendar. The window straddles the **leap day (2024-02-29)**
and the **2024/2025 year boundary**, where naive "year + week-of-year" bucketing
resets the week counter and mis-numbers the boundary weeks (the classic week-53 /
week-1 trap). Define a week as a **Monday-anchored 7-day bucket**: the window
begins on Monday 2024-01-01, so weeks are `2024-01-01..2024-01-07`,
`2024-01-08..2024-01-14`, and so on, each **labelled by its Monday**
(`week_start`). This index increases monotonically and **never resets** at the year
boundary, so the boundary weeks are counted exactly once. (A literal calendar of
these week ranges is the portable way to bucket without a per-engine ISO-week
function.)

Report **every** week in the window, even one with zero active users.

## Task

For each Monday-anchored week from 2024-01-01 to 2025-03-31, report:

1. `week_start` — the week's Monday (a `YYYY-MM-DD` date);
2. `wau` — `COUNT(DISTINCT user_id)` of non-internal users active that week (0 if none);
3. `wow_growth` — `(wau - prev_wau) / prev_wau` versus the **immediately preceding
   calendar week**, guarded with `NULLIF(prev_wau, 0)` and rounded to 6 decimals.

The **first week has no predecessor**, so its growth is **NULL** (undefined, not
`0`). A week whose predecessor had zero active users also yields NULL (the guard
turning `x / 0` into NULL rather than an error).

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `week_start` | Monday of the week (`YYYY-MM-DD`) |
| 2 | `wau` | distinct non-internal active users that week |
| 3 | `wow_growth` | fractional change vs the previous week, or NULL, 6 dp |

**Order matters.** `ORDER BY week_start` ascending.

## Worked example

An excerpt of the reference output on the visible sample fixture, around the
2024/2025 boundary (the sample is tiny, so weekly counts are small):

| week_start | wau | wow_growth |
|---|---|---|
| 2024-12-16 | 2 | -0.333333 |
| 2024-12-23 | 0 | -1.0 |
| 2024-12-30 | 1 | *(NULL)* |
| 2025-01-06 | 2 | 1.0 |
| 2025-01-13 | 0 | -1.0 |
| 2025-01-20 | 1 | *(NULL)* |
| 2025-01-27 | 2 | 1.0 |
| 2025-02-03 | 5 | 1.5 |
| 2025-02-10 | 2 | -0.6 |

The week beginning `2024-12-30` is the boundary week (it runs into January 2025);
the monotonic index keeps it adjacent to the prior week rather than resetting. Its
growth is NULL because the preceding week (`2024-12-23`) had zero active users, so
the `NULLIF` guard returns NULL instead of dividing by zero. `2025-01-06`:
`(2 - 1) / 1 = 1.0`. These rows appear exactly as shown in the reference output on
the visible sample fixture.
