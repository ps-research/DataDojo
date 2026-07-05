-- NAIVE (WA): aggregates only over the eligible index set and divides directly. A
-- department with zero eligible index stays -- Palliative Care, whose discharges are
-- all EXPIRED -- produces no rows in `idx` and therefore vanishes from the result
-- entirely, instead of appearing with a NULL rate as required. (Because the group only
-- exists when COUNT(*) >= 1 the direct division never actually divides by zero here,
-- but dropping NULLIF is the same latent divide-by-zero the spec calls out, the
-- observable failure is the missing zero-eligible department row.)
WITH seq AS (
    SELECT a.admission_id, a.patient_id, w.department AS department, a.admit_ts, a.discharge_ts, a.discharge_disposition,
           LEAD(a.admit_ts)   OVER (PARTITION BY a.patient_id ORDER BY a.admit_ts, a.admission_id) AS next_admit_ts,
           LEAD(a.admit_type) OVER (PARTITION BY a.patient_id ORDER BY a.admit_ts, a.admission_id) AS next_admit_type
    FROM admissions a JOIN wards w ON w.ward_id = a.ward_id
),
idx AS (
    SELECT department,
           CASE WHEN next_admit_type = 'EMERGENCY' AND next_admit_ts IS NOT NULL
                     AND next_admit_ts >= discharge_ts
                     AND next_admit_ts <= datetime(discharge_ts, '+30 days')
                THEN 1 ELSE 0 END AS readmitted
    FROM seq
    WHERE discharge_ts IS NOT NULL AND discharge_disposition NOT IN ('EXPIRED', 'TRANSFER')
)
SELECT department,
       COUNT(*)        AS eligible_index_stays,
       SUM(readmitted) AS readmissions,
       ROUND(1.0 * SUM(readmitted) / COUNT(*), 4) AS readmission_rate
FROM idx
GROUP BY department
ORDER BY department ASC;
