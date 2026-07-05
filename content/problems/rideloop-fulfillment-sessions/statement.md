# True Request Fulfillment via Re-Request Sessionization

RideLoop's headline metric is *fulfillment*: when a rider wants to travel, do they
get a ride? The naive read -- completed trips over all trips -- is quietly wrong,
because one **intent to travel** can leave several rows in `trips`. A request that
hits `no_driver` or a driver-cancel usually triggers the same rider to re-request
within a couple of minutes. Counting each of those rows as an independent attempt
inflates the denominator and understates fulfillment.

The fix is to collapse a rider's rapid-fire requests into **intent sessions** and
measure fulfillment at the session level.

## Definitions

- Order each rider's requests by `request_ts`, then `trip_id` (the tiebreak;
  `request_ts` has exact-second ties and some follow-ups are back-dated a few
  seconds, and `trip_id` is not time-ordered so it cannot be the sort key).
- A request starts a **new session** when the gap to the rider's previous request
  is **more than 5 minutes** (300 seconds). A gap of exactly 5:00 stays in the
  same session (the boundary is exclusive). Duplicate rows sit at gap 0.
- Sessions are per **rider only** -- they are **never** split by calendar day, so a
  session may cross midnight or a month end.
- A session is **fulfilled** if **any** trip in it has `status = 'completed'`.
- A session's **city** is the city of the pickup zone of its **first** request.
- A fulfilled session's **latency** is the minutes from the session's first
  `request_ts` to the **dropoff** of its first completed trip (first in
  `(request_ts, trip_id)` order).

## Task

For each city report:

- `num_sessions` = number of intent sessions whose first request is in that city,
- `fulfillment_rate` = fulfilled sessions / num_sessions, rounded to 4 dp,
- `median_minutes_to_completion` = the **exact median** latency over that city's
  fulfilled sessions, rounded to 2 dp (NULL if the city has no fulfilled session).

For an even number of fulfilled sessions the median is the average of the two
central values.

## Output columns

| Column | Meaning |
|--------|---------|
| `city` | city of each session's first request |
| `num_sessions` | intent sessions in the city |
| `fulfillment_rate` | fulfilled sessions / num_sessions, 4 dp |
| `median_minutes_to_completion` | exact median latency over fulfilled sessions, 2 dp |

Order by `city` ascending. `orderMatters` is true.

## Worked example (visible sample, seed 42)

| city | num_sessions | fulfillment_rate | median_minutes_to_completion |
|------|--------------|------------------|------------------------------|
| Northgate | 108 | 0.75 | 23.22 |
| Rivermouth | 89 | 0.764 | 29.39 |

The per-trip rate (no sessionization) reports Northgate as 119 rows / 0.6639 --
wrong denominator. Splitting sessions by calendar day inflates `num_sessions` on
days with a midnight-crossing session. Ordering the scan by `trip_id` instead of
`request_ts` mangles the sessions completely (Northgate collapses to 70 / 0.8143).
Reporting the mean instead of the median gives Northgate 25.11.
