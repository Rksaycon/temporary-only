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
// severity is presented to admins for review, rather than to residents.
// Classification failure never rejects a submission.

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
  final bool isValidPhoto;
  final String? detectedCategory; // 'Fire' | 'Flooding' | 'Earthquake' | 'Landslide'
  final bool requiresManualReview;
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
    this.verdict,
  });

  factory ImageVerificationResult.fromJson(Map<String, dynamic> json) {
    return ImageVerificationResult(
      isValidPhoto: json['is_valid_report_photo'] ?? false,
      detectedCategory: json['detected_disaster_category'] as String?,
      requiresManualReview: json['requires_human_review'] ?? true,
      verdict: json['verdict'] as String?,
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
  /// callers should leave severity unassigned for admin review when AI is
  /// unavailable and never reject a submission because classification failed.
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
        return ImageVerificationResult.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('AiTriageService.verifyImage error: $e');
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
