const LABELS: Record<string, string> = {
  sqlite: "SQLite",
  duckdb: "DuckDB",
  postgres: "PostgreSQL",
  mysql: "MySQL",
  mssql: "SQL Server",
  python: "Python (pandas)",
  r: "R",
};

export function engineLabel(engine: string): string {
  return LABELS[engine] ?? engine;
}
