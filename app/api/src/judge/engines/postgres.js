// PostgreSQL judge engine. Each run happens inside a transaction that is always
// rolled back, so problem fixtures (temp tables / inserts) never persist and
// runs are isolated. A per-statement statement_timeout yields TLE.
import pg from "pg";
import { env } from "../../config/env.js";

let pool = null;
function getPool() {
  if (!pool) pool = new pg.Pool({ connectionString: env.engines.postgres, max: 4 });
  return pool;
}

export async function runPostgres(fixtureSql, userSql, timeoutMs) {
  let client;
  try {
    client = await getPool().connect();
  } catch (e) {
    return { ok: false, error: `postgres unavailable: ${e.message}` };
  }
  try {
    await client.query("BEGIN");
    await client.query(`SET LOCAL statement_timeout = ${Math.max(1, timeoutMs)}`);
    if (fixtureSql && fixtureSql.trim()) await client.query(fixtureSql);
    const res = await client.query(userSql);
    const last = Array.isArray(res) ? res[res.length - 1] : res;
    const columns = (last.fields || []).map((f) => f.name);
    const rows = (last.rows || []).map((r) => columns.map((c) => r[c]));
    return { ok: true, result: { columns, rows } };
  } catch (e) {
    if (e.code === "57014") return { ok: false, timeout: true }; // query_canceled
    return { ok: false, error: String(e.message || e).slice(0, 400) };
  } finally {
    try { await client.query("ROLLBACK"); } catch {}
    client.release();
  }
}
