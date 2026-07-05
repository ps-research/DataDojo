import { Router } from "express";
import { z } from "zod";
import { Problem } from "../models/Problem.js";
import { Submission } from "../models/Submission.js";
import { UserProblemState } from "../models/UserProblemState.js";
import { ApiError, asyncHandler } from "../middleware/error.js";
import { requireAuth, type AuthedRequest } from "../middleware/auth.js";
import { judgeQueue, verdictChannel } from "../queue/index.js";
import { makeRedis, redis } from "../config/db.js";
import { engineAvailable, getAdapter } from "../judge/registry.js";
import { env } from "../config/env.js";
import { ENGINES } from "../types.js";

const router = Router();

const submitSchema = z.object({
  slug: z.string().min(1),
  engine: z.enum(ENGINES),
  code: z.string().min(1, "Code is required").max(20000, "Code too long (20 KB max)"),
});

router.post(
  "/",
  requireAuth,
  asyncHandler(async (req: AuthedRequest, res) => {
    const { slug, engine, code } = submitSchema.parse(req.body);

    // L2 rate limit: 30 submissions per minute per user
    const rlKey = `rl:sub:${req.userId}`;
    const count = await redis.incr(rlKey);
    if (count === 1) await redis.expire(rlKey, 60);
    if (count > 30) throw new ApiError(429, "Rate limit: max 30 submissions per minute");

    const problem = await Problem.findOne({ slug });
    if (!problem) throw new ApiError(404, "Problem not found");
    const variant = problem.engines.find((e) => e.engine === engine);
    if (!variant) throw new ApiError(400, `This problem does not support ${engine}`);
    if (!engineAvailable(engine)) throw new ApiError(503, `Engine ${engine} is currently unavailable`);

    if (problem.prerequisites.length > 0) {
      const solvedCount = await UserProblemState.countDocuments({
        user: req.userId,
        problemSlug: { $in: problem.prerequisites },
        state: "solved",
      });
      if (solvedCount < problem.prerequisites.length)
        throw new ApiError(423, "Problem is locked - solve its prerequisites first");
    }

    const sub = await Submission.create({
      user: req.userId,
      problem: problem._id,
      problemSlug: slug,
      engine,
      code,
      status: "queued",
    });
    await judgeQueue.add("judge", { submissionId: String(sub._id) }, { removeOnComplete: 100, removeOnFail: 100 });
    res.status(202).json({ id: String(sub._id), status: "queued" });
  })
);

// Run (not judged): execute the user's code against the sample fixture, or a
// custom fixture the user supplies, and return the result table so they can
// iterate before submitting.
const runSchema = z.object({
  slug: z.string().min(1),
  engine: z.enum(ENGINES),
  code: z.string().min(1).max(20000),
  customFixture: z.string().max(50000).optional(),
});

router.post(
  "/run",
  requireAuth,
  asyncHandler(async (req: AuthedRequest, res) => {
    const { slug, engine, code, customFixture } = runSchema.parse(req.body);
    const rlKey = `rl:run:${req.userId}`;
    const count = await redis.incr(rlKey);
    if (count === 1) await redis.expire(rlKey, 60);
    if (count > 40) throw new ApiError(429, "Slow down a moment before running again.");

    const problem = await Problem.findOne({ slug });
    if (!problem) throw new ApiError(404, "Problem not found");
    const variant = problem.engines.find((e) => e.engine === engine);
    if (!variant) throw new ApiError(400, `This problem does not support ${engine}`);
    if (!engineAvailable(engine)) throw new ApiError(503, `Engine ${engine} is currently unavailable`);

    const fixture = customFixture && customFixture.trim() ? customFixture : variant.fixtureSql;
    const t0 = Date.now();
    const result = await getAdapter(engine).run(fixture, code, env.judgeTimeoutMs);
    const runtimeMs = Date.now() - t0;

    if (result.ok) {
      const rows = result.result.rows;
      res.json({
        ok: true,
        columns: result.result.columns,
        rows: rows.slice(0, 200),
        truncated: rows.length > 200,
        rowCount: rows.length,
        runtimeMs,
      });
    } else if (result.timeout) {
      res.json({ ok: false, error: `Time limit exceeded (${env.judgeTimeoutMs} ms).`, runtimeMs });
    } else {
      res.json({ ok: false, error: result.error, runtimeMs });
    }
  })
);

router.get(
  "/:id",
  requireAuth,
  asyncHandler(async (req: AuthedRequest, res) => {
    const sub = await Submission.findById(req.params.id);
    if (!sub || String(sub.user) !== req.userId) throw new ApiError(404, "Submission not found");
    res.json({
      submission: {
        id: String(sub._id),
        problemSlug: sub.problemSlug,
        engine: sub.engine,
        status: sub.status,
        verdict: sub.verdict ?? null,
        message: sub.message,
        runtimeMs: sub.runtimeMs,
        rowsReturned: sub.rowsReturned,
        testsPassed: sub.testsPassed,
        testsTotal: sub.testsTotal,
        createdAt: sub.createdAt,
      },
    });
  })
);

// SSE verdict stream: one-shot - closes after the verdict arrives.
router.get(
  "/:id/stream",
  requireAuth,
  asyncHandler(async (req: AuthedRequest, res) => {
    const sub = await Submission.findById(req.params.id);
    if (!sub || String(sub.user) !== req.userId) throw new ApiError(404, "Submission not found");

    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");
    res.flushHeaders();

    if (sub.status === "done") {
      res.write(
        `data: ${JSON.stringify({ id: String(sub._id), status: "done", verdict: sub.verdict, message: sub.message, runtimeMs: sub.runtimeMs, testsPassed: sub.testsPassed, testsTotal: sub.testsTotal })}\n\n`
      );
      res.end();
      return;
    }

    const subscriber = makeRedis();
    const channel = verdictChannel(String(sub._id));
    await subscriber.subscribe(channel);
    const heartbeat = setInterval(() => res.write(": ping\n\n"), 15000);
    const cleanup = () => {
      clearInterval(heartbeat);
      void subscriber.unsubscribe(channel).then(() => subscriber.quit());
    };
    subscriber.on("message", (_ch, message) => {
      res.write(`data: ${message}\n\n`);
      cleanup();
      res.end();
    });
    req.on("close", cleanup);
  })
);

router.get(
  "/",
  requireAuth,
  asyncHandler(async (req: AuthedRequest, res) => {
    const { problem } = req.query as Record<string, string | undefined>;
    const filter: Record<string, unknown> = { user: req.userId };
    if (problem) filter.problemSlug = problem;
    const subs = await Submission.find(filter).sort({ createdAt: -1 }).limit(50);
    res.json({
      submissions: subs.map((s) => ({
        id: String(s._id),
        problemSlug: s.problemSlug,
        engine: s.engine,
        status: s.status,
        verdict: s.verdict ?? null,
        runtimeMs: s.runtimeMs,
        createdAt: s.createdAt,
      })),
    });
  })
);

export default router;
