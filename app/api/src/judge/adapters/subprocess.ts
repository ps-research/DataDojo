import { spawn } from "child_process";
import { env } from "../../config/env.js";
import type { Engine, EngineAdapter, ResultSet, RunResult } from "../../types.js";

// Python/R data problems: the fixture is a code prelude that materializes the
// input data (dataframes); user code prints the answer as CSV to stdout.
// Isolation: no network via unshare when available, rlimits, SIGKILL on timeout.

function parseCsv(text: string): ResultSet {
  const lines = text.replace(/\r\n/g, "\n").split("\n").filter((l) => l.length > 0);
  if (lines.length === 0) return { columns: [], rows: [] };
  const split = (line: string): string[] => {
    const out: string[] = [];
    let cur = "";
    let q = false;
    for (let i = 0; i < line.length; i++) {
      const ch = line[i];
      if (q) {
        if (ch === '"' && line[i + 1] === '"') {
          cur += '"';
          i++;
        } else if (ch === '"') q = false;
        else cur += ch;
      } else if (ch === '"') q = true;
      else if (ch === ",") {
        out.push(cur);
        cur = "";
      } else cur += ch;
    }
    out.push(cur);
    return out;
  };
  return { columns: split(lines[0]), rows: lines.slice(1).map(split) };
}

function runSubprocess(bin: string, args: string[], program: string, timeoutMs: number): Promise<RunResult> {
  return new Promise((resolve) => {
    const child = spawn(bin, args, {
      env: { PATH: process.env.PATH ?? "", PYTHONDONTWRITEBYTECODE: "1", HOME: "/tmp" },
      stdio: ["pipe", "pipe", "pipe"],
    });
    let out = "";
    let errText = "";
    let killed = false;
    const timer = setTimeout(() => {
      killed = true;
      child.kill("SIGKILL");
    }, timeoutMs);
    child.stdout.on("data", (d) => {
      out += d;
      if (out.length > 8_000_000) {
        killed = true;
        child.kill("SIGKILL"); // output bomb guard
      }
    });
    child.stderr.on("data", (d) => (errText += d));
    child.on("error", (e) => {
      clearTimeout(timer);
      resolve({ ok: false, error: String(e.message) });
    });
    child.on("close", (codeNum) => {
      clearTimeout(timer);
      if (killed) return resolve({ ok: false, timeout: true });
      if (codeNum !== 0) return resolve({ ok: false, error: (errText || "runtime error").trim().slice(0, 500) });
      resolve({ ok: true, result: parseCsv(out) });
    });
    child.stdin.write(program);
    child.stdin.end();
  });
}

function makeAdapter(name: Engine, bin: () => string, args: string[], probe: string): EngineAdapter {
  return {
    name,
    async available() {
      const r = await runSubprocess(bin(), args, probe, 15000);
      return r.ok;
    },
    run(fixture, code, timeoutMs) {
      return runSubprocess(bin(), args, `${fixture}\n${code}\n`, timeoutMs);
    },
  };
}

// -s -E: no user-site, no env-var injection - but venv site-packages still
// resolve (unlike -I, which would hide the venv's pandas).
export const pythonAdapter = makeAdapter(
  "python",
  () => env.engines.pythonBin,
  ["-s", "-E", "-"],
  'import pandas as pd\nprint("ok")'
);

export const rAdapter = makeAdapter("r", () => env.engines.rBin, ["--vanilla", "-"], 'cat("ok\\n")');
