import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:may_laud/providers/app_providers.dart';
import 'package:may_laud/theme/app_colors.dart';
import 'home.dart';
import '../app_features/announcement/announcements_list_screen.dart';
import '../app_features/report/citizen_report_screen.dart';
import '../app_features/flood_alert/flood_alert_screen.dart';
import '../app_features/emergency/hotlines_screen.dart';
import '../app_features/document/document_request_screen.dart';
import '../app_features/document/document_tracking_screen.dart';
import '../app_features/report/report_history_screen.dart';
import '../notifications_screen.dart';
import '../profile_screen.dart';

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});
  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  // FIX — this used to be private widget state (`_selectedIndex`), so
  // nothing outside MainApp could switch tabs. The home screen's bell
  // icon needs to jump straight to the Notifications tab, so the
  // selected index now lives in `bottomNavProvider` (already declared
  // in app_providers.dart, but previously unused) — any screen can read
  // or set it via `ref`.
  int get _selectedIndex => ref.watch(bottomNavProvider);

  late final List<Widget> _screens = [
    const HomeScreen(),
    const AnnouncementsListScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  static final List<_QuickService> _services = [
    _QuickService(Icons.report_problem_rounded, 'Citizen Report',   'Report issues or concerns',    CitizenReportScreen()),
    _QuickService(Icons.warning_rounded,         'Flood Alert',      'Disaster alerts & updates',    FloodAlertScreen()),
    _QuickService(Icons.phone_rounded,           'Milaor Hotlines',  'Emergency contacts',           HotlinesScreen()),
    _QuickService(Icons.description_rounded,     'Document Request', 'Barangay clearance, permits',  DocumentRequestScreen()),
    _QuickService(Icons.track_changes_rounded,   'My Requests',      'Track requests in real time',  DocumentTrackingScreen()),
    _QuickService(Icons.history_rounded,         'My Reports',       'Track reports in real time',   ReportHistoryScreen()),
  ];

  void _onItemTapped(int i) => ref.read(bottomNavProvider.notifier).state = i;

  void _openService(BuildContext ctx, _QuickService s) {
    Navigator.pop(ctx);
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => s.screen));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      floatingActionButton: Container(
        width: 72.w, height: 72.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [AppColors.riverFlow, AppColors.heritagePurple]),
          boxShadow: [BoxShadow(color: AppColors.heritagePurple.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 10))],
        ),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: Colors.transparent,
          onPressed: () => _showQuickServices(context),
          child: Icon(Icons.miscellaneous_services, color: Colors.white, size: 34.sp),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(colors),
    );
  }

  Widget _buildBottomNav(AppColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [BoxShadow(color: AppColors.heritagePurple.withValues(alpha: .08), blurRadius: 24, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          height: 100.h,
          child: BottomAppBar(
            color: Colors.transparent, elevation: 0,
            shape: const CircularNotchedRectangle(), notchMargin: 8,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(Icons.home_rounded,              'Home',          0, colors),
                  _navItem(Icons.campaign_outlined,         'Announcements', 1, colors),
                  SizedBox(width: 44.w),
                  _navItem(Icons.notifications_outlined,    'Notifications', 2, colors),
                  _navItem(Icons.person_outline_rounded,    'Profile',       3, colors),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, AppColorScheme colors) {
    final active = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: () => _onItemTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic,
              margin: EdgeInsets.only(bottom: active ? 2.h : 0),
              width: active ? 32.w : 0, height: 3.h,
              decoration: BoxDecoration(color: AppColors.heritagePurple, borderRadius: BorderRadius.circular(10.r)),
            ),
            Icon(icon, size: active ? 23.sp : 21.sp, color: active ? AppColors.heritagePurple : colors.iconMuted),
            SizedBox(height: 2.h),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic,
              style: TextStyle(fontSize: 10.sp, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.heritagePurple : colors.iconMuted, letterSpacing: active ? .2 : 0),
              child: Text(label),
            ),
          ]),
        ),
      ),
    );
  }

  void _showQuickServices(BuildContext context) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 36.h),
        decoration: BoxDecoration(
          color: colors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40.w, height: 4.h,
            decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(20.r)),
          ),
          SizedBox(height: 24.h),
          Row(children: [
            Container(
              width: 42.w, height: 42.w,
              decoration: BoxDecoration(color: AppColors.heritagePurple.withValues(alpha: .1), borderRadius: BorderRadius.circular(12.r)),
              child: Icon(Icons.miscellaneous_services_rounded, size: 22.sp, color: AppColors.heritagePurple),
            ),
            SizedBox(width: 14.w),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Public Services', style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: colors.textPrimary)),
              Text('Choose a service below', style: TextStyle(fontSize: 13.sp, color: colors.textMuted)),
            ]),
          ]),
          SizedBox(height: 24.h),
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, mainAxisSpacing: 14.h, crossAxisSpacing: 14.w, childAspectRatio: 1.05,
            children: _services.map((s) => _serviceTile(context, s, colors)).toList(),
          ),
        ]),
      ),
    );
  }

  Widget _serviceTile(BuildContext ctx, _QuickService s, AppColorScheme colors) {
    return InkWell(
      borderRadius: BorderRadius.circular(20.r),
      onTap: () => _openService(ctx, s),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: colors.background, borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.heritagePurple.withValues(alpha: .08)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 56.w, height: 56.w,
            decoration: BoxDecoration(
              color: colors.surface, borderRadius: BorderRadius.circular(16.r),
              boxShadow: [BoxShadow(color: AppColors.heritagePurple.withValues(alpha: .08), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Icon(s.icon, size: 28.sp, color: AppColors.heritagePurple),
          ),
          SizedBox(height: 12.h),
          Text(s.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary, height: 1.2)),
          SizedBox(height: 4.h),
          Text(s.subtitle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.sp, height: 1.2, color: colors.textMuted)),
        ]),
      ),
    );
  }
}

class _QuickService {
  final IconData icon; final String title, subtitle; final Widget screen;
  const _QuickService(this.icon, this.title, this.subtitle, this.screen);
}