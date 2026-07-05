# Spend per customer segment.
# Inner-join orders to the customer master so guest checkouts (customer_id with no
# matching customer row) drop out, then aggregate by segment.
_merged = orders.merge(customers, on="customer_id", how="inner")

result = (
    _merged.groupby("segment")
    .agg(
        order_count=("order_id", "count"),
        total_amount=("amount", "sum"),
    )
    .reset_index()
)
result["total_amount"] = result["total_amount"].round(2)
result = result.sort_values(
    ["total_amount", "segment"], ascending=[False, True]
).reset_index(drop=True)

print(result.to_csv(index=False), end="")
