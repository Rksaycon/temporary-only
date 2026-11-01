// ai_triage_service.dart
//
// Talks to the trained ML backend (severity classification + image
// verification for disaster-type reports) — see api.py for the actual
// FastAPI server. Deployed on Hugging Face Spaces (free cpu-basic tier —
// it sleeps after inactivity and takes a bit to wake on the first
// request after a while): https://jus1012-triage-delro-api.hf.space
//
// Used by CitizenReportService.submitReport() in app_services.dart to
// auto-suggest a severity level and flag whether an attached photo looks
// like it matches a real disaster scene. Both results are suggestions —
// the resident (and later, an admin) can always see/override them; this
// service never blocks a submission on its own.

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

const String _aiApiBaseUrl = 'https://jus1012-triage-delro-api.hf.space';

class SeverityResult {
  final String severity; // 'Critical' | 'High' | 'Medium' | 'Low'
  final double confidence; // 0-100
  final String? languageHint;
  // Per-level confidence breakdown, e.g. {'High': 0.0, 'Medium': 0.0, 'Low': 99.9}
  // — drives the score bars in the report screen's "ML Triage Result" panel.
  final Map<String, double> scores;

  SeverityResult({
    required this.severity,
    required this.confidence,
    this.languageHint,
    this.scores = const {},
  });

  factory SeverityResult.fromJson(Map<String, dynamic> json) {
    final rawScores = json['severity_scores'] as Map<String, dynamic>?;
    return SeverityResult(
      severity: json['severity'] ?? 'Unknown',
      confidence: (json['severity_confidence'] ?? 0).toDouble(),
      languageHint: json['language_hint'] as String?,
      scores: rawScores == null
          ? const {}
          : rawScores.map((k, v) => MapEntry(k, (v as num).toDouble())),
    );
  }

  /// Maps the backend's severity labels onto this app's priority picker
  /// levels (Low / Medium / High — kept to exactly 3 to match the
  /// project's documented severity scale). "Critical" from the AI folds
  /// into "High" here — there's no separate "Emergency" tier in this app.
  String toPriorityLevel() {
    switch (severity) {
      case 'Critical':
      case 'High':
        return 'High';
      case 'Medium':
        return 'Medium';
      case 'Low':
      default:
        return 'Low';
    }
  }
}

class ImageVerificationResult {
  // The last working mobile/API flow treated the classifier's own top
  // disaster confidence as the validity signal. Its deployed threshold was
  // raised to 90% specifically to reject closed-set guesses on unrelated
  // photos while still accepting clear disaster evidence.
  static const double legacyDisasterConfidenceThreshold = 90.0;
  static const double medicalConfidenceThreshold = 75.0;
  // Do not offer the citizen Medical/Road Accident confirmation below the
  // externally tested 65% safety gate. Lower scores remain admin-only evidence.
  static const double medicalCandidateConfidenceThreshold = 65.0;
  static const double medicalSinglePhotoConfidenceThreshold = 90.0;
  static const double infrastructureConfidenceThreshold = 65.0;
  static const double validityAutoSelectThreshold = 85.0;

  final bool isValidPhoto;
  final String? detectedCategory;
  final bool requiresManualReview;
  final bool autoSelectAllowed;
  final bool? matchesReportedCategory;
  final double validityModelConfidence;
  final double categoryConfidence;
  final bool dominantFaceDetected;
  final String? reviewReason;
  // The backend's own human-readable verdict (e.g. "⚠️ Photo doesn't
  // look like a disaster report photo. Needs manual review.", or the
  // selfie/mismatch-specific wording) — reused as-is in the UI instead
  // of re-deriving similar copy from isValidPhoto/requiresManualReview
  // client-side and risking it drifting out of sync with api.py's cases.
  final String? verdict;

  ImageVerificationResult({
    required this.isValidPhoto,
    this.detectedCategory,
    required this.requiresManualReview,
    required this.autoSelectAllowed,
    this.matchesReportedCategory,
    required this.validityModelConfidence,
    required this.categoryConfidence,
    required this.dominantFaceDetected,
    this.reviewReason,
    this.verdict,
  });

