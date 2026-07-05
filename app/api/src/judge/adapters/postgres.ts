import pg from "pg";
import { env } from "../../config/env.js";
import type { EngineAdapter, RunResult } from "../../types.js";

// Every run: one transaction, always rolled back; statement_timeout yields TLE.
// pg returns dates/numerics as strings by default in many cases - the
// normalizer handles unification, so we pass values through untouched.

let pool: pg.Pool | null = null;
function getPool(): pg.Pool {
  if (!pool) pool = new pg.Pool({ connectionString: env.engines.pgUrl, max: 4 });
  return pool;
}

export const postgresAdapter: EngineAdapter = {
  name: "postgres",
  async available() {
    try {
      const c = await getPool().connect();
      c.release();
      return true;
    } catch {
      return false;
    }
  },
  async run(fixture, code, timeoutMs): Promise<RunResult> {
    let client: pg.PoolClient;
    try {
      client = await getPool().connect();
    } catch (e) {
      return { ok: false, error: `postgres unavailable: ${(e as Error).message}` };
    }
    try {
      await client.query("BEGIN");
      await client.query(`SET LOCAL statement_timeout = ${Math.max(1, timeoutMs)}`);
      // Fixture DDL goes to the session-private temp schema: isolated from any
      // pre-existing public tables, auto-dropped, and invisible to other runs.
      await client.query("SET LOCAL search_path = pg_temp");
      if (fixture.trim()) await client.query(fixture);
      const res = await client.query({ text: code, rowMode: "array" });
      const results = (Array.isArray(res) ? res : [res]) as pg.QueryArrayResult[];
      const last = results[results.length - 1];
      const columns = (last.fields ?? []).map((f: pg.FieldDef) => f.name);
      return { ok: true, result: { columns, rows: (last.rows ?? []) as unknown[][] } };
    } catch (e) {
      const err = e as { code?: string; message?: string };
      if (err.code === "57014") return { ok: false, timeout: true };
      return { ok: false, error: String(err.message ?? e).slice(0, 500) };
    } finally {
      try {
        await client!.query("ROLLBACK");
      } catch {
        /* connection died mid-run */
      }
      client!.release();
    }
  },
};
