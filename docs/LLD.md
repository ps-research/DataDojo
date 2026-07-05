# DataDojo - Low-Level Design

Companion to [HLD](./HLD.md).

## Data model (MongoDB)

**users**: name, email (unique), passwordHash (bcrypt), role, emailVerified,
solvedCount, score.

**problems**: slug, number, title, statementMd, belt (white/blue/purple/black/
red), category (sql/python/r), universe, concepts, schemaPreview, orderMatters,
points, `engines[]`, and `hiddenFixtures[]` (the judge datasets, never sent to
the client). Each engine variant holds: engine, fixtureSql (visible sample),
referenceSolution, starterCode, timeoutMs.

**submissions**: user, problem, engine, code, verdict, message, runtimeMs,
testsPassed, testsTotal, createdAt.

**userProblemState**: user, problemSlug, state (attempted/solved). Drives the
solved marker; never downgrades from solved.

Reference solutions and hidden fixtures are stripped in the API serializer, so
only slug, statement, schema preview, engines, and starter code reach the client.

## API

Base path `/api`. Bearer JWT unless marked public. Input validated with Zod.

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | /auth/signup | public | register (trusted-domain email); OTP if enabled |
| POST | /auth/login | public | login |
| POST | /auth/verify-otp | public | verify email code |
| POST | /auth/refresh | cookie | rotate access token |
| GET | /auth/me | JWT | current user |
| GET | /problems | optional | list with filters + solved flag |
| GET | /problems/:slug | optional | detail (no solutions/fixtures) |
| POST | /submissions | JWT | submit, returns 202 + id |
| POST | /submissions/run | JWT | run against sample, return result table |
| GET | /submissions/:id | JWT | poll verdict |
| GET | /submissions/:id/stream | JWT | SSE live verdict |
| GET | /leaderboard | public | top N from Redis sorted set |
| GET | /users/me/stats | JWT | profile analytics |
| PUT | /users/me, /users/me/password | JWT | update profile / password |
| POST | /ai/hint | JWT | AI hint (rate limited) |

## Judge

Every engine implements `run(fixtureSql, code, timeoutMs)` returning a result set
or an error/timeout.

Verdict logic: for each hidden fixture, run the reference to get the expected
output, run the user's code, and compare (normalized: NULL sentinel, int/float
unification, trimmed strings, dates to YYYY-MM-DD; rows sorted when order does
not matter). Return the first failing verdict with the count of fixtures passed,
or AC if all pass. Errors are classified CE (syntax-like) or RE; a wall-clock
overrun is TLE.

Isolation per engine:

| Engine | Execution | Isolation | Timeout |
|--------|-----------|-----------|---------|
| sqlite, duckdb | in-process | fresh in-memory db, worker thread | terminate thread |
| postgres, mssql | server | transaction, always rolled back | statement/query timeout |
| mysql | server | throwaway schema | max_execution_time |
| python, r | subprocess | isolated, no site leakage | SIGKILL |

## AI hint

`POST /ai/hint` builds a prompt from the problem statement, the reference
solution (server-side only), and the user's code, and calls a Python helper that
uses the Gemini SDK with a JSON response schema. Five free-tier keys are tried
round-robin with failover on quota. Ten hints per user per hour (Redis counter).
Disabled if no keys are configured.

## Auth

Access token (15 min) held in memory; refresh token in an httpOnly, SameSite
cookie, rotated on refresh. Passwords hashed with bcrypt. Admin routes re-check
the role from the JWT. Email signup limited to trusted providers; OTP verification
is available when SMTP is configured (otherwise signups verify immediately).

## Content pipeline (build time)

`kb/` extracts the SQL Cookbook verbatim (sha256), parses recipes and their
per-dialect solutions, and runs every solution on all five SQL engines to record
what actually works. `content/build_gold.py` builds each problem's visible sample
and three hidden fixtures (seeded generators), verifies the reference runs on
them, and writes `gold_problems.json`, which is seeded into MongoDB.
