import pandas as pd
import random
import datetime as _dt

# Deterministic in-memory input. No file or network access.
# `transactions` holds one row per transaction across the first half of 2024.
# NOTE: no transaction is dated in March 2024 -- that month is deliberately empty.
_rng = random.Random(9091)

# Month start dates for Jan..Jun 2024, but March is intentionally omitted from the
# set of months that receive transactions.
_active_months = [
    _dt.date(2024, 1, 1),
    _dt.date(2024, 2, 1),
    _dt.date(2024, 4, 1),
    _dt.date(2024, 5, 1),
    _dt.date(2024, 6, 1),
]


def _month_len(_m):
    if _m.month == 12:
        _nxt = _dt.date(_m.year + 1, 1, 1)
    else:
        _nxt = _dt.date(_m.year, _m.month + 1, 1)
    return (_nxt - _m).days


_rows = []
_tid = 40000
for _m in _active_months:
    _n = _rng.randint(18, 34)
    for _ in range(_n):
        _day = _rng.randint(1, _month_len(_m))
        _ts = _dt.date(_m.year, _m.month, _day)
        _rows.append(
            {
                "txn_id": _tid,
                "ts": _ts.strftime("%Y-%m-%d"),
                "amount": round(_rng.uniform(10.0, 400.0), 2),
            }
        )
        _tid += 1

# Shuffle so rows are not pre-sorted by date.
_rng.shuffle(_rows)
transactions = pd.DataFrame(_rows)
