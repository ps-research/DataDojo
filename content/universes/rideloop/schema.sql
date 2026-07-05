-- ==========================================================================
-- RideLoop universe schema (DataDojo)
-- Portable DDL: INTEGER, BIGINT, DECIMAL(p,s), VARCHAR(n), DATE, TIMESTAMP only.
-- Foreign keys are expressed as comments; per-engine loaders add real
-- constraints. Column order here IS the CSV column order emitted by
-- generator.py (headers match exactly).
-- ==========================================================================

-- --------------------------------------------------------------------------
-- geozones : dimension of service areas within cities (pickup/dropoff zones)
-- --------------------------------------------------------------------------
CREATE TABLE geozones (
    zone_id      INTEGER       NOT NULL,   -- PK
    zone_code    VARCHAR(8),               -- external code, zero-padded e.g. '007' (type-coercion trap)
    zone_name    VARCHAR(64),
    city         VARCHAR(48),
    is_airport   INTEGER,                  -- 0 / 1 flag
    area_km2     DECIMAL(8,2),
    base_fare    DECIMAL(6,2)              -- zone base fare before distance/surge
    -- PRIMARY KEY (zone_id)
);

-- --------------------------------------------------------------------------
-- riders : dimension of passengers
-- --------------------------------------------------------------------------
CREATE TABLE riders (
    rider_id        INTEGER    NOT NULL,   -- PK
    signup_date     DATE,
    home_zone_id    INTEGER,               -- FK -> geozones(zone_id); NULL for riders with no home zone
    rider_tier      VARCHAR(16),           -- 'basic' | 'plus'; NULL for legacy accounts
    referral_source VARCHAR(24)            -- 'organic' | 'promo' | 'referral' | ... ; nullable
    -- PRIMARY KEY (rider_id)
    -- FOREIGN KEY (home_zone_id) REFERENCES geozones(zone_id)
);

-- --------------------------------------------------------------------------
-- drivers : dimension of drivers
-- --------------------------------------------------------------------------
CREATE TABLE drivers (
    driver_id     INTEGER   NOT NULL,      -- PK
    onboard_date  DATE,
    home_zone_id  INTEGER,                 -- FK -> geozones(zone_id)
    status        VARCHAR(16),             -- 'active' | 'suspended' | 'churned'
    rating        DECIMAL(3,2)             -- rolling avg star rating; NULL for drivers with no rated trips yet
    -- PRIMARY KEY (driver_id)
    -- FOREIGN KEY (home_zone_id) REFERENCES geozones(zone_id)
);

-- --------------------------------------------------------------------------
-- vehicles : a driver may register more than one vehicle over time (1:N)
-- --------------------------------------------------------------------------
CREATE TABLE vehicles (
    vehicle_id    BIGINT    NOT NULL,      -- PK
    driver_id     INTEGER,                 -- FK -> drivers(driver_id)
    vehicle_class VARCHAR(16),             -- 'economy' | 'xl' | 'lux'
    make          VARCHAR(24),
    model         VARCHAR(24),
    model_year    INTEGER,
    seats         INTEGER,
    active_from   DATE,
    active_to     DATE                     -- NULL = currently active
    -- PRIMARY KEY (vehicle_id)
    -- FOREIGN KEY (driver_id) REFERENCES drivers(driver_id)
);

