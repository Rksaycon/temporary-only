import { useState, useEffect, useCallback } from "react";
import { supabase } from "./supabaseClient";

const STATUS_OPTIONS = ["pending", "processing", "ready", "completed", "rejected"];

const statusColors = {
  pending: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-200",
  processing: "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-200",
  ready: "bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-200",
  completed: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-200",
  rejected: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-200",
};

const statusLabel = (status) => ({
  pending: "Pending review",
  processing: "Processing",
  ready: "Ready for pickup",
  completed: "Completed",
  rejected: "Rejected",
})[status || "pending"] || String(status || "pending").replaceAll("_", " ");

// Mirrors the catalogue currently shown by the mobile request form. These
// descriptions and prices are prototypes, not an approved barangay list.
const DOCUMENT_CATALOG = {
  "Business Permit": {
    description: "Official permit to operate a business within the municipality",
    fee: 500,
    mobileAvailable: true,
  },
  "Civil Registry Documents": {
    description: "Birth, death, and marriage certificates from the civil registry",
    fee: 200,
    mobileAvailable: true,
  },
  "Tax Declaration": {
    description: "Official tax declaration document for property assessment",
    fee: 150,
    mobileAvailable: false,
  },
  "Certificate of Residency": {
    description: "Proof of residency within the municipality",
    fee: 75,
    mobileAvailable: false,
  },
  "Police Clearance": {
    description: "Police clearance certificate for employment or travel purposes",
    fee: 150,
    mobileAvailable: false,
  },
  "Community Tax Certificate (Cedula)": {
    description: "Community tax certificate required for various transactions",
    fee: 50,
    mobileAvailable: false,
  },
  "Zoning Clearance": {
    description: "Clearance certifying property zoning compliance",
    fee: 300,
    mobileAvailable: false,
  },
  "Fire Safety Inspection Certificate": {
    description: "Certificate of compliance with fire safety standards",
    fee: 250,
    mobileAvailable: false,
  },
  "Sanitary Permit": {
    description: "Permit certifying compliance with health and sanitation standards",
    fee: 200,
    mobileAvailable: false,
  },
};

const requestReference = (request) => {
  const compact = String(request?.id || "").replaceAll("-", "");
  return `MLR-${compact.slice(0, 8).toUpperCase()}`;
};

const attachmentName = (url, index) => {
  try {
    const pathname = new URL(url).pathname;
    return decodeURIComponent(pathname.split("/").pop() || `Attachment ${index + 1}`);
  } catch {
    return `Attachment ${index + 1}`;
  }
};

