"""
Uniform execution interface for the four DataDojo judge engines.

Each engine exposes run(sql, datasets) -> Result, where `datasets` is the list
of {name, create_sql, seed_sql} the solution may reference. Engines isolate
every run: in-process engines (sqlite/duckdb) build a fresh in-memory DB with
only the referenced base tables; server engines (postgres/mysql) preload the
base tables once and roll back / reload around each run.

Result.status: 'pass' (executed, no error) | 'error' (raised) .
Result.csv: canonical CSV of the result set (header = lowercased columns),
            or a '-- <n> row(s) affected' note for non-SELECT statements.
"""
import csv, io, re, subprocess

BASE_TABLES = ["emp", "dept", "t1", "t10", "t100", "t500"]
READONLY = re.compile(r"^\s*(select|with|explain|show|describe|desc|values)\b", re.I)

def referenced(sql):
    low = sql.lower()
    return [t for t in BASE_TABLES if re.search(rf"\b{t}\b", low)]

def to_csv(columns, rows):
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    w.writerow([str(c).lower() for c in columns])
    for r in rows:
        w.writerow(["" if v is None else v for v in r])
    return buf.getvalue().rstrip("\n")

class Result:
    def __init__(self, status, csv=None, error=None):
        self.status, self.csv, self.error = status, csv, error


# ----------------------------- SQLite --------------------------------------
import sqlite3
def _sqlite_version():
    return "sqlite " + sqlite3.sqlite_version

def run_sqlite(sql, datasets):
    con = sqlite3.connect(":memory:")
    try:
        need = set(referenced(sql))
        for d in datasets:
            if d["name"].lower() in need:
                con.executescript(d["create_sql"] + "\n" + d["seed_sql"])
        cur = con.execute(sql)
        if cur.description:
            cols = [c[0] for c in cur.description]
            return Result("pass", to_csv(cols, cur.fetchall()))
        return Result("pass", f"-- {cur.rowcount} row(s) affected")
    except Exception as ex:
        return Result("error", error=f"{type(ex).__name__}: {ex}")
    finally:
        con.close()


# ----------------------------- DuckDB --------------------------------------
import duckdb
def _duckdb_version():
    return "duckdb " + duckdb.__version__

def run_duckdb(sql, datasets):
    con = duckdb.connect(":memory:")
    try:
        need = set(referenced(sql))
        for d in datasets:
            if d["name"].lower() in need:
                for stmt in filter(str.strip, (d["create_sql"] + "\n" + d["seed_sql"]).split(";")):
                    con.execute(stmt)
        cur = con.execute(sql)
        if cur.description:
            cols = [c[0] for c in cur.description]
            return Result("pass", to_csv(cols, cur.fetchall()))
        return Result("pass", "-- statement ok")
    except Exception as ex:
        return Result("error", error=f"{type(ex).__name__}: {ex}")
    finally:
        con.close()


# --------------------------- PostgreSQL ------------------------------------
import psycopg2
class Postgres:
    def __init__(self):
        self.con = psycopg2.connect(host="/tmp", port=5433, user="postgres", dbname="postgres")
        self.con.autocommit = False
        self.version = self._v()
        self._load_base()
    def _v(self):
        with self.con.cursor() as c:
            c.execute("select version()"); v = c.fetchone()[0]
        self.con.rollback(); return v.split(",")[0]
    def _load_base(self):
        from pathlib import Path  # base tables loaded once, committed
        import sqlite3 as _s
        kb = _s.connect(str(Path(__file__).resolve().parent.parent / "datadojo_kb.sqlite"))
        with self.con.cursor() as c:
            for name, create_sql, seed_sql in kb.execute("select name,create_sql,seed_sql from datasets"):
                c.execute(f"drop table if exists {name.lower()} cascade")
                c.execute(create_sql)
                for stmt in filter(str.strip, seed_sql.split(";")):
                    c.execute(stmt)
        self.con.commit(); kb.close()
    def run(self, sql, datasets=None):
        try:
            with self.con.cursor() as c:
                c.execute(sql)
                if c.description:
                    cols = [d[0] for d in c.description]
                    out = to_csv(cols, c.fetchall())
                else:
                    out = f"-- {c.rowcount} row(s) affected"
            self.con.rollback()               # undo any mutation, keep base pristine
            return Result("pass", out)
        except Exception as ex:
            self.con.rollback()
            return Result("error", error=f"{type(ex).__name__}: {str(ex).strip()}")


