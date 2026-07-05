-- B1 - Busiest pickup zones in one city, by completed trips.
-- City lives on the zone dimension, so join trips to geozones and filter on
-- g.city. "Busiest" means COMPLETED rides, not every request: a no_driver or a
-- cancellation is a request that produced no ride, so the WHERE clause must pin
-- status = 'completed'. Ties on the count are broken by zone_name so the top-10
-- cut is deterministic.
SELECT
    g.zone_name,
    COUNT(*) AS completed_trips
FROM trips t
JOIN geozones g ON g.zone_id = t.pickup_zone_id
WHERE g.city = 'Northgate'
  AND t.status = 'completed'
GROUP BY g.zone_name
ORDER BY completed_trips DESC, g.zone_name ASC
LIMIT 10;
