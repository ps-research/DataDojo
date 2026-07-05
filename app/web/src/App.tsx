import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import type { ReactNode } from "react";
import { AuthProvider, useAuth } from "./lib/auth";
import { ThemeProvider } from "./lib/theme";
import { Navbar } from "./components/Navbar";
import { LoginPage } from "./pages/LoginPage";
import { ProblemsPage } from "./pages/ProblemsPage";
import { SolvePage } from "./pages/SolvePage";
import { LeaderboardPage } from "./pages/LeaderboardPage";

function RequireAuth({ children }: { children: ReactNode }) {
  const { user, booting } = useAuth();
  const location = useLocation();
  if (booting) return <div className="p-10 text-center text-sm text-stone-400">Warming up...</div>;
  if (!user) return <Navigate to="/login" state={{ from: location.pathname }} replace />;
  return <>{children}</>;
}

export default function App() {
  return (
    <ThemeProvider>
      <AuthProvider>
        <Navbar />
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/problems" element={<ProblemsPage />} />
          <Route
            path="/problems/:slug"
            element={
              <RequireAuth>
                <SolvePage />
              </RequireAuth>
            }
          />
          <Route path="/leaderboard" element={<LeaderboardPage />} />
          <Route path="*" element={<Navigate to="/problems" replace />} />
        </Routes>
      </AuthProvider>
    </ThemeProvider>
  );
}
