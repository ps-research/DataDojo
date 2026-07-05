// Dev-only seed: one problem across four SQL engines + python, so the full
// submit -> queue -> judge -> verdict path can be smoke-tested before real
// content lands. Replaced entirely by the KB gold export.
import mongoose from "mongoose";
import { connectMongo } from "../config/db.js";
import { Problem } from "../models/Problem.js";
import { User } from "../models/User.js";

const EMP_SQL = `
CREATE TABLE emp (empno INTEGER PRIMARY KEY, ename VARCHAR(10), job VARCHAR(9), mgr INTEGER, hiredate DATE, sal INTEGER, comm INTEGER, deptno INTEGER);
INSERT INTO emp VALUES (7369,'SMITH','CLERK',7902,'2005-12-17',800,NULL,20);
INSERT INTO emp VALUES (7499,'ALLEN','SALESMAN',7698,'2006-02-20',1600,300,30);
INSERT INTO emp VALUES (7521,'WARD','SALESMAN',7698,'2006-02-22',1250,500,30);
INSERT INTO emp VALUES (7566,'JONES','MANAGER',7839,'2006-04-02',2975,NULL,20);
INSERT INTO emp VALUES (7654,'MARTIN','SALESMAN',7698,'2006-09-28',1250,1400,30);
INSERT INTO emp VALUES (7698,'BLAKE','MANAGER',7839,'2006-05-01',2850,NULL,30);
INSERT INTO emp VALUES (7782,'CLARK','MANAGER',7839,'2006-06-09',2450,NULL,10);
INSERT INTO emp VALUES (7788,'SCOTT','ANALYST',7566,'2007-12-09',3000,NULL,20);
INSERT INTO emp VALUES (7839,'KING','PRESIDENT',NULL,'2006-11-17',5000,NULL,10);
INSERT INTO emp VALUES (7844,'TURNER','SALESMAN',7698,'2006-09-08',1500,0,30);
INSERT INTO emp VALUES (7876,'ADAMS','CLERK',7788,'2008-01-12',1100,NULL,20);
INSERT INTO emp VALUES (7900,'JAMES','CLERK',7698,'2006-12-03',950,NULL,30);
INSERT INTO emp VALUES (7902,'FORD','ANALYST',7566,'2006-12-03',3000,NULL,20);
INSERT INTO emp VALUES (7934,'MILLER','CLERK',7782,'2007-01-23',1300,NULL,10);
`.trim();

const PY_FIXTURE = `
import io, pandas as pd
emp = pd.read_csv(io.StringIO("""empno,ename,job,mgr,hiredate,sal,comm,deptno
7369,SMITH,CLERK,7902,2005-12-17,800,,20
7499,ALLEN,SALESMAN,7698,2006-02-20,1600,300,30
7521,WARD,SALESMAN,7698,2006-02-22,1250,500,30
7566,JONES,MANAGER,7839,2006-04-02,2975,,20
7654,MARTIN,SALESMAN,7698,2006-09-28,1250,1400,30
7698,BLAKE,MANAGER,7839,2006-05-01,2850,,30
7782,CLARK,MANAGER,7839,2006-06-09,2450,,10
7788,SCOTT,ANALYST,7566,2007-12-09,3000,,20
7839,KING,PRESIDENT,,2006-11-17,5000,,10
7844,TURNER,SALESMAN,7698,2006-09-08,1500,0,30
7876,ADAMS,CLERK,7788,2008-01-12,1100,,20
7900,JAMES,CLERK,7698,2006-12-03,950,,30
7902,FORD,ANALYST,7566,2006-12-03,3000,,20
7934,MILLER,CLERK,7782,2007-01-23,1300,,10
"""))
`.trim();

const SQL_REFERENCE = "SELECT deptno, COUNT(*) AS headcount FROM emp GROUP BY deptno ORDER BY deptno";
const PY_REFERENCE = `res = emp.groupby("deptno").size().reset_index(name="headcount").sort_values("deptno")
print(res.to_csv(index=False), end="")`;

async function main(): Promise<void> {
  await connectMongo();

  await Problem.updateOne(
    { slug: "dev-headcount-by-dept" },
    {
      $set: {
        slug: "dev-headcount-by-dept",
        number: 9001,
        title: "[DEV] Headcount by Department",
        statementMd:
          "Count employees per department.\n\nReturn two columns: `deptno`, `headcount`, ordered by `deptno`.\n\n_Dev seed problem - will be removed._",
        belt: "white",
        category: "sql",
        universe: "",
        concepts: ["group-by", "aggregate-count"],
        tags: ["dev"],
        schemaPreview: "emp(empno, ename, job, mgr, hiredate, sal, comm, deptno)",
        orderMatters: true,
        prerequisites: [],
        provenance: "dev-seed",
        points: 10,
        engines: [
          { engine: "sqlite", fixtureSql: EMP_SQL, fixtureRef: "", referenceSolution: SQL_REFERENCE, starterCode: "SELECT ...", timeoutMs: 0 },
          { engine: "duckdb", fixtureSql: EMP_SQL, fixtureRef: "", referenceSolution: SQL_REFERENCE, starterCode: "SELECT ...", timeoutMs: 0 },
          { engine: "postgres", fixtureSql: EMP_SQL, fixtureRef: "", referenceSolution: SQL_REFERENCE, starterCode: "SELECT ...", timeoutMs: 0 },
          { engine: "mysql", fixtureSql: EMP_SQL, fixtureRef: "", referenceSolution: SQL_REFERENCE, starterCode: "SELECT ...", timeoutMs: 0 },
          { engine: "mssql", fixtureSql: EMP_SQL, fixtureRef: "", referenceSolution: SQL_REFERENCE, starterCode: "SELECT ...", timeoutMs: 0 },
          { engine: "python", fixtureSql: PY_FIXTURE, fixtureRef: "", referenceSolution: PY_REFERENCE, starterCode: "# emp is a pandas DataFrame\n", timeoutMs: 10000 },
        ],
      },
    },
    { upsert: true }
  );

  const admin = await User.findOne({ email: "admin@datadojo.dev" });
  if (!admin) {
    const u = new User({ name: "Dojo Admin", email: "admin@datadojo.dev", role: "admin" });
    await u.setPassword("admin-dev-password-1");
    await u.save();
  }

  console.log("[seed:dev] seeded dev problem + admin");
  await mongoose.disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
