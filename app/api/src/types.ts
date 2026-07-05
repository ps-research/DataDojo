export const ENGINES = ["sqlite", "duckdb", "postgres", "mysql", "mssql", "python", "r"] as const;
export type Engine = (typeof ENGINES)[number];

export const VERDICTS = ["AC", "WA", "TLE", "RE", "CE"] as const;
export type Verdict = (typeof VERDICTS)[number];

export const BELTS = ["white", "blue", "purple", "black", "red"] as const;
export type Belt = (typeof BELTS)[number];

export interface ResultSet {
  columns: string[];
  rows: unknown[][];
}

export type RunResult =
  | { ok: true; result: ResultSet }
  | { ok: false; timeout: true }
  | { ok: false; timeout?: false; error: string };

export interface EngineAdapter {
  readonly name: Engine;
  available(): Promise<boolean>;
  run(fixture: string, code: string, timeoutMs: number): Promise<RunResult>;
}

export interface JudgeOutcome {
  verdict: Verdict;
  message: string;
  runtimeMs: number;
  rowsReturned: number;
  testsPassed: number;
  testsTotal: number;
}
