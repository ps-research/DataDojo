import { useEffect, useRef, useState, type FormEvent } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "../lib/auth";
import { ApiRequestError } from "../lib/api";
import { Logo } from "../components/Logo";
import { OtpInput } from "../components/OtpInput";

type Mode = "login" | "signup" | "otp";

export function LoginPage() {
  const { login, signup, verifyOtp, resendOtp } = useAuth();
  const navigate = useNavigate();
  const location = useLocation() as { state?: { from?: string } };
  const [mode, setMode] = useState<Mode>("login");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");
  const [busy, setBusy] = useState(false);
  const [cooldown, setCooldown] = useState(0);
  const timer = useRef<ReturnType<typeof setInterval>>();

  useEffect(() => () => clearInterval(timer.current), []);

  const startCooldown = (s: number) => {
    setCooldown(s);
    clearInterval(timer.current);
    timer.current = setInterval(() => {
      setCooldown((c) => {
        if (c <= 1) clearInterval(timer.current);
        return c - 1;
      });
    }, 1000);
  };

  const goHome = () => navigate(location.state?.from ?? "/problems", { replace: true });

  async function onSubmitAuth(e: FormEvent) {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const out = mode === "login" ? await login(email, password) : await signup(name, email, password);
      if (out.needsVerification) {
        setMode("otp");
        setInfo(`We sent a 6-digit code to ${out.email ?? email}.`);
        startCooldown(45);
      } else {
        goHome();
      }
    } catch (err) {
      setError(err instanceof ApiRequestError ? err.message : "Something went wrong. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  async function submitCode(fullCode?: string) {
    const c = fullCode ?? code;
    if (c.length !== 6) return;
    setError("");
    setBusy(true);
    try {
      await verifyOtp(email, c);
      goHome();
    } catch (err) {
      setError(err instanceof ApiRequestError ? err.message : "Verification failed.");
      setCode("");
    } finally {
      setBusy(false);
    }
  }

  async function onResend() {
    if (cooldown > 0) return;
    setError("");
    setInfo("");
    try {
      await resendOtp(email);
      setInfo("A new code is on its way.");
      startCooldown(45);
    } catch {
      setError("Could not resend. Try again shortly.");
    }
  }

  const title =
    mode === "otp" ? "Verify your email" : mode === "login" ? "Sign in to DataDojo" : "Create your account";
  const subtitle =
    mode === "otp"
      ? "Enter the 6-digit code we emailed you."
      : "Practice SQL, pandas, and R against a real judge.";

  return (
    <div className="flex min-h-screen items-center justify-center px-4">
      <div className="w-full max-w-[380px]">
        <div className="mb-8 flex flex-col items-center text-center">
          <Logo className="h-10 w-10" />
          <h1 className="mt-4 text-xl font-semibold tracking-tight">{title}</h1>
          <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">{subtitle}</p>
        </div>

        {mode === "otp" ? (
          <div className="card space-y-5 p-6">
            {info && <p className="text-center text-sm text-zinc-500 dark:text-zinc-400">{info}</p>}
            <OtpInput value={code} onChange={setCode} onComplete={(c) => void submitCode(c)} disabled={busy} />
            {error && <p className="text-center text-sm text-rose-600 dark:text-rose-400">{error}</p>}
            <button className="btn-primary w-full py-2.5" disabled={busy || code.length !== 6} onClick={() => void submitCode()}>
              {busy ? "Verifying..." : "Verify"}
            </button>
            <div className="flex items-center justify-between text-sm">
              <button
                className="text-zinc-500 hover:text-zinc-800 dark:text-zinc-400 dark:hover:text-zinc-200"
                onClick={() => {
                  setMode("login");
                  setCode("");
                  setError("");
                }}
              >
                Back
              </button>
              <button
                className={cooldown > 0 ? "text-zinc-400" : "link"}
                disabled={cooldown > 0}
                onClick={() => void onResend()}
              >
                {cooldown > 0 ? `Resend in ${cooldown}s` : "Resend code"}
              </button>
            </div>
          </div>
        ) : (
          <>
            <form onSubmit={onSubmitAuth} className="card space-y-4 p-6">
              {mode === "signup" && (
                <div>
                  <label className="mb-1.5 block text-xs font-medium text-zinc-600 dark:text-zinc-400">Name</label>
                  <input className="input" value={name} onChange={(e) => setName(e.target.value)} required maxLength={60} />
                </div>
              )}
              <div>
                <label className="mb-1.5 block text-xs font-medium text-zinc-600 dark:text-zinc-400">Email</label>
                <input className="input" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
                {mode === "signup" && (
                  <p className="mt-1.5 text-xs text-zinc-400">
                    Use Gmail, Yahoo, Outlook, iCloud, Proton, or a school email.
                  </p>
                )}
              </div>
              <div>
                <label className="mb-1.5 block text-xs font-medium text-zinc-600 dark:text-zinc-400">Password</label>
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
              {error && <p className="text-sm text-rose-600 dark:text-rose-400">{error}</p>}
              <button className="btn-primary w-full py-2.5" disabled={busy}>
                {busy ? "Please wait..." : mode === "login" ? "Sign in" : "Create account"}
              </button>
            </form>

            <p className="mt-6 text-center text-sm text-zinc-500 dark:text-zinc-400">
              {mode === "login" ? "New to DataDojo? " : "Already have an account? "}
              <button
                className="link font-medium"
                onClick={() => {
                  setMode(mode === "login" ? "signup" : "login");
                  setError("");
                }}
              >
                {mode === "login" ? "Create an account" : "Sign in"}
              </button>
            </p>
          </>
        )}
      </div>
    </div>
  );
}
