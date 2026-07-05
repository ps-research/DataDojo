import { createApp } from "./app.js";
import { connectDB } from "./config/db.js";
import { env } from "./config/env.js";

async function main() {
  await connectDB();
  const app = createApp();
  app.listen(env.port, () => {
    console.log(`[api] DataDojo API listening on :${env.port} (${env.nodeEnv})`);
  });
}

main().catch((err) => {
  console.error("[api] fatal startup error:", err);
  process.exit(1);
});
