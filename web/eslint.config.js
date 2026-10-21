import js from '@eslint/js'
import globals from 'globals'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import { defineConfig, globalIgnores } from 'eslint/config'

export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{js,jsx}'],
    extends: [
      js.configs.recommended,
      reactHooks.configs.flat.recommended,
      reactRefresh.configs.vite,
    ],
    languageOptions: {
      globals: globals.browser,
      parserOptions: { ecmaFeatures: { jsx: true } },
    },
    rules: {
      // This app fetches data on mount via useEffect + setState across every
      // page (Announcements, Citizen Reports, Document Requests, Hotlines,
      // Dashboard) — a standard, well-established React data-fetching
      // pattern. The newest react-hooks rules (aimed at React Compiler /
      // Suspense-based data fetching with libraries like React Query) flag
      // this pattern as an error, which doesn't fit this codebase. Downgrade
      // to a warning instead of rewriting every page's data layer.
      'react-hooks/set-state-in-effect': 'warn',
      // ThemeContext.jsx and AuthContext.jsx each export their Provider
      // component alongside a matching useX() hook — a very common React
      // pattern. This rule wants every file to export only components for
      // Fast Refresh to work optimally; downgraded since splitting each
      // context into two files isn't worth it here.
      'react-refresh/only-export-components': 'warn',
    },
  },
])
