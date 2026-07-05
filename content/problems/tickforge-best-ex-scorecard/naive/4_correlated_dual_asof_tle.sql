-- NAIVE 4: correct result, but arrival and markout mids are found by two
-- correlated subqueries scanning quotes per fill. O(fills x quotes) per instrument
-- -> Time Limit Exceeded at red scale (~7M fills). Fails on time, not correctness.
WITH taker AS (
    SELECT fill_id, instrument_id,
           CASE WHEN side='BUY' THEN 1 ELSE -1 END AS side_sign,
           fill_price, fill_quantity, fill_time,
           ROW_NUMBER() OVER (PARTITION BY order_id, side, fill_price, fill_quantity, fill_time
                              ORDER BY fill_id) AS rn
    FROM fills
    WHERE liquidity_flag='TAKER' AND session_date BETWEEN '2023-01-01' AND '2023-12-31'
),
per_fill AS (
    SELECT t.instrument_id, t.side_sign, t.fill_price, t.fill_quantity,
      (SELECT (qa.bid_price+qa.ask_price)/2.0 FROM quotes qa
       WHERE qa.instrument_id=t.instrument_id AND qa.quote_time<=t.fill_time
         AND qa.bid_price IS NOT NULL AND qa.ask_price IS NOT NULL AND qa.ask_price>qa.bid_price
         AND qa.bid_size>0 AND qa.ask_size>0
       ORDER BY qa.quote_time DESC, qa.quote_id DESC LIMIT 1) AS arrival_mid,
      (SELECT (qm.bid_price+qm.ask_price)/2.0 FROM quotes qm
       WHERE qm.instrument_id=t.instrument_id AND qm.quote_time>t.fill_time
         AND qm.bid_price IS NOT NULL AND qm.ask_price IS NOT NULL AND qm.ask_price>qm.bid_price
         AND qm.bid_size>0 AND qm.ask_size>0
       ORDER BY qm.quote_time ASC, qm.quote_id ASC LIMIT 1) AS markout_mid
    FROM taker t WHERE t.rn=1
),
pf AS (SELECT * FROM per_fill WHERE arrival_mid IS NOT NULL),
inst_agg AS (
    SELECT i.instrument_id, i.symbol, COALESCE(i.sector,'UNCLASSIFIED') AS sector_cohort,
           SUM(pf.fill_quantity) AS taker_volume,
           ROUND(AVG(pf.side_sign*(pf.fill_price-pf.arrival_mid)/pf.arrival_mid*10000.0),4) AS avg_slippage_bps,
           SUM(CASE WHEN pf.markout_mid IS NOT NULL AND pf.markout_mid>0 THEN 1 ELSE 0 END) AS n_markout,
           ROUND(AVG(CASE WHEN pf.markout_mid IS NOT NULL AND pf.markout_mid>0
                          THEN pf.side_sign*(pf.markout_mid-pf.arrival_mid)/pf.arrival_mid*10000.0
                          END),4) AS avg_markout_bps
    FROM pf JOIN instruments i ON i.instrument_id=pf.instrument_id
    GROUP BY i.instrument_id, i.symbol, COALESCE(i.sector,'UNCLASSIFIED')
)
SELECT sector_cohort, symbol, taker_volume, avg_slippage_bps, n_markout, avg_markout_bps,
       ROUND(PERCENT_RANK() OVER (PARTITION BY sector_cohort ORDER BY avg_slippage_bps),6) AS sector_slippage_pctile,
       DENSE_RANK() OVER (ORDER BY taker_volume DESC) AS vol_rank
FROM inst_agg
ORDER BY sector_cohort, avg_slippage_bps, symbol;
