# Reference solution. Uses `order_items` and `products`; prints CSV to stdout.
min_shipped <- 100

m <- merge(order_items, products[, c("product_id", "category")], by = "product_id")

# Shipped units: delivered and returned lines count; cancelled lines do not.
shipped <- m[m$status %in% c("delivered", "returned"), ]
tot_shipped <- aggregate(quantity ~ category, data = shipped, FUN = sum)
names(tot_shipped) <- c("category", "total_shipped")

# Returned units.
returned <- m[m$status == "returned", ]
tot_returned <- aggregate(quantity ~ category, data = returned, FUN = sum)
names(tot_returned) <- c("category", "total_returned")

# Keep every shipping category even when it has no returns.
res <- merge(tot_shipped, tot_returned, by = "category", all.x = TRUE)
res$total_returned[is.na(res$total_returned)] <- 0

# Only categories with enough shipped volume qualify.
res <- res[res$total_shipped >= min_shipped, ]
res$return_rate <- round(res$total_returned / res$total_shipped, 4)

res <- res[order(-res$return_rate, res$category), ]
res <- res[, c("category", "total_shipped", "total_returned", "return_rate")]
write.csv(res, row.names = FALSE)
