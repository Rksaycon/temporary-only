import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:may_laud/services/supabase_service.dart';

class Announcement {
  final String id;
  final String title;
  final String description;
  final String category;
  final DateTime date;
  final String? imageUrl;
  final bool isImportant;
  final bool isRead; // FIX #1 — immutable (was mutable `bool isRead`)

  const Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.date,
    this.imageUrl,
    this.isImportant = false,
    this.isRead = false,
  });

  String get formattedDate =>
      DateFormat('MMM dd, yyyy • hh:mm a').format(date);

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id:          json['id'] ?? '',
      title:       json['title'] ?? '',
      description: json['description'] ?? '',
      category:    json['category'] ?? 'General',
      // FIX — Supabase returns created_at in UTC (e.g. "...T07:00:00Z").
      // DateTime.parse keeps that as a UTC-flagged DateTime, and
      // formatting it directly shows the raw UTC clock time instead of
      // the resident's local time — an announcement posted at 3:00 PM
      // Philippine time (UTC+8) was showing as 7:00 AM in the app.
      // .toLocal() converts it to the device's local timezone before
      // it's ever formatted.
      date:        json['created_at'] != null
                     ? DateTime.parse(json['created_at']).toLocal()
                     : DateTime.now(),
      imageUrl:    json['image_url'],
      isImportant: json['is_important'] ?? false,
      isRead:      json['is_read'] ?? false,
    );
  }

  Announcement copyWith({bool? isRead}) {
    return Announcement(
      id:          id,
      title:       title,
      description: description,
      category:    category,
      date:        date,
      imageUrl:    imageUrl,
      isImportant: isImportant,
      isRead:      isRead ?? this.isRead,
    );
  }
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String type;
  final bool isRead; // FIX #1 — immutable (was mutable `bool isRead`)
  final Map<String, dynamic>? data;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.data,
  });

  String get formattedTime {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours   < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays    < 1) return '${diff.inHours}h ago';
    if (diff.inDays    < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd').format(timestamp);
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id:        json['id'] ?? '',
      title:     json['title'] ?? '',
      message:   json['message'] ?? '',
      timestamp: json['created_at'] != null
                   ? DateTime.parse(json['created_at'])
                   : DateTime.now(),
      type:      json['type'] ?? 'system',
      isRead:    json['is_read'] ?? false,
      data:      json['data'],
    );
  }

  // FIX #8 — add missing copyWith
  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id:        id,
      title:     title,
      message:   message,
      timestamp: timestamp,
      type:      type,
      isRead:    isRead ?? this.isRead,
      data:      data,
    );
  }
}

class AnnouncementsProvider extends StateNotifier<List<Announcement>> {
  AnnouncementsProvider() : super([]) {
    try {
      fetchAnnouncements();
    } catch (_) {}
    _subscribeToRealtimeChanges();
  }

  SupabaseClient get _client => SupabaseService.client;

  // FIX — live updates: without this the provider only ever fetches once,
  // on construction, so a new row inserted in Supabase never shows up
  // until the whole app is restarted (which recreates the provider).
  // Subscribing to Postgres Changes on the `announcements` table means
  // new/edited/deleted announcements reach the app immediately, no
  // manual reload or app restart required.
  RealtimeChannel? _channel;

