-- DataDojo Knowledge Base — 5-layer medallion schema
-- L0 bronze: immutable verbatim truth   L1 silver: parsed structure
-- L2 semantic: concept DAG              L3 verification: execution ground truth
-- L4 gold: derived OJ problems          + pipeline_runs audit log
PRAGMA foreign_keys = ON;

-- ============ L0 BRONZE (append-only) ============
CREATE TABLE IF NOT EXISTS sources (
    id           INTEGER PRIMARY KEY,
    kind         TEXT NOT NULL CHECK (kind IN ('book','docs')),
    title        TEXT NOT NULL,
    locator      TEXT NOT NULL,            -- file path or URL
    version      TEXT,                     -- e.g. '2nd Edition' / 'PostgreSQL 18'
    sha256       TEXT NOT NULL,
    retrieved_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (kind, locator)
);

CREATE TABLE IF NOT EXISTS raw_spans (
    id         INTEGER PRIMARY KEY,
    source_id  INTEGER NOT NULL REFERENCES sources(id),
    label      TEXT NOT NULL,              -- e.g. 'recipe:6.14' / 'docs:queries.html'
    locator    TEXT NOT NULL,              -- 'pdf_pages:175-182' / 'url#anchor'
    raw_text   TEXT NOT NULL,              -- VERBATIM, never edited
    sha256     TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (source_id, label)
);

-- ============ L1 SILVER ============
CREATE TABLE IF NOT EXISTS recipes (
    id             TEXT PRIMARY KEY,       -- '6.14'
    chapter        INTEGER NOT NULL,
    number         INTEGER NOT NULL,       -- 14 (within chapter)
    title          TEXT NOT NULL,          -- verbatim from TOC
    book_page      INTEGER NOT NULL,
    span_id        INTEGER NOT NULL REFERENCES raw_spans(id),
    problem_text   TEXT,                   -- verbatim Problem section
    discussion_text TEXT,                  -- verbatim Discussion section
    parse_status   TEXT NOT NULL DEFAULT 'ok' CHECK (parse_status IN ('ok','partial','failed','skipped')),
    parse_notes    TEXT
);

CREATE TABLE IF NOT EXISTS solutions (
    id         INTEGER PRIMARY KEY,
    recipe_id  TEXT NOT NULL REFERENCES recipes(id),
    dialect    TEXT NOT NULL,              -- 'PostgreSQL','MySQL','Oracle','DB2','SQL Server','ALL'
    sql_code   TEXT NOT NULL,              -- verbatim from book
    position   INTEGER NOT NULL DEFAULT 1, -- order within the Solution section
    UNIQUE (recipe_id, dialect, position)
);

CREATE TABLE IF NOT EXISTS doc_sections (
    id        INTEGER PRIMARY KEY,
    span_id   INTEGER NOT NULL REFERENCES raw_spans(id),
    part      TEXT,                        -- 'Tutorial' / 'The SQL Language'
    chapter   TEXT NOT NULL,               -- '7. Queries'
    section   TEXT,                        -- '7.2.4'
    title     TEXT NOT NULL,
    url       TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS datasets (
    id         INTEGER PRIMARY KEY,
    name       TEXT NOT NULL UNIQUE,       -- 'EMP','DEPT','T1','T10','T100',...
    create_sql TEXT NOT NULL,
    seed_sql   TEXT NOT NULL,
    span_id    INTEGER REFERENCES raw_spans(id)
);

CREATE TABLE IF NOT EXISTS recipe_datasets (
    recipe_id  TEXT NOT NULL REFERENCES recipes(id),
    dataset_id INTEGER NOT NULL REFERENCES datasets(id),
    PRIMARY KEY (recipe_id, dataset_id)
);

-- ============ L2 SEMANTIC ============
CREATE TABLE IF NOT EXISTS concepts (
    id          TEXT PRIMARY KEY,          -- 'window-functions'
    name        TEXT NOT NULL,
    description TEXT
);

CREATE TABLE IF NOT EXISTS concept_edges (
    concept_id      TEXT NOT NULL REFERENCES concepts(id),
    prerequisite_id TEXT NOT NULL REFERENCES concepts(id),
    PRIMARY KEY (concept_id, prerequisite_id),
    CHECK (concept_id <> prerequisite_id)
);

CREATE TABLE IF NOT EXISTS recipe_concepts (
    recipe_id  TEXT NOT NULL REFERENCES recipes(id),
    concept_id TEXT NOT NULL REFERENCES concepts(id),
    is_primary INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (recipe_id, concept_id)
);

CREATE TABLE IF NOT EXISTS docsection_concepts (
    doc_section_id INTEGER NOT NULL REFERENCES doc_sections(id),
    concept_id     TEXT NOT NULL REFERENCES concepts(id),
    PRIMARY KEY (doc_section_id, concept_id)
);

-- ============ L3 VERIFICATION ============
CREATE TABLE IF NOT EXISTS verifications (
    id              INTEGER PRIMARY KEY,
    solution_id     INTEGER NOT NULL REFERENCES solutions(id),
    engine          TEXT NOT NULL,         -- 'sqlite','duckdb','postgres','mysql'
    engine_version  TEXT,
    status          TEXT NOT NULL CHECK (status IN ('pass','fail','error','unsupported','skipped')),
    captured_output TEXT,                  -- result set as CSV
    error_message   TEXT,
    executed_at     TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (solution_id, engine)
);

-- ============ L4 GOLD (derived, app-facing) ============
CREATE TABLE IF NOT EXISTS problems (
    id             INTEGER PRIMARY KEY,
    slug           TEXT NOT NULL UNIQUE,
    recipe_id      TEXT REFERENCES recipes(id),   -- provenance (NULL = fully original)
    title          TEXT NOT NULL,
    statement_md   TEXT NOT NULL,          -- authored real-world skin (DERIVED, not verbatim)
    difficulty     TEXT NOT NULL CHECK (difficulty IN ('white','blue','purple','brown','black')),
    dataset_sql    TEXT NOT NULL,          -- fixture: CREATE+INSERT for the problem's tables
    reference_sql  TEXT NOT NULL,          -- known-correct solution (verified)
    expected_csv   TEXT,                   -- computed by executing reference_sql
    order_matters  INTEGER NOT NULL DEFAULT 0,
    engines        TEXT NOT NULL DEFAULT 'sqlite,duckdb,postgres,mysql',
    created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ============ AUDIT ============
CREATE TABLE IF NOT EXISTS pipeline_runs (
    id          INTEGER PRIMARY KEY,
    stage       TEXT NOT NULL,
    started_at  TEXT NOT NULL DEFAULT (datetime('now')),
    finished_at TEXT,
    inputs      INTEGER,
    outputs     INTEGER,
    exceptions  TEXT,                      -- JSON list; '[]' means airtight
    script_sha256 TEXT
);

-- Full-text search over bronze for authoring-time lookup
CREATE VIRTUAL TABLE IF NOT EXISTS spans_fts USING fts5(
    label, raw_text, content='raw_spans', content_rowid='id'
);

CREATE TRIGGER IF NOT EXISTS spans_fts_insert AFTER INSERT ON raw_spans BEGIN
    INSERT INTO spans_fts(rowid, label, raw_text) VALUES (new.id, new.label, new.raw_text);
END;
