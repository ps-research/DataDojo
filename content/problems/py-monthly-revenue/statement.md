# Monthly Revenue and Running Total

The finance team needs a month-by-month revenue trend for the first half of 2024,
including a running cumulative total. The transaction data is already loaded for you
into a pandas DataFrame named `transactions`, with one row per transaction:

| Column | Meaning |
|---|---|
| `txn_id` | unique transaction id |
| `ts` | transaction date, a string like `2024-04-17` |
| `amount` | transaction value |

The rows are not sorted by date.

## Task

Roll the transactions up to **calendar months** over the observed range (the first
month that has any transaction through the last month that has any transaction).
For each month report the revenue, the transaction count, and the cumulative
revenue through that month.

Important: the reporting range is contiguous. If a month inside the range has **no
transactions**, it must still appear as a row with `revenue` of `0.0` and a
`txn_count` of `0`, and it still advances the cumulative total (by adding zero).
Do not silently skip empty months.

## Output columns

Print exactly these columns, in this order:

| # | Column | Meaning |
|---|--------|---------|
| 1 | `month` | the month as a string `YYYY-MM` |
| 2 | `revenue` | sum of `amount` in the month, rounded to 2 decimals |
| 3 | `txn_count` | number of transactions in the month |
| 4 | `cumulative_revenue` | running sum of `revenue` from the first month through this one, rounded to 2 decimals |

**Order matters.** Sort by `month` ascending (chronological).

## Worked example

Suppose transactions fall only in January and March 2024 (nothing in February):

| txn_id | ts | amount |
|---|---|---|
| 1 | 2024-01-10 | 100.00 |
| 2 | 2024-01-22 | 50.00 |
| 3 | 2024-03-05 | 30.00 |

The observed range runs January through March, so February appears as a zero month:

| month | revenue | txn_count | cumulative_revenue |
|---|---|---|---|
| 2024-01 | 150.00 | 2 | 150.00 |
| 2024-02 | 0.0 | 0 | 150.00 |
| 2024-03 | 30.00 | 1 | 180.00 |

The result must be printed as CSV to standard output (a header row followed by the
data rows) and nothing else.
