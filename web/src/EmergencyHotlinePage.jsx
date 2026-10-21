import { useState, useEffect, useCallback } from "react";
import { supabase } from "./supabaseClient";

const hotlineTypes = ["General", "Police", "Fire", "Medical", "Disaster", "Social", "Utility"];

const EmergencyHotlinePage = () => {
  const [hotlines, setHotlines] = useState([]);
  const [hotlinesLoading, setHotlinesLoading] = useState(true);
  const [hotlineSchemaNote, setHotlineSchemaNote] = useState("");

  const [floodAlerts, setFloodAlerts] = useState([]);
  const [alertsLoading, setAlertsLoading] = useState(true);

  const [error, setError] = useState("");

  const [newHotline, setNewHotline] = useState({
    name: "",
    number: "",
    type: "General",
  });

  const [newAlert, setNewAlert] = useState({
    level: "Moderate",
    affected_areas: "",
    water_level: "",
    advice: "",
  });

  const fetchHotlines = useCallback(async () => {
    setHotlinesLoading(true);
    const { data, error } = await supabase
      .from("hotlines")
      .select("*")
      .order("name", { ascending: true });
    if (error) {
      setError(error.message);
    } else {
      setHotlines(data || []);
    }
    setHotlinesLoading(false);
  }, []);

  const fetchFloodAlerts = useCallback(async () => {
    setAlertsLoading(true);
    const { data, error } = await supabase
      .from("flood_alerts")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(20);
    if (error) {
      // Table may not exist / be reachable — don't block the rest of the page.
      setFloodAlerts([]);
    } else {
      setFloodAlerts(data || []);
    }
    setAlertsLoading(false);
  }, []);

  useEffect(() => {
    fetchHotlines();
    fetchFloodAlerts();
  }, [fetchHotlines, fetchFloodAlerts]);

  // The mobile app's HotlineService only ever selects `name` + `is_active`,
  // so those are the two columns we know for certain exist. We attempt a
  // richer insert first (name, number, type, is_active) and gracefully fall
  // back to the minimal shape if Supabase rejects an unknown column.
  const handleAddHotline = async (e) => {
    e.preventDefault();
    setError("");
    setHotlineSchemaNote("");

    const fullPayload = {
      name: newHotline.name,
      number: newHotline.number,
      type: newHotline.type,
      is_active: true,
    };

    let { error } = await supabase.from("hotlines").insert(fullPayload);

    if (error) {
      // Retry with just the confirmed columns.
      const minimalPayload = { name: newHotline.name, is_active: true };
      const retry = await supabase.from("hotlines").insert(minimalPayload);
      if (retry.error) {
        setError(retry.error.message);
        return;
      }
      setHotlineSchemaNote(
        "Saved with just the name — your `hotlines` table doesn't have a `number`/`type` column yet, so those weren't stored."
      );
    }

    await fetchHotlines();
    setNewHotline({ name: "", number: "", type: "General" });
  };

  const handleToggleHotline = async (id, isActive) => {
    setHotlines((prev) => prev.map((h) => (h.id === id ? { ...h, is_active: !isActive } : h)));
    const { error } = await supabase.from("hotlines").update({ is_active: !isActive }).eq("id", id);
    if (error) setError(error.message);
  };

  const handleDeleteHotline = async (id) => {
    if (!window.confirm("Delete this hotline number?")) return;
    const { error } = await supabase.from("hotlines").delete().eq("id", id);
    if (error) {
      setError(error.message);
    } else {
      setHotlines((prev) => prev.filter((h) => h.id !== id));
    }
  };

  const handleAddAlert = async (e) => {
    e.preventDefault();
    setError("");
    const payload = {
      level: newAlert.level,
      affected_areas: newAlert.affected_areas
        ? newAlert.affected_areas.split(",").map((s) => s.trim()).filter(Boolean)
        : [],
      water_level: newAlert.water_level,
      advice: newAlert.advice,
      is_active: true,
    };
    const { error } = await supabase.from("flood_alerts").insert(payload);
    if (error) {
      setError(error.message);
    } else {
      await fetchFloodAlerts();
      setNewAlert({ level: "Moderate", affected_areas: "", water_level: "", advice: "" });
    }
  };

  const handleResolveAlert = async (id) => {
    setFloodAlerts((prev) => prev.map((a) => (a.id === id ? { ...a, is_active: false } : a)));
    const { error } = await supabase.from("flood_alerts").update({ is_active: false }).eq("id", id);
    if (error) setError(error.message);
  };

  const levelColors = {
    Low: "bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300",
    Moderate: "bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300",
    High: "bg-orange-100 dark:bg-orange-900/30 text-orange-800 dark:text-orange-300",
    Critical: "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300",
  };

  const formatDate = (iso) => {
    if (!iso) return "—";
    return new Date(iso).toLocaleString("en-PH", {
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  const activeAlerts = floodAlerts.filter((a) => a.is_active);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-gray-800 dark:text-white">
            Emergency Hotline & Alert Management
          </h1>
          <p className="text-gray-600 dark:text-gray-400">
            Manage the hotline directory and flood/emergency alerts residents see in the mobile app
          </p>
        </div>
        {activeAlerts.length > 0 && (
          <div className="flex items-center space-x-2">
            <div className="w-3 h-3 rounded-full bg-red-500 animate-pulse"></div>
            <span className="text-sm font-medium text-red-600 dark:text-red-400">
              {activeAlerts.length} Active Alert{activeAlerts.length > 1 ? "s" : ""}
            </span>
          </div>
        )}
      </div>

      {error && (
        <div className="rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 text-sm px-4 py-3">
          {error}
        </div>
      )}
      {hotlineSchemaNote && (
        <div className="rounded-lg bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 text-yellow-800 dark:text-yellow-300 text-sm px-4 py-3">
          {hotlineSchemaNote}
        </div>
      )}

      {/* Flood / Emergency Alerts */}
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-6 border dark:border-gray-700">
        <h3 className="text-lg font-semibold text-gray-800 dark:text-white mb-4">
          Flood & Emergency Alerts
        </h3>

        <div className="space-y-3 mb-6">
          {alertsLoading && (
            <p className="text-sm text-gray-500 dark:text-gray-400">Loading alerts…</p>
          )}
          {!alertsLoading && floodAlerts.length === 0 && (
            <p className="text-sm text-gray-500 dark:text-gray-400">
              No alerts recorded yet in `flood_alerts`.
            </p>
          )}
          {floodAlerts.map((alert) => (
            <div
              key={alert.id}
              className="p-4 border dark:border-gray-700 rounded-lg flex flex-col md:flex-row md:items-center justify-between"
            >
              <div>
                <div className="flex items-center space-x-2">
                  <span
                    className={`px-3 py-1 rounded-full text-xs font-medium ${
                      levelColors[alert.level] || levelColors.Moderate
                    }`}
                  >
                    {alert.level}
                  </span>
                  {alert.is_active ? (
                    <span className="text-xs text-red-600 dark:text-red-400 font-medium">Active</span>
                  ) : (
                    <span className="text-xs text-gray-400">Resolved</span>
                  )}
                </div>
                <p className="text-gray-800 dark:text-white mt-2">
                  {Array.isArray(alert.affected_areas)
                    ? alert.affected_areas.join(", ")
                    : alert.affected_areas}
                </p>
                {alert.water_level && (
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    Water level: {alert.water_level}
                  </p>
                )}
                {alert.advice && (
                  <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">{alert.advice}</p>
                )}
                <p className="text-xs text-gray-400 mt-1">{formatDate(alert.created_at)}</p>
              </div>
              {alert.is_active && (
                <button
                  onClick={() => handleResolveAlert(alert.id)}
                  className="mt-3 md:mt-0 px-3 py-1 bg-green-600 hover:bg-green-700 text-white text-sm rounded-lg self-start"
                >
                  Mark Resolved
                </button>
              )}
            </div>
          ))}
        </div>

        <form onSubmit={handleAddAlert} className="space-y-3 pt-4 border-t dark:border-gray-700">
          <h4 className="font-medium text-gray-800 dark:text-white">Issue New Alert</h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <select
              value={newAlert.level}
              onChange={(e) => setNewAlert({ ...newAlert, level: e.target.value })}
              className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
            >
              <option value="Low">Low</option>
              <option value="Moderate">Moderate</option>
              <option value="High">High</option>
              <option value="Critical">Critical</option>
            </select>
            <input
              type="text"
              placeholder="Water level (e.g. Knee-deep)"
              value={newAlert.water_level}
              onChange={(e) => setNewAlert({ ...newAlert, water_level: e.target.value })}
              className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
            />
          </div>
          <input
            type="text"
            placeholder="Affected areas (comma-separated, e.g. Zone 2, Purok 3)"
            value={newAlert.affected_areas}
            onChange={(e) => setNewAlert({ ...newAlert, affected_areas: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
            required
          />
          <textarea
            placeholder="Advice for residents"
            value={newAlert.advice}
            onChange={(e) => setNewAlert({ ...newAlert, advice: e.target.value })}
            rows={2}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
          />
          <button
            type="submit"
            className="w-full bg-red-600 hover:bg-red-700 text-white font-semibold py-2 px-4 rounded-lg transition"
          >
            Publish Alert to Mobile App
          </button>
        </form>
      </div>

      {/* Hotline Directory */}
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-6 border dark:border-gray-700">
        <h3 className="text-lg font-semibold text-gray-800 dark:text-white mb-4">
          Emergency Hotline Directory
        </h3>
        <div className="space-y-3">
          {hotlinesLoading && (
            <p className="text-sm text-gray-500 dark:text-gray-400">Loading hotlines…</p>
          )}
          {!hotlinesLoading && hotlines.length === 0 && (
            <p className="text-sm text-gray-500 dark:text-gray-400">
              No hotlines saved yet. Add one below.
            </p>
          )}
          {hotlines.map((hotline) => (
            <div
              key={hotline.id}
              className="flex items-center justify-between p-3 border dark:border-gray-700 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700/50"
            >
              <div>
                <div className="font-medium text-gray-800 dark:text-white">
                  {hotline.name}
                </div>
                <div className="text-sm text-gray-600 dark:text-gray-400">
                  {hotline.type || hotline.category || ""}
                  {!hotline.is_active && (
                    <span className="ml-2 text-xs text-gray-400">(inactive)</span>
                  )}
                </div>
              </div>
              <div className="flex items-center space-x-3">
                <div className="text-xl font-bold text-red-600 dark:text-red-400">
                  {hotline.number || hotline.phone || ""}
                </div>
                <button
                  onClick={() => handleToggleHotline(hotline.id, hotline.is_active)}
                  className="text-xs px-2 py-1 border rounded-lg dark:border-gray-600 text-gray-600 dark:text-gray-300"
                >
                  {hotline.is_active ? "Deactivate" : "Activate"}
                </button>
                <button
                  onClick={() => handleDeleteHotline(hotline.id)}
                  className="text-xs px-2 py-1 border rounded-lg border-red-300 dark:border-red-700 text-red-600 dark:text-red-400"
                >
                  Delete
                </button>
              </div>
            </div>
          ))}
        </div>

        {/* Add Hotline Form */}
        <div className="mt-6 pt-4 border-t dark:border-gray-700">
          <h4 className="font-medium text-gray-800 dark:text-white mb-3">
            Add New Hotline Number
          </h4>
          <form onSubmit={handleAddHotline} className="space-y-3">
            <div className="grid grid-cols-2 gap-3">
              <input
                type="text"
                placeholder="Service Name"
                value={newHotline.name}
                onChange={(e) => setNewHotline({ ...newHotline, name: e.target.value })}
                className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
                required
              />
              <input
                type="tel"
                placeholder="Phone Number"
                value={newHotline.number}
                onChange={(e) =>
                  setNewHotline({
                    ...newHotline,
                    number: e.target.value.replace(/[^0-9+\-\s]/g, ""),
                  })
                }
                inputMode="numeric"
                pattern="[0-9+\-\s]*"
                className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
                required
              />
            </div>
            <select
              value={newHotline.type}
              onChange={(e) => setNewHotline({ ...newHotline, type: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
            >
              {hotlineTypes.map((t) => (
                <option key={t} value={t}>
                  {t}
                </option>
              ))}
            </select>
            <button
              type="submit"
              className="w-full bg-red-600 hover:bg-red-700 text-white font-semibold py-2 px-4 rounded-lg transition"
            >
              Add Hotline
            </button>
          </form>
        </div>
      </div>

      {/* Mobile Integration */}
      <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4">
        <div className="flex items-center">
          <div className="flex-shrink-0">
            <span className="text-2xl">📱</span>
          </div>
          <div className="ml-3">
            <h4 className="text-sm font-medium text-red-800 dark:text-red-300">
              Live Mobile Integration
            </h4>
            <p className="text-sm text-red-700 dark:text-red-400">
              This page reads and writes the same `hotlines` and `flood_alerts` tables the
              Milaud mobile app uses — alerts published here appear to residents without any
              extra sync step.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default EmergencyHotlinePage;