  double get categoryAcceptanceThreshold {
    switch (detectedCategory) {
      case 'Medical Emergency':
        return medicalConfidenceThreshold;
      case 'Infrastructure Damage':
        return infrastructureConfidenceThreshold;
      case 'Fire':
      case 'Flooding':
      default:
        return legacyDisasterConfidenceThreshold;
    }
  }

  // Restore the original validity gate before trusting any category. The
  // deployed backend currently bypasses this 85% gate in its Medical and
  // Infrastructure branches, so the client must enforce it consistently.
  bool get passesValidityGate =>
      isValidPhoto &&
      autoSelectAllowed &&
      validityModelConfidence >= validityAutoSelectThreshold;

  // A photo may be valid emergency evidence even when its category confidence
  // is not strong enough to auto-select by itself. This narrower gate is used
  // only when several photos of the same incident corroborate one another.
  bool get passesIncidentEvidenceGate =>
      isValidPhoto &&
      validityModelConfidence >= validityAutoSelectThreshold &&
      !dominantFaceDetected;

  bool get isLegacyAutoCategory =>
      detectedCategory == 'Fire' || detectedCategory == 'Flooding';

  /// Medical includes visible medical emergencies and road crashes. It uses
  /// its own detector because the older validity model was trained mainly for
  /// Fire/Flood evidence. This is only candidate evidence: the report screen
  /// still requires stronger single-photo evidence or two corroborating views,
  /// followed by an explicit citizen confirmation.
  bool get hasGuardedMedicalEvidence =>
      detectedCategory == 'Medical Emergency' &&
      isValidPhoto &&
      categoryConfidence >= medicalCandidateConfidenceThreshold;

  bool get hasTrustedCategory =>
      detectedCategory != null &&
      isLegacyAutoCategory &&
      passesValidityGate &&
      categoryConfidence >= categoryAcceptanceThreshold &&
      !dominantFaceDetected;

  factory ImageVerificationResult.fromJson(Map<String, dynamic> json) {
    return ImageVerificationResult(
      isValidPhoto: json['is_valid_report_photo'] ?? false,
      detectedCategory: json['detected_disaster_category'] as String?,
      requiresManualReview: json['requires_human_review'] ?? true,
      autoSelectAllowed: json['auto_select_allowed'] ?? false,
      matchesReportedCategory: json['matches_report'] as bool?,
      validityModelConfidence:
          (json['validity_model_probability'] as num?)?.toDouble() ?? 0,
      categoryConfidence:
          (json['disaster_confidence'] as num?)?.toDouble() ?? 0,
      dominantFaceDetected: json['dominant_face_detected'] ?? false,
      reviewReason: json['review_reason'] as String?,
      verdict: json['verdict'] as String?,
    );
  }
}

class IncidentContextAssessment {
  final bool available;
  final String incidentStatus;
  final String category;
  final String evidenceStrength;
  final String summary;
  final String lookalikeReason;
  final bool needsMorePhotos;
  final bool emergencyCallRecommended;
  final List<String> visibleEvidence;
  final List<String> authenticityConcerns;

  const IncidentContextAssessment({
    required this.available,
    required this.incidentStatus,
    required this.category,
    required this.evidenceStrength,
    required this.summary,
    required this.lookalikeReason,
    required this.needsMorePhotos,
    required this.emergencyCallRecommended,
    required this.visibleEvidence,
    required this.authenticityConcerns,
  });

  factory IncidentContextAssessment.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) =>
        (json[key] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toList(growable: false);

    return IncidentContextAssessment(
      available: json['available'] == true,
      incidentStatus:
          json['incident_status'] as String? ?? 'insufficient_evidence',
      category: json['category'] as String? ?? 'Unclear',
      evidenceStrength: json['evidence_strength'] as String? ?? 'weak',
      summary: json['summary'] as String? ?? '',
      lookalikeReason: json['lookalike_reason'] as String? ?? '',
      needsMorePhotos: json['needs_more_photos'] == true,
      emergencyCallRecommended: json['emergency_call_recommended'] == true,
      visibleEvidence: strings('visible_evidence'),
      authenticityConcerns: strings('authenticity_concerns'),
    );
  }
}

