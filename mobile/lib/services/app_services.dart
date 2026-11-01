import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:may_laud/providers/content_providers.dart';
import 'package:may_laud/services/supabase_service.dart';
import 'package:may_laud/services/ai_triage_service.dart';

/// A picked photo's raw bytes plus a filename, used by
/// CitizenReportService.submitReport() and AiTriageService.verifyImage().
/// Bytes rather than a `dart:io File` — `File` doesn't exist on Flutter
/// web, and this keeps the whole report-photo pipeline working on every
/// platform the app targets, not just mobile.
class ReportPhoto {
  final Uint8List bytes;
  final String filename;
  const ReportPhoto({required this.bytes, required this.filename});
}

class ReportPhotoAssessment {
  final int checkedPhotoCount;
  final String reportedCategory;
  final String? suggestedCategory;
  final String? acceptedCategory;
  final bool hasTrustedMatch;
  final bool hasTrustedMismatch;
  final bool hasConflictingResults;
  final bool aiUnavailable;
  final bool forceManualReview;

  const ReportPhotoAssessment({
    required this.checkedPhotoCount,
    required this.reportedCategory,
    this.suggestedCategory,
    this.acceptedCategory,
    required this.hasTrustedMatch,
    required this.hasTrustedMismatch,
    required this.hasConflictingResults,
    required this.aiUnavailable,
    this.forceManualReview = false,
  });

  bool get requiresManualReview =>
      aiUnavailable ||
      forceManualReview ||
      !hasTrustedMatch ||
      hasTrustedMismatch ||
      hasConflictingResults;

  bool get hasTrustedEvidence => acceptedCategory != null || hasTrustedMismatch;
}

class ReportCategorySuggestion {
  final int checkedPhotoCount;
  final String? suggestedCategory;
  final double? suggestedConfidence;
  final int supportingPhotoCount;
  final bool hasConflictingResults;
  final bool aiUnavailable;
  final List<ImageVerificationResult> results;
  final bool contextAvailable;
  final String contextDecision;
  final String? contextSuggestedCategory;
  final String? contextSummary;
  final bool contextNeedsMorePhotos;
  final bool emergencyCallRecommended;

  const ReportCategorySuggestion({
    required this.checkedPhotoCount,
    this.suggestedCategory,
    this.suggestedConfidence,
    this.supportingPhotoCount = 0,
    required this.hasConflictingResults,
    required this.aiUnavailable,
    required this.results,
    this.contextAvailable = false,
    this.contextDecision = 'ml_only',
    this.contextSuggestedCategory,
    this.contextSummary,
    this.contextNeedsMorePhotos = false,
    this.emergencyCallRecommended = false,
  });

  bool get hasTrustedEvidence => suggestedCategory != null;

  bool get allPhotosRejectedForAutomaticCategory =>
      results.isNotEmpty &&
      results.every((result) =>
          !result.hasTrustedCategory && !result.hasGuardedMedicalEvidence);
}

/// A short, structured safety check for Medical Emergency / Road Accident.
///
/// The text severity model can misread short or misspelled reports and
/// negation such as "walang nasaktan". These answers therefore provide the
/// citizen-facing priority suggestion for this category. The barangay still
/// makes the official severity decision during review.
enum AccidentTriageDecision {
  injuryOrImmediateDanger,
  notSure,
  noInjuryRoadBlocked,
  noInjuryRoadClear,
}

extension AccidentTriageDecisionDetails on AccidentTriageDecision {
  String get suggestedSeverity {
    switch (this) {
      case AccidentTriageDecision.injuryOrImmediateDanger:
        return 'High';
      case AccidentTriageDecision.notSure:
      case AccidentTriageDecision.noInjuryRoadBlocked:
        return 'Medium';
      case AccidentTriageDecision.noInjuryRoadClear:
        return 'Low';
    }
  }

