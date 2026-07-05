# Time-to-First-Ride by Signup Cohort

How long does a new rider take to actually ride? Growth wants the answer bucketed
by **signup month cohort**: for every rider, find their *first completed ride*,
measure the whole days from their `signup_date` to that ride, and average that
gap within each signup-month cohort.

Two facts about the data make the "obvious" query wrong:

1. A request is not a ride. Riders often cancel or hit `no_driver` before their
   first success, so the first *completed* trip is not the first *request*.
2. `trip_id` is a surrogate key inserted in time-random order — it is **not**
   ordered by `request_ts`. So "smallest trip_id" is not "earliest request".

A rider who never completed any trip has no first ride and is excluded.

## Task

For each rider, take the **first completed trip** ordered by `(request_ts,
trip_id)` — `status = 'completed'` only, `request_ts` first, `trip_id` as the
deterministic tiebreak. Compute the whole-day gap from the rider's `signup_date`
to that trip's request date. Bucket riders by signup month (`YYYY-MM`) and report,
per cohort, how many riders it contains and the average days-to-first-ride.

## Output columns

| Column | Meaning |
|--------|---------|
| `signup_cohort` | rider's signup month as `'YYYY-MM'` |
| `riders` | number of riders in the cohort who ever completed a ride |
| `avg_days_to_first_ride` | mean whole-day gap (signup -> first completed ride), rounded to 2 dp |

Order by `signup_cohort` ascending. `orderMatters` is true.

## Worked example (visible sample, seed 42)

First few cohorts (17 in total):

| signup_cohort | riders | avg_days_to_first_ride |
|---------------|--------|------------------------|
| 2022-09 | 2 | 513.0 |
| 2022-10 | 5 | 496.0 |
| 2022-11 | 6 | 454.67 |
| 2022-12 | 1 | 409.0 |
| 2023-01 | 1 | 382.0 |

Dropping the `completed` filter and taking each rider's earliest request instead
turns the `2022-11` cohort into 7 riders averaging 458.57 (it counts an
extra rider and dates first rides to earlier failed requests). Picking the first
completed trip by `trip_id` instead of `request_ts` shifts `2022-10` to 503.6.
The reference produces the table above.
