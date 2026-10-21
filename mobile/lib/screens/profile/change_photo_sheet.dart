import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../home/home.dart';

class ChangePhotoSheet extends StatelessWidget {
  const ChangePhotoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Adaptive colors (backgrounds, text)
    final backgroundColor = isDark ? colorScheme.surface : Colors.white;
    final titleColor = isDark ? colorScheme.onSurface : HomeColors.deepAnchor;
    final subtitleColor = isDark ? colorScheme.onSurface.withOpacity(0.6) : const Color(0xFF9E9E9E);
    final handleColor = isDark ? colorScheme.onSurface.withOpacity(0.2) : Colors.grey[300]!;
    final borderColor = isDark ? colorScheme.onSurface.withOpacity(0.15) : Colors.grey[200]!;
    
    // Fixed purple accent – same as ProfileScreen
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
              'Change Profile Photo',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Profile photo upload requires camera/gallery permissions. '
              'This feature connects to Supabase Storage when permissions are granted.',
              style: TextStyle(
                fontSize: 13.sp,
                color: subtitleColor,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24.h),
            _optionTile(
              context: context,
              icon: Icons.camera_alt_outlined,
              label: 'Take a photo',
              accentColor: accentColor,
              titleColor: titleColor,
              borderColor: borderColor,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'Camera access not yet configured on this build.'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    margin: EdgeInsets.all(12.w),
                  ),
                );
              },
            ),
            SizedBox(height: 12.h),
            _optionTile(
              context: context,
              icon: Icons.photo_library_outlined,
              label: 'Choose from gallery',
              accentColor: accentColor,
              titleColor: titleColor,
              borderColor: borderColor,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'Gallery access not yet configured on this build.'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    margin: EdgeInsets.all(12.w),
                  ),
                );
              },
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

  Widget _optionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color accentColor,
    required Color titleColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Icon(icon, color: accentColor, size: 22.sp),
            SizedBox(width: 14.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper to show this sheet from anywhere
Future<void> showChangePhotoSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent, // Use container's background
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (_) => const ChangePhotoSheet(),
  );
}