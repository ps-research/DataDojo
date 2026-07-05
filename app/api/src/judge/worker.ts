// Worker thread for in-process engines (sqlite, duckdb): the parent enforces
// wall-clock TLE by terminating this thread, which safely kills a runaway query
// without destabilizing the API event loop.
import { parentPort, workerData } from "worker_threads";
import { splitStatements } from "./sql-split.js";
import type { ResultSet } from "../types.js";

interface WorkerInput {
  engine: "sqlite" | "duckdb";
  fixture: string;
  code: string;
}

async function runSqlite(fixture: string, code: string): Promise<ResultSet> {
  const { default: Database } = await import("better-sqlite3");
  const db = new Database(":memory:");
  try {
    db.pragma("trusted_schema = OFF");
    if (fixture.trim()) db.exec(fixture);
    let result: ResultSet = { columns: [], rows: [] };
    for (const stmt of splitStatements(code)) {
      const prepared = db.prepare(stmt);
      if (prepared.reader) {
        const columns = prepared.columns().map((c) => c.name);
        const raw = prepared.raw(true).all() as unknown[][];
        result = { columns, rows: raw };
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

async function runDuckdb(fixture: string, code: string): Promise<ResultSet> {
  const { DuckDBInstance } = await import("@duckdb/node-api");
  const instance = await DuckDBInstance.create(":memory:");
  const conn = await instance.connect();
  try {
    for (const stmt of splitStatements(fixture)) await conn.run(stmt);
    let result: ResultSet = { columns: [], rows: [] };
    for (const stmt of splitStatements(code)) {
      const reader = await conn.runAndReadAll(stmt);
      const columns = reader.columnNames();
      if (columns.length > 0) {
        result = { columns, rows: reader.getRows() as unknown[][] };
      }
    }
    return result;
  } finally {
    conn.closeSync();
    instance.closeSync();
  }
}

(async () => {
  const { engine, fixture, code } = workerData as WorkerInput;
  try {
    const result = engine === "sqlite" ? await runSqlite(fixture, code) : await runDuckdb(fixture, code);
    // BigInt/Date cannot cross the thread boundary via postMessage cloning of
    // arbitrary types reliably in all cases — stringify defensively.
    parentPort!.postMessage({
      ok: true,
      result: {
        columns: result.columns,
        rows: result.rows.map((r) =>
          r.map((v) => (typeof v === "bigint" ? v.toString() : v instanceof Date ? v.toISOString() : v))
        ),
      },
    });
  } catch (err) {
    parentPort!.postMessage({ ok: false, error: String((err as Error).message ?? err) });
  }
})();
