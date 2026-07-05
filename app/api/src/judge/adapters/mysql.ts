import mysql from "mysql2/promise";
import { env } from "../../config/env.js";
import { splitStatements } from "../sql-split.js";
import type { EngineAdapter, RunResult } from "../../types.js";

// Each run gets a throwaway schema (judge_<random>) dropped afterwards, so DDL
// in fixtures is fully isolated. max_execution_time caps SELECTs; a session
// kill via a second connection handles non-SELECT runaways.

let pool: mysql.Pool | null = null;
function getPool(): mysql.Pool {
  if (!pool) {
    pool = mysql.createPool({
      socketPath: env.engines.mysql.socketPath,
      user: env.engines.mysql.user,
      multipleStatements: false,
      rowsAsArray: true,
      connectionLimit: 4,
    });
  }
  return pool;
}

export const mysqlAdapter: EngineAdapter = {
  name: "mysql",
  async available() {
    try {
      const c = await getPool().getConnection();
      c.release();
      return true;
    } catch {
      return false;
    }
  },
  async run(fixture, code, timeoutMs): Promise<RunResult> {
    const schema = `judge_${Math.random().toString(36).slice(2, 10)}`;
    let conn: mysql.PoolConnection;
    try {
      conn = await getPool().getConnection();
    } catch (e) {
      return { ok: false, error: `mysql unavailable: ${(e as Error).message}` };
    }
    const killer = setTimeout(() => {
      // out-of-band kill for statements max_execution_time cannot stop
      void getPool()
        .query(`KILL QUERY ${conn.threadId}`)
        .catch(() => {});
    }, timeoutMs + 500);
    try {
      await conn.query(`CREATE DATABASE ${schema}`);
      await conn.query(`USE ${schema}`);
      await conn.query(`SET SESSION max_execution_time = ${Math.max(1, timeoutMs)}`);
      for (const stmt of splitStatements(fixture)) await conn.query(stmt);
      let result: { columns: string[]; rows: unknown[][] } = { columns: [], rows: [] };
      for (const stmt of splitStatements(code)) {
        const [rows, fields] = await conn.query(stmt);
        if (Array.isArray(fields) && fields.length > 0) {
          result = { columns: fields.map((f) => f.name), rows: rows as unknown[][] };
        }
      }
      return { ok: true, result };
    } catch (e) {
      const err = e as { code?: string; errno?: number; message?: string };
      if (err.errno === 3024 || err.errno === 1317) return { ok: false, timeout: true };
      return { ok: false, error: String(err.message ?? e).slice(0, 500) };
    } finally {
      clearTimeout(killer);
      try {
        await conn!.query(`DROP DATABASE IF EXISTS ${schema}`);
      } catch {
        /* best effort */
      }
      conn!.release();
    }
  },
};