-- --------------------------------------------------------------------------
-- trips : the central fact table (one row per trip request, any outcome)
--   status values:
--     'completed'         -> pickup/dropoff/fare populated
--     'cancelled_rider'   -> rider cancelled after (maybe) matching
--     'cancelled_driver'  -> driver cancelled after matching
--     'no_driver'         -> never matched; driver_id / vehicle_id NULL
-- --------------------------------------------------------------------------
CREATE TABLE trips (
    trip_id          BIGINT      NOT NULL, -- PK
    rider_id         INTEGER,              -- FK -> riders(rider_id)
    driver_id        INTEGER,              -- FK -> drivers(driver_id); NULL when no_driver
    vehicle_id       BIGINT,               -- FK -> vehicles(vehicle_id); NULL when no vehicle assigned
    request_ts       TIMESTAMP,            -- when the ride was requested (NOT monotonic with trip_id)
    pickup_ts        TIMESTAMP,            -- NULL unless a pickup happened
    dropoff_ts       TIMESTAMP,            -- NULL unless completed
    pickup_zone_id   INTEGER,              -- FK -> geozones(zone_id)
    dropoff_zone_id  INTEGER,              -- FK -> geozones(zone_id); NULL unless completed
    distance_km      DECIMAL(7,2),         -- NULL unless completed
    duration_s       INTEGER,              -- NULL unless completed
    fare_amount      DECIMAL(8,2),         -- rider-charged fare; NULL unless completed
    surge_multiplier DECIMAL(4,2),         -- applied surge (>= 1.00); NULL for some non-completed rows
    status           VARCHAR(20),
    payment_type     VARCHAR(16)           -- 'card' | 'cash' | 'wallet'; NULL for some non-completed rows
    -- PRIMARY KEY (trip_id)
    -- FOREIGN KEY (rider_id)        REFERENCES riders(rider_id)
    -- FOREIGN KEY (driver_id)       REFERENCES drivers(driver_id)
    -- FOREIGN KEY (vehicle_id)      REFERENCES vehicles(vehicle_id)
    -- FOREIGN KEY (pickup_zone_id)  REFERENCES geozones(zone_id)
    -- FOREIGN KEY (dropoff_zone_id) REFERENCES geozones(zone_id)
);

-- --------------------------------------------------------------------------
-- surge_events : published surge feed, one row each time a zone multiplier
--   changes. Events are NOT strictly ordered by effective_ts (late arrivals)
--   and may duplicate (zone_id, effective_ts). Use for as-of joins.
-- --------------------------------------------------------------------------
CREATE TABLE surge_events (
    surge_id     BIGINT     NOT NULL,      -- PK
    zone_id      INTEGER,                  -- FK -> geozones(zone_id)
    effective_ts TIMESTAMP,               -- when this multiplier took effect
    multiplier   DECIMAL(4,2),            -- published multiplier (>= 1.00)
    reason       VARCHAR(24)              -- 'demand' | 'weather' | 'event' | 'manual'; nullable
    -- PRIMARY KEY (surge_id)
    -- FOREIGN KEY (zone_id) REFERENCES geozones(zone_id)
);

-- --------------------------------------------------------------------------
-- trip_ratings : post-trip ratings. Only some completed trips are rated;
--   a trip may (rarely) have a duplicate rating from a double submission.
-- --------------------------------------------------------------------------
CREATE TABLE trip_ratings (
    rating_id    BIGINT     NOT NULL,      -- PK
    trip_id      BIGINT,                   -- FK -> trips(trip_id)
    rider_stars  INTEGER,                  -- rider's rating OF the driver (1..5); NULL if not given
    driver_stars INTEGER,                  -- driver's rating OF the rider (1..5); NULL if not given
    tip_amount   DECIMAL(6,2),             -- NULL = no tip info recorded; 0.00 = explicit zero tip
    rated_ts     TIMESTAMP
    -- PRIMARY KEY (rating_id)
    -- FOREIGN KEY (trip_id) REFERENCES trips(trip_id)
);

-- --------------------------------------------------------------------------
-- promotions : dimension of promo codes
-- --------------------------------------------------------------------------
CREATE TABLE promotions (
    promo_id       INTEGER   NOT NULL,     -- PK
    promo_code     VARCHAR(24),
    promo_type     VARCHAR(16),            -- 'percent' | 'flat' | 'first_ride'
    discount_value DECIMAL(6,2),           -- percent (0..100) OR flat currency amount, per promo_type
    valid_from     DATE,
    valid_to       DATE
    -- PRIMARY KEY (promo_id)
);

-- --------------------------------------------------------------------------
-- trip_promotions : bridge (M:N). A trip can carry multiple promos; a
--   (trip_id, promo_id) pair may (rarely) appear twice (double application).
--   Joining trips to this table fans out trip-grain measures like fare.
-- --------------------------------------------------------------------------
CREATE TABLE trip_promotions (
    application_id  BIGINT   NOT NULL,     -- PK (surrogate; duplicates live in trip_id/promo_id)
    trip_id         BIGINT,                -- FK -> trips(trip_id)
    promo_id        INTEGER,               -- FK -> promotions(promo_id)
    discount_amount DECIMAL(6,2),          -- actual currency discount applied
    applied_ts      TIMESTAMP
    -- PRIMARY KEY (application_id)
    -- FOREIGN KEY (trip_id)  REFERENCES trips(trip_id)
    -- FOREIGN KEY (promo_id) REFERENCES promotions(promo_id)
);
