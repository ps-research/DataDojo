#!/usr/bin/env python3
# ============================================================================
# MediCore universe -- deterministic, seeded data generator (DataDojo)
#
#   python3 generator.py --seed N --scale {sample|blue|purple|black|red} --out DIR
#
# Emits one RFC4180 CSV per table into DIR (header row on each). Given the same
# --seed and --scale the output is byte-identical: all randomness flows through a
# single random.Random(seed); no global random and no wall-clock are ever used.
#
# Memory model: dimension tables (wards, staff, diagnoses) are small at every
# scale and are held in memory. The large fact tables (patients, admissions,
# procedures, bed_transfers, roster_shifts) are STREAMED row-by-row straight to
# their CSV writers -- the generator never accumulates millions of rows.
#
# Landmines are planted deliberately and are documented in universe.md. A handful
# of them are GUARANTEED (forced on low-index rows) so that even the tiny `sample`
# fixture demonstrates every trap family.
#
# Pure standard library only: argparse, csv, os, random, math, datetime.
# ============================================================================

import argparse
import csv
import math
import os
import random
from datetime import date, datetime, timedelta

# ----------------------------------------------------------------------------
# Scale configuration. Row volumes are approximate; the belt caps are:
#   sample ~ hundreds total | blue <=50k | purple <=500k | black 1M-5M | red 5M-10M
# (measured on the largest fact table; the others scale proportionally).
# Every window includes 29 Feb 2024 and the reporting month 2024-02.
# ----------------------------------------------------------------------------
SCALES = {
    "sample": dict(patients=40,      staff=12,   wards=6,   sim_start=(2024, 2, 1),  days=35,   slot_mean=0.6),
    "blue":   dict(patients=9000,    staff=130,  wards=20,  sim_start=(2023, 6, 1),  days=365,  slot_mean=1.3),
    "purple": dict(patients=90000,   staff=420,  wards=40,  sim_start=(2022, 6, 1),  days=730,  slot_mean=2.0),
    "black":  dict(patients=680000,  staff=2600, wards=80,  sim_start=(2021, 6, 1),  days=1095, slot_mean=5.5),
    "red":    dict(patients=1500000, staff=6200, wards=120, sim_start=(2020, 6, 1),  days=1460, slot_mean=14.0),
}

# Ward templates. The first six are guaranteed to appear even at `sample`
# (wards=6). Order matters: index 3 is force-decommissioned (capacity 0) and
# 'Palliative Care' (index 5) discharges are all EXPIRED (a department whose
# readmission denominator is zero).
WARD_TEMPLATES = [
    # (department,          ward_type,   base_capacity, base_min_nurses)
    ("Cardiology",          "SURGICAL",  32, 4),
    ("Emergency",           "ED",        40, 6),
    ("Intensive Care",      "ICU",       18, 5),
    ("General Medicine",    "GENERAL",   36, 3),   # index 3 -> capacity forced to 0
    ("Maternity",           "MATERNITY", 28, 3),
    ("Palliative Care",     "GENERAL",   16, 2),   # index 5 -> all discharges EXPIRED
    ("Orthopedics",         "SURGICAL",  30, 3),
    ("Oncology",            "GENERAL",   26, 3),
    ("Neurology",           "GENERAL",   24, 3),
    ("Pediatrics",          "GENERAL",   30, 3),
    ("Nephrology",          "GENERAL",   22, 2),
    ("Pulmonology",         "GENERAL",   24, 3),
]

ROLES = ["NURSE", "PHYSICIAN", "SURGEON", "RESIDENT", "TECH"]
ROLE_WEIGHTS = [55, 15, 10, 12, 8]

BLOOD_TYPES = ["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"]
BLOOD_WEIGHTS = [37, 6, 27, 5, 15, 3, 5, 2]
SEXES = ["M", "F", "U"]

ADMIT_TYPES = ["EMERGENCY", "ELECTIVE", "TRANSFER", "NEWBORN"]
ADMIT_SOURCES = ["ED", "REFERRAL", "TRANSFER", "CLINIC"]
DISPOSITIONS = ["HOME", "SNF", "AMA", "TRANSFER", "EXPIRED"]
DISPO_WEIGHTS = [70, 12, 4, 8, 6]