  void _subscribeToRealtimeChanges() {
    try {
      _channel = _client
          .channel('public:announcements')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'announcements',
            callback: (payload) => _handleRealtimeChange(payload),
          )
          .subscribe();
    } catch (_) {
      // Realtime may be unavailable (e.g. offline) — the manual
      // refresh button / pull-to-refresh still works as a fallback.
    }
  }

  void _handleRealtimeChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        final a = Announcement.fromJson(payload.newRecord);
        // Guard against duplicates if a manual fetch raced the event.
        if (state.any((e) => e.id == a.id)) return;
        state = [a, ...state]
          ..sort((x, y) => y.date.compareTo(x.date));
        break;
      case PostgresChangeEvent.update:
        final updated = Announcement.fromJson(payload.newRecord);
        state = state.map((a) {
          if (a.id != updated.id) return a;
          // Preserve the locally-known read status; it isn't part of
          // the `announcements` row itself (it lives in
          // `announcement_reads`), so don't let the update clobber it.
          return updated.copyWith(isRead: a.isRead);
        }).toList();
        break;
      case PostgresChangeEvent.delete:
        final oldId = payload.oldRecord['id'] as String?;
        if (oldId == null) return;
        state = state.where((a) => a.id != oldId).toList();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> fetchAnnouncements() async {
    try {
      final uid = SupabaseService.userId;

      final rows = await _client
          .from('announcements')
          .select()
          .order('created_at', ascending: false);

      Set<String> readIds = {};
      if (uid != null) {
        final reads = await _client
            .from('announcement_reads')
            .select('announcement_id')
            .eq('user_id', uid);
        readIds = {for (final r in reads) r['announcement_id'] as String};
      }

      state = (rows as List).map((row) {
        final a = Announcement.fromJson(row as Map<String, dynamic>);
        return a.copyWith(isRead: readIds.contains(a.id));
      }).toList();
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    final uid = SupabaseService.userId;
    if (uid == null) return;

    await _client.from('announcement_reads').upsert({
      'user_id':         uid,
      'announcement_id': id,
    });

    // FIX #1 — use copyWith instead of mutating isRead directly
    state = state.map((a) => a.id == id ? a.copyWith(isRead: true) : a).toList();
  }

  Future<void> markAllAsRead() async {
    final uid = SupabaseService.userId;
    if (uid == null) return;

    final unread = state.where((a) => !a.isRead).toList();
    for (final a in unread) {
      await _client.from('announcement_reads').upsert({
        'user_id':         uid,
        'announcement_id': a.id,
      });
    }

    // FIX #1 — use copyWith instead of mutating
    state = state.map((a) => a.copyWith(isRead: true)).toList();
  }

  void addAnnouncement(Announcement a) => state = [a, ...state];
  void deleteAnnouncement(String id) =>
      state = state.where((a) => a.id != id).toList();
}

class NotificationsProvider extends StateNotifier<List<AppNotification>> {
  NotificationsProvider() : super([]) {
    try {
      fetchNotifications();
    } catch (_) {}
    _subscribeToRealtimeChanges();
  }

  SupabaseClient get _client => SupabaseService.client;

  // FIX — live updates: previously this only ever fetched once, on
  // construction. When the web admin changes a citizen_report's status
  // (or any other server-side flow inserts a row into `notifications`
  // for this user), the resident wouldn't see it until they force-closed
  // and reopened the app. Subscribing to Postgres Changes on the
  // `notifications` table means a new row — e.g. "Your report was
  // marked resolved" — reaches the app immediately and updates the
  // unread badge/list in real time, the same way FCM push does when the
  // app is backgrounded. This also covers the case where a push is
  // missed (permission denied, offline at delivery time, etc.) since
  // Supabase stays the source of truth.
  RealtimeChannel? _channel;
  String? _subscribedUid;

