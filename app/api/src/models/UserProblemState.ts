import mongoose, { Schema, type Document, type Model, type Types } from "mongoose";

export interface UserProblemStateDoc extends Document {
  user: Types.ObjectId;
  problemSlug: string;
  state: "attempted" | "solved";
}

const upsSchema = new Schema<UserProblemStateDoc>(
  {
    user: { type: Schema.Types.ObjectId, ref: "User", required: true },
    problemSlug: { type: String, required: true },
    state: { type: String, enum: ["attempted", "solved"], default: "attempted" },
  },
  { timestamps: true }
);

upsSchema.index({ user: 1, problemSlug: 1 }, { unique: true });

export const UserProblemState: Model<UserProblemStateDoc> = mongoose.model<UserProblemStateDoc>(
  "UserProblemState",
  upsSchema
);
