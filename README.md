# DataDojo

**The training ground for data skills.** An Online Judge built for data roles — business analysts, data analysts, data engineers, and data scientists — where you solve real analytical problems in SQL (SQLite, DuckDB, PostgreSQL, MySQL/MariaDB) and Python/pandas, judged automatically against hidden test cases.

## Why

Practice platforms for *data* work are scarce and paywalled: LeetCode locks most of its database problems behind premium; the free tier is ~50 problems. DataDojo closes that gap with an open, curriculum-driven problem set.

## The learning spine (not vibes)

Every problem traces to an authoritative source:

- **SQL Cookbook, 2nd Ed.** (Molinaro & de Graaf, O'Reilly 2020) — 14 chapters / 164 recipes form the skill tree, from `SELECT` fundamentals to window functions, gaps-and-islands, pivots, and recursive CTEs.
- **PostgreSQL official documentation** — the authority for correctness, linked per-concept in each problem's Learn panel.

Content flows through a 5-layer knowledge base (`kb/`): **bronze** (verbatim extraction with sha256 provenance) → **silver** (parsed recipes/solutions/datasets) → **semantic** (concept prerequisite DAG) → **verification** (every solution executed on every target engine — ground truth, no trust) → **gold** (OJ-ready problems with auto-computed hidden tests).

## Stack

MERN: MongoDB (Mongoose) · Express · React (Vite, Tailwind, Monaco) · Node.
Judge engines: SQLite & DuckDB in-process; PostgreSQL & MySQL servers; Python/pandas sandboxed subprocess.

## Repository layout

```
kb/            knowledge-base pipeline (Python) + datadojo_kb.sqlite artifact
  pipeline/    numbered, idempotent ETL stages with integrity reports
  reports/     per-stage run reports (counts, exceptions)
app/           MERN application (api/ + web/)
Resources/     source corpora (not committed)
```
