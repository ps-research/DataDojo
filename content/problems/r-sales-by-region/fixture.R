# Fixture: regional sales line items (in-memory, deterministic).
# The data frame `sales` is already loaded for you.
set.seed(101)
regions <- c("North", "South", "East", "West", "Central")
n <- 200
sales <- data.frame(
  region  = sample(regions, n, replace = TRUE),
  product = paste0("SKU-", sample(1:40, n, replace = TRUE)),
  units   = sample(1:20, n, replace = TRUE),
  revenue = round(runif(n, 5, 500), 2),
  stringsAsFactors = FALSE
)
