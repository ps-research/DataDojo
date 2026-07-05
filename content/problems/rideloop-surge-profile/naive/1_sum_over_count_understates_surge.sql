-- NAIVE (WA): computes avg_surge as SUM(surge_multiplier) / COUNT(*) instead of
-- AVG(surge_multiplier). Some non-completed rows carry a NULL surge_multiplier
-- (no recorded surge). SUM skips those NULLs in the numerator, but COUNT(*)
-- counts them in the denominator, so the "average" is the known-surge total
-- spread over ALL requests -- systematically understated wherever null surge
-- exists (purple and larger fixtures). On the fully-populated visible sample
-- there are no NULL surges, so it matches there; it diverges on the hidden
-- fixture. avg_surge is the reported column, so any city/hour with null surge
-- makes the row wrong.
SELECT
    g.city,
    CAST(SUBSTR(t.request_ts, 12, 2) AS INTEGER) AS hour_of_day,
    COUNT(*) AS total_requests,
    ROUND(1.0 * SUM(t.surge_multiplier) / COUNT(*), 4) AS avg_surge,
    ROUND(1.0 * SUM(CASE WHEN t.surge_multiplier > 1.0 THEN 1 ELSE 0 END) / COUNT(*), 4)
        AS surged_share
FROM trips t
JOIN geozones g ON g.zone_id = t.pickup_zone_id
GROUP BY g.city, CAST(SUBSTR(t.request_ts, 12, 2) AS INTEGER)
ORDER BY g.city, hour_of_day;
