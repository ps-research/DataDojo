import { useCallback, useEffect, useRef, useState } from "react";
import { Link, useParams } from "react-router-dom";
import Editor from "@monaco-editor/react";
import { api, getAccessToken } from "../lib/api";
import { useTheme } from "../lib/theme";
import { Split } from "../components/Split";
import { Markdown } from "../components/Markdown";
import { BeltBadge, Pill, VerdictBadge } from "../components/Badges";
import { CollapseIcon, ExpandIcon } from "../components/icons";

interface EngineOption {
  engine: string;
  starterCode: string;
  available: boolean;
}
interface ProblemDetail {
  slug: string;
  title: string;
  number: number;
  belt: string;
  universe: string;
  statementMd: string;
  schemaPreview: string;
  concepts: string[];
  points: number;
  engines: EngineOption[];
}
interface SubmissionRow {
  id: string;
  engine: string;
  status: string;
  verdict: string | null;
  runtimeMs: number;
  createdAt: string;
}
interface VerdictEvent {
  verdict: string;
  message: string;
  runtimeMs: number;
}

const MONACO_LANG: Record<string, string> = {
  sqlite: "sql", duckdb: "sql", postgres: "sql", mysql: "sql", mssql: "sql",
  python: "python", r: "r",
};

export function SolvePage() {
  const { slug = "" } = useParams();
  const { theme } = useTheme();
  const [problem, setProblem] = useState<ProblemDetail | null>(null);
  const [lockedInfo, setLockedInfo] = useState<{ prerequisites: string[] } | null>(null);
  const [engine, setEngine] = useState("");
  const [code, setCode] = useState("");
  const [focus, setFocus] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [result, setResult] = useState<VerdictEvent | null>(null);
  const [history, setHistory] = useState<SubmissionRow[]>([]);
  const [tab, setTab] = useState<"statement" | "submissions">("statement");
  const esRef = useRef<EventSource | null>(null);

  const codeKey = useCallback((eng: string) => `dojo-code:${slug}:${eng}`, [slug]);

  useEffect(() => {
    setLockedInfo(null);
    void api<{ problem: ProblemDetail }>(`/api/problems/${slug}`)
      .then((d) => {
        setProblem(d.problem);
        const first = d.problem.engines.find((e) => e.available) ?? d.problem.engines[0];
        if (first) {
          setEngine(first.engine);
          setCode(localStorage.getItem(`dojo-code:${slug}:${first.engine}`) ?? first.starterCode);
        }
      })
      .catch((err: { status?: number; body?: { prerequisites?: string[] } }) => {
        if (err.status === 423) setLockedInfo({ prerequisites: err.body?.prerequisites ?? [] });
      });
    return () => esRef.current?.close();
  }, [slug]);

  useEffect(() => {
    if (!slug) return;
    void api<{ submissions: SubmissionRow[] }>(`/api/submissions?problem=${slug}`)
      .then((d) => setHistory(d.submissions))
      .catch(() => undefined);
  }, [slug, result]);

  // focus mode: F on the page (outside the editor) or the toolbar button; Esc exits
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setFocus(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const switchEngine = (eng: string) => {
    if (engine) localStorage.setItem(codeKey(engine), code);
    setEngine(eng);
    const starter = problem?.engines.find((e) => e.engine === eng)?.starterCode ?? "";
    setCode(localStorage.getItem(codeKey(eng)) ?? starter);
    setResult(null);
  };

  const submit = useCallback(async () => {
    if (!problem || !engine || submitting) return;
    localStorage.setItem(codeKey(engine), code);
    setSubmitting(true);
    setResult(null);
    try {
      const { id } = await api<{ id: string }>("/api/submissions", {
        method: "POST",
        body: JSON.stringify({ slug: problem.slug, engine, code }),
      });
      const token = getAccessToken() ?? "";
      const es = new EventSource(`/api/submissions/${id}/stream?token=${encodeURIComponent(token)}`);
      esRef.current = es;
      es.onmessage = (ev) => {
        const data = JSON.parse(ev.data) as VerdictEvent;
        setResult(data);
        setSubmitting(false);
        es.close();
      };
      es.onerror = () => {
        es.close();
        // graceful fallback: poll once after a beat
        setTimeout(() => {
          void api<{ submission: SubmissionRow & { message: string } }>(`/api/submissions/${id}`).then((d) => {
            if (d.submission.status === "done") {
              setResult({ verdict: d.submission.verdict ?? "RE", message: d.submission.message, runtimeMs: d.submission.runtimeMs });
              setSubmitting(false);
            }
          });
        }, 2500);
      };
    } catch (err) {
      setResult({ verdict: "RE", message: err instanceof Error ? err.message : "Submission failed", runtimeMs: 0 });
      setSubmitting(false);
    }
  }, [problem, engine, code, submitting, codeKey]);

  // Ctrl/Cmd+Enter submits from inside the editor
  const editorMount = useCallback(
    (editor: { addCommand: (k: number, f: () => void) => void }, monaco: { KeyMod: { CtrlCmd: number }; KeyCode: { Enter: number } }) => {
      editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter, () => void submitRef.current());
    },
    []
  );
  const submitRef = useRef(submit);
  useEffect(() => {
    submitRef.current = submit;
  }, [submit]);

  if (lockedInfo) {
    return (
      <div className="mx-auto max-w-lg px-4 py-24 text-center">
        <h1 className="text-lg font-semibold">This problem is locked</h1>
        <p className="mt-2 text-sm text-zinc-500 dark:text-zinc-400">
          Earn it: solve the prerequisite first.
        </p>
        <div className="mt-4 flex justify-center gap-2">
          {lockedInfo.prerequisites.map((p) => (
            <Link key={p} to={`/problems/${p}`} className="btn-primary">
              {p}
            </Link>
          ))}
        </div>
      </div>
    );
  }

  if (!problem) {
    return <div className="p-10 text-center text-sm text-zinc-400">Loading problem...</div>;
  }

  const statementPanel = (
    <div className="h-full px-5 py-4">
      <div className="mb-3 flex items-center gap-3">
        <h1 className="text-base font-semibold tracking-tight">
          {problem.number}. {problem.title}
        </h1>
        <BeltBadge belt={problem.belt} />
        {problem.universe && <Pill>{problem.universe}</Pill>}
        <span className="ml-auto text-xs text-zinc-400">{problem.points} pts</span>
      </div>

      <div className="mb-4 flex gap-1 border-b border-zinc-200 text-sm dark:border-zinc-800">
        {(["statement", "submissions"] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`-mb-px border-b-2 px-3 py-1.5 capitalize transition-colors ${
              tab === t
                ? "border-brand font-medium text-zinc-800 dark:text-zinc-100"
                : "border-transparent text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-200"
            }`}
          >
            {t}
          </button>
        ))}
      </div>

      {tab === "statement" ? (
        <>
          <Markdown source={problem.statementMd} />
          {problem.schemaPreview && (
            <div className="mt-5">
              <h3 className="mb-1.5 text-xs font-semibold uppercase tracking-wide text-zinc-400">Schema</h3>
              <pre className="overflow-x-auto rounded-md bg-zinc-100 p-3 font-mono text-xs leading-relaxed dark:bg-zinc-800">
                {problem.schemaPreview}
              </pre>
            </div>
          )}
          {problem.concepts.length > 0 && (
            <div className="mt-4 flex flex-wrap gap-1.5">
              {problem.concepts.map((c) => (
                <Pill key={c}>{c}</Pill>
              ))}
            </div>
          )}
        </>
      ) : (
        <div className="space-y-1.5">
          {history.length === 0 && <p className="text-sm text-zinc-400">No submissions yet.</p>}
          {history.map((s) => (
            <div key={s.id} className="flex items-center gap-3 rounded-md bg-zinc-50 px-3 py-2 text-xs dark:bg-zinc-800/50">
              <VerdictBadge verdict={s.verdict} />
              <span className="text-zinc-500 dark:text-zinc-400">{s.engine}</span>
              <span className="text-zinc-400">{s.runtimeMs} ms</span>
              <span className="ml-auto text-zinc-400">{new Date(s.createdAt).toLocaleTimeString()}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );

  const editorPanel = (
    <div className="flex h-full min-h-0 flex-col">
      <div className="flex flex-none items-center gap-2 border-b border-zinc-200 px-3 py-2 dark:border-zinc-800">
        <select className="input w-auto py-1.5" value={engine} onChange={(e) => switchEngine(e.target.value)}>
          {problem.engines.map((e) => (
            <option key={e.engine} value={e.engine} disabled={!e.available}>
              {e.engine}
              {!e.available ? " (offline)" : ""}
            </option>
          ))}
        </select>
        <button
          onClick={() => setFocus(!focus)}
          className="btn-ghost h-8 w-8 justify-center p-0"
          title={focus ? "Exit focus mode (Esc)" : "Focus mode — just you and the editor"}
        >
          {focus ? <CollapseIcon /> : <ExpandIcon />}
        </button>
        <div className="ml-auto flex items-center gap-2">
          <span className="hidden text-xs text-zinc-400 md:inline">Ctrl+Enter to submit</span>
          <button onClick={() => void submit()} disabled={submitting} className="btn-primary">
            {submitting ? "Judging..." : "Submit"}
          </button>
        </div>
      </div>

      <div className="min-h-0 flex-1">
        <Editor
          language={MONACO_LANG[engine] ?? "sql"}
          value={code}
          onChange={(v) => setCode(v ?? "")}
          onMount={editorMount as never}
          theme={theme === "dark" ? "vs-dark" : "light"}
          options={{
            minimap: { enabled: false },
            fontSize: 14,
            lineHeight: 1.6,
            padding: { top: 12 },
            scrollBeyondLastLine: false,
            renderLineHighlight: "none",
            overviewRulerLanes: 0,
            wordWrap: "on",
            automaticLayout: true,
          }}
        />
      </div>

      {result && (
        <div
          className={`flex flex-none items-start gap-3 border-t px-4 py-3 text-sm ${
            result.verdict === "AC"
              ? "border-emerald-200 bg-emerald-50 dark:border-emerald-900 dark:bg-emerald-950/40"
              : "border-zinc-200 bg-zinc-50 dark:border-zinc-800 dark:bg-zinc-900"
          }`}
        >
          <VerdictBadge verdict={result.verdict} />
          <p className="min-w-0 flex-1 text-zinc-600 dark:text-zinc-300">{result.message}</p>
          <span className="flex-none text-xs text-zinc-400">{result.runtimeMs} ms</span>
        </div>
      )}
    </div>
  );

  return (
    <div className="h-[calc(100vh-3.5rem)]">
      <Split left={statementPanel} right={editorPanel} storageKey={`dojo-split:${slug}`} hidden={focus} />
    </div>
  );
}
