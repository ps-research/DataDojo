-- PostgreSQL: elapsed whole days = floor(epoch-seconds of the interval / 86400).
-- (discharge_ts - admit_ts) is an INTERVAL, EXTRACT(EPOCH ...) gives its seconds.
SELECT
    w.department AS department,
    ROUND(AVG(FLOOR(EXTRACT(EPOCH FROM (a.discharge_ts - a.admit_ts)) / 86400.0)), 2) AS avg_los_days
FROM admissions a
JOIN wards w ON w.ward_id = a.ward_id
WHERE a.discharge_ts IS NOT NULL
GROUP BY w.department
ORDER BY avg_los_days DESC, department ASC;
