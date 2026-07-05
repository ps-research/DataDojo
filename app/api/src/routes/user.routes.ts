import { Router } from "express";
import { z } from "zod";
import { User } from "../models/User.js";
import { Problem } from "../models/Problem.js";
import { Submission } from "../models/Submission.js";
import { UserProblemState } from "../models/UserProblemState.js";
import { ApiError, asyncHandler } from "../middleware/error.js";
import { requireAuth, type AuthedRequest } from "../middleware/auth.js";

const router = Router();
const BELTS = ["white", "blue", "purple", "black", "red"];

// Analytics for the profile panel.
router.get(
  "/me/stats",
  requireAuth,
  asyncHandler(async (req: AuthedRequest, res) => {
    const user = await User.findById(req.userId);
    if (!user) throw new ApiError(404, "User not found");

    const solvedSlugs = await UserProblemState.find({ user: req.userId, state: "solved" }).distinct("problemSlug");
    const solvedProblems = await Problem.find({ slug: { $in: solvedSlugs } }).select("belt");
    const totals = await Problem.aggregate([{ $group: { _id: "$belt", n: { $sum: 1 } } }]);

    const solvedByBelt: Record<string, number> = {};
    const totalByBelt: Record<string, number> = {};
    for (const b of BELTS) {
      solvedByBelt[b] = 0;
      totalByBelt[b] = 0;
    }
    for (const p of solvedProblems) solvedByBelt[p.belt] = (solvedByBelt[p.belt] ?? 0) + 1;
    for (const t of totals) totalByBelt[t._id] = t.n;

    const [totalSubs, acSubs] = await Promise.all([
      Submission.countDocuments({ user: req.userId }),
      Submission.countDocuments({ user: req.userId, verdict: "AC" }),
    ]);
    const verdictAgg = await Submission.aggregate([
      { $match: { user: user._id } },
      { $group: { _id: "$verdict", n: { $sum: 1 } } },
    ]);
    const verdictCounts: Record<string, number> = {};
    for (const v of verdictAgg) if (v._id) verdictCounts[v._id] = v.n;

    const recent = await Submission.find({ user: req.userId }).sort({ createdAt: -1 }).limit(12);
    const langAgg = await Submission.aggregate([
      { $match: { user: user._id } },
      { $group: { _id: "$engine", n: { $sum: 1 } } },
      { $sort: { n: -1 } },
    ]);

    res.json({
      user: user.toPublic(),
      solvedByBelt,
      totalByBelt,
      totalSolved: solvedSlugs.length,
      totalSubmissions: totalSubs,
      acSubmissions: acSubs,
      acRate: totalSubs ? Math.round((acSubs / totalSubs) * 100) : 0,
      verdictCounts,
      languages: langAgg.map((l) => ({ engine: l._id, count: l.n })),
      recent: recent.map((s) => ({
        problemSlug: s.problemSlug,
        engine: s.engine,
        verdict: s.verdict ?? null,
        runtimeMs: s.runtimeMs,
        createdAt: s.createdAt,
      })),
    });
  })
);

const profileSchema = z.object({ name: z.string().min(1, "Name is required").max(60) });
router.put(
  "/me",
  requireAuth,
  asyncHandler(async (req: AuthedRequest, res) => {
    const { name } = profileSchema.parse(req.body);
    const user = await User.findByIdAndUpdate(req.userId, { name }, { new: true });
    if (!user) throw new ApiError(404, "User not found");
    res.json({ user: user.toPublic() });
  })
);

const passwordSchema = z.object({
  currentPassword: z.string().min(1),
  newPassword: z.string().min(8, "New password must be at least 8 characters"),
});
router.put(
  "/me/password",
  requireAuth,
  asyncHandler(async (req: AuthedRequest, res) => {
    const { currentPassword, newPassword } = passwordSchema.parse(req.body);
    const user = await User.findById(req.userId);
    if (!user) throw new ApiError(404, "User not found");
    if (!(await user.verifyPassword(currentPassword))) throw new ApiError(401, "Current password is incorrect");
    await user.setPassword(newPassword);
    await user.save();
    res.json({ ok: true });
  })
);

export default router;
