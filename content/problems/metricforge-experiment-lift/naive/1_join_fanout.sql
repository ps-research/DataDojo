WITH comp AS (SELECT experiment_id, experiment_key, primary_metric FROM experiments WHERE status='completed' AND end_date IS NOT NULL),
j AS (
  SELECT c.experiment_id, c.experiment_key, a.variant,
    CASE WHEN e.event_type=c.primary_metric AND e.event_ts>a.assigned_ts THEN 1 ELSE 0 END AS conv
  FROM experiment_assignments a JOIN comp c ON c.experiment_id=a.experiment_id
  LEFT JOIN events e ON e.user_id=a.user_id
),
agg AS (SELECT experiment_id, experiment_key, variant, COUNT(*) AS n_users, SUM(conv) AS n_conv FROM j GROUP BY experiment_id, experiment_key, variant)
SELECT c.experiment_key,
  COALESCE(ct.n_users,0) control_users, COALESCE(ct.n_conv,0) control_conversions,
  ROUND(1.0*ct.n_conv/NULLIF(ct.n_users,0),6) control_rate,
  COALESCE(tr.n_users,0) treatment_users, COALESCE(tr.n_conv,0) treatment_conversions,
  ROUND(1.0*tr.n_conv/NULLIF(tr.n_users,0),6) treatment_rate,
  ROUND(1.0*tr.n_conv/NULLIF(tr.n_users,0)-1.0*ct.n_conv/NULLIF(ct.n_users,0),6) lift
FROM comp c
LEFT JOIN agg ct ON ct.experiment_id=c.experiment_id AND ct.variant='control'
LEFT JOIN agg tr ON tr.experiment_id=c.experiment_id AND tr.variant='treatment'
ORDER BY lift DESC, c.experiment_key;
