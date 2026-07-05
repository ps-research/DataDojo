import { Problem } from "../models/Problem.js";
import { Submission } from "../models/Submission.js";
import { ApiError, asyncHandler } from "../middleware/error.js";

export const listProblems = asyncHandler(async (req, res) => {
  const { difficulty, category, concept, q } = req.query;
  const filter = {};
  if (difficulty) filter.difficulty = difficulty;
  if (category) filter.category = category;
  if (concept) filter.concepts = concept;
  if (q) filter.title = { $regex: String(q), $options: "i" };

  const problems = await Problem.find(filter).sort({ number: 1 }).lean();

  // annotate solved state for the authenticated user
  let solvedSlugs = new Set();
  if (req.userId) {
    const solved = await Submission.find({ user: req.userId, verdict: "AC" }).distinct("problemSlug");
    solvedSlugs = new Set(solved);
  }
  res.json({
    problems: problems.map((p) => ({
      slug: p.slug,
      number: p.number,
      title: p.title,
      difficulty: p.difficulty,
      category: p.category,
      concepts: p.concepts,
      engines: (p.engines || []).map((e) => e.engine),
      points: p.points,
      solved: solvedSlugs.has(p.slug),
    })),
  });
});

export const getProblem = asyncHandler(async (req, res) => {
  const p = await Problem.findOne({ slug: req.params.slug }).lean();
  if (!p) throw new ApiError(404, "Problem not found");
  // never leak reference solutions or hidden fixture internals to the client
  res.json({
    problem: {
      slug: p.slug,
      number: p.number,
      title: p.title,
      statementMd: p.statementMd,
      difficulty: p.difficulty,
      category: p.category,
      concepts: p.concepts,
      tags: p.tags,
      schemaPreview: p.schemaPreview,
      orderMatters: p.orderMatters,
      points: p.points,
      engines: (p.engines || []).map((e) => ({ engine: e.engine, starterCode: e.starterCode })),
    },
  });
});
