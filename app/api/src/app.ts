import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import cookieParser from "cookie-parser";
import rateLimit from "express-rate-limit";
import { env } from "./config/env.js";
import { errorHandler, notFound } from "./middleware/error.js";
import { availableEngines } from "./judge/registry.js";
import authRoutes from "./routes/auth.routes.js";
import problemRoutes from "./routes/problem.routes.js";
import submissionRoutes from "./routes/submission.routes.js";
import leaderboardRoutes from "./routes/leaderboard.routes.js";

export function createApp(): express.Express {
  const app = express();

  app.set("trust proxy", 1); // behind nginx
  app.use(helmet());
  app.use(cors({ origin: env.clientOrigin, credentials: true }));
  app.use(express.json({ limit: "256kb" }));
  app.use(cookieParser());
  if (env.nodeEnv !== "test") app.use(morgan(env.isProd ? "combined" : "dev"));

  const authLimiter = rateLimit({ windowMs: 60_000, max: 20, standardHeaders: true, legacyHeaders: false });

  app.get("/api/health", (_req, res) =>
    res.json({ ok: true, service: "datadojo-api", engines: availableEngines() })
  );
  app.use("/api/auth", authLimiter, authRoutes);
  app.use("/api/problems", problemRoutes);
  app.use("/api/submissions", submissionRoutes);
  app.use("/api/leaderboard", leaderboardRoutes);

  app.use(notFound);
  app.use(errorHandler);
  return app;
}
