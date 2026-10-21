// ignore_for_file: unused_local_variable

import 'package:may_laud/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../providers/app_providers.dart';

class PrivacySecuritySheet extends ConsumerWidget {
  const PrivacySecuritySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final backgroundColor = AppColors.of(context).surface;
    final titleColor = AppColors.of(context).textPrimary;
    final subtitleColor = AppColors.of(context).textMuted;
    final textColor = AppColors.of(context).textSecondary;
    final handleColor = AppColors.of(context).border;
    final dividerColor = AppColors.of(context).divider;
    final footnoteColor = AppColors.of(context).textMuted;
    final chevronColor = AppColors.of(context).iconMuted;

    // Fixed purple accent – matches ProfileScreen
    final accentColor = AppColors.of(context).accentPurple;

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
              'Privacy & Security',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            SizedBox(height: 20.h),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.location_on_outlined,
                color: accentColor,
              ),
              title: Text(
                'Location Access',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              subtitle: Text(
                settings.locationEnabled
                    ? 'Enabled — used for flood zone detection'
                    : 'Disabled',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: subtitleColor,
                ),
              ),
              value: settings.locationEnabled,
              activeColor: accentColor,
              onChanged: (_) =>
                  ref.read(appSettingsProvider.notifier).toggleLocation(),
            ),
            Divider(color: dividerColor, height: 24.h),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.errorDark,
              ),
              title: Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.errorDark,
                ),
              ),
              subtitle: Text(
                'Permanently remove your data',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: subtitleColor,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                size: 22.sp,
                color: chevronColor,
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteAccountDialog(context);
              },
            ),
            SizedBox(height: 8.h),
            Text(
              'Your data is securely stored and never shared with third parties without your consent.',
              style: TextStyle(
                fontSize: 12.sp,
                color: footnoteColor,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final dialogBgColor = AppColors.of(context).surface;
    final textColor = AppColors.of(context).textSecondary;
    final cancelTextColor = AppColors.of(context).textMuted;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          'Delete Account',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.errorDark,
          ),
        ),
        content: Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.',
          style: TextStyle(
            fontSize: 14.sp,
            color: textColor,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: cancelTextColor,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorDark,
              foregroundColor: AppColors.neutralWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                      'Account deletion requires admin approval. Contact support.'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  margin: EdgeInsets.all(12.w),
                ),
              );
            },
            child: Text(
              'Delete',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
Future<void> showPrivacySecuritySheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent, // Use our container's background
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (_) => const PrivacySecuritySheet(),
  );
}
