import { Router, type Response } from "express";
import jwt from "jsonwebtoken";
import { z } from "zod";
import { User } from "../models/User.js";
import { ApiError, asyncHandler } from "../middleware/error.js";
import { requireAuth, signAccessToken, signRefreshToken, type AuthedRequest } from "../middleware/auth.js";
import { env } from "../config/env.js";
import { isTrustedEmailDomain, TRUSTED_DOMAINS_HINT } from "../config/trusted-domains.js";
import { issueOtp, canResend, verifyOtp } from "../services/otp.js";
import { mailerConfigured } from "../services/mailer.js";

const router = Router();

const signupSchema = z.object({
  name: z.string().min(1, "Name is required").max(60),
  email: z
    .string()
    .email("Valid email required")
    .refine(isTrustedEmailDomain, `Please use a trusted email provider. ${TRUSTED_DOMAINS_HINT}`),
  password: z.string().min(8, "Password must be at least 8 characters"),
});
const loginSchema = z.object({ email: z.string().email(), password: z.string().min(1) });
const otpSchema = z.object({ email: z.string().email(), code: z.string().length(6, "Enter the 6-digit code") });
const emailSchema = z.object({ email: z.string().email() });

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
    // If email delivery isn't configured, don't trap users behind a code that
    // never arrives - verify immediately. OTP activates the moment SMTP is set.
    const user = new User({ name, email, emailVerified: !mailerConfigured });
    await user.setPassword(password);
    await user.save();
    if (!mailerConfigured) {
      res.status(201).json({ accessToken: issueTokens(res, user), user: user.toPublic() });
      return;
    }
    await issueOtp(String(user._id), email, name);
    res.status(201).json({ needsVerification: true, email });
  })
);

router.post(
  "/login",
  asyncHandler(async (req, res) => {
    const { email, password } = loginSchema.parse(req.body);
    const user = await User.findOne({ email });
    if (!user || !(await user.verifyPassword(password))) throw new ApiError(401, "Invalid email or password");
    if (mailerConfigured && !user.emailVerified) {
      // send a fresh code and route the client to verification
      if (!(await canResend(String(user._id)))) await issueOtp(String(user._id), email, user.name);
      res.status(403).json({ needsVerification: true, email });
      return;
    }
    res.json({ accessToken: issueTokens(res, user), user: user.toPublic() });
  })
);

router.post(
  "/verify-otp",
  asyncHandler(async (req, res) => {
    const { email, code } = otpSchema.parse(req.body);
    const user = await User.findOne({ email });
    if (!user) throw new ApiError(404, "Account not found");
    if (user.emailVerified) return res.json({ accessToken: issueTokens(res, user), user: user.toPublic() });

    const result = await verifyOtp(String(user._id), code);
    if (result === "too_many") throw new ApiError(429, "Too many attempts. Request a new code.");
    if (result === "expired") throw new ApiError(410, "Code expired. Request a new one.");
    if (result === "mismatch") throw new ApiError(400, "Incorrect code. Try again.");

    user.emailVerified = true;
    await user.save();
    res.json({ accessToken: issueTokens(res, user), user: user.toPublic() });
  })
);

router.post(
  "/resend-otp",
  asyncHandler(async (req, res) => {
    const { email } = emailSchema.parse(req.body);
    const user = await User.findOne({ email });
    // Do not leak which emails exist; always answer 200.
    if (user && !user.emailVerified) {
      const wait = await canResend(String(user._id));
      if (wait > 0) return res.status(200).json({ ok: true, retryAfter: wait });
      await issueOtp(String(user._id), email, user.name);
    }
    res.status(200).json({ ok: true });
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
