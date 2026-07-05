import { createApp } from "./app.js";
import { connectMongo } from "./config/db.js";
import { env } from "./config/env.js";
import { probeEngines } from "./judge/registry.js";
import { startJudgeWorker } from "./queue/index.js";

async function main(): Promise<void> {
  await connectMongo();
  const engines = await probeEngines();
  console.log("[judge] engine availability:", engines);

  const app = createApp();
  if (process.env.ROLE !== "api-only") startJudgeWorker();

  app.listen(env.port, () => {
    console.log(`[api] DataDojo API on :${env.port} (${env.nodeEnv})`);
  });
}

main().catch((err) => {
  console.error("[api] fatal startup error:", err);
  process.exit(1);
});
