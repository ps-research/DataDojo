// In-process SQLite judge engine (better-sqlite3). Runs in a worker thread so
// the caller can enforce a hard wall-clock timeout by terminating the worker.
import Database from "better-sqlite3";

export function runSqlite(fixtureSql, userSql) {
  const db = new Database(":memory:");
  try {
    db.pragma("trusted_schema = OFF");
    if (fixtureSql && fixtureSql.trim()) db.exec(fixtureSql);
    // Only the final statement's result set is judged; allow multi-statement setup.
    const statements = splitStatements(userSql);
    if (statements.length === 0) throw new Error("empty submission");
    let result = { columns: [], rows: [] };
    for (const stmt of statements) {
      const prepared = db.prepare(stmt);
      if (prepared.reader) {
        const rows = prepared.all();
        const columns = prepared.columns().map((c) => c.name);
        result = { columns, rows: rows.map((r) => columns.map((c) => r[c])) };
      } else {
        prepared.run();
        result = { columns: [], rows: [] };
      }
    }
    return result;
  } finally {
    db.close();
  }
}

function splitStatements(sql) {
  // naive but adequate: split on ';' not inside quotes
  const out = [];
  let cur = "";
  let quote = null;
  for (const ch of sql) {
    if (quote) {
      cur += ch;
      if (ch === quote) quote = null;
    } else if (ch === "'" || ch === '"') {
      quote = ch;
      cur += ch;
    } else if (ch === ";") {
      if (cur.trim()) out.push(cur.trim());
      cur = "";
    } else {
      cur += ch;
    }
  }
  if (cur.trim()) out.push(cur.trim());
  return out;
}