  String get summary {
    switch (this) {
      case AccidentTriageDecision.injuryOrImmediateDanger:
        return 'Citizen reports an injury or immediate danger.';
      case AccidentTriageDecision.notSure:
        return 'Citizen is not sure whether anyone is injured or in danger.';
      case AccidentTriageDecision.noInjuryRoadBlocked:
        return 'No injury reported, but the road is blocked or unsafe.';
      case AccidentTriageDecision.noInjuryRoadClear:
        return 'No injury reported and the road is clear.';
    }
  }

  String get reportNote =>
      'Accident safety check: $summary Suggested priority: $suggestedSeverity. '
      'Barangay verification required.';
}

/// Structured secondary evidence for a photo-supported Fire report.
enum FireTriageDecision {
  peopleOrStructuresInDanger,
  notSure,
  activeUncontrolledFire,
  controlledOrNoActiveDanger,
}

extension FireTriageDecisionDetails on FireTriageDecision {
  String get suggestedSeverity {
    switch (this) {
      case FireTriageDecision.peopleOrStructuresInDanger:
        return 'High';
      case FireTriageDecision.notSure:
      case FireTriageDecision.activeUncontrolledFire:
        return 'Medium';
      case FireTriageDecision.controlledOrNoActiveDanger:
        return 'Low';
    }
  }

  String get summary {
    switch (this) {
      case FireTriageDecision.peopleOrStructuresInDanger:
        return 'Citizen reports people or structures in immediate danger, or a spreading fire.';
      case FireTriageDecision.notSure:
        return 'Citizen is not sure whether the fire is spreading or threatening anyone.';
      case FireTriageDecision.activeUncontrolledFire:
        return 'Citizen reports an active, uncontrolled fire without a known immediate life threat.';
      case FireTriageDecision.controlledOrNoActiveDanger:
        return 'Citizen reports a controlled fire or no active danger.';
    }
  }

  String get reportNote =>
      'Fire safety check: $summary Suggested priority: $suggestedSeverity. '
      'Barangay verification required.';
}

/// Conservative acceptance policy for Medical Emergency / Road Accident.
/// A medium-confidence single image may be offered to the citizen as a
/// possible Medical/Road Accident report, but it is never selected without
/// explicit confirmation. When several views are attached, two independent
/// photos must support the same incident unless one view is already very
/// strong. Admin review remains mandatory after citizen confirmation.
class MedicalCategoryGuard {
  const MedicalCategoryGuard._();

  static List<ImageVerificationResult> supportingResults(
    List<ImageVerificationResult> results,
  ) =>
      results
          .where((result) => result.hasGuardedMedicalEvidence)
          .toList(growable: false);

  static bool qualifies(
    List<ImageVerificationResult> results, {
    required int attachedPhotoCount,
  }) {
    final supporting = supportingResults(results);
    if (attachedPhotoCount <= 1) {
      return supporting.length == 1;
    }
    return supporting.length >= 2 ||
        supporting.any((result) =>
            result.categoryConfidence >=
            ImageVerificationResult.medicalSinglePhotoConfidenceThreshold);
  }
}

class AnnouncementService {
  final Ref ref;
  AnnouncementService(this.ref);

  Future<List<Announcement>> fetchAnnouncements() async {
    await ref.read(announcementsProvider.notifier).fetchAnnouncements();
    return ref.read(announcementsProvider);
  }

  Future<void> markAsRead(String id) async =>
      ref.read(announcementsProvider.notifier).markAsRead(id);

  Future<void> markAllAsRead() async =>
      ref.read(announcementsProvider.notifier).markAllAsRead();

  Future<void> submitAnnouncement({
    required String title,
    required String description,
    required String category,
    String? imageUrl,
    bool isImportant = false,
  }) async {
    await SupabaseService.client.from('announcements').insert({
      'title': title,
      'description': description,
      'category': category,
      'image_url': imageUrl,
      'is_important': isImportant,
    });
    await fetchAnnouncements();
  }
}

class NotificationService {
  final Ref ref;
  NotificationService(this.ref);

  Future<List<AppNotification>> fetchNotifications() async {
    await ref.read(notificationsProvider.notifier).fetchNotifications();
    return ref.read(notificationsProvider);
  }

  Future<void> markAsRead(String id) async =>
      ref.read(notificationsProvider.notifier).markAsRead(id);