SHIFT_TYPES = ["DAY", "NIGHT", "SWING"]
SHIFT_HOURS = {"DAY": (7, 19), "NIGHT": (19, 7), "SWING": (15, 23)}

# (code, description, category, chronic_flag, severity_weight)
DIAGNOSES = [
    ("I10",  "Essential hypertension",                "Circulatory",   1, 0.30),
    ("I25",  "Chronic ischaemic heart disease",       "Circulatory",   1, 1.20),
    ("I48",  "Atrial fibrillation and flutter",       "Circulatory",   1, 1.05),
    ("I50",  "Heart failure",                         "Circulatory",   1, 2.40),
    ("I21",  "Acute myocardial infarction",           "Circulatory",   0, 3.10),
    ("I63",  "Cerebral infarction",                   "Circulatory",   0, 3.50),
    ("E11",  "Type 2 diabetes mellitus",              "Endocrine",     1, 0.90),
    ("E10",  "Type 1 diabetes mellitus",              "Endocrine",     1, 1.10),
    ("E66",  "Obesity",                               "Endocrine",     1, 0.40),
    ("E87",  "Fluid and electrolyte disorder",        "Endocrine",     0, 0.80),
    ("J18",  "Pneumonia, organism unspecified",       "Respiratory",   0, 1.60),
    ("J44",  "Chronic obstructive pulmonary disease", "Respiratory",   1, 1.90),
    ("J45",  "Asthma",                                "Respiratory",   1, 0.70),
    ("J96",  "Respiratory failure",                   "Respiratory",   0, 3.20),
    ("N17",  "Acute kidney failure",                  "Genitourinary", 0, 2.10),
    ("N18",  "Chronic kidney disease",                "Genitourinary", 1, 1.70),
    ("N39",  "Urinary tract infection",               "Genitourinary", 0, 0.60),
    ("K35",  "Acute appendicitis",                    "Digestive",     0, 1.30),
    ("K70",  "Alcoholic liver disease",               "Digestive",     1, 2.00),
    ("K80",  "Cholelithiasis",                        "Digestive",     0, 0.90),
    ("K92",  "Gastrointestinal haemorrhage",          "Digestive",     0, 1.80),
    ("A41",  "Sepsis",                                "Infectious",    0, 3.60),
    ("B96",  "Bacterial agent infection",             "Infectious",    0, 1.10),
    ("C50",  "Malignant neoplasm of breast",          "Neoplasm",      1, 2.50),
    ("C34",  "Malignant neoplasm of bronchus/lung",   "Neoplasm",      1, 2.90),
    ("C18",  "Malignant neoplasm of colon",           "Neoplasm",      1, 2.70),
    ("C61",  "Malignant neoplasm of prostate",        "Neoplasm",      1, 1.80),
    ("D64",  "Anaemia, unspecified",                  "Blood",         1, 0.70),
    ("D69",  "Purpura and haemorrhagic conditions",   "Blood",         0, 1.20),
    ("M17",  "Osteoarthritis of knee",                "Musculoskeletal", 1, 0.80),
    ("M16",  "Osteoarthritis of hip",                 "Musculoskeletal", 1, 0.85),
    ("M54",  "Dorsalgia",                             "Musculoskeletal", 1, 0.50),
    ("S72",  "Fracture of femur",                     "Injury",        0, 2.20),
    ("S06",  "Intracranial injury",                   "Injury",        0, 3.00),
    ("T81",  "Complication of a procedure",           "Injury",        0, 1.90),
    ("O80",  "Single spontaneous delivery",           "Pregnancy",     0, 0.40),
    ("O82",  "Delivery by caesarean section",         "Pregnancy",     0, 1.00),
    ("O60",  "Preterm labour",                        "Pregnancy",     0, 1.40),
    ("P07",  "Disorders of preterm newborn",          "Perinatal",     0, 1.60),
    ("R07",  "Chest pain",                            "Symptoms",      0, 0.60),
    ("R55",  "Syncope and collapse",                  "Symptoms",      0, 0.70),
    ("R56",  "Convulsions",                           "Symptoms",      0, 1.00),
    ("G40",  "Epilepsy",                              "Nervous",       1, 1.30),
    ("G20",  "Parkinson disease",                     "Nervous",       1, 1.50),
    ("F03",  "Dementia, unspecified",                 "Mental",        1, 1.40),
    ("F10",  "Alcohol use disorder",                  "Mental",        1, 1.10),
    ("L03",  "Cellulitis",                            "Skin",          0, 0.90),
    ("Z51",  "Encounter for other aftercare",         "Factors",       0, 0.30),
    ("Z38",  "Liveborn infant",                       "Factors",       0, 0.20),
]
# A fabricated code deliberately ABSENT from the table above (orphan / NOT-IN trap).
ORPHAN_DIAG = "Z999"

