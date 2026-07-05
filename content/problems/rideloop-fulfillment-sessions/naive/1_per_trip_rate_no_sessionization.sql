-- NAIVE (WA): no sessionization at all -- treats every trip row as an independent
-- unit. num_sessions becomes the raw request count and fulfillment_rate becomes
-- the per-trip completion rate, both with the WRONG denominator: a single intent
-- that took three re-requests to succeed counts as 3 units, 1 success here, but as
-- 1 fulfilled session in the reference. On the visible sample Northgate reports
-- 119 / 0.6639 instead of 108 / 0.75. The median is taken over completed trips
-- rather than over fulfilled sessions, so it diverges too.
WITH per_trip AS (
    SELECT g.city, t.status,
        (julianday(t.dropoff_ts) - julianday(t.request_ts)) * 1440.0 AS latency_min
    FROM trips t
    JOIN geozones g ON g.zone_id = t.pickup_zone_id
),
ranked AS (
    SELECT city, latency_min,
        ROW_NUMBER() OVER (PARTITION BY city ORDER BY latency_min) AS rn,
        COUNT(*) OVER (PARTITION BY city) AS c
    FROM per_trip WHERE status = 'completed'
),
median AS (
    SELECT city, AVG(latency_min) AS median_min
    FROM ranked WHERE rn IN ((c + 1) / 2, (c + 2) / 2)
    GROUP BY city
)
SELECT p.city,
    COUNT(*) AS num_sessions,
    ROUND(1.0 * SUM(CASE WHEN p.status = 'completed' THEN 1 ELSE 0 END) / COUNT(*), 4)
        AS fulfillment_rate,
    ROUND(m.median_min, 2) AS median_minutes_to_completion
FROM per_trip p
LEFT JOIN median m ON m.city = p.city
GROUP BY p.city, m.median_min
ORDER BY p.city;
