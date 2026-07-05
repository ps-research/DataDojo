import pandas as pd
import random

# Deterministic in-memory input. No file or network access.
# `customers` is the customer master; `orders` is the order log.
# Some orders reference a customer_id that is NOT in `customers` (guest checkouts).
_rng = random.Random(3315)

_segments = ["Enterprise", "Consumer", "SMB"]

# Registered customers have ids 200..259.
_customer_rows = []
for _cid in range(200, 260):
    _customer_rows.append(
        {
            "customer_id": _cid,
            "name": "cust_%d" % _cid,
            "segment": _rng.choice(_segments),
        }
    )
customers = pd.DataFrame(_customer_rows)

# Orders reference ids 200..269. Ids 260..269 are guest checkouts with no
# matching customer row and must not contribute to any segment.
_order_rows = []
for _i in range(200):
    _cid = 200 + _rng.randint(0, 69)
    _order_rows.append(
        {
            "order_id": 700000 + _i,
            "customer_id": _cid,
            "amount": round(_rng.uniform(20.0, 600.0), 2),
        }
    )
orders = pd.DataFrame(_order_rows)
