import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../home/home.dart';

class AboutMilaudSheet extends StatelessWidget {
  const AboutMilaudSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Adaptive backgrounds (same as ProfileScreen cards)
    final backgroundColor = isDark ? colorScheme.surface : Colors.white;
    final titleColor = isDark ? colorScheme.onSurface : HomeColors.deepAnchor;
    final subtitleColor = isDark ? colorScheme.onSurface.withOpacity(0.6) : const Color(0xFF757575);
    final bodyTextColor = isDark ? colorScheme.onSurface.withOpacity(0.8) : const Color(0xFF424242);
    final dividerColor = isDark ? colorScheme.onSurface.withOpacity(0.12) : const Color(0xFFE0E0E0);
    final handleColor = isDark ? colorScheme.onSurface.withOpacity(0.3) : Colors.grey[300]!;
    
    // Fixed purple – matches ProfileScreen's icon color everywhere
    final fixedAccent = HomeColors.heritagePurple;

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

            // App identity row
            Row(
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: fixedAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(
                    Icons.account_balance_outlined,
                    color: fixedAccent,
                    size: 28.sp,
                  ),
                ),
                SizedBox(width: 16.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maylaud',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 20.h),
            Text(
              'Maylaud is a participatory governance mobile application designed for Milaor, Camarines Sur residents. It provides real-time announcements, citizen reporting, emergency alerts, document requests, and AI-powered assistance — all in one platform.',
              style: TextStyle(
                fontSize: 13.sp,
                color: bodyTextColor,
                height: 1.6,
              ),
            ),

            SizedBox(height: 20.h),
            _aboutRow(
              icon: Icons.code_outlined,
              label: 'Built with',
              value: 'Flutter + Supabase',
              iconColor: fixedAccent,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
            ),
            SizedBox(height: 10.h),
            _aboutRow(
              icon: Icons.location_city_outlined,
              label: 'Municipality',
              value: 'Milaor, Camarines Sur',
              iconColor: fixedAccent,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
            ),
            SizedBox(height: 10.h),
            _aboutRow(
              icon: Icons.school_outlined,
              label: 'Purpose',
              value: 'Academic Final Defense Project',
              iconColor: fixedAccent,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
            ),

            SizedBox(height: 20.h),
            Divider(color: dividerColor, height: 1),
            SizedBox(height: 12.h),
            Text(
              'This application is developed for academic purposes. All resident data is stored securely and used solely for governance services.',
              style: TextStyle(
                fontSize: 12.sp,
                color: subtitleColor,
                height: 1.5,
              ),
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

  Widget _aboutRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: iconColor),
        SizedBox(width: 10.w),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: subtitleColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
      ],
    );
  }
}

/// Helper to show this sheet from anywhere
Future<void> showAboutMilaudSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (_) => const AboutMilaudSheet(),
  );
}