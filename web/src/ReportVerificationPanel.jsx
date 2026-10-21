import { useState } from "react";

import { verificationLabel } from "./reportVerification";

export default function ReportVerificationPanel({ report, onReview, busy }) {
  const [note, setNote] = useState(report.verification_note || "");
  const [severity, setSeverity] = useState(report.severity || "");
  const [error, setError] = useState("");
  const review = async (decision) => {
    if (decision !== "verified" && !note.trim()) {
      setError("Enter a rejection reason or explain what information is needed."); return;
    }
    if (decision === "verified" && !["Low", "Medium", "High"].includes(severity)) {
      setError("Select the final severity before verifying."); return;
    }
    setError("");
    try { await onReview(report, decision, note.trim(), severity); }
    catch (err) { setError(err.message || "Review could not be saved."); }
  };
  const progressed = ["in_progress", "resolved", "closed"].includes(report.status);
  return (
    <section className="space-y-3 rounded-lg border border-purple-200 p-4 dark:border-purple-800">
      <h3 className="font-semibold">Admin verification: {verificationLabel(report)}</h3>
      <p className="text-sm text-gray-500">AI severity suggests urgency, not authenticity. Check the photo, location and description, and contact the reporter when needed.</p>
      {report.reviewed_at && <p className="text-xs text-gray-500">Last reviewed: {new Date(report.reviewed_at).toLocaleString()}</p>}
      <label className="block text-sm">Final severity
        <select value={severity} onChange={(e) => setSeverity(e.target.value)} disabled={busy}
          className="ml-3 rounded border p-2 dark:bg-gray-800">
          <option value="">Select severity</option>
          {["High", "Medium", "Low"].map((level) => <option key={level}>{level}</option>)}
        </select>
      </label>
      <label className="block text-sm">Review notes / reason (visible to the citizen)
        <textarea value={note} onChange={(e) => setNote(e.target.value)} disabled={busy} maxLength={2000}
          className="mt-1 w-full rounded border p-2 dark:bg-gray-800" rows={3}
          placeholder="Explain your decision. For more information, tell the citizen what to provide and how to contact your office." />
      </label>
      <div className="flex flex-wrap gap-2">
        <button type="button" disabled={busy} onClick={() => review("verified")} className="rounded bg-green-700 px-3 py-2 text-white disabled:opacity-50">{busy ? "Saving..." : "Verify and assign"}</button>
        <button type="button" disabled={busy || progressed} onClick={() => review("needs_information")} className="rounded bg-amber-600 px-3 py-2 text-white disabled:opacity-50">Request more information</button>
        <button type="button" disabled={busy || progressed} onClick={() => review("rejected")} className="rounded bg-red-700 px-3 py-2 text-white disabled:opacity-50">Reject report</button>
      </div>
      {progressed && <p className="text-xs text-gray-500">This report is already in progress or completed. It cannot be rejected here.</p>}
      {error && <p role="alert" className="text-sm text-red-600">{error}</p>}
    </section>
  );
}