  void _subscribeToRealtimeChanges() {
    // FIX — SupabaseService.userId (like SupabaseService.client) throws
    // synchronously if called before Supabase.initialize() has completed.
    // This method runs unguarded from the constructor (unlike
    // AnnouncementsProvider's equivalent, which wraps its own
    // _client access in try/catch below) — reading notificationsProvider
    // early enough to race SupabaseService.init() used to crash provider
    // construction entirely instead of just skipping realtime for now.
    String? uid;
    try {
      uid = SupabaseService.userId;
    } catch (_) {
      return;
    }
    if (uid == null) return;
    if (_channel != null && _subscribedUid == uid) return;
    // A different user signed in on this device than the one the
    // channel was opened for (or none at all yet) — drop the stale
    // subscription before opening a fresh, correctly-filtered one.
    _channel?.unsubscribe();
    _subscribedUid = uid;
    try {
      _channel = _client
          .channel('public:notifications:user_id=eq.$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: uid,
            ),
            callback: (payload) => _handleRealtimeChange(payload),
          )
          .subscribe();
    } catch (_) {
      // Realtime may be unavailable (e.g. offline) — pull-to-refresh on
      // NotificationsScreen and the FCM-triggered refresh still work.
    }
  }

  void _handleRealtimeChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        final n = AppNotification.fromJson(payload.newRecord);
        if (state.any((e) => e.id == n.id)) return;
        state = [n, ...state];
        break;
      case PostgresChangeEvent.update:
        final updated = AppNotification.fromJson(payload.newRecord);
        state = state.map((n) => n.id == updated.id ? updated : n).toList();
        break;
      case PostgresChangeEvent.delete:
        final oldId = payload.oldRecord['id'] as String?;
        if (oldId == null) return;
        state = state.where((n) => n.id != oldId).toList();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> fetchNotifications() async {
    // FIX — SupabaseService.userId was read outside any try/catch here.
    // It throws synchronously if Supabase.initialize() hasn't completed
    // yet, and since fetchNotifications() is async, that throw doesn't
    // reach the constructor's `try { fetchNotifications(); } catch (_) {}`
    // (which only catches a *synchronous* throw, not this function's
    // returned Future rejecting later) — it surfaced instead as an
    // unhandled async error. AnnouncementsProvider.fetchAnnouncements()
    // already wraps this same access inside its try block; mirror that
    // here instead of checking it up front.
    try {
      final uid = SupabaseService.userId;
      if (uid == null) return;

      // The provider is constructed once, at app start, when there may
      // be no signed-in user yet (guest mode, session still restoring)
      // — so the realtime channel from the constructor never attached.
      // Every later call to fetchNotifications() (pull-to-refresh,
      // opening the screen, a push arriving) is a safe point to
      // (re)attach it for whoever is currently signed in, without
      // needing auth_provider to know about this provider at all.
      _subscribeToRealtimeChanges();

      final rows = await _client
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      state = (rows as List)
          .map((r) => AppNotification.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    final uid = SupabaseService.userId;
    if (uid == null) return;

    // FIX — scope the update to the signed-in user as well as the row id.
    // Filtering by `id` alone means the *client* trusts that `id` always
    // belongs to the current user; it's only true today because the UI
    // never shows anyone else's notification. Adding `user_id = uid` here
    // is defense-in-depth for the app, but it is NOT what actually keeps
    // one resident from reading/marking another resident's notifications —
    // that has to be enforced by a Row Level Security policy on the
    // `notifications` table in Supabase (see notes below).
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('user_id', uid);

    // FIX #1 — use copyWith instead of mutating n.isRead directly
    state = state.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
  }

  Future<void> markAllAsRead() async {
    final uid = SupabaseService.userId;
    if (uid == null) return;

    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid);

    // FIX #1 — use copyWith instead of mutating
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void addNotification(AppNotification n) => state = [n, ...state];

  // FIX — this used to only drop the item from local `state`, so the row
  // never actually left Supabase: it would silently reappear the next
  // time fetchNotifications() ran (pull-to-refresh, app relaunch, a push
  // triggering a refresh). Deleting server-side first, then updating
  // local state on success, is what makes the delete actually stick.
  Future<void> deleteNotification(String id) async {
    final uid = SupabaseService.userId;
    if (uid == null) return;

    await _client
        .from('notifications')
        .delete()
        .eq('id', id)
        .eq('user_id', uid);

    state = state.where((n) => n.id != id).toList();
  }

  int get unreadCount => state.where((n) => !n.isRead).length;
}

final announcementsProvider =
    StateNotifierProvider<AnnouncementsProvider, List<Announcement>>(
  (ref) => AnnouncementsProvider(),
);

final notificationsProvider =
    StateNotifierProvider<NotificationsProvider, List<AppNotification>>(
  (ref) => NotificationsProvider(),
);

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.isRead).length;
});

final importantAnnouncementsProvider = Provider<List<Announcement>>((ref) {
  return ref.watch(announcementsProvider).where((a) => a.isImportant).toList();
});

// ─────────────────────────────────────────────────────────
// DOCUMENT REQUESTS 
// ─────────────────────────────────────────────────────────
/// A picked attachment's raw bytes plus its filename. Bytes rather than a
/// `dart:io File` so the snapshot keeps working on Flutter web, where `File`
/// doesn't exist — mirrors `ReportPhoto` in app_services.dart.
class DocumentAttachment {
  final Uint8List bytes;
  final String filename;
  const DocumentAttachment({required this.bytes, required this.filename});
}

class DocumentRequest {
  final String id;
  final String documentType;
  final String purpose;
  final String status; // 'pending' | 'processing' | 'ready' | 'released' | 'rejected'
  final String? fee;
  final String? notes;
  /// Everything the resident typed on the request form. Persisted so the web
  /// admin sees the same details the resident submitted (see
  /// supabase/document_requests_full_details.sql).
  final String? fullName;
  final String? address;
  final String? urgency;
  final String? additionalNotes;
  /// Public URLs of the supporting documents uploaded with the request.
  final List<String> attachmentUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DocumentRequest({
    required this.id,
    required this.documentType,
    required this.purpose,
    required this.status,
    required this.createdAt,
    this.fee,
    this.notes,
    this.fullName,
    this.address,
    this.urgency,
    this.additionalNotes,
    this.attachmentUrls = const [],
    this.updatedAt,
  });

  factory DocumentRequest.fromJson(Map<String, dynamic> json) {
    return DocumentRequest(
      id:              json['id']?.toString() ?? '',
      documentType:    json['document_type'] ?? '',
      purpose:         json['purpose'] ?? '',
      status:          json['status'] ?? 'pending',
      fee:             json['fee'],
      notes:           json['notes'],
      fullName:        json['full_name'],
      address:         json['address'],
      urgency:         json['urgency'],
      additionalNotes: json['additional_notes'],
      attachmentUrls:  (json['attachment_urls'] as List?)
                           ?.map((e) => e.toString())
                           .toList() ??
                       const [],
      createdAt:       json['created_at'] != null
                           ? DateTime.parse(json['created_at'])
                           : DateTime.now(),
      updatedAt:       json['updated_at'] != null
                           ? DateTime.parse(json['updated_at'])
                           : null,
    );
  }

