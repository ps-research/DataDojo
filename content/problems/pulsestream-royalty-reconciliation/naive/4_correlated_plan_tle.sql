-- NAIVE (TLE, not WA): resolves each play's active plan with a correlated scalar
-- subquery (ORDER BY precedence ... LIMIT 1) evaluated once PER PLAY. Same answer as the
-- reference but O(plays x subscriptions): it re-scans a listener's subscriptions for
-- every one of their plays and blows the time limit on the multi-million-row hidden
-- fixture. The reference resolves all plans in one windowed pass. (Designated naive-slow
-- for the section-6 TLE calibration.)
WITH play_dates AS (
    SELECT play_id, user_id, track_id,
           SUBSTR(CONCAT(played_at, ''), 1, 10)               AS play_date,
           CONCAT(SUBSTR(CONCAT(played_at, ''), 1, 7), '-01') AS period_month
    FROM plays
),
paid_plays AS (
    SELECT pd.play_id, pd.track_id, pd.user_id, pd.play_date, pd.period_month,
           (SELECT s.plan
              FROM subscriptions s
             WHERE s.user_id = pd.user_id
               AND CONCAT(s.started_at, '') <= pd.play_date
               AND (s.ended_at IS NULL OR pd.play_date <= CONCAT(s.ended_at, ''))
             ORDER BY CASE s.plan WHEN 'premium' THEN 5 WHEN 'family' THEN 4
                                  WHEN 'student' THEN 3 WHEN 'trial' THEN 2
                                  WHEN 'free' THEN 1 ELSE 0 END DESC,
                      s.started_at DESC, s.subscription_id ASC
             LIMIT 1) AS plan
    FROM play_dates pd
),
play_royalty AS (
    SELECT t.artist_id, pp.period_month,
           ROUND(COALESCE(rc.per_play_usd, rg.per_play_usd, 0) * 1000000) AS rate_micro
    FROM paid_plays pp
    JOIN tracks t ON t.track_id = pp.track_id
    JOIN users  u ON u.user_id  = pp.user_id
    LEFT JOIN royalty_rates rc ON rc.plan = pp.plan AND rc.country = u.country
          AND CONCAT(rc.effective_from, '') <= pp.play_date AND (rc.effective_to IS NULL OR pp.play_date < CONCAT(rc.effective_to, ''))
    LEFT JOIN royalty_rates rg ON rg.plan = pp.plan AND rg.country IS NULL
          AND CONCAT(rg.effective_from, '') <= pp.play_date AND (rg.effective_to IS NULL OR pp.play_date < CONCAT(rg.effective_to, ''))
    WHERE pp.plan IN ('student', 'family', 'premium')
),
computed AS (
    SELECT artist_id, period_month,
           FLOOR((SUM(rate_micro) + 5000) / 10000.0) AS computed_cents
    FROM play_royalty
    GROUP BY artist_id, period_month
    HAVING SUM(rate_micro) >= 5000        -- reconcile only months that accrued >= 1 cent
),
payout_agg AS (
    SELECT artist_id, CONCAT(period_month, '') AS period_month, 1 AS has_payout,
           SUM(CASE WHEN status = 'paid'    THEN ROUND(amount_usd * 100) ELSE 0 END) AS paid_cents,
           MAX(CASE WHEN status = 'paid'    THEN 1 ELSE 0 END) AS any_paid,
           MAX(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS any_pending
    FROM artist_payouts
    WHERE artist_id IS NOT NULL
    GROUP BY artist_id, CONCAT(period_month, '')
)
SELECT
    c.artist_id,
    a.name                                                 AS artist_name,
    c.period_month,
    c.computed_cents / 100.0                               AS computed_usd,
    COALESCE(pa.paid_cents, 0) / 100.0                     AS paid_usd,
    CASE WHEN pa.has_payout IS NULL THEN 'missing'
         WHEN pa.any_paid = 1 THEN 'paid'
         WHEN pa.any_pending = 1 THEN 'pending'
         ELSE 'reversed' END                               AS payout_status,
    (c.computed_cents - COALESCE(pa.paid_cents, 0)) / 100.0 AS discrepancy_usd
FROM computed c
JOIN artists a ON a.artist_id = c.artist_id
LEFT JOIN payout_agg pa ON pa.artist_id = c.artist_id AND pa.period_month = c.period_month
WHERE pa.has_payout IS NULL
   OR (pa.has_payout = 1 AND pa.any_paid = 0)
   OR (pa.any_paid = 1 AND ABS(c.computed_cents - COALESCE(pa.paid_cents, 0)) > 1)
ORDER BY c.artist_id, c.period_month;
