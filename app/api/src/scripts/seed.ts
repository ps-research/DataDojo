// Load content/gold_problems.json (built by content/build_gold.py) into MongoDB.
// Idempotent: upserts by slug. Removes the dev seed problem if present.
import { readFileSync } from "fs";
import path from "path";
import mongoose from "mongoose";
import { connectMongo } from "../config/db.js";
import { Problem } from "../models/Problem.js";

interface GoldProblem {
  slug: string;
  number: number;
  [k: string]: unknown;
}

async function main(): Promise<void> {
  const goldPath =
    process.env.GOLD_PATH ??
    path.resolve(process.cwd(), "../../content/gold_problems.json");
  const gold = JSON.parse(readFileSync(goldPath, "utf8")) as GoldProblem[];
  await connectMongo();

  let upserted = 0;
  for (const p of gold) {
    await Problem.updateOne({ slug: p.slug }, { $set: p }, { upsert: true });
    upserted++;
  }
  await Problem.deleteOne({ slug: "dev-headcount-by-dept" });

  const byBelt = await Problem.aggregate([{ $group: { _id: "$belt", n: { $sum: 1 } } }]);
  console.log(`[seed] upserted ${upserted} problems from ${goldPath}`);
  console.log("[seed] by belt:", Object.fromEntries(byBelt.map((b) => [b._id, b.n])));
  await mongoose.disconnect();
}

main().catch((e) => {
  console.error("[seed] failed:", e);
  process.exit(1);
});
