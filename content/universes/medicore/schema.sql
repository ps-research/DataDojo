-- ============================================================================
-- MediCore universe -- portable schema (DataDojo)
-- Theme: hospital operations -- admissions, wards, staffing rosters,
--        procedures, bed transfers, readmissions.
--
-- Conventions
--   * Types are restricted to the portable set the loaders understand:
--       INTEGER, BIGINT, DECIMAL(p,s), VARCHAR(n), DATE, TIMESTAMP.
--     No engine-specific types appear here; per-engine loaders map them.
--   * TIMESTAMP values are emitted by the generator as 'YYYY-MM-DD HH:MM:SS'
--     and DATE values as 'YYYY-MM-DD'.
--   * An EMPTY field in a CSV denotes SQL NULL. The loaders convert an empty
--     column to NULL on import; a literal empty string is never stored.
--   * PRIMARY KEYs are declared inline. FOREIGN KEYs are documented as
--     comments only -- the loaders apply (or relax) constraints per engine so
--     that intentional data-quality landmines survive the load.
--   * A small, DOCUMENTED set of rows breaks referential integrity on purpose
--     (e.g. a primary_diagnosis_code that is absent from `diagnoses`); these
--     are landmines, not bugs. See universe.md for the full inventory.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- patients -- one row per registered patient (dimension)
-- ----------------------------------------------------------------------------
CREATE TABLE patients (
    patient_id       INTEGER      NOT NULL,   -- surrogate key
    mrn              VARCHAR(20)  NOT NULL,    -- medical record number; NOT unique:
                                              --   patient-merge events reuse an MRN
    birth_date       DATE,                     -- nullable (unknown DOB); includes 29 Feb births
    sex              VARCHAR(1),               -- 'M','F','U'; nullable
    blood_type       VARCHAR(3),               -- e.g. 'O+','AB-'; nullable
    postal_code      VARCHAR(10),              -- nullable
    registered_date  DATE         NOT NULL,
    deceased_date    DATE,                     -- mostly NULL; set only for deaths on file
    PRIMARY KEY (patient_id)
);


-- ----------------------------------------------------------------------------
-- wards -- physical care units (dimension)
-- ----------------------------------------------------------------------------
CREATE TABLE wards (
    ward_id               INTEGER     NOT NULL,
    ward_code             VARCHAR(10) NOT NULL,
    ward_name             VARCHAR(60) NOT NULL,
    department            VARCHAR(40) NOT NULL,  -- grouping used by most reports
    ward_type             VARCHAR(20) NOT NULL,  -- 'ICU','ED','SURGICAL','GENERAL','MATERNITY'
    bed_capacity          INTEGER     NOT NULL,  -- can be 0 for a decommissioned/mis-recorded unit
                                                 --   (division-by-zero trap for occupancy rates)
    min_nurses_per_shift  INTEGER     NOT NULL,  -- required nurse coverage per shift slot (0 = none)
    opened_date           DATE        NOT NULL,
    closed_date           DATE,                  -- mostly NULL
    PRIMARY KEY (ward_id)
);


-- ----------------------------------------------------------------------------
-- staff -- clinical staff (dimension)
-- ----------------------------------------------------------------------------
CREATE TABLE staff (
    staff_id          INTEGER      NOT NULL,
    staff_code        VARCHAR(12)  NOT NULL,
    full_name         VARCHAR(80)  NOT NULL,
    role              VARCHAR(20)  NOT NULL,   -- 'NURSE','PHYSICIAN','SURGEON','RESIDENT','TECH'
    department        VARCHAR(40)  NOT NULL,
    home_ward_id      INTEGER,                 -- FK -> wards(ward_id); NULL for float/agency staff
    hire_date         DATE         NOT NULL,
    termination_date  DATE,                    -- mostly NULL
    fte               DECIMAL(3,2) NOT NULL,   -- 0.00..1.00; 0.00 = on extended leave
                                               --   (division-by-zero trap for per-FTE metrics)
    PRIMARY KEY (staff_id)
);


-- ----------------------------------------------------------------------------
-- diagnoses -- coded diagnosis reference (dimension)
-- ----------------------------------------------------------------------------
CREATE TABLE diagnoses (
    diagnosis_code   VARCHAR(10)  NOT NULL,
    description      VARCHAR(120) NOT NULL,
    category         VARCHAR(40)  NOT NULL,   -- body-system chapter
    chronic_flag     INTEGER      NOT NULL,   -- 0 / 1
    severity_weight  DECIMAL(4,2) NOT NULL,   -- comorbidity weight
    PRIMARY KEY (diagnosis_code)
);


