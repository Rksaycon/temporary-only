export const verificationOf = (report) => report.verification_status ||
  (["assigned", "in_progress", "resolved", "closed"].includes(report.status) ? "verified" : "pending");
export const verificationLabel = (report) => ({
  pending: "Pending verification", verified: "Verified",
  needs_information: "More information needed", rejected: "Rejected",
})[verificationOf(report)] || "Pending verification";

