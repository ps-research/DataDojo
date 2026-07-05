import { useState, type FormEvent } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "../lib/auth";
import { ApiRequestError } from "../lib/api";
import { Enso } from "../components/Enso";

// The entrance to the dojo. You cross this threshold before you may train.
export function LoginPage() {
  const { login, signup } = useAuth();
  const navigate = useNavigate();
  const location = useLocation() as { state?: { from?: string } };
  const [mode, setMode] = useState<"login" | "signup">("login");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      if (mode === "login") await login(email, password);
      else await signup(name, email, password);
      navigate(location.state?.from ?? "/problems", { replace: true });
    } catch (err) {
      setError(err instanceof ApiRequestError ? err.message : "Something went wrong. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex min-h-screen">
      {/* Left: the dojo threshold — a torii and the way */}
      <aside className="relative hidden w-1/2 flex-col justify-between overflow-hidden bg-sumi-900 p-12 text-washi-100 lg:flex">
        <div
          className="pointer-events-none absolute inset-0 opacity-[0.06]"
          style={{
            backgroundImage:
              "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='80' height='40'%3E%3Cpath d='M0 40 C20 10 60 10 80 40' fill='none' stroke='%23fff' stroke-width='1.5'/%3E%3C/svg%3E\")",
            backgroundSize: "80px 40px",
          }}
        />
        <div className="relative flex items-center gap-3">
          <Enso className="h-9 w-9 text-shu-light" />
          <span className="font-serif text-xl tracking-wide">DataDojo</span>
          <span className="kanji text-lg text-washi-100/40">道場</span>
        </div>
        <div className="relative">
          <p className="max-w-sm font-serif text-2xl leading-relaxed">
            Enter the training ground for data.
          </p>
          <p className="mt-3 max-w-sm text-sm text-washi-100/60">
            Query in five SQL dialects, in pandas, in R. Advance belt by belt —
            white through red — against problems that judge you honestly.
          </p>
        </div>
        <p className="relative text-xs text-washi-100/40">稽古 · keiko · practice without end</p>
      </aside>

      {/* Right: the gate */}
      <main className="flex w-full flex-col justify-center px-6 lg:w-1/2">
        <div className="mx-auto w-full max-w-sm">
          <div className="mb-8 text-center lg:hidden">
            <Enso className="mx-auto h-10 w-10 text-shu" />
          </div>
          <div className="mb-6">
            <h1 className="font-serif text-2xl tracking-tight">
              {mode === "login" ? "Welcome back" : "Cross the threshold"}
            </h1>
            <p className="mt-1 text-sm text-sumi/60 dark:text-washi-100/60">
              {mode === "login" ? "Sign in to continue your training." : "Create your account to begin."}
            </p>
          </div>

          <form onSubmit={onSubmit} className="space-y-4">
            {mode === "signup" && (
              <div>
                <label className="mb-1 block text-xs font-medium text-sumi/60 dark:text-washi-100/60">Name</label>
                <input className="input" value={name} onChange={(e) => setName(e.target.value)} required maxLength={60} />
              </div>
            )}
            <div>
              <label className="mb-1 block text-xs font-medium text-sumi/60 dark:text-washi-100/60">Email</label>
              <input className="input" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-sumi/60 dark:text-washi-100/60">Password</label>
              <input
                className="input"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                minLength={mode === "signup" ? 8 : 1}
                placeholder={mode === "signup" ? "At least 8 characters" : undefined}
              />
            </div>
            {error && <p className="text-sm text-shu">{error}</p>}
            <button className="btn-primary w-full justify-center py-2.5" disabled={busy}>
              {busy ? "One moment..." : mode === "login" ? "Enter the dojo" : "Begin training"}
            </button>
          </form>

          <button
            className="mt-6 w-full text-center text-sm text-sumi/60 hover:text-sumi dark:text-washi-100/60 dark:hover:text-washi-100"
            onClick={() => {
              setMode(mode === "login" ? "signup" : "login");
              setError("");
            }}
          >
            {mode === "login" ? "New to the dojo? Create an account" : "Already training? Sign in"}
          </button>
        </div>
      </main>
    </div>
  );
}
