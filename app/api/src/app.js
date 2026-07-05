import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import cookieParser from "cookie-parser";
import rateLimit from "express-rate-limit";
import { env } from "./config/env.js";
import { errorHandler, notFound } from "./middleware/error.js";
import authRoutes from "./routes/auth.routes.js";
import problemRoutes from "./routes/problem.routes.js";
import submissionRoutes from "./routes/submission.routes.js";
import leaderboardRoutes from "./routes/leaderboard.routes.js";

export function createApp() {
  const app = express();

  app.use(helmet());
  app.use(cors({ origin: env.clientOrigin, credentials: true }));
  app.use(express.json({ limit: "256kb" }));
  app.use(cookieParser());
  if (env.nodeEnv !== "test") app.use(morgan("dev"));

  // Submissions run code — rate-limit to blunt abuse (rubric: infinite loops, etc.)
  const judgeLimiter = rateLimit({ windowMs: 60_000, max: 30 });

  app.get("/api/health", (_req, res) => res.json({ ok: true, service: "datadojo-api" }));
  app.use("/api/auth", authRoutes);
  app.use("/api/problems", problemRoutes);
  app.use("/api/submissions", judgeLimiter, submissionRoutes);
  app.use("/api/leaderboard", leaderboardRoutes);

  app.use(notFound);
  app.use(errorHandler);
  return app;
}
