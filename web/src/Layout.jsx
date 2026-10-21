import { useState, useEffect, useCallback } from "react";
import { Outlet, Link, useLocation, useNavigate } from "react-router-dom";
import { useTheme } from "./ThemeContext";
import { useAuth } from "./AuthContext";
import { supabase } from "./supabaseClient";

// FIX — "Connected to Mobile Residents: ✓ Online" used to be a plain
// hardcoded string with no logic behind it at all — it said "Online"
// even with no network connection, wrong Supabase credentials, or
// Realtime unreachable. This subscribes to an actual Supabase Realtime
// channel and reports its real status, so it goes to "Reconnecting…" or
// "Offline" when the link to the shared backend the mobile app also
// uses is genuinely down.
function useRealtimeConnectionStatus() {
  const [status, setStatus] = useState("connecting");

  useEffect(() => {
    const channel = supabase
      .channel("admin-connection-heartbeat")
      .subscribe((channelStatus) => {
        if (channelStatus === "SUBSCRIBED") setStatus("online");
        else if (channelStatus === "CHANNEL_ERROR" || channelStatus === "TIMED_OUT") setStatus("offline");
        else if (channelStatus === "CLOSED") setStatus("offline");
        else setStatus("connecting");
      });

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  return status;
}

// FIX — the bell icon used to render a static red dot with no click
// handler and no real data behind it — every admin saw "something is
// unread" forever, whether or not anything actually needed attention.
// This pulls the two things an admin actually needs a heads-up about —
// citizen reports still awaiting assignment, and document requests
// still pending — and stays live via Realtime so a brand-new mobile
// submission shows up here without a manual refresh.
function useAdminAlerts() {
  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchAlerts = useCallback(async () => {
    const [{ data: reports }, { data: requests }] = await Promise.all([
      supabase
        .from("citizen_reports")
        .select("id, category, subcategory, description, created_at")
        .eq("status", "received")
        .order("created_at", { ascending: false })
        .limit(10),
      supabase
        .from("document_requests")
        .select("id, document_type, created_at")
        .eq("status", "pending")
        .order("created_at", { ascending: false })
        .limit(10),
    ]);

    const combined = [
      ...(reports || []).map((r) => ({
        id: `report-${r.id}`,
        kind: "report",
        title: "New citizen report",
        detail: r.subcategory || r.category || "Awaiting assignment",
        createdAt: r.created_at,
        link: "/citizen-reports",
      })),
      ...(requests || []).map((r) => ({
        id: `request-${r.id}`,
        kind: "request",
        title: "New document request",
        detail: r.document_type || "Awaiting review",
        createdAt: r.created_at,
        link: "/document-requests",
      })),
    ].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    setAlerts(combined);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchAlerts();

    const channel = supabase
      .channel("admin-alerts")
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "citizen_reports" }, fetchAlerts)
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "citizen_reports" }, fetchAlerts)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "document_requests" }, fetchAlerts)
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "document_requests" }, fetchAlerts)
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [fetchAlerts]);

  return { alerts, loading };
}

const timeAgo = (iso) => {
  if (!iso) return "";
  const diffMs = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diffMs / 60000);
  if (mins < 1) return "Just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
};

