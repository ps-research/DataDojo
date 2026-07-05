import dotenv from "dotenv";
dotenv.config();

function required(key: string, fallback?: string): string {
  const v = process.env[key] ?? fallback;
  if (v === undefined) throw new Error(`Missing required env var: ${key}`);
  return v;
}

export const env = {
  port: parseInt(process.env.PORT ?? "4000", 10),
  nodeEnv: process.env.NODE_ENV ?? "development",
  isProd: (process.env.NODE_ENV ?? "development") === "production",
  mongoUri: required("MONGO_URI", "mongodb://127.0.0.1:27017/datadojo"),
  redisUrl: required("REDIS_URL", "redis://127.0.0.1:6379"),
  jwtSecret: required("JWT_SECRET", "dev-insecure-change-me"),
  jwtExpiry: process.env.JWT_EXPIRY ?? "15m",
  refreshExpiry: process.env.REFRESH_TOKEN_EXPIRY ?? "7d",
  clientOrigin: process.env.CLIENT_ORIGIN ?? "http://localhost:5173",
  engines: {
    pgUrl: process.env.PG_URL ?? "postgresql://postgres@127.0.0.1:5433/postgres",
    mysql: {
      socketPath: process.env.MYSQL_SOCKET ?? "/tmp/mariadb.sock",
      user: process.env.MYSQL_USER ?? "root",
      database: process.env.MYSQL_DB ?? "datadojo_judge",
    },
    mssql: {
      server: process.env.MSSQL_HOST ?? "127.0.0.1",
      port: parseInt(process.env.MSSQL_PORT ?? "1433", 10),
      user: process.env.MSSQL_USER ?? "SA",
      password: process.env.MSSQL_PASSWORD ?? "DataDojo!2026",
      database: process.env.MSSQL_DB ?? "datadojo_judge",
    },
    pythonBin: process.env.PYTHON_BIN ?? "python3",
    rBin: process.env.R_BIN ?? "Rscript",
  },
  judgeTimeoutMs: parseInt(process.env.JUDGE_TIMEOUT_MS ?? "5000", 10),
  fixturesDir: process.env.FIXTURES_DIR ?? "",
} as const;

if (env.isProd && env.jwtSecret === "dev-insecure-change-me") {
  throw new Error("JWT_SECRET must be set in production");
}
