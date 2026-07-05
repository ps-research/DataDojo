import { useState, type FormEvent } from "react";
import { api, ApiRequestError } from "../lib/api";
import { useAuth } from "../lib/auth";

function Note({ kind, text }: { kind: "ok" | "err"; text: string }) {
  return (
    <p className={`text-sm ${kind === "ok" ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"}`}>
      {text}
    </p>
  );
}

export function SettingsPage() {
  const { user } = useAuth();
  const [name, setName] = useState(user?.name ?? "");
  const [nameMsg, setNameMsg] = useState<{ kind: "ok" | "err"; text: string } | null>(null);
  const [cur, setCur] = useState("");
  const [next, setNext] = useState("");
  const [pwMsg, setPwMsg] = useState<{ kind: "ok" | "err"; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  async function saveName(e: FormEvent) {
    e.preventDefault();
    setNameMsg(null);
    setBusy(true);
    try {
      await api("/api/users/me", { method: "PUT", body: JSON.stringify({ name }) });
      setNameMsg({ kind: "ok", text: "Saved. Refresh to see it in the navbar." });
    } catch (err) {
      setNameMsg({ kind: "err", text: err instanceof ApiRequestError ? err.message : "Could not save." });
    } finally {
      setBusy(false);
    }
  }

  async function changePassword(e: FormEvent) {
    e.preventDefault();
    setPwMsg(null);
    setBusy(true);
    try {
      await api("/api/users/me/password", {
        method: "PUT",
        body: JSON.stringify({ currentPassword: cur, newPassword: next }),
      });
      setPwMsg({ kind: "ok", text: "Password updated." });
      setCur("");
      setNext("");
    } catch (err) {
      setPwMsg({ kind: "err", text: err instanceof ApiRequestError ? err.message : "Could not update password." });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto max-w-lg px-4 py-8">
      <h1 className="mb-6 text-2xl font-semibold tracking-tight">Settings</h1>

      <form onSubmit={saveName} className="card mb-5 space-y-4 p-5">
        <h2 className="text-sm font-semibold">Profile</h2>
        <div>
          <label className="mb-1.5 block text-xs font-medium text-zinc-600 dark:text-zinc-400">Display name</label>
          <input className="input" value={name} onChange={(e) => setName(e.target.value)} maxLength={60} required />
        </div>
        <div>
          <label className="mb-1.5 block text-xs font-medium text-zinc-600 dark:text-zinc-400">Email</label>
          <input className="input opacity-60" value={user?.email ?? ""} disabled />
        </div>
        {nameMsg && <Note kind={nameMsg.kind} text={nameMsg.text} />}
        <button className="btn-primary" disabled={busy}>Save profile</button>
      </form>

      <form onSubmit={changePassword} className="card space-y-4 p-5">
        <h2 className="text-sm font-semibold">Change password</h2>
        <div>
          <label className="mb-1.5 block text-xs font-medium text-zinc-600 dark:text-zinc-400">Current password</label>
          <input className="input" type="password" value={cur} onChange={(e) => setCur(e.target.value)} required />
        </div>
        <div>
          <label className="mb-1.5 block text-xs font-medium text-zinc-600 dark:text-zinc-400">New password</label>
          <input className="input" type="password" value={next} onChange={(e) => setNext(e.target.value)} minLength={8} required placeholder="At least 8 characters" />
        </div>
        {pwMsg && <Note kind={pwMsg.kind} text={pwMsg.text} />}
        <button className="btn-primary" disabled={busy}>Update password</button>
      </form>
    </div>
  );
}
