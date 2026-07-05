-- NAIVE 1: no split re-basing (cumulative split factor forced to 1). Price PnL on
-- any name that has split is wrong from the ex-date on, so the attribution no
-- longer reconciles to the equity change.
-- Per (account,instrument,session) attribution + independent equity, for verification.
WITH td AS (
    SELECT session_date, session_seq FROM trading_days
),
splits AS (
    SELECT instrument_id, ex_date,
           CASE split_ratio WHEN '2:1' THEN 2.0 WHEN '3:1' THEN 3.0 WHEN '3:2' THEN 1.5
                            WHEN '4:1' THEN 4.0 WHEN '1:5' THEN 0.2 WHEN '1:10' THEN 0.1 END AS mult
    FROM corporate_actions WHERE action_type='SPLIT' AND split_ratio IS NOT NULL
),
divs AS (
    SELECT instrument_id, ex_date, SUM(cash_amount) AS div_cash
    FROM corporate_actions WHERE action_type='DIVIDEND' AND cash_amount IS NOT NULL
    GROUP BY instrument_id, ex_date
),
dd AS (  -- de-duplicated fills, signed, native basis
    SELECT account_id, instrument_id, session_date,
           CASE WHEN side='BUY' THEN fill_quantity ELSE -fill_quantity END AS sq,
           (CASE WHEN side='BUY' THEN fill_quantity ELSE -fill_quantity END) * fill_price AS sqn
    FROM (
      SELECT account_id, instrument_id, session_date, side, fill_quantity, fill_price,
             ROW_NUMBER() OVER (PARTITION BY order_id, side, fill_price, fill_quantity, fill_time ORDER BY fill_id) rn
      FROM fills
    ) t WHERE rn=1
),
daytrade AS (
    SELECT account_id, instrument_id, session_date,
           SUM(sq) AS day_qty, SUM(sqn) AS day_notional
    FROM dd GROUP BY account_id, instrument_id, session_date
),
pairs AS (  -- active pairs and their first-trade session
    SELECT dt.account_id, dt.instrument_id, MIN(td.session_seq) AS first_seq
    FROM daytrade dt JOIN td ON td.session_date=dt.session_date
    GROUP BY dt.account_id, dt.instrument_id
),
pair_sessions AS (  -- every session from first trade to window end
    SELECT p.account_id, p.instrument_id, td.session_date, td.session_seq
    FROM pairs p JOIN td ON td.session_seq >= p.first_seq
),
instr_sessions AS (SELECT DISTINCT instrument_id, session_date, session_seq FROM pair_sessions),
cf AS (  -- cumulative split factor per (instrument, session)
    SELECT s.instrument_id, s.session_date, s.session_seq,
           1.0 AS cf
    FROM instr_sessions s
    LEFT JOIN splits sp ON sp.instrument_id=s.instrument_id AND sp.ex_date<=s.session_date
    GROUP BY s.instrument_id, s.session_date, s.session_seq
),
eod_marked AS (  -- sessions with a valid EOD mid
    SELECT instrument_id, session_date, (bid_price+ask_price)/2.0 AS mark
    FROM (
      SELECT instrument_id, session_date, bid_price, ask_price,
             ROW_NUMBER() OVER (PARTITION BY instrument_id, session_date ORDER BY quote_time DESC, quote_id DESC) rn
      FROM quotes
      WHERE bid_price IS NOT NULL AND ask_price IS NOT NULL AND ask_price>bid_price AND bid_size>0 AND ask_size>0
    ) z WHERE rn=1
),
carry_date AS (  -- for each instr-session, the latest session<=it that had a mark
    SELECT s.instrument_id, s.session_date,
           MAX(em.session_date) AS mdate
    FROM instr_sessions s
    LEFT JOIN eod_marked em ON em.instrument_id=s.instrument_id AND em.session_date<=s.session_date
    GROUP BY s.instrument_id, s.session_date
),
eod_carry AS (
    SELECT c.instrument_id, c.session_date, em.mark
    FROM carry_date c LEFT JOIN eod_marked em
      ON em.instrument_id=c.instrument_id AND em.session_date=c.mdate
),
base AS (
    SELECT ps.account_id, ps.instrument_id, ps.session_date, ps.session_seq,
           cf.cf AS cf_d,
           ec.mark AS m_d,
           COALESCE(dt.day_qty,0)     AS day_qty,
           COALESCE(dt.day_notional,0) AS day_notional,
           COALESCE(dv.div_cash,0)    AS div_d,
           SUM(COALESCE(dt.day_qty,0)/cf.cf)
               OVER (PARTITION BY ps.account_id, ps.instrument_id ORDER BY ps.session_seq
                     ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Q_d
    FROM pair_sessions ps
    JOIN cf        ON cf.instrument_id=ps.instrument_id AND cf.session_date=ps.session_date
    LEFT JOIN eod_carry ec ON ec.instrument_id=ps.instrument_id AND ec.session_date=ps.session_date
    LEFT JOIN daytrade dt ON dt.account_id=ps.account_id AND dt.instrument_id=ps.instrument_id AND dt.session_date=ps.session_date
    LEFT JOIN divs dv ON dv.instrument_id=ps.instrument_id AND dv.ex_date=ps.session_date
),
calc AS (
    SELECT b.*,
           b.Q_d - b.day_qty/b.cf_d AS Q_prev,
           LAG(b.cf_d) OVER (PARTITION BY b.account_id, b.instrument_id ORDER BY b.session_seq) AS cf_prev,
           LAG(b.m_d)  OVER (PARTITION BY b.account_id, b.instrument_id ORDER BY b.session_seq) AS m_prev
    FROM base b
),
comp AS (
  SELECT account_id, instrument_id, session_date, session_seq, day_qty, Q_prev,
       CASE WHEN Q_prev=0 OR m_d IS NULL OR m_prev IS NULL THEN 0.0
            ELSE Q_prev*(cf_d*m_d - cf_prev*m_prev) END AS price_pnl,
       CASE WHEN day_qty=0 THEN 0.0 WHEN m_d IS NULL THEN 0.0
            ELSE m_d*day_qty - day_notional END AS trading_pnl,
       CASE WHEN Q_prev=0 OR div_d=0 THEN 0.0
            ELSE div_d*Q_prev*cf_prev END AS dividend_pnl
  FROM calc
)
SELECT account_id, session_date,
       ROUND(SUM(price_pnl),4)    AS price_pnl,
       ROUND(SUM(trading_pnl),4)  AS trading_pnl,
       ROUND(SUM(dividend_pnl),4) AS dividend_pnl,
       ROUND(SUM(price_pnl+trading_pnl+dividend_pnl),4) AS total_pnl
FROM comp
GROUP BY account_id, session_date
HAVING SUM(CASE WHEN day_qty<>0 OR Q_prev<>0 THEN 1 ELSE 0 END) > 0
ORDER BY account_id, session_date;
