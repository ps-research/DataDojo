import { Router, type Response } from "express";
import jwt from "jsonwebtoken";
import { z } from "zod";
import { User } from "../models/User.js";
import { ApiError, asyncHandler } from "../middleware/error.js";
import { requireAuth, signAccessToken, signRefreshToken, type AuthedRequest } from "../middleware/auth.js";
import { env } from "../config/env.js";

const router = Router();

const signupSchema = z.object({
  name: z.string().min(1, "Name is required").max(60),
  email: z.string().email("Valid email required"),
  password: z.string().min(8, "Password must be at least 8 characters"),
});
const loginSchema = z.object({ email: z.string().email(), password: z.string().min(1) });

const refreshCookieOpts = {
  httpOnly: true,
  sameSite: "strict" as const,
  secure: env.isProd,
  path: "/api/auth",
  maxAge: 7 * 24 * 60 * 60 * 1000,
};

function issueTokens(res: Response, user: Parameters<typeof signAccessToken>[0]) {
  res.cookie("refreshToken", signRefreshToken(user), refreshCookieOpts);
  return signAccessToken(user);
}

router.post(
  "/signup",
  asyncHandler(async (req, res) => {
    const { name, email, password } = signupSchema.parse(req.body);
    if (await User.findOne({ email })) throw new ApiError(409, "Email already registered");
    const user = new User({ name, email });
    await user.setPassword(password);
    await user.save();
    res.status(201).json({ accessToken: issueTokens(res, user), user: user.toPublic() });
  })
);

router.post(
  "/login",
  asyncHandler(async (req, res) => {
    const { email, password } = loginSchema.parse(req.body);
    const user = await User.findOne({ email });
    if (!user || !(await user.verifyPassword(password))) throw new ApiError(401, "Invalid email or password");
    res.json({ accessToken: issueTokens(res, user), user: user.toPublic() });
  })
);

router.post(
  "/refresh",
  asyncHandler(async (req, res) => {
    const token = (req.cookies as Record<string, string>)?.refreshToken;
    if (!token) throw new ApiError(401, "No refresh token");
    let payload: jwt.JwtPayload;
    try {
      payload = jwt.verify(token, env.jwtSecret) as jwt.JwtPayload;
    } catch {
      throw new ApiError(401, "Invalid refresh token");
    }
    if (payload.typ !== "refresh") throw new ApiError(401, "Invalid token type");
    const user = await User.findById(payload.sub);
    if (!user) throw new ApiError(401, "User no longer exists");
    res.json({ accessToken: issueTokens(res, user), user: user.toPublic() });
  })
);

router.post("/logout", (_req, res) => {
  res.clearCookie("refreshToken", { path: "/api/auth" });
  res.json({ ok: true });
});

router.get(
  "/me",
  requireAuth,
  asyncHandler(async (req: AuthedRequest, res) => {
    const user = await User.findById(req.userId);
    if (!user) throw new ApiError(404, "User not found");
    res.json({ user: user.toPublic() });
  })
);

export default router;
