import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { api, ApiRequestError, onSessionChange, setAccessToken, tryRestoreSession } from "./api";

export interface SessionUser {
  id: string;
  name: string;
  email: string;
  role: string;
  solvedCount: number;
  score: number;
}

export interface AuthOutcome {
  needsVerification?: boolean;
  email?: string;
}

interface AuthCtx {
  user: SessionUser | null;
  booting: boolean;
  login(email: string, password: string): Promise<AuthOutcome>;
  signup(name: string, email: string, password: string): Promise<AuthOutcome>;
  verifyOtp(email: string, code: string): Promise<void>;
  resendOtp(email: string): Promise<void>;
  logout(): Promise<void>;
}

const Ctx = createContext<AuthCtx>(null as unknown as AuthCtx);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<SessionUser | null>(null);
  const [booting, setBooting] = useState(true);

  useEffect(() => {
    onSessionChange((token) => {
      if (!token) setUser(null);
    });
    void (async () => {
      if (await tryRestoreSession()) {
        try {
          const { user } = await api<{ user: SessionUser }>("/api/auth/me");
          setUser(user);
        } catch {
          setUser(null);
        }
      }
      setBooting(false);
    })();
  }, []);

  const login = useCallback(async (email: string, password: string): Promise<AuthOutcome> => {
    try {
      const data = await api<{ accessToken: string; user: SessionUser }>("/api/auth/login", {
        method: "POST",
        body: JSON.stringify({ email, password }),
      });
      setAccessToken(data.accessToken);
      setUser(data.user);
      return {};
    } catch (err) {
      if (err instanceof ApiRequestError && err.status === 403) {
        const body = err.body as { needsVerification?: boolean; email?: string };
        if (body?.needsVerification) return { needsVerification: true, email: body.email ?? email };
      }
      throw err;
    }
  }, []);

  const signup = useCallback(async (name: string, email: string, password: string): Promise<AuthOutcome> => {
    const data = await api<{ needsVerification?: boolean; email?: string }>("/api/auth/signup", {
      method: "POST",
      body: JSON.stringify({ name, email, password }),
    });
    return { needsVerification: data.needsVerification, email: data.email ?? email };
  }, []);

  const verifyOtp = useCallback(async (email: string, code: string) => {
    const data = await api<{ accessToken: string; user: SessionUser }>("/api/auth/verify-otp", {
      method: "POST",
      body: JSON.stringify({ email, code }),
    });
    setAccessToken(data.accessToken);
    setUser(data.user);
  }, []);

  const resendOtp = useCallback(async (email: string) => {
    await api("/api/auth/resend-otp", { method: "POST", body: JSON.stringify({ email }) });
  }, []);

  const logout = useCallback(async () => {
    await api("/api/auth/logout", { method: "POST" }).catch(() => undefined);
    setAccessToken(null);
    setUser(null);
  }, []);

  const value = useMemo(
    () => ({ user, booting, login, signup, verifyOtp, resendOtp, logout }),
    [user, booting, login, signup, verifyOtp, resendOtp, logout]
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAuth(): AuthCtx {
  return useContext(Ctx);
}
