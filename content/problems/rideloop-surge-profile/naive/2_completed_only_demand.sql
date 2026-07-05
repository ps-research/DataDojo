-- NAIVE (WA): filters to completed rides before counting demand. Demand is the
-- intent to travel -- every request row, including no_driver and cancellations.
-- Restricting to status='completed' undercounts total_requests (and shifts both
-- ratios, since the surged share is now over completed rides only). The
-- total_requests column diverges from the reference in every busy hour.
SELECT
    g.city,
    CAST(SUBSTR(t.request_ts, 12, 2) AS INTEGER) AS hour_of_day,
    COUNT(*) AS total_requests,
    ROUND(AVG(t.surge_multiplier), 4) AS avg_surge,
    ROUND(1.0 * SUM(CASE WHEN t.surge_multiplier > 1.0 THEN 1 ELSE 0 END) / COUNT(*), 4)
        AS surged_share
FROM trips t
JOIN geozones g ON g.zone_id = t.pickup_zone_id
WHERE t.status = 'completed'
GROUP BY g.city, CAST(SUBSTR(t.request_ts, 12, 2) AS INTEGER)
ORDER BY g.city, hour_of_day;