# (code, name, base_duration_min)
PROCEDURES = [
    ("P001", "Percutaneous coronary intervention", 95),
    ("P002", "Coronary artery bypass graft",       240),
    ("P003", "Cardiac catheterisation",            60),
    ("P004", "Appendectomy",                       55),
    ("P005", "Cholecystectomy",                    80),
    ("P006", "Hip replacement",                    120),
    ("P007", "Knee replacement",                   110),
    ("P008", "Caesarean section",                  50),
    ("P009", "Colonoscopy",                        35),
    ("P010", "Upper GI endoscopy",                 30),
    ("P011", "Haemodialysis session",              210),
    ("P012", "Mechanical ventilation setup",       25),
    ("P013", "Central line insertion",             30),
    ("P014", "Blood transfusion",                  90),
    ("P015", "CT scan of head",                    20),
    ("P016", "MRI of spine",                       45),
    ("P017", "Wound debridement",                  40),
    ("P018", "Lumbar puncture",                    25),
    ("P019", "Thrombolysis administration",        30),
    ("P020", "Craniotomy",                         200),
]

FIRST_NAMES = ["Aisha", "Ben", "Carla", "David", "Elena", "Farid", "Grace", "Hassan",
               "Ivy", "James", "Kira", "Liam", "Mona", "Noah", "Olga", "Priya",
               "Quentin", "Rosa", "Samir", "Tara", "Umar", "Vera", "Wei", "Ximena",
               "Yusuf", "Zoe", "Anita", "Bruno", "Chen", "Diego"]
LAST_NAMES = ["Adams", "Bello", "Cortez", "Diallo", "Evans", "Fischer", "Gupta",
              "Haddad", "Ito", "Jensen", "Kaur", "Larsen", "Mensah", "Novak",
              "Owens", "Patel", "Quinn", "Ricci", "Sato", "Torres", "Ueda",
              "Volkov", "Walsh", "Xu", "Yates", "Zimmer", "Abbas", "Blum",
              "Costa", "Dumas"]


def money(x):
    """Format a DECIMAL(p,2) value deterministically, or return None for NULL."""
    return None if x is None else "%.2f" % x


def dec2(x):
    return None if x is None else "%.2f" % x


def ts(dt):
    return None if dt is None else dt.strftime("%Y-%m-%d %H:%M:%S")


def ds(d):
    return None if d is None else d.strftime("%Y-%m-%d")


