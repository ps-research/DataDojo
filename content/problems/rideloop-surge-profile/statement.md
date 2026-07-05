# Hourly Demand and Surge Profile by City

Surge pricing rises when demand outstrips supply. Pricing wants the daily shape of
demand and surge for each city: for every **city x hour-of-day**, how many ride
requests came in, what the average **applied** surge multiplier was, and what
fraction of requests happened while surge was active.

Two data facts drive the correct query:

- **Demand is every request.** A request that ends in `no_driver` or a
  cancellation still expresses intent to travel. `total_requests` counts all trip
  rows, not just completed rides.
- **`surge_multiplier` is sometimes NULL.** Some non-completed rows carry no
  recorded surge (NULL). A NULL surge is unknown, not `1.0` and not `0`. The
  average surge should be taken over requests whose surge is *known*; folding the
  NULLs into the denominator understates it.

## Task

Join `trips` to `geozones` for the city. Bucket by city and by hour of day
(0-23), extracted from `request_ts`. For each bucket report:

- `total_requests` = count of all request rows,
- `avg_surge` = average of `surge_multiplier` over rows where it is not NULL,
  rounded to 4 dp,
- `surged_share` = fraction of all requests whose `surge_multiplier > 1.0`,
  rounded to 4 dp.

## Output columns

| Column | Meaning |
|--------|---------|
| `city` | city name (from `geozones`) |
| `hour_of_day` | hour extracted from `request_ts`, integer 0-23 |
| `total_requests` | count of all request rows in the bucket |
| `avg_surge` | mean `surge_multiplier` over non-NULL rows, 4 dp |
| `surged_share` | share of requests with `surge_multiplier > 1.0`, 4 dp |

Order by `city` ascending, then `hour_of_day` ascending. `orderMatters` is true.

## Worked example (visible sample, seed 42)

Northgate's morning and evening rush hours show the surge climbing:

| city | hour_of_day | total_requests | avg_surge | surged_share |
|------|-------------|----------------|-----------|--------------|
| Northgate | 6 | 2 | 1.22 | 0.5 |
| Northgate | 7 | 13 | 1.3308 | 0.6154 |
| Northgate | 8 | 12 | 1.1575 | 0.4167 |
| Northgate | 9 | 6 | 1.4433 | 0.6667 |
| Northgate | 17 | 18 | 1.2833 | 0.8889 |
| Northgate | 18 | 5 | 1.46 | 0.8 |
| Northgate | 19 | 9 | 1.2867 | 0.5556 |

The visible sample has no NULL surges, so `avg_surge` here equals the naive
`SUM/COUNT`; on the hidden fixture the two diverge because non-completed rows with
NULL surge inflate the naive denominator. Filtering to completed rides would drop
`total_requests` for hour 17 from 18 down to its completed subset.
