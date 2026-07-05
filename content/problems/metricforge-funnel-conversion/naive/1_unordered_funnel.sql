-- NAIVE: presence-based (ignores event_ts ordering); also drops NULL channel.
WITH sess AS (
  SELECT s.session_id, u.referral_channel AS channel,
    MAX(CASE WHEN e.event_type='view_plans'     THEN 1 ELSE 0 END) AS h1,
    MAX(CASE WHEN e.event_type='start_checkout' THEN 1 ELSE 0 END) AS h2,
    MAX(CASE WHEN e.event_type='enter_payment'  THEN 1 ELSE 0 END) AS h3,
    MAX(CASE WHEN e.event_type='purchase'       THEN 1 ELSE 0 END) AS h4
  FROM sessions s JOIN users u ON u.user_id=s.user_id
  LEFT JOIN events e ON e.session_id=s.session_id
  GROUP BY s.session_id, u.referral_channel
)
SELECT channel AS referral_channel,
  SUM(h1) AS entered,
  SUM(CASE WHEN h1=1 AND h2=1 THEN 1 ELSE 0 END) AS reached_checkout,
  SUM(CASE WHEN h1=1 AND h2=1 AND h3=1 THEN 1 ELSE 0 END) AS reached_payment,
  SUM(CASE WHEN h1=1 AND h2=1 AND h3=1 AND h4=1 THEN 1 ELSE 0 END) AS reached_purchase,
  ROUND(1.0*SUM(CASE WHEN h1=1 AND h2=1 THEN 1 ELSE 0 END)/NULLIF(SUM(h1),0),6) AS cr_checkout,
  ROUND(1.0*SUM(CASE WHEN h1=1 AND h2=1 AND h3=1 THEN 1 ELSE 0 END)/NULLIF(SUM(CASE WHEN h1=1 AND h2=1 THEN 1 ELSE 0 END),0),6) AS cr_payment,
  ROUND(1.0*SUM(CASE WHEN h1=1 AND h2=1 AND h3=1 AND h4=1 THEN 1 ELSE 0 END)/NULLIF(SUM(CASE WHEN h1=1 AND h2=1 AND h3=1 THEN 1 ELSE 0 END),0),6) AS cr_purchase
FROM sess
GROUP BY channel
ORDER BY entered DESC, referral_channel;
