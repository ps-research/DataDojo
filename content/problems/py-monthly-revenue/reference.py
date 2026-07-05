# Monthly revenue with a running cumulative total.
# Resample to calendar-month buckets so that a month with no transactions still
# appears as a zero row, then accumulate revenue across months in order.
tx = transactions.copy()
tx["ts"] = pd.to_datetime(tx["ts"])
tx = tx.set_index("ts").sort_index()

monthly = tx["amount"].resample("MS").agg(["sum", "count"])
monthly.columns = ["revenue", "txn_count"]
monthly = monthly.reset_index()

monthly["month"] = monthly["ts"].dt.to_period("M").astype(str)
monthly["revenue"] = monthly["revenue"].round(2)
monthly["txn_count"] = monthly["txn_count"].astype(int)
monthly["cumulative_revenue"] = monthly["revenue"].cumsum().round(2)

result = monthly[["month", "revenue", "txn_count", "cumulative_revenue"]]
print(result.to_csv(index=False), end="")
