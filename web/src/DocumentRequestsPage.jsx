import { useState, useEffect, useCallback } from "react";
import { supabase } from "./supabaseClient";

// Status vocabulary matches DocumentService._statusMessage() in the mobile
// app exactly, so a status set here maps to the message residents see.
const STATUS_OPTIONS = ["pending", "processing", "ready", "completed", "rejected"];

const statusColors = {
  pending: "bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300",
  processing: "bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300",
  ready: "bg-purple-100 dark:bg-purple-900/30 text-purple-800 dark:text-purple-300",
  completed: "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300",
  rejected: "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300",
};

const statusLabel = (s) => (s || "pending").replace("_", " ");

// Mirrors DocumentService._statusMessage() in the mobile app.
const REQUEST_STATUS_MESSAGES = {
  pending: "Your request is awaiting review.",
  processing: "Your document is being processed.",
  ready: "Your document is ready for pickup.",
  completed: "Your document has been picked up.",
  rejected: "Your request was rejected. Please resubmit.",
};

// Same pattern as CitizenReportsPage — a status change here previously
// only ever touched `document_requests`, so the resident never heard
// about it unless they reopened the app and checked manually.
const notifyResidentOfRequestStatus = async (request, newStatus) => {
  if (!request?.user_id) return;
  try {
    const { error } = await supabase.from("notifications").insert({
      user_id: request.user_id,
      title: `Document Request Update: ${request.document_type || "Request"}`,
      message:
        REQUEST_STATUS_MESSAGES[newStatus] ||
        `Your request status changed to "${statusLabel(newStatus)}".`,
      type: "document",
      data: { request_id: request.id, status: newStatus },
    });
    if (error) console.error("Failed to notify resident of request status change:", error);
  } catch (err) {
    console.error("Failed to notify resident of request status change:", err);
  }
};