# ----------------------------- MySQL ---------------------------------------
class MySQL:
    """Runs through the mariadb CLI (batch mode) to avoid a driver dependency."""
    SOCK = "/tmp/mariadb.sock"
    def __init__(self):
        self.version = self._cli("select version();").strip().splitlines()[-1]
        self._load_base()
    def _cli(self, sql, db="datadojo"):
        p = subprocess.run(["mariadb", "--socket", self.SOCK, "-u", "root", db,
                            "--batch", "--raw", "-e", sql],
                           capture_output=True, text=True)
        if p.returncode != 0:
            raise RuntimeError(p.stderr.strip() or "mariadb error")
        return p.stdout
    def _load_base(self):
        from pathlib import Path
        import sqlite3 as _s
        kb = _s.connect(str(Path(__file__).resolve().parent.parent / "datadojo_kb.sqlite"))
        stmts = ["drop database if exists datadojo", "create database datadojo"]
        self._cli(";".join(stmts) + ";", db="")
        for name, create_sql, seed_sql in kb.execute("select name,create_sql,seed_sql from datasets"):
            self._cli(create_sql + "\n" + seed_sql)
        kb.close()
    def run(self, sql, datasets=None):
        try:
            out = self._cli(sql)
            if not READONLY.match(sql):
                self._load_base()             # reload after a mutation
            rows = out.rstrip("\n").split("\n") if out.strip() else []
            if rows and "\t" in (rows[0] if rows else ""):
                # convert TSV -> CSV canonical
                import io as _io
                buf = _io.StringIO(); w = csv.writer(buf, lineterminator="\n")
                for r in rows:
                    w.writerow([c.lower() for c in r.split("\t")] if r is rows[0]
                               else r.split("\t"))
                return Result("pass", buf.getvalue().rstrip("\n"))
            return Result("pass", out.rstrip("\n") or "-- statement ok")
        except Exception as ex:
            try: self._load_base()
            except Exception: pass
            return Result("error", error=f"{type(ex).__name__}: {str(ex).strip()[:300]}")


# --------------------------- SQL Server ------------------------------------
import pymssql
class SqlServer:
    def __init__(self):
        self.con0 = pymssql.connect(server="127.0.0.1", port=1433, user="SA",
                                    password="DataDojo!2026", autocommit=True)
        with self.con0.cursor() as c:
            c.execute("IF DB_ID('datadojo') IS NULL CREATE DATABASE datadojo")
            c.execute("SELECT @@VERSION")
            self.version = c.fetchone()[0].splitlines()[0].strip()
        self.con = pymssql.connect(server="127.0.0.1", port=1433, user="SA",
                                   password="DataDojo!2026", database="datadojo",
                                   autocommit=False)
        self._load_base()
    def _load_base(self):
        from pathlib import Path
        import sqlite3 as _s
        kb = _s.connect(str(Path(__file__).resolve().parent.parent / "datadojo_kb.sqlite"))
        with self.con.cursor() as c:
            for name, create_sql, seed_sql in kb.execute("select name,create_sql,seed_sql from datasets"):
                c.execute(f"IF OBJECT_ID('{name.lower()}','U') IS NOT NULL DROP TABLE {name.lower()}")
                c.execute(create_sql)
                for stmt in filter(str.strip, seed_sql.split(";")):
                    c.execute(stmt)
        self.con.commit(); kb.close()
    def run(self, sql, datasets=None):
        try:
            with self.con.cursor() as c:
                c.execute(sql)
                if c.description:
                    cols = [d[0] for d in c.description]
                    out = to_csv(cols, c.fetchall())
                else:
                    out = f"-- {c.rowcount} row(s) affected"
            self.con.rollback()               # T-SQL DDL is transactional -> clean
            return Result("pass", out)
        except Exception as ex:
            try: self.con.rollback()
            except Exception:
                self.con = pymssql.connect(server="127.0.0.1", port=1433, user="SA",
                                           password="DataDojo!2026", database="datadojo",
                                           autocommit=False)
            return Result("error", error=f"{type(ex).__name__}: {str(ex).strip()[:300]}")


ENGINE_VERSIONS = {
    "sqlite": _sqlite_version(),
    "duckdb": _duckdb_version(),
}
