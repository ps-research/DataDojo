-- NAIVE (kills: COUNT(*) instead of COUNT(DISTINCT user_id)).
-- Counts every feature_used row (repeat usage + double-fired duplicates), so it
-- both inflates the adopter numbers and reorders the leaderboard.
SELECT ff.flag_key AS flag_key, COUNT(*) AS adopters
FROM events e JOIN feature_flags ff ON ff.flag_id = e.flag_id
WHERE e.event_type='feature_used' AND e.event_ts>='2024-02-01' AND e.event_ts<'2024-03-01'
GROUP BY ff.flag_key ORDER BY adopters DESC, flag_key ASC;
