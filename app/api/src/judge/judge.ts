import { getAdapter } from "./registry.js";
import { resultsEqual } from "./normalize.js";
import { env } from "../config/env.js";
import type { EngineVariant } from "../models/Problem.js";
import type { JudgeOutcome } from "../types.js";

// CE vs RE: syntax-class failures read as "your code didn't parse/resolve",
// runtime-class as "it ran and blew up". Patterns documented per engine family.
const SYNTAX_ERROR = /syntax error|parse error|unrecognized token|no such (table|column|function)|does not exist|unknown column|invalid column|incorrect syntax|near "/i;

export async function judgeSubmission(
  variant: EngineVariant,
  userCode: string,
  orderMatters: boolean
): Promise<JudgeOutcome> {
  const adapter = getAdapter(variant.engine);
  const timeoutMs = variant.timeoutMs > 0 ? variant.timeoutMs : env.judgeTimeoutMs;

  const expected = await adapter.run(variant.fixtureSql, variant.referenceSolution, Math.max(timeoutMs * 2, 15000));
  if (!expected.ok) {
    console.error(`[judge] reference failed for engine=${variant.engine}:`, "error" in expected ? expected.error : "timeout");
    return {
      verdict: "RE",
      message: "Judge configuration error — this is on us, not you. The problem has been flagged.",
      runtimeMs: 0,
      rowsReturned: 0,
    };
  }

  const t0 = Date.now();
  const actual = await adapter.run(variant.fixtureSql, userCode, timeoutMs);
  const runtimeMs = Date.now() - t0;

  if (!actual.ok) {
    if (actual.timeout) {
      return { verdict: "TLE", message: `Time limit exceeded (${timeoutMs} ms).`, runtimeMs, rowsReturned: 0 };
    }
    const verdict = SYNTAX_ERROR.test(actual.error) ? "CE" : "RE";
    return { verdict, message: actual.error, runtimeMs, rowsReturned: 0 };
  }

  if (expected.result.columns.length !== actual.result.columns.length) {
    return {
      verdict: "WA",
      message: `Expected ${expected.result.columns.length} column(s), your query returned ${actual.result.columns.length}.`,
      runtimeMs,
      rowsReturned: actual.result.rows.length,
    };
  }

  const pass = resultsEqual(expected.result, actual.result, orderMatters);
  return {
    verdict: pass ? "AC" : "WA",
    message: pass
      ? "Accepted — all checks passed."
      : expected.result.rows.length === actual.result.rows.length
        ? `Wrong answer — row count matches (${actual.result.rows.length}) but values differ.`
        : `Wrong answer — expected ${expected.result.rows.length} row(s), got ${actual.result.rows.length}.`,
    runtimeMs,
    rowsReturned: actual.result.rows.length,
  };
}
