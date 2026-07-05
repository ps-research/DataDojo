import { getAdapter } from "./registry.js";
import { resultsEqual } from "./normalize.js";
import { env } from "../config/env.js";
import type { EngineVariant } from "../models/Problem.js";
import type { JudgeOutcome } from "../types.js";

const SYNTAX_ERROR = /syntax error|parse error|unrecognized token|no such (table|column|function)|does not exist|unknown column|invalid column|incorrect syntax|near "/i;
const SQL_ENGINES = new Set(["sqlite", "duckdb", "postgres", "mysql", "mssql"]);

/**
 * Judge a submission against every hidden fixture, in order. Returns the first
 * failing verdict (with how many fixtures passed before it) or AC if all pass.
 * SQL problems judge on the big hidden fixtures; python/r judge on their own
 * self-contained fixture (a single test).
 */
export async function judgeSubmission(
  variant: EngineVariant,
  userCode: string,
  orderMatters: boolean,
  hiddenFixtures: string[]
): Promise<JudgeOutcome> {
  const adapter = getAdapter(variant.engine);
  const timeoutMs = variant.timeoutMs > 0 ? variant.timeoutMs : env.judgeTimeoutMs;

  const fixtures =
    SQL_ENGINES.has(variant.engine) && hiddenFixtures.length > 0 ? hiddenFixtures : [variant.fixtureSql];
  const testsTotal = fixtures.length;

  let passed = 0;
  let totalRuntime = 0;
  let rowsReturned = 0;

  for (const fixture of fixtures) {
    const expected = await adapter.run(fixture, variant.referenceSolution, Math.max(timeoutMs * 2, 15000));
    if (!expected.ok) {
      return {
        verdict: "RE",
        message: "Judge configuration error - this is on us, not you. The problem has been flagged.",
        runtimeMs: totalRuntime,
        rowsReturned,
        testsPassed: passed,
        testsTotal,
      };
    }

    const t0 = Date.now();
    const actual = await adapter.run(fixture, userCode, timeoutMs);
    totalRuntime += Date.now() - t0;

    if (!actual.ok) {
      if (actual.timeout) {
        return { verdict: "TLE", message: `Time limit exceeded (${timeoutMs} ms) on test ${passed + 1} of ${testsTotal}.`, runtimeMs: totalRuntime, rowsReturned, testsPassed: passed, testsTotal };
      }
      const verdict = SYNTAX_ERROR.test(actual.error) ? "CE" : "RE";
      return { verdict, message: actual.error, runtimeMs: totalRuntime, rowsReturned, testsPassed: passed, testsTotal };
    }

    rowsReturned = actual.result.rows.length;
    const ok =
      expected.result.columns.length === actual.result.columns.length &&
      resultsEqual(expected.result, actual.result, orderMatters);

    if (!ok) {
      return {
        verdict: "WA",
        message: `Wrong answer on hidden test ${passed + 1} of ${testsTotal}.`,
        runtimeMs: totalRuntime,
        rowsReturned,
        testsPassed: passed,
        testsTotal,
      };
    }
    passed++;
  }

  return {
    verdict: "AC",
    message: `Accepted. Passed all ${testsTotal} hidden test${testsTotal === 1 ? "" : "s"}.`,
    runtimeMs: totalRuntime,
    rowsReturned,
    testsPassed: passed,
    testsTotal,
  };
}
