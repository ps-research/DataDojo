import { Router } from "express";
import { asyncHandler } from "../middleware/error.js";
import { redis } from "../config/db.js";
import { User } from "../models/User.js";

const router = Router();

router.get(
  "/",
  asyncHandler(async (req, res) => {
    const limit = Math.min(parseInt(String(req.query.limit ?? "50"), 10) || 50, 100);
    const raw = await redis.zrevrange("lb:global", 0, limit - 1, "WITHSCORES");
    const ids: string[] = [];
    const scores = new Map<string, number>();
    for (let i = 0; i < raw.length; i += 2) {
      ids.push(raw[i]);
      scores.set(raw[i], Number(raw[i + 1]));
    }
    const users = await User.find({ _id: { $in: ids } }).select("name solvedCount");
    const byId = new Map(users.map((u) => [String(u._id), u]));
    res.json({
      entries: ids.map((id, idx) => ({
        rank: idx + 1,
        name: byId.get(id)?.name ?? "deleted user",
        solvedCount: byId.get(id)?.solvedCount ?? 0,
        score: scores.get(id) ?? 0,
      })),
    });
  })
);

export default router;