  /// Status normalized to lower case so 'Pending', ' pending ' and 'pending'
  /// all resolve to the same tracking step/label.
  String get normalizedStatus => status.trim().toLowerCase();

  /// Human-readable label for the status chip and tracking timeline.
  String get statusLabel {
    switch (normalizedStatus) {
      case 'pending':
        return 'Pending Review';
      case 'processing':
        return 'Processing';
      case 'ready':
        return 'Ready for Pickup';
      case 'released':
        return 'Released';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Submitted';
    }
  }

  /// One-line explanation of what the current status means for the resident.
  String get statusMessage {
    switch (normalizedStatus) {
      case 'pending':
        return 'Your request was received and is awaiting review by the office.';
      case 'processing':
        return 'Your document is being prepared. We\'ll update you here.';
      case 'ready':
        return 'Your document is ready — you can pick it up at the municipal office.';
      case 'released':
        return 'Your document has been released. Thank you!';
      case 'completed':
        return 'Your request is complete. Thank you!';
      case 'rejected':
        return 'Your request was rejected. Please contact the office for details.';
      default:
        return 'We received your request.';
    }
  }

  bool get isRejected => normalizedStatus == 'rejected';

  /// Index of the latest reached step in the 4-stage timeline
  /// (0 Submitted · 1 Processing · 2 Ready · 3 Released). A 'rejected'
  /// request is handled separately by the UI and maps to step 0.
  int get timelineStep {
    switch (normalizedStatus) {
      case 'pending':
        return 0;
      case 'processing':
        return 1;
      case 'ready':
        return 2;
      case 'released':
      case 'completed':
        return 3;
      default:
        return 0;
    }
  }

  /// Name shown on the tracking cards for who filed the request.
  ///
  /// Requests created before `full_name` existed (and the offline fallback row
  /// used when the insert fails) have nothing to show, so those fall back to a
  /// neutral label rather than rendering an empty line.
  String get requesterName {
    final name = fullName?.trim() ?? '';
    return name.isEmpty ? 'You' : name;
  }

  /// True when supporting documents were uploaded with this request.
  bool get hasAttachments => attachmentUrls.isNotEmpty;

  /// A short, stable reference the resident can quote to the office. Derived
  /// from the row id so it can never drift from what's stored in Supabase.
  String get reference {
    final compact = id.replaceAll('-', '');
    final slice = compact.length >= 8 ? compact.substring(0, 8) : compact;
    return 'MLR-${slice.toUpperCase()}';
  }

  String get submittedLabel =>
      DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt.toLocal());

  String? get updatedLabel => updatedAt == null
      ? null
      : DateFormat('MMM dd, yyyy • hh:mm a').format(updatedAt!.toLocal());
}

class DocumentRequestsProvider extends StateNotifier<List<DocumentRequest>> {
  DocumentRequestsProvider() : super([]) {
    try {
      fetchRequests();
    } catch (_) {}
    _subscribeToRealtimeChanges();
  }

  SupabaseClient get _client => SupabaseService.client;

  // FIX — live updates: previously this provider only ever fetched once, on
  // construction. When an admin changes a request's status from the web
  // dashboard, a resident watching the tracker wouldn't see it until they
  // force-closed and reopened the app. Subscribing to Postgres Changes on
  // `document_requests` (filtered to this user) means a status change —
  // e.g. 'pending' -> 'ready' — reaches the app immediately and updates the
  // tracking screen in real time, the same way FCM push does when the app is
  // backgrounded. Supabase stays the source of truth, so a missed push still
  // self-heals on the next realtime event or pull-to-refresh.
  RealtimeChannel? _channel;
  String? _subscribedUid;

