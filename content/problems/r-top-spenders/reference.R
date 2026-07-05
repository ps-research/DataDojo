# Reference solution. Uses `customers` and `orders`; prints CSV to stdout.
spend <- aggregate(amount ~ customer_id, data = orders, FUN = sum)
names(spend) <- c("customer_id", "total_spend")
res <- merge(spend, customers[, c("customer_id", "name")], by = "customer_id")
res$total_spend <- round(res$total_spend, 2)
res <- res[order(-res$total_spend, res$customer_id), ]
res <- head(res, 5)
res <- res[, c("customer_id", "name", "total_spend")]
write.csv(res, row.names = FALSE)
