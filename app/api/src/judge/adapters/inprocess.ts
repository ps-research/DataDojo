import { Worker } from "worker_threads";
import path from "path";
import { fileURLToPath } from "url";
import type { Engine, EngineAdapter, RunResult } from "../../types.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// tsx runs .ts directly; compiled dist runs .js. Resolve whichever exists.
const workerPath = () => {
  const base = path.join(__dirname, "..", "worker");
  return import.meta.url.endsWith(".ts") ? `${base}.ts` : `${base}.js`;
};

function runInWorker(engine: "sqlite" | "duckdb", fixture: string, code: string, timeoutMs: number): Promise<RunResult> {
  return new Promise((resolve) => {
    let worker: Worker;
    try {
      worker = new Worker(workerPath(), {
        workerData: { engine, fixture, code },
        execArgv: import.meta.url.endsWith(".ts") ? ["--import", "tsx"] : [],
      });
    } catch (err) {
      resolve({ ok: false, error: String((err as Error).message) });
      return;
    }
    let settled = false;
    const finish = (r: RunResult) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      void worker.terminate();
      resolve(r);
    };
    const timer = setTimeout(() => finish({ ok: false, timeout: true }), timeoutMs);
    worker.on("message", (msg: RunResult) => finish(msg));
    worker.on("error", (err) => finish({ ok: false, error: String(err.message ?? err) }));
    worker.on("exit", (codeNum) => {
      if (!settled && codeNum !== 0) finish({ ok: false, error: `worker exited with code ${codeNum}` });
    });
  });
}

function makeInProcessAdapter(name: "sqlite" | "duckdb"): EngineAdapter {
  return {
    name: name as Engine,
    async available() {
      try {
        const probe = await runInWorker(name, "", "SELECT 1 AS ok", 10000);
        return probe.ok;
      } catch {
        return false;
      }
    },
    run(fixture, code, timeoutMs) {
      return runInWorker(name, fixture, code, timeoutMs);
    },
  };
}

export const sqliteAdapter = makeInProcessAdapter("sqlite");
export const duckdbAdapter = makeInProcessAdapter("duckdb");
