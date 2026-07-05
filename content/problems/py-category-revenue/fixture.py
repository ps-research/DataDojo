import pandas as pd
import random

# Deterministic in-memory input. No file or network access.
# `sales` holds one row per billed order line.
_rng = random.Random(4021)

_categories = ["Apparel", "Books", "Electronics", "Grocery", "Home", "Toys"]
_price_pool = {
    "Apparel": [12.50, 24.00, 39.99, 55.00],
    "Books": [8.99, 14.99, 19.50, 27.00],
    "Electronics": [49.99, 89.00, 129.50, 249.00],
    "Grocery": [3.50, 6.25, 11.00, 21.75],
    "Home": [15.00, 32.50, 60.00, 110.00],
    "Toys": [9.99, 18.50, 25.00, 42.00],
}

_rows = []
for _i in range(150):
    _cat = _rng.choice(_categories)
    _rows.append(
        {
            "order_id": 5000 + _i,
            "category": _cat,
            "quantity": _rng.randint(1, 6),
            "unit_price": _rng.choice(_price_pool[_cat]),
        }
    )

sales = pd.DataFrame(_rows)
