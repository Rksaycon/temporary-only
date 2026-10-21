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
  // Severity is classified at submission for admin review. Citizens do not
  // choose a level or see the AI result in the report form.
  Future<Map<String, dynamic>> submitReport({
    required String category,
    required String subcategory,
    required String description,
    required String location,
    List<ReportPhoto>? photoFiles,
    String? contactInfo,
    String? priority,
    // Optional precomputed result for callers that already classified a report.
    SeverityResult? severityResult,
    // 'Emergency' | 'Minor Concern' — forwarded to the AI backend when it
    // has to run classifySeverity() itself below (severityResult wasn't
    // already provided). Matches api.py's report_type field, which
    // forces 'Low' severity outright for 'Minor Concern'.
    String? reportType,
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
    // image fields. Classification failure must never reject a submission.
    final ai = AiTriageService();
    final severity = severityResult ??
        await ai.classifySeverity(description,
            reportType: reportType, category: category);

    ImageVerificationResult? imageResult;
    if (photoFiles != null && photoFiles.isNotEmpty) {
      imageResult = await ai.verifyImage(
        photoFiles.first.bytes,
        filename: photoFiles.first.filename,
      );
    }

    final finalPriority = priority ?? severity?.toPriorityLevel();
    final requiresReview = imageResult != null &&
        (!imageResult.isValidPhoto || imageResult.requiresManualReview);

    final row = await SupabaseService.client
        .from('citizen_reports')
        .insert({
          'user_id': uid,
          'category': category,
          'subcategory': subcategory,
          'description': description,
          'location': location,
          'photo_urls': photoUrls,
          'contact': contactInfo,
          'severity': finalPriority,
          'ai_suggested_severity': severity?.severity,
          'ai_severity_confidence': severity?.confidence,
          'ai_detected_image_category': imageResult?.detectedCategory,
          'ai_image_valid': imageResult?.isValidPhoto,
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
        description: '[UNVERIFIED REPORT - admin verification required] $description',
        location: location,
        imageUrl: photoUrls.isNotEmpty ? photoUrls.first : null,
      ));
    }

    return {
      'reportId': row['id'],
      'status': 'received',
      'submittedAt': row['created_at'],
      // FIX — the caller reads `result['assignedTo']` to show which
      // department the report went to. That key never existed here, so
      // `result['assignedTo'] as String` threw a null-cast TypeError on
      // *every* successful submission, which the screen's catch block
      // then showed to the resident as "Something went wrong. Please try
      // again." — even though the report had already been saved. Residents
      // saw a failure message every time and had no way to know the
      // report actually went through.
      'assignedTo': '$category Department',
      'estimatedResolution': '3-5 business days',
      'message': 'Thank you! Your report has been received.',
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
