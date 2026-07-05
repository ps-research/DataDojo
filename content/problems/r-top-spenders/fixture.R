# Fixture: customers and their orders (in-memory, deterministic).
# The data frames `customers` and `orders` are already loaded for you.
set.seed(202)
n_cust <- 60
customers <- data.frame(
  customer_id = 1:n_cust,
  name = paste0("Customer_", 1:n_cust),
  city = sample(c("Denver", "Austin", "Miami", "Seattle", "Boston"), n_cust, replace = TRUE),
  stringsAsFactors = FALSE
)
n_ord <- 250
orders <- data.frame(
  order_id = 1:n_ord,
  customer_id = sample(1:n_cust, n_ord, replace = TRUE),
  amount = round(runif(n_ord, 10, 400), 2),
  stringsAsFactors = FALSE
)
