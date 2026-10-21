import { useState, useEffect, useCallback } from "react";
import { supabase } from "./supabaseClient";

const categories = ["General", "Emergency", "Community", "Health", "Infrastructure", "Education", "Event"];

const emptyForm = {
  title: "",
  description: "",
  category: "General",
  image_url: "",
  is_important: false,
};

const AnnouncementsPage = () => {
  const [announcements, setAnnouncements] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [formData, setFormData] = useState(emptyForm);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [saving, setSaving] = useState(false);

  const [viewing, setViewing] = useState(null); // full detail modal
  const [imgError, setImgError] = useState(false);

  const fetchAnnouncements = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const { data, error } = await supabase
        .from("announcements")
        .select("*")
        .order("created_at", { ascending: false });

      if (error) {
        setError(error.message);
      } else {
        setAnnouncements(data || []);
      }
    } catch (err) {
      setError(err.message || "Could not reach Supabase. Check your connection and configuration.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchAnnouncements();
  }, [fetchAnnouncements]);

  const handleInputChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: type === "checkbox" ? checked : value,
    }));
  };

  const openNewForm = () => {
    setFormData(emptyForm);
    setEditingId(null);
    setShowForm(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError("");

    const payload = {
      title: formData.title,
      description: formData.description,
      category: formData.category,
      image_url: formData.image_url || null,
      is_important: formData.is_important,
    };

    try {
      const { error } = editingId
        ? await supabase.from("announcements").update(payload).eq("id", editingId)
        : await supabase.from("announcements").insert(payload);

      if (error) {
        setError(error.message);
      } else {
        await fetchAnnouncements();
        setFormData(emptyForm);
        setEditingId(null);
        setShowForm(false);
      }
    } catch (err) {
      // Catches network failures, misconfigured client, etc. — anything
      // that wouldn't come back as a normal Supabase {error} response, so
      // a failure never just silently does nothing.
      setError(
        err.message ||
          "Something went wrong publishing this announcement. Check your connection and Supabase configuration."
      );
    } finally {
      setSaving(false);
    }
  };

  const handleEdit = (announcement) => {
    setFormData({
      title: announcement.title || "",
      description: announcement.description || "",
      category: announcement.category || "General",
      image_url: announcement.image_url || "",
      is_important: !!announcement.is_important,
    });
    setEditingId(announcement.id);
    setShowForm(true);
    setViewing(null);
  };

  const handleDelete = async (id) => {
    if (!window.confirm("Are you sure you want to delete this announcement?")) return;
    const { error } = await supabase.from("announcements").delete().eq("id", id);
    if (error) {
      setError(error.message);
    } else {
      setAnnouncements((prev) => prev.filter((a) => a.id !== id));
      if (viewing?.id === id) setViewing(null);
    }
  };

  const formatDate = (iso) => {
    if (!iso) return "—";
    return new Date(iso).toLocaleDateString("en-PH", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  const openView = (announcement) => {
    setImgError(false);
    setViewing(announcement);
  };

  // Lazy useState initializer runs exactly once (on mount), not on every
  // render, so calling Date.now() here doesn't violate the "components must
  // be pure" rule the way calling it directly during render would.
  const [oneWeekAgo] = useState(() => Date.now() - 7 * 24 * 60 * 60 * 1000);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-gray-800 dark:text-white">
            Announcement Management
          </h1>
          <p className="text-gray-600 dark:text-gray-400">
            Create and manage announcements for residents — synced live to the Maylaud mobile app
          </p>
        </div>
        <button
          onClick={openNewForm}
          className="bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded-lg transition"
        >
          + New Announcement
        </button>
      </div>

      {error && (
        <div className="rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 text-sm px-4 py-3">
          {error}
        </div>
      )}

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-white dark:bg-gray-800 rounded-xl p-4 border dark:border-gray-700">
          <div className="text-2xl font-bold text-blue-600 dark:text-blue-400">
            {announcements.length}
          </div>
          <div className="text-sm text-gray-600 dark:text-gray-400">Total Announcements</div>
        </div>
        <div className="bg-white dark:bg-gray-800 rounded-xl p-4 border dark:border-gray-700">
          <div className="text-2xl font-bold text-red-600 dark:text-red-400">
            {announcements.filter((a) => a.is_important).length}
          </div>
          <div className="text-sm text-gray-600 dark:text-gray-400">Marked Important</div>
        </div>
        <div className="bg-white dark:bg-gray-800 rounded-xl p-4 border dark:border-gray-700">
          <div className="text-2xl font-bold text-purple-600 dark:text-purple-400">
            {announcements.filter((a) => new Date(a.created_at).getTime() >= oneWeekAgo).length}
          </div>
          <div className="text-sm text-gray-600 dark:text-gray-400">Posted This Week</div>
        </div>
      </div>

      {/* Create/Edit Form */}
      {showForm && (
        <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-6 border dark:border-gray-700">
          <h3 className="text-lg font-semibold text-gray-800 dark:text-white mb-4">
            {editingId ? "Edit Announcement" : "Create New Announcement"}
          </h3>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Title
              </label>
              <input
                type="text"
                name="title"
                value={formData.title}
                onChange={handleInputChange}
                className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
                placeholder="Enter announcement title"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Description
              </label>
              <textarea
                name="description"
                value={formData.description}
                onChange={handleInputChange}
                rows="5"
                className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
                placeholder="Enter the full announcement text residents will see"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Image URL <span className="text-gray-400 font-normal">(optional)</span>
              </label>
              <input
                type="url"
                name="image_url"
                value={formData.image_url}
                onChange={handleInputChange}
                className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
                placeholder="https://..."
              />
              {formData.image_url && (
                <img
                  src={formData.image_url}
                  alt="Preview"
                  className="mt-2 h-32 w-full max-w-xs object-cover rounded-lg border dark:border-gray-700"
                  onError={(e) => (e.target.style.display = "none")}
                  onLoad={(e) => (e.target.style.display = "block")}
                />
              )}
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Category
                </label>
                <select
                  name="category"
                  value={formData.category}
                  onChange={handleInputChange}
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
                >
                  {categories.map((cat) => (
                    <option key={cat} value={cat}>
                      {cat}
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex items-center">
                <input
                  type="checkbox"
                  id="is_important"
                  name="is_important"
                  checked={formData.is_important}
                  onChange={handleInputChange}
                  className="h-4 w-4 text-blue-600 rounded"
                />
                <label htmlFor="is_important" className="ml-2 text-sm text-gray-700 dark:text-gray-300">
                  Mark as important (highlighted for residents)
                </label>
              </div>
            </div>

            <div className="flex justify-end space-x-3">
              <button
                type="button"
                onClick={() => setShowForm(false)}
                className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={saving}
                className="bg-blue-600 hover:bg-blue-700 disabled:opacity-60 text-white font-semibold py-2 px-4 rounded-lg transition"
              >
                {saving ? "Saving…" : editingId ? "Update Announcement" : "Publish Announcement"}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Announcements Table */}
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm overflow-hidden border dark:border-gray-700">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead className="bg-gray-50 dark:bg-gray-900">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Announcement
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Category
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Important
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Date
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
              {loading && (
                <tr>
                  <td colSpan={5} className="px-6 py-8 text-center text-gray-500 dark:text-gray-400">
                    Loading announcements…
                  </td>
                </tr>
              )}
              {!loading && announcements.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-6 py-8 text-center text-gray-500 dark:text-gray-400">
                    No announcements yet. Create the first one above.
                  </td>
                </tr>
              )}
              {announcements.map((announcement) => (
                <tr
                  key={announcement.id}
                  className="hover:bg-gray-50 dark:hover:bg-gray-700/50 cursor-pointer"
                  onClick={() => openView(announcement)}
                >
                  <td className="px-6 py-4">
                    <div className="flex items-start gap-3">
                      {announcement.image_url && (
                        <img
                          src={announcement.image_url}
                          alt=""
                          className="w-12 h-12 rounded-lg object-cover flex-shrink-0 border dark:border-gray-700"
                          onError={(e) => (e.target.style.display = "none")}
                        />
                      )}
                      <div>
                        <div className="font-medium text-gray-800 dark:text-white">
                          {announcement.title}
                        </div>
                        <div className="text-sm text-gray-600 dark:text-gray-400 line-clamp-2 max-w-md">
                          {announcement.description}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300">
                      {announcement.category}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    {announcement.is_important ? (
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300">
                        Important
                      </span>
                    ) : (
                      <span className="text-gray-400 text-xs">Normal</span>
                    )}
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-600 dark:text-gray-400">
                    {formatDate(announcement.created_at)}
                  </td>
                  <td className="px-6 py-4 text-sm font-medium space-x-2">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        openView(announcement);
                      }}
                      className="text-gray-600 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white"
                    >
                      View
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleEdit(announcement);
                      }}
                      className="text-blue-600 dark:text-blue-400 hover:text-blue-900 dark:hover:text-blue-300"
                    >
                      Edit
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleDelete(announcement.id);
                      }}
                      className="text-red-600 dark:text-red-400 hover:text-red-900 dark:hover:text-red-300"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Full Detail View Modal */}
      {viewing && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => setViewing(null)}
        >
          <div
            className="bg-white dark:bg-gray-800 rounded-xl shadow-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            {viewing.image_url && !imgError && (
              <img
                src={viewing.image_url}
                alt={viewing.title}
                className="w-full h-56 object-cover rounded-t-xl"
                onError={() => setImgError(true)}
              />
            )}
            <div className="p-6">
              <div className="flex justify-between items-start mb-4">
                <div>
                  <div className="flex items-center gap-2 mb-2">
                    <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300">
                      {viewing.category}
                    </span>
                    {viewing.is_important && (
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300">
                        Important
                      </span>
                    )}
                  </div>
                  <h3 className="text-xl font-bold text-gray-800 dark:text-white">
                    {viewing.title}
                  </h3>
                  <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
                    {formatDate(viewing.created_at)}
                  </p>
                </div>
                <button
                  onClick={() => setViewing(null)}
                  className="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300"
                >
                  ✕
                </button>
              </div>

              <div className="whitespace-pre-wrap text-gray-800 dark:text-gray-200 bg-gray-50 dark:bg-gray-900/50 p-4 rounded-lg">
                {viewing.description}
              </div>

              <div className="flex justify-end space-x-3 pt-6 mt-2 border-t dark:border-gray-700">
                <button
                  onClick={() => setViewing(null)}
                  className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-300"
                >
                  Close
                </button>
                <button
                  onClick={() => handleEdit(viewing)}
                  className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg"
                >
                  Edit
                </button>
                <button
                  onClick={() => handleDelete(viewing.id)}
                  className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Mobile Sync Info */}
      <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
        <div className="flex items-center">
          <div className="flex-shrink-0">
            <span className="text-2xl">📱</span>
          </div>
          <div className="ml-3">
            <h4 className="text-sm font-medium text-blue-800 dark:text-blue-300">
              Live Mobile Sync
            </h4>
            <p className="text-sm text-blue-700 dark:text-blue-400">
              This page reads and writes the same `announcements` table the Maylaud mobile app
              uses, so anything published here (including images) appears for residents
              immediately.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AnnouncementsPage;
