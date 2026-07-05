-- Top surgeon(s) by billable-procedure volume within each department, ties kept.
--   counts: one row per (department, surgeon) with the number of BILLABLE procedures
--           they performed, where a procedure's department comes from its admission's
--           admitting ward. is_billable = 1 keeps only billable work, the NULL surgeon
--           filter drops unassigned procedures. COUNT(*) counts every billable
--           procedure row (multiple within one admission all count).
--   ranked: RANK() over each department by count DESC. RANK() gives every surgeon at
--           the top count the same rank 1, so co-leaders are all retained (unlike
--           ROW_NUMBER(), which would keep only one).
-- Portable across engines: window function + COUNT + joins, no date math.
WITH counts AS (
    SELECT
        w.department          AS department,
        p.primary_surgeon_id  AS surgeon_id,
        COUNT(*)              AS billable_count
    FROM procedures p
    JOIN admissions a ON a.admission_id = p.admission_id
    JOIN wards      w ON w.ward_id      = a.ward_id
    WHERE p.is_billable = 1
      AND p.primary_surgeon_id IS NOT NULL
    GROUP BY w.department, p.primary_surgeon_id
),
ranked AS (
    SELECT
        c.*,
        RANK() OVER (PARTITION BY c.department ORDER BY c.billable_count DESC) AS rnk
    FROM counts c
)
SELECT
    r.department,
    r.surgeon_id,
    s.full_name AS surgeon_name,
    r.billable_count
FROM ranked r
JOIN staff s ON s.staff_id = r.surgeon_id
WHERE r.rnk = 1
ORDER BY r.department ASC, r.surgeon_id ASC;
