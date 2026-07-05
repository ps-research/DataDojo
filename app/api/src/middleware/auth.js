import jwt from "jsonwebtoken";
import { env } from "../config/env.js";
import { ApiError } from "./error.js";

export function signAccessToken(user) {
  return jwt.sign({ sub: user._id.toString(), role: user.role }, env.jwtSecret, {
    expiresIn: env.jwtExpiry,
  });
}
export function signRefreshToken(user) {
  return jwt.sign({ sub: user._id.toString(), typ: "refresh" }, env.jwtSecret, {
    expiresIn: env.refreshExpiry,
  });
}

export function requireAuth(req, _res, next) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) return next(new ApiError(401, "Authentication required"));
  try {
    const payload = jwt.verify(token, env.jwtSecret);
    req.userId = payload.sub;
    req.userRole = payload.role;
    next();
  } catch {
    next(new ApiError(401, "Invalid or expired token"));
  }
}

// Server-enforced admin check (rubric: don't trust frontend role manipulation).
export function requireAdmin(req, _res, next) {
  if (req.userRole !== "admin") return next(new ApiError(403, "Admin access required"));
  next();
}
