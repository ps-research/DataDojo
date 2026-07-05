import { Link, NavLink } from "react-router-dom";
import { useAuth } from "../lib/auth";
import { useTheme } from "../lib/theme";
import { MoonIcon, SunIcon } from "./icons";
import { Logo } from "./Logo";

export function Navbar() {
  const { user, logout } = useAuth();
  const { theme, toggle } = useTheme();

  const tab = ({ isActive }: { isActive: boolean }) =>
    `text-sm transition-colors ${
      isActive
        ? "text-zinc-900 dark:text-zinc-100 font-medium"
        : "text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100"
    }`;

  return (
    <header className="sticky top-0 z-20 border-b border-zinc-200 bg-white/80 backdrop-blur dark:border-zinc-800 dark:bg-zinc-950/80">
      <div className="mx-auto flex h-14 max-w-6xl items-center gap-7 px-4">
        <Link to="/problems" className="flex items-center gap-2">
          <Logo className="h-6 w-6" />
          <span className="text-[15px] font-semibold tracking-tight">DataDojo</span>
        </Link>
        <nav className="flex items-center gap-5">
          <NavLink to="/problems" className={tab}>Problems</NavLink>
          <NavLink to="/leaderboard" className={tab}>Leaderboard</NavLink>
        </nav>
        <div className="ml-auto flex items-center gap-1.5">
          <button
            onClick={toggle}
            className="btn-ghost h-9 w-9 p-0"
            title={theme === "dark" ? "Light mode" : "Dark mode"}
            aria-label="Toggle theme"
          >
            {theme === "dark" ? <SunIcon /> : <MoonIcon />}
          </button>
          {user && (
            <div className="flex items-center gap-3 pl-1.5">
              <span className="hidden text-sm text-zinc-500 dark:text-zinc-400 sm:inline">
                {user.name} · <span className="font-mono text-zinc-700 dark:text-zinc-300">{user.score}</span>
              </span>
              <button onClick={() => void logout()} className="btn-ghost text-sm">Sign out</button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}
