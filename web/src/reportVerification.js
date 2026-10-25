export const verificationOf = (report) => report.verification_status ||
  (["assigned", "in_progress", "resolved", "closed"].includes(report.status) ? "verified" : "pending");
export const verificationLabel = (report) => ({pending: "Pending verification", verified: "Verified", needs_information: "More information needed", rejected: "Rejected"})[verificationOf(report)] || "Pending verification";
export const canProgress = (report) => verificationOf(report) === "verified";

// Rejection is a verification decision; existing closed reports remain resolved.
export const reportStatus = (report) => verificationOf(report) === "rejected"
  ? "rejected" : report.status === "closed" ? "resolved" : report.status || "received";
export const needsAttention = (report) => !["resolved", "rejected"].includes(reportStatus(report));
export const matchesStatus = (report, filter) => filter === "all" || (filter === "outstanding" ? needsAttention(report) : filter === "active"
  ? ["assigned", "in_progress"].includes(reportStatus(report))
  : reportStatus(report) === filter);
