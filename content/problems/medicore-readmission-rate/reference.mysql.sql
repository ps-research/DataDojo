-- MySQL 8+: the 30-day inclusive upper bound is discharge_ts + INTERVAL 30 DAY.
WITH seq AS (
    SELECT
        a.admission_id, a.patient_id, w.department AS department,
        a.admit_ts, a.discharge_ts, a.discharge_disposition,
        LEAD(a.admit_ts)   OVER (PARTITION BY a.patient_id ORDER BY a.admit_ts, a.admission_id) AS next_admit_ts,
        LEAD(a.admit_type) OVER (PARTITION BY a.patient_id ORDER BY a.admit_ts, a.admission_id) AS next_admit_type
    FROM admissions a
    JOIN wards w ON w.ward_id = a.ward_id
),
idx AS (
    SELECT
        department,
        CASE WHEN next_admit_type = 'EMERGENCY'
                  AND next_admit_ts IS NOT NULL
                  AND next_admit_ts >= discharge_ts
                  AND next_admit_ts <= discharge_ts + INTERVAL 30 DAY
             THEN 1 ELSE 0 END AS readmitted
    FROM seq
    WHERE discharge_ts IS NOT NULL
      AND discharge_disposition NOT IN ('EXPIRED', 'TRANSFER')
),
agg AS (
    SELECT department, COUNT(*) AS eligible_index_stays, SUM(readmitted) AS readmissions
    FROM idx GROUP BY department
)
SELECT
    d.department,
    COALESCE(g.eligible_index_stays, 0)  AS eligible_index_stays,
    COALESCE(g.readmissions, 0)          AS readmissions,
    ROUND(1.0 * g.readmissions / NULLIF(g.eligible_index_stays, 0), 4) AS readmission_rate
FROM (SELECT DISTINCT department FROM wards) d
LEFT JOIN agg g ON g.department = d.department
ORDER BY d.department ASC;
