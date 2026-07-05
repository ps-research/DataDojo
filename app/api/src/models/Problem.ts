import mongoose, { Schema, type Document, type Model } from "mongoose";
import type { Belt, Engine } from "../types.js";

export interface EngineVariant {
  engine: Engine;
  fixtureSql: string;        // visible-sample fixture (small); hidden fixture referenced via fixtureRef
  fixtureRef: string;        // key of the pre-built hidden fixture ("" = use fixtureSql)
  referenceSolution: string; // never serialized to clients
  starterCode: string;
  timeoutMs: number;         // per-engine calibrated budget (0 = default)
}

export interface ProblemDoc extends Document {
  slug: string;
  number: number;
  title: string;
  statementMd: string;
  belt: Belt;
  category: "sql" | "python" | "r";
  universe: string;          // "" for White tutorials
  concepts: string[];
  tags: string[];
  schemaPreview: string;
  orderMatters: boolean;
  engines: EngineVariant[];
  prerequisites: string[];   // problem slugs that must be AC'd first (ladder rule)
  provenance: string;
  points: number;
  toListItem(): Record<string, unknown>;
  toClient(): Record<string, unknown>;
}

const engineVariantSchema = new Schema<EngineVariant>(
  {
    engine: { type: String, required: true, enum: ["sqlite", "duckdb", "postgres", "mysql", "mssql", "python", "r"] },
    fixtureSql: { type: String, default: "" },
    fixtureRef: { type: String, default: "" },
    referenceSolution: { type: String, required: true },
    starterCode: { type: String, default: "" },
    timeoutMs: { type: Number, default: 0 },
  },
  { _id: false }
);

const problemSchema = new Schema<ProblemDoc>(
  {
    slug: { type: String, required: true, unique: true },
    number: { type: Number, required: true, unique: true },
    title: { type: String, required: true },
    statementMd: { type: String, required: true },
    belt: { type: String, enum: ["white", "blue", "purple", "black", "red"], default: "white" },
    category: { type: String, enum: ["sql", "python", "r"], default: "sql" },
    universe: { type: String, default: "" },
    concepts: [{ type: String }],
    tags: [{ type: String }],
    schemaPreview: { type: String, default: "" },
    orderMatters: { type: Boolean, default: false },
    engines: [engineVariantSchema],
    prerequisites: [{ type: String }],
    provenance: { type: String, default: "" },
    points: { type: Number, default: 10 },
  },
  { timestamps: true }
);

problemSchema.methods.toListItem = function (this: ProblemDoc) {
  return {
    slug: this.slug,
    number: this.number,
    title: this.title,
    belt: this.belt,
    category: this.category,
    universe: this.universe,
    concepts: this.concepts,
    engines: this.engines.map((e) => e.engine),
    prerequisites: this.prerequisites,
    points: this.points,
  };
};

// The single choke point that keeps solutions/hidden fixtures off the wire.
problemSchema.methods.toClient = function (this: ProblemDoc) {
  return {
    ...this.toListItem(),
    statementMd: this.statementMd,
    schemaPreview: this.schemaPreview,
    orderMatters: this.orderMatters,
    tags: this.tags,
    engines: this.engines.map((e) => ({ engine: e.engine, starterCode: e.starterCode })),
  };
};

export const Problem: Model<ProblemDoc> = mongoose.model<ProblemDoc>("Problem", problemSchema);
