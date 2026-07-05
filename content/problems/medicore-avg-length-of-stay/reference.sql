-- Average length of stay (whole elapsed days) per department, completed stays only.
-- SQLite form: julianday(discharge) - julianday(admit) is the elapsed time in days
-- as a float, CAST(... AS INTEGER) truncates toward zero, which for a non-negative
-- span is floor() -- the number of complete 24-hour days. A 12-hour stay -> 0, a
-- 3.5-day stay -> 3. Because it measures elapsed time, a stay that crosses midnight
-- (or 29 Feb) is scored correctly without any calendar special-casing.
--   * WHERE discharge_ts IS NOT NULL drops still-open stays (no LOS yet) -- they are
--     excluded, never counted as 0-day stays.
--   * Same-day (0-day) stays remain in the average.
-- Portable overrides for the elapsed-day expression live in reference.postgres.sql,
-- reference.mysql.sql and reference.duckdb.sql.
SELECT
    w.department AS department,
    ROUND(AVG(CAST(julianday(a.discharge_ts) - julianday(a.admit_ts) AS INTEGER)), 2) AS avg_los_days
FROM admissions a
JOIN wards w ON w.ward_id = a.ward_id
WHERE a.discharge_ts IS NOT NULL
GROUP BY w.department
ORDER BY avg_los_days DESC, department ASC;
