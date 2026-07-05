-- NAIVE (WA): computes LOS from the DATE parts only, so it counts the number of
-- calendar-day boundaries crossed rather than the elapsed 24-hour days. A stay from
-- 23:00 to 03:00 the next morning (4 hours) scores 1 instead of 0, every stay that
-- spans a midnight without a full extra day is over-counted by one. The per-department
-- averages come out systematically too high. The correct measure is elapsed time
-- (floor of the timestamp difference), not date subtraction.
SELECT
    w.department AS department,
    ROUND(AVG(CAST(julianday(date(a.discharge_ts)) - julianday(date(a.admit_ts)) AS INTEGER)), 2) AS avg_los_days
FROM admissions a
JOIN wards w ON w.ward_id = a.ward_id
WHERE a.discharge_ts IS NOT NULL
GROUP BY w.department
ORDER BY avg_los_days DESC, department ASC;
