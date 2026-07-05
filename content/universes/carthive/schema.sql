-- ============================================================================
-- CartHive universe -- portable schema (DataDojo)
-- ----------------------------------------------------------------------------
-- An e-commerce marketplace: a product catalog listed by third-party sellers,
-- customer orders and their line items, product returns, and a raw web-funnel
-- event stream (view -> add_to_cart -> checkout -> purchase) that also feeds
-- cohort/retention analysis.
--
-- Portable types only: INTEGER, BIGINT, DECIMAL(p,s), VARCHAR(n), DATE, TIMESTAMP.
-- Primary keys are declared inline. Foreign keys are written as comments only --
-- per-engine loaders decide whether/how to enforce them. Several columns are
-- deliberately NULL-bearing (guest checkouts, anonymous sessions, missing
-- attributes) and several relationships deliberately fan out (an order has many
-- items; an item may have several partial returns). See universe.md for the full
-- landmine inventory.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- categories: a two-level catalog taxonomy. Top-level "departments" have a NULL
-- parent_id; leaf categories point at their department. Some leaf categories
-- carry no products, and departments never hold products directly (products live
-- on leaves), so revenue for a department must roll up through its children.
-- ---------------------------------------------------------------------------
CREATE TABLE categories (
    category_id  INTEGER      NOT NULL,   -- surrogate key
    parent_id    INTEGER,                 -- NULL for a top-level department
    name         VARCHAR(60)  NOT NULL,
    PRIMARY KEY (category_id)
    -- FK: categories.parent_id -> categories.category_id  (self-reference, NULLable)
);

-- ---------------------------------------------------------------------------
-- sellers: third-party merchants listing on the marketplace. Some sellers never
-- make a sale; some are suspended or closed.
-- ---------------------------------------------------------------------------
CREATE TABLE sellers (
    seller_id    INTEGER      NOT NULL,
    seller_name  VARCHAR(80)  NOT NULL,
    country      VARCHAR(2)   NOT NULL,   -- ISO-3166 alpha-2
    joined_date  DATE         NOT NULL,
    status       VARCHAR(10)  NOT NULL,   -- 'active' | 'suspended' | 'closed'
    PRIMARY KEY (seller_id)
);

-- ---------------------------------------------------------------------------
-- products: catalog listings. list_price is drawn from a small set of common
-- price points, so many products share the same price (ranking ties). Popularity
-- is heavily skewed (power law): a few products drive most sales, and a long tail
-- never sells at all.
-- ---------------------------------------------------------------------------
CREATE TABLE products (
    product_id   INTEGER       NOT NULL,
    seller_id    INTEGER       NOT NULL,
    category_id  INTEGER       NOT NULL,  -- always a leaf category
    title        VARCHAR(120)  NOT NULL,
    list_price   DECIMAL(10,2) NOT NULL,
    launch_date  DATE          NOT NULL,
    is_active    INTEGER       NOT NULL,  -- 0 | 1
    PRIMARY KEY (product_id)
    -- FK: products.seller_id   -> sellers.seller_id
    -- FK: products.category_id -> categories.category_id
);

-- ---------------------------------------------------------------------------
-- customers: acquired accounts. customer_id links orders and events. A share of
-- customers are dormant (signed up, never browsed/bought). country,
-- acquisition_channel and birth_year are all NULL-bearing.
-- ---------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id          INTEGER      NOT NULL,
    signup_date          DATE         NOT NULL,
    country              VARCHAR(2),               -- NULLable (unknown)
    acquisition_channel  VARCHAR(20),              -- NULLable; e.g. 'organic','paid_search','social','referral','email'
    birth_year           INTEGER,                  -- NULLable (not disclosed)
    PRIMARY KEY (customer_id)
);

