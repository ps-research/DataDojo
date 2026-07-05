-- NAIVE (WA): joins trips straight to trip_promotions and sums
-- (fare - discount) over the joined rows. This fans out fare_amount: a trip with
-- two promo rows contributes its fare TWICE (minus each discount), so
-- net_revenue for any group containing multi-promo trips is inflated by roughly
-- one extra fare per extra promo row. On the hidden fixture duplicate
-- (trip_id, promo_id) rows also double-subtract the discount. The LEFT JOIN keeps
-- promo-free trips (so it is not simply an under-count), which makes the error
-- look plausible while every multi-promo group diverges from the reference.
SELECT
    t.pickup_zone_id AS zone_id,
    g.zone_name,
    v.vehicle_class,
    COUNT(DISTINCT t.trip_id) AS completed_trips,
    ROUND(SUM(t.fare_amount - COALESCE(tp.discount_amount, 0)), 2) AS net_revenue,
    ROUND(1.0 * COUNT(DISTINCT CASE WHEN tp.trip_id IS NOT NULL THEN t.trip_id END)
              / COUNT(DISTINCT t.trip_id), 4) AS promo_penetration
FROM trips t
JOIN geozones g ON g.zone_id = t.pickup_zone_id
JOIN vehicles v ON v.vehicle_id = t.vehicle_id
LEFT JOIN trip_promotions tp ON tp.trip_id = t.trip_id
WHERE t.status = 'completed'
  AND t.pickup_zone_id IN (
      SELECT dropoff_zone_id FROM trips WHERE dropoff_zone_id IS NOT NULL
  )
GROUP BY t.pickup_zone_id, g.zone_name, v.vehicle_class
ORDER BY zone_id, vehicle_class;
