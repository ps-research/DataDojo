# Fixture: shipment lines and the product catalog (in-memory, deterministic).
# The data frames `order_items` and `products` are already loaded for you.
set.seed(303)
base_cats <- c("Apparel", "Footwear", "Electronics", "Home", "Toys", "Beauty")
n_prod <- 80
products <- data.frame(
  product_id = 1:n_prod,
  product_name = paste0("P", 1:n_prod),
  category = sample(base_cats, n_prod, replace = TRUE),
  stringsAsFactors = FALSE
)
n_items <- 270
order_items <- data.frame(
  order_id = 1:n_items,
  product_id = sample(1:n_prod, n_items, replace = TRUE),
  quantity = sample(1:6, n_items, replace = TRUE),
  status = sample(c("delivered", "returned", "cancelled"), n_items,
                  replace = TRUE, prob = c(0.72, 0.16, 0.12)),
  stringsAsFactors = FALSE
)

# A "Garden" category that ships steadily but is never returned.
garden_products <- data.frame(
  product_id = 81:85,
  product_name = paste0("P", 81:85),
  category = "Garden",
  stringsAsFactors = FALSE
)
products <- rbind(products, garden_products)
garden_items <- data.frame(
  order_id = 271:300,
  product_id = rep(81:85, length.out = 30),
  quantity = c(rep(5, 24), rep(3, 6)),
  status = c(rep("delivered", 24), rep("cancelled", 6)),
  stringsAsFactors = FALSE
)
order_items <- rbind(order_items, garden_items)
