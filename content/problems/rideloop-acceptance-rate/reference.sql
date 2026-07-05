-- P1 - Driver acceptance rate by pickup zone.
-- acceptance_rate = completed trips / total requests, per pickup zone, for zones
-- with at least 20 requests. Two traps:
--   (1) "completed" is a status, not "a driver was assigned". driver_id is NULL
--       for no_driver AND for some cancelled_rider rows, so COUNT(driver_id) or a
--       "driver matched" proxy measures the wrong thing. Count status='completed'.
--   (2) integer / integer truncates to 0 on every engine; force real division with
--       1.0 * numerator (or CAST) before dividing.
-- The >= 20 HAVING gate drops thin zones whose rate is noise, and guarantees the
-- COUNT(*) denominator is well above zero.
SELECT
    g.zone_id,
    g.zone_name,
    COUNT(*) AS total_requests,
    SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) AS completed_trips,
    ROUND(1.0 * SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) / COUNT(*), 4)
        AS acceptance_rate
FROM trips t
JOIN geozones g ON g.zone_id = t.pickup_zone_id
GROUP BY g.zone_id, g.zone_name
HAVING COUNT(*) >= 20
ORDER BY acceptance_rate ASC, g.zone_id ASC;
