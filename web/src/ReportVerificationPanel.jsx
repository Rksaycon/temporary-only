import { useState } from "react";
import { verificationLabel } from "./reportVerification";
export default function ReportVerificationPanel({ report, onReview, busy }) {
 const [note, setNote] = useState(report.verification_note || "");
 const [severity, setSeverity] = useState(report.severity || "");
 const [error, setError] = useState("");
 const progressed = ["in_progress", "resolved", "closed"].includes(report.status);
 const review = async (decision) => {
   if (decision !== "verified" && !note.trim()) { setError("Enter a rejection reason or explain what information is needed."); return; }
   if (decision === "verified" && !["High","Medium","Low"].includes(severity)) { setError("Select the final severity first."); return; }
   setError("");
   try { await onReview(report, decision, note.trim(), severity); }
   catch (err) { setError(err.message || "Could not save review."); }
 };
 return <section className="space-y-3 rounded-lg border border-purple-200 p-4 dark:border-purple-800">
   <h3 className="font-semibold">Admin verification: {verificationLabel(report)}</h3>
   <p className="text-sm text-gray-500">AI suggests urgency, not authenticity. Check the photo, description and location, and contact the reporter when necessary.</p>
   {report.reviewed_at && <p className="text-xs">Last reviewed: {new Date(report.reviewed_at).toLocaleString()}</p>}
   <label className="block text-sm">Final severity
     <select value={severity} onChange={(e)=>setSeverity(e.target.value)} disabled={busy} className="ml-3 rounded border p-2 dark:bg-gray-800">
       <option value="">Select severity</option>{["High","Medium","Low"].map(level=><option key={level}>{level}</option>)}
     </select>
   </label>
   <label className="block text-sm">Review notes / reason (visible to the citizen)
     <textarea value={note} onChange={(e)=>setNote(e.target.value)} disabled={busy} maxLength={2000} rows={3}
       className="mt-1 w-full rounded border p-2 dark:bg-gray-800"
       placeholder="Explain the decision. For clarification, include what is needed and how the citizen can contact your office." />
   </label>
   <div className="flex flex-wrap gap-2">
     <button type="button" disabled={busy} onClick={()=>review("verified")} className="rounded bg-green-700 px-3 py-2 text-white disabled:opacity-50">{busy ? "Saving..." : "Verify and assign"}</button>
     <button type="button" disabled={busy || progressed} onClick={()=>review("needs_information")} className="rounded bg-amber-600 px-3 py-2 text-white disabled:opacity-50">Request more information</button>
     <button type="button" disabled={busy || progressed} onClick={()=>review("rejected")} className="rounded bg-red-700 px-3 py-2 text-white disabled:opacity-50">Reject report</button>
   </div>
   {progressed && <p className="text-xs text-gray-500">This report is already being handled or completed; rejection is unavailable.</p>}
   {error && <p role="alert" className="text-sm text-red-600">{error}</p>}
 </section>;
}