class Generator:
    def __init__(self, seed, scale, out_dir):
        self.rng = random.Random(seed)
        self.cfg = SCALES[scale]
        self.scale = scale
        self.out = out_dir
        self.win_start = datetime(*self.cfg["sim_start"])
        self.win_days = self.cfg["days"]
        self.win_end = self.win_start + timedelta(days=self.win_days)
        # populated by write_wards / write_staff
        self.wards = []          # list of dicts
        self.staff = []          # list of dicts
        self.surgeon_ids = []    # staff eligible to lead a procedure
        self.nurse_ids = []      # staff pool for rostering (nurse-biased)
        self.recent_mrns = []    # bounded ring buffer for duplicate-MRN planting
        # global monotonic surrogate-key counters
        self._adm = 0
        self._proc = 0
        self._xfer = 0
        self._shift = 0

    # -- helpers ------------------------------------------------------------
    def _writer(self, name, header):
        f = open(os.path.join(self.out, name + ".csv"), "w", newline="")
        w = csv.writer(f)  # default RFC4180 dialect: minimal quoting, CRLF
        w.writerow(header)
        return f, w

    def _rand_dt(self, lo_frac=0.0, hi_frac=1.0):
        """A random timestamp inside the simulation window (fractional sub-range)."""
        span = self.win_days * 86400
        lo = int(span * lo_frac)
        hi = int(span * hi_frac)
        secs = self.rng.randint(lo, max(lo, hi - 1))
        return self.win_start + timedelta(seconds=secs)

    # -- dimensions ---------------------------------------------------------
    def write_wards(self):
        n = self.cfg["wards"]
        f, w = self._writer("wards", [
            "ward_id", "ward_code", "ward_name", "department", "ward_type",
            "bed_capacity", "min_nurses_per_shift", "opened_date", "closed_date"])
        for i in range(n):
            dept, wtype, cap, minn = WARD_TEMPLATES[i % len(WARD_TEMPLATES)]
            wid = i + 1
            # GUARANTEED landmine: ward index 3 is decommissioned -> capacity 0.
            if i == 3:
                cap, minn = 0, 0
            else:
                cap = cap + self.rng.randint(-4, 8)
            code = "W%02d" % wid
            name = "%s Unit %d" % (dept, (i // len(WARD_TEMPLATES)) + 1)
            opened = date(2010, 1, 1) + timedelta(days=self.rng.randint(0, 4000))
            closed = None
            self.wards.append(dict(ward_id=wid, department=dept, ward_type=wtype,
                                   capacity=cap, min_nurses=minn,
                                   palliative=(dept == "Palliative Care")))
            w.writerow([wid, code, name, dept, wtype, cap, minn, ds(opened), ds(closed)])
        f.close()

    def write_staff(self):
        n = self.cfg["staff"]
        depts = [wt[0] for wt in WARD_TEMPLATES[:self.cfg["wards"]]]
        ward_by_dept = {}
        for wd in self.wards:
            ward_by_dept.setdefault(wd["department"], []).append(wd["ward_id"])
        f, w = self._writer("staff", [
            "staff_id", "staff_code", "full_name", "role", "department",
            "home_ward_id", "hire_date", "termination_date", "fte"])
        for i in range(n):
            sid = i + 1
            role = self.rng.choices(ROLES, weights=ROLE_WEIGHTS, k=1)[0]
            dept = self.rng.choice(depts)
            name = "%s %s" % (self.rng.choice(FIRST_NAMES), self.rng.choice(LAST_NAMES))
            code = "S%05d" % sid
            homes = ward_by_dept.get(dept, [])
            home = self.rng.choice(homes) if (homes and self.rng.random() > 0.10) else None
            hire = date(2008, 1, 1) + timedelta(days=self.rng.randint(0, 5800))
            term = None
            if self.rng.random() < 0.06:
                term = hire + timedelta(days=self.rng.randint(400, 4000))
            fte = self.rng.choice([1.00, 1.00, 1.00, 0.80, 0.75, 0.60, 0.50, 0.40])
            # GUARANTEED landmine: staff index 2 is on leave -> fte 0.00.
            if i == 2:
                fte = 0.00
            self.staff.append(dict(staff_id=sid, role=role, department=dept))
            if role in ("SURGEON", "PHYSICIAN", "RESIDENT"):
                self.surgeon_ids.append(sid)
            if role == "NURSE":
                self.nurse_ids.append(sid)
            w.writerow([sid, code, name, role, dept, home, ds(hire), ds(term), dec2(fte)])
        f.close()
        # Fallbacks so small scales always have someone to assign.
        if not self.surgeon_ids:
            self.surgeon_ids = [s["staff_id"] for s in self.staff]
        if not self.nurse_ids:
            self.nurse_ids = [s["staff_id"] for s in self.staff]

    def write_diagnoses(self):
        f, w = self._writer("diagnoses", [
            "diagnosis_code", "description", "category", "chronic_flag", "severity_weight"])
        for code, desc, cat, chronic, weight in DIAGNOSES:
            w.writerow([code, desc, cat, chronic, dec2(weight)])
        f.close()

    # -- patient / admission / procedure / transfer stream ------------------
    def _adm_count(self):
        r = self.rng.random()
        if r < 0.50:
            return 1
        if r < 0.75:
            return 2
        if r < 0.88:
            return 3
        if r < 0.95:
            return 4
        if r < 0.98:
            return self.rng.randint(5, 7)
        return self.rng.randint(8, 20)          # frequent-flyer tail (power law)

    def _pick_ward(self):
        wd = self.rng.choice(self.wards)
        return wd

    def _gap_days(self):
        r = self.rng.random()
        if r < 0.10:
            return 30                             # exact 30-day boundary (inclusive/exclusive trap)
        if r < 0.35:
            return self.rng.randint(1, 29)        # clearly within
        if r < 0.45:
            return self.rng.randint(31, 45)       # just outside
        return self.rng.randint(46, 400)          # unrelated later stay

    def write_facts(self):
        pf, pw = self._writer("patients", [
            "patient_id", "mrn", "birth_date", "sex", "blood_type",
            "postal_code", "registered_date", "deceased_date"])
        af, aw = self._writer("admissions", [
            "admission_id", "patient_id", "ward_id", "attending_staff_id",
            "admit_ts", "discharge_ts", "admit_type", "admit_source",
            "discharge_disposition", "primary_diagnosis_code", "total_charge"])
        cf, cw = self._writer("procedures", [
            "procedure_id", "admission_id", "procedure_code", "procedure_name",
            "performed_ts", "primary_surgeon_id", "duration_min", "is_billable"])
        tf, tw = self._writer("bed_transfers", [
            "transfer_id", "admission_id", "seq_no", "from_ward_id",
            "to_ward_id", "transfer_ts", "reason"])

        n_patients = self.cfg["patients"]
        for i in range(n_patients):
            pid = i + 1
            self._emit_patient(pw, pid, i)
            self._emit_admissions_for(aw, cw, tw, pid, i)

        for fh in (pf, af, cf, tf):
            fh.close()

    def _emit_patient(self, pw, pid, i):
        # MRN, with a bounded duplicate-MRN (patient merge) plant.
        if i > 0 and self.recent_mrns and self.rng.random() < 0.006:
            mrn = self.rng.choice(self.recent_mrns)            # duplicate business key
        else:
            mrn = "MRN%08d" % (self.rng.randint(1, 90000000))
        if len(self.recent_mrns) < 64:
            self.recent_mrns.append(mrn)

        birth = date(1930, 1, 1) + timedelta(days=self.rng.randint(0, 34000))
        if i == 2:
            birth = date(2000, 2, 29)                           # GUARANTEED leap-day birth
        if self.rng.random() < 0.03:
            birth = None                                        # unknown DOB (NULL)
        sex = self.rng.choices(SEXES, weights=[48, 48, 4], k=1)[0]
        if self.rng.random() < 0.02:
            sex = None
        blood = self.rng.choices(BLOOD_TYPES, weights=BLOOD_WEIGHTS, k=1)[0]
        if self.rng.random() < 0.05:
            blood = None
        postal = "%05d" % self.rng.randint(1000, 99999)
        if self.rng.random() < 0.04:
            postal = None
        reg = date(2012, 1, 1) + timedelta(days=self.rng.randint(0, 4300))
        deceased = None
        if self.rng.random() < 0.04:
            deceased = reg + timedelta(days=self.rng.randint(30, 4000))
        pw.writerow([pid, mrn, ds(birth), sex, blood, postal, ds(reg), ds(deceased)])

    def _emit_admissions_for(self, aw, cw, tw, pid, i):
        n_adm = self._adm_count()
        if i == 0:
            n_adm = max(2, n_adm)      # patient 0 always carries the guaranteed 30-day readmit pair
        prev_dis = None
        for k in range(n_adm):
            wd = self._pick_ward()
            atype = None
            dispo = None
            dis_dt = None
            forced = False

            # GUARANTEED readmission boundary on patient 0: two stays exactly 30
            # days apart, same department, both true (non-transfer) encounters.
            if i == 0 and k == 0:
                wd = self.wards[0]
                admit_dt = datetime(2024, 2, 1, 9, 0, 0)
                dis_dt = admit_dt + timedelta(days=3)
                atype, dispo = "ELECTIVE", "HOME"
                forced = True
            elif i == 0 and k == 1 and prev_dis is not None:
                wd = self.wards[0]
                admit_dt = prev_dis + timedelta(days=30)       # index-discharge + exactly 30d
                dis_dt = admit_dt + timedelta(days=1)
                atype, dispo = "EMERGENCY", "HOME"
                forced = True
            else:
                # -- admit timestamp --
                if k == 0 or prev_dis is None:
                    admit_dt = self._rand_dt(0.0, 0.72)
                else:
                    gap = self._gap_days()
                    admit_dt = prev_dis + timedelta(days=gap,
                                                    hours=self.rng.randint(0, 23))
                    if admit_dt >= self.win_end:
                        break
                    # readmissions within the window are usually EMERGENCY, but a
                    # deliberate slice are ELECTIVE (planned) or TRANSFER (must not count).
                    if gap <= 30:
                        atype = self.rng.choices(
                            ["EMERGENCY", "ELECTIVE", "TRANSFER"], weights=[70, 18, 12], k=1)[0]
                if atype is None:
                    atype = self.rng.choices(ADMIT_TYPES, weights=[52, 30, 12, 6], k=1)[0]

                # -- length of stay / discharge --
                los_choice = self.rng.random()
                if los_choice < 0.08:
                    los_h = self.rng.randint(0, 6)             # same-day / very short (0-day LOS)
                elif los_choice < 0.70:
                    los_h = self.rng.randint(12, 168)          # 0.5 - 7 days
                elif los_choice < 0.93:
                    los_h = self.rng.randint(168, 480)         # 1 - 3 weeks
                else:
                    los_h = self.rng.randint(480, 1600)        # long stay
                dis_dt = admit_dt + timedelta(hours=los_h)
                # Open stays (no discharge): more likely near the window end.
                p_open = 0.03 + (0.25 if admit_dt > self.win_end - timedelta(days=20) else 0.0)
                is_open = self.rng.random() < p_open
                if wd["palliative"]:
                    dispo = "EXPIRED"                          # palliative dept -> all deaths
                    is_open = False
                elif is_open:
                    dispo = None
                else:
                    dispo = self.rng.choices(DISPOSITIONS, weights=DISPO_WEIGHTS, k=1)[0]
                if is_open:
                    dis_dt = None
                # GUARANTEED open stay on patient 1's last admission.
                if i == 1 and k == n_adm - 1:
                    dis_dt = None
                    dispo = None

            _ = forced  # (kept explicit for readability; both branches fully set fields)

            # attending staff (nullable -> NULL-in-NOT-IN trap)
            attending = None if self.rng.random() < 0.08 else self.rng.choice(self.surgeon_ids)

            # primary diagnosis: real code, NULL, or an orphan (absent) code.
            r = self.rng.random()
            if r < 0.05:
                diag = None
            elif r < 0.07:
                diag = ORPHAN_DIAG                              # orphan FK (NOT-IN / join trap)
            else:
                diag = self.rng.choice(DIAGNOSES)[0]
            if i == 3 and k == 0:
                diag = ORPHAN_DIAG                              # GUARANTEED orphan code
            admit_src = self.rng.choices(ADMIT_SOURCES, weights=[45, 25, 12, 18], k=1)[0]
            charge = None
            if self.rng.random() > 0.03:
                charge = round(self.rng.uniform(200, 90000), 2)
                if self.rng.random() < 0.02:
                    charge = 0.00                              # zero charge
            self._adm += 1
            adm_id = self._adm
            aw.writerow([adm_id, pid, wd["ward_id"], attending, ts(admit_dt), ts(dis_dt),
                         atype, admit_src, dispo, diag, money(charge)])

            self._emit_procedures(cw, adm_id, wd, admit_dt, dis_dt)
            self._emit_transfers(tw, adm_id, wd, admit_dt, dis_dt)

            prev_dis = dis_dt if dis_dt is not None else None

    def _emit_procedures(self, cw, adm_id, wd, admit_dt, dis_dt):
        surgical = wd["ward_type"] in ("SURGICAL", "ICU", "ED")
        base = 1.4 if surgical else 0.7
        n = min(6, self._poisson_like(base))
        end_dt = dis_dt if dis_dt is not None else (admit_dt + timedelta(days=2))
        for _ in range(n):
            code, name, base_dur = self.rng.choice(PROCEDURES)
            # performed time: usually within stay, sometimes before/after (late event).
            span = max(1, int((end_dt - admit_dt).total_seconds()))
            roll = self.rng.random()
            if roll < 0.05:
                perf = admit_dt - timedelta(hours=self.rng.randint(1, 12))   # pre-admit record
            elif roll < 0.10 and dis_dt is not None:
                perf = dis_dt + timedelta(hours=self.rng.randint(1, 48))     # post-discharge late charge
            elif roll < 0.14:
                perf = None                                                 # missing timestamp
            else:
                perf = admit_dt + timedelta(seconds=self.rng.randint(0, span))
            surgeon = None if self.rng.random() < 0.07 else self.rng.choice(self.surgeon_ids)
            dur = base_dur + self.rng.randint(-10, 40)
            if self.rng.random() < 0.05:
                dur = 0
            if self.rng.random() < 0.05:
                dur = None
            billable = 0 if self.rng.random() < 0.12 else 1
            self._proc += 1
            cw.writerow([self._proc, adm_id, code, name, ts(perf), surgeon, dur, billable])

    def _emit_transfers(self, tw, adm_id, wd, admit_dt, dis_dt):
        # First placement: from NULL to the admitting ward at admit time.
        self._xfer += 1
        seq = 1
        tw.writerow([self._xfer, adm_id, seq, None, wd["ward_id"], ts(admit_dt), "ADMISSION"])
        cur_ward = wd["ward_id"]
        cur_ts = admit_dt
        prev_ts = admit_dt
        end_dt = dis_dt if dis_dt is not None else (admit_dt + timedelta(days=3))
        n_moves = self._poisson_like(0.6)
        for _ in range(min(4, n_moves)):
            step = max(1, int((end_dt - cur_ts).total_seconds() // 2))
            cur_ts = cur_ts + timedelta(seconds=self.rng.randint(1, max(2, step)))
            if cur_ts >= end_dt:
                break
            seq += 1
            # ~15% of moves are to the SAME ward (consecutive same-ward -> island merge).
            if self.rng.random() < 0.15:
                to_ward = cur_ward
            else:
                to_ward = self.rng.choice(self.wards)["ward_id"]
            reason = self.rng.choice(["ESCALATION", "STEP_DOWN", "BED_MGMT", "SPECIALTY", None])
            # ~4% genuine tie: this move shares the exact timestamp of the prior step,
            # so ordering by transfer_ts alone is ambiguous (needs a tiebreak on seq_no).
            row_ts = prev_ts if self.rng.random() < 0.04 else cur_ts
            self._xfer += 1
            tw.writerow([self._xfer, adm_id, seq, cur_ward, to_ward, ts(row_ts), reason])
            # ~2% duplicate transfer row (same business content, new surrogate id).
            if self.rng.random() < 0.02:
                self._xfer += 1
                tw.writerow([self._xfer, adm_id, seq, cur_ward, to_ward, ts(row_ts), reason])
            cur_ward = to_ward
            prev_ts = row_ts

    def _poisson_like(self, mean):
        # Cheap, deterministic small-count sampler (no numpy).
        if mean <= 0:
            return 0
        L = math.exp(-mean)
        k = 0
        p = 1.0
        while True:
            p *= self.rng.random()
            if p <= L or k > 12:
                return k
            k += 1

    # -- roster stream ------------------------------------------------------
    def write_roster(self):
        f, w = self._writer("roster_shifts", [
            "shift_id", "staff_id", "ward_id", "shift_date", "shift_type",
            "scheduled_start", "scheduled_end", "scheduled_hours",
            "actual_hours", "status"])
        mean = self.cfg["slot_mean"]
        staff_pool = self.nurse_ids + [s["staff_id"] for s in self.staff]  # nurse-biased pool
        for wd in self.wards:
            wid = wd["ward_id"]
            for d in range(self.win_days):
                day = (self.win_start + timedelta(days=d)).date()
                weekend = day.weekday() >= 5
                for st in SHIFT_TYPES:
                    self._emit_slot(w, wid, day, st, mean, weekend, staff_pool)
        f.close()

    def _emit_slot(self, w, wid, day, st, mean, weekend, staff_pool):
        # GUARANTEED coverage landmines in the reporting month, on ward 2:
        #   - a fully uncovered slot (NO rows at all)
        #   - a slot where every assigned nurse is a NOSHOW (rows exist, zero worked)
        if wid == 2 and day == date(2024, 2, 29) and st == "NIGHT":
            return                                             # empty group -> uncovered slot
        force_all_noshow = (wid == 2 and day == date(2024, 2, 29) and st == "DAY")

        m = mean * (0.7 if weekend else 1.0) * (0.6 if st == "SWING" else 1.0)
        count = self._poisson_like(m)
        # deliberate under/over dispersion so real gaps and duplicates both occur
        if self.rng.random() < 0.05:
            count = 0                                          # random uncovered slot
        for _ in range(count):
            sid = self.rng.choice(staff_pool)
            sh_start, sh_end = SHIFT_HOURS[st]
            start_dt = datetime(day.year, day.month, day.day, sh_start, 0, 0)
            if st == "NIGHT":
                end_dt = datetime(day.year, day.month, day.day, sh_end, 0, 0) + timedelta(days=1)
                sched = 12.0
            elif st == "DAY":
                end_dt = datetime(day.year, day.month, day.day, sh_end, 0, 0)
                sched = 12.0
            else:
                end_dt = datetime(day.year, day.month, day.day, sh_end, 0, 0)
                sched = 8.0
            if force_all_noshow:
                status, actual = "NOSHOW", None
            else:
                r = self.rng.random()
                if r < 0.06:
                    status, actual = "NOSHOW", None            # no-show -> NULL actual (AVG vs SUM trap)
                elif r < 0.10:
                    status, actual = "CANCELLED", 0.00
                elif r < 0.13:
                    status, actual = "SWAPPED", round(sched + self.rng.uniform(-2, 2), 2)
                else:
                    status = "WORKED"
                    actual = round(sched + self.rng.uniform(-1.5, 3.0), 2)  # incl. overtime
                    if actual < 0:
                        actual = 0.00
            self._shift += 1
            w.writerow([self._shift, sid, wid, ds(day), st, ts(start_dt), ts(end_dt),
                        dec2(sched), dec2(actual), status])
            # ~1.5% double-booked duplicate (same staff/ward/date/shift, new id).
            if self.rng.random() < 0.015:
                self._shift += 1
                w.writerow([self._shift, sid, wid, ds(day), st, ts(start_dt), ts(end_dt),
                            dec2(sched), dec2(actual), status])

    # -- driver -------------------------------------------------------------
    def run(self):
        os.makedirs(self.out, exist_ok=True)
        self.write_wards()
        self.write_staff()
        self.write_diagnoses()
        self.write_facts()
        self.write_roster()


def main():
    ap = argparse.ArgumentParser(description="MediCore deterministic data generator")
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--scale", choices=list(SCALES.keys()), required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    Generator(args.seed, args.scale, args.out).run()


if __name__ == "__main__":
    main()
