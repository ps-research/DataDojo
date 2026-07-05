WITH active AS (
  SELECT DISTINCT strftime('%Y', e.event_ts) || '-' || strftime('%W', e.event_ts) AS wk_label,
                  e.user_id AS user_id
  FROM events e JOIN users u ON u.user_id=e.user_id
  WHERE u.is_internal=0
),
wau AS (SELECT wk_label, COUNT(*) AS wau FROM active GROUP BY wk_label)
SELECT wk_label AS week_start, wau,
  ROUND(1.0*(wau - LAG(wau) OVER (ORDER BY wk_label))/NULLIF(LAG(wau) OVER (ORDER BY wk_label),0),6) AS wow_growth
FROM wau ORDER BY wk_label;
