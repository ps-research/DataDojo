import pandas as pd
import random

# Deterministic in-memory input. No file or network access.
# `sales` holds one row per sale, tagged with a region and a product category.
_rng = random.Random(5150)

_regions = ["East", "North", "South", "West"]
_categories = ["Apparel", "Electronics", "Home", "Toys"]

# Skew the mix so that not every (region, category) pair is guaranteed to occur;
# a solver must still emit a 0 for any pair that never sold.
_pairs = []
for _r in _regions:
    for _c in _categories:
        _pairs.append((_r, _c))

_rows = []
for _i in range(220):
    _r, _c = _rng.choice(_pairs)
    # Deliberately suppress one specific pair so its cell must be filled with 0.
    if _r == "South" and _c == "Electronics":
        _r, _c = "South", "Apparel"
    _rows.append(
        {
            "sale_id": 8000 + _i,
            "region": _r,
            "category": _c,
            "amount": round(_rng.uniform(20.0, 500.0), 2),
        }
    )

sales = pd.DataFrame(_rows)
