import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/local_storage.dart';
import '../../providers/app_providers.dart';
import '../home/home.dart';

class QuickSettingsSheet extends ConsumerWidget {
  const QuickSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Adaptive colors
    final backgroundColor = isDark ? colorScheme.surface : Colors.white;
    final titleColor = isDark ? colorScheme.onSurface : HomeColors.deepAnchor;
    final textColor = isDark ? colorScheme.onSurface : const Color(0xFF424242);
    final subtitleColor = isDark ? colorScheme.onSurface.withOpacity(0.6) : const Color(0xFF757575);
    final handleColor = isDark ? colorScheme.onSurface.withOpacity(0.2) : Colors.grey[300]!;
    
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
              'Quick Settings',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            SizedBox(height: 20.h),

            // Dark mode toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                settings.isDarkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                color: accentColor,
              ),
              title: Text(
                'Dark Mode',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              subtitle: Text(
                settings.isDarkMode ? 'Dark theme active' : 'Light theme active',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: subtitleColor,
                ),
              ),
              value: settings.isDarkMode,
              activeColor: accentColor,
              onChanged: (val) async {
                ref.read(appSettingsProvider.notifier).toggleDarkMode();
                await LocalStorage.setDarkMode(val);
              },
            ),

            // Notifications toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.notifications_outlined,
                color: accentColor,
              ),
              title: Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              subtitle: Text(
                settings.notificationsEnabled ? 'Enabled' : 'Disabled',
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

/// Helper to show this sheet from anywhere
Future<void> showQuickSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent, // Use container's background
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (_) => const QuickSettingsSheet(),
  );
}