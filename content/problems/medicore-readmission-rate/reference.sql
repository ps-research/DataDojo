-- Thirty-day EMERGENCY readmission rate by index-stay department.
-- seq: sequence each patient's admissions in TIME (admit_ts, admission_id as the
--   deterministic tiebreak -- never by admission_id alone, which is not chronological
--   across patients) and LEAD the NEXT admission's admit_ts and admit_type onto each
--   row. One O(n log n) window pass, no self-join.
-- idx: keep only eligible index stays -- completed (discharge_ts IS NOT NULL) and not a
--   death or transfer-out. Flag readmitted = 1 when the IMMEDIATE next admission is
--   EMERGENCY and admits within [discharge, discharge + 30 days] INCLUSIVE. The upper
--   bound uses datetime(discharge_ts,'+30 days') so exactly 30 days still counts,
--   next_admit_ts >= discharge_ts keeps it a genuine post-discharge return.
-- Final: start from the full department list and LEFT JOIN the aggregates, so a
--   department with zero eligible index stays (e.g. all-EXPIRED Palliative Care) still
--   appears with a NULL rate. NULLIF guards the divide-by-zero, 1.0* forces real division.
-- SQLite form. Per-engine 30-day interval overrides live in reference.postgres.sql,
-- reference.mysql.sql and reference.duckdb.sql.
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
                  AND next_admit_ts <= datetime(discharge_ts, '+30 days')
             THEN 1 ELSE 0 END AS readmitted
    FROM seq
    WHERE discharge_ts IS NOT NULL
      AND discharge_disposition NOT IN ('EXPIRED', 'TRANSFER')
),
agg AS (
    SELECT department,
           COUNT(*)         AS eligible_index_stays,
           SUM(readmitted)  AS readmissions
    FROM idx
    GROUP BY department
)
SELECT
    d.department,
    COALESCE(g.eligible_index_stays, 0)  AS eligible_index_stays,
    COALESCE(g.readmissions, 0)          AS readmissions,
    ROUND(1.0 * g.readmissions / NULLIF(g.eligible_index_stays, 0), 4) AS readmission_rate
FROM (SELECT DISTINCT department FROM wards) d
LEFT JOIN agg g ON g.department = d.department
ORDER BY d.department ASC;
