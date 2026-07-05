-- NAIVE (WA): sessionizes PARTITION BY rider_id, calendar-day instead of by rider
-- alone. Any intent session that straddles midnight is chopped into two sessions,
-- so num_sessions is inflated and the fulfillment_rate denominator is wrong for
-- every city that has a midnight-crossing session. The effect is small but exact:
-- on the purple fixture every city's num_sessions differs from the reference
-- (e.g. Fair Harbor 37398 vs 37393), which makes each such row a WA. The spec
-- requires sessions to NOT be split by day.
WITH ordered AS (
    SELECT t.rider_id, t.trip_id, t.request_ts, t.dropoff_ts, t.pickup_zone_id, t.status,
        SUBSTR(t.request_ts, 1, 10) AS req_day,
        LAG(t.request_ts) OVER (
            PARTITION BY t.rider_id, SUBSTR(t.request_ts, 1, 10)
            ORDER BY t.request_ts, t.trip_id) AS prev_ts
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
            PARTITION BY rider_id, req_day ORDER BY request_ts, trip_id
            ROWS UNBOUNDED PRECEDING) AS session_no
    FROM flagged
),
session_start AS (
    SELECT rider_id, req_day, session_no, pickup_zone_id
    FROM sessioned WHERE is_new_session = 1
),
session_agg AS (
    SELECT rider_id, req_day, session_no,
        MIN(request_ts) AS start_ts,
        MAX(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS fulfilled
    FROM sessioned
    GROUP BY rider_id, req_day, session_no
),
first_completion AS (
    SELECT rider_id, req_day, session_no, dropoff_ts
    FROM (
        SELECT rider_id, req_day, session_no, dropoff_ts,
            ROW_NUMBER() OVER (PARTITION BY rider_id, req_day, session_no
                               ORDER BY request_ts, trip_id) AS rc
        FROM sessioned WHERE status = 'completed'
    ) q WHERE rc = 1
),
sessions AS (
    SELECT a.rider_id, a.req_day, a.session_no, g.city, a.fulfilled,
        (julianday(fc.dropoff_ts) - julianday(a.start_ts)) * 1440.0 AS latency_min
    FROM session_agg a
    JOIN session_start s ON s.rider_id = a.rider_id AND s.req_day = a.req_day
                        AND s.session_no = a.session_no
    JOIN geozones g ON g.zone_id = s.pickup_zone_id
    LEFT JOIN first_completion fc ON fc.rider_id = a.rider_id AND fc.req_day = a.req_day
                                 AND fc.session_no = a.session_no
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
