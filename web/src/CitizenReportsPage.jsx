import { useState, useEffect, useCallback, useMemo, Fragment } from "react";
import { useSearchParams } from "react-router-dom";
import { supabase } from "./supabaseClient";
import ReportVerificationPanel from "./ReportVerificationPanel";
import { groupReportsIntoIncidents } from "./incidentGrouping";
import { verificationOf, verificationLabel, canProgress, reportStatus, matchesStatus, workflowLabel } from "./reportVerification";
import {
  AI_ASSESSMENT_OUTCOMES,
  COMMUNITY_CONCERN_CATEGORIES,
  EMERGENCY_REPORT_CATEGORIES,
  REPORT_CATEGORIES,
  aiAssessmentOutcome,
  aiCategoryOf,
  classificationSource,
  effectiveCategoryOf,
  matchesClassification,
  reportedCategoryOf,
  isCommunityConcern,
  isEmergencyReport,
  verifiedCategoryOf,
} from "./reportClassification";
import { departmentForCategory } from "./reportRouting";
import { parseReportLocation } from "./reportLocation";

// Status vocabulary matches CitizenReportService._statusMessage() in the
// mobile app exactly, so a status set here maps to the message residents see.
const statusColors = {
  received: "bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300",
  assigned: "bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300",
  in_progress: "bg-indigo-100 dark:bg-indigo-900/30 text-indigo-800 dark:text-indigo-300",
  resolved: "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300",
  rejected: "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300",
  closed: "bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300",
};

const statusLabel = (s) => ({
  received: "New",
  assigned: "Acknowledged",
  in_progress: "Action ongoing",
  resolved: "Resolved",
  closed: "Resolved",
})[s || "received"] || String(s || "received").replaceAll("_", " ");

// severity comes from the mobile app's ML triage (see
// AiTriageService.classifySeverity() / SeverityResult.toPriorityLevel())
// — always exactly one of these three, when set at all.
const SEVERITY_ORDER = { High: 0, Medium: 1, Low: 2 };
const severityColors = {
  High: "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300",
  Medium: "bg-orange-100 dark:bg-orange-900/30 text-orange-800 dark:text-orange-300",
  Low: "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300",
};

const verificationColors = {
  pending: "bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-200",
  verified: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300",
  needs_information: "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300",
  rejected: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300",
};

const PAGE_SIZE = 25;
const REPORT_QUEUES = [
  { id: "needs_attention", label: "Needs Review" },
  { id: "ready", label: "ML Supported" },
  { id: "active", label: "Being Handled" },
  { id: "completed", label: "Finished" },
];

const REPORT_STREAMS = [
  { id: "emergency", label: "Emergency" },
  { id: "community", label: "Community" },
  { id: "all", label: "All reports" },
];

