-- NAIVE (WA): fills the discharge of a still-open stay with the admit time, so every
-- in-house patient is scored as a 0-day stay and swept into the average. That both
-- inflates the denominator (open stays should not be counted at all) and pulls the
-- mean down. Departments with many open stays -- especially near the window end --
-- report an average well below the true figure over completed stays. Correct handling
-- excludes discharge_ts IS NULL entirely.
SELECT
    w.department AS department,
    ROUND(AVG(CAST(julianday(COALESCE(a.discharge_ts, a.admit_ts)) - julianday(a.admit_ts) AS INTEGER)), 2) AS avg_los_days
FROM admissions a
JOIN wards w ON w.ward_id = a.ward_id
GROUP BY w.department
ORDER BY avg_los_days DESC, department ASC;
