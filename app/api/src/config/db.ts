import mongoose from "mongoose";
import { Redis } from "ioredis";
import { env } from "./env.js";

export async function connectMongo(): Promise<void> {
  mongoose.set("strictQuery", true);
  await mongoose.connect(env.mongoUri);
  console.log("[db] MongoDB connected");
}

// BullMQ requires maxRetriesPerRequest: null on its connections.
export function makeRedis(): Redis {
  return new Redis(env.redisUrl, { maxRetriesPerRequest: null });
}

export const redis = makeRedis();