class IncidentVerificationResult {
  final List<ImageVerificationResult> photoResults;
  final IncidentContextAssessment context;
  final String decision;
  final String? suggestedCategory;
  final bool autoSelectAllowed;
  final bool requiresHumanReview;
  final String reason;

  const IncidentVerificationResult({
    required this.photoResults,
    required this.context,
    required this.decision,
    this.suggestedCategory,
    required this.autoSelectAllowed,
    required this.requiresHumanReview,
    required this.reason,
  });

  factory IncidentVerificationResult.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photo_results'] as List<dynamic>? ?? const [];
    final rawContext =
        json['context_assessment'] as Map<String, dynamic>? ?? const {};
    return IncidentVerificationResult(
      photoResults: rawPhotos
          .whereType<Map<String, dynamic>>()
          .map(ImageVerificationResult.fromJson)
          .toList(growable: false),
      context: IncidentContextAssessment.fromJson(rawContext),
      decision: json['decision'] as String? ?? 'ml_only',
      suggestedCategory: json['suggested_category'] as String?,
      autoSelectAllowed: json['auto_select_allowed'] == true,
      requiresHumanReview: json['requires_human_review'] != false,
      reason: json['reason'] as String? ?? '',
    );
  }
}

/// A single live rain-based flood-risk snapshot — see api.py's
/// GET /weather/rain-risk. Not a multi-point forecast (no hourly
/// timeline) — just "here's the current outlook," refreshed on demand.
class RainRiskResult {
  final double lat;
  final double lng;
  final double expectedRainMmNext12h;
  final String floodRisk; // 'Low' | 'Moderate' | 'High' | 'Severe'
  final bool evacuationAdvisory;
  final String recommendedAction;
  final String note;
  final DateTime checkedAt;

  RainRiskResult({
    required this.lat,
    required this.lng,
    required this.expectedRainMmNext12h,
    required this.floodRisk,
    required this.evacuationAdvisory,
    required this.recommendedAction,
    required this.note,
    required this.checkedAt,
  });

