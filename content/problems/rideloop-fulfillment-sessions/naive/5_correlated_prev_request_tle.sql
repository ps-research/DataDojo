-- NAIVE (TLE): correct logic, but finds each request's previous request with a
-- correlated scalar subquery instead of LAG. For every one of the ~7M trip rows
-- it scans that rider's other requests to find the immediately-preceding one --
-- O(N^2)-ish work that blows the time limit, while the windowed reference is a
-- single ordered pass. It produces the SAME answer as the reference on the visible
-- sample (it is only slow, not wrong), so it is a pure TLE landmine.
WITH ordered AS (
    SELECT t.rider_id, t.trip_id, t.request_ts, t.dropoff_ts, t.pickup_zone_id, t.status,
        (SELECT p.request_ts
         FROM trips p
         WHERE p.rider_id = t.rider_id
           AND (p.request_ts < t.request_ts
                OR (p.request_ts = t.request_ts AND p.trip_id < t.trip_id))
         ORDER BY p.request_ts DESC, p.trip_id DESC
         LIMIT 1) AS prev_ts
    FROM trips t
),
flagged AS (
    SELECT ordered.*,
        CASE WHEN prev_ts IS NULL
                  OR (julianday(request_ts) - julianday(prev_ts)) * 86400.0 > 300
             THEN 1 ELSE 0 END AS is_new_session
    FROM ordered
),
sessioned AS (
    SELECT flagged.*,
        SUM(is_new_session) OVER (
            PARTITION BY rider_id ORDER BY request_ts, trip_id
            ROWS UNBOUNDED PRECEDING) AS session_no
    FROM flagged
),
session_start AS (
    SELECT rider_id, session_no, pickup_zone_id
    FROM sessioned WHERE is_new_session = 1
),
session_agg AS (
    SELECT rider_id, session_no,
        MIN(request_ts) AS start_ts,
        MAX(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS fulfilled
    FROM sessioned
    GROUP BY rider_id, session_no
),
first_completion AS (
    SELECT rider_id, session_no, dropoff_ts
    FROM (
        SELECT rider_id, session_no, dropoff_ts,
            ROW_NUMBER() OVER (PARTITION BY rider_id, session_no
                               ORDER BY request_ts, trip_id) AS rc
        FROM sessioned WHERE status = 'completed'
    ) q WHERE rc = 1
),
sessions AS (
    SELECT a.rider_id, a.session_no, g.city, a.fulfilled,
        (julianday(fc.dropoff_ts) - julianday(a.start_ts)) * 1440.0 AS latency_min
    FROM session_agg a
    JOIN session_start s ON s.rider_id = a.rider_id AND s.session_no = a.session_no
    JOIN geozones g ON g.zone_id = s.pickup_zone_id
    LEFT JOIN first_completion fc
        ON fc.rider_id = a.rider_id AND fc.session_no = a.session_no
),
ranked AS (
    SELECT city, latency_min,
        ROW_NUMBER() OVER (PARTITION BY city ORDER BY latency_min) AS rn,
        COUNT(*) OVER (PARTITION BY city) AS c
    FROM sessions WHERE fulfilled = 1
),
median AS (
    SELECT city, AVG(latency_min) AS median_min
    FROM ranked WHERE rn IN ((c + 1) / 2, (c + 2) / 2)
    GROUP BY city
)
SELECT s.city,
    COUNT(*) AS num_sessions,
    ROUND(1.0 * SUM(s.fulfilled) / COUNT(*), 4) AS fulfillment_rate,
    ROUND(m.median_min, 2) AS median_minutes_to_completion
FROM sessions s
LEFT JOIN median m ON m.city = s.city
GROUP BY s.city, m.median_min
ORDER BY s.city;
