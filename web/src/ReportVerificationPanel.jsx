import { useState } from "react";
import { verificationLabel } from "./reportVerification";
import {
  AI_ASSESSMENT_OUTCOMES,
  REPORT_CATEGORIES,
  aiAssessmentOutcome,
  aiCategoryOf,
  isAiClassificationApplicable,
  isCommunityConcern,
  reportedCategoryOf,
  verifiedCategoryOf,
} from "./reportClassification";
import { BARANGAY_RESPONSE_TEAM } from "./reportRouting";

export default function ReportVerificationPanel({ report, onReview, onMessage, busy }) {
  const citizenCategory = reportedCategoryOf(report);
  const aiCategory = aiCategoryOf(report);
  const aiApplicable = isAiClassificationApplicable(report);
  const communityConcern = isCommunityConcern(report);
  const outcome = aiAssessmentOutcome(report);
  const corroborated = outcome === AI_ASSESSMENT_OUTCOMES.CORROBORATED;
  const [severity, setSeverity] = useState(
    report.severity || report.ai_suggested_severity || "",
  );
  const [category, setCategory] = useState(
    verifiedCategoryOf(report) || citizenCategory || "",
  );
  const department = BARANGAY_RESPONSE_TEAM;
  const [error, setError] = useState("");
  const [manualCorrection, setManualCorrection] = useState(false);
  const [citizenMessage, setCitizenMessage] = useState("");
  const [messageStatus, setMessageStatus] = useState("");
  const [messageAlreadySent, setMessageAlreadySent] = useState(
    Boolean(report.citizen_message_sent_at || report.citizen_message),
  );
  const [decisionPrompt, setDecisionPrompt] = useState("");
  const [decisionReason, setDecisionReason] = useState("");
  const quickConfirm = corroborated && !manualCorrection;
  const progressed = ["in_progress", "resolved", "closed"].includes(
    report.status,
  );
  const informationAlreadyRequested = report.verification_status === "needs_information";
  const reportRejected = report.verification_status === "rejected";

  const outcomeView = {
    [AI_ASSESSMENT_OUTCOMES.CORROBORATED]: {
      icon: "✓",
      label: `ML supports ${aiCategory || citizenCategory}`,
      description: `The photo appears to show ${citizenCategory}. Check the report details before starting barangay action.`,
      border: "border-green-300 dark:border-green-800",
      banner: "border-green-200 bg-green-50 text-green-800 dark:border-green-800 dark:bg-green-900/20 dark:text-green-300",
    },
    [AI_ASSESSMENT_OUTCOMES.MISMATCH]: {
      icon: "!",
      label: `ML suggests ${aiCategory || "a different category"}`,
      description: `The report says ${citizenCategory}, but the photo check found possible ${aiCategory}. Check the photo before continuing.`,
      border: "border-amber-300 dark:border-amber-800",
      banner: "border-amber-200 bg-amber-50 text-amber-800 dark:border-amber-800 dark:bg-amber-900/20 dark:text-amber-300",
    },
    [AI_ASSESSMENT_OUTCOMES.LEARNING_MODE]: {
      icon: "i",
      label: aiCategory
        ? `ML suggests ${aiCategory} - check manually`
        : "ML result needs manual review",
      description: `The system does not have enough training data for ${citizenCategory}. Please check the report manually.`,
      border: "border-violet-300 dark:border-violet-800",
      banner: "border-violet-200 bg-violet-50 text-violet-800 dark:border-violet-800 dark:bg-violet-900/20 dark:text-violet-300",
    },
    [AI_ASSESSMENT_OUTCOMES.MANUAL_REVIEW]: {
      icon: "?",
      label: aiCategory
        ? aiCategory === citizenCategory
          ? `AI photo result matches the report: ${aiCategory}`
          : `AI photo result suggests: ${aiCategory}`
        : "AI photo result unavailable · manual review",
      description: aiCategory
        ? `${aiCategory === citizenCategory ? "The image model predicted the same category selected by the citizen." : `The image model predicted ${aiCategory}, which differs from the citizen's selection.`} This is an AI prediction, not proof that the incident is real. Review the evidence and confirm the official classification.`
        : "The system did not provide a usable category result. Review the photo and report manually.",
      border: "border-red-300 dark:border-red-800",
      banner: "border-red-200 bg-red-50 text-red-800 dark:border-red-800 dark:bg-red-900/20 dark:text-red-300",
    },
    [AI_ASSESSMENT_OUTCOMES.NOT_APPLICABLE]: {
      icon: "i",
      label: "Barangay staff review",
      description: `${citizenCategory || "This category"} is a community concern. Check the report details and set its priority manually.`,
      border: "border-blue-300 dark:border-blue-800",
      banner: "border-blue-200 bg-blue-50 text-blue-800 dark:border-blue-800 dark:bg-blue-900/20 dark:text-blue-300",
    },
  }[outcome];

  const review = async (decision, reason = "") => {
    if (decision !== "verified" && !reason.trim()) {
      setError(
        "Enter a rejection reason or explain what information is needed.",
      );
      return false;
    }
    if (
      decision === "verified" &&
      !["High", "Medium", "Low"].includes(severity)
    ) {
      setError("Select the final severity first.");
      return false;
    }
    if (decision === "verified" && !category) {
      setError("Select the final classification first.");
      return false;
    }
    setError("");
    try {
      await onReview(
        report,
        decision,
        reason.trim(),
        severity,
        category,
        department,
      );
      return true;
    } catch (err) {
      setError(err.message || "Could not save review.");
      return false;
    }
  };

  const openDecisionPrompt = (decision) => {
    setDecisionPrompt(decision);
    setDecisionReason("");
    setError("");
  };

  const submitDecisionPrompt = async () => {
    const saved = await review(decisionPrompt, decisionReason);
    if (saved) {
      setDecisionPrompt("");
      setDecisionReason("");
    }
  };

  const sendCitizenMessage = async () => {
    const message = citizenMessage.trim();
    if (!message) {
      setMessageStatus("Enter a message first.");
      return;
    }
    setMessageStatus("");
    try {
      await onMessage(report, message);
      setCitizenMessage("");
      setMessageAlreadySent(true);
      setMessageStatus("Message sent. This report cannot receive another general message.");
    } catch (err) {
      setMessageStatus(err.message || "Could not send the message.");
    }
  };

  return (
    <section className={`space-y-4 rounded-xl border p-4 ${outcomeView.border}`}>
      <div>
        <h3 className="text-lg font-bold">
          {communityConcern ? "Review community report" : "Review this report"}
        </h3>
        <p className="mt-1 text-sm text-gray-600 dark:text-gray-300">
          Current status: <strong>{verificationLabel(report)}</strong>.{" "}
          {quickConfirm
            ? "The photo supports the report. Check the details and confirm."
            : "Check the report, choose the correct details, and save your decision."}
        </p>
      </div>

      <div className={`rounded-lg border px-3 py-3 ${outcomeView.banner}`}>
        <div className="flex items-start gap-3">
          <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-current font-bold" aria-hidden="true">
            {outcomeView.icon}
          </span>
          <div>
            <p className="font-bold">{outcomeView.label}</p>
            <p className="mt-0.5 text-sm">{outcomeView.description}</p>
          </div>
        </div>
      </div>

      {!communityConcern && (
      <details className="rounded-lg border border-gray-300 bg-gray-50 dark:border-gray-700 dark:bg-gray-900/40">
        <summary className="cursor-pointer px-3 py-2.5 font-semibold text-gray-800 dark:text-gray-100">Show photo-check details</summary>
        <div className="grid gap-3 border-t p-3 text-sm sm:grid-cols-2 dark:border-gray-700">
          <div>
            <p className="font-bold text-gray-700 dark:text-gray-200">Reported category</p>
            <p className="mt-1">{citizenCategory || "Not provided"}</p>
          </div>
          <div>
            <p className="font-bold text-gray-700 dark:text-gray-200">AI photo check</p>
            <p className="mt-1">
              {outcome === AI_ASSESSMENT_OUTCOMES.CORROBORATED && `AI prediction matches citizen report: ${aiCategory}`}
              {outcome === AI_ASSESSMENT_OUTCOMES.MISMATCH && `AI prediction differs: ${aiCategory}`}
              {outcome === AI_ASSESSMENT_OUTCOMES.LEARNING_MODE && "Recorded for evaluation - not used for routing"}
              {outcome === AI_ASSESSMENT_OUTCOMES.MANUAL_REVIEW &&
                (aiCategory
                  ? `${aiCategory === citizenCategory ? "AI prediction matches citizen report" : "AI prediction"}: ${aiCategory} - admin verification required`
                  : "Result withheld - uncertain or invalid")}
              {outcome === AI_ASSESSMENT_OUTCOMES.NOT_APPLICABLE && "Not analyzed by the emergency model"}
            </p>
            {aiApplicable && report.ai_suggested_severity && (
              <p className="mt-1 text-sm text-gray-600 dark:text-gray-300">
                Suggested priority: {report.ai_suggested_severity}
                {report.ai_severity_confidence != null
                  ? ` (${Number(report.ai_severity_confidence).toFixed(1)}% confidence)`
                  : ""}
              </p>
            )}
          </div>
        </div>
      </details>
      )}

      {report.reviewed_at && (
        <p className="text-xs">
          Last reviewed: {new Date(report.reviewed_at).toLocaleString()}
        </p>
      )}

      <div className="grid gap-4 sm:grid-cols-2">
        {quickConfirm ? (
          <div className="block font-semibold">
            Official classification
            <div className="mt-1 min-h-11 rounded-lg border border-green-300 bg-green-50 p-2.5 font-semibold text-green-800 dark:border-green-800 dark:bg-green-900/20 dark:text-green-300">
              {category}
            </div>
            <p className="mt-1 text-xs font-normal text-gray-500">
              The ML result supports this category. Change it if the report evidence does not agree.
            </p>
            <button
              type="button"
              onClick={() => setManualCorrection(true)}
              disabled={busy}
              className="mt-2 min-h-10 rounded-lg border border-purple-300 px-3 py-2 text-sm font-semibold text-purple-700 hover:bg-purple-50 disabled:opacity-50 dark:text-purple-300"
            >
              Photo or category looks wrong? Correct manually
            </button>
          </div>
        ) : (
          <label className="block font-semibold">
            Official classification
            <select
              value={category}
              onChange={(e) => {
                setCategory(e.target.value);
              }}
              disabled={busy}
              className="mt-1 min-h-11 w-full rounded-lg border border-gray-300 p-2.5 text-base dark:bg-gray-800"
            >
              <option value="">Select classification</option>
              {REPORT_CATEGORIES.map((item) => (
                <option key={item} value={item}>
                  {item}
                </option>
              ))}
            </select>
          </label>
        )}
        <label className="block font-semibold">
          {communityConcern ? "Priority" : "Final severity"}
          <select
            value={severity}
            onChange={(e) => setSeverity(e.target.value)}
            disabled={busy}
            className="mt-1 min-h-11 w-full rounded-lg border border-gray-300 p-2.5 text-base dark:bg-gray-800"
          >
            <option value="">Select severity</option>
            {["High", "Medium", "Low"].map((level) => (
              <option key={level}>{level}</option>
            ))}
          </select>
        </label>
      </div>

      <div className="rounded-lg border border-gray-200 bg-gray-50 px-3 py-2.5 dark:border-gray-700 dark:bg-gray-900/40">
        <p className="font-semibold text-gray-800 dark:text-gray-100">Handled by: {BARANGAY_RESPONSE_TEAM}</p>
        <p className="mt-1 text-sm text-gray-600 dark:text-gray-300">
          This system currently records and coordinates reports at the barangay level only.
        </p>
      </div>

      <div className="rounded-lg border border-blue-200 bg-blue-50 p-3 dark:border-blue-900 dark:bg-blue-950/20">
        {messageAlreadySent ? (
          <div>
            <p className="font-bold text-blue-900 dark:text-blue-100">Citizen message sent</p>
            <p className="mt-1 rounded-md bg-white px-3 py-2 text-sm text-gray-800 dark:bg-gray-800 dark:text-gray-100">
              {report.citizen_message || "The one-time message was sent successfully."}
            </p>
            <p className="mt-2 text-xs text-gray-600 dark:text-gray-300">
              Only one general message is allowed per report. Use a status update or Request more information for the next required action.
            </p>
          </div>
        ) : (
          <>
            <label className="block font-semibold text-gray-900 dark:text-white">
              One-time message to citizen
              <textarea
                value={citizenMessage}
                onChange={(event) => {
                  setCitizenMessage(event.target.value);
                  setMessageStatus("");
                }}
                disabled={busy}
                maxLength={1000}
                rows={3}
                className="mt-1 w-full rounded-lg border border-gray-300 bg-white p-2.5 text-base dark:border-gray-600 dark:bg-gray-800"
                placeholder="Example: We received your report. Please monitor its status here."
              />
            </label>
            <div className="mt-2 flex flex-wrap items-center justify-between gap-2">
              <p className="text-xs text-gray-600 dark:text-gray-300">
                This can be sent once and appears inside this exact report in the citizen app.
              </p>
              <button
                type="button"
                disabled={busy || !citizenMessage.trim()}
                onClick={sendCitizenMessage}
                className="min-h-10 rounded-lg bg-blue-700 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-800 disabled:opacity-50"
              >
                {busy ? "Sending..." : "Send one-time message"}
              </button>
            </div>
          </>
        )}
        {messageStatus && (
          <p role="status" className="mt-2 text-sm font-medium text-blue-800 dark:text-blue-200">
            {messageStatus}
          </p>
        )}
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        <button
          type="button"
          disabled={busy}
          onClick={() => review("verified")}
          className="min-h-11 rounded-lg bg-green-700 px-4 py-2.5 text-base font-semibold text-white hover:bg-green-800 disabled:opacity-50 sm:col-span-2"
        >
          {busy
            ? "Saving..."
            : quickConfirm
              ? "Confirm report"
              : outcome === AI_ASSESSMENT_OUTCOMES.MISMATCH
                ? "Confirm corrected report"
                : communityConcern
                  ? "Approve for barangay action"
                  : "Confirm report"}
        </button>
        <button
          type="button"
          disabled={busy || progressed || informationAlreadyRequested || reportRejected}
          onClick={() => openDecisionPrompt("needs_information")}
          className="min-h-10 rounded-lg border border-amber-500 bg-white px-3 py-2 text-sm font-semibold text-amber-800 hover:bg-amber-50 disabled:opacity-50 dark:bg-gray-800 dark:text-amber-200"
        >
          {informationAlreadyRequested ? "Information requested" : "Request more information"}
        </button>
        <button
          type="button"
          disabled={busy || progressed || reportRejected}
          onClick={() => openDecisionPrompt("rejected")}
          className="min-h-10 rounded-lg border border-red-500 bg-white px-3 py-2 text-sm font-semibold text-red-800 hover:bg-red-50 disabled:opacity-50 dark:bg-gray-800 dark:text-red-200"
        >
          Reject report
        </button>
      </div>
      {progressed && (
        <p className="text-xs text-gray-500">
          This case is already being handled or completed; rejection is unavailable.
        </p>
      )}
      {error && (
        <p role="alert" className="text-sm text-red-600">
          {error}
        </p>
      )}
      {decisionPrompt && (
        <div
          className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4"
          onMouseDown={() => !busy && setDecisionPrompt("")}
        >
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby="decision-prompt-title"
            className="w-full max-w-md rounded-xl bg-white p-4 shadow-2xl dark:bg-gray-800"
            onMouseDown={(event) => event.stopPropagation()}
          >
            <h4 id="decision-prompt-title" className="text-lg font-bold text-gray-900 dark:text-white">
              {decisionPrompt === "needs_information"
                ? "Request more information"
                : "Reason for rejection"}
            </h4>
            <p className="mt-1 text-sm text-gray-600 dark:text-gray-300">
              {decisionPrompt === "needs_information"
                ? "Tell the citizen exactly what information is missing."
                : "Explain clearly why this report cannot be accepted."}
            </p>
            <textarea
              autoFocus
              value={decisionReason}
              onChange={(event) => setDecisionReason(event.target.value)}
              disabled={busy}
              maxLength={2000}
              rows={4}
              className="mt-3 w-full rounded-lg border border-gray-300 p-2.5 text-base dark:border-gray-600 dark:bg-gray-900"
              placeholder={decisionPrompt === "needs_information"
                ? "Example: Please provide the nearest landmark."
                : "Enter the rejection reason."}
            />
            <div className="mt-3 flex justify-end gap-2">
              <button
                type="button"
                disabled={busy}
                onClick={() => setDecisionPrompt("")}
                className="min-h-10 rounded-lg border border-gray-300 px-4 py-2 text-sm font-semibold dark:border-gray-600"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={busy || !decisionReason.trim()}
                onClick={submitDecisionPrompt}
                className={`min-h-10 rounded-lg px-4 py-2 text-sm font-semibold text-white disabled:opacity-50 ${
                  decisionPrompt === "needs_information"
                    ? "bg-amber-700 hover:bg-amber-800"
                    : "bg-red-700 hover:bg-red-800"
                }`}
              >
                {busy
                  ? "Saving..."
                  : decisionPrompt === "needs_information"
                    ? "Send request"
                    : "Reject report"}
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
