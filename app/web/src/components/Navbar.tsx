import { Link, NavLink } from "react-router-dom";
import { useAuth } from "../lib/auth";
import { useTheme } from "../lib/theme";
import { MoonIcon, SunIcon } from "./icons";
import { Enso } from "./Enso";

export function Navbar() {
  const { user, logout } = useAuth();
  const { theme, toggle } = useTheme();

  const tab = ({ isActive }: { isActive: boolean }) =>
    `rounded-md px-3 py-1.5 text-sm transition-colors ${
      isActive
        ? "bg-washi-200 font-medium text-sumi dark:bg-sumi-700 dark:text-washi-50"
        : "text-sumi/55 hover:text-sumi dark:text-washi-100/55 dark:hover:text-washi-100"
    }`;

  return (
    <header className="sticky top-0 z-20 border-b border-washi-300 bg-washi-100/90 backdrop-blur dark:border-sumi-700 dark:bg-sumi-900/90">
      <div className="mx-auto flex h-14 max-w-6xl items-center gap-6 px-4">
        <Link to="/problems" className="flex items-center gap-2">
          <Enso className="h-6 w-6 text-shu" />
          <span className="font-serif text-lg tracking-wide">DataDojo</span>
          <span className="kanji hidden text-base sm:inline">道場</span>
        </Link>
        <nav className="flex items-center gap-1">
          <NavLink to="/problems" className={tab}>
            Problems
          </NavLink>
          <NavLink to="/leaderboard" className={tab}>
            Ranking
          </NavLink>
        </nav>
        <div className="ml-auto flex items-center gap-2">
          <button
            onClick={toggle}
            className="btn-ghost h-9 w-9 justify-center p-0"
            title={theme === "dark" ? "Light" : "Dark"}
            aria-label="Toggle theme"
          >
            {theme === "dark" ? <SunIcon /> : <MoonIcon />}
          </button>
          {user && (
            <div className="flex items-center gap-3">
              <span className="hidden text-sm text-sumi/60 dark:text-washi-100/60 sm:inline">
                {user.name} · <span className="font-mono">{user.score}</span>
              </span>
              <button onClick={() => void logout()} className="btn-ghost">
                Leave
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}