  Future<void> markAllAsRead() async =>
      ref.read(notificationsProvider.notifier).markAllAsRead();

  Future<void> deleteNotification(String id) async =>
      ref.read(notificationsProvider.notifier).deleteNotification(id);

  Future<void> sendNotification({
    required String title,
    required String message,
    required String type,
    String? targetUserId,
  }) async {
    final uid = targetUserId ?? SupabaseService.userId;
    if (uid == null) return;

    await SupabaseService.client.from('notifications').insert({
      'user_id': uid,
      'title': title,
      'message': message,
      'type': type,
    });
    await fetchNotifications();
  }
}

class HotlineService {
  Future<List<Map<String, dynamic>>> fetchHotlines() async {
    final rows = await SupabaseService.client
        .from('hotlines')
        .select()
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(rows as List);
  }
}

class DocumentService {
  Future<List<Map<String, dynamic>>> fetchDocumentTypes() async {
    return [
      {
        'id': '1',
        'name': 'Barangay Clearance',
        'description': 'Certificate of residency and good moral character',
        'processingTime': '1-2 days',
        'fee': '₱50.00',
        'requirements': ['Valid ID', 'Proof of residency'],
      },
      {
        'id': '2',
        'name': 'Business Permit',
        'description': 'License to operate a business in Milaor',
        'processingTime': '3-5 days',
        'fee': '₱500.00 - ₱5,000.00',
        'requirements': ['DTI/SEC registration', 'Proof of business address'],
      },
      {
        'id': '3',
        'name': 'Certificate of Indigency',
        'description': 'Proof of low-income status',
        'processingTime': '1 day',
        'fee': '₱20.00',
        'requirements': ['Valid ID', 'Proof of income'],
      },
      {
        'id': '4',
        'name': 'Police Clearance',
        'description': 'Certificate of no criminal record',
        'processingTime': '2-3 days',
        'fee': '₱100.00',
        'requirements': ['Valid ID', '2x2 photo', 'Barangay clearance'],
      },
      {
        'id': '5',
        'name': 'Building Permit',
        'description': 'Authorization for construction projects',
        'processingTime': '7-14 days',
        'fee': 'Based on project cost',
        'requirements': ['Land title', 'Building plans'],
      },
    ];
  }

  Future<Map<String, dynamic>> submitDocumentRequest({
    required String documentTypeId,
    required String purpose,
    required Map<String, dynamic> userInfo,
    List<String>? attachments,
  }) async {
    final uid = SupabaseService.userId;
    if (uid == null) throw Exception('Not logged in');

    final types = await fetchDocumentTypes();
    final docType = types.firstWhere(
      (t) => t['id'] == documentTypeId,
      orElse: () => {'name': 'Document', 'fee': '—'},
    );

    final row = await SupabaseService.client
        .from('document_requests')
        .insert({
          'user_id': uid,
          'document_type': docType['name'],
          'purpose': purpose,
          'fee': docType['fee'],
        })
        .select()
        .single();

    return {
      'requestId': row['id'],
      'status': row['status'],
      'submittedAt': row['created_at'],
      'documentType': row['document_type'],
      'message':
          'Your request has been submitted. You will be notified when it\'s ready.',
    };
  }

  Future<Map<String, dynamic>> checkRequestStatus(String requestId) async {
    final row = await SupabaseService.client
        .from('document_requests')
        .select()
        .eq('id', requestId)
        .single();

    return {
      'requestId': row['id'],
      'status': row['status'],
      'lastUpdated': row['created_at'],
      'message': _statusMessage(row['status'] as String),
    };
  }

  String _statusMessage(String status) {
    const map = {
      'pending': 'Your request is awaiting review.',
      'processing': 'Your document is being processed.',
      'ready': 'Your document is ready for pickup.',
      'completed': 'Document has been picked up.',
      'rejected': 'Request was rejected. Please resubmit.',
    };
    return map[status] ?? 'Status unknown.';
  }
}

class FloodAlertService {
  Future<Map<String, dynamic>> getCurrentAlert() async {
    final rows = await SupabaseService.client
        .from('flood_alerts')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1);

