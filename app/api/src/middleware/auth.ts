import jwt from "jsonwebtoken";
import type { NextFunction, Request, Response } from "express";
import { env } from "../config/env.js";
import { ApiError } from "./error.js";
import type { UserDoc } from "../models/User.js";

export interface AuthedRequest extends Request {
  userId?: string;
  userRole?: string;
}

export function signAccessToken(user: UserDoc): string {
  return jwt.sign({ sub: String(user._id), role: user.role }, env.jwtSecret, {
    expiresIn: env.jwtExpiry,
  } as jwt.SignOptions);
}

export function signRefreshToken(user: UserDoc): string {
  return jwt.sign({ sub: String(user._id), typ: "refresh" }, env.jwtSecret, {
    expiresIn: env.refreshExpiry,
  } as jwt.SignOptions);
}

function extractToken(req: Request): string | null {
  const header = req.headers.authorization ?? "";
  if (header.startsWith("Bearer ")) return header.slice(7);
  // SSE (EventSource) cannot set headers - allow query token there only.
  if (req.path.endsWith("/stream") && typeof req.query.token === "string") return req.query.token;
  return null;
}

export function requireAuth(req: AuthedRequest, _res: Response, next: NextFunction): void {
  const token = extractToken(req);
  if (!token) return next(new ApiError(401, "Authentication required"));
  try {
    const payload = jwt.verify(token, env.jwtSecret) as jwt.JwtPayload;
    if (payload.typ === "refresh") return next(new ApiError(401, "Invalid token type"));
    req.userId = payload.sub as string;
    req.userRole = payload.role as string;
    next();
  } catch {
    next(new ApiError(401, "Invalid or expired token"));
  }
}

export function optionalAuth(req: AuthedRequest, _res: Response, next: NextFunction): void {
  const token = extractToken(req);
  if (token) {
    try {
      const payload = jwt.verify(token, env.jwtSecret) as jwt.JwtPayload;
      req.userId = payload.sub as string;
      req.userRole = payload.role as string;
    } catch {
      /* anonymous */
    }
  }
  next();
}

export function requireAdmin(req: AuthedRequest, _res: Response, next: NextFunction): void {
  if (req.userRole !== "admin") return next(new ApiError(403, "Admin access required"));
  next();
}
