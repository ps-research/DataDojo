import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import type { ReactNode } from "react";
import { AuthProvider, useAuth } from "./lib/auth";
import { ThemeProvider } from "./lib/theme";
import { Navbar } from "./components/Navbar";
import { Spinner } from "./components/Logo";
import { LoginPage } from "./pages/LoginPage";
import { ProblemsPage } from "./pages/ProblemsPage";
import { SolvePage } from "./pages/SolvePage";
import { LeaderboardPage } from "./pages/LeaderboardPage";
import { ProfilePage } from "./pages/ProfilePage";
import { SettingsPage } from "./pages/SettingsPage";

function BootScreen() {
  return (
    <div className="flex min-h-screen items-center justify-center text-zinc-400">
      <Spinner className="h-6 w-6" />
    </div>
  );
}

// The whole site is gated: sign in before entering.
function Gated({ children }: { children: ReactNode }) {
  const { user, booting } = useAuth();
  const location = useLocation();
  if (booting) return <BootScreen />;
  if (!user) return <Navigate to="/login" state={{ from: location.pathname }} replace />;
  return (
    <>
      <Navbar />
      {children}
    </>
  );
}

function LoginGate() {
  const { user, booting } = useAuth();
  if (booting) return <BootScreen />;
  if (user) return <Navigate to="/problems" replace />;
  return <LoginPage />;
}

export default function App() {
  return (
    <ThemeProvider>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<LoginGate />} />
          <Route path="/problems" element={<Gated><ProblemsPage /></Gated>} />
          <Route path="/problems/:slug" element={<Gated><SolvePage /></Gated>} />
          <Route path="/leaderboard" element={<Gated><LeaderboardPage /></Gated>} />
          <Route path="/profile" element={<Gated><ProfilePage /></Gated>} />
          <Route path="/settings" element={<Gated><SettingsPage /></Gated>} />
          <Route path="*" element={<Navigate to="/problems" replace />} />
        </Routes>
      </AuthProvider>
    </ThemeProvider>
  );
}
