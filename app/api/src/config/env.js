import dotenv from "dotenv";
dotenv.config();

const required = (key, fallback) => {
  const v = process.env[key] ?? fallback;
  if (v === undefined) throw new Error(`Missing required env var: ${key}`);
  return v;
};

export const env = {
  port: parseInt(process.env.PORT ?? "4000", 10),
  nodeEnv: process.env.NODE_ENV ?? "development",
  mongoUri: required("MONGO_URI", "mongodb://127.0.0.1:27017/datadojo"),
  jwtSecret: required("JWT_SECRET", "dev-insecure-change-me"),
  jwtExpiry: process.env.JWT_EXPIRY ?? "15m",
  refreshExpiry: process.env.REFRESH_TOKEN_EXPIRY ?? "7d",
  clientOrigin: process.env.CLIENT_ORIGIN ?? "http://localhost:5173",
  // Judge engine endpoints (optional; SQLite + Python always available in-process)
  engines: {
    postgres: process.env.PG_URL ?? "postgresql://postgres@/postgres?host=/tmp&port=5433",
    mysql: process.env.MYSQL_SOCKET ?? "/tmp/mariadb.sock",
    mssql: process.env.MSSQL_URL ?? "Server=127.0.0.1,1433;User=SA;Password=DataDojo!2026",
    pythonBin: process.env.PYTHON_BIN ?? "python3",
    rBin: process.env.R_BIN ?? "Rscript",
  },
  judgeTimeoutMs: parseInt(process.env.JUDGE_TIMEOUT_MS ?? "5000", 10),
};
