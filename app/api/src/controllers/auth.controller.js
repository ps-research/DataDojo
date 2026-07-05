import { z } from "zod";
import { User } from "../models/User.js";
import { ApiError, asyncHandler } from "../middleware/error.js";
import { signAccessToken, signRefreshToken } from "../middleware/auth.js";
import { env } from "../config/env.js";

const signupSchema = z.object({
  name: z.string().min(1).max(60),
  email: z.string().email(),
  password: z.string().min(8, "Password must be at least 8 characters"),
});
const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const refreshCookieOpts = {
  httpOnly: true,
  sameSite: "strict",
  secure: env.nodeEnv === "production",
  maxAge: 7 * 24 * 60 * 60 * 1000,
};

export const signup = asyncHandler(async (req, res) => {
  const { name, email, password } = signupSchema.parse(req.body);
  if (await User.findOne({ email })) throw new ApiError(409, "Email already registered");
  const user = new User({ name, email });
  await user.setPassword(password);
  await user.save();
  const accessToken = signAccessToken(user);
  res.cookie("refreshToken", signRefreshToken(user), refreshCookieOpts);
  res.status(201).json({ accessToken, user: user.toPublic() });
});

export const login = asyncHandler(async (req, res) => {
  const { email, password } = loginSchema.parse(req.body);
  const user = await User.findOne({ email });
  if (!user || !(await user.verifyPassword(password)))
    throw new ApiError(401, "Invalid email or password");
  const accessToken = signAccessToken(user);
  res.cookie("refreshToken", signRefreshToken(user), refreshCookieOpts);
  res.json({ accessToken, user: user.toPublic() });
});

export const me = asyncHandler(async (req, res) => {
  const user = await User.findById(req.userId);
  if (!user) throw new ApiError(404, "User not found");
  res.json({ user: user.toPublic() });
});

export const logout = asyncHandler(async (_req, res) => {
  res.clearCookie("refreshToken");
  res.json({ ok: true });
});
