import mongoose, { Schema, type Document, type Model } from "mongoose";
import bcrypt from "bcryptjs";

export interface UserDoc extends Document {
  name: string;
  email: string;
  passwordHash: string;
  role: "user" | "admin";
  solvedCount: number;
  score: number;
  setPassword(plain: string): Promise<void>;
  verifyPassword(plain: string): Promise<boolean>;
  toPublic(): Record<string, unknown>;
}

const userSchema = new Schema<UserDoc>(
  {
    name: { type: String, required: true, trim: true, maxlength: 60 },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    role: { type: String, enum: ["user", "admin"], default: "user" },
    solvedCount: { type: Number, default: 0 },
    score: { type: Number, default: 0 },
  },
  { timestamps: true }
);

userSchema.methods.setPassword = async function (this: UserDoc, plain: string) {
  this.passwordHash = await bcrypt.hash(plain, 10);
};
userSchema.methods.verifyPassword = function (this: UserDoc, plain: string) {
  return bcrypt.compare(plain, this.passwordHash);
};
userSchema.methods.toPublic = function (this: UserDoc) {
  return {
    id: this._id,
    name: this.name,
    email: this.email,
    role: this.role,
    solvedCount: this.solvedCount,
    score: this.score,
  };
};

export const User: Model<UserDoc> = mongoose.model<UserDoc>("User", userSchema);
