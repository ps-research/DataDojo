# Driver Acceptance Rate by Pickup Zone

A pickup zone's **acceptance rate** is the share of ride requests that end in a
completed ride. Low-acceptance zones are where supply is failing demand: riders
request, but too often the request dies as `no_driver` or a cancellation. Ops
wants the worst zones first so they can rebalance driver incentives.

Every request is one `trips` row. `status` is one of `completed`,
`cancelled_rider`, `cancelled_driver`, `no_driver`. A completed ride is the only
success. Beware `driver_id`: it is NULL for `no_driver` and for riders who cancel
before a match, but it is **present** for a matched driver who then cancels — so
"a driver was assigned" is not the same as "the ride completed".

## Task

For each pickup zone (`trips.pickup_zone_id` joined to `geozones`) that received
**at least 20 requests**, compute:

- `total_requests` = number of trip rows with that pickup zone (all statuses),
- `completed_trips` = number of those with `status = 'completed'`,
- `acceptance_rate` = `completed_trips / total_requests`, as a real number rounded
  to 4 decimal places.

Zones with fewer than 20 requests are excluded. List zones **worst acceptance
first**.

## Output columns

| Column | Meaning |
|--------|---------|
| `zone_id` | pickup zone id |
| `zone_name` | pickup zone name |
| `total_requests` | count of all trip rows in the zone |
| `completed_trips` | count of `status='completed'` rows in the zone |
| `acceptance_rate` | `completed_trips / total_requests`, rounded to 4 dp |

Order by `acceptance_rate` **ascending**, then `zone_id` **ascending**.
`orderMatters` is true.

## Worked example (visible sample, seed 42)

Five zones clear the 20-request threshold:

| zone_id | zone_name | total_requests | completed_trips | acceptance_rate |
|---------|-----------|----------------|-----------------|-----------------|
| 5 | Northgate East | 55 | 32 | 0.5818 |
| 3 | Northgate Upper | 22 | 15 | 0.6818 |
| 4 | Rivermouth Market | 27 | 19 | 0.7037 |
| 1 | Northgate Old | 24 | 17 | 0.7083 |
| 6 | Rivermouth Airport | 45 | 34 | 0.7556 |

Using `COUNT(driver_id)` instead of the completed count would rank `Northgate
Upper` best-of-the-worst as 0.7273 and reorder the list, because matched-then-
cancelled rides carry a `driver_id`. Writing the ratio as integer `completed_trips
/ total_requests` returns 0.0 for every zone.
