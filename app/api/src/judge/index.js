import { Worker } from "worker_threads";
import { fileURLToPath } from "url";
import path from "path";
import { compare } from "./normalize.js";
import { runPython } from "./engines/python.js";
import { runPostgres } from "./engines/postgres.js";
import { env } from "../config/env.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WORKER = path.join(__dirname, "worker.js");

const IN_PROCESS_ENGINES = new Set(["sqlite"]);
const ASYNC_ENGINES = { python: runPython, postgres: runPostgres };

// Run an in-process engine inside a worker with a hard timeout.
function runInWorker(engine, fixtureSql, userSql, timeoutMs) {
  return new Promise((resolve) => {
    const worker = new Worker(WORKER, { workerData: { engine, fixtureSql, userSql } });
    let settled = false;
    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      worker.terminate();
      resolve({ ok: false, timeout: true });
    }, timeoutMs);
    worker.on("message", (msg) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      worker.terminate();
      resolve(msg);
    });
    worker.on("error", (err) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve({ ok: false, error: String(err.message || err) });
    });
  });
}

async function runEngine(engine, fixtureSql, code, timeoutMs) {
  if (IN_PROCESS_ENGINES.has(engine)) return runInWorker(engine, fixtureSql, code, timeoutMs);
  const fn = ASYNC_ENGINES[engine];
  if (!fn) return { ok: false, error: `engine not enabled: ${engine}` };
  return fn(fixtureSql, code, timeoutMs);
}

function classifyError(msg) {
  return /syntax|parse|unrecognized|near ".*":|no such (column|table|function)/i.test(msg)
    ? "CE"
    : "RE";
}

/**
 * Judge a submission against one engine variant of a problem.
 * @returns {verdict, message, runtimeMs, rowsReturned}
 */
export async function judge(variant, userCode, orderMatters, timeoutMs = env.judgeTimeoutMs) {
  const { engine, fixtureSql, referenceSolution } = variant;

  // 1. Trusted expected output (reference must succeed; else problem misconfig).
  const expectedRun = await runEngine(engine, fixtureSql, referenceSolution, timeoutMs);
  if (!expectedRun.ok) {
    return {
      verdict: "RE",
      message: "Judge configuration error: reference solution failed to run.",
      runtimeMs: 0,
      rowsReturned: 0,
    };
  }

  // 2. Run the user's code.
  const t0 = Date.now();
  const userRun = await runEngine(engine, fixtureSql, userCode, timeoutMs);
  const runtimeMs = Date.now() - t0;

  if (userRun.timeout) {
    return { verdict: "TLE", message: `Exceeded ${timeoutMs} ms time limit.`, runtimeMs, rowsReturned: 0 };
  }
  if (!userRun.ok) {
    return { verdict: classifyError(userRun.error), message: userRun.error, runtimeMs, rowsReturned: 0 };
  }

  const ok = compare(expectedRun.result, userRun.result, orderMatters);
  return {
    verdict: ok ? "AC" : "WA",
    message: ok
      ? "All test cases passed."
      : `Wrong answer: expected ${expectedRun.result.rows.length} row(s), your query returned ${userRun.result.rows.length}.`,
    runtimeMs,
    rowsReturned: userRun.result.rows.length,
    expectedPreview: ok ? undefined : expectedRun.result,
    actualPreview: ok ? undefined : userRun.result,
  };
}
