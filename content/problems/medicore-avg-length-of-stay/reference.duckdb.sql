-- DuckDB: epoch(ts) gives seconds since the Unix epoch, the difference over 86400,
-- floored, is the number of complete 24-hour days elapsed.
SELECT
    w.department AS department,
    ROUND(AVG(CAST(FLOOR((epoch(a.discharge_ts) - epoch(a.admit_ts)) / 86400.0) AS INTEGER)), 2) AS avg_los_days
FROM admissions a
JOIN wards w ON w.ward_id = a.ward_id
WHERE a.discharge_ts IS NOT NULL
GROUP BY w.department
ORDER BY avg_los_days DESC, department ASC;
