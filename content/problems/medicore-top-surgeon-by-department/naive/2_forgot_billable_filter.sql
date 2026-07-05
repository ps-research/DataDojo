-- NAIVE (WA): drops the is_billable = 1 filter and counts all procedures. Non-billable
-- work then inflates each surgeon's total, and because surgeons differ in how much of
-- their work is billable, the inflation is uneven -- in some departments it changes
-- which surgeon (or set of tied surgeons) holds the top count. RANK() is used correctly
-- here, so the failure is purely the missing filter, not the ranking.
WITH counts AS (
    SELECT w.department AS department, p.primary_surgeon_id AS surgeon_id, COUNT(*) AS billable_count
    FROM procedures p
    JOIN admissions a ON a.admission_id = p.admission_id
    JOIN wards      w ON w.ward_id      = a.ward_id
    WHERE p.primary_surgeon_id IS NOT NULL
    GROUP BY w.department, p.primary_surgeon_id
),
ranked AS (
    SELECT c.*, RANK() OVER (PARTITION BY c.department ORDER BY c.billable_count DESC) AS rnk
    FROM counts c
)
SELECT r.department, r.surgeon_id, s.full_name AS surgeon_name, r.billable_count
FROM ranked r
JOIN staff s ON s.staff_id = r.surgeon_id
WHERE r.rnk = 1
ORDER BY r.department ASC, r.surgeon_id ASC;
