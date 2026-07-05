import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import type { ReactNode } from "react";
import { AuthProvider, useAuth } from "./lib/auth";
import { ThemeProvider } from "./lib/theme";
import { Navbar } from "./components/Navbar";
import { Enso } from "./components/Enso";
import { LoginPage } from "./pages/LoginPage";
import { ProblemsPage } from "./pages/ProblemsPage";
import { SolvePage } from "./pages/SolvePage";
import { LeaderboardPage } from "./pages/LeaderboardPage";

function BootScreen() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-3">
      <Enso className="h-10 w-10 text-ai" spin />
      <p className="text-sm text-sumi/50 dark:text-washi-100/50">Opening the dojo...</p>
    </div>
  );
}

// The whole dojo is gated: cross the entrance (login) before you may train.
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
          <Route path="*" element={<Navigate to="/problems" replace />} />
        </Routes>
      </AuthProvider>
    </ThemeProvider>
  );
}