const DocumentRequestsPage = () => {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [filter, setFilter] = useState("all");

  const fetchRequests = useCallback(async () => {
    setLoading(true);
    setError("");

    let { data, error } = await supabase
      .from("document_requests")
      .select("*, profiles(name, email, phone)")
      .order("created_at", { ascending: false });

    if (error) {
      ({ data, error } = await supabase
        .from("document_requests")
        .select("*")
        .order("created_at", { ascending: false }));
    }

    if (error) {
      setError(error.message);
    } else {
      setRequests(data || []);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchRequests();
  }, [fetchRequests]);

  const handleStatusChange = async (id, newStatus) => {
    const request = requests.find((r) => r.id === id);
    setRequests((prev) => prev.map((r) => (r.id === id ? { ...r, status: newStatus } : r)));
    const { error } = await supabase
      .from("document_requests")
      .update({ status: newStatus })
      .eq("id", id);
    if (error) {
      setError(error.message);
      return;
    }
    if (request && request.status !== newStatus) {
      await notifyResidentOfRequestStatus(request, newStatus);
    }
  };

  const residentName = (req) => req.profiles?.name || "Resident";

  const filteredRequests = requests.filter((req) => {
    if (filter !== "all" && req.status !== filter) return false;
    return true;
  });

  const formatDate = (iso) => {
    if (!iso) return "—";
    return new Date(iso).toLocaleDateString("en-PH", {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-800 dark:text-white">
          Document Request Management
        </h1>
        <p className="text-gray-600 dark:text-gray-400">
          Process and track document requests submitted through the mobile app
        </p>
      </div>

      {error && (
        <div className="rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 text-sm px-4 py-3">
          {error}
        </div>
      )}

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white dark:bg-gray-800 rounded-xl p-4 border dark:border-gray-700">
          <div className="text-2xl font-bold text-blue-600 dark:text-blue-400">
            {requests.length}
          </div>
          <div className="text-sm text-gray-600 dark:text-gray-400">Total Requests</div>
        </div>
        <div className="bg-white dark:bg-gray-800 rounded-xl p-4 border dark:border-gray-700">
          <div className="text-2xl font-bold text-yellow-600 dark:text-yellow-400">
            {requests.filter((r) => r.status === "pending").length}
          </div>
          <div className="text-sm text-gray-600 dark:text-gray-400">Pending</div>
        </div>
        <div className="bg-white dark:bg-gray-800 rounded-xl p-4 border dark:border-gray-700">
          <div className="text-2xl font-bold text-purple-600 dark:text-purple-400">
            {requests.filter((r) => r.status === "ready").length}
          </div>
          <div className="text-sm text-gray-600 dark:text-gray-400">Ready for Pickup</div>
        </div>
        <div className="bg-white dark:bg-gray-800 rounded-xl p-4 border dark:border-gray-700">
          <div className="text-2xl font-bold text-green-600 dark:text-green-400">
            {requests.filter((r) => r.status === "completed").length}
          </div>
          <div className="text-sm text-gray-600 dark:text-gray-400">Completed</div>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-4 border dark:border-gray-700">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Filter by Status
            </label>
            <select
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white"
            >
              <option value="all">All Requests</option>
              {STATUS_OPTIONS.map((s) => (
                <option key={s} value={s}>
                  {statusLabel(s)}
                </option>
              ))}
            </select>
          </div>
          <div className="text-sm text-gray-600 dark:text-gray-400">
            Showing {filteredRequests.length} of {requests.length} requests
          </div>
        </div>
      </div>

      {/* Requests Table */}
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm overflow-hidden border dark:border-gray-700">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead className="bg-gray-50 dark:bg-gray-900">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Request Details
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Document Type
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Fee
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Submitted
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
              {loading && (
                <tr>
                  <td colSpan={6} className="px-6 py-8 text-center text-gray-500 dark:text-gray-400">
                    Loading requests…
                  </td>
                </tr>
              )}
              {!loading && filteredRequests.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-6 py-8 text-center text-gray-500 dark:text-gray-400">
                    No requests match this view.
                  </td>
                </tr>
              )}
              {filteredRequests.map((request) => (
                <tr key={request.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/50">
                  <td className="px-6 py-4">
                    <div>
                      <div className="font-medium text-gray-800 dark:text-white">
                        {residentName(request)}
                      </div>
                      <div className="text-sm text-gray-600 dark:text-gray-400">
                        {request.purpose}
                      </div>
                      <div className="text-xs text-blue-600 dark:text-blue-400 mt-1">
                        📱 Mobile Request
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 dark:bg-gray-900/30 text-gray-800 dark:text-gray-300">
                      {request.document_type}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <select
                      value={request.status || "pending"}
                      onChange={(e) => handleStatusChange(request.id, e.target.value)}
                      className={`text-xs font-medium px-2 py-1 rounded-full border-0 focus:ring-2 focus:ring-offset-1 ${
                        statusColors[request.status] || statusColors.pending
                      }`}
                    >
                      {STATUS_OPTIONS.map((s) => (
                        <option key={s} value={s}>
                          {statusLabel(s)}
                        </option>
                      ))}
                    </select>
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-600 dark:text-gray-400">
                    {request.fee || "—"}
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-600 dark:text-gray-400">
                    {formatDate(request.created_at)}
                  </td>
                  <td className="px-6 py-4 text-sm font-medium space-x-2">
                    <button
                      onClick={() => handleStatusChange(request.id, "ready")}
                      className="text-purple-600 dark:text-purple-400 hover:text-purple-900 dark:hover:text-purple-300"
                    >
                      Mark Ready
                    </button>
                    <button
                      onClick={() => handleStatusChange(request.id, "completed")}
                      className="text-green-600 dark:text-green-400 hover:text-green-900 dark:hover:text-green-300"
                    >
                      Complete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Mobile Integration */}
      <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
        <div className="flex items-center">
          <div className="flex-shrink-0">
            <span className="text-2xl">📱</span>
          </div>
          <div className="ml-3">
            <h4 className="text-sm font-medium text-blue-800 dark:text-blue-300">
              Mobile Document Requests
            </h4>
            <p className="text-sm text-blue-700 dark:text-blue-400">
              Residents submit document requests through the Maylaud mobile app and can track
              status live. Status updates made here read directly from the same
              `document_requests` table used by the app.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default DocumentRequestsPage;