    if ((rows as List).isEmpty) {
      return {
        'level': 'Low',
        'affectedAreas': <String>[],
        'waterLevel': '—',
        'advice': 'No active alerts.',
        'isActive': false,
      };
    }

    final row = rows.first;
    return {
      'level': row['level'],
      'affectedAreas': List<String>.from(row['affected_areas'] ?? []),
      'waterLevel': row['water_level'] ?? '—',
      'advice': row['advice'] ?? '',
      'isActive': row['is_active'],
      'updateTime': row['created_at'],
    };
  }
}

class CitizenReportService {
  static const int maxAnalyzedPhotos = 3;
  static const double _incidentAcceptanceThreshold = 90.0;

  /// Runs the admin-only text severity model after the citizen has finished
  /// writing the report. The screen may use this result to decide whether a
  /// short-message fallback question is necessary, without displaying the
  /// severity to the citizen.
  Future<SeverityResult?> classifyReportSeverity({
    required String description,
    required String reportType,
    required String category,
  }) =>
      AiTriageService().classifySeverity(
        description,
        reportType: reportType,
        category: category,
      );

  // Combine corroborating photos conservatively. The strongest photo keeps
  // its full score; every additional matching photo can only reduce half of
  // the remaining uncertainty. This rewards independent evidence without
  // simply adding percentages or allowing several weak guesses to reach 100%.
  double _combinedIncidentConfidence(List<double> confidences) {
    if (confidences.isEmpty) return 0;
    final ordered = List<double>.of(confidences)
      ..sort((a, b) => b.compareTo(a));
    var combined = ordered.first.clamp(0.0, 100.0);
    for (final confidence in ordered.skip(1)) {
      final support = confidence.clamp(0.0, 100.0) / 100.0;
      combined += (100.0 - combined) * support * 0.5;
    }
    return combined.clamp(0.0, 99.9);
  }

