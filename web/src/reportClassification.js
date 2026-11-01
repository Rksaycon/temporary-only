export const REPORT_CATEGORIES = [
  "Fire",
  "Flooding",
  "Medical Emergency",
  "Infrastructure Damage",
  "Earthquake",
  "Landslide",
  "Sanitation",
  "Security",
  "Traffic",
  "Environment",
  "Health",
  "Other",
];

// These are the only categories supported by the current image model. Reports
// outside this list use citizen selection + admin verification, without
// pretending that the emergency classifier understands community concerns.
export const ML_SUPPORTED_CATEGORIES = [
  "Fire",
  "Flooding",
  "Medical Emergency",
  "Infrastructure Damage",
];

// Only these classes currently have enough validated training coverage to
// help streamline routing. The model still records results for Medical and
// Infrastructure, but those classes stay in a human-only learning workflow.
export const AI_ROUTING_CATEGORIES = ["Fire", "Flooding"];

export const COMMUNITY_CONCERN_CATEGORIES = [
  "Sanitation",
  "Security",
  "Traffic",
  "Environment",
  "Health",
  "Other",
];

export const EMERGENCY_REPORT_CATEGORIES = [
  "Fire",
  "Flooding",
  "Medical Emergency",
  "Infrastructure Damage",
  "Earthquake",
  "Landslide",
];

const CATEGORY_ALIASES = {
  fire: "Fire",
  flood: "Flooding",
  flooding: "Flooding",
  medical: "Medical Emergency",
  "medical emergency": "Medical Emergency",
  infrastructure: "Infrastructure Damage",
  "infrastructure damage": "Infrastructure Damage",
  earthquake: "Earthquake",
  landslide: "Landslide",
  sanitation: "Sanitation",
  security: "Security",
  traffic: "Traffic",
  environment: "Environment",
  health: "Health",
  other: "Other",
  others: "Other",
};

export const canonicalCategory = (value) => {
  const category = String(value || "").trim();
  if (!category) return "";
  return CATEGORY_ALIASES[category.toLowerCase()] || category;
};

export const reportedCategoryOf = (report) =>
  canonicalCategory(report.reported_category || report.category);

export const aiCategoryOf = (report) => {
  // A manual-review flag prevents automation, not visibility. Show a valid
  // model suggestion as supporting evidence while keeping it unaccepted.
  // Explicitly invalid photos still suppress the model's closed-set guess.
  if (report.ai_image_valid === false) {
    return "";
  }
  return canonicalCategory(report.ai_detected_image_category);
};

export const isAiCategoryAccepted = (report) =>
  Boolean(aiCategoryOf(report)) &&
  report.ai_image_valid !== false &&
  report.requires_manual_review !== true;

export const isAiClassificationApplicable = (report) => {
  const reportType = String(report.report_type || "").trim().toLowerCase();
  if (reportType === "minor concern") return false;
  return ML_SUPPORTED_CATEGORIES.includes(reportedCategoryOf(report));
};

export const isCommunityConcern = (report) => {
  const reportType = String(report.report_type || "").trim().toLowerCase();
  if (reportType === "minor concern") return true;
  if (reportType === "emergency") return false;
  return COMMUNITY_CONCERN_CATEGORIES.includes(reportedCategoryOf(report));
};

export const isEmergencyReport = (report) => {
  const reportType = String(report.report_type || "").trim().toLowerCase();
  if (reportType === "emergency") return true;
  if (reportType === "minor concern") return false;
  return EMERGENCY_REPORT_CATEGORIES.includes(reportedCategoryOf(report));
};

// One shared decision for every web view. The model is an evidence checker:
// it either corroborates the citizen, identifies a mismatch, records a
// learning-only result, withholds an uncertain result, or is not applicable.
export const AI_ASSESSMENT_OUTCOMES = {
  CORROBORATED: "corroborated",
  MISMATCH: "mismatch",
  LEARNING_MODE: "learning_mode",
  MANUAL_REVIEW: "manual_review",
  NOT_APPLICABLE: "not_applicable",
};

export const aiAssessmentOutcome = (report) => {
  if (!isAiClassificationApplicable(report)) {
    return AI_ASSESSMENT_OUTCOMES.NOT_APPLICABLE;
  }

  if (
    report.requires_manual_review === true ||
    report.ai_image_valid === false
  ) {
    return AI_ASSESSMENT_OUTCOMES.MANUAL_REVIEW;
  }

  const citizenCategory = reportedCategoryOf(report);
  const detectedCategory = aiCategoryOf(report);
  if (!detectedCategory) return AI_ASSESSMENT_OUTCOMES.MANUAL_REVIEW;

  // Scarce Medical and Infrastructure datasets must never move a report into
  // the fast-routing queue. The prediction remains available for model
  // evaluation, while the administrator makes the official decision.
  if (!AI_ROUTING_CATEGORIES.includes(citizenCategory)) {
    return AI_ASSESSMENT_OUTCOMES.LEARNING_MODE;
  }

  if (citizenCategory !== detectedCategory) {
    return AI_ASSESSMENT_OUTCOMES.MISMATCH;
  }
  return AI_ASSESSMENT_OUTCOMES.CORROBORATED;
};

export const isAiCorroborated = (report) =>
  aiAssessmentOutcome(report) === AI_ASSESSMENT_OUTCOMES.CORROBORATED;

// Older verified rows predate verified_category. For those rows, category was
// the only available classification and remains the safest compatibility value.
export const verifiedCategoryOf = (report) => {
  const verified = canonicalCategory(report.verified_category);
  if (verified) return verified;
  const legacyVerified =
    report.verification_status === "verified" ||
    (!report.verification_status &&
      ["assigned", "in_progress", "resolved", "closed"].includes(report.status));
  if (legacyVerified) return reportedCategoryOf(report);
  return "";
};

export const effectiveCategoryOf = (report) =>
  verifiedCategoryOf(report) ||
  reportedCategoryOf(report) ||
  (isAiClassificationApplicable(report) && isAiCategoryAccepted(report)
    ? aiCategoryOf(report)
    : "");

export const hasClassificationMismatch = (report) => {
  return aiAssessmentOutcome(report) === AI_ASSESSMENT_OUTCOMES.MISMATCH;
};

export const matchesClassification = (report, filter) => {
  if (filter === "all") return true;
  if (filter === "mismatch") return hasClassificationMismatch(report);
  if (filter === "corroborated") return isAiCorroborated(report);
  if (filter === "learning_mode") {
    return aiAssessmentOutcome(report) === AI_ASSESSMENT_OUTCOMES.LEARNING_MODE;
  }
  if (filter === "awaiting_ai") {
    return (
      isAiClassificationApplicable(report) &&
      !aiCategoryOf(report) &&
      report.requires_manual_review !== true &&
      report.ai_image_valid !== false
    );
  }
  if (filter === "community_concern") return isCommunityConcern(report);
  if (filter === "manual_review") {
    return aiAssessmentOutcome(report) === AI_ASSESSMENT_OUTCOMES.MANUAL_REVIEW;
  }
  return effectiveCategoryOf(report) === canonicalCategory(filter);
};

export const classificationSource = (report) => {
  if (verifiedCategoryOf(report)) return "Admin verified";
  if (reportedCategoryOf(report)) return "Citizen reported";
  if (isAiClassificationApplicable(report) && isAiCategoryAccepted(report)) {
    return "AI suggestion";
  }
  return "Unclassified";
};
