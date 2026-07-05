import type { Engine, EngineAdapter } from "../types.js";
import { sqliteAdapter, duckdbAdapter } from "./adapters/inprocess.js";
import { postgresAdapter } from "./adapters/postgres.js";
import { mysqlAdapter } from "./adapters/mysql.js";
import { mssqlAdapter } from "./adapters/mssql.js";
import { pythonAdapter, rAdapter } from "./adapters/subprocess.js";

const adapters: Record<Engine, EngineAdapter> = {
  sqlite: sqliteAdapter,
  duckdb: duckdbAdapter,
  postgres: postgresAdapter,
  mysql: mysqlAdapter,
  mssql: mssqlAdapter,
  python: pythonAdapter,
  r: rAdapter,
};

export function getAdapter(engine: Engine): EngineAdapter {
  return adapters[engine];
}

// Probed once at startup; exposed on /api/health for ops and shown in the UI
// so unavailable engines are greyed out rather than failing at submit time.
const availability = new Map<Engine, boolean>();

export async function probeEngines(): Promise<Record<string, boolean>> {
  await Promise.all(
    (Object.keys(adapters) as Engine[]).map(async (e) => {
      try {
        availability.set(e, await adapters[e].available());
      } catch {
        availability.set(e, false);
      }
    })
  );
  return Object.fromEntries(availability);
}

export function engineAvailable(engine: Engine): boolean {
  return availability.get(engine) ?? false;
}

export function availableEngines(): Engine[] {
  return [...availability.entries()].filter(([, ok]) => ok).map(([e]) => e);
}
