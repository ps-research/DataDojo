import { useState, type FormEvent } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "../lib/auth";
import { ApiRequestError } from "../lib/api";

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
    <div className="mx-auto flex min-h-[70vh] max-w-sm flex-col justify-center px-4">
      <div className="mb-6 text-center">
        <div className="mx-auto mb-3 h-9 w-9 rounded-lg bg-accent" aria-hidden />
        <h1 className="text-xl font-semibold tracking-tight">
          {mode === "login" ? "Welcome back" : "Join DataDojo"}
        </h1>
        <p className="mt-1 text-sm text-stone-500 dark:text-stone-400">
          The training ground for data skills.
        </p>
      </div>

      <form onSubmit={onSubmit} className="card space-y-3 p-5">
        {mode === "signup" && (
          <div>
            <label className="mb-1 block text-xs font-medium text-stone-500 dark:text-stone-400">Name</label>
            <input className="input" value={name} onChange={(e) => setName(e.target.value)} required maxLength={60} />
          </div>
        )}
        <div>
          <label className="mb-1 block text-xs font-medium text-stone-500 dark:text-stone-400">Email</label>
          <input className="input" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
        </div>
        <div>
          <label className="mb-1 block text-xs font-medium text-stone-500 dark:text-stone-400">Password</label>
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
        {error && <p className="text-sm text-red-600 dark:text-red-400">{error}</p>}
        <button className="btn-primary w-full justify-center" disabled={busy}>
          {busy ? "One moment..." : mode === "login" ? "Sign in" : "Create account"}
        </button>
      </form>

      <button
        className="mt-4 text-center text-sm text-stone-500 hover:text-stone-800 dark:text-stone-400 dark:hover:text-stone-200"
        onClick={() => {
          setMode(mode === "login" ? "signup" : "login");
          setError("");
        }}
      >
        {mode === "login" ? "New here? Create an account" : "Already have an account? Sign in"}
      </button>
    </div>
  );
}