-- ---------------------------------------------------------------------------
-- orders: order headers. customer_id is NULL for guest checkouts (no account).
-- No order-level total is stored: order value must be derived from order_items,
-- and shipping_fee is a per-order attribute that double-counts if summed after a
-- join to order_items. Order status is a lifecycle enum.
-- ---------------------------------------------------------------------------
CREATE TABLE orders (
    order_id        BIGINT       NOT NULL,
    customer_id     INTEGER,                       -- NULL => guest checkout
    order_ts        TIMESTAMP    NOT NULL,
    status          VARCHAR(12)  NOT NULL,         -- 'placed'|'paid'|'shipped'|'delivered'|'cancelled'|'refunded'
    ship_country    VARCHAR(2),                    -- NULLable
    payment_method  VARCHAR(16),                   -- NULLable; 'card'|'paypal'|'wallet'|'giftcard'
    shipping_fee    DECIMAL(8,2) NOT NULL,         -- order-level; do NOT sum across item joins
    PRIMARY KEY (order_id)
    -- FK: orders.customer_id -> customers.customer_id  (NULLable; guest orders)
);

-- ---------------------------------------------------------------------------
-- order_items: order line items -- the primary large fact table. An order has
-- one or more lines. The same (order_id, product_id) can appear on two lines
-- (duplicate line / pipeline double-insert). discount is NULLable (NULL means no
-- discount, and must be coalesced before arithmetic). quantity is an INTEGER, so
-- naive integer division on quantities truncates.
-- ---------------------------------------------------------------------------
CREATE TABLE order_items (
    order_item_id  BIGINT        NOT NULL,
    order_id       BIGINT        NOT NULL,
    product_id     INTEGER       NOT NULL,
    seller_id      INTEGER       NOT NULL,   -- denormalized from products at sale time
    quantity       INTEGER       NOT NULL,   -- >= 1
    unit_price     DECIMAL(10,2) NOT NULL,   -- price charged (may differ from list_price)
    discount       DECIMAL(10,2),            -- NULLable per-line discount amount; NULL = none
    PRIMARY KEY (order_item_id)
    -- FK: order_items.order_id   -> orders.order_id
    -- FK: order_items.product_id -> products.product_id
    -- FK: order_items.seller_id  -> sellers.seller_id
);

-- ---------------------------------------------------------------------------
-- returns: product returns/refunds against a specific order line. Most lines are
-- never returned. A single line may be returned in more than one part (partial
-- returns across time) -> multiple rows per order_item_id (fan-out). reason is
-- NULLable. A small share of returns are timestamped before their order (clock
-- skew / backdated processing): late / out-of-order events.
-- ---------------------------------------------------------------------------
CREATE TABLE returns (
    return_id          BIGINT        NOT NULL,
    order_item_id      BIGINT        NOT NULL,
    return_ts          TIMESTAMP     NOT NULL,
    reason             VARCHAR(30),                -- NULLable
    quantity_returned  INTEGER       NOT NULL,     -- 1 .. line quantity
    refund_amount      DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (return_id)
    -- FK: returns.order_item_id -> order_items.order_item_id  (fan-out: many returns per item)
);

-- ---------------------------------------------------------------------------
-- events: the raw web-funnel event stream grouped by session_id. event_type is
-- one of 'view','add_to_cart','checkout','purchase'. customer_id is NULL for
-- anonymous (not-logged-in) sessions; product_id is NULL for non-product events
-- (e.g. a homepage view). order_id is populated only on 'purchase' events and
-- links to the resulting order. Analytics double-fires produce duplicate rows
-- (identical session/customer/product/type/ts, different event_id), and some
-- sessions have event timestamps out of logical funnel order.
-- ---------------------------------------------------------------------------
CREATE TABLE events (
    event_id     BIGINT       NOT NULL,
    session_id   BIGINT       NOT NULL,
    customer_id  INTEGER,                    -- NULL => anonymous session
    product_id   INTEGER,                    -- NULL => non-product event
    event_type   VARCHAR(16)  NOT NULL,      -- 'view'|'add_to_cart'|'checkout'|'purchase'
    event_ts     TIMESTAMP    NOT NULL,
    order_id     BIGINT,                     -- non-NULL only on 'purchase'
    PRIMARY KEY (event_id)
    -- FK: events.customer_id -> customers.customer_id  (NULLable)
    -- FK: events.product_id  -> products.product_id    (NULLable)
    -- FK: events.order_id    -> orders.order_id         (NULLable; set on purchase)
);
