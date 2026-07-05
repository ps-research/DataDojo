-- ============================================================================
-- TickForge universe -- portable DDL
-- ----------------------------------------------------------------------------
-- An electronic securities exchange and its order-book. Instruments are quoted
-- (top-of-book), accounts route orders, orders execute into fills (trades),
-- daily end-of-month position snapshots record risk, and corporate actions
-- (splits, dividends, symbol changes) re-base the book.
--
-- Portable types only: INTEGER, BIGINT, DECIMAL(p,s), VARCHAR(n), DATE,
-- TIMESTAMP. Loaders map these per engine. Foreign keys are expressed as
-- comments; per-engine loaders add/relax constraints as the target requires.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- instruments : the tradable securities master (dimension).
-- ---------------------------------------------------------------------------
CREATE TABLE instruments (
    instrument_id   INTEGER        NOT NULL,   -- PK
    symbol          VARCHAR(12)    NOT NULL,   -- ticker, unique among active names
    company_name    VARCHAR(120)   NOT NULL,
    sector          VARCHAR(40),               -- NULLABLE: some names are unclassified
    currency        VARCHAR(3)     NOT NULL,   -- ISO-4217 (USD, EUR, GBP, JPY)
    listing_date    DATE           NOT NULL,
    delisting_date  DATE,                       -- NULLABLE: NULL while still listed
    tick_size       DECIMAL(10,5)  NOT NULL,   -- minimum price increment
    lot_size        INTEGER        NOT NULL,   -- round-lot share multiple
    status          VARCHAR(12)    NOT NULL,   -- ACTIVE / HALTED / DELISTED
    is_marginable   INTEGER        NOT NULL    -- 0/1 flag
    -- PRIMARY KEY (instrument_id)
);


-- ---------------------------------------------------------------------------
-- accounts : trading accounts / customers (dimension).
-- ---------------------------------------------------------------------------
CREATE TABLE accounts (
    account_id      INTEGER        NOT NULL,   -- PK
    account_code    VARCHAR(12)    NOT NULL,   -- external code, zero-padded (e.g. AC0000007)
    display_name    VARCHAR(80)    NOT NULL,
    account_type    VARCHAR(16)    NOT NULL,   -- RETAIL / INSTITUTIONAL / MARKET_MAKER
    region          VARCHAR(24)    NOT NULL,
    base_currency   VARCHAR(3)     NOT NULL,   -- ISO-4217 settlement currency
    opened_date     DATE           NOT NULL,
    risk_tier       INTEGER        NOT NULL    -- 1 (tightest) .. 5 (widest)
    -- PRIMARY KEY (account_id)
);


-- ---------------------------------------------------------------------------
-- trading_days : the exchange session calendar (dimension).
-- Contains ONLY real sessions -- weekends and holidays are absent, so the
-- absence of a date is itself information (calendar gaps).
-- ---------------------------------------------------------------------------
CREATE TABLE trading_days (
    session_date    DATE           NOT NULL,   -- PK
    session_seq     INTEGER        NOT NULL,   -- 1..N dense session index
    session_type    VARCHAR(10)    NOT NULL,   -- REGULAR / HALF_DAY
    open_ts         TIMESTAMP      NOT NULL,
    close_ts        TIMESTAMP      NOT NULL
    -- PRIMARY KEY (session_date)
);


-- ---------------------------------------------------------------------------
-- orders : order submissions and their lifecycle (fact).
-- ---------------------------------------------------------------------------
CREATE TABLE orders (
    order_id        BIGINT         NOT NULL,   -- PK
    account_id      INTEGER        NOT NULL,   -- FK -> accounts(account_id)
    instrument_id   INTEGER        NOT NULL,   -- FK -> instruments(instrument_id)
    side            VARCHAR(4)     NOT NULL,   -- BUY / SELL
    order_type      VARCHAR(8)     NOT NULL,   -- LIMIT / MARKET / STOP
    limit_price     DECIMAL(18,6),             -- NULLABLE: NULL for MARKET orders
    quantity        INTEGER        NOT NULL,   -- ordered share quantity (> 0)
    time_in_force   VARCHAR(4)     NOT NULL,   -- DAY / GTC / IOC / FOK
    status          VARCHAR(10)    NOT NULL,   -- NEW/PARTIAL/FILLED/CANCELLED/REJECTED
    created_at      TIMESTAMP      NOT NULL,
    updated_at      TIMESTAMP      NOT NULL,
    session_date    DATE           NOT NULL,   -- FK -> trading_days(session_date)
    parent_order_id BIGINT                     -- NULLABLE self-FK -> orders(order_id); NULL if top-level
    -- PRIMARY KEY (order_id)
);


