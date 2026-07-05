-- Bk1 - Promotion-adjusted net revenue by pickup zone and vehicle class.
-- net_revenue = fare - total applied discount, over COMPLETED trips only.
--
-- Grain safety is the whole problem. trip_promotions is M:N: a trip can carry
-- several promos, and a (trip_id, promo_id) pair can be logged twice (a double
-- application that discounted the rider only once). Joining trips -> trip_promotions
-- directly fans out fare_amount (counted once per promo row) and, with duplicates,
-- over-subtracts the discount. So we collapse promotions to trip grain FIRST:
--   promo_dedup : one row per (trip_id, promo_id)  -> kills duplicate over-discount
--   disc        : one discount total per trip       -> kills fare fan-out
--   used        : the set of trips that used any promo (for penetration)
-- Every join into trips is then 1:1 (disc, used, vehicles on the vehicle_id PK),
-- so COUNT(*) is the true completed-trip count.
--
-- Reachability: keep only pickup zones that have served as the dropoff of at
-- least one completed trip. The IN-list is guarded with IS NOT NULL, because
-- dropoff_zone_id is NULL on every non-completed row; an unguarded NOT IN over
-- that column collapses to empty (see naive 3).
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
  AND t.pickup_zone_id IN (
      SELECT dropoff_zone_id FROM trips WHERE dropoff_zone_id IS NOT NULL
  )
GROUP BY t.pickup_zone_id, g.zone_name, v.vehicle_class
ORDER BY zone_id, vehicle_class;