  void _subscribeToRealtimeChanges() {
    // SupabaseService.userId (like SupabaseService.client) throws
    // synchronously if called before Supabase.initialize() has completed.
    String? uid;
    try {
      uid = SupabaseService.userId;
    } catch (_) {
      return;
    }
    if (uid == null) return;
    if (_channel != null && _subscribedUid == uid) return;
    // A different user signed in on this device than the one the channel was
    // opened for (or none at all yet) — drop the stale subscription before
    // opening a fresh, correctly-filtered one.
    _channel?.unsubscribe();
    _subscribedUid = uid;
    try {
      _channel = _client
          .channel('public:document_requests:user_id=eq.$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'document_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: uid,
            ),
            callback: (payload) => _handleRealtimeChange(payload),
          )
          .subscribe();
    } catch (_) {
      // Realtime may be unavailable (e.g. offline) — pull-to-refresh on the
      // tracking screen still works.
    }
  }

  void _handleRealtimeChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        final r = DocumentRequest.fromJson(payload.newRecord);
        if (state.any((e) => e.id == r.id)) return;
        state = [r, ...state];
        break;
      case PostgresChangeEvent.update:
        final updated = DocumentRequest.fromJson(payload.newRecord);
        state = state.map((r) => r.id == updated.id ? updated : r).toList();
        break;
      case PostgresChangeEvent.delete:
        final oldId = payload.oldRecord['id']?.toString();
        if (oldId == null) return;
        state = state.where((r) => r.id != oldId).toList();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> fetchRequests() async {
    // The provider is constructed once, at app start, when there may be no
    // signed-in user yet (guest mode, session still restoring) — so the
    // realtime channel from the constructor may never have attached. Every
    // later call to fetchRequests() (pull-to-refresh, opening the tracking
    // screen) is a safe point to (re)attach it for whoever is signed in now.
    _subscribeToRealtimeChanges();

    String? uid;
    try {
      uid = SupabaseService.userId;
    } catch (_) {
      return;
    }
    if (uid == null) return;

    try {
      final rows = await _client
          .from('document_requests')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      state = (rows as List)
          .map((r) => DocumentRequest.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Table may not exist yet, or the user has no requests — leave
      // state as-is rather than crashing the profile screen.
    }
  }

  /// Local mutator used to seed a request without a backend (tests), and to
  /// prepend a realtime-inserted row.
  void addRequest(DocumentRequest r) => state = [r, ...state];

  /// Called by DocumentRequestScreen on successful submission.
  ///
  /// Everything the resident filled in is persisted — Full Name, Address,
  /// Urgency, Additional Notes and any attached supporting documents — so the
  /// web admin sees the same request the resident sees (see
  /// supabase/document_requests_full_details.sql). `notes` is still written
  /// with the urgency string so an admin screen that already renders that
  /// column keeps working unchanged.
  Future<void> submitRequest({
    required String documentType,
    required String purpose,
    required String urgency,
    String? fee,
    String? fullName,
    String? address,
    String? additionalNotes,
    List<DocumentAttachment> attachments = const [],
  }) async {
    String? uid;
    try {
      uid = SupabaseService.userId;
    } catch (_) {
      uid = null;
    }

    // Upload the supporting documents first, best-effort: losing a photo must
    // never lose the whole request. A failed upload just leaves
    // `attachment_urls` shorter than what the picker showed.
    final attachmentUrls = <String>[];
    if (attachments.isNotEmpty && uid != null) {
      final bucket = _client.storage.from('document-attachments');
      for (var i = 0; i < attachments.length; i++) {
        try {
          final path = '$uid/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          await bucket.uploadBinary(path, attachments[i].bytes);
          attachmentUrls.add(bucket.getPublicUrl(path));
        } catch (_) {
          // Bucket missing / offline — skip this attachment.
        }
      }
    }

    final details = <String, dynamic>{
      'full_name':        fullName?.trim(),
      'address':          address?.trim(),
      'urgency':          urgency,
      'additional_notes': additionalNotes?.trim(),
      'attachment_urls':  attachmentUrls,
    };

    try {
      if (uid == null) throw StateError('Not signed in');
      final row = await _insertRequest(
        uid: uid,
        documentType: documentType,
        purpose: purpose,
        urgency: urgency,
        fee: fee,
        details: details,
      );
      state = [DocumentRequest.fromJson(row), ...state];
    } catch (_) {
      // If the insert fails (e.g. table not provisioned yet) at least
      // reflect the request locally so the stats stay honest for this
      // session instead of silently doing nothing.
      state = [
        DocumentRequest(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          documentType: documentType,
          purpose: purpose,
          status: 'pending',
          notes: 'Urgency: $urgency',
          urgency: urgency,
          fullName: fullName,
          address: address,
          additionalNotes: additionalNotes,
          attachmentUrls: attachmentUrls,
          createdAt: DateTime.now(),
        ),
        ...state,
      ];
    }
  }

  /// Inserts the request row and returns what Supabase stored.
  ///
  /// Tries the full payload first; if the database hasn't been migrated yet
  /// (the detail columns added by document_requests_full_details.sql are
  /// missing) the insert is retried with just the original columns, so a
  /// resident is never blocked from filing a request by a schema change that
  /// hasn't been applied yet.
  Future<Map<String, dynamic>> _insertRequest({
    required String uid,
    required String documentType,
    required String purpose,
    required String urgency,
    required Map<String, dynamic> details,
    String? fee,
  }) async {
    final base = <String, dynamic>{
      'user_id':       uid,
      'document_type': documentType,
      'purpose':       purpose,
      'status':        'pending',
      if (fee != null) 'fee': fee,
      'notes':         'Urgency: $urgency',
    };

    try {
      return await _client
          .from('document_requests')
          .insert({...base, ...details})
          .select()
          .single();
    } catch (_) {
      return await _client
          .from('document_requests')
          .insert(base)
          .select()
          .single();
    }
  }
}