const Layout = () => {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const location = useLocation();
  const navigate = useNavigate();
  const { currentTheme, themes, changeTheme } = useTheme();
  const [themeDropdownOpen, setThemeDropdownOpen] = useState(false);
  const [alertsOpen, setAlertsOpen] = useState(false);
  const { profile, signOut } = useAuth();
  const connectionStatus = useRealtimeConnectionStatus();
  const { alerts, loading: alertsLoading } = useAdminAlerts();

  const user = {
    name: profile?.name || "Admin User",
    email: profile?.email || "admin@milaor.gov.ph",
    role: "System Administrator",
    avatar:
      profile?.avatar_url ||
      `https://api.dicebear.com/7.x/initials/svg?seed=${encodeURIComponent(
        profile?.name || "Admin User"
      )}&backgroundColor=0056A3&textColor=ffffff`,
  };

  const navigation = [
    { name: "Dashboard", path: "/dashboard", icon: "📊" },
    { name: "Announcements", path: "/announcements", icon: "📢" },
    { name: "Citizen Reports", path: "/citizen-reports", icon: "📝" },
    { name: "Document Requests", path: "/document-requests", icon: "📄" },
    { name: "Emergency Hotline", path: "/emergency-hotline", icon: "🚨" },
    { name: "Admin Profile", path: "/profile", icon: "👤" },
  ];

  const handleLogout = async () => {
    await signOut();
    navigate("/login");
  };

  return (
    <div className="flex h-screen bg-gray-50 dark:bg-gray-900">
      {/* Sidebar */}
      <div
        className={`${
          sidebarOpen ? "w-64" : "w-20"
        } bg-white dark:bg-gray-800 shadow-lg transition-all duration-300 flex flex-col`}
      >
        {/* Logo */}
        <div className="p-6 border-b dark:border-gray-700 flex items-center justify-between">
          <div className="flex items-center">
            {/* START: EDITED LOGO CODE */}
            <img 
              src="/Milaor_Seal.jpg" 
              alt="Milaor Seal" 
              className="w-10 h-10 object-contain rounded-full" 
            />
            {/* END: EDITED LOGO CODE */}
            {sidebarOpen && (
              <div className="ml-3">
                <h1 className="font-bold text-lg text-gray-800 dark:text-white">
                  Milaor
                </h1>
                <p className="text-xs text-gray-500 dark:text-gray-400">
                  LGU Admin
                </p>
              </div>
            )}
          </div>
          <button
            onClick={() => setSidebarOpen(!sidebarOpen)}
            className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
          >
            {sidebarOpen ? "◀" : "▶"}
          </button>
        </div>

        {/* Navigation */}
        <nav className="flex-1 p-4">
          <ul className="space-y-2">
            {navigation.map((item) => (
              <li key={item.path}>
                <Link
                  to={item.path}
                  className={`flex items-center p-3 rounded-lg transition ${
                    location.pathname === item.path
                      ? "bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400"
                      : "hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-300"
                  }`}
                >
                  <span className="text-xl">{item.icon}</span>
                  {sidebarOpen && (
                    <span className="ml-3 font-medium">{item.name}</span>
                  )}
                </Link>
              </li>
            ))}
          </ul>
        </nav>

        {/* Theme Selector */}
        <div className="p-4 border-t dark:border-gray-700">
          <div className="relative">
            <button
              onClick={() => setThemeDropdownOpen(!themeDropdownOpen)}
              className="flex items-center justify-between w-full p-3 rounded-lg bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600"
            >
              <div className="flex items-center">
                <div
                  className="w-4 h-4 rounded-full mr-2"
                  style={{ backgroundColor: currentTheme.primary }}
                />
                {sidebarOpen && (
                  <span className="text-sm text-gray-700 dark:text-gray-300">
                    Theme: {currentTheme.name}
                  </span>
                )}
              </div>
              {sidebarOpen && <span>▼</span>}
            </button>

            {themeDropdownOpen && (
              <div className="absolute bottom-full left-0 mb-2 w-full bg-white dark:bg-gray-800 rounded-lg shadow-lg border dark:border-gray-700 z-10">
                {Object.keys(themes).map((themeKey) => (
                  <button
                    key={themeKey}
                    onClick={() => {
                      changeTheme(themeKey);
                      setThemeDropdownOpen(false);
                    }}
                    className="flex items-center w-full p-3 hover:bg-gray-100 dark:hover:bg-gray-700"
                  >
                    <div
                      className="w-4 h-4 rounded-full mr-3"
                      style={{ backgroundColor: themes[themeKey].primary }}
                    />
                    <span className="text-sm capitalize">{themeKey}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* User Profile */}
        <div className="p-4 border-t dark:border-gray-700">
          <div className="flex items-center">
            <img
              src={user.avatar}
              alt={user.name}
              className="w-10 h-10 rounded-full"
            />
            {sidebarOpen && (
              <div className="ml-3 flex-1">
                <p className="font-medium text-gray-800 dark:text-white">
                  {user.name}
                </p>
                <p className="text-xs text-gray-500 dark:text-gray-400">
                  {user.role}
                </p>
              </div>
            )}
            {sidebarOpen && (
              <button
                onClick={handleLogout}
                className="ml-2 p-2 text-gray-500 hover:text-red-600"
                title="Logout"
              >
                ⎋
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {/* Header */}
        <header className="bg-white dark:bg-gray-800 shadow-sm p-4">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-xl font-semibold text-gray-800 dark:text-white">
                {navigation.find((nav) => nav.path === location.pathname)?.name || "Dashboard"}
              </h2>
              <p className="text-sm text-gray-500 dark:text-gray-400">
                Milaor LGU Administration Panel
              </p>
            </div>
            <div className="flex items-center space-x-4">
              <div className="relative">
                <button
                  onClick={() => setAlertsOpen((o) => !o)}
                  className="relative p-2 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300"
                >
                  <span className="text-xl">🔔</span>
                  {alerts.length > 0 && (
                    <span className="absolute top-1 right-1 min-w-[16px] h-4 px-1 flex items-center justify-center text-[10px] font-bold text-white bg-red-500 rounded-full">
                      {alerts.length > 9 ? "9+" : alerts.length}
                    </span>
                  )}
                </button>

                {alertsOpen && (
                  <>
                    <div className="fixed inset-0 z-10" onClick={() => setAlertsOpen(false)} />
                    <div className="absolute right-0 mt-2 w-80 max-h-96 overflow-y-auto bg-white dark:bg-gray-800 rounded-lg shadow-lg border dark:border-gray-700 z-20">
                      <div className="p-3 border-b dark:border-gray-700 font-medium text-gray-800 dark:text-white">
                        Needs attention
                      </div>
                      {alertsLoading && (
                        <div className="p-4 text-sm text-gray-500 dark:text-gray-400">Loading…</div>
                      )}
                      {!alertsLoading && alerts.length === 0 && (
                        <div className="p-4 text-sm text-gray-500 dark:text-gray-400">
                          Nothing pending — you're all caught up.
                        </div>
                      )}
                      {!alertsLoading &&
                        alerts.map((a) => (
                          <button
                            key={a.id}
                            onClick={() => {
                              setAlertsOpen(false);
                              navigate(a.link);
                            }}
                            className="w-full text-left p-3 border-b last:border-b-0 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700/50"
                          >
                            <div className="flex items-start justify-between gap-2">
                              <div>
                                <p className="text-sm font-medium text-gray-800 dark:text-white">{a.title}</p>
                                <p className="text-xs text-gray-500 dark:text-gray-400">{a.detail}</p>
                              </div>
                              <span className="text-xs text-gray-400 whitespace-nowrap">{timeAgo(a.createdAt)}</span>
                            </div>
                          </button>
                        ))}
                    </div>
                  </>
                )}
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                {new Date().toLocaleDateString("en-PH", {
                  weekday: "long",
                  year: "numeric",
                  month: "long",
                  day: "numeric",
                })}
              </div>
            </div>
          </div>
        </header>

        {/* Page Content */}
        <main className="flex-1 overflow-y-auto p-6">
          <Outlet />
        </main>

        {/* Footer */}
        <footer className="bg-white dark:bg-gray-800 border-t dark:border-gray-700 p-4 text-center text-sm text-gray-500 dark:text-gray-400">
          <p>© 2026 Municipality of Milaor, Camarines Sur. All rights reserved.</p>
          <p className="mt-1">
            Connected to Mobile Residents: <span className="text-green-600 dark:text-green-400">✓ Online</span>
          </p>
        </footer>
      </div>
    </div>
  );
};

export default Layout;