  /// Analyzes the photos before the citizen chooses a category. The model's
  /// result is only a suggestion: the citizen can correct it, and the admin
  /// still receives both values for verification.
  Future<ReportCategorySuggestion> suggestReportCategory({
    required List<ReportPhoto> photos,
  }) async {
    final checkedPhotos = photos.take(maxAnalyzedPhotos).toList();
    if (checkedPhotos.isEmpty) {
      return const ReportCategorySuggestion(
        checkedPhotoCount: 0,
        hasConflictingResults: false,
        aiUnavailable: false,
        results: <ImageVerificationResult>[],
      );
    }

    final ai = AiTriageService();
    final results = <ImageVerificationResult>[];

    // Prefer one incident-level request so all attached views can be checked
    // together for context (for example, a normal river versus actual road
    // inundation). The endpoint still returns every local ML result. If it is
    // not deployed yet, the legacy per-photo flow below remains available.
    final incident = await ai.verifyIncident(
      [for (final photo in checkedPhotos) photo.bytes],
      filenames: [for (final photo in checkedPhotos) photo.filename],
    );
    if (incident != null) {
      results.addAll(incident.photoResults);
    }

    if (incident?.context.available == true) {
      final context = incident!.context;
      var autoCategory =
          incident.autoSelectAllowed ? incident.suggestedCategory : null;
      if (autoCategory == 'Medical Emergency' &&
          !MedicalCategoryGuard.qualifies(
            results,
            attachedPhotoCount: checkedPhotos.length,
          )) {
        autoCategory = null;
      }
      final supportingCount = autoCategory == null
          ? 0
          : autoCategory == 'Medical Emergency'
              ? MedicalCategoryGuard.supportingResults(results).length
              : results
                  .where((result) =>
                      result.isValidPhoto &&
                      result.detectedCategory == autoCategory)
                  .length;
      return ReportCategorySuggestion(
        checkedPhotoCount: checkedPhotos.length,
        suggestedCategory: autoCategory,
        supportingPhotoCount: supportingCount,
        hasConflictingResults: incident.decision == 'possible_emergency',
        aiUnavailable: false,
        results: List<ImageVerificationResult>.unmodifiable(results),
        contextAvailable: true,
        contextDecision: incident.decision,
        contextSuggestedCategory: incident.suggestedCategory,
        contextSummary:
            incident.reason.isNotEmpty ? incident.reason : context.summary,
        contextNeedsMorePhotos: context.needsMorePhotos,
        emergencyCallRecommended: context.emergencyCallRecommended,
      );
    }

    // Keep these sequential so several attachments do not overload the free
    // inference service. Passing no reported category keeps the photo result
    // independent from the citizen's later choice.
    if (results.isEmpty) {
      for (final photo in checkedPhotos) {
        final result = await ai.verifyImage(
          photo.bytes,
          filename: photo.filename,
          reportedCategory: null,
        );
        if (result != null) results.add(result);
      }
    }

    // Never aggregate the classifier's closed-set raw guess. Fire/Flood still
    // require the calibrated legacy validity gate. Medical/Road Accident uses
    // its specialized detector, then the stricter MedicalCategoryGuard below.
    final evidenceByCategory = <String, List<double>>{};
    for (final result in results) {
      final category = result.detectedCategory;
      final contributes = result.hasTrustedCategory ||
          (category == 'Medical Emergency' && result.hasGuardedMedicalEvidence);
      if (category == null || !contributes) {
        continue;
      }
      evidenceByCategory
          .putIfAbsent(category, () => <double>[])
          .add(result.categoryConfidence);
    }

    final combinedByCategory = <String, double>{
      for (final entry in evidenceByCategory.entries)
        entry.key: _combinedIncidentConfidence(entry.value),
    };
    final hasConflicts = evidenceByCategory.length > 1;
    String? suggestedCategory;
    double? suggestedConfidence;
    var supportingPhotoCount = 0;

    if (!hasConflicts && combinedByCategory.length == 1) {
      final entry = combinedByCategory.entries.first;
      final qualifies = entry.key == 'Medical Emergency'
          ? MedicalCategoryGuard.qualifies(
              results,
              attachedPhotoCount: checkedPhotos.length,
            )
          : entry.value >= _incidentAcceptanceThreshold;
      if (qualifies) {
        suggestedCategory = entry.key;
        suggestedConfidence = entry.value;
        supportingPhotoCount = evidenceByCategory[entry.key]!.length;
      }
    }

    return ReportCategorySuggestion(
      checkedPhotoCount: checkedPhotos.length,
      suggestedCategory: suggestedCategory,
      suggestedConfidence: suggestedConfidence,
      supportingPhotoCount: supportingPhotoCount,
      hasConflictingResults: hasConflicts,
      aiUnavailable: results.length != checkedPhotos.length,
      results: List<ImageVerificationResult>.unmodifiable(results),
      contextAvailable: false,
      contextDecision: incident?.decision ?? 'ml_only',
      contextSummary: incident?.reason,
    );
  }

  ReportPhotoAssessment assessmentFromSuggestion({
    required ReportCategorySuggestion suggestion,
    required String category,
  }) {
    final normalizedReported = category.trim().toLowerCase();
    final trustedCategory = suggestion.suggestedCategory;
    final reviewCategory =
        trustedCategory ?? suggestion.contextSuggestedCategory;
    final hasMatch = trustedCategory != null &&
        trustedCategory.trim().toLowerCase() == normalizedReported;
    final hasMismatch = trustedCategory != null && !hasMatch;
    final hasConflicts = suggestion.hasConflictingResults;
    final acceptedCategory = hasMatch && !hasConflicts ? trustedCategory : null;

    return ReportPhotoAssessment(
      checkedPhotoCount: suggestion.checkedPhotoCount,
      reportedCategory: category,
      suggestedCategory: reviewCategory,
      acceptedCategory: acceptedCategory,
      hasTrustedMatch: hasMatch,
      hasTrustedMismatch: hasMismatch,
      hasConflictingResults: hasConflicts,
      aiUnavailable: suggestion.aiUnavailable,
      // The specialized Medical detector includes road crashes and bypasses
      // the old Fire/Flood validity model. Citizen confirmation makes it a
      // usable report category, but an admin must still verify it officially.
      forceManualReview: trustedCategory == 'Medical Emergency',
    );
  }