final documentRequestsProvider =
    StateNotifierProvider<DocumentRequestsProvider, List<DocumentRequest>>(
  (ref) => DocumentRequestsProvider(),
);

final documentRequestStatsProvider = Provider<Map<String, int>>((ref) {
  final requests = ref.watch(documentRequestsProvider);
  return {
    'total': requests.length,
    'approved': requests
        .where((r) =>
            const {'ready', 'released', 'completed'}
                .contains(r.normalizedStatus))
        .length,
    'pending': requests
        .where((r) =>
            const {'pending', 'processing'}.contains(r.normalizedStatus))
        .length,
  };
});

// ─────────────────────────────────────────────────────────
// CITIZEN REPORTS — the resident's report history (citizen_report_screen.dart
// submits, report_history_screen.dart renders). Mirrors DocumentRequest above:
// rows live in the `citizen_reports` table and are kept current by a Supabase
// realtime subscription, so a status change made in the web admin appears in
// the history screen without a manual refresh — and the same status change
// inserts a `notifications` row that the `push` Edge Function turns into an
// FCM notification even while the app is backgrounded or closed.
// ─────────────────────────────────────────────────────────
class CitizenReport {
  final String id;
  final String category;
  final String subcategory; // the form's title (falls back to category)
  final String description;
  final String location;
  final List<String> photoUrls;
  final String contact;
  final String severity; // 'Low' | 'Medium' | 'High' | ...
  final String status; // received | assigned | in_progress | resolved | closed
  final String verificationStatus;
  final String verificationNote;
  final bool requiresManualReview;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CitizenReport({
    required this.id,
    required this.category,
    this.subcategory = '',
    this.description = '',
    this.location = '',
    this.photoUrls = const [],
    this.contact = '',
    this.severity = '',
    this.status = 'received',
    this.verificationStatus = 'pending',
    this.verificationNote = '',
    this.requiresManualReview = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CitizenReport.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : DateTime.now();
    return CitizenReport(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Other',
      subcategory: json['subcategory']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      photoUrls: json['photo_urls'] is List
          ? List<String>.from(json['photo_urls'] as List)
          : const [],
      contact: json['contact']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      status: json['status']?.toString() ?? 'received',
      verificationStatus: json['verification_status']?.toString() ??
          (['assigned', 'in_progress', 'resolved', 'closed'].contains(json['status'])
              ? 'verified' : 'pending'),
      verificationNote: json['verification_note']?.toString() ?? '',
      requiresManualReview: json['requires_manual_review'] == true,
      // Supabase returns timestamps in UTC — kept as parsed and converted to
      // local at format time (same convention as Announcement.fromJson).
      createdAt: createdAt,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : createdAt,
    );
  }

  String get verificationMessage => switch (verificationStatus) {
    'verified' => 'Your report has been checked by an administrator.',
    'rejected' => 'Your report was rejected. Open the details to read the reason.',
    'needs_information' => 'An administrator needs more information. Open the details for instructions.',
    _ => 'Your report is awaiting administrator verification.',
  };

  String get verificationLabel => switch (verificationStatus) {
    'verified' => 'Verified',
    'rejected' => 'Rejected',
    'needs_information' => 'More information needed',
    _ => 'Pending verification',
  };

  /// Lower-cased and defaulted — unknown/legacy statuses fall back to
  /// 'received' so nothing downstream has to null-check.
  String get normalizedStatus {
    final s = status.trim().toLowerCase();
    return s.isEmpty ? 'received' : s;
  }

  /// Chip label shown on the history card. Matches
  /// citizen_reports_status_label() in the SQL trigger, so the push text and
  /// the in-app chip word a status identically.
  String get statusLabel {
    switch (normalizedStatus) {
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'Ongoing';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      case 'received':
        return 'Received';
      default:
        final s = status.trim();
        return s.isEmpty
            ? 'Received'
            : s[0].toUpperCase() + s.substring(1).toLowerCase();
    }
  }

  /// Resident-facing sentence shown under the status chip.
  String get statusMessage {
    switch (normalizedStatus) {
      case 'assigned':
        return 'Your report has been assigned to a department for action.';
      case 'in_progress':
        return 'Ongoing — the department is currently working on your report.';
      case 'resolved':
        return 'Solved! Your report has been resolved.';
      case 'closed':
        return 'Your report has been closed after resolution.';
      case 'received':
      default:
        return 'Report received — awaiting assignment.';
    }
  }

  /// Step in the four-stage history timeline (Received → Assigned → Ongoing →
  /// Resolved), matching [timelineLabels]. 'closed' counts as the final step.
  int get timelineStep {
    switch (normalizedStatus) {
      case 'assigned':
        return 1;
      case 'in_progress':
        return 2;
      case 'resolved':
      case 'closed':
        return 3;
      case 'received':
      default:
        return 0;
    }
  }

  bool get isResolved =>
      normalizedStatus == 'resolved' || normalizedStatus == 'closed';

  /// Not yet solved — the state the resident is actively tracking.
  bool get isOngoing => !isResolved && verificationStatus != 'rejected';

  /// Short reference code shown to the resident (and embedded in push
  /// notifications). Derived from the row id the exact way the SQL trigger's
  /// ref_label does (RPT- + first 8 chars of the uuid without dashes), so the
  /// history card, the in-app notification and the push all match.
  String get reference {
    final compact = id.replaceAll('-', '');
    if (compact.isEmpty) return 'RPT-';
    final slice = compact.length >= 8 ? compact.substring(0, 8) : compact;
    return 'RPT-${slice.toUpperCase()}';
  }

  String get submittedLabel =>
      DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt.toLocal());

