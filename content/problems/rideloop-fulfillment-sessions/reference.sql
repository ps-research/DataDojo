-- R1 - True request fulfillment via re-request sessionization.  (SQLite
-- reference; per-engine variants in reference.postgres/mysql/duckdb.sql.)
--
-- A rider's consecutive requests (ordered by request_ts, then trip_id to break
-- exact-second ties and back-dated follow-ups) form ONE intent session while each
-- gap to the prior request is <= 5 minutes (300 s). A gap > 300 s starts a new
-- session. Sessions are per rider only -- NEVER split by calendar day, so they may
-- cross midnight and month ends. A session is FULFILLED if any trip in it is
-- completed. Per city (city of the session's FIRST request's pickup zone):
--   num_sessions, session-level fulfillment_rate, and the MEDIAN minutes from the
--   session's first request to the dropoff of its first completed trip (median
--   over fulfilled sessions only; NULL if a city has none).
--
-- Ordering by request_ts (not trip_id, which is time-random) is essential; the
-- gap uses seconds, with the 300 s boundary EXCLUSIVE (exactly 5:00 stays in the
-- same session). Duplicate trip rows sit at gap 0 and never start a session.
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
