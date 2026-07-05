import mongoose, { Schema, type Document, type Model, type Types } from "mongoose";
import type { Engine, Verdict } from "../types.js";

export interface SubmissionDoc extends Document {
  user: Types.ObjectId;
  problem: Types.ObjectId;
  problemSlug: string;
  engine: Engine;
  code: string;
  status: "queued" | "running" | "done";
  verdict?: Verdict;
  message: string;
  runtimeMs: number;
  rowsReturned: number;
  createdAt: Date;
}

const submissionSchema = new Schema<SubmissionDoc>(
  {
    user: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    problem: { type: Schema.Types.ObjectId, ref: "Problem", required: true, index: true },
    problemSlug: { type: String, required: true },
    engine: { type: String, required: true },
    code: { type: String, required: true, maxlength: 20000 },
    status: { type: String, enum: ["queued", "running", "done"], default: "queued" },
    verdict: { type: String, enum: ["AC", "WA", "TLE", "RE", "CE"] },
    message: { type: String, default: "" },
    runtimeMs: { type: Number, default: 0 },
    rowsReturned: { type: Number, default: 0 },
  },
  { timestamps: true }
);

submissionSchema.index({ user: 1, problem: 1, createdAt: -1 });

export const Submission: Model<SubmissionDoc> = mongoose.model<SubmissionDoc>("Submission", submissionSchema);
