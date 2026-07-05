import { Router } from "express";
import { z } from "zod";
import { Problem } from "../models/Problem.js";
import { UserProblemState } from "../models/UserProblemState.js";
import { ApiError, asyncHandler } from "../middleware/error.js";
import { optionalAuth, requireAdmin, requireAuth, type AuthedRequest } from "../middleware/auth.js";
import { redis } from "../config/db.js";
import { engineAvailable } from "../judge/registry.js";

const router = Router();

router.get(
  "/",
  optionalAuth,
  asyncHandler(async (req: AuthedRequest, res) => {
    const { belt, category, universe, concept, q } = req.query as Record<string, string | undefined>;
    const filter: Record<string, unknown> = {};
    if (belt) filter.belt = belt;
    if (category) filter.category = category;
    if (universe) filter.universe = universe;
    if (concept) filter.concepts = concept;
    if (q) filter.title = { $regex: q.slice(0, 60), $options: "i" };

    const cacheKey = `prob:list:${JSON.stringify(filter)}`;
    let items: Record<string, unknown>[];
    const cached = await redis.get(cacheKey);
    if (cached) {
      items = JSON.parse(cached) as Record<string, unknown>[];
    } else {
      const problems = await Problem.find(filter).sort({ number: 1 });
      items = problems.map((p) => p.toListItem());
      await redis.set(cacheKey, JSON.stringify(items), "EX", 60);
    }

    const solved = new Set<string>();
    if (req.userId) {
      const states = await UserProblemState.find({ user: req.userId, state: "solved" }).select("problemSlug");
      for (const s of states) solved.add(s.problemSlug);
    }
    res.json({
      problems: items.map((p) => ({
        ...p,
        solved: solved.has(p.slug as string),
        locked:
          Array.isArray(p.prerequisites) &&
          (p.prerequisites as string[]).length > 0 &&
          !(p.prerequisites as string[]).every((pre) => solved.has(pre)),
      })),
    });
  })
);

router.get(
  "/:slug",
  optionalAuth,
  asyncHandler(async (req: AuthedRequest, res) => {
    const p = await Problem.findOne({ slug: req.params.slug });
    if (!p) throw new ApiError(404, "Problem not found");

    // Ladder rule enforced server-side: locked problems hide their statement.
    if (p.prerequisites.length > 0) {
      const solvedCount = req.userId
        ? await UserProblemState.countDocuments({
            user: req.userId,
            problemSlug: { $in: p.prerequisites },
            state: "solved",
          })
        : 0;
      if (solvedCount < p.prerequisites.length) {
        res.status(423).json({
          error: "This problem is locked",
          prerequisites: p.prerequisites,
          problem: { slug: p.slug, title: p.title, belt: p.belt, universe: p.universe },
        });
        return;
      }
    }

    const client = p.toClient() as { engines: { engine: string; starterCode: string; available?: boolean }[] };
    client.engines = client.engines.map((e) => ({ ...e, available: engineAvailable(e.engine as never) }));
    res.json({ problem: client });
  })
);

const upsertSchema = z.object({ problems: z.array(z.record(z.string(), z.unknown())).min(1) });

router.post(
  "/",
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    const { problems } = upsertSchema.parse(req.body);
    let upserted = 0;
    for (const doc of problems) {
      await Problem.updateOne({ slug: doc.slug }, { $set: doc }, { upsert: true });
      upserted++;
    }
    const keys = await redis.keys("prob:list:*");
    if (keys.length) await redis.del(...keys);
    res.status(201).json({ upserted });
  })
);

export default router;
