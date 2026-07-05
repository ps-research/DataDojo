// Minimal fetch wrapper: attaches the in-memory access token, silently
// refreshes once on 401 (httpOnly cookie), and surfaces {error} bodies.

let accessToken: string | null = null;
let onSession: ((token: string | null) => void) | null = null;

export function setAccessToken(t: string | null): void {
  accessToken = t;
}
export function getAccessToken(): string | null {
  return accessToken;
}
export function onSessionChange(fn: (token: string | null) => void): void {
  onSession = fn;
}

export class ApiRequestError extends Error {
  constructor(public status: number, message: string, public body?: unknown) {
    super(message);
  }
}

async function refresh(): Promise<boolean> {
  try {
    const res = await fetch("/api/auth/refresh", { method: "POST", credentials: "include" });
    if (!res.ok) return false;
    const data = (await res.json()) as { accessToken: string };
    accessToken = data.accessToken;
    onSession?.(accessToken);
    return true;
  } catch {
    return false;
  }
}

export async function api<T>(path: string, options: RequestInit = {}, retried = false): Promise<T> {
  const headers: Record<string, string> = {
    ...(options.body ? { "Content-Type": "application/json" } : {}),
    ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
    ...((options.headers as Record<string, string>) ?? {}),
  };
  const res = await fetch(path, { ...options, headers, credentials: "include" });
  if (res.status === 401 && !retried && !path.startsWith("/api/auth/")) {
    if (await refresh()) return api<T>(path, options, true);
    accessToken = null;
    onSession?.(null);
  }
  const body = (await res.json().catch(() => ({}))) as { error?: string };
  if (!res.ok) throw new ApiRequestError(res.status, body.error ?? `Request failed (${res.status})`, body);
  return body as T;
}

export async function tryRestoreSession(): Promise<boolean> {
  return refresh();
}
