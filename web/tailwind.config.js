/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // Theme-context driven tokens (see ThemeContext.jsx / index.css)
        primary: 'var(--primary-color)',
        secondary: 'var(--secondary-color)',
        background: 'var(--background-color)',
        text: 'var(--text-color)',
        card: 'var(--card-color)',
        border: 'var(--border-color)',
        accent: 'var(--accent-color)',
        error: 'var(--error-color)',

        // Maylaud brand palette — same values used by the mobile app's
        // AppColors design system (lib/theme/app_colors.dart), so the
        // web admin panel and the resident mobile app read as one product.
        'milaor-blue': '#0056A3',      // primary
        'philippine-gold': '#FDB913',  // secondary
        'philippine-red': '#CE1126',   // accent
        'philippine-green': '#0C5A43', // success
        'heritage-purple': '#4C229C',  // accent purple (home/profile/auth)
        'river-flow': '#643EB5',       // mid purple
        'deep-anchor': '#24005B',      // dark purple anchor

        // Tailwind's default "blue" scale is overridden so every existing
        // bg-blue-*/text-blue-*/border-blue-* utility across the app
        // automatically renders in the mobile app's primary blue.
        blue: {
          50: '#F0F5F9',
          100: '#DBE7F2',
          200: '#B8D0E5',
          300: '#8CB3D6',
          400: '#528CC0',
          500: '#266FB1',
          600: '#0056A3',
          700: '#004786',
          800: '#003768',
          900: '#00294E',
          950: '#001C34',
        },
        // Tailwind's default "purple" scale, overridden to match the
        // mobile app's heritage-purple accent family.
        purple: {
          50: '#F4F2F9',
          100: '#E6E0F1',
          200: '#CDC1E3',
          300: '#AE9CD2',
          400: '#8569BC',
          500: '#6743AB',
          600: '#4C229C',
          700: '#3E1C80',
          800: '#311664',
          900: '#24104B',
          950: '#180B32',
        },
        // Tailwind's default "indigo" scale, aligned to the same purple
        // family so gradients (from-blue to-indigo, etc.) stay cohesive.
        indigo: {
          50: '#F4F2F9',
          100: '#E6E0F1',
          200: '#CDC1E3',
          300: '#AE9CD2',
          400: '#8569BC',
          500: '#6743AB',
          600: '#4C229C',
          700: '#3E1C80',
          800: '#311664',
          900: '#24104B',
          950: '#180B32',
        },
        // Tailwind's default "yellow" scale (used for "pending"/warning
        // badges throughout the app), aligned to the mobile app's
        // Philippine-gold secondary / warning color.
        yellow: {
          50: '#FFFBF1',
          100: '#FFF5DE',
          200: '#FEEBBD',
          300: '#FEE095',
          400: '#FECF5F',
          500: '#FDC436',
          600: '#FDB913',
          700: '#CF9810',
          800: '#A2760C',
          900: '#795909',
          950: '#513B06',
        },
      },
      fontFamily: {
        // Body copy — matches the mobile app's Inter body font.
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        // Headings — matches the mobile app's Poppins display font.
        heading: ['Poppins', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
      borderRadius: {
        // Mirrors AppTheme's borderRadius* tokens from the mobile app.
        DEFAULT: '12px',
        xs: '4px',
        sm: '8px',
        md: '12px',
        lg: '16px',
        xl: '24px',
      },
      boxShadow: {
        // Mirrors AppTheme's shadow* tokens from the mobile app.
        xs: '0 1px 2px 0 rgba(0,0,0,0.04)',
        sm: '0 2px 4px 0 rgba(0,0,0,0.08)',
        md: '0 4px 8px 0 rgba(0,0,0,0.12)',
        lg: '0 8px 16px 0 rgba(0,0,0,0.16)',
        xl: '0 12px 24px 0 rgba(0,0,0,0.24)',
      },
      backgroundImage: {
        // Mirrors AppColors.headerGradient / fabGradient / primaryGradient.
        'header-gradient': 'linear-gradient(135deg, #24005B 0%, #4C229C 100%)',
        'fab-gradient': 'linear-gradient(135deg, #643EB5 0%, #4C229C 100%)',
        'primary-gradient': 'linear-gradient(135deg, #0056A3 0%, #0077CC 100%)',
      },
    },
  },
  plugins: [],
}
