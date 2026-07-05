import { spawn } from "child_process";
import path from "path";
import { env } from "../config/env.js";
import { ApiError } from "../middleware/error.js";

// The single Gemini call lives in a small Python helper (matches the requested
// SDK/signature). This module handles key rotation across the 5 free-tier keys:
// round-robin start, advance to the next key on quota exhaustion.

interface HelperResult {
  ok: boolean;
  hint?: string;
  quota?: boolean;
  error?: string;
}

const helperPath = () => path.resolve(process.cwd(), "ai/gemini_hint.py");
let keyPointer = 0;

function callHelper(apiKey: string, system: string, prompt: string): Promise<HelperResult> {
  return new Promise((resolve) => {
    const child = spawn(env.engines.pythonBin, [helperPath()], {
      timeout: 45000,
      killSignal: "SIGKILL",
      env: { PATH: process.env.PATH ?? "", HOME: "/tmp" },
    });
    let out = "";
    let err = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (err += d));
    child.on("error", (e) => resolve({ ok: false, error: String(e.message) }));
    child.on("close", () => {
      try {
        resolve(JSON.parse(out.trim()) as HelperResult);
      } catch {
        resolve({ ok: false, error: (err || "hint helper failed").slice(0, 200) });
      }
    });
    child.stdin.write(JSON.stringify({ api_key: apiKey, model: env.gemini.model, system, prompt }));
    child.stdin.end();
  });
}

export function aiConfigured(): boolean {
  return env.gemini.keys.length > 0;
}

export async function generateHint(system: string, prompt: string): Promise<string> {
  const keys = env.gemini.keys;
  if (!keys.length) throw new ApiError(503, "AI hints are not enabled.");
  const start = keyPointer++ % keys.length;
  for (let i = 0; i < keys.length; i++) {
    const result = await callHelper(keys[(start + i) % keys.length], system, prompt);
    if (result.ok && result.hint) return result.hint;
    // On a quota error, move to the next key; on any other error, also try the
    // next key (a transient 500 on one key should not fail the whole request).
  }
  throw new ApiError(503, "The hint service is busy right now. Please try again in a minute.");
}
