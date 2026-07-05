# High-value completed orders.
# Keep only completed orders worth at least 100, then sort by amount descending
# with order_id as the tie-break.
_mask = (orders["status"] == "completed") & (orders["amount"] >= 100)
result = orders.loc[_mask, ["order_id", "customer_id", "region", "amount"]].copy()
result = result.sort_values(
    ["amount", "order_id"], ascending=[False, True]
).reset_index(drop=True)

print(result.to_csv(index=False), end="")
