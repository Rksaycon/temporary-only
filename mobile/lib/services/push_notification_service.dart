// lib/services/push_notification_service.dart
//
// Wraps Firebase Cloud Messaging + flutter_local_notifications so the
// rest of the app only ever talks to PushNotificationService, never to
// FirebaseMessaging directly.
//
// Wiring:
//   1. main.dart calls Firebase.initializeApp(...) and registers
//      firebaseMessagingBackgroundHandler BEFORE runApp().
//   2. main.dart (or the first authenticated screen) calls
//      PushNotificationService.instance.init() once.
//   3. auth_provider.dart calls syncTokenWithSupabase() after a user is
//      known (login / session restore / registration) and
//      clearTokenOnLogout() before signing out.
//
// The device's FCM token is stored on profiles.fcm_token. Actually
// *sending* a push (e.g. when an admin publishes an announcement, or a
// document request's status changes) happens server-side — see the
// Supabase Edge Function example that ships alongside this file.

import 'dart:async';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'supabase_service.dart';

/// Must be a top-level (or static) function — FCM runs it in a separate
/// background isolate that shares no state with the running app, so it
/// re-initializes Firebase itself.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
      '[PushNotificationService] Background message: ${message.messageId} '
      '${message.notification?.title}');
  // Nothing else to do here — Android/iOS already show the system
  // notification for a background push automatically when the payload
  // has a `notification` block. This handler exists mainly for
  // data-only pushes / analytics hooks you might add later.
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'milaud_default_channel', // must match AndroidManifest.xml meta-data
    'General Notifications',
    description:
        'Announcements, document request updates, and alerts from Maylaud.',
    importance: Importance.high,
  );

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Fired when the user taps a notification — a foreground one shown by
  /// flutter_local_notifications, or one that opened the app from the
  /// background/terminated state. `data` is the FCM message's data payload
  /// (e.g. {'type': 'document_request', 'document_request_id': '...'}), so the
  /// caller can decide where to navigate.
  ///
  /// A tap can arrive BEFORE the app wires this handler: on a cold start
  /// `main()` calls init() (which runs getInitialMessage()) before runApp(),
  /// so the very tap that launched the app is processed while this is still
  /// null. Rather than dropping it, the last tap is buffered and delivered the
  /// moment a handler is assigned.
  void Function(Map<String, dynamic> data)? get onNotificationTap =>
      _onNotificationTap;
  set onNotificationTap(void Function(Map<String, dynamic> data)? handler) {
    _onNotificationTap = handler;
    final pending = _pendingTap;
    if (handler != null && pending != null) {
      _pendingTap = null;
      handler(pending);
    }
  }

  void Function(Map<String, dynamic> data)? _onNotificationTap;
  Map<String, dynamic>? _pendingTap;

  /// Delivers a tap to the registered handler, or buffers it if none is set
  /// yet (see [onNotificationTap]).
  void _emitTap(Map<String, dynamic> data) {
    final handler = _onNotificationTap;
    if (handler != null) {
      handler(data);
    } else {
      _pendingTap = data;
    }
  }

  /// Fired whenever a push is received while the app is running
  /// (foreground) or just opened one — a good hook to refresh
  /// `notificationsProvider` from Supabase, which stays the source of
  /// truth for the in-app notification list.
  VoidCallback? onMessageReceived;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _setUpLocalNotifications();

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
        '[PushNotificationService] Permission: ${settings.authorizationStatus}');

    // iOS: without this, foreground pushes are received silently (no
    // banner/sound) — Apple's default assumes you'll show your own UI.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // App was fully terminated and got launched by tapping a push.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleMessageOpenedApp(initialMessage);

    _messaging.onTokenRefresh.listen(_saveTokenToSupabase);
  }

  Future<void> _setUpLocalNotifications() async {
    // FIX — was '@mipmap/ic_launcher': the full-color app launcher icon.
    // Android's status bar refuses to render a color icon like that — on
    // Android 5-7 it silently falls back to a plain white/gray square,
    // and even on newer versions it looks wrong next to every other
    // app's monochrome status-bar icon. The fix is a dedicated small
    // white-silhouette-on-transparent PNG per density, placed at
    // android/app/src/main/res/mipmap-*/ic_stat_notification.png (a
    // ready-made set is provided alongside this change — see
    // notification_icon_android_res.zip), referenced here by name
    // without the extension. `color:` below is what actually tints the
    // silhouette so it matches the brand instead of coming out flat
    // white/gray, which is the other half of "the icon doesn't work" —
    // a bare white silhouette with no color still looks broken.
    const androidInit = AndroidInitializationSettings('ic_stat_notification');
    const iosInit = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final type = response.payload;
        if (type != null) _emitTap({'type': type});
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  /// Android/iOS do NOT show a system banner for a foreground push on
  /// their own — this builds one manually via flutter_local_notifications
  /// so foreground behaves the same as background.
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_notification',
            // Brand purple — matches the header gradient used everywhere
            // else in the app (see AppColors.heritagePurple). Without an
            // explicit color, a monochrome status-bar icon renders flat
            // white/gray, which reads as broken.
            color: const Color(0xFF4C229C),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['type'] as String?,
      );
    }
    onMessageReceived?.call();
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    _emitTap(message.data);
    onMessageReceived?.call();
  }

  /// Fetches this device's current FCM token and, if a user is signed
  /// in, stores it on their Supabase profile. Call after login,
  /// registration, or session restore.
  ///
  /// Android only for now — no iOS app is registered in Firebase yet.
  /// If iOS support is added later, request the APNs token first
  /// (`await _messaging.getAPNSToken()`) before calling `getToken()`,
  /// since FCM won't hand back a token on iOS until that exists.
  Future<void> syncTokenWithSupabase() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveTokenToSupabase(token);
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to fetch token: $e');
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', uid);
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to save token: $e');
    }
  }

  /// Call on logout, BEFORE signing out, so a stale token isn't left
  /// pointing at a device that's no longer this user.
  Future<void> clearTokenOnLogout() async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'fcm_token': null})
          .eq('id', uid);
    } catch (_) {}
  }
}