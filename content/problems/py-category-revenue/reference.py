# Revenue per product category.
# Line revenue = quantity * unit_price. Aggregate by category, then sort by
# revenue descending with category as the tie-break.
sales = sales.copy()
sales["line_revenue"] = sales["quantity"] * sales["unit_price"]

result = (
    sales.groupby("category")
    .agg(
        order_count=("order_id", "count"),
        total_units=("quantity", "sum"),
        total_revenue=("line_revenue", "sum"),
    )
    .reset_index()
)
result["total_revenue"] = result["total_revenue"].round(2)
result = result.sort_values(
    ["total_revenue", "category"], ascending=[False, True]
).reset_index(drop=True)

print(result.to_csv(index=False), end="")
