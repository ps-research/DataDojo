-- ============================================================================
-- PulseStream universe — portable schema
-- ----------------------------------------------------------------------------
-- Music/video streaming platform: artists, albums, tracks, listeners,
-- subscriptions, the play-event firehose, a royalty rate card, and monthly
-- artist payouts.
--
-- Portability contract (CONTENT-SPEC section 4.5): only INTEGER, BIGINT,
-- DECIMAL(p,s), VARCHAR(n), DATE and TIMESTAMP are used. No vendor types.
-- Foreign keys are expressed as comments; per-engine loaders materialize the
-- real constraints. Column order here IS the CSV column order emitted by
-- generator.py (header row per table).
--
-- Intentional data properties (landmines) are documented in universe.md and
-- are NOT schema errors: nullable ended_at means "still active", a nullable
-- artist_id in artist_payouts models unattributed manual adjustments, etc.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- artists — the rights holders that royalties accrue to.
-- ---------------------------------------------------------------------------
CREATE TABLE artists (
    artist_id              INTEGER      NOT NULL,   -- PK
    name                   VARCHAR(120) NOT NULL,
    country                VARCHAR(2),              -- ISO-2 home market; NULL = unknown
    primary_genre          VARCHAR(40),             -- NULL = uncategorized
    signed_date            DATE         NOT NULL,   -- date the artist joined the roster
    monthly_listeners_est  BIGINT,                  -- denormalized stat; may be NULL / stale
    PRIMARY KEY (artist_id)
);

-- ---------------------------------------------------------------------------
-- albums — release groupings owned by one artist.
-- ---------------------------------------------------------------------------
CREATE TABLE albums (
    album_id      INTEGER      NOT NULL,   -- PK
    artist_id     INTEGER      NOT NULL,   -- FK -> artists(artist_id)
    title         VARCHAR(160) NOT NULL,
    release_date  DATE         NOT NULL,
    album_type    VARCHAR(20)  NOT NULL,   -- album | ep | single | compilation
    PRIMARY KEY (album_id)
);

-- ---------------------------------------------------------------------------
-- tracks — the individually streamable unit.
-- ---------------------------------------------------------------------------
CREATE TABLE tracks (
    track_id      INTEGER      NOT NULL,   -- PK
    artist_id     INTEGER      NOT NULL,   -- FK -> artists(artist_id)
    album_id      INTEGER,                 -- FK -> albums(album_id); NULL = non-album single
    title         VARCHAR(200) NOT NULL,
    genre         VARCHAR(40),             -- NULL = uncategorized (landmine)
    duration_sec  INTEGER,                 -- length in SECONDS; NULL for a few legacy rows
    release_date  DATE         NOT NULL,
    is_explicit   INTEGER      NOT NULL,   -- 0 | 1
    isrc          VARCHAR(15)  NOT NULL,   -- alphanumeric code; NEVER numeric (coercion trap)
    PRIMARY KEY (track_id)
);

-- ---------------------------------------------------------------------------
-- users — listener accounts.
-- ---------------------------------------------------------------------------
CREATE TABLE users (
    user_id          INTEGER     NOT NULL,   -- PK
    display_name     VARCHAR(80) NOT NULL,
    country          VARCHAR(2),             -- ISO-2 consumption market; NULL = unknown (rate falls back to global)
    birth_year       INTEGER,                -- NULL = undisclosed
    signup_date      DATE        NOT NULL,
    referral_source  VARCHAR(30),            -- NULL = organic/unknown
    PRIMARY KEY (user_id)
);

-- ---------------------------------------------------------------------------
-- subscriptions — plan periods per user. A user can have several rows over
-- time (free -> paid -> churn -> resubscribe) and, in a few glitchy cases,
-- two OVERLAPPING paid rows (join fan-out landmine).
-- ended_at NULL == currently active.
-- ---------------------------------------------------------------------------
CREATE TABLE subscriptions (
    subscription_id  INTEGER      NOT NULL,   -- PK
    user_id          INTEGER      NOT NULL,   -- FK -> users(user_id)
    plan             VARCHAR(20)  NOT NULL,   -- free | trial | student | family | premium
    started_at       DATE         NOT NULL,
    ended_at         DATE,                    -- NULL = still active (meaningful NULL)
    price_usd        DECIMAL(6,2) NOT NULL,   -- monthly price for the plan (0.00 for free/trial)
    is_auto_renew    INTEGER      NOT NULL,   -- 0 | 1
    PRIMARY KEY (subscription_id)
);

-- ---------------------------------------------------------------------------
-- plays — the event firehose (largest fact table). One row per stream start.
-- Events are stored roughly in ingestion order, which is NOT chronological:
-- play_id order does not equal played_at order (out-of-order / late offline
-- syncs). A small fraction of events are duplicated (same natural key, new
-- play_id) from client retries.
-- ---------------------------------------------------------------------------
CREATE TABLE plays (
    play_id     BIGINT    NOT NULL,   -- PK (surrogate; NOT chronological)
    user_id     INTEGER   NOT NULL,   -- FK -> users(user_id)
    track_id    INTEGER   NOT NULL,   -- FK -> tracks(track_id)
    played_at   TIMESTAMP NOT NULL,   -- event wall-clock time
    ms_played   BIGINT,               -- MILLISECONDS listened; NULL = telemetry missing
    device      VARCHAR(20),          -- ios | android | web | desktop | smart_speaker | NULL
    source      VARCHAR(20) NOT NULL, -- search | playlist | album | radio | artist_page | daily_mix
    is_offline  INTEGER   NOT NULL,   -- 0 | 1 (offline plays often sync late)
    PRIMARY KEY (play_id)
);

-- ---------------------------------------------------------------------------
-- royalty_rates — the per-stream rate card. Keyed by (plan, market, epoch).
-- country NULL == the global fallback rate for that plan. Rates changed on
-- 2024-01-01 (a mid-window revision => a boundary landmine). Effective range
-- is [effective_from, effective_to) with effective_to NULL meaning open-ended.
-- free and trial plans carry a 0.000000 rate (zero-denominator / zero-value).
-- ---------------------------------------------------------------------------
CREATE TABLE royalty_rates (
    rate_id         INTEGER       NOT NULL,   -- PK
    plan            VARCHAR(20)   NOT NULL,   -- matches subscriptions.plan
    country         VARCHAR(2),               -- consumption market; NULL = global fallback
    effective_from  DATE          NOT NULL,   -- inclusive
    effective_to    DATE,                     -- exclusive; NULL = open-ended
    per_play_usd    DECIMAL(10,6) NOT NULL,   -- USD paid per qualifying stream
    PRIMARY KEY (rate_id)
);

-- ---------------------------------------------------------------------------
-- artist_payouts — what the finance system ACTUALLY paid each artist per
-- month. Ground truth (computed royalties) can diverge: some months are
-- over/underpaid, some are still 'pending', some owed months have NO row at
-- all, and a few adjustment rows have a NULL artist_id (NULL-in-NOT-IN trap).
-- period_month is the first day of the accounting month.
-- ---------------------------------------------------------------------------
CREATE TABLE artist_payouts (
    payout_id     INTEGER       NOT NULL,   -- PK
    artist_id     INTEGER,                  -- FK -> artists(artist_id); NULL = unattributed adjustment
    period_month  DATE          NOT NULL,   -- first day of the accounting month
    amount_usd    DECIMAL(12,2) NOT NULL,
    status        VARCHAR(20)   NOT NULL,   -- paid | pending | reversed
    PRIMARY KEY (payout_id)
);
