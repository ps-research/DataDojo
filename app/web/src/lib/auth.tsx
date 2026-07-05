import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { api, onSessionChange, setAccessToken, tryRestoreSession } from "./api";

export interface SessionUser {
  id: string;
  name: string;
  email: string;
  role: string;
  solvedCount: number;
  score: number;
}

interface AuthCtx {
  user: SessionUser | null;
  booting: boolean;
  login(email: string, password: string): Promise<void>;
  signup(name: string, email: string, password: string): Promise<void>;
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

  const login = useCallback(async (email: string, password: string) => {
    const data = await api<{ accessToken: string; user: SessionUser }>("/api/auth/login", {
      method: "POST",
      body: JSON.stringify({ email, password }),
    });
    setAccessToken(data.accessToken);
    setUser(data.user);
  }, []);

  const signup = useCallback(async (name: string, email: string, password: string) => {
    const data = await api<{ accessToken: string; user: SessionUser }>("/api/auth/signup", {
      method: "POST",
      body: JSON.stringify({ name, email, password }),
    });
    setAccessToken(data.accessToken);
    setUser(data.user);
  }, []);

  const logout = useCallback(async () => {
    await api("/api/auth/logout", { method: "POST" }).catch(() => undefined);
    setAccessToken(null);
    setUser(null);
  }, []);

  const value = useMemo(() => ({ user, booting, login, signup, logout }), [user, booting, login, signup, logout]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAuth(): AuthCtx {
  return useContext(Ctx);
}
