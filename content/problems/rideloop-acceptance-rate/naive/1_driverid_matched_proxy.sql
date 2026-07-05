-- NAIVE (WA): uses "a driver was assigned" as a proxy for "completed".
-- COUNT(driver_id) counts every row with a non-NULL driver_id, but driver_id is
-- NULL for no_driver rows and for the ~40% of cancelled_rider rows where the
-- rider bailed before a match -- while a MATCHED driver who then cancelled
-- (cancelled_driver) still has a driver_id and is counted. So this measures the
-- match rate, not the completion rate, and both the values and the worst-to-best
-- ordering diverge from the reference.
SELECT
    g.zone_id,
    g.zone_name,
    COUNT(*) AS total_requests,
    COUNT(t.driver_id) AS completed_trips,
    ROUND(1.0 * COUNT(t.driver_id) / COUNT(*), 4) AS acceptance_rate
FROM trips t
JOIN geozones g ON g.zone_id = t.pickup_zone_id
GROUP BY g.zone_id, g.zone_name
HAVING COUNT(*) >= 20
ORDER BY acceptance_rate ASC, g.zone_id ASC;
