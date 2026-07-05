import pandas as pd
import random

# Deterministic in-memory input. No file or network access.
# `orders` holds one row per order.
_rng = random.Random(7788)

_regions = ["East", "North", "South", "West"]
_statuses = ["cancelled", "completed", "pending", "refunded"]
# Weighted so that "completed" is common but not overwhelming.
_status_weights = [1, 4, 2, 1]

_rows = []
for _i in range(180):
    _amount = round(_rng.uniform(15.0, 480.0), 2)
    _rows.append(
        {
            "order_id": 90000 + _i,
            "customer_id": 1000 + _rng.randint(0, 59),
            "region": _rng.choice(_regions),
            "status": _rng.choices(_statuses, weights=_status_weights, k=1)[0],
            "amount": _amount,
        }
    )

orders = pd.DataFrame(_rows)
