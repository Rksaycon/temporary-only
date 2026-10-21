import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../providers/app_providers.dart';
import '../home/home.dart';

class NotificationPreferencesSheet extends ConsumerWidget {
  const NotificationPreferencesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final backgroundColor = isDark ? colorScheme.surface : Colors.white;
    final titleColor = isDark ? colorScheme.onSurface : HomeColors.deepAnchor;
    final subtitleColor = isDark ? colorScheme.onSurface.withOpacity(0.6) : const Color(0xFF757575);
    final textColor = isDark ? colorScheme.onSurface : const Color(0xFF424242);
    final handleColor = isDark ? colorScheme.onSurface.withOpacity(0.2) : Colors.grey[300]!;
    final dividerColor = isDark ? colorScheme.onSurface.withOpacity(0.12) : const Color(0xFFE0E0E0);
    
    // Fixed purple accent – matches ProfileScreen
    final accentColor = HomeColors.heritagePurple;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHandle(handleColor),
            SizedBox(height: 20.h),
            Text(
              'Notification Preferences',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            SizedBox(height: 20.h),

            // Master toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.notifications_outlined,
                color: accentColor,
              ),
              title: Text(
                'All Notifications',
                style: TextStyle(
                  fontSize: 15.sp, 
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              subtitle: Text(
                settings.notificationsEnabled ? 'On' : 'Off',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: subtitleColor,
                ),
              ),
              value: settings.notificationsEnabled,
              activeColor: accentColor,
              onChanged: (_) =>
                  ref.read(appSettingsProvider.notifier).toggleNotifications(),
            ),

            Divider(color: dividerColor, height: 24.h),

            // Per-category rows
            _NotifSubTile(
              title: 'Flood Alerts',
              icon: Icons.water_outlined,
              subtitle: 'Critical disaster warnings',
              defaultVal: true,
            ),
            _NotifSubTile(
              title: 'Announcements',
              icon: Icons.campaign_outlined,
              subtitle: 'Barangay news and updates',
              defaultVal: true,
            ),
            _NotifSubTile(
              title: 'Document Updates',
              icon: Icons.description_outlined,
              subtitle: 'Request status changes',
              defaultVal: true,
            ),
            _NotifSubTile(
              title: 'General',
              icon: Icons.info_outline,
              subtitle: 'App updates and reminders',
              defaultVal: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(Color color) {
    return Center(
      child: Container(
        width: 40.w,
        height: 4.h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2.r),
        ),
      ),
    );
  }
}

/// Individual sub-toggle row with its own local state
class _NotifSubTile extends StatefulWidget {
  final String title;
  final IconData icon;
  final String subtitle;
  final bool defaultVal;

  const _NotifSubTile({
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.defaultVal,
  });

  @override
  State<_NotifSubTile> createState() => _NotifSubTileState();
}

class _NotifSubTileState extends State<_NotifSubTile> {
  late bool _val;

  @override
  void initState() {
    super.initState();
    _val = widget.defaultVal;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    
    final accentColor = HomeColors.heritagePurple;
    final iconColor = isDark ? colorScheme.onSurface.withOpacity(0.5) : const Color(0xFF9E9E9E);
    final titleColor = isDark ? colorScheme.onSurface : const Color(0xFF424242);
    final subtitleColor = isDark ? colorScheme.onSurface.withOpacity(0.6) : const Color(0xFF757575);

    return SwitchListTile(
      contentPadding: EdgeInsets.only(left: 8.w),
      secondary: Icon(
        widget.icon,
        size: 20.sp,
        color: iconColor,
      ),
      title: Text(
        widget.title,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        widget.subtitle,
        style: TextStyle(
          fontSize: 12.sp,
          color: subtitleColor,
        ),
      ),
      value: _val,
      activeColor: accentColor,
      onChanged: (v) => setState(() => _val = v),
    );
  }
}

/// Helper to show this sheet from anywhere
Future<void> showNotificationPreferencesSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent, // Use our container's background
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (_) => const NotificationPreferencesSheet(),
  );
}