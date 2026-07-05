// Proper display names for the engine dropdown.
export const ENGINE_LABELS: Record<string, string> = {
  sqlite: "SQLite",
  duckdb: "DuckDB",
  postgres: "PostgreSQL",
  mysql: "MySQL",
  mssql: "SQL Server",
  python: "Python (pandas)",
  r: "R (tidyverse)",
};

export function engineLabel(engine: string): string {
  return ENGINE_LABELS[engine] ?? engine;
}
