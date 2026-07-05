-- NAIVE (TLE + WA): replaces the pre-aggregated joins with per-trip correlated
-- subqueries. It re-scans trip_promotions once per completed trip for the
-- discount total and again (EXISTS) for penetration; at black scale (3M completed
-- trips against ~1.5M promo rows with no covering index) that is quadratic work
-- and blows the time limit while the set-based reference stays well under it.
-- It is ALSO wrong: the correlated SUM(discount_amount) does not dedupe a
-- (trip_id, promo_id) pair applied twice, so it over-subtracts that discount --
-- observable on the visible sample (3 rows differ, e.g. Northgate Old / lux comes
-- out 81.05 instead of 87.29), not just on the hidden fixture. TLE at scale, WA
-- anywhere duplicates exist.
SELECT
    t.pickup_zone_id AS zone_id,
    g.zone_name,
    v.vehicle_class,
    COUNT(*) AS completed_trips,
    ROUND(SUM(t.fare_amount - COALESCE(
        (SELECT SUM(tp.discount_amount) FROM trip_promotions tp WHERE tp.trip_id = t.trip_id),
        0)), 2) AS net_revenue,
    ROUND(1.0 * SUM(CASE WHEN EXISTS (
        SELECT 1 FROM trip_promotions tp WHERE tp.trip_id = t.trip_id
    ) THEN 1 ELSE 0 END) / COUNT(*), 4) AS promo_penetration
FROM trips t
JOIN geozones g ON g.zone_id = t.pickup_zone_id
JOIN vehicles v ON v.vehicle_id = t.vehicle_id
WHERE t.status = 'completed'
  AND t.pickup_zone_id IN (
      SELECT dropoff_zone_id FROM trips WHERE dropoff_zone_id IS NOT NULL
  )
GROUP BY t.pickup_zone_id, g.zone_name, v.vehicle_class
ORDER BY zone_id, vehicle_class;
