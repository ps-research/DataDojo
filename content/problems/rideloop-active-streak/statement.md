# Longest Streak of Consecutive Active Days per Driver

Driver-retention wants to reward consistency. An **active day** for a driver is a
calendar day on which they **completed** at least one trip (keyed on the
completion / dropoff date). Find, for each driver, the longest run of
**consecutive** active days, then return the drivers who hold the longest streak
overall -- including **every** driver tied at the maximum.

Three things make the obvious query wrong:

- **Consecutive, not total.** The number of active days a driver has is not the
  length of their longest unbroken run.
- **One day, once.** A driver can complete several trips in a day; those must
  collapse to a single active day before any run math, or the island key drifts.
- **Ties are real.** Many drivers share the same maximum streak. `ROW_NUMBER`
  keeps one and drops the rest; you need `RANK`/`DENSE_RANK`.

Runs must be computed with true date arithmetic so a streak survives month ends
and the leap day 2024-02-29 -- not day-of-month subtraction.

## Task

1. Reduce completed trips to distinct `(driver_id, active_day)` pairs, where
   `active_day` is the dropoff date. Ignore rows with a NULL `driver_id`.
2. Use gaps-and-islands: within a driver, order active days and label each with
   `day_number - ROW_NUMBER()`, constant along a consecutive run.
3. The longest run per driver is that driver's streak.
4. Return the drivers whose streak equals the global maximum (all ties).

## Output columns

| Column | Meaning |
|--------|---------|
| `driver_id` | driver id |
| `longest_streak` | length in days of the driver's longest consecutive-active-day run |

Return every driver tied at the maximum streak. Order by `driver_id` ascending.
`orderMatters` is true.

## Worked example (visible sample, seed 42)

Three drivers are tied at the top with a 3-day consecutive run:

| driver_id | longest_streak |
|-----------|----------------|
| 1 | 3 |
| 7 | 3 |
| 9 | 3 |

`COUNT(DISTINCT active_day)` instead of a run length would return only driver 1
with 14 (total active days). The span `MAX(day) - MIN(day) + 1` would return
driver 1 with 37. Ranking the leaderboard with `ROW_NUMBER()` would return only
driver 1 and hide drivers 7 and 9.
