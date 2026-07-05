# Region-by-category revenue matrix.
# Pivot region against category, summing amount, and fill any absent pair with 0.
# Force the full, fixed set of category columns so a category that never sold in a
# region still shows up as a 0 cell. Add a per-region row total.
_cats = ["Apparel", "Electronics", "Home", "Toys"]

pivot = sales.pivot_table(
    index="region",
    columns="category",
    values="amount",
    aggfunc="sum",
    fill_value=0,
)
pivot = pivot.reindex(columns=_cats, fill_value=0).round(2)
pivot["row_total"] = pivot[_cats].sum(axis=1).round(2)

result = pivot.reset_index().sort_values("region").reset_index(drop=True)
result = result[["region"] + _cats + ["row_total"]]
print(result.to_csv(index=False), end="")