-- ----------------------------------------------------------------------------
-- admissions -- one row per inpatient encounter (primary fact)
--   This is the readmission spine. It is intentionally NOT time-sorted, and
--   admission_id is NOT monotonic with admit_ts across patients.
-- ----------------------------------------------------------------------------
CREATE TABLE admissions (
    admission_id            BIGINT       NOT NULL,
    patient_id              INTEGER      NOT NULL,  -- FK -> patients(patient_id)
    ward_id                 INTEGER      NOT NULL,  -- FK -> wards(ward_id) (admitting ward)
    attending_staff_id      INTEGER,                -- FK -> staff(staff_id); NULL when unassigned
                                                    --   (NULL-in-NOT-IN trap)
    admit_ts                TIMESTAMP    NOT NULL,
    discharge_ts            TIMESTAMP,              -- NULL for a still-open (in-house) stay
    admit_type              VARCHAR(12)  NOT NULL,  -- 'EMERGENCY','ELECTIVE','TRANSFER','NEWBORN'
    admit_source            VARCHAR(20)  NOT NULL,  -- 'ED','REFERRAL','TRANSFER','CLINIC'
    discharge_disposition   VARCHAR(20),            -- 'HOME','SNF','EXPIRED','AMA','TRANSFER'; NULL if open
    primary_diagnosis_code  VARCHAR(10),            -- FK -> diagnoses(diagnosis_code);
                                                    --   NULL (undocumented) OR an orphan code (data entry)
    total_charge            DECIMAL(12,2),          -- NULL or 0.00 possible
    PRIMARY KEY (admission_id)
);


-- ----------------------------------------------------------------------------
-- procedures -- procedures performed during an admission (fact; child of admissions)
--   One admission has 0..N procedures -> join fan-out risk.
-- ----------------------------------------------------------------------------
CREATE TABLE procedures (
    procedure_id       BIGINT       NOT NULL,
    admission_id       BIGINT       NOT NULL,   -- FK -> admissions(admission_id)
    procedure_code     VARCHAR(10)  NOT NULL,
    procedure_name     VARCHAR(80)  NOT NULL,
    performed_ts       TIMESTAMP,               -- NULL, or occasionally before admit / after discharge
                                                --   (late / out-of-order event trap)
    primary_surgeon_id INTEGER,                 -- FK -> staff(staff_id); NULL when not recorded
    duration_min       INTEGER,                 -- NULL or 0 possible
    is_billable        INTEGER      NOT NULL,   -- 0 / 1
    PRIMARY KEY (procedure_id)
);


-- ----------------------------------------------------------------------------
-- bed_transfers -- ward-to-ward movements within an admission (fact)
--   The first placement of a stay has from_ward_id = NULL.
--   seq_no is the intended order, but transfer_ts can tie or arrive out of order.
-- ----------------------------------------------------------------------------
CREATE TABLE bed_transfers (
    transfer_id    BIGINT      NOT NULL,
    admission_id   BIGINT      NOT NULL,   -- FK -> admissions(admission_id)
    seq_no         INTEGER     NOT NULL,   -- intended step number within the stay
    from_ward_id   INTEGER,                -- FK -> wards(ward_id); NULL for the initial placement
    to_ward_id     INTEGER     NOT NULL,   -- FK -> wards(ward_id)
    transfer_ts    TIMESTAMP   NOT NULL,   -- ties and out-of-order values occur
    reason         VARCHAR(30),            -- nullable
    PRIMARY KEY (transfer_id)
);


-- ----------------------------------------------------------------------------
-- roster_shifts -- staffing roster: one row per assigned shift slot (fact)
--   NIGHT shifts cross midnight (scheduled_end is on the following calendar day).
--   A (ward_id, shift_date, shift_type) slot may have ZERO rows -> a coverage gap
--   that INNER joins silently miss (empty-group trap).
-- ----------------------------------------------------------------------------
CREATE TABLE roster_shifts (
    shift_id         BIGINT       NOT NULL,
    staff_id         INTEGER      NOT NULL,   -- FK -> staff(staff_id)
    ward_id          INTEGER      NOT NULL,   -- FK -> wards(ward_id)
    shift_date       DATE         NOT NULL,   -- the calendar date the shift STARTS on
    shift_type       VARCHAR(6)   NOT NULL,   -- 'DAY','NIGHT','SWING'
    scheduled_start  TIMESTAMP    NOT NULL,
    scheduled_end    TIMESTAMP    NOT NULL,   -- NIGHT: next calendar day
    scheduled_hours  DECIMAL(4,2) NOT NULL,
    actual_hours     DECIMAL(4,2),            -- NULL for a no-show; 0.00 possible; may exceed scheduled
    status           VARCHAR(10)  NOT NULL,   -- 'WORKED','NOSHOW','CANCELLED','SWAPPED'
    PRIMARY KEY (shift_id)
);

-- ============================================================================
-- Foreign-key summary (enforced by loaders per engine; here for documentation)
--   admissions.patient_id             -> patients(patient_id)
--   admissions.ward_id                -> wards(ward_id)
--   admissions.attending_staff_id     -> staff(staff_id)        [nullable]
--   admissions.primary_diagnosis_code -> diagnoses(diagnosis_code) [nullable, some orphan]
--   procedures.admission_id           -> admissions(admission_id)
--   procedures.primary_surgeon_id     -> staff(staff_id)        [nullable]
--   bed_transfers.admission_id        -> admissions(admission_id)
--   bed_transfers.from_ward_id        -> wards(ward_id)         [nullable]
--   bed_transfers.to_ward_id          -> wards(ward_id)
--   roster_shifts.staff_id            -> staff(staff_id)
--   roster_shifts.ward_id             -> wards(ward_id)
--   staff.home_ward_id                -> wards(ward_id)         [nullable]
-- ============================================================================
