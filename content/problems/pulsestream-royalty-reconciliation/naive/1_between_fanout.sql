-- NAIVE (WA): resolves the plan by joining EVERY active paid subscription with no
-- precedence tiebreak. A listener with two overlapping paid periods (the data-entry
-- glitch) matches two subscription rows per play, so every such play earns TWICE
-- (once per plan). Royalties for those artists are overstated and their
-- reconciliation flips.
WITH play_dates AS (
    SELECT play_id, user_id, track_id,
           SUBSTR(played_at, 1, 10)         AS play_date,
           SUBSTR(played_at, 1, 7) || '-01' AS period_month
    FROM plays
),
play_royalty AS (
    SELECT t.artist_id, pd.period_month,
           COALESCE(rc.per_play_usd, rg.per_play_usd, 0) AS rate
    FROM play_dates pd
    JOIN subscriptions s
      ON s.user_id = pd.user_id
     AND s.started_at <= pd.play_date
     AND (s.ended_at IS NULL OR pd.play_date <= s.ended_at)
     AND s.plan IN ('student', 'family', 'premium')
    JOIN tracks t ON t.track_id = pd.track_id
    JOIN users  u ON u.user_id  = pd.user_id
    LEFT JOIN royalty_rates rc
           ON rc.plan = s.plan AND rc.country = u.country
          AND rc.effective_from <= pd.play_date
          AND (rc.effective_to IS NULL OR pd.play_date < rc.effective_to)
    LEFT JOIN royalty_rates rg
           ON rg.plan = s.plan AND rg.country IS NULL
          AND rg.effective_from <= pd.play_date
          AND (rg.effective_to IS NULL OR pd.play_date < rg.effective_to)
),
computed AS (
    SELECT artist_id, period_month, ROUND(SUM(rate), 2) AS computed_usd
    FROM play_royalty
    GROUP BY artist_id, period_month
    HAVING ROUND(SUM(rate), 2) > 0
),
payout_agg AS (
    SELECT artist_id, period_month, 1 AS has_payout,
           SUM(CASE WHEN status = 'paid'    THEN amount_usd ELSE 0 END) AS paid_usd,
           MAX(CASE WHEN status = 'paid'    THEN 1 ELSE 0 END)          AS any_paid,
           MAX(CASE WHEN status = 'pending' THEN 1 ELSE 0 END)          AS any_pending
    FROM artist_payouts
    WHERE artist_id IS NOT NULL
    GROUP BY artist_id, period_month
)
SELECT c.artist_id, a.name AS artist_name, c.period_month, c.computed_usd,
       COALESCE(pa.paid_usd, 0) AS paid_usd,
       CASE WHEN pa.has_payout IS NULL THEN 'missing'
            WHEN pa.any_paid = 1 THEN 'paid'
            WHEN pa.any_pending = 1 THEN 'pending'
            ELSE 'reversed' END AS payout_status,
       ROUND(c.computed_usd - COALESCE(pa.paid_usd, 0), 2) AS discrepancy_usd
FROM computed c
JOIN artists a ON a.artist_id = c.artist_id
LEFT JOIN payout_agg pa ON pa.artist_id = c.artist_id AND pa.period_month = c.period_month
WHERE pa.has_payout IS NULL
   OR (pa.has_payout = 1 AND pa.any_paid = 0)
   OR (pa.any_paid = 1 AND ABS(c.computed_usd - pa.paid_usd) > 0.01)
ORDER BY c.artist_id, c.period_month;
