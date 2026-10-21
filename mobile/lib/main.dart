import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:may_laud/core/local_storage.dart';
import 'package:may_laud/core/performance_optimization.dart';
import 'package:may_laud/firebase_options.dart';
import 'package:may_laud/providers/app_providers.dart';
import 'package:may_laud/providers/app_theme_provider.dart';
import 'package:may_laud/providers/content_providers.dart';
import 'package:may_laud/screens/app_features/document/document_tracking_screen.dart';
import 'package:may_laud/screens/app_features/document/document_request_modal.dart';
import 'package:may_laud/screens/app_features/report/report_history_screen.dart';
import 'package:may_laud/screens/intro_pages/opening_milaud.dart';
import 'package:may_laud/screens/home/nav_bar_button.dart';
import 'package:may_laud/services/push_notification_service.dart';
import 'package:may_laud/services/supabase_service.dart';
import 'theme/app_theme.dart';

/// Global navigator key so a tapped push notification can navigate even
/// when it arrives outside a widget's BuildContext (e.g. app was
/// terminated and just launched).
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseService.init();
  } catch (e) {
    debugPrint('[SupabaseService] Failed to initialize: $e');
  }

  // Pull the admin's published brand palette before the first frame so the app
  // opens already wearing it (and the realtime provider below starts from the
  // same values, so it won't immediately remount).
  try {
    AppThemeService.apply(await AppThemeService.fetch());
  } catch (e) {
    debugPrint('[AppThemeService] Failed to load the brand palette: $e');
  }

  try {
    await LocalStorage.init();
  } catch (e) {
    debugPrint('[LocalStorage] Failed to initialize: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Must be registered before runApp() so FCM can deliver background
    // messages even if the app isn't currently running.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushNotificationService.instance.init();
  } catch (e) {
    debugPrint('[PushNotificationService] Failed to initialize: $e');
  }

  PerformanceOptimization.configureImageCache();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  /// Guards against stacking a second document-request sheet when a realtime
  /// update and a push land (or several requests change) at the same moment.
  bool _documentModalVisible = false;

  @override
  void initState() {
    super.initState();
    // Wire push callbacks once we have a WidgetRef/navigator to act on.
    // Guarded the same way as the Firebase.initializeApp() call in main():
    // PushNotificationService.instance internally touches
    // FirebaseMessaging.instance, which throws if Firebase never actually
    // initialized (e.g. running on web, where this app's Firebase project
    // isn't configured yet — see DefaultFirebaseOptions.currentPlatform).
    // Without this guard, that throw happens during the very first widget
    // build and takes the whole app down instead of just disabling push.
    try {
      PushNotificationService.instance.onMessageReceived = () {
        // Supabase stays the source of truth for the in-app list —
        // just re-pull it whenever a push comes in or is opened.
        ref.read(notificationsProvider.notifier).fetchNotifications();
        // A push also means a document request may have changed status while
        // the app was backgrounded (which is exactly when the realtime socket
        // is closed), so re-pull the tracker too — the resident never has to
        // refresh by hand.
        ref.read(documentRequestsProvider.notifier).fetchRequests();
        // Same for citizen reports: a "your report was reviewed/solved" push
        // means the history list may be stale for the same reason.
        ref.read(citizenReportsProvider.notifier).fetchReports();
      };
      PushNotificationService.instance.onNotificationTap = (data) {
        // A document-request status change opens the request in a modal
        // (falling back to the tracker if the row isn't loaded yet);
        // a citizen-report status change opens the report history / detail;
        // anything else lands on the main app and deep-links from there.
        if (data['type'] == 'document_request') {
          _openDocumentRequestFromPush(data);
          return;
        }
        if (data['type'] == 'citizen_report') {
          _openReportHistoryFromPush(data);
          return;
        }
        navigatorKey.currentState?.pushNamed('/main');
      };
    } catch (e) {
      debugPrint('[PushNotificationService] Callback wiring skipped: $e');
    }
  }

  /// Opens the document request referenced by a tapped push. The push payload
  /// only carries the id (see supabase/functions/push), so re-pull the
  /// resident's requests first — then surface the fresh row in the modal.
  Future<void> _openDocumentRequestFromPush(Map<String, dynamic> data) async {
    final id = data['document_request_id']?.toString();
    try {
      await ref.read(documentRequestsProvider.notifier).fetchRequests();
    } catch (_) {}
    if (!mounted) return;

    DocumentRequest? match;
    if (id != null) {
      for (final r in ref.read(documentRequestsProvider)) {
        if (r.id == id) {
          match = r;
          break;
        }
      }
    }

    if (match != null) {
      _showDocumentRequestModal(match, highlightUpdate: true);
    } else {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const DocumentTrackingScreen()),
      );
    }
  }

  /// Opens the citizen report referenced by a tapped push (payload keys come
  /// from citizen_reports_notify_status_change in the SQL: `report_id`,
  /// `status`, `reference`). Re-pull the resident's history first — the push
  /// most likely arrived from a backgrounded/closed app where the realtime
  /// socket was down — then surface the fresh row's detail screen, falling
  /// back to the history list when the row can't be matched.
  Future<void> _openReportHistoryFromPush(Map<String, dynamic> data) async {
    final id = data['report_id']?.toString();
    try {
      await ref.read(citizenReportsProvider.notifier).fetchReports();
    } catch (_) {}
    if (!mounted) return;

    CitizenReport? match;
    if (id != null) {
      for (final r in ref.read(citizenReportsProvider)) {
        if (r.id == id) {
          match = r;
          break;
        }
      }
    }

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => match != null
            ? ReportHistoryDetailScreen(report: match)
            : const ReportHistoryScreen(),
      ),
    );
  }

  /// Shows the document-request modal, deferred to the next frame because it
  /// can be triggered from a Riverpod `ref.listen` callback (which may run
  /// mid-build) and because the navigator may still be attaching on a cold
  /// start launched by a push.
  void _showDocumentRequestModal(DocumentRequest request,
      {bool highlightUpdate = false}) {
    if (_documentModalVisible) return;
    _documentModalVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (!mounted || ctx == null) {
        _documentModalVisible = false;
        return;
      }
      showDocumentRequestModal(
        ctx,
        request: request,
        highlightUpdate: highlightUpdate,
        onViewDetails: () => navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => DocumentRequestDetailScreen(request: request),
          ),
        ),
      ).whenComplete(() => _documentModalVisible = false);
    });
  }

  /// Pops the document-request modal when an already-known request flips
  /// status — the realtime counterpart to a background push. New requests (an
  /// insert) never trigger it, and at most one sheet is shown per change.
  void _announceStatusChanges(
      List<DocumentRequest> previous, List<DocumentRequest> next) {
    for (final updated in next) {
      DocumentRequest? before;
      for (final r in previous) {
        if (r.id == updated.id) {
          before = r;
          break;
        }
      }
      if (before != null &&
          before.normalizedStatus != updated.normalizedStatus) {
        _showDocumentRequestModal(updated, highlightUpdate: true);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // A live status change — a Supabase Realtime event while the app is open,
    // or the tracker refresh triggered by a foreground push — opens the modal
    // so the resident sees the update without opening the tracker themselves.
    ref.listen<List<DocumentRequest>>(documentRequestsProvider, (previous, next) {
      if (previous == null) return;
      _announceStatusChanges(previous, next);
    });

    // Bumped whenever the admin publishes a new palette. Rebuilding MyApp with
    // a new key remounts the tree, which is what makes every already-built
    // screen repaint with the new AppColors — they're plain statics, so nothing
    // else would rebuild on its own.
    final themeRevision = ref.watch(appThemeRevisionProvider);

    final isDarkMode =
        ref.watch(appSettingsProvider.select((s) => s.isDarkMode));

    return ScreenUtilInit(
      designSize: const Size(430, 932),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          key: ValueKey('maylaud-theme-$themeRevision'),
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Maylaud - Participatory Governance',
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          // A normal launch keeps the onboarding entry point. A live restyle
          // remounts straight back into the app shell so the resident isn't
          // bounced to the opening screen over a color change — the selected
          // bottom-nav tab lives in bottomNavProvider, above this subtree, so
          // it survives too.
          initialRoute: themeRevision == 0 ? '/' : '/main',
          routes: {
            '/': (context) => const OpeningScreen(),
            '/main': (context) => const MainApp(),
          },
        );
      },
    );
  }
}