import mongoose from "mongoose";

export const VERDICTS = ["AC", "WA", "TLE", "RE", "CE"];

const submissionSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    problem: { type: mongoose.Schema.Types.ObjectId, ref: "Problem", required: true, index: true },
    problemSlug: { type: String, required: true },
    engine: { type: String, required: true },
    code: { type: String, required: true },
    verdict: { type: String, enum: VERDICTS, required: true },
    // For WA: how the user's output differed; for RE/CE: the error text
    message: { type: String, default: "" },
    runtimeMs: { type: Number, default: 0 },
    rowsReturned: { type: Number, default: 0 },
  },
  { timestamps: true }
);

submissionSchema.index({ user: 1, problem: 1, createdAt: -1 });

export const Submission = mongoose.model("Submission", submissionSchema);