const DocumentRequestsPage = () => {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [filter, setFilter] = useState("all");
  const [selectedRequest, setSelectedRequest] = useState(null);

  const fetchRequests = useCallback(async () => {
    setLoading(true);
    setError("");

    let { data, error: requestError } = await supabase
      .from("document_requests")
      .select("*, profiles(name, email, phone)")
      .order("created_at", { ascending: false });

    if (requestError) {
      ({ data, error: requestError } = await supabase
        .from("document_requests")
        .select("*")
        .order("created_at", { ascending: false }));
    }

    if (requestError) setError(requestError.message);
    else setRequests(data || []);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchRequests();
  }, [fetchRequests]);

  const residentName = (request) =>
    request.full_name?.trim() ||
    request.profiles?.name?.trim() ||
    "Name not provided";

  const formatDate = (value, includeTime = false) => {
    if (!value) return "Not available";
    return new Date(value).toLocaleString("en-PH", includeTime
      ? { month: "short", day: "numeric", year: "numeric", hour: "numeric", minute: "2-digit" }
      : { month: "short", day: "numeric", year: "numeric" });
  };

  const filteredRequests = requests.filter(
    (request) => filter === "all" || request.status === filter,
  );

  const selectedMeta = selectedRequest
    ? DOCUMENT_CATALOG[selectedRequest.document_type]
    : null;
  const selectedAttachments = Array.isArray(selectedRequest?.attachment_urls)
    ? selectedRequest.attachment_urls.filter(Boolean)
    : [];
  const displayedFee = selectedRequest?.fee || selectedMeta?.fee;

  return (
    <div className="mx-auto max-w-7xl space-y-5 text-[15px]">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Document Requests</h1>
        <p className="mt-1 text-sm text-gray-600 dark:text-gray-300">
          Read submitted request details. Processing actions remain disabled until the barangay confirms its official requirements and workflow.
        </p>
      </div>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700 dark:border-red-800 dark:bg-red-900/20 dark:text-red-300">
          {error}
        </div>
      )}

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {[
          ["Total", requests.length, "text-blue-700 dark:text-blue-300"],
          ["Pending", requests.filter((request) => request.status === "pending").length, "text-amber-700 dark:text-amber-300"],
          ["Ready", requests.filter((request) => request.status === "ready").length, "text-purple-700 dark:text-purple-300"],
          ["Completed", requests.filter((request) => request.status === "completed").length, "text-green-700 dark:text-green-300"],
        ].map(([label, value, tone]) => (
          <div key={label} className="rounded-lg border bg-white p-3 dark:border-gray-700 dark:bg-gray-800">
            <p className={`text-xl font-bold ${tone}`}>{value}</p>
            <p className="text-xs font-medium text-gray-500 dark:text-gray-400">{label}</p>
          </div>
        ))}
      </div>

      <div className="flex flex-col gap-3 rounded-lg border bg-white p-3 sm:flex-row sm:items-end sm:justify-between dark:border-gray-700 dark:bg-gray-800">
        <label className="text-sm font-semibold text-gray-700 dark:text-gray-200">
          Status
          <select
            value={filter}
            onChange={(event) => setFilter(event.target.value)}
            className="mt-1 block min-h-10 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm dark:border-gray-600 dark:bg-gray-700"
          >
            <option value="all">All requests</option>
            {STATUS_OPTIONS.map((status) => (
              <option key={status} value={status}>{statusLabel(status)}</option>
            ))}
          </select>
        </label>
        <p className="text-sm text-gray-500 dark:text-gray-400">
          Showing {filteredRequests.length} of {requests.length}
        </p>
      </div>

      <div className="overflow-hidden rounded-lg border bg-white dark:border-gray-700 dark:bg-gray-800">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead className="bg-gray-50 dark:bg-gray-900">
              <tr>
                {["Requester", "Requested document", "Purpose", "Status", "Submitted", "Details"].map((heading) => (
                  <th key={heading} className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400">
                    {heading}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
              {loading && (
                <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-500">Loading requests…</td></tr>
              )}
              {!loading && filteredRequests.length === 0 && (
                <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-500">No requests match this view.</td></tr>
              )}
              {filteredRequests.map((request) => (
                <tr key={request.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/50">
                  <td className="px-4 py-3">
                    <p className="font-semibold text-gray-900 dark:text-white">{residentName(request)}</p>
                    <p className="text-xs text-gray-500">{requestReference(request)}</p>
                  </td>
                  <td className="px-4 py-3 text-sm font-medium text-gray-800 dark:text-gray-100">
                    {request.document_type || "Not provided"}
                  </td>
                  <td className="max-w-xs px-4 py-3 text-sm text-gray-600 dark:text-gray-300">
                    <p className="line-clamp-2">{request.purpose || "Not provided"}</p>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`inline-flex rounded-full px-2.5 py-1 text-xs font-semibold ${statusColors[request.status] || statusColors.pending}`}>
                      {statusLabel(request.status)}
                    </span>
                  </td>
                  <td className="whitespace-nowrap px-4 py-3 text-sm text-gray-600 dark:text-gray-300">
                    {formatDate(request.created_at)}
                  </td>
                  <td className="px-4 py-3">
                    <button
                      type="button"
                      onClick={() => setSelectedRequest(request)}
                      className="min-h-9 rounded-md border border-purple-300 px-3 py-1.5 text-sm font-semibold text-purple-700 hover:bg-purple-50 dark:border-purple-700 dark:text-purple-200 dark:hover:bg-purple-900/20"
                    >
                      View details
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {selectedRequest && (
        <div className="fixed inset-0 z-50 flex justify-end bg-black/50" onMouseDown={() => setSelectedRequest(null)}>
          <aside
            className="h-full w-full max-w-2xl overflow-y-auto bg-white shadow-2xl dark:bg-gray-800"
            onMouseDown={(event) => event.stopPropagation()}
          >
            <div className="p-4 sm:p-5">
              <div className="flex items-start justify-between gap-3 border-b pb-4 dark:border-gray-700">
                <div>
                  <p className="text-xs font-bold uppercase tracking-wide text-purple-700 dark:text-purple-300">{requestReference(selectedRequest)}</p>
                  <h2 className="mt-1 text-xl font-bold text-gray-900 dark:text-white">Request details</h2>
                  <p className="mt-1 text-sm text-gray-500">Submitted {formatDate(selectedRequest.created_at, true)}</p>
                </div>
                <button
                  type="button"
                  aria-label="Close request details"
                  onClick={() => setSelectedRequest(null)}
                  className="flex h-10 w-10 items-center justify-center rounded-lg border text-xl dark:border-gray-600"
                >
                  ×
                </button>
              </div>

              <div className="mt-4 space-y-4">
                <section className="rounded-xl border border-purple-200 bg-purple-50 p-4 dark:border-purple-900 dark:bg-purple-950/20">
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <div>
                      <p className="text-xs font-bold uppercase tracking-wide text-purple-700 dark:text-purple-300">Requested document</p>
                      <h3 className="mt-1 text-lg font-bold text-gray-900 dark:text-white">{selectedRequest.document_type || "Not provided"}</h3>
                    </div>
                    <span className={`rounded-full px-2.5 py-1 text-xs font-bold ${statusColors[selectedRequest.status] || statusColors.pending}`}>
                      {statusLabel(selectedRequest.status)}
                    </span>
                  </div>
                  <p className="mt-2 text-sm text-gray-700 dark:text-gray-200">
                    {selectedMeta?.description || "No catalogue description is available for this document type."}
                  </p>
                </section>

                <section className="rounded-xl border p-4 dark:border-gray-700">
                  <h3 className="font-bold text-gray-900 dark:text-white">What the resident submitted</h3>
                  <dl className="mt-3 grid gap-3 text-sm sm:grid-cols-2">
                    <div><dt className="font-semibold text-gray-500">Full name</dt><dd className="mt-1 text-gray-900 dark:text-white">{residentName(selectedRequest)}</dd></div>
                    <div><dt className="font-semibold text-gray-500">Complete address</dt><dd className="mt-1 text-gray-900 dark:text-white">{selectedRequest.address || "Not provided"}</dd></div>
                    <div><dt className="font-semibold text-gray-500">Account email</dt><dd className="mt-1 break-words text-gray-900 dark:text-white">{selectedRequest.profiles?.email || "Not available"}</dd></div>
                    <div><dt className="font-semibold text-gray-500">Account phone</dt><dd className="mt-1 text-gray-900 dark:text-white">{selectedRequest.profiles?.phone || "Not available"}</dd></div>
                    <div className="sm:col-span-2"><dt className="font-semibold text-gray-500">Purpose of request</dt><dd className="mt-1 whitespace-pre-wrap text-gray-900 dark:text-white">{selectedRequest.purpose || "Not provided"}</dd></div>
                    <div><dt className="font-semibold text-gray-500">Requested urgency</dt><dd className="mt-1 text-gray-900 dark:text-white">{selectedRequest.urgency || selectedRequest.notes || "Not provided"}</dd></div>
                    <div><dt className="font-semibold text-gray-500">Mobile fee estimate</dt><dd className="mt-1 text-gray-900 dark:text-white">{displayedFee ? `₱${String(displayedFee).replace(/^₱/, "")}` : "Not provided"}</dd></div>
                    <div className="sm:col-span-2"><dt className="font-semibold text-gray-500">Additional notes</dt><dd className="mt-1 whitespace-pre-wrap text-gray-900 dark:text-white">{selectedRequest.additional_notes || "None provided"}</dd></div>
                  </dl>
                </section>

                <section className="rounded-xl border p-4 dark:border-gray-700">
                  <h3 className="font-bold text-gray-900 dark:text-white">Supporting attachments</h3>
                  {selectedAttachments.length === 0 ? (
                    <p className="mt-2 text-sm text-gray-500">No attachments were submitted.</p>
                  ) : (
                    <div className="mt-3 grid gap-2 sm:grid-cols-2">
                      {selectedAttachments.map((url, index) => (
                        <div key={`${url}-${index}`} className="rounded-lg border bg-gray-50 px-3 py-2 dark:border-gray-700 dark:bg-gray-900/40">
                          <p className="truncate text-sm font-semibold text-gray-800 dark:text-gray-100">{attachmentName(url, index)}</p>
                          <p className="mt-0.5 text-xs text-gray-500">Submitted file {index + 1} · preview disabled</p>
                        </div>
                      ))}
                    </div>
                  )}
                </section>

                <section className="rounded-xl border border-amber-300 bg-amber-50 p-4 dark:border-amber-800 dark:bg-amber-950/20">
                  <h3 className="font-bold text-amber-900 dark:text-amber-100">Official processing is not enabled</h3>
                  <p className="mt-1 text-sm text-amber-800 dark:text-amber-200">
                    Required documents, official fees, processing time, approval authority, and release procedure must be confirmed with the barangay. Values copied from the mobile prototype must not be treated as official.
                  </p>
                  <div className="mt-3 grid gap-2 sm:grid-cols-3">
                    {["Verify requirements", "Start processing", "Mark ready"].map((label) => (
                      <button key={label} type="button" disabled className="min-h-10 cursor-not-allowed rounded-lg border border-amber-300 bg-white px-3 py-2 text-sm font-semibold text-gray-400 opacity-70 dark:border-amber-800 dark:bg-gray-800">
                        {label}
                      </button>
                    ))}
                  </div>
                </section>

                <section className="rounded-xl border p-4 text-sm dark:border-gray-700">
                  <h3 className="font-bold text-gray-900 dark:text-white">Record information</h3>
                  <div className="mt-2 grid gap-2 sm:grid-cols-2">
                    <p><strong>Submitted:</strong> {formatDate(selectedRequest.created_at, true)}</p>
                    <p><strong>Last updated:</strong> {formatDate(selectedRequest.updated_at, true)}</p>
                  </div>
                </section>
              </div>
            </div>
          </aside>
        </div>
      )}
    </div>
  );
};

export default DocumentRequestsPage;