  factory RainRiskResult.fromJson(Map<String, dynamic> json) {
    return RainRiskResult(
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      expectedRainMmNext12h:
          (json['expected_rain_mm_next_12h'] as num?)?.toDouble() ?? 0,
      floodRisk: json['flood_risk'] as String? ?? 'Low',
      evacuationAdvisory: json['evacuation_advisory'] as bool? ?? false,
      recommendedAction: json['recommended_action'] as String? ?? '',
      note: json['note'] as String? ?? '',
      checkedAt: DateTime.tryParse(json['checked_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AiTriageService {
  static final AiTriageService _instance = AiTriageService._internal();
  factory AiTriageService() => _instance;
  AiTriageService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _aiApiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Classifies a report's description text for severity. Returns null on
  /// any failure (network issue, backend down, etc.) rather than throwing —
  /// callers should treat a null result as "AI unavailable, fall back to
  /// whatever the resident picked manually" and never block submission.
  ///
  /// [reportType] should be 'Emergency' or 'Minor Concern' when known — the
  /// backend forces 'Low' severity outright for 'Minor Concern' without
  /// even running the model (see api.py's classify_report()).
  Future<SeverityResult?> classifySeverity(
    String descriptionText, {
    String? reportType,
    String? category,
  }) async {
    if (descriptionText.trim().isEmpty) return null;
    try {
      final response = await _dio.post(
        '/classify',
        data: jsonEncode({
          'report_text': descriptionText,
          if (reportType != null) 'report_type': reportType,
          if (category != null) 'category': category,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (response.statusCode == 200) {
        return SeverityResult.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('AiTriageService.classifySeverity error: $e');
      return null;
    }
  }

  /// Verifies a single photo against the (optional) reported category.
  /// Pass [reportedCategory] as null when there's nothing to compare
  /// against yet — the backend then just detects what's in the photo
  /// rather than reporting a false mismatch.
  ///
  /// Takes raw bytes (+ a filename for content-type sniffing) rather than
  /// a `dart:io File` — `File` doesn't exist at all on Flutter web, and
  /// this keeps the service working on every platform the app targets.
  Future<ImageVerificationResult?> verifyImage(
    Uint8List photoBytes, {
    required String filename,
    String? reportedCategory,
  }) async {
    try {
      final formData = FormData.fromMap({
        if (reportedCategory != null) 'reported_category': reportedCategory,
        'file': MultipartFile.fromBytes(photoBytes, filename: filename),
      });
      final response = await _dio.post(
        '/verify-image',
        data: formData,
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      if (response.statusCode == 200) {
        return ImageVerificationResult.fromJson(
            response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('AiTriageService.verifyImage error: $e');
      return null;
    }
  }

  /// Checks one to three photos together as one incident. The backend first
  /// runs the existing local ML models, then (when configured) applies a
  /// multimodal context check for harmless look-alikes. Null means the new
  /// endpoint is unavailable, so callers should retain the legacy per-photo
  /// fallback.
  Future<IncidentVerificationResult?> verifyIncident(
    List<Uint8List> photoBytes, {
    required List<String> filenames,
    String? description,
  }) async {
    if (photoBytes.isEmpty || photoBytes.length != filenames.length) {
      return null;
    }
    try {
      final files = <MultipartFile>[
        for (var index = 0; index < photoBytes.length && index < 3; index++)
          MultipartFile.fromBytes(
            photoBytes[index],
            filename: filenames[index],
          ),
      ];
      final response = await _dio.post(
        '/verify-incident',
        data: FormData.fromMap({
          'files': files,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        }),
        options: Options(receiveTimeout: const Duration(seconds: 50)),
      );
      if (response.statusCode == 200) {
        return IncidentVerificationResult.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('AiTriageService.verifyIncident error: $e');
      return null;
    }
  }

  /// Live rain-based flood risk for a barangay, from your weather API
  /// (see api.py's /weather/rain-risk, which needs OPENWEATHER_API_KEY
  /// configured server-side — a 503 there surfaces here as a null
  /// result, same as any other backend-unavailable case). Pass lat/lng
  /// for a specific spot; omit both to use the backend's own Milaor
  /// default location.
  Future<RainRiskResult?> getRainRisk({double? lat, double? lng}) async {
    try {
      final response = await _dio.get(
        '/weather/rain-risk',
        queryParameters: {
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
      );
      if (response.statusCode == 200) {
        return RainRiskResult.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('AiTriageService.getRainRisk error: $e');
      return null;
    }
  }

  /// Fires the backend's High-severity email alert to officials (see
  /// api.py's POST /notify-high — it currently sends to a placeholder
  /// personal inbox until Resend's sending domain is verified; see
  /// TEMP_DEMO_RECIPIENT there). Fire-and-forget on purpose: the report
  /// is already saved in Supabase by the time this is called (see
  /// CitizenReportService.submitReport() in app_services.dart), so a
  /// failed/slow email dispatch must never affect what the resident
  /// sees — this returns false rather than throwing on any failure.
  Future<bool> notifyHighSeverityIncident({
    required String category,
    required String severity,
    required String description,
    String? location,
    double? lat,
    double? lng,
    String? imageUrl,
  }) async {
    try {
      final response = await _dio.post(
        '/notify-high',
        data: jsonEncode({
          'category': category,
          'severity': severity,
          'description': description,
          if (location != null) 'location': location,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          if (imageUrl != null) 'image_url': imageUrl,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('AiTriageService.notifyHighSeverityIncident error: $e');
      return false;
    }
  }
}
