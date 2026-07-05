-- NAIVE 2: ROW_NUMBER instead of DENSE_RANK for the volume rank. The twin names
-- print identical taker volume and must share a rank; ROW_NUMBER breaks the tie.
WITH taker AS (
    SELECT fill_id, instrument_id,
           CASE WHEN side='BUY' THEN 1 ELSE -1 END AS side_sign,
           fill_price, fill_quantity, fill_time,
           ROW_NUMBER() OVER (PARTITION BY order_id, side, fill_price, fill_quantity, fill_time
                              ORDER BY fill_id) AS rn
    FROM fills
    WHERE liquidity_flag='TAKER' AND session_date BETWEEN '2023-01-01' AND '2023-12-31'
),
ff AS (SELECT fill_id, instrument_id, side_sign, fill_price, fill_quantity, fill_time AS t
       FROM taker WHERE rn=1),
vq AS (
    SELECT instrument_id, quote_time AS t, bid_price, ask_price, quote_id
    FROM quotes
    WHERE bid_price IS NOT NULL AND ask_price IS NOT NULL AND ask_price>bid_price
      AND bid_size>0 AND ask_size>0
),
ev AS (
    SELECT instrument_id, t, 0 AS is_fill, quote_id AS ord2, bid_price, ask_price,
           CAST(NULL AS INTEGER) AS fill_id, CAST(NULL AS INTEGER) AS side_sign,
           CAST(NULL AS REAL) AS fill_price, CAST(NULL AS INTEGER) AS fill_quantity
    FROM vq
    UNION ALL
    SELECT instrument_id, t, 1, fill_id, CAST(NULL AS REAL), CAST(NULL AS REAL),
           fill_id, side_sign, fill_price, fill_quantity
    FROM ff
),
idx AS (
    SELECT ev.*,
        SUM(CASE WHEN is_fill=0 THEN 1 ELSE 0 END)
            OVER (PARTITION BY instrument_id ORDER BY t, is_fill, ord2
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS qrank
    FROM ev
),
qlist AS (SELECT instrument_id, qrank, bid_price, ask_price FROM idx WHERE is_fill=0),
per_fill AS (
    SELECT f.instrument_id, f.side_sign, f.fill_price, f.fill_quantity,
           (qa.bid_price+qa.ask_price)/2.0 AS arrival_mid,   -- last valid quote at/before fill
           (qm.bid_price+qm.ask_price)/2.0 AS markout_mid     -- first valid quote strictly after fill
    FROM idx f
    JOIN      qlist qa ON qa.instrument_id=f.instrument_id AND qa.qrank=f.qrank
    LEFT JOIN qlist qm ON qm.instrument_id=f.instrument_id AND qm.qrank=f.qrank+1
    WHERE f.is_fill=1 AND f.qrank>=1
),
inst_agg AS (
    SELECT i.instrument_id, i.symbol, COALESCE(i.sector,'UNCLASSIFIED') AS sector_cohort,
           SUM(p.fill_quantity) AS taker_volume,
           ROUND(AVG(p.side_sign*(p.fill_price-p.arrival_mid)/p.arrival_mid*10000.0),4) AS avg_slippage_bps,
           SUM(CASE WHEN p.markout_mid IS NOT NULL AND p.markout_mid>0 THEN 1 ELSE 0 END) AS n_markout,
           ROUND(AVG(CASE WHEN p.markout_mid IS NOT NULL AND p.markout_mid>0
                          THEN p.side_sign*(p.markout_mid-p.arrival_mid)/p.arrival_mid*10000.0
                          END),4) AS avg_markout_bps
    FROM per_fill p JOIN instruments i ON i.instrument_id=p.instrument_id
    GROUP BY i.instrument_id, i.symbol, COALESCE(i.sector,'UNCLASSIFIED')
)
SELECT sector_cohort, symbol, taker_volume, avg_slippage_bps, n_markout, avg_markout_bps,
       ROUND(PERCENT_RANK() OVER (PARTITION BY sector_cohort ORDER BY avg_slippage_bps),6) AS sector_slippage_pctile,
       ROW_NUMBER() OVER (ORDER BY taker_volume DESC) AS vol_rank
FROM inst_agg
ORDER BY sector_cohort, avg_slippage_bps, symbol;
