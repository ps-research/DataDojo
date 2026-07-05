// Worker thread: runs an in-process judge engine and returns its result set.
// Isolated here so the parent can kill it on timeout (=> TLE) without hanging
// the API event loop.
import { parentPort, workerData } from "worker_threads";
import { runSqlite } from "./engines/sqlite.js";

const IN_PROCESS = {
  sqlite: runSqlite,
  // duckdb added alongside; both are synchronous in-process engines
};

try {
  const { engine, fixtureSql, userSql } = workerData;
  const fn = IN_PROCESS[engine];
  if (!fn) throw new Error(`in-process engine not available: ${engine}`);
  const result = fn(fixtureSql, userSql);
  parentPort.postMessage({ ok: true, result });
} catch (err) {
  parentPort.postMessage({ ok: false, error: String(err.message || err) });
}
