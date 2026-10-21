import { useEffect, useState, useCallback } from "react";
import { Link } from "react-router-dom";
import { supabase } from "./supabaseClient";

const Dashboard = () => {
  const [counts, setCounts] = useState({
    announcements: null,
    citizenReports: null,
    documentRequests: null,
    activeHotlines: null,
  });
  const [openReports, setOpenReports] = useState(null);
  const [pendingRequests, setPendingRequests] = useState(null);
  const [recentActivity, setRecentActivity] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");

    const [
      announcementsCount,
      reportsCount,
      requestsCount,
      hotlinesCount,
      openReportsCount,
      pendingRequestsCount,
      recentAnnouncements,
      recentReports,
      recentRequests,
    ] = await Promise.all([
      supabase.from("announcements").select("id", { count: "exact", head: true }),
      supabase.from("citizen_reports").select("id", { count: "exact", head: true }),
      supabase.from("document_requests").select("id", { count: "exact", head: true }),
      supabase.from("hotlines").select("id", { count: "exact", head: true }).eq("is_active", true),
      supabase
        .from("citizen_reports")
        .select("id", { count: "exact", head: true })
        .not("status", "in", "(resolved,closed)"),
      supabase
        .from("document_requests")
        .select("id", { count: "exact", head: true })
        .not("status", "in", "(completed,rejected)"),
      supabase.from("announcements").select("id, title, created_at").order("created_at", { ascending: false }).limit(5),
      supabase.from("citizen_reports").select("id, category, subcategory, created_at").order("created_at", { ascending: false }).limit(5),
      supabase.from("document_requests").select("id, document_type, created_at").order("created_at", { ascending: false }).limit(5),
    ]);

    const firstError = [
      announcementsCount, reportsCount, requestsCount, hotlinesCount,
    ].find((r) => r.error)?.error;
    if (firstError) setError(firstError.message);

    setCounts({
      announcements: announcementsCount.count ?? 0,
      citizenReports: reportsCount.count ?? 0,
      documentRequests: requestsCount.count ?? 0,
      activeHotlines: hotlinesCount.count ?? 0,
    });
    setOpenReports(openReportsCount.count ?? 0);
    setPendingRequests(pendingRequestsCount.count ?? 0);

    const activity = [
      ...(recentAnnouncements.data || []).map((a) => ({
        type: "Announcement",
        label: a.title,
        time: a.created_at,
        link: "/announcements",
        icon: "📢",
      })),
      ...(recentReports.data || []).map((r) => ({
        type: "Citizen Report",
        label: r.subcategory || r.category,
        time: r.created_at,
        link: "/citizen-reports",
        icon: "📋",
      })),
      ...(recentRequests.data || []).map((r) => ({
        type: "Document Request",
        label: r.document_type,
        time: r.created_at,
        link: "/document-requests",
        icon: "📄",
      })),
    ]
      .filter((item) => item.time)
      .sort((a, b) => new Date(b.time) - new Date(a.time))
      .slice(0, 8);

    setRecentActivity(activity);
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  // Lazy useState initializer runs once on mount rather than on every
  // render, so referencing Date.now() here stays compliant with the "no
  // impure calls during render" rule — formatTime below reads this cached
  // value instead of calling Date.now() itself during render.
  const [now] = useState(() => Date.now());

  const formatTime = (iso) => {
    const date = new Date(iso);
    const diffMs = now - date.getTime();
    const diffMins = Math.round(diffMs / 60000);
    if (diffMins < 1) return "just now";
    if (diffMins < 60) return `${diffMins}m ago`;
    const diffHours = Math.round(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    const diffDays = Math.round(diffHours / 24);
    return `${diffDays}d ago`;
  };

  const statCards = [
    {
      label: "Announcements",
      value: counts.announcements,
      link: "/announcements",
      color: "text-blue-600 dark:text-blue-400",
    },
    {
      label: "Open Citizen Reports",
      value: openReports,
      link: "/citizen-reports",
      color: "text-yellow-600 dark:text-yellow-400",
    },
    {
      label: "Pending Document Requests",
      value: pendingRequests,
      link: "/document-requests",
      color: "text-purple-600 dark:text-purple-400",
    },
    {
      label: "Active Hotlines",
      value: counts.activeHotlines,
      link: "/emergency-hotline",
      color: "text-red-600 dark:text-red-400",
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-800 dark:text-white">Dashboard</h1>
        <p className="text-gray-600 dark:text-gray-400">
          Live overview from the shared Supabase backend — the same data residents see in the
          Milaud mobile app.
        </p>
      </div>

      {error && (
        <div className="rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 text-sm px-4 py-3">
          {error}
        </div>
      )}

      {/* Stat cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {statCards.map((card) => (
          <Link
            key={card.label}
            to={card.link}
            className="bg-white dark:bg-gray-800 rounded-xl p-5 border dark:border-gray-700 hover:shadow-md transition"
          >
            <div className={`text-3xl font-bold ${card.color}`}>
              {loading ? "…" : card.value}
            </div>
            <div className="text-sm text-gray-600 dark:text-gray-400 mt-1">{card.label}</div>
          </Link>
        ))}
      </div>

      {/* Recent activity */}
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-6 border dark:border-gray-700">
        <h3 className="text-lg font-semibold text-gray-800 dark:text-white mb-4">
          Recent Activity
        </h3>
        {loading && <p className="text-sm text-gray-500 dark:text-gray-400">Loading…</p>}
        {!loading && recentActivity.length === 0 && (
          <p className="text-sm text-gray-500 dark:text-gray-400">
            No activity yet — once residents start submitting reports and requests, they'll
            show up here in real time.
          </p>
        )}
        <div className="space-y-3">
          {recentActivity.map((item, idx) => (
            <Link
              key={idx}
              to={item.link}
              className="flex items-center justify-between p-3 border dark:border-gray-700 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700/50"
            >
              <div className="flex items-center space-x-3">
                <span className="text-xl">{item.icon}</span>
                <div>
                  <div className="text-sm font-medium text-gray-800 dark:text-white">
                    {item.label}
                  </div>
                  <div className="text-xs text-gray-500 dark:text-gray-400">{item.type}</div>
                </div>
              </div>
              <div className="text-xs text-gray-400">{formatTime(item.time)}</div>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
