-- MySQL: TIMESTAMPDIFF(DAY, a, b) is the count of complete 24-hour days between the
-- two instants (it truncates a partial day), i.e. exactly the whole-day floor of the
-- elapsed span. A 12-hour stay -> 0, a 3.5-day stay -> 3.
SELECT
    w.department AS department,
    ROUND(AVG(TIMESTAMPDIFF(DAY, a.admit_ts, a.discharge_ts)), 2) AS avg_los_days
FROM admissions a
JOIN wards w ON w.ward_id = a.ward_id
WHERE a.discharge_ts IS NOT NULL
GROUP BY w.department
ORDER BY avg_los_days DESC, department ASC;
