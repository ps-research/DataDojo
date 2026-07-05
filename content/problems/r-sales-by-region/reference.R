# Reference solution. Uses `sales` from the fixture and prints CSV to stdout.
agg <- aggregate(cbind(units, revenue) ~ region, data = sales, FUN = sum)
agg$revenue <- round(agg$revenue, 2)
names(agg) <- c("region", "total_units", "total_revenue")
agg <- agg[order(-agg$total_revenue, agg$region), ]
write.csv(agg, row.names = FALSE)