  Future<ReportPhotoAssessment?> assessReportPhotos({
    required List<ReportPhoto> photos,
    required String category,
    required String? reportType,
  }) async {
    if (reportType == 'Minor Concern' || photos.isEmpty) return null;

    final suggestion = await suggestReportCategory(photos: photos);
    return assessmentFromSuggestion(
      suggestion: suggestion,
      category: category,
    );
  }

  Future<List<Map<String, dynamic>>> fetchReportCategories() async {
    return [
      {
        'id': '1',
        'name': 'Infrastructure',
        'icon': '🚧',
        'subcategories': [
          'Road Damage',
          'Bridge Issues',
          'Street Light',
          'Drainage Problems'
        ]
      },
      {
        'id': '2',
        'name': 'Sanitation',
        'icon': '🗑️',
        'subcategories': [
          'Garbage Collection',
          'Illegal Dumping',
          'Public Toilets'
        ]
      },
      {
        'id': '3',
        'name': 'Public Safety',
        'icon': '👮',
        'subcategories': [
          'Criminal Activity',
          'Traffic Violations',
          'Fire Hazards'
        ]
      },
      {
        'id': '4',
        'name': 'Environment',
        'icon': '🌳',
        'subcategories': ['Tree Maintenance', 'Flooding', 'Pollution']
      },
      {
        'id': '5',
        'name': 'Utilities',
        'icon': '⚡',
        'subcategories': ['Water Supply', 'Power Outage', 'Internet Issues']
      },
      {
        'id': '6',
        'name': 'Others',
        'icon': '📋',
        'subcategories': ['General Complaint', 'Suggestion', 'Other Concerns']
      },
    ];
  }

