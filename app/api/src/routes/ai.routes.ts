import { Router } from "express";
import { z } from "zod";
import { Problem } from "../models/Problem.js";
import { ApiError, asyncHandler } from "../middleware/error.js";
import { requireAuth, type AuthedRequest } from "../middleware/auth.js";
import { redis } from "../config/db.js";
import { env } from "../config/env.js";
import { engineLabel } from "../judge/labels.js";
import { generateHint, aiConfigured } from "../services/ai-hint.js";
import { ENGINES } from "../types.js";

const router = Router();

const hintSchema = z.object({
  slug: z.string().min(1),
  engine: z.enum(ENGINES),
  code: z.string().max(20000).optional(),
});

const SYSTEM = `You are an expert tutor on DataDojo, an online judge for SQL, pandas, and R.
You will be given a problem, its correct reference solution, and the student's current code.
Your job is to give ONE substantial hint that moves the student meaningfully toward the answer.

Rules:
- Diagnose the specific gap or mistake in the student's code relative to the intended approach.
- Name the concept, clause, or function they are missing, and give a concrete nudge on how to use it.
- Do NOT write the full query or any complete runnable solution.
- Do NOT reveal or paraphrase the reference solution line by line.
- If the student's code is empty, point them at the first concrete step and the key technique.
- Keep it to 2 to 4 sentences, concrete, specific to their code, and encouraging.
- No em dashes.
Respond as JSON: {"response": "<the hint>"}.`;

router.post(
  "/hint",
  requireAuth,
  asyncHandler(async (req: AuthedRequest, res) => {
    if (!aiConfigured()) throw new ApiError(503, "AI hints are not enabled on this server.");
    const { slug, engine, code } = hintSchema.parse(req.body);

    // per-user limit: 10 hints per hour
    const rlKey = `rl:hint:${req.userId}`;
    const used = parseInt((await redis.get(rlKey)) ?? "0", 10);
    if (used >= env.aiHintsPerHour) {
      const ttl = await redis.ttl(rlKey);
      throw new ApiError(429, `You have used all ${env.aiHintsPerHour} hints for this hour. Try again in ${Math.max(1, Math.ceil(ttl / 60))} min.`);
    }

    const problem = await Problem.findOne({ slug });
    if (!problem) throw new ApiError(404, "Problem not found");
    const variant = problem.engines.find((e) => e.engine === engine) ?? problem.engines[0];
    if (!variant) throw new ApiError(400, "No solution reference for this problem");

    const prompt = [
      `Problem (${engineLabel(engine)}):`,
      problem.statementMd.slice(0, 3500),
      "",
      "Correct reference solution (NEVER reveal it; use it only to understand the intended approach):",
      variant.referenceSolution.slice(0, 4000),
      "",
      "The student's current code:",
      (code ?? "").trim() ? code!.slice(0, 4000) : "(empty)",
      "",
      "Give one substantial hint.",
    ].join("\n");

    const hint = await generateHint(SYSTEM, prompt);

    // count only successful hints
    const count = await redis.incr(rlKey);
    if (count === 1) await redis.expire(rlKey, 3600);

    res.json({ hint, remaining: Math.max(0, env.aiHintsPerHour - count) });
  })
);

export default router;