  String get lastUpdatedLabel =>
      DateFormat('MMM dd, yyyy • hh:mm a').format(updatedAt.toLocal());

  /// Falls back to the category when the row predates the title fallback, so
  /// the card never renders an empty headline.
  String get displayTitle =>
      subcategory.trim().isEmpty ? category : subcategory.trim();
}


class CitizenReportsProvider extends StateNotifier<List<CitizenReport>> {
  CitizenReportsProvider() : super(const []) {
    try {
      fetchReports();
    } catch (_) {}
  }

  SupabaseClient get _client => SupabaseService.client;
  RealtimeChannel? _channel;

  /// Loads this resident's reports and (re)attaches the realtime channel.
  /// Called from the constructor and again whenever the history screen opens,
  /// so a login/logout without an app restart still shows the right
  /// resident's history.
  Future<void> fetchReports() async {
    // Realtime first — the provider is constructed once at app start, when
    // there may be no signed-in user yet, so (re)attaching here is the safe
    // point to subscribe for whoever is signed in now (mirrors
    // DocumentRequestsProvider.fetchRequests).
    _subscribeToRealtimeChanges();

    // SupabaseService.userId throws synchronously if called before
    // Supabase.initialize() has completed (e.g. under `flutter test`) —
    // catch INSIDE this async body so the returned future still completes
    // normally instead of surfacing an unhandled async error.
    String? uid;
    try {
      uid = SupabaseService.userId;
    } catch (_) {
      return;
    }
    if (uid == null) {
      state = const [];
      return;
    }
    try {
      final rows = await _client
          .from('citizen_reports')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      state = List.unmodifiable([
        for (final r in rows as List)
          CitizenReport.fromJson(Map<String, dynamic>.from(r)),
      ]);
    } catch (_) {
      // Keep whatever we already have (offline / table missing) — the history
      // screen renders its own empty state from the current state.
    }
  }

  /// Merges a locally-known report (e.g. right after a successful submission)
  /// without waiting for a round trip. Newest first; no duplicates.
  void addReport(CitizenReport report) {
    if (state.any((r) => r.id == report.id)) return;
    state = List.unmodifiable([report, ...state]);
  }

