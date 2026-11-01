import {
  hasClassificationMismatch,
  reportedCategoryOf,
  verifiedCategoryOf,
} from "./reportClassification";
import { reportStatus, verificationOf } from "./reportVerification";
import { locationGroupingKey } from "./reportLocation";

const WINDOW_MS = 30 * 60 * 1000;
const SEVERITY_RANK = { High: 3, Medium: 2, Low: 1 };

const normalizedLocation = (value) =>
  String(value || "Unknown location")
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const locationKey = (value) => {
  const location = normalizedLocation(locationGroupingKey(value));
  const zone = location.match(/\b(?:zone|purok)\s*[-:]?\s*(\d+)\b/);
  return zone ? `zone-${zone[1]}` : location;
};

const latestSeverity = (reports) =>
  reports.reduce((highest, report) => {
    const candidate = report.severity || report.ai_suggested_severity;
    return (SEVERITY_RANK[candidate] || 0) > (SEVERITY_RANK[highest] || 0)
      ? candidate
      : highest;
  }, "");

const incidentState = (reports) => {
  if (reports.every((report) => ["resolved", "closed"].includes(reportStatus(report)))) {
    return "Resolved";
  }
  if (reports.some((report) => reportStatus(report) === "in_progress")) {
    return "Responder contacted / ongoing";
  }
  if (reports.some((report) => reportStatus(report) === "assigned")) {
    return "Acknowledged";
  }
  if (reports.some((report) => verificationOf(report) === "pending")) {
    return "Needs confirmation";
  }
  return "New incident";
};

// This is intentionally a visual grouping layer. It never deletes or merges
// citizen records, so an admin can always inspect every original submission.
export const groupReportsIntoIncidents = (reports) => {
  const sorted = [...reports].sort(
    (a, b) => new Date(a.created_at || 0) - new Date(b.created_at || 0),
  );
  const groups = [];

  for (const report of sorted) {
    // Group from the citizen/admin classification, not an unverified AI
    // suggestion. This prevents a single wrong AI result from splitting one
    // real-world incident into two cards.
    const category = verifiedCategoryOf(report) || reportedCategoryOf(report) || "Unclassified";
    const location = locationKey(report.location);
    const createdAt = new Date(report.created_at || 0).getTime();
    const matching = groups.find(
      (group) =>
        group.category === category &&
        group.locationKey === location &&
        Math.abs(createdAt - group.latestTimestamp) <= WINDOW_MS,
    );

    if (matching) {
      matching.reports.push(report);
      matching.latestTimestamp = Math.max(matching.latestTimestamp, createdAt);
      matching.firstTimestamp = Math.min(matching.firstTimestamp, createdAt);
    } else {
      groups.push({
        id: `${category}:${location}:${report.id}`,
        category,
        locationKey: location,
        location: report.location || "Unknown location",
        firstTimestamp: createdAt,
        latestTimestamp: createdAt,
        reports: [report],
      });
    }
  }

  return groups
    .map((group) => ({
      ...group,
      severity: latestSeverity(group.reports) || "Unassigned",
      state: incidentState(group.reports),
      hasMismatch: group.reports.some(hasClassificationMismatch),
      needsReview: group.reports.some(
        (report) => verificationOf(report) !== "verified",
      ),
    }))
    .sort((a, b) => {
      const severityDifference =
        (SEVERITY_RANK[b.severity] || 0) - (SEVERITY_RANK[a.severity] || 0);
      return severityDifference || b.latestTimestamp - a.latestTimestamp;
    });
};

