import sql from "mssql";
import { env } from "../../config/env.js";
import type { EngineAdapter, RunResult } from "../../types.js";

// T-SQL DDL is transactional: one transaction per run, always rolled back.
// requestTimeout maps to TLE.

let poolPromise: Promise<sql.ConnectionPool> | null = null;
function getPool(): Promise<sql.ConnectionPool> {
  if (poolPromise) return poolPromise;
  const created: Promise<sql.ConnectionPool> = new sql.ConnectionPool({
    server: env.engines.mssql.server,
    port: env.engines.mssql.port,
    user: env.engines.mssql.user,
    password: env.engines.mssql.password,
    database: "tempdb",
    options: { encrypt: false, trustServerCertificate: true },
    pool: { max: 4 },
  }).connect();
  poolPromise = created;
  return created;
}

export const mssqlAdapter: EngineAdapter = {
  name: "mssql",
  async available() {
    try {
      await getPool();
      return true;
    } catch {
      return false;
    }
  },
  async run(fixture, code, timeoutMs): Promise<RunResult> {
    let pool: sql.ConnectionPool;
    try {
      pool = await getPool();
    } catch (e) {
      return { ok: false, error: `mssql unavailable: ${(e as Error).message}` };
    }
    const tx = new sql.Transaction(pool);
    let timer: NodeJS.Timeout | undefined;
    try {
      await tx.begin();
      const req = new sql.Request(tx);
      // arrayRowMode gives us positional rows + column metadata
      (req as unknown as { arrayRowMode: boolean }).arrayRowMode = true;
      // per-request timeout is not in the driver typings; enforce our own
      // wall-clock and cancel the request (surfaces as ECANCEL => TLE)
      timer = setTimeout(() => req.cancel(), Math.max(1, timeoutMs));
      if (fixture.trim()) await req.batch(fixture);
      const res = (await req.batch(code)) as unknown as {
        recordsets: Array<unknown[][] & { columns?: Record<string, { index: number; name: string }> }>;
      };
      const sets = res.recordsets ?? [];
      const lastSet = sets.length > 0 ? sets[sets.length - 1] : undefined;
      const columns: string[] = lastSet?.columns
        ? Object.values(lastSet.columns)
            .sort((a, b) => a.index - b.index)
            .map((c) => c.name)
        : [];
      return { ok: true, result: { columns, rows: (lastSet ?? []) as unknown[][] } };
    } catch (e) {
      const err = e as { code?: string; message?: string };
      if (err.code === "ETIMEOUT" || err.code === "ECANCEL") return { ok: false, timeout: true };
      return { ok: false, error: String(err.message ?? e).slice(0, 500) };
    } finally {
      if (timer) clearTimeout(timer);
      try {
        await tx.rollback();
      } catch {
        /* not begun or already dead */
      }
    }
  },
};
