import { createContext, useState, useContext, useEffect } from "react";

const ThemeContext = createContext();

export const useTheme = () => useContext(ThemeContext);

// Palette source of truth: the mobile app's AppColors design system
// (may_laud/lib/theme/app_colors.dart) — light and dark map 1:1 to
// AppColors.light / AppColors.dark.
const themes = {
  light: {
    name: "light",
    primary: "#0056A3", // Milaor Blue - Primary Brand / Buttons
    secondary: "#212529", // Near-black - Primary Text / Headings
    background: "#F8F9FA", // Light gray - Background / Canvas
    text: "#212529", // Near-black - Primary Text / Headings
    card: "#FFFFFF", // White - Card Surface
    border: "#E9ECEF", // Light gray - Input Borders / Dividers
    accent: "#F6F2FC", // Lavender wash - Accent / Soft Shapes
    error: "#DC3545", // Error / Alert
  },
  dark: {
    name: "dark",
    primary: "#66B5FF", // Softened blue for dark mode
    secondary: "#E9ECEF", // Near-white text in dark mode
    background: "#121212", // Dark background
    text: "#E9ECEF", // Near-white text
    card: "#1E1E1E", // Dark surface for cards
    border: "#444444", // Dark mode borders
    accent: "#252030", // Muted purple-tinted surface
    error: "#CF6679", // Error / Alert (dark mode)
  },
};

export const ThemeProvider = ({ children }) => {
  const [currentTheme, setCurrentTheme] = useState(() => {
    // Check localStorage for saved theme
    const saved = localStorage.getItem("milaud-theme");
    return saved && themes[saved] ? themes[saved] : themes.light;
  });

  const changeTheme = (themeName) => {
    if (themes[themeName]) {
      setCurrentTheme(themes[themeName]);
      localStorage.setItem("milaud-theme", themeName);
      
      // Sync with mobile app (simulated)
      syncThemeWithMobile(themes[themeName]);
    }
  };

  // Function to sync theme with mobile app
  const syncThemeWithMobile = (theme) => {
    // In a real app, this would be an API call to your backend
    // which would then push to mobile apps via Firebase Cloud Messaging or similar
    console.log("Syncing theme with mobile app:", theme);
    
    // Simulate API call
    fetch("https://api.milaor.gov.ph/sync-theme", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        theme: theme.name,
        colors: theme,
        timestamp: new Date().toISOString(),
      }),
    }).catch(() => console.log("Theme sync (simulated):", theme.name));
    
    // Also store in localStorage for mobile app to read (if using same domain)
    localStorage.setItem("milaud-mobile-theme", JSON.stringify(theme));
  };

  // Apply theme to document root for CSS variables
  useEffect(() => {
    const root = document.documentElement;
    root.style.setProperty("--primary-color", currentTheme.primary);
    root.style.setProperty("--secondary-color", currentTheme.secondary);
    root.style.setProperty("--background-color", currentTheme.background);
    root.style.setProperty("--text-color", currentTheme.text);
    root.style.setProperty("--card-color", currentTheme.card);
    root.style.setProperty("--border-color", currentTheme.border);
    root.style.setProperty("--accent-color", currentTheme.accent || "#E8E2F7");
    root.style.setProperty("--error-color", currentTheme.error || "#F8E7EF");
    
    // Add theme class to body for Tailwind dark mode
    if (currentTheme.name === "dark") {
      document.body.classList.add("dark");
    } else {
      document.body.classList.remove("dark");
    }
  }, [currentTheme]);

  // Initialize theme sync on load
  useEffect(() => {
    // Check if there's a mobile theme preference
    const mobileTheme = localStorage.getItem("milaud-mobile-theme");
    if (mobileTheme) {
      try {
        const parsed = JSON.parse(mobileTheme);
        if (parsed.name && parsed.name !== currentTheme.name) {
          console.log("Mobile theme preference detected:", parsed.name);
          // Optional: Ask user if they want to sync from mobile
        }
      } catch (e) {
        console.error("Error parsing mobile theme:", e);
      }
    }
  }, []);

  return (
    <ThemeContext.Provider value={{ currentTheme, themes, changeTheme }}>
      {children}
    </ThemeContext.Provider>
  );
};

// Custom hook for theme-aware styling
export const useThemeColors = () => {
  const { currentTheme } = useTheme();
  return currentTheme;
};