-- Admissions per department in February 2024.
-- INNER JOIN admissions -> wards to attach each admission's department, then a
-- half-open range on admit_ts (>= first of the month, < first of next month) keeps
-- exactly the February admissions -- including any timestamped on 29 Feb after
-- midnight, which a BETWEEN ... '2024-02-29' would drop. COUNT(*) counts admission
-- rows (open stays, NULL dispositions and the capacity-0 ward are all counted
-- correctly, because an admission is an admission regardless of how it ends).
-- The filter is on admit_ts, never on the non-chronological admission_id.
SELECT
    w.department          AS department,
    COUNT(*)              AS admission_count
FROM admissions a
JOIN wards w ON w.ward_id = a.ward_id
WHERE a.admit_ts >= '2024-02-01'
  AND a.admit_ts <  '2024-03-01'
GROUP BY w.department
ORDER BY admission_count DESC, department ASC;