  void _subscribeToRealtimeChanges() {
    // SupabaseService.userId (like SupabaseService.client) throws
    // synchronously if called before Supabase.initialize() has completed.
    String? uid;
    try {
      uid = SupabaseService.userId;
    } catch (_) {
      return;
    }
    if (uid == null) return;
    try {
      final client = _client;
      _channel?.unsubscribe();
      _channel = client
          .channel('citizen_reports_channel_$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'citizen_reports',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: uid,
            ),
            callback: _handleRealtimeChange,
          )
          .subscribe();
    } catch (_) {
      // Realtime may be unavailable (e.g. offline) — pull-to-refresh on the
      // history screen still works.
    }
  }

  /// Merges an INSERT/UPDATE payload into the list (or drops the row on
  /// DELETE) so the history screen repaints with the live status — requires
  /// `alter table citizen_reports replica identity full` for UPDATE events,
  /// installed by supabase/citizen_reports_status_tracking.sql.
  void _handleRealtimeChange(PostgresChangePayload payload) {
    final newRecord = payload.newRecord;
    if (payload.eventType == PostgresChangeEvent.delete) {
      final oldId = payload.oldRecord['id']?.toString();
      if (oldId != null) {
        state = List.unmodifiable([
          for (final r in state)
            if (r.id != oldId) r,
        ]);
      }
      return;
    }
    if (newRecord.isEmpty) return;
    final incoming =
        CitizenReport.fromJson(Map<String, dynamic>.from(newRecord));
    if (incoming.id.isEmpty) return;
    final index = state.indexWhere((r) => r.id == incoming.id);
    if (index >= 0) {
      final next = [...state];
      next[index] = incoming;
      state = List.unmodifiable(next);
    } else {
      state = List.unmodifiable([incoming, ...state]);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final citizenReportsProvider =
    StateNotifierProvider<CitizenReportsProvider, List<CitizenReport>>(
  (ref) => CitizenReportsProvider(),
);

/// Summary figures for the history screen header — total reports, how many
/// are still ongoing (received/assigned/in_progress) and how many are solved
/// (resolved/closed).
final citizenReportStatsProvider = Provider<Map<String, int>>((ref) {
  final reports = ref.watch(citizenReportsProvider);
  return {
    'total': reports.length,
    'ongoing': reports.where((r) => r.isOngoing).length,
    'resolved': reports.where((r) => r.isResolved).length,
  };
});

// ─────────────────────────────────────────────────────────
// DASHBOARD STAT
// ─────────────────────────────────────────────────────────
class DashboardStats {
  final int activeProjects;
  final double budgetUtilizedPercent;
  final int resolvedReports;
  final int barangayAssemblies;
  final bool isLoading;

  const DashboardStats({
    this.activeProjects = 0,
    this.budgetUtilizedPercent = 0,
    this.resolvedReports = 0,
    this.barangayAssemblies = 0,
    this.isLoading = true,
  });

  DashboardStats copyWith({
    int? activeProjects,
    double? budgetUtilizedPercent,
    int? resolvedReports,
    int? barangayAssemblies,
    bool? isLoading,
  }) {
    return DashboardStats(
      activeProjects: activeProjects ?? this.activeProjects,
      budgetUtilizedPercent:
          budgetUtilizedPercent ?? this.budgetUtilizedPercent,
      resolvedReports: resolvedReports ?? this.resolvedReports,
      barangayAssemblies: barangayAssemblies ?? this.barangayAssemblies,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DashboardStatsNotifier extends StateNotifier<DashboardStats> {
  DashboardStatsNotifier() : super(const DashboardStats()) {
    try {
      fetchStats();
    } catch (_) {}
  }

  SupabaseClient get _client => SupabaseService.client;

  Future<void> fetchStats() async {
    // Each figure is fetched independently and defaults to 0 on
    // failure, so a missing table (e.g. `projects` not created yet)
    // degrades gracefully instead of blanking the whole dashboard.
    final results = await Future.wait([
      _resolvedReportsCount(),
      _activeProjectsCount(),
      _budgetUtilizedPercent(),
      _barangayAssembliesCount(),
    ]);

    state = DashboardStats(
      resolvedReports: results[0] as int,
      activeProjects: results[1] as int,
      budgetUtilizedPercent: results[2] as double,
      barangayAssemblies: results[3] as int,
      isLoading: false,
    );
  }

  Future<int> _resolvedReportsCount() async {
    try {
      final rows = await _client
          .from('citizen_reports')
          .select('id')
          .eq('status', 'resolved');
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _activeProjectsCount() async {
    try {
      final rows = await _client
          .from('projects')
          .select('id')
          .eq('status', 'active');
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<double> _budgetUtilizedPercent() async {
    try {
      final row = await _client
          .from('municipal_budget')
          .select('total_allocated, total_utilized')
          .order('fiscal_year', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return 0;
      final allocated = (row['total_allocated'] as num?)?.toDouble() ?? 0;
      final utilized = (row['total_utilized'] as num?)?.toDouble() ?? 0;
      if (allocated <= 0) return 0;
      return (utilized / allocated) * 100;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _barangayAssembliesCount() async {
    try {
      final now = DateTime.now();
      final yearStart = DateTime(now.year, 1, 1).toIso8601String();
      final rows = await _client
          .from('barangay_assemblies')
          .select('id')
          .gte('held_at', yearStart);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }
}

final dashboardStatsProvider =
    StateNotifierProvider<DashboardStatsNotifier, DashboardStats>(
  (ref) => DashboardStatsNotifier(),
);