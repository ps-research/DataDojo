-- NAIVE (WA): sessionizes correctly but reports the MEAN time-to-completion
-- instead of the MEDIAN. The latency distribution is right-skewed (a heavy tail of
-- re-request sessions that took many minutes), so the mean sits above the median.
-- On the visible sample Northgate's mean is 25.11 vs the median 23.22, and
-- Rivermouth 29.25 vs 29.39. The spec asks for the exact median.
WITH ordered AS (
    SELECT t.rider_id, t.trip_id, t.request_ts, t.dropoff_ts, t.pickup_zone_id, t.status,
        LAG(t.request_ts) OVER (PARTITION BY t.rider_id ORDER BY t.request_ts, t.trip_id)
            AS prev_ts
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
)
SELECT s.city,
    COUNT(*) AS num_sessions,
    ROUND(1.0 * SUM(s.fulfilled) / COUNT(*), 4) AS fulfillment_rate,
    ROUND(AVG(CASE WHEN s.fulfilled = 1 THEN s.latency_min END), 2)
        AS median_minutes_to_completion
FROM sessions s
GROUP BY s.city
ORDER BY s.city;
