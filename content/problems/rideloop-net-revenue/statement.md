# Promotion-Adjusted Net Revenue by Zone and Vehicle Class

Finance wants net revenue -- fare collected minus promotional discount -- broken
down by **pickup zone** and **vehicle class**, over completed rides only, plus how
deeply promotions penetrated each group.

The trap is grain. Fares live at **trip** grain, but promotions live **below** it:
`trip_promotions` is many-to-many, so one trip can carry several promo rows, and a
`(trip_id, promo_id)` pair can even appear **twice** (a double application that
discounted the rider only once). Join `trips` straight to `trip_promotions` and
you count each trip's fare once per promo row, and subtract duplicated discounts.
The vehicle join is safe (`vehicle_id` is a primary key), so the only fan-out risk
is the promotions bridge.

## Task

Over `status = 'completed'` trips, grouped by `pickup_zone_id` and the trip's
`vehicle_class` (via `vehicles.vehicle_id`), compute:

- `completed_trips` = number of completed trips in the group,
- `net_revenue` = sum over the group of `fare_amount` minus that trip's **total
  applied discount**, where a trip's discount is summed once per distinct
  `(trip_id, promo_id)` (duplicates collapsed), rounded to 2 dp,
- `promo_penetration` = share of the group's completed trips that used at least one
  promotion, rounded to 4 dp.

Restrict to pickup zones that have served as the **dropoff** zone of at least one
completed trip (guard the subquery with `dropoff_zone_id IS NOT NULL`; an
unguarded `NOT IN` collapses to nothing).

## Output columns

| Column | Meaning |
|--------|---------|
| `zone_id` | pickup zone id |
| `zone_name` | pickup zone name |
| `vehicle_class` | `economy` / `xl` / `lux` |
| `completed_trips` | completed trips in the (zone, class) group |
| `net_revenue` | sum of `fare - trip_discount`, 2 dp |
| `promo_penetration` | share of the group's trips using >= 1 promo, 4 dp |

Order by `zone_id` ascending, then `vehicle_class` ascending. `orderMatters` is
true.

## Worked example (visible sample, seed 42)

First two zones:

| zone_id | zone_name | vehicle_class | completed_trips | net_revenue | promo_penetration |
|---------|-----------|---------------|-----------------|-------------|-------------------|
| 1 | Northgate Old | economy | 7 | 69.73 | 0.2857 |
| 1 | Northgate Old | lux | 8 | 87.29 | 0.25 |
| 1 | Northgate Old | xl | 2 | 32.37 | 0.0 |
| 2 | Rivermouth Industrial | economy | 4 | 28.12 | 0.5 |
| 2 | Rivermouth Industrial | lux | 5 | 100.77 | 0.2 |
| 2 | Rivermouth Industrial | xl | 2 | 37.86 | 0.0 |

Joining through `trip_promotions` without collapsing to trip grain turns
`Northgate Old / lux` into 93.53 (fare double-counted on its multi-promo trips).
Writing the reachability filter as `NOT IN (SELECT dropoff_zone_id FROM trips)`
returns zero rows, because `dropoff_zone_id` is NULL on every non-completed trip.
