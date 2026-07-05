SELECT ff.flag_key AS flag_key, COUNT(DISTINCT e.user_id) AS adopters
FROM events e JOIN feature_flags ff ON ff.flag_id = e.flag_id
WHERE e.event_type='feature_used' AND e.event_ts>='2024-02-01' AND e.event_ts<'2024-03-01'
GROUP BY ff.flag_key ORDER BY adopters DESC, flag_key ASC;
