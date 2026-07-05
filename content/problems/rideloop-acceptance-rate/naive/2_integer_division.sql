-- NAIVE (WA): integer division. Both COUNT-based operands are integers, so
-- completed / total truncates toward zero on every engine (SQLite, Postgres,
-- DuckDB, MySQL, SQL Server): every acceptance_rate comes out 0. The fix is real
-- division (1.0 * ... or CAST(... AS DECIMAL)) as in the reference.
SELECT
    g.zone_id,
    g.zone_name,
    COUNT(*) AS total_requests,
    SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) AS completed_trips,
    SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) / COUNT(*) AS acceptance_rate
FROM trips t
JOIN geozones g ON g.zone_id = t.pickup_zone_id
GROUP BY g.zone_id, g.zone_name
HAVING COUNT(*) >= 20
ORDER BY acceptance_rate ASC, g.zone_id ASC;
