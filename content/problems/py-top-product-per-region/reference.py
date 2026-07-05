# Top two products by revenue within each region.
# First total revenue per (region, product). Then rank products inside each region
# by revenue descending, breaking ties by product name ascending, and keep ranks
# 1 and 2. Ranks are assigned by sorted position (a dense 1, 2 per region).
_agg = (
    sales.groupby(["region", "product"], as_index=False)["amount"]
    .sum()
    .rename(columns={"amount": "product_revenue"})
)
_agg["product_revenue"] = _agg["product_revenue"].round(2)

_agg = _agg.sort_values(
    ["region", "product_revenue", "product"], ascending=[True, False, True]
)
_agg["rank"] = _agg.groupby("region").cumcount() + 1

result = _agg[_agg["rank"] <= 2].reset_index(drop=True)
result = result[["region", "product", "product_revenue", "rank"]]
print(result.to_csv(index=False), end="")
