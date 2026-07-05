-- NAIVE (WA): the grain-safe body is correct, but the reachability filter is
-- written as an UNGUARDED NOT IN over dropoff_zone_id. That column is NULL on
-- every non-completed row, so the subquery returns a set that contains NULL, and
-- `x NOT IN (list with NULL)` is never true -- the predicate is NULL for every
-- row and the whole result collapses to zero rows. The reference keeps the intent
-- as `IN (... WHERE dropoff_zone_id IS NOT NULL)` and returns the full result set.
WITH promo_dedup AS (
    SELECT trip_id, promo_id, MIN(discount_amount) AS discount_amount
    FROM trip_promotions
    GROUP BY trip_id, promo_id
),
disc AS (
    SELECT trip_id, SUM(discount_amount) AS trip_discount
    FROM promo_dedup
    GROUP BY trip_id
),
used AS (
    SELECT DISTINCT trip_id FROM trip_promotions
)
SELECT
    t.pickup_zone_id AS zone_id,
    g.zone_name,
    v.vehicle_class,
    COUNT(*) AS completed_trips,
    ROUND(SUM(t.fare_amount - COALESCE(d.trip_discount, 0)), 2) AS net_revenue,
    ROUND(1.0 * SUM(CASE WHEN u.trip_id IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 4)
        AS promo_penetration
FROM trips t
JOIN geozones g ON g.zone_id = t.pickup_zone_id
JOIN vehicles v ON v.vehicle_id = t.vehicle_id
LEFT JOIN disc d ON d.trip_id = t.trip_id
LEFT JOIN used u ON u.trip_id = t.trip_id
WHERE t.status = 'completed'
  AND t.pickup_zone_id NOT IN (SELECT dropoff_zone_id FROM trips)
GROUP BY t.pickup_zone_id, g.zone_name, v.vehicle_class
ORDER BY zone_id, vehicle_class;
