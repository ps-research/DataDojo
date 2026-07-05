import { Link, NavLink } from "react-router-dom";
import { useAuth } from "../lib/auth";
import { useTheme } from "../lib/theme";
import { MoonIcon, SunIcon } from "./icons";

export function Navbar() {
  const { user, logout } = useAuth();
  const { theme, toggle } = useTheme();

  const tab = ({ isActive }: { isActive: boolean }) =>
    `rounded-md px-3 py-1.5 text-sm transition-colors ${
      isActive
        ? "bg-stone-100 font-medium text-stone-900 dark:bg-stone-800 dark:text-stone-100"
        : "text-stone-500 hover:text-stone-800 dark:text-stone-400 dark:hover:text-stone-200"
    }`;

  return (
    <header className="sticky top-0 z-20 border-b border-stone-200 bg-white/90 backdrop-blur dark:border-stone-800 dark:bg-stone-950/90">
      <div className="mx-auto flex h-14 max-w-6xl items-center gap-6 px-4">
        <Link to="/" className="flex items-center gap-2 font-semibold tracking-tight">
          <span className="inline-block h-5 w-5 rounded bg-accent" aria-hidden />
          DataDojo
        </Link>
        <nav className="flex items-center gap-1">
          <NavLink to="/problems" className={tab}>
            Problems
          </NavLink>
          <NavLink to="/leaderboard" className={tab}>
            Leaderboard
          </NavLink>
        </nav>
        <div className="ml-auto flex items-center gap-2">
          <button
            onClick={toggle}
            className="btn-ghost h-9 w-9 justify-center p-0"
            title={theme === "dark" ? "Switch to light mode" : "Switch to dark mode"}
            aria-label="Toggle theme"
          >
            {theme === "dark" ? <SunIcon /> : <MoonIcon />}
          </button>
          {user ? (
            <div className="flex items-center gap-3">
              <span className="hidden text-sm text-stone-500 dark:text-stone-400 sm:inline">
                {user.name} · {user.score} pts
              </span>
              <button onClick={() => void logout()} className="btn-ghost">
                Sign out
              </button>
            </div>
          ) : (
            <Link to="/login" className="btn-primary">
              Sign in
            </Link>
          )}
        </div>
      </div>
    </header>
  );
}
