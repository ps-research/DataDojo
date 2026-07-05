-- P3 - Hourly demand and surge profile by city.
-- For each city x hour-of-day: how many requests, the average APPLIED surge, and
-- the share of requests that happened under surge (> 1.0).
--   * hour is sliced from the ISO timestamp (chars 12-13 = HH) and cast to int --
--     portable and independent of any engine's EXTRACT/DATEPART spelling.
--   * total_requests counts every request row (all statuses) -- demand is intent,
--     not just completed rides.
--   * avg_surge uses AVG(surge_multiplier), which ignores rows where surge is
--     NULL (some non-completed rows carry no recorded surge). That is deliberate:
--     the average is over requests whose surge is known. SUM(surge)/COUNT(*) would
--     divide the known-surge total by ALL rows and understate it.
--   * surged_share = requests with a recorded surge > 1.0 over all requests; a
--     NULL surge is not "> 1.0", so it counts in the denominator but not the top.
SELECT
    g.city,
    CAST(SUBSTR(t.request_ts, 12, 2) AS INTEGER) AS hour_of_day,
    COUNT(*) AS total_requests,
    ROUND(AVG(t.surge_multiplier), 4) AS avg_surge,
    ROUND(1.0 * SUM(CASE WHEN t.surge_multiplier > 1.0 THEN 1 ELSE 0 END) / COUNT(*), 4)
        AS surged_share
FROM trips t
JOIN geozones g ON g.zone_id = t.pickup_zone_id
GROUP BY g.city, CAST(SUBSTR(t.request_ts, 12, 2) AS INTEGER)
ORDER BY g.city, hour_of_day;