-- ---------------------------------------------------------------------------
-- fills : executions / trades -- the primary fact table, largest by far.
-- A single order can produce many fills (fan-out). account_id, instrument_id
-- and side are denormalized from the parent order for query convenience.
-- ---------------------------------------------------------------------------
CREATE TABLE fills (
    fill_id         BIGINT         NOT NULL,   -- PK (surrogate)
    order_id        BIGINT         NOT NULL,   -- FK -> orders(order_id)
    instrument_id   INTEGER        NOT NULL,   -- FK -> instruments(instrument_id)
    account_id      INTEGER        NOT NULL,   -- FK -> accounts(account_id)
    side            VARCHAR(4)     NOT NULL,   -- BUY / SELL (from parent order)
    fill_price      DECIMAL(18,6)  NOT NULL,
    fill_quantity   INTEGER        NOT NULL,   -- shares in this execution (> 0)
    fill_time       TIMESTAMP      NOT NULL,   -- may skew before order.created_at or across midnight
    liquidity_flag  VARCHAR(6)     NOT NULL,   -- MAKER / TAKER
    venue           VARCHAR(8)     NOT NULL,   -- routing venue code
    fee             DECIMAL(12,6)  NOT NULL,   -- signed; negative = maker rebate
    session_date    DATE           NOT NULL    -- FK -> trading_days(session_date)
    -- PRIMARY KEY (fill_id)
);


-- ---------------------------------------------------------------------------
-- quotes : top-of-book market-data snapshots (fact).
-- ---------------------------------------------------------------------------
CREATE TABLE quotes (
    quote_id        BIGINT         NOT NULL,   -- PK
    instrument_id   INTEGER        NOT NULL,   -- FK -> instruments(instrument_id)
    quote_time      TIMESTAMP      NOT NULL,
    bid_price       DECIMAL(18,6),             -- NULLABLE: NULL when no bid present
    bid_size        INTEGER        NOT NULL,   -- may be 0 (one-sided book)
    ask_price       DECIMAL(18,6),             -- NULLABLE: NULL when no offer present
    ask_size        INTEGER        NOT NULL,   -- may be 0 (one-sided book)
    session_date    DATE           NOT NULL    -- FK -> trading_days(session_date)
    -- PRIMARY KEY (quote_id)
);


-- ---------------------------------------------------------------------------
-- positions : end-of-month risk snapshots per account+instrument (fact).
-- Emitted on the last session of each month for pairs active that month.
-- ---------------------------------------------------------------------------
CREATE TABLE positions (
    position_id     BIGINT         NOT NULL,   -- PK
    account_id      INTEGER        NOT NULL,   -- FK -> accounts(account_id)
    instrument_id   INTEGER        NOT NULL,   -- FK -> instruments(instrument_id)
    as_of_date      DATE           NOT NULL,   -- FK -> trading_days(session_date)
    quantity        INTEGER        NOT NULL,   -- signed net position; 0 = flat
    avg_cost        DECIMAL(18,6),             -- NULLABLE: NULL when flat
    mark_price      DECIMAL(18,6),             -- NULLABLE: NULL when no EOD quote
    realized_pnl    DECIMAL(18,4)  NOT NULL,   -- cumulative realized (incl. dividends)
    unrealized_pnl  DECIMAL(18,4)              -- NULLABLE: NULL when flat or unmarked
    -- PRIMARY KEY (position_id)
    -- Logical uniqueness (account_id, instrument_id, as_of_date) is NOT enforced;
    -- rare double-posted snapshots occur at full-landmine scales.
);


-- ---------------------------------------------------------------------------
-- corporate_actions : splits, dividends and symbol changes (fact/dimension).
-- ---------------------------------------------------------------------------
CREATE TABLE corporate_actions (
    action_id       INTEGER        NOT NULL,   -- PK
    instrument_id   INTEGER        NOT NULL,   -- FK -> instruments(instrument_id)
    action_type     VARCHAR(12)    NOT NULL,   -- SPLIT / DIVIDEND / SYMBOL_CHANGE
    ex_date         DATE           NOT NULL,   -- FK -> trading_days(session_date)
    record_date     DATE           NOT NULL,
    split_ratio     VARCHAR(8),                -- NULLABLE: 'a:b' for SPLIT only, else NULL
    cash_amount     DECIMAL(12,6),             -- NULLABLE: per-share cash for DIVIDEND only
    new_symbol      VARCHAR(12),               -- NULLABLE: for SYMBOL_CHANGE only
    announced_at    TIMESTAMP      NOT NULL    -- may post-date ex_date (retroactive) at full scale
    -- PRIMARY KEY (action_id)
);
