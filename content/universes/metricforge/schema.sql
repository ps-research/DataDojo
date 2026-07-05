-- ============================================================================
-- MetricForge -- SaaS product-analytics universe
-- Portable DDL. Types restricted to: INTEGER, BIGINT, DECIMAL(p,s),
-- VARCHAR(n), DATE, TIMESTAMP. No vendor-specific types.
--
-- Foreign keys are written as comments; per-engine loaders materialise the
-- constraints they support. Column semantics and the deliberately planted
-- data landmines are documented in universe.md.
-- ============================================================================


-- Customer organisations (tenants). One account owns many end users and
-- carries a subscription/billing history.
CREATE TABLE accounts (
    account_id    INTEGER       PRIMARY KEY,
    account_name  VARCHAR(120)  NOT NULL,
    plan_tier     VARCHAR(20),          -- current tier: free|starter|pro|enterprise
    signup_date   DATE,
    region        VARCHAR(40),          -- NULLable: geo unknown for some accounts
    industry      VARCHAR(40),
    is_active     INTEGER               -- 0/1: account currently active
);

-- End users belonging to an account. Cohort membership is derived from
-- signup_ts. Internal/test users are flagged and must usually be excluded.
CREATE TABLE users (
    user_id           INTEGER      PRIMARY KEY,
    account_id        INTEGER,           -- FK -> accounts(account_id)
    signup_ts         TIMESTAMP,
    country           VARCHAR(40),       -- NULLable: geo-IP miss
    referral_channel  VARCHAR(30),       -- NULLable: organic|paid_search|social|referral|email|partner
    device_type       VARCHAR(20),
    is_internal       INTEGER            -- 0/1: staff / QA / test user
);

-- Feature-flag catalogue. Flags gate features; events reference the flag whose
-- feature they exercised.
CREATE TABLE feature_flags (
    flag_id        INTEGER       PRIMARY KEY,
    flag_key       VARCHAR(60),
    description    VARCHAR(200),
    created_date   DATE,
    rollout_pct    INTEGER,             -- 0..100
    is_deprecated  INTEGER              -- 0/1
);

-- A/B experiments. May be flag-backed (flag_id set) or standalone. A running
-- experiment has a NULL end_date.
CREATE TABLE experiments (
    experiment_id    INTEGER      PRIMARY KEY,
    experiment_key   VARCHAR(60),
    flag_id          INTEGER,           -- FK -> feature_flags(flag_id), NULLable
    start_date       DATE,
    end_date         DATE,              -- NULLable: NULL == still running
    status           VARCHAR(20),       -- running|completed|aborted
    primary_metric   VARCHAR(40)        -- event_type that defines conversion
);

-- Which user was bucketed into which variant of which experiment. Bridge/fact
-- table. NOT clean: users can appear more than once (see landmine inventory).
CREATE TABLE experiment_assignments (
    assignment_id   INTEGER       PRIMARY KEY,
    experiment_id   INTEGER,            -- FK -> experiments(experiment_id)
    user_id         INTEGER,            -- FK -> users(user_id)
    variant         VARCHAR(20),        -- control|treatment
    assigned_ts     TIMESTAMP
);

-- Subscription / billing history per account. An account has one or more rows
-- (plan changes over time); at most one is "active" (ended_date NULL).
CREATE TABLE subscriptions (
    subscription_id  INTEGER       PRIMARY KEY,
    account_id       INTEGER,           -- FK -> accounts(account_id)
    plan_tier        VARCHAR(20),
    started_date     DATE,
    ended_date       DATE,              -- NULLable: NULL == currently active
    mrr_amount       DECIMAL(10,2),     -- monthly recurring revenue; 0.00 on free
    status           VARCHAR(20)        -- active|upgraded|churned|paused
);

-- User sessions. ended_ts NULL == abandoned/ongoing. app_version is a text
-- version string (lexical vs numeric ordering trap). is_bounce sessions carry
-- zero events.
CREATE TABLE sessions (
    session_id    BIGINT        PRIMARY KEY,
    user_id       INTEGER,            -- FK -> users(user_id)
    started_ts    TIMESTAMP,
    ended_ts      TIMESTAMP,          -- NULLable
    device_type   VARCHAR(20),
    app_version   VARCHAR(15),
    is_bounce     INTEGER             -- 0/1
);

-- The primary fact table. One row per client-emitted event. Largest table
-- (5M-10M rows at red scale). event_ts is not guaranteed ordered w.r.t.
-- event_id and may fall outside its session window (late / clock-skewed).
CREATE TABLE events (
    event_id     BIGINT        PRIMARY KEY,
    session_id   BIGINT,             -- FK -> sessions(session_id)
    user_id      INTEGER,            -- FK -> users(user_id)  (denormalised)
    event_ts     TIMESTAMP,
    event_type   VARCHAR(30),        -- page_view|feature_used|view_plans|
                                     -- start_checkout|enter_payment|purchase|
                                     -- search|error
    flag_id      INTEGER,            -- FK -> feature_flags(flag_id), NULL unless feature_used
    event_value  DECIMAL(12,2),      -- revenue on purchase; NULL otherwise (some NULL even on purchase)
    page_path    VARCHAR(80)
);
