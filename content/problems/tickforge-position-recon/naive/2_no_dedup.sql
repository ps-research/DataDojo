-- NAIVE 2: no de-duplication of double-booked fills or double-posted position
-- snapshots (both injected only at full-landmine scale). Matches on the mild
-- visible sample; over-counts on the hidden black fixture.
WITH splits AS (
    -- interpret the 'a:b' split token as a numeric multiplier a/b
    SELECT instrument_id, ex_date,
           CASE split_ratio
             WHEN '2:1'  THEN 2.0  WHEN '3:1' THEN 3.0  WHEN '3:2'  THEN 1.5
             WHEN '4:1'  THEN 4.0  WHEN '1:5' THEN 0.2  WHEN '1:10' THEN 0.1
           END AS mult
    FROM corporate_actions
    WHERE action_type = 'SPLIT' AND split_ratio IS NOT NULL
),
dd AS (
    -- de-duplicated fills (business key), signed, bucketed by the authoritative session
    SELECT t.account_id, t.instrument_id, t.session_date,
           CASE WHEN t.side='BUY' THEN t.fill_quantity ELSE -t.fill_quantity END AS signed_qty
    FROM fills t  -- NO DEDUP
),
month_ends AS (
    -- month-end reporting dates = the real month-end sessions on which risk snapshots land
    SELECT DISTINCT as_of_date FROM positions
),
sd AS (SELECT DISTINCT instrument_id, session_date FROM dd),
sd_factor AS (
    -- cumulative split factor that re-bases a fill from its session up to as_of_date
    -- (product of the mults of splits with ex_date strictly after the fill and on/before as_of)
    SELECT sd.instrument_id, sd.session_date, m.as_of_date,
           EXP(COALESCE(SUM(LN(s.mult)),0)) AS factor
    FROM sd JOIN month_ends m ON sd.session_date <= m.as_of_date
    LEFT JOIN splits s ON s.instrument_id=sd.instrument_id
         AND s.ex_date > sd.session_date AND s.ex_date <= m.as_of_date
    GROUP BY sd.instrument_id, sd.session_date, m.as_of_date
),
recon AS (
    SELECT f.account_id, f.instrument_id, sf.as_of_date,
           CAST(ROUND(SUM(f.signed_qty * sf.factor)) AS INTEGER) AS recon_qty
    FROM dd f
    JOIN sd_factor sf ON sf.instrument_id=f.instrument_id AND sf.session_date=f.session_date
    GROUP BY f.account_id, f.instrument_id, sf.as_of_date
),
eod AS (
    -- month-end EOD mark: mid of the last valid two-sided quote on the session
    SELECT instrument_id, session_date AS as_of_date, (bid_price+ask_price)/2.0 AS mark
    FROM (
      SELECT instrument_id, session_date, bid_price, ask_price,
             ROW_NUMBER() OVER (PARTITION BY instrument_id, session_date
                                ORDER BY quote_time DESC, quote_id DESC) AS rn
      FROM quotes
      WHERE bid_price IS NOT NULL AND ask_price IS NOT NULL AND ask_price>bid_price
        AND bid_size>0 AND ask_size>0
    ) z WHERE rn=1
),
snap AS (
    -- de-duplicate double-posted snapshots on the logical key
    SELECT account_id, instrument_id, as_of_date, quantity AS snap_qty
    FROM positions  -- NO DEDUP of double-posted snapshots
)
SELECT s.account_id, s.instrument_id, s.as_of_date,
       r.recon_qty,
       s.snap_qty,
       ROUND(e.mark, 6) AS mark,
       ROUND(r.recon_qty * e.mark, 4) AS recon_mtm,
       CASE WHEN r.recon_qty = s.snap_qty THEN 1 ELSE 0 END AS qty_reconciles
FROM snap s
LEFT JOIN recon r ON r.account_id=s.account_id AND r.instrument_id=s.instrument_id AND r.as_of_date=s.as_of_date
LEFT JOIN eod   e ON e.instrument_id=s.instrument_id AND e.as_of_date=s.as_of_date
ORDER BY s.as_of_date, s.account_id, s.instrument_id;
