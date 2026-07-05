-- NAIVE (WA): uses ROW_NUMBER() instead of RANK(). ROW_NUMBER() assigns a strict
-- 1,2,3,... within each department even when several surgeons share the top count, so
-- WHERE rn = 1 keeps exactly one surgeon per department and silently drops every tied
-- co-leader. In any department with a tie for the maximum, this returns too few rows.
-- The tie-break inside ORDER BY (surgeon_id) only decides which single co-leader
-- survives -- it does not restore the others.
WITH counts AS (
    SELECT w.department AS department, p.primary_surgeon_id AS surgeon_id, COUNT(*) AS billable_count
    FROM procedures p
    JOIN admissions a ON a.admission_id = p.admission_id
    JOIN wards      w ON w.ward_id      = a.ward_id
    WHERE p.is_billable = 1 AND p.primary_surgeon_id IS NOT NULL
    GROUP BY w.department, p.primary_surgeon_id
),
ranked AS (
    SELECT c.*, ROW_NUMBER() OVER (PARTITION BY c.department ORDER BY c.billable_count DESC, c.surgeon_id) AS rn
    FROM counts c
)
SELECT r.department, r.surgeon_id, s.full_name AS surgeon_name, r.billable_count
FROM ranked r
JOIN staff s ON s.staff_id = r.surgeon_id
WHERE r.rn = 1
ORDER BY r.department ASC, r.surgeon_id ASC;
