import crypto from "crypto";
import { redis } from "../config/db.js";
import { sendOtpEmail } from "./mailer.js";

const TTL_SECONDS = 600; // 10 minutes
const RESEND_COOLDOWN = 45; // seconds between sends
const MAX_ATTEMPTS = 5;

const otpKey = (userId: string) => `otp:${userId}`;
const attemptsKey = (userId: string) => `otp:att:${userId}`;
const cooldownKey = (userId: string) => `otp:cd:${userId}`;

function sixDigits(): string {
  // uniform 000000-999999
  return String(crypto.randomInt(0, 1_000_000)).padStart(6, "0");
}

export async function issueOtp(userId: string, email: string, name: string): Promise<{ sent: boolean }> {
  const code = sixDigits();
  await redis.set(otpKey(userId), code, "EX", TTL_SECONDS);
  await redis.del(attemptsKey(userId));
  await redis.set(cooldownKey(userId), "1", "EX", RESEND_COOLDOWN);
  await sendOtpEmail(email, code, name);
  return { sent: true };
}

export async function canResend(userId: string): Promise<number> {
  const ttl = await redis.ttl(cooldownKey(userId));
  return ttl > 0 ? ttl : 0; // seconds remaining, 0 if allowed
}

export type VerifyResult = "ok" | "expired" | "mismatch" | "too_many";

export async function verifyOtp(userId: string, code: string): Promise<VerifyResult> {
  const attempts = await redis.incr(attemptsKey(userId));
  if (attempts === 1) await redis.expire(attemptsKey(userId), TTL_SECONDS);
  if (attempts > MAX_ATTEMPTS) return "too_many";

  const stored = await redis.get(otpKey(userId));
  if (!stored) return "expired";
  if (stored !== code) return "mismatch";

  await redis.del(otpKey(userId), attemptsKey(userId), cooldownKey(userId));
  return "ok";
}
