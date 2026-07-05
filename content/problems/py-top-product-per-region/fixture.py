import pandas as pd
import random

# Deterministic in-memory input. No file or network access.
# `sales` holds one row per sale line, tagged with a region and a product.
_rng = random.Random(6262)

_regions = ["East", "North", "South", "West"]
_products = ["Alpha", "Bravo", "Charlie", "Delta", "Echo"]

_rows = []
for _i in range(240):
    _rows.append(
        {
            "sale_id": 3000 + _i,
            "region": _rng.choice(_regions),
            "product": _rng.choice(_products),
            "amount": round(_rng.uniform(5.0, 250.0), 2),
        }
    )

sales = pd.DataFrame(_rows)
