-- NAIVE 1: running total ordered by fill_time only (no fill_id tiebreak).
-- Tied fill_times are window peers under the default RANGE frame, so every fill
-- sharing a timestamp shows the SAME (end-of-peer) running total -> the earlier
-- tied fill's running inventory/cash is overstated.
WITH ff AS (
    SELECT fill_id, instrument_id, session_date, fill_time, side, fill_price, fill_quantity, fee,
           CASE WHEN side='BUY' THEN fill_quantity ELSE -fill_quantity END AS signed_qty,
           (CASE WHEN side='SELL' THEN fill_price*fill_quantity ELSE -fill_price*fill_quantity END) - fee AS signed_cash
    FROM fills
    WHERE account_id = 2
)
SELECT instrument_id, session_date, fill_time, fill_id, signed_qty,
  SUM(signed_qty) OVER (PARTITION BY instrument_id ORDER BY session_date, fill_time) AS running_inventory,
  ROUND(SUM(signed_cash) OVER (PARTITION BY instrument_id ORDER BY session_date, fill_time),4) AS running_net_cash
FROM ff
ORDER BY instrument_id, session_date, fill_time, fill_id;
