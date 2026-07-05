import mongoose from "mongoose";

// A judge-able problem. `engines` lists which SQL dialects/languages it can be
// solved in; each carries its own fixture DDL and a verified reference solution.
// expectedResult is the canonical output computed by executing the reference.
const engineVariantSchema = new mongoose.Schema(
  {
    engine: {
      type: String,
      required: true,
      enum: ["sqlite", "duckdb", "postgres", "mysql", "mssql", "python", "r"],
    },
    fixtureSql: { type: String, default: "" }, // CREATE + INSERT for this problem's tables
    referenceSolution: { type: String, required: true },
    starterCode: { type: String, default: "" },
  },
  { _id: false }
);

const problemSchema = new mongoose.Schema(
  {
    slug: { type: String, required: true, unique: true },
    number: { type: Number, required: true, unique: true },
    title: { type: String, required: true },
    statementMd: { type: String, required: true }, // markdown, authored
    difficulty: {
      type: String,
      enum: ["white", "blue", "purple", "brown", "black"],
      default: "white",
    },
    category: { type: String, default: "sql" }, // sql | python | r
    concepts: [{ type: String }],
    tags: [{ type: String }],
    // The datasets shown to the user (schema + a few example rows), display-only
    schemaPreview: { type: String, default: "" },
    orderMatters: { type: Boolean, default: false }, // does result row order count?
    engines: [engineVariantSchema],
    // provenance back to the KB (recipe id / source), never shown as-is
    provenance: { type: String, default: "" },
    points: { type: Number, default: 10 },
  },
  { timestamps: true }
);

problemSchema.methods.toListItem = function () {
  return {
    slug: this.slug,
    number: this.number,
    title: this.title,
    difficulty: this.difficulty,
    category: this.category,
    concepts: this.concepts,
    engines: this.engines.map((e) => e.engine),
    points: this.points,
  };
};

export const Problem = mongoose.model("Problem", problemSchema);