  // FIX — `category` is now the category's display name directly (e.g.
  // "Infrastructure"), not an id to look up. The old version took a
  // `categoryId` and matched it against fetchReportCategories()' ids
  // ('1'..'6'), but the caller (citizen_report_screen.dart) was actually
  // passing the category's *name*, which never matched any id — every
  // report silently got saved with category "Other" regardless of what
  // the resident picked. Passing the name straight through avoids that
  // indirection entirely (the screen's own category list doesn't even
  // match fetchReportCategories()' set, so the id lookup was never going
  // to be reliable).
  // Classify submitted reports automatically and save findings for admins.
  Future<Map<String, dynamic>> submitReport({
    required String category,
    required String subcategory,
    required String description,
    required String location,
    List<ReportPhoto>? photoFiles,
    String? contactInfo,
    String? reportType,
    ReportPhotoAssessment? photoAssessment,
    AccidentTriageDecision? accidentTriageDecision,
    FireTriageDecision? fireTriageDecision,
    SeverityResult? preclassifiedSeverity,
    bool severityClassificationAttempted = false,
  }) async {
    final uid = SupabaseService.userId;
    if (uid == null) throw Exception('Not logged in');

    final photoUrls = <String>[];
    if (photoFiles != null) {
      for (int i = 0; i < photoFiles.length; i++) {
        final path = '$uid/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        // FIX — .upload() takes a `dart:io File`, which doesn't exist on
        // Flutter web at all ("Unsupported operation: _Namespace" the
        // moment a photo was attached). .uploadBinary() takes raw bytes
        // instead, which works on every platform.
        await SupabaseService.client.storage
            .from('report-photos')
            .uploadBinary(path, photoFiles[i].bytes);
        final url = SupabaseService.client.storage
            .from('report-photos')
            .getPublicUrl(path);
        photoUrls.add(url);
      }
    }

    // AI TRIAGE — severity classification + image verification. Both are
    // best-effort: a null result (backend down, network issue, etc.) just
    // leaves severity unassigned for admin review and skips unavailable
    // photo findings. AI failure must never reject a submission.
    final ai = AiTriageService();
    final severity = severityClassificationAttempted
        ? preclassifiedSeverity
        : await ai.classifySeverity(description,
            reportType: reportType, category: category);

    final assessment = photoAssessment ??
        await assessReportPhotos(
          photos: photoFiles ?? const <ReportPhoto>[],
          category: category,
          reportType: reportType,
        );

    // A structured accident answer is safer than the free-text model for
    // short messages and negation. Do not attach a fake confidence percentage
    // to this deterministic decision.
    final structuredSeverity = accidentTriageDecision?.suggestedSeverity ??
        fireTriageDecision?.suggestedSeverity;
    final structuredNote =
        accidentTriageDecision?.reportNote ?? fireTriageDecision?.reportNote;
    // Text ML is the normal decision for a sufficiently detailed message.
    // A structured answer exists only when the message was too short or
    // unclear, so in that case it becomes the fallback severity.
    final finalPriority = structuredSeverity ?? severity?.toPriorityLevel();
    final storedDescription = structuredNote == null
        ? description
        : '$description\n\n$structuredNote';
    // Keep a trusted independent suggestion even when it differs from the
    // citizen's category. The web admin uses that difference as a review
    // signal; it never replaces the citizen or official classification.
    final trustedImageSuggestion = assessment?.suggestedCategory;
    // An emergency submitted without usable photo evidence must remain in
    // the admin's manual-review queue. Routine concerns do not use the
    // four-class emergency image model.
    final requiresReview =
        assessment?.requiresManualReview ?? reportType == 'Emergency';

    final row = await SupabaseService.client
        .from('citizen_reports')
        .insert({
          'user_id': uid,
          'category': category,
          'subcategory': subcategory,
          'description': storedDescription,
          'location': location,
          'photo_urls': photoUrls,
          'contact': contactInfo,
          'severity': finalPriority,
          'ai_suggested_severity': structuredSeverity ?? severity?.severity,
          'ai_severity_confidence':
              structuredSeverity == null ? severity?.confidence : null,
          // Never persist the classifier's forced guess for an invalid,
          // unrelated, or low-confidence image.
          'ai_detected_image_category': trustedImageSuggestion,
          'ai_image_valid': assessment?.hasTrustedEvidence,
          'requires_manual_review': requiresReview,
        })
        .select()
        .single();

    // FIX — nothing previously called api.py's /notify-high, so a High
    // severity report never actually reached officials by email despite
    // that endpoint existing. Fire-and-forget: the report is already
    // saved above regardless of whether this succeeds, so a slow/failed
    // email dispatch must never delay or fail the resident's submission.
    if (finalPriority == 'High') {
      unawaited(ai.notifyHighSeverityIncident(
        category: category,
        severity: finalPriority!,
        description:
            '[UNVERIFIED REPORT - admin verification required] $storedDescription',
        location: location,
        imageUrl: photoUrls.isNotEmpty ? photoUrls.first : null,
      ));
    }

    return {
      'reportId': row['id'],
      'status': 'received',
      'submittedAt': row['created_at'],
      'storedDescription': storedDescription,
      'message': 'Your report was received and is awaiting LGU review.',
    };
  }

  Future<Map<String, dynamic>> checkReportStatus(String reportId) async {
    final row = await SupabaseService.client
        .from('citizen_reports')
        .select()
        .eq('id', reportId)
        .single();

    return {
      'reportId': row['id'],
      'status': row['status'],
      'lastUpdated': row['updated_at'],
      'message': _statusMessage(row['status'] as String),
    };
  }

  String _statusMessage(String status) {
    const map = {
      'received': 'Report received, awaiting assignment.',
      'assigned': 'Assigned to a department for action.',
      'in_progress': 'Department is currently working on this.',
      'resolved': 'The issue has been resolved.',
      'closed': 'Report closed after resolution.',
    };
    return map[status] ?? 'Status unknown.';
  }
}

final announcementServiceProvider = Provider((ref) => AnnouncementService(ref));
final notificationServiceProvider = Provider((ref) => NotificationService(ref));
final hotlineServiceProvider = Provider((_) => HotlineService());
final documentServiceProvider = Provider((_) => DocumentService());
final floodAlertServiceProvider = Provider((_) => FloodAlertService());
final citizenReportServiceProvider = Provider((_) => CitizenReportService());
