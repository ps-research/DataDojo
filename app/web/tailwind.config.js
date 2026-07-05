/** @type {import('tailwindcss').Config} */
export default {
  darkMode: "class",
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // washi (paper) — light surfaces
        washi: { 50: "#faf7ef", 100: "#f3ece0", 200: "#e9dfcd", 300: "#dbcfb6" },
        // sumi (ink) — text + dark surfaces
        sumi: { DEFAULT: "#282320", 700: "#3a342c", 800: "#231f19", 900: "#1a1712", 950: "#141109" },
        // ai (藍) — indigo accent
        ai: { DEFAULT: "#2c5f8a", light: "#6b9bc7", dark: "#1e4568" },
        // shu (朱) — vermilion, for the red belt + seals
        shu: { DEFAULT: "#c1402f", light: "#dd6252" },
      },
      fontFamily: {
        serif: ["Iowan Old Style", "Palatino Linotype", "Palatino", "Georgia", "serif"],
        sans: ["system-ui", "-apple-system", "Segoe UI", "Roboto", "sans-serif"],
        mono: ["ui-monospace", "SFMono-Regular", "Menlo", "Consolas", "monospace"],
      },
    },
  },
  plugins: [],
};
