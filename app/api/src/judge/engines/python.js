// Python/pandas judge engine. The problem's `fixtureSql` field carries a Python
// prelude that defines the input data (e.g. pandas DataFrames). User (and
// reference) code uses those and prints the answer as CSV to stdout. We parse
// stdout into { columns, rows } for uniform comparison. Executed in a sandboxed
// subprocess with a hard timeout and no network.
import { spawn } from "child_process";
import { env } from "../../config/env.js";

function parseCsv(text) {
  const lines = text.replace(/\r\n/g, "\n").trim().split("\n").filter((l) => l.length);
  if (lines.length === 0) return { columns: [], rows: [] };
  const split = (l) => {
    const out = [];
    let cur = "", q = false;
    for (const ch of l) {
      if (q) { if (ch === '"') q = false; else cur += ch; }
      else if (ch === '"') q = true;
      else if (ch === ",") { out.push(cur); cur = ""; }
      else cur += ch;
    }
    out.push(cur);
    return out;
  };
  const columns = split(lines[0]);
  const rows = lines.slice(1).map((l) => split(l));
  return { columns, rows };
}

export function runPython(prelude, code, timeoutMs) {
  const program = `${prelude || ""}\n${code}\n`;
  return new Promise((resolve) => {
    // -I isolated mode; resource limits applied via prlimit if available
    const child = spawn(env.engines.pythonBin, ["-I", "-c", program], {
      timeout: timeoutMs,
      killSignal: "SIGKILL",
      env: { PATH: process.env.PATH, PYTHONDONTWRITEBYTECODE: "1" },
    });
    let out = "", err = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (err += d));
    child.on("error", (e) => resolve({ ok: false, error: String(e.message || e) }));
    child.on("close", (codeNum, signal) => {
      if (signal === "SIGKILL") return resolve({ ok: false, timeout: true });
      if (codeNum !== 0) return resolve({ ok: false, error: (err || "runtime error").trim().slice(0, 400) });
      resolve({ ok: true, result: parseCsv(out) });
    });
  });
}
