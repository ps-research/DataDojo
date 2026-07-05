import { Queue, Worker, type ConnectionOptions, type Job } from "bullmq";
import os from "os";
import { makeRedis, redis } from "../config/db.js";
import { Submission } from "../models/Submission.js";
import { Problem } from "../models/Problem.js";
import { User } from "../models/User.js";
import { UserProblemState } from "../models/UserProblemState.js";
import { judgeSubmission } from "../judge/judge.js";

export interface JudgeJobData {
  submissionId: string;
}

const QUEUE_NAME = "judge";

// bullmq bundles its own ioredis type instance; the runtime object is fully
// compatible — cast bridges the duplicate nominal types.
const asConn = (r: ReturnType<typeof makeRedis>) => r as unknown as ConnectionOptions;

export const judgeQueue = new Queue<JudgeJobData, unknown, string>(QUEUE_NAME, {
  connection: asConn(makeRedis()),
});

export function verdictChannel(submissionId: string): string {
  return `verdict:${submissionId}`;
}

// Worker pool runs in-process for the single-box deployment; the queue boundary
// is what lets this move to separate containers without code changes.
export function startJudgeWorker(): Worker<JudgeJobData, unknown, string> {
  const concurrency = Math.max(1, Math.min(os.cpus().length - 1, 3));
  const worker = new Worker<JudgeJobData, unknown, string>(
    QUEUE_NAME,
    async (job: Job<JudgeJobData>) => {
      const sub = await Submission.findById(job.data.submissionId);
      if (!sub) return;
      sub.status = "running";
      await sub.save();

      const problem = await Problem.findById(sub.problem);
      const variant = problem?.engines.find((e) => e.engine === sub.engine);
      if (!problem || !variant) {
        sub.status = "done";
        sub.verdict = "RE";
        sub.message = "Problem or engine variant no longer exists.";
        await sub.save();
        return;
      }

      const outcome = await judgeSubmission(variant, sub.code, problem.orderMatters);
      sub.status = "done";
      sub.verdict = outcome.verdict;
      sub.message = outcome.message;
      sub.runtimeMs = outcome.runtimeMs;
      sub.rowsReturned = outcome.rowsReturned;
      await sub.save();

      if (outcome.verdict === "AC") {
        const prev = await UserProblemState.findOneAndUpdate(
          { user: sub.user, problemSlug: sub.problemSlug },
          { $setOnInsert: { state: "attempted" } },
          { upsert: true, new: false }
        );
        const firstSolve = !prev || prev.state !== "solved";
        if (firstSolve) {
          await UserProblemState.updateOne(
            { user: sub.user, problemSlug: sub.problemSlug },
            { $set: { state: "solved" } }
          );
          await User.updateOne({ _id: sub.user }, { $inc: { solvedCount: 1, score: problem.points } });
          await redis.zincrby("lb:global", problem.points, String(sub.user));
        }
      } else {
        await UserProblemState.updateOne(
          { user: sub.user, problemSlug: sub.problemSlug },
          { $setOnInsert: { state: "attempted" } },
          { upsert: true }
        );
      }

      await redis.publish(
        verdictChannel(String(sub._id)),
        JSON.stringify({
          id: String(sub._id),
          status: "done",
          verdict: sub.verdict,
          message: sub.message,
          runtimeMs: sub.runtimeMs,
        })
      );
    },
    { connection: asConn(makeRedis()), concurrency }
  );
  worker.on("failed", (job, err) => console.error(`[worker] job ${job?.id} failed:`, err.message));
  console.log(`[worker] judge worker started (concurrency ${concurrency})`);
  return worker;
}