const SIMPLE_STATUS = {
  received: { label: "New · Needs review", tone: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-200" },
  assigned: { label: "Acknowledged", tone: "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-200" },
  in_progress: { label: "Action ongoing", tone: "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-200" },
  resolved: { label: "Resolved", tone: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-200" },
  closed: { label: "Closed", tone: "bg-gray-200 text-gray-800 dark:bg-gray-700 dark:text-gray-100" },
};

const mlPhotoView = (report) => {
  const outcome = aiAssessmentOutcome(report);
  const category = aiCategoryOf(report);
  if (outcome === AI_ASSESSMENT_OUTCOMES.CORROBORATED) {
    return {
      label: `Supports ${category}`,
      detail: "The ML photo result matches the citizen report. Admin confirmation is still required.",
      tone: "border-green-200 bg-green-50 text-green-800 dark:border-green-800 dark:bg-green-900/20 dark:text-green-200",
    };
  }
  if (outcome === AI_ASSESSMENT_OUTCOMES.MISMATCH) {
    return {
      label: `Possible ${category}`,
      detail: "The ML photo result does not match the citizen category. Review the evidence before continuing.",
      tone: "border-amber-300 bg-amber-50 text-amber-900 dark:border-amber-800 dark:bg-amber-900/20 dark:text-amber-200",
    };
  }
  if (outcome === AI_ASSESSMENT_OUTCOMES.LEARNING_MODE) {
    return {
      label: category ? `Possible ${category}` : "Learning result unavailable",
      detail: "The result is supporting information only and requires manual classification.",
      tone: "border-violet-200 bg-violet-50 text-violet-900 dark:border-violet-800 dark:bg-violet-900/20 dark:text-violet-200",
    };
  }
  if (outcome === AI_ASSESSMENT_OUTCOMES.MANUAL_REVIEW) {
    const agreesWithCitizen = category && category === reportedCategoryOf(report);
    return {
      label: category
        ? agreesWithCitizen
          ? `AI photo result matches report: ${category}`
          : `AI photo result suggests: ${category}`
        : "AI photo result unavailable · manual review",
      detail: category
        ? `${agreesWithCitizen ? "The image model's prediction matches the citizen's category." : "The image model predicted a category different from the citizen's selection."} This is an AI prediction, not proof that the incident is real. Admin verification is still required.`
        : "The photo was unclear, invalid, or below the safety threshold. Check it manually.",
      tone: "border-red-200 bg-red-50 text-red-900 dark:border-red-800 dark:bg-red-900/20 dark:text-red-200",
    };
  }
  return {
    label: "ML photo check not used",
    detail: "This category is handled through normal barangay review.",
    tone: "border-gray-200 bg-gray-50 text-gray-700 dark:border-gray-700 dark:bg-gray-900/30 dark:text-gray-200",
  };
};

const STATUS_OPTIONS = ["received", "assigned", "in_progress", "resolved", "closed"];

const attachReporterProfiles = async (rows) => {
  const reports = rows || [];
  const userIds = [...new Set(reports.map((report) => report.user_id).filter(Boolean))];
  if (userIds.length === 0) return reports;

  const { data: profiles, error: profileError } = await supabase
    .from("profiles")
    .select("id, name, email, phone")
    .in("id", userIds);

  if (profileError) return reports;
  const profilesById = new Map((profiles || []).map((profile) => [profile.id, profile]));
  return reports.map((report) => ({
    ...report,
    profiles: profilesById.get(report.user_id) || report.profiles || null,
  }));
};

const CitizenReportsPage = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const linkedReportId = searchParams.get("report");
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [selectedReport, setSelectedReport] = useState(null);
  const [filter, setFilter] = useState("all");
  // Include reports awaiting AI classification; severity sorting keeps urgent reports first.
  const [severityFilter, setSeverityFilter] = useState("all");
  const [search, setSearch] = useState("");
  const [savingId, setSavingId] = useState(null);
  const [verificationFilter, setVerificationFilter] = useState("all");
  const [classificationFilter, setClassificationFilter] = useState("all");
  const [reportStream, setReportStream] = useState("emergency");
  const [queue, setQueue] = useState("needs_attention");
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [page, setPage] = useState(0);
  const [totalMatching, setTotalMatching] = useState(0);
  const [queueCounts, setQueueCounts] = useState({});
  const [serverFiltering, setServerFiltering] = useState(null);
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [individualReportsOpen, setIndividualReportsOpen] = useState(false);
  const [expandedIncidentId, setExpandedIncidentId] = useState(null);
  const [hotlines, setHotlines] = useState([]);
  const [copiedNumber, setCopiedNumber] = useState("");

  const openReport = useCallback((report) => {
    setSelectedReport(report);
    const nextParams = new URLSearchParams(searchParams);
    nextParams.set("report", report.id);
    setSearchParams(nextParams, { replace: false });
  }, [searchParams, setSearchParams]);

  const closeReport = useCallback(() => {
    setSelectedReport(null);
    const nextParams = new URLSearchParams(searchParams);
    nextParams.delete("report");
    setSearchParams(nextParams, { replace: true });
  }, [searchParams, setSearchParams]);

  // Notification links include the report id. Fetch the report directly so
  // the correct review drawer opens even when the row is outside the current
  // queue, filter, or page of results.
  useEffect(() => {
    if (!linkedReportId) return;

    let cancelled = false;
    const openLinkedReport = async () => {
      const { data, error: reportError } = await supabase
        .from("citizen_reports")
        .select("*")
        .eq("id", linkedReportId)
        .maybeSingle();

      if (cancelled) return;
      if (reportError) {
        setError(`Unable to open the selected report: ${reportError.message}`);
        return;
      }
      if (!data) {
        setError("The selected report no longer exists or you do not have access to it.");
        return;
      }

      const [reportWithProfile] = await attachReporterProfiles([data]);
      if (!cancelled) setSelectedReport(reportWithProfile);
    };

    openLinkedReport();
    return () => {
      cancelled = true;
    };
  }, [linkedReportId]);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(search.trim()), 300);
    return () => clearTimeout(timer);
  }, [search]);

  useEffect(() => {
    let cancelled = false;
    const loadHotlines = async () => {
      const { data } = await supabase
        .from("hotlines")
        .select("*")
        .eq("is_active", true)
        .order("name");
      if (!cancelled) setHotlines(data || []);
    };
    loadHotlines();
    return () => {
      cancelled = true;
    };
  }, []);

  const fetchQueueCounts = useCallback(async () => {
    const { data, error: countError } = await supabase.rpc(
      "admin_citizen_report_queue_counts",
    );
    if (countError) return;
    setQueueCounts(
      Object.fromEntries(
        (data || []).map((row) => [row.queue, Number(row.total_count || 0)]),
      ),
    );
  }, []);

  const fetchReports = useCallback(async () => {
    setLoading(true);
    setError("");
    void fetchQueueCounts();

    // Stream views are selected from explicit emergency/community category
    // lists, not from ML support. This keeps Earthquake and Landslide in the
    // emergency queue even though the current image model cannot classify them.
    if (reportStream !== "all") {
      const categories = reportStream === "emergency"
        ? [...EMERGENCY_REPORT_CATEGORIES, "Flood", "Medical", "Infrastructure"]
        : [...COMMUNITY_CONCERN_CATEGORIES, "Others"];
      let { data, error: streamError } = await supabase
        .from("citizen_reports")
        .select("*")
        .in("category", categories)
        .order("created_at", { ascending: false })
        .limit(1000);

      if (streamError) {
        setError(streamError.message);
        setReports([]);
        setTotalMatching(0);
      } else {
        data = await attachReporterProfiles(data);
        setReports(data);
        setTotalMatching(data.length);
      }
      setServerFiltering(false);
      setLoading(false);
      return;
    }

    // Prefer the paginated admin RPC installed by
    // supabase_scale_citizen_reports.sql. It performs filtering, sorting and
    // counting in Postgres, so this page remains fast with thousands of rows.
    const { data: queueRows, error: queueError } = await supabase.rpc(
      "admin_list_citizen_reports_v2",
      {
        p_queue: queue,
        p_status: filter,
        p_severity: severityFilter,
        p_classification: classificationFilter,
        p_verification: verificationFilter,
        p_search: debouncedSearch,
        p_limit: PAGE_SIZE,
        p_offset: page * PAGE_SIZE,
      },
    );

    if (!queueError) {
      const rows = (queueRows || []).map((row) => row.report || row);
      setReports(rows);
      setTotalMatching(Number(queueRows?.[0]?.total_count || 0));
      setServerFiltering(true);
      setLoading(false);
      return;
    }

    // citizen_reports.user_id references auth.users rather than profiles, so
    // PostgREST cannot embed the profile automatically. Fetch reports and
    // account profiles separately, then join them by the same user id.
    let { data, error } = await supabase
      .from("citizen_reports")
      .select("*")
      .order("created_at", { ascending: false });

    if (error) {
      setError(error.message);
    } else {
      data = await attachReporterProfiles(data);
      setReports(data);
      setServerFiltering(false);
    }
    setLoading(false);
  }, [classificationFilter, debouncedSearch, fetchQueueCounts, filter, page, queue, reportStream, severityFilter, verificationFilter]);

  useEffect(() => {
    if (serverFiltering === false) return;
    // The effect intentionally starts a remote fetch whenever its query inputs
    // change; fetchReports owns the loading and result state for that request.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    fetchReports();
  }, [fetchReports, serverFiltering]);

  const saveReport = async (report, updates) => {
    let query = supabase.from("citizen_reports").update(updates).eq("id", report.id);
    if (report.updated_at) query = query.eq("updated_at", report.updated_at);
    const { data, error: saveError } = await query.select("*").single();
    if (saveError) throw new Error(`${saveError.message}. Refresh if another admin changed this report. Classification verification requires supabase_add_report_classification.sql to be installed.`);
    setReports(prev => prev.map(item => item.id === data.id ? { ...item, ...data } : item));
    setSelectedReport(prev => prev?.id === data.id ? { ...prev, ...data } : prev);
    if (serverFiltering === true) await fetchReports();
  };
  const handleReview = async (report, decision, note, severity, category, department) => {
    if (savingId) throw new Error("Wait for the current save to finish.");
    if (decision !== "verified" && !note.trim()) throw new Error("A reason is required.");
    if (decision === "verified" && !["High","Medium","Low"].includes(severity)) throw new Error("Choose the final severity.");
    if (decision === "verified" && !category) throw new Error("Choose the final classification.");
    if (decision === "verified" && !department) throw new Error("Barangay handling information is missing.");
    setSavingId(report.id);
    try {
      const updates = { verification_status: decision, verification_note: note };
      if (decision === "verified") {
        updates.severity = severity;
        updates.verified_category = category;
        updates.assigned_department = department;
        updates.assigned_at = new Date().toISOString();
        if (["received", "assigned"].includes(report.status || "received")) updates.status = "assigned";
      } else updates.status = "received";
      await saveReport(report, updates);
      // Database triggers record the reviewer and notify the citizen atomically.
    } catch (reviewError) {
      if (/assigned_department|assigned_at/i.test(reviewError.message || "")) {
        throw new Error(
          "Barangay assignment storage is not installed yet. Run web/supabase_add_report_assignment.sql in Supabase, then try again.",
          { cause: reviewError },
        );
      }
      throw reviewError;
    } finally { setSavingId(null); }
  };
  const handleSendCitizenMessage = async (report, message) => {
    const trimmedMessage = String(message || "").trim();
    if (!trimmedMessage) throw new Error("Enter a message first.");
    if (!report?.user_id) throw new Error("This report is not linked to a citizen account.");
    if (report.citizen_message_sent_at || report.citizen_message) {
      throw new Error("The one-time citizen message for this report has already been sent.");
    }
    if (savingId) throw new Error("Wait for the current save to finish.");

    setSavingId(report.id);
    try {
      const { data, error: messageError } = await supabase.rpc(
        "send_one_time_citizen_report_message",
        {
          p_report_id: report.id,
          p_message: trimmedMessage,
        },
      );
      if (messageError) {
        const setupHint = /send_one_time_citizen_report_message|schema cache|function/i.test(
          messageError.message || "",
        )
          ? " Run web/supabase_add_one_time_citizen_message.sql in Supabase first."
          : "";
        throw new Error(`${messageError.message}.${setupHint}`);
      }
      const updates = {
        citizen_message: data?.message || trimmedMessage,
        citizen_message_sent_at: data?.sent_at || new Date().toISOString(),
        ...(data?.updated_at ? { updated_at: data.updated_at } : {}),
      };
      setReports((previous) => previous.map((item) =>
        item.id === report.id ? { ...item, ...updates } : item,
      ));
      setSelectedReport((previous) =>
        previous?.id === report.id ? { ...previous, ...updates } : previous,
      );
      return updates;
    } finally {
      setSavingId(null);
    }
  };
  const handleStatusChange = async (id, newStatus) => {
    const report = reports.find(item => item.id === id) || selectedReport;
    if (!report || savingId || report.status === newStatus) return;
    if (!canProgress(report) && newStatus !== "received") {
      setError("Open report details and verify this report before progressing it."); return;
    }
    setSavingId(id); setError("");
    try { await saveReport(report, {status: newStatus, updated_at: new Date().toISOString()}); }
    catch (err) { setError(err.message); }
    finally { setSavingId(null); }
  };

  const residentName = (report) =>
    report.profiles?.name?.trim() ||
    report.contact?.trim() ||
    report.profiles?.email?.trim() ||
    "Unknown account";

  const isDone = (report) => report.status === "resolved" || report.status === "closed" || verificationOf(report) === "rejected";

  const matchesQueue = (report) => {
    const outcome = aiAssessmentOutcome(report);
    const verification = verificationOf(report);
    switch (queue) {
      case "needs_attention":
        return (
          verification === "needs_information" ||
          (verification === "pending" && outcome !== AI_ASSESSMENT_OUTCOMES.CORROBORATED)
        );
      case "ready":
        return verification === "pending" && outcome === AI_ASSESSMENT_OUTCOMES.CORROBORATED;
      case "active":
        return ["assigned", "in_progress"].includes(reportStatus(report));
      case "completed":
        return isDone(report);
      default:
        return true;
    }
  };

  // FIX — reports used to only ever sort by created_at, so a High
  // severity report submitted yesterday could sit buried below a dozen
  // Low severity ones from this morning — and a resolved/closed report
  // could sit ABOVE an ongoing one just for being more severe or newer,
  // burying the work that's still actually in progress. Ongoing reports
  // now always come before resolved/closed ones; within each of those
  // two groups, High severity floats to the top, then most recent first.
  const filteredReports = serverFiltering === true
    ? reports
    : reports.filter((report) => {
      if (reportStream === "emergency" && !isEmergencyReport(report)) return false;
      if (reportStream === "community" && !isCommunityConcern(report)) return false;
      if (!matchesQueue(report)) return false;
      if (verificationFilter !== "all" && verificationOf(report) !== verificationFilter) return false;
      if (!matchesStatus(report, filter)) return false;
      if (severityFilter === "unassigned" && report.severity) return false;
      if (!["all", "unassigned"].includes(severityFilter) && report.severity !== severityFilter) return false;
      if (!matchesClassification(report, classificationFilter)) return false;
      const haystack = `${report.description || ""} ${residentName(report)} ${reportedCategoryOf(report)} ${aiCategoryOf(report)} ${verifiedCategoryOf(report)}`.toLowerCase();
      if (search && !haystack.includes(search.toLowerCase())) return false;
      return true;
    })
    .sort((a, b) => {
      const doneDiff = Number(isDone(a)) - Number(isDone(b));
      if (doneDiff !== 0) return doneDiff;
      const severityDiff =
        (SEVERITY_ORDER[a.severity] ?? 3) - (SEVERITY_ORDER[b.severity] ?? 3);
      if (severityDiff !== 0) return severityDiff;
      return new Date(b.created_at) - new Date(a.created_at);
    });

  const visibleReports = serverFiltering === true
    ? filteredReports
    : filteredReports.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE);
  const resultCount = serverFiltering === true ? totalMatching : filteredReports.length;
  const totalPages = Math.max(1, Math.ceil(resultCount / PAGE_SIZE));
  const visibleIncidents = groupReportsIntoIncidents(visibleReports);

  // Index where the resolved/closed group begins, so the table can drop
  // in a section divider right at that boundary (filteredReports is
  // already sorted so all "ongoing" rows come first).
  const firstDoneIndex = visibleReports.findIndex(isDone);

  const formatDate = (iso) => {
    if (!iso) return "—";
    return new Date(iso).toLocaleDateString("en-PH", {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  };

  const formatDateTime = (value) =>
    new Date(value).toLocaleString("en-PH", {
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    });

  const hotlineForCategory = (category) => {
    const wantedType = category === "Fire"
      ? "fire"
      : category === "Medical Emergency"
        ? "medical"
        : "";
    if (!wantedType) return null;
    const match = hotlines.find(
      (hotline) => String(hotline.type || "").trim().toLowerCase() === wantedType,
    );
    if (!match) return null;
    const number = String(match.number || match.phone || "").trim();
    return number ? { name: match.name || (wantedType === "fire" ? "BFP" : "Ambulance"), number } : null;
  };

  const copyPhoneNumber = async (number) => {
    try {
      await navigator.clipboard.writeText(number);
      setCopiedNumber(number);
      window.setTimeout(() => setCopiedNumber(""), 1800);
    } catch {
      setError(`Could not copy ${number}. Select and copy it manually.`);
    }
  };

  const selectedCategory = selectedReport ? effectiveCategoryOf(selectedReport) : "";
  const selectedEmergencyContact = selectedReport
    ? hotlineForCategory(selectedCategory)
    : null;
  const possibleReporterPhone = selectedReport
    ? String(selectedReport.profiles?.phone || selectedReport.contact || "").trim()
    : "";
  const selectedReporterPhone = /^\+?[0-9()\-\s]{7,}$/.test(possibleReporterPhone)
    ? possibleReporterPhone
    : "";
  const selectedIncident = useMemo(() => {
    if (!selectedReport) return null;
    const incidentSource = [
      ...reports.filter((report) => report.id !== selectedReport.id),
      selectedReport,
    ];
    return groupReportsIntoIncidents(incidentSource).find((incident) =>
      incident.reports.some((report) => report.id === selectedReport.id),
    ) || null;
  }, [reports, selectedReport]);
  const selectedIncidentPhotos = useMemo(() => {
    if (!selectedIncident || !selectedReport) return [];
    return [...new Set(
      [
        ...(Array.isArray(selectedReport.photo_urls) ? selectedReport.photo_urls : []),
        ...selectedIncident.reports
          .filter((report) => report.id !== selectedReport.id)
          .flatMap((report) => Array.isArray(report.photo_urls) ? report.photo_urls : []),
      ].filter(Boolean),
    )];
  }, [selectedIncident, selectedReport]);
  const selectedMainPhoto = selectedIncidentPhotos[0] || "";
  const selectedLocationInfo = parseReportLocation(selectedReport?.location);
  const selectedMlView = selectedReport ? mlPhotoView(selectedReport) : null;

  const activeFiltersCount = [
    filter !== "all",
    severityFilter !== "all",
    verificationFilter !== "all",
    classificationFilter !== "all",
    search.trim() !== "",
  ].filter(Boolean).length;

  const selectQueue = (nextQueue) => {
    setQueue(nextQueue);
    setPage(0);
  };

  const selectStream = (nextStream) => {
    setReportStream(nextStream);
    setClassificationFilter("all");
    if (nextStream === "community" && queue === "ready") {
      setQueue("needs_attention");
    }
    setPage(0);
    setExpandedIncidentId(null);
    // Re-enable fetching when the current stream is using the local fallback.
    setServerFiltering(null);
  };

  const clearFilters = () => {
    setFilter("all");
    setSeverityFilter("all");
    setVerificationFilter("all");
    setClassificationFilter("all");
    setSearch("");
    setPage(0);
  };

  const visibleClassificationCategories = reportStream === "community"
    ? COMMUNITY_CONCERN_CATEGORIES
    : reportStream === "emergency"
      ? EMERGENCY_REPORT_CATEGORIES
      : REPORT_CATEGORIES;

  return (
    <div className="mx-auto max-w-7xl space-y-5 text-[15px]">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">
          Citizen Reports
        </h1>
        <p className="mt-1 text-base text-gray-600 dark:text-gray-300">
          Choose a report below to review and take action.
        </p>
      </div>

      {error && (
        <div className="rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 text-sm px-4 py-3">
          {error}
        </div>
      )}

      <div className="grid overflow-hidden rounded-xl border border-gray-300 bg-white sm:grid-cols-3 dark:border-gray-600 dark:bg-gray-800">
        {REPORT_STREAMS.map((stream) => {
          const selected = reportStream === stream.id;
          return (
            <button
              key={stream.id}
              type="button"
              onClick={() => selectStream(stream.id)}
              className={`min-h-11 border-b border-gray-300 px-4 py-2.5 text-center text-base font-semibold transition last:border-b-0 sm:border-b-0 sm:border-r sm:last:border-r-0 dark:border-gray-600 ${
                selected
                  ? stream.id === "emergency"
                    ? "bg-red-700 text-white"
                    : "bg-purple-700 text-white"
                  : "text-gray-700 hover:bg-gray-100 dark:text-gray-100 dark:hover:bg-gray-700"
              }`}
            >
              {stream.label}
            </button>
          );
        })}
      </div>

      {/* Operational queues keep the default view focused on work that needs action. */}
      <div className="space-y-3 rounded-xl border bg-white p-3 dark:border-gray-700 dark:bg-gray-800">
        <div>
          <p className="mb-2 font-semibold text-gray-800 dark:text-gray-100">Report queues</p>
          <div className={`grid gap-2 sm:grid-cols-2 ${reportStream === "community" ? "xl:grid-cols-3" : "xl:grid-cols-4"}`}>
            {REPORT_QUEUES.filter((item) => reportStream !== "community" || item.id !== "ready").map((item) => {
              const count = reportStream === "all"
                ? (queueCounts[item.id] ?? (queue === item.id ? resultCount : null))
                : (queue === item.id ? resultCount : null);
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => selectQueue(item.id)}
                  className={`min-h-11 rounded-lg border px-3 py-2 text-sm font-semibold transition ${
                    queue === item.id
                      ? "border-purple-700 bg-purple-700 text-white"
                      : "border-gray-300 text-gray-700 hover:bg-gray-100 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-700"
                  }`}
                >
                  {item.label}
                  {count !== null && !loading && (
                    <span className={`ml-2 rounded-full px-2 py-0.5 text-xs ${queue === item.id ? "bg-white/20" : "bg-gray-100 dark:bg-gray-700"}`}>
                      {count}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        </div>

        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
            <input
              type="search"
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(0);
              }}
              placeholder="Search reports"
              aria-label="Search reports"
              className="min-h-11 w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-base text-gray-900 dark:border-gray-500 dark:bg-gray-700 dark:text-white"
            />
            <button
              type="button"
              onClick={() => setFiltersOpen((open) => !open)}
              aria-expanded={filtersOpen}
              className={`min-h-11 whitespace-nowrap rounded-lg border px-4 py-2 text-sm font-semibold ${
                filtersOpen || activeFiltersCount > 0
                  ? "border-purple-500 bg-purple-50 text-purple-800 dark:bg-purple-900/30 dark:text-purple-200"
                  : "border-gray-300 text-gray-700 dark:border-gray-600 dark:text-gray-200"
              }`}
            >
              More filters{activeFiltersCount > 0 ? ` (${activeFiltersCount})` : ""}
            </button>
        </div>
      </div>

      {/* Advanced filters stay out of the way until an admin needs them. */}
      {filtersOpen && (
      <div className="bg-white dark:bg-gray-800 rounded-xl p-4 border dark:border-gray-700">
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Filter by Status
            </label>
            <span className="relative block">
              <select
                value={filter}
                onChange={(e) => { setFilter(e.target.value); setPage(0); }}
                className="w-full cursor-pointer appearance-none rounded-lg border border-gray-300 bg-white px-3 py-2 pr-10 text-gray-800 focus:ring-2 focus:ring-purple-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              >
                <option value="all">All Reports</option>
                <option value="outstanding">Awaiting action</option>
                <option value="active">Assigned / In progress</option>
                {["received", "assigned", "in_progress", "resolved", "rejected"].map((status) => (
                  <option key={status} value={status}>{statusLabel(status)}</option>
                ))}
              </select>
              <svg aria-hidden="true" viewBox="0 0 20 20" fill="none" className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-600 dark:text-gray-300"><path d="m5 7.5 5 5 5-5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg>
            </span>
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Filter by Severity
            </label>
            <span className="relative block">
              <select
                value={severityFilter}
                onChange={(e) => { setSeverityFilter(e.target.value); setPage(0); }}
                className="w-full cursor-pointer appearance-none rounded-lg border border-gray-300 bg-white px-3 py-2 pr-10 text-gray-800 focus:ring-2 focus:ring-purple-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              >
                <option value="all">All Severities</option>
                <option value="High">High Priority</option>
                <option value="Medium">Medium Priority</option>
                <option value="Low">Low Priority</option>
                <option value="unassigned">Awaiting severity</option>
              </select>
              <svg aria-hidden="true" viewBox="0 0 20 20" fill="none" className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-600 dark:text-gray-300"><path d="m5 7.5 5 5 5-5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg>
            </span>
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
              {reportStream === "community" ? "Filter by Category" : "Filter by Classification"}
            </label>
            <span className="relative block">
              <select
                value={classificationFilter}
                onChange={(e) => { setClassificationFilter(e.target.value); setPage(0); }}
                className="w-full cursor-pointer appearance-none rounded-lg border border-gray-300 bg-white px-3 py-2 pr-10 text-gray-800 focus:ring-2 focus:ring-purple-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              >
                <option value="all">{reportStream === "community" ? "All Categories" : "All Classifications"}</option>
                {reportStream !== "community" && (
                  <>
                    <option value="mismatch">Citizen / ML mismatch</option>
                    <option value="corroborated">AI agrees with report (Fire/Flood only)</option>
                    <option value="learning_mode">ML learning mode</option>
                    <option value="manual_review">Manual review required</option>
                    <option value="awaiting_ai">Emergency awaiting ML result</option>
                  </>
                )}
                {reportStream === "all" && (
                  <option value="community_concern">Community concern</option>
                )}
                {visibleClassificationCategories.map((category) => (
                  <option key={category} value={category}>{category}</option>
                ))}
              </select>
              <svg aria-hidden="true" viewBox="0 0 20 20" fill="none" className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-600 dark:text-gray-300"><path d="m5 7.5 5 5 5-5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg>
            </span>
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Filter by Verification
            </label>
            <span className="relative block">
              <select
                value={verificationFilter}
                onChange={(e) => { setVerificationFilter(e.target.value); setPage(0); }}
                className="w-full cursor-pointer appearance-none rounded-lg border border-gray-300 bg-white px-3 py-2 pr-10 text-gray-800 focus:ring-2 focus:ring-purple-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
              >
                <option value="all">All Verification States</option>
                <option value="pending">Pending verification</option>
                <option value="verified">Verified</option>
                <option value="needs_information">More information needed</option>
                <option value="rejected">Rejected</option>
              </select>
              <svg aria-hidden="true" viewBox="0 0 20 20" fill="none" className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-600 dark:text-gray-300"><path d="m5 7.5 5 5 5-5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg>
            </span>
          </div>

        </div>
        <div className="mt-3 flex flex-wrap items-center justify-between gap-3 text-xs text-gray-500 dark:text-gray-400">
          <p>Classification uses admin result first, then AI, then citizen selection.</p>
          <div className="flex flex-wrap gap-3">
            <button type="button" onClick={() => selectQueue("all")} className="font-semibold text-purple-700 hover:text-purple-900 dark:text-purple-300 dark:hover:text-purple-200">
              View all reports
            </button>
            <button type="button" onClick={clearFilters} className="font-semibold text-purple-700 hover:text-purple-900 dark:text-purple-300 dark:hover:text-purple-200">
              Clear advanced filters
            </button>
          </div>
        </div>
      </div>
      )}

      {/* Incident view keeps duplicate citizen reports from overwhelming non-technical admins. */}
      <section className="space-y-3 rounded-xl border bg-gray-50 p-3 dark:border-gray-700 dark:bg-gray-900/30">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="text-xl font-bold text-gray-900 dark:text-white">Reports to handle</h2>
            <p className="mt-0.5 text-sm text-gray-600 dark:text-gray-300">
              {visibleIncidents.length} {visibleIncidents.length === 1 ? "incident" : "incidents"}
            </p>
          </div>
          <button
            type="button"
            onClick={() => setIndividualReportsOpen((open) => !open)}
            className="min-h-10 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-100 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700"
          >
            {individualReportsOpen ? "Hide full report list" : "View full report list"}
          </button>
        </div>

        {loading && (
          <p className="rounded-lg bg-white px-4 py-8 text-center text-base text-gray-600 dark:bg-gray-800 dark:text-gray-300">Loading reports...</p>
        )}
        {!loading && visibleIncidents.length === 0 && (
          <p className="rounded-lg bg-white px-4 py-8 text-center text-base text-gray-600 dark:bg-gray-800 dark:text-gray-300">No reports need attention here.</p>
        )}

        {!loading && visibleIncidents.map((incident) => {
          const expanded = expandedIncidentId === incident.id;
          const representative = incident.reports[incident.reports.length - 1];
          const reporterNames = [...new Set(incident.reports.map(residentName))];
          const visibleReporterNames = reporterNames.slice(0, 3).join(", ");
          const remainingReporterCount = reporterNames.length - 3;
          const corroboratedCount = incident.reports.filter(
            (report) => aiAssessmentOutcome(report) === AI_ASSESSMENT_OUTCOMES.CORROBORATED,
          ).length;
          const exceptionCount = incident.reports.filter(
            (report) =>
              verificationOf(report) === "needs_information" ||
              (verificationOf(report) === "pending" &&
                aiAssessmentOutcome(report) !== AI_ASSESSMENT_OUTCOMES.CORROBORATED),
          ).length;
          const routeDepartment = departmentForCategory(incident.category);
          const currentStatus = reportStatus(representative);
          const statusView = SIMPLE_STATUS[currentStatus] || SIMPLE_STATUS.received;
          const actionLabel = currentStatus === "received"
            ? "Review this incident"
            : currentStatus === "assigned"
              ? "Open contact steps"
              : currentStatus === "in_progress"
                ? "Open incident"
                : "View incident";
          const incidentLocationInfo = parseReportLocation(incident.location);
          const representativeMl = mlPhotoView(representative);
          const mlDetectedCategories = [...new Set(
            incident.reports.map(aiCategoryOf).filter(Boolean),
          )];
          const incidentMlTone = incident.hasMismatch || exceptionCount > 0
            ? "border-amber-300 bg-amber-50 text-amber-900 dark:border-amber-800 dark:bg-amber-900/20 dark:text-amber-200"
            : representativeMl.tone;
          const incidentBorder = incident.state === "Resolved"
            ? "border-green-300 dark:border-green-900"
            : currentStatus === "in_progress"
              ? "border-blue-400 dark:border-blue-800"
              : currentStatus === "assigned"
                ? "border-amber-400 dark:border-amber-800"
                : reportStream === "emergency"
                  ? "border-red-400 dark:border-red-800"
                  : "border-gray-200 dark:border-gray-700";
          return (
            <article key={incident.id} className={`overflow-hidden rounded-lg border border-l-4 bg-white shadow-sm dark:bg-gray-800 ${incidentBorder}`}>
              <div className="p-3">
                <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <h3 className="text-base font-bold text-gray-900 dark:text-white">{incident.category}</h3>
                      {incident.severity === "High" && (
                        <span className="rounded bg-red-700 px-2 py-0.5 text-[11px] font-bold text-white">High</span>
                      )}
                      <span className={`rounded px-2 py-0.5 text-[11px] font-bold ${statusView.tone}`}>
                        {statusView.label}
                      </span>
                    </div>
                    <p className="mt-1 truncate text-sm text-gray-700 dark:text-gray-200" title={incidentLocationInfo.display}>{incidentLocationInfo.display}</p>
                    <div className="mt-1.5 flex flex-wrap gap-x-3 gap-y-1 text-xs text-gray-500 dark:text-gray-400">
                      <span>{incident.reports.length} {incident.reports.length === 1 ? "report" : "reports"}</span>
                      <span>Latest: {formatDateTime(incident.latestTimestamp)}</span>
                    </div>
                    {!isCommunityConcern(representative) && (
                    <div className={`mt-2 rounded-md border px-2.5 py-2 text-xs ${incidentMlTone}`}>
                      <span className="font-bold">ML photo result: </span>
                      {incident.reports.length === 1 ? (
                        <span>{representativeMl.label}</span>
                      ) : (
                        <span>
                          {corroboratedCount} support {incident.category}; {exceptionCount} need review
                          {incident.hasMismatch && mlDetectedCategories.length > 0
                            ? ` · possible ${mlDetectedCategories.join(", ")}`
                            : ""}
                        </span>
                      )}
                    </div>
                    )}
                  </div>

                  <div className="grid shrink-0 grid-cols-2 gap-2 sm:w-44 sm:grid-cols-1">
                    <button
                      type="button"
                      disabled={savingId !== null}
                      onClick={() => openReport(representative)}
                      className={`min-h-9 rounded-md px-3 py-1.5 text-sm font-semibold text-white disabled:opacity-50 ${
                        currentStatus === "assigned" ? "bg-blue-700 hover:bg-blue-800" : "bg-purple-700 hover:bg-purple-800"
                      }`}
                    >
                      {actionLabel}
                    </button>

                    <button
                      type="button"
                      onClick={() => setExpandedIncidentId(expanded ? null : incident.id)}
                      className="min-h-9 rounded-md border border-gray-300 px-3 py-1.5 text-sm font-semibold text-gray-700 hover:bg-gray-100 dark:text-gray-200 dark:hover:bg-gray-700"
                    >
                      {expanded ? "Hide details" : "More details"}
                    </button>
                  </div>
                </div>
              </div>

              {expanded && (
                <div className="border-t bg-gray-50 p-3 dark:border-gray-700 dark:bg-gray-900/30">
                  <div className="mb-3 grid gap-2 text-sm text-gray-700 sm:grid-cols-2 dark:text-gray-200">
                    <p><strong>First report:</strong> {formatDateTime(incident.firstTimestamp)}</p>
                    <p><strong>Handling team:</strong> {routeDepartment}</p>
                    <p><strong>Reported by:</strong> {visibleReporterNames || "Unknown resident"}{remainingReporterCount > 0 ? ` and ${remainingReporterCount} more` : ""}</p>
                    {!isCommunityConcern(representative) && (
                      <p><strong>ML photo check:</strong> supported {corroboratedCount} {corroboratedCount === 1 ? "report" : "reports"}; {exceptionCount} need review</p>
                    )}
                  </div>
                  <p className="mb-2 font-semibold text-gray-700 dark:text-gray-200">Individual reports</p>
                  <div className="grid gap-2 md:grid-cols-2">
                    {incident.reports.map((report, index) => (
                      <button
                        key={report.id}
                        type="button"
                        onClick={() => openReport(report)}
                        className="min-h-16 rounded-lg border bg-white p-3 text-left hover:border-purple-500 dark:border-gray-700 dark:bg-gray-800"
                      >
                        <span className="font-bold text-gray-800 dark:text-white">Report {index + 1} - {residentName(report)}</span>
                        <span className="mt-1 block truncate text-sm text-gray-600 dark:text-gray-300">{report.description || "No description"}</span>
                        <span className="mt-1 block text-xs text-gray-500">{formatDateTime(report.created_at)}</span>
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </article>
          );
        })}

        {totalPages > 1 && (
          <div className="flex items-center justify-between border-t pt-3 dark:border-gray-700">
            <button type="button" disabled={page === 0 || loading} onClick={() => setPage((current) => Math.max(0, current - 1))} className="rounded-lg border px-3 py-2 text-sm font-semibold disabled:opacity-40 dark:border-gray-600">Previous</button>
            <span className="text-sm text-gray-500">Page {Math.min(page + 1, totalPages)} of {totalPages}</span>
            <button type="button" disabled={page + 1 >= totalPages || loading} onClick={() => setPage((current) => current + 1)} className="rounded-lg border px-3 py-2 text-sm font-semibold disabled:opacity-40 dark:border-gray-600">Next</button>
          </div>
        )}
      </section>

      {/* Individual reports stay available as evidence, but are hidden by default. */}
      <div className={`${individualReportsOpen ? "block" : "hidden"} bg-white dark:bg-gray-800 rounded-xl shadow-sm overflow-hidden border dark:border-gray-700`}>
        <div className="flex flex-wrap items-center justify-between gap-3 border-b px-4 py-3 text-sm text-gray-600 dark:border-gray-700 dark:text-gray-300">
          <span>
            {resultCount === 0
              ? "No reports"
              : `Showing ${page * PAGE_SIZE + 1}-${Math.min((page + 1) * PAGE_SIZE, resultCount)} of ${resultCount}`}
          </span>
          <span className="text-xs text-gray-400">
            {serverFiltering ? "Server-paginated" : "Local preview mode"}
          </span>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead className="bg-gray-50 dark:bg-gray-900">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Report Details
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Classification
                </th>
                <th
                  className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider"
                  title="AI-suggested severity — requires human confirmation, not a final determination"
                >
                  Severity ⓘ
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Status
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
                  <td colSpan={6} className="px-6 py-8 text-center text-gray-500 dark:text-gray-400">
                    Loading reports…
                  </td>
                </tr>
              )}
              {!loading && visibleReports.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-6 py-8 text-center text-gray-500 dark:text-gray-400">
                    No reports match this view.
                  </td>
                </tr>
              )}
              {visibleReports.map((report, index) => (
                <Fragment key={report.id}>
                  {index === firstDoneIndex && index > 0 && (
                    <tr>
                      <td
                        colSpan={6}
                        className="px-6 py-2 bg-gray-100 dark:bg-gray-900 text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400"
                      >
                        Resolved / Rejected
                      </td>
                    </tr>
                  )}
                  <tr
                    className="hover:bg-gray-50 dark:hover:bg-gray-700/50 cursor-pointer"
                    onClick={() => openReport(report)}
                  >
                  <td className="px-6 py-4">
                    <div>
                      <div className="font-medium text-gray-800 dark:text-white">
                        {report.subcategory || report.category}
                      </div>
                      <div className="text-sm text-gray-600 dark:text-gray-400">
                        by {residentName(report)}
                      </div>
                      <div className="text-xs text-gray-500 mt-1 truncate max-w-xs">
                        {parseReportLocation(report.location).display}
                      </div>
                      <div className="text-xs text-blue-600 dark:text-blue-400 mt-1">
                        📱 Submitted via mobile
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <div className="space-y-1">
                      <span className="inline-flex items-center rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-800 dark:bg-gray-900/30 dark:text-gray-300">
                        {effectiveCategoryOf(report) || "Unclassified"}
                      </span>
                      <p className="text-xs text-gray-500 dark:text-gray-400">
                        {classificationSource(report)}
                      </p>
                      {aiAssessmentOutcome(report) === AI_ASSESSMENT_OUTCOMES.CORROBORATED && (
                        <span className="inline-flex rounded bg-green-100 px-1.5 py-0.5 text-[11px] font-semibold text-green-800 dark:bg-green-900/30 dark:text-green-300">AI corroborated</span>
                      )}
                      {aiAssessmentOutcome(report) === AI_ASSESSMENT_OUTCOMES.MISMATCH && (
                        <span className="inline-flex rounded bg-amber-100 px-1.5 py-0.5 text-[11px] font-semibold text-amber-800 dark:bg-amber-900/30 dark:text-amber-300">Classification mismatch</span>
                      )}
                      {aiAssessmentOutcome(report) === AI_ASSESSMENT_OUTCOMES.LEARNING_MODE && (
                        <span className="inline-flex rounded bg-violet-100 px-1.5 py-0.5 text-[11px] font-semibold text-violet-800 dark:bg-violet-900/30 dark:text-violet-300">AI learning mode</span>
                      )}
                      {aiAssessmentOutcome(report) === AI_ASSESSMENT_OUTCOMES.MANUAL_REVIEW && (
                        <div className="flex flex-wrap gap-1">
                          {aiCategoryOf(report) && (
                            <span className="inline-flex rounded bg-violet-100 px-1.5 py-0.5 text-[11px] font-semibold text-violet-900 dark:bg-violet-900/30 dark:text-violet-200">
                              {aiCategoryOf(report) === reportedCategoryOf(report)
                                ? `AI photo matches: ${aiCategoryOf(report)}`
                                : `AI photo suggests: ${aiCategoryOf(report)}`}
                            </span>
                          )}
                          <span className="inline-flex rounded bg-red-100 px-1.5 py-0.5 text-[11px] font-semibold text-red-800 dark:bg-red-900/30 dark:text-red-300">Admin verification required</span>
                        </div>
                      )}
                      {aiAssessmentOutcome(report) === AI_ASSESSMENT_OUTCOMES.NOT_APPLICABLE && (
                        <span className="inline-flex rounded bg-blue-100 px-1.5 py-0.5 text-[11px] font-semibold text-blue-800 dark:bg-blue-900/30 dark:text-blue-300">Barangay review</span>
                      )}
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    {report.severity ? (
                      <span
                        className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                          severityColors[report.severity] || severityColors.Low
                        }`}
                      >
                        {report.severity}
                      </span>
                    ) : (
                      <span className="text-xs text-gray-400">—</span>
                    )}
                    <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                      {verificationOf(report) === "verified" ? "Admin confirmed" : "Awaiting confirmation"}
                    </p>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`mb-2 inline-flex rounded-full px-2.5 py-1 text-xs font-semibold ${verificationColors[verificationOf(report)] || verificationColors.pending}`}>
                      {verificationLabel(report)}
                    </span>
                    <span className={`inline-flex rounded-full px-2.5 py-1 text-xs font-semibold ${statusColors[reportStatus(report)] || statusColors.received}`}>
                      {reportStatus(report) === "rejected" ? "Rejected" : statusLabel(reportStatus(report))}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-600 dark:text-gray-400">
                    {formatDate(report.created_at)}
                  </td>
                  <td className="px-6 py-4 text-sm font-medium space-x-2">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        openReport(report);
                      }}
                      className="text-blue-600 dark:text-blue-400 hover:text-blue-900 dark:hover:text-blue-300"
                    >
                      View
                    </button>
                  </td>
                  </tr>
                </Fragment>
              ))}
            </tbody>
          </table>
        </div>
        <div className="flex items-center justify-between border-t px-4 py-3 dark:border-gray-700">
          <button
            type="button"
            disabled={page === 0 || loading}
            onClick={() => setPage((current) => Math.max(0, current - 1))}
            className="rounded-lg border px-3 py-2 text-sm font-semibold disabled:cursor-not-allowed disabled:opacity-40 dark:border-gray-600"
          >
            Previous
          </button>
          <span className="text-sm text-gray-500 dark:text-gray-400">
            Page {Math.min(page + 1, totalPages)} of {totalPages}
          </span>
          <button
            type="button"
            disabled={page + 1 >= totalPages || loading}
            onClick={() => setPage((current) => current + 1)}
            className="rounded-lg border px-3 py-2 text-sm font-semibold disabled:cursor-not-allowed disabled:opacity-40 dark:border-gray-600"
          >
            Next
          </button>
        </div>
      </div>

      {/* Right-side review drawer keeps the queue visible behind the report. */}
      {selectedReport && (
        <div
          className="fixed inset-0 z-50 flex justify-end bg-black/50"
          onMouseDown={closeReport}
        >
          <div
            className="h-full w-full max-w-2xl overflow-y-auto bg-white shadow-2xl dark:bg-gray-800"
            onMouseDown={(event) => event.stopPropagation()}
          >
            <div className="p-4">
              <div className="mb-3 flex items-start justify-between">
                <div>
                  <h3 className="text-lg font-bold text-gray-800 dark:text-white">
                    Incident brief
                  </h3>
                  <p className="text-gray-600 dark:text-gray-400">
                    Report #{selectedReport.id?.toString().slice(0, 8)} · {formatDate(selectedReport.created_at)}
                  </p>
                </div>
                <button
                  onClick={closeReport}
                  aria-label="Close report"
                  className="flex h-10 w-10 items-center justify-center rounded-lg border border-gray-300 text-xl text-gray-700 hover:bg-gray-100 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-700"
                >
                  ✕
                </button>
              </div>

              <div className="space-y-4">
                <section className="rounded-xl border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
                  <div className="flex flex-wrap items-start justify-between gap-3 border-b border-gray-200 pb-3 dark:border-gray-700">
                    <div>
                       <h4 className="text-lg font-bold text-gray-900 dark:text-white">{selectedCategory || "Unclassified report"}</h4>
                      <p className="mt-1 text-sm text-gray-600 dark:text-gray-300">{workflowLabel(selectedReport)}</p>
                    </div>
                    {(selectedReport.severity || selectedReport.ai_suggested_severity || selectedIncident?.severity) && (
                      <span className={`rounded-md px-2.5 py-1 text-sm font-semibold ${
                        (selectedReport.severity || selectedReport.ai_suggested_severity || selectedIncident?.severity) === "High"
                          ? "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-200"
                          : "bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-200"
                      }`}>
                        {selectedReport.severity || selectedReport.ai_suggested_severity || selectedIncident?.severity} priority
                      </span>
                    )}
                  </div>

                  {selectedMlView && !isCommunityConcern(selectedReport) && (
                    <div className={`mt-3 rounded-lg border px-3 py-2.5 ${selectedMlView.tone}`}>
                      <div className="flex flex-wrap items-baseline gap-x-2 gap-y-1">
                        <span className="text-xs font-bold uppercase tracking-wide">ML photo result</span>
                        <strong className="text-sm">{selectedMlView.label}</strong>
                      </div>
                      <p className="mt-1 text-xs leading-relaxed">{selectedMlView.detail}</p>
                    </div>
                  )}

                  <div className="mt-3 grid gap-3 md:grid-cols-[minmax(0,1fr)_210px]">
                    <dl className="grid content-start gap-2.5 text-sm">
                      <div className="grid grid-cols-[88px_1fr] gap-3">
                        <dt className="font-semibold text-gray-500 dark:text-gray-400">Time</dt>
                        <dd className="text-gray-900 dark:text-white">{formatDateTime(selectedIncident?.latestTimestamp || selectedReport.created_at)}</dd>
                      </div>
                      {selectedLocationInfo.landmark && (
                        <div className="grid grid-cols-[88px_1fr] gap-3">
                          <dt className="font-semibold text-gray-500 dark:text-gray-400">Landmark</dt>
                          <dd className="break-words font-medium text-gray-900 dark:text-white">Near {selectedLocationInfo.landmark}</dd>
                        </div>
                      )}
                      <div className="grid grid-cols-[88px_1fr] gap-3">
                        <dt className="font-semibold text-gray-500 dark:text-gray-400">Address</dt>
                        <dd className="break-words font-medium text-gray-900 dark:text-white">{selectedLocationInfo.address || (selectedLocationInfo.coordinates ? "Address unavailable" : "Not provided")}</dd>
                      </div>
                      {selectedLocationInfo.coordinates && (
                        <div className="grid grid-cols-[88px_1fr] gap-3">
                          <dt className="font-semibold text-gray-500 dark:text-gray-400">GPS</dt>
                          <dd className="break-words text-gray-600 dark:text-gray-300">{selectedLocationInfo.coordinates}</dd>
                        </div>
                      )}
                      <div className="grid grid-cols-[88px_1fr] gap-3">
                        <dt className="font-semibold text-gray-500 dark:text-gray-400">Reports</dt>
                        <dd className="text-gray-900 dark:text-white">
                          {selectedIncident?.reports.length || 1} {(selectedIncident?.reports.length || 1) === 1 ? "resident report" : "resident reports"}
                        </dd>
                      </div>
                      <div className="grid grid-cols-[88px_1fr] gap-3">
                        <dt className="font-semibold text-gray-500 dark:text-gray-400">Reporter</dt>
                        <dd className="text-gray-900 dark:text-white">
                          {residentName(selectedReport)}
                          {selectedReporterPhone && <span className="block text-gray-600 dark:text-gray-300">{selectedReporterPhone}</span>}
                        </dd>
                      </div>
                      <div className="border-t border-gray-200 pt-3 dark:border-gray-700">
                        <dt className="font-semibold text-gray-500 dark:text-gray-400">What happened</dt>
                         <dd className="mt-1 whitespace-pre-wrap text-sm leading-relaxed text-gray-900 dark:text-white">
                          {selectedReport.description || "No description provided."}
                        </dd>
                      </div>
                    </dl>

                    <div>
                      {selectedMainPhoto ? (
                        <a href={selectedMainPhoto} target="_blank" rel="noreferrer" className="block">
                          <img
                            src={selectedMainPhoto}
                            alt="Main incident evidence"
                            className="aspect-[4/3] w-full rounded-lg border border-gray-200 object-cover dark:border-gray-700"
                          />
                        </a>
                      ) : (
                        <div className="flex aspect-[4/3] items-center justify-center rounded-lg border border-dashed border-gray-300 bg-gray-50 px-3 text-center text-sm text-gray-500 dark:border-gray-600 dark:bg-gray-900/40 dark:text-gray-400">
                          No photo attached
                        </div>
                      )}
                      {selectedIncidentPhotos.length > 1 && (
                        <div className="mt-2 flex gap-2 overflow-x-auto">
                          {selectedIncidentPhotos.slice(1, 4).map((url, index) => (
                            <a key={url} href={url} target="_blank" rel="noreferrer" className="shrink-0">
                              <img src={url} alt={`Additional incident evidence ${index + 2}`} className="h-12 w-12 rounded-md border border-gray-200 object-cover dark:border-gray-700" />
                            </a>
                          ))}
                          {selectedIncidentPhotos.length > 4 && (
                            <span className="flex h-12 min-w-12 items-center justify-center rounded-md bg-gray-100 px-2 text-xs font-semibold text-gray-600 dark:bg-gray-700 dark:text-gray-200">
                              +{selectedIncidentPhotos.length - 4}
                            </span>
                          )}
                        </div>
                      )}
                      {selectedLocationInfo.mapQuery && (
                        <a
                          href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(selectedLocationInfo.mapQuery)}`}
                          target="_blank"
                          rel="noreferrer"
                          className="mt-3 block min-h-10 rounded-lg border border-gray-300 px-3 py-2 text-center text-sm font-semibold text-gray-800 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-100 dark:hover:bg-gray-700"
                        >
                          View location on map
                        </a>
                      )}
                    </div>
                  </div>
                </section>

                {/* Contact steps stay directly below the brief so the
                    admin can read the facts and act without scrolling. */}
                {isEmergencyReport(selectedReport) && (
                  <section className="rounded-xl border border-red-300 bg-red-50 p-4 dark:border-red-900 dark:bg-red-950/20">
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div>
                        <h4 className="text-lg font-bold text-red-800 dark:text-red-200">Barangay contact steps</h4>
                        <p className="mt-1 text-base font-bold text-gray-900 dark:text-white">Status: {workflowLabel(selectedReport)}</p>
                        <p className="mt-1 text-sm text-gray-700 dark:text-gray-200">
                          Copy the number, call using the barangay phone or landline, then record the result only after someone answers and accepts the incident details.
                        </p>
                      </div>
                      {reportStatus(selectedReport) === "received" && (
                        <span className="rounded-md bg-red-700 px-3 py-1.5 text-sm font-semibold text-white">Needs review</span>
                      )}
                    </div>

                    <div className="mt-4 grid gap-2.5 sm:grid-cols-2">
                      {selectedEmergencyContact && (
                        <div className="rounded-lg border border-red-200 bg-white p-3 dark:border-red-900 dark:bg-gray-900 sm:col-span-2">
                          <p className="text-xs font-bold uppercase tracking-wide text-gray-500 dark:text-gray-400">Call using the barangay phone</p>
                          <div className="mt-1 flex flex-wrap items-center justify-between gap-2">
                            <div>
                              <p className="font-bold text-gray-900 dark:text-white">{selectedEmergencyContact.name}</p>
                              <p className="text-lg font-bold text-red-800 dark:text-red-200">{selectedEmergencyContact.number}</p>
                            </div>
                          <button
                            type="button"
                            onClick={() => copyPhoneNumber(selectedEmergencyContact.number)}
                              className="min-h-10 rounded-lg bg-red-700 px-4 py-2 text-sm font-semibold text-white hover:bg-red-800"
                          >
                            {copiedNumber === selectedEmergencyContact.number ? "Number copied" : `Copy ${selectedEmergencyContact.number}`}
                          </button>
                          </div>
                        </div>
                      )}
                      <button
                        type="button"
                        onClick={() => copyPhoneNumber("911")}
                        className="min-h-11 rounded-lg border border-red-400 px-4 py-2.5 text-center text-sm font-semibold text-red-800 hover:bg-red-100 dark:border-red-800 dark:text-red-200"
                      >
                        {copiedNumber === "911" ? "911 copied" : "Copy 911"}
                      </button>
                      {selectedReporterPhone && (
                        <button
                          type="button"
                          onClick={() => copyPhoneNumber(selectedReporterPhone)}
                          className="min-h-11 rounded-lg border border-blue-300 px-4 py-2.5 text-center text-base font-semibold text-blue-800 hover:bg-blue-50 dark:border-blue-800 dark:text-blue-200"
                        >
                          {copiedNumber === selectedReporterPhone ? "Reporter number copied" : `Copy reporter: ${selectedReporterPhone}`}
                        </button>
                      )}
                      {selectedLocationInfo.mapQuery && (
                        <a
                          href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(selectedLocationInfo.mapQuery)}`}
                          target="_blank"
                          rel="noreferrer"
                          className="min-h-11 rounded-lg border border-gray-300 px-4 py-2.5 text-center text-base font-semibold text-gray-800 hover:bg-white dark:border-gray-600 dark:text-gray-100"
                        >
                          View map
                        </a>
                      )}
                      {reportStatus(selectedReport) === "assigned" && canProgress(selectedReport) && (
                        <button
                          type="button"
                          disabled={savingId !== null}
                          onClick={() => handleStatusChange(selectedReport.id, "in_progress")}
                          className="min-h-11 rounded-lg bg-blue-700 px-4 py-2.5 text-base font-semibold text-white hover:bg-blue-800 disabled:opacity-50 sm:col-span-2"
                        >
                          Record: assistance contacted
                        </button>
                      )}
                    </div>

                    {!selectedEmergencyContact && ["Fire", "Medical Emergency"].includes(selectedCategory) && (
                      <p className="mt-3 rounded-lg bg-amber-100 p-3 text-sm font-semibold text-amber-900 dark:bg-amber-900/30 dark:text-amber-200">
                        The local {selectedCategory === "Fire" ? "fire" : "medical"} number is not set. Copy 911 and call using the barangay phone, then add a verified local number in Emergency Hotlines.
                      </p>
                    )}
                  </section>
                )}

                <ReportVerificationPanel key={selectedReport.id + ":" + selectedReport.updated_at}
                  report={selectedReport} onReview={handleReview} onMessage={handleSendCitizenMessage} busy={savingId !== null} />

                <div className="pt-4 border-t dark:border-gray-700">
                  <h4 className="font-medium text-gray-800 dark:text-white mb-2">
                    Update barangay case status
                  </h4>
                  <p className="mb-2 text-xs text-gray-500 dark:text-gray-400">
                    This records barangay handling only. It does not contact or dispatch an emergency service.
                  </p>
                  <div className="relative inline-block min-w-48">
                  <select
                    aria-label="Update report status"
                    disabled={savingId !== null || !canProgress(selectedReport)}
                    value={selectedReport.status || "received"}
                    onChange={(e) => handleStatusChange(selectedReport.id, e.target.value)}
                    className="w-full cursor-pointer appearance-none pl-3 pr-10 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white focus:ring-2 focus:ring-purple-500 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    {STATUS_OPTIONS.map((s) => (
                      <option key={s} value={s}>
                        {statusLabel(s)}
                      </option>
                    ))}
                  </select>
                    <svg aria-hidden="true" viewBox="0 0 20 20" fill="none"
                      className="pointer-events-none absolute right-3 top-1/2 h-5 w-5 -translate-y-1/2 text-gray-600 dark:text-gray-300">
                      <path d="m5 7.5 5 5 5-5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                    </svg>
                  </div>
                </div>

                <div className="flex justify-end space-x-3 pt-4 border-t dark:border-gray-700">
                  <button
                    onClick={closeReport}
                    className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-300"
                  >
                    Close
                  </button>
                  <button
                    disabled={savingId !== null || !canProgress(selectedReport)}
                    onClick={() => {
                      handleStatusChange(selectedReport.id, "resolved");
                    }}
                    className="px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg"
                  >
                    Mark Case as Resolved
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

    </div>
  );
};

export default CitizenReportsPage;
