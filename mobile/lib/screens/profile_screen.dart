// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User, LocalStorage;
import 'package:may_laud/providers/auth_provider.dart';
import 'package:may_laud/providers/app_providers.dart';
import 'package:may_laud/providers/content_providers.dart';
import 'package:may_laud/core/local_storage.dart';
import 'package:may_laud/theme/app_colors.dart';

import 'app_features/document/document_tracking_screen.dart';

import 'profile/quick_settings_sheet.dart';
import 'profile/change_photo_sheet.dart';
import 'profile/edit_profile_sheet.dart';
import 'profile/privacy_security_sheet.dart';
import 'profile/notification_preferences_sheet.dart';
import 'profile/help_support_sheet.dart';
import 'profile/about_milaud_sheet.dart';
import 'otp_verification/forgot_password_otp_screen.dart';

// Brand colors now sourced from AppColors — no local duplication needed.

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
          child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(colors),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            sliver: SliverList(
                delegate: SliverChildListDelegate([
              SizedBox(height: 12.h),
              _buildProfileHeaderCard(user),
              SizedBox(height: 20.h),
              _buildStatsRow(colors),
              SizedBox(height: 20.h),
              _buildPersonalInfoCard(user, colors),
              SizedBox(height: 20.h),
              _buildAccountActionsCard(user, colors),
              SizedBox(height: 20.h),
              _buildAppSettingsCard(colors),
              SizedBox(height: 24.h),
              _buildLogoutButton(),
              SizedBox(height: 40.h),
            ])),
          ),
        ],
      )),
    );
  }

  Widget _buildAppBar(AppColorScheme colors) => SliverAppBar(
        pinned: true,
        floating: false,
        automaticallyImplyLeading: false,
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text('My Profile',
            style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                letterSpacing: -.5)),
        actions: [
          IconButton(
              onPressed: () => showQuickSettingsSheet(context),
              icon: Icon(Icons.settings_outlined,
                  size: 22.sp, color: AppColors.heritagePurple)),
          SizedBox(width: 4.w),
        ],
      );

  // Gradient header — unchanged in both modes (intentional brand element)
  Widget _buildProfileHeaderCard(User? user) {
    final name = user?.name ?? 'Resident';
    final memberYear = user?.createdAt?.year.toString() ?? '2022';
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
              color: AppColors.heritagePurple.withValues(alpha: .3),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(children: [
        Stack(children: [
          Container(
            width: 90.w,
            height: 90.w,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: .15),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]),
            child: CircleAvatar(
              radius: 45.r,
              backgroundColor: Colors.white.withValues(alpha: .15),
              backgroundImage: user?.profileImage != null
                  ? NetworkImage(user!.profileImage!)
                  : null,
              child: user?.profileImage == null
                  ? Icon(Icons.person, size: 48.sp, color: Colors.white)
                  : null,
            ),
          ),
          Positioned(
              bottom: 0,
              right: 0,
              child: InkWell(
                onTap: () => showChangePhotoSheet(context),
                child: Container(
                  width: 30.w,
                  height: 30.w,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.white),
                  child: Icon(Icons.camera_alt_rounded,
                      size: 16.sp, color: AppColors.heritagePurple),
                ),
              )),
        ]),
        SizedBox(height: 16.h),
        Text(name,
            style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -.3)),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(20.r)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.email_outlined, size: 15.sp, color: Colors.white70),
            SizedBox(width: 6.w),
            Text(user?.email ?? '',
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: .3)),
          ]),
        ),
        SizedBox(height: 6.h),
        Text('Member since $memberYear',
            style: TextStyle(fontSize: 13.sp, color: Colors.white60)),
      ]),
    );
  }

  Widget _buildStatsRow(AppColorScheme colors) {
    final docStats = ref.watch(documentRequestStatsProvider);
    return Row(children: [
      _statCard(Icons.description_outlined, '${docStats['total']}',
          'Total\nRequests', AppColors.heritagePurple, colors,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DocumentTrackingScreen()))),
      SizedBox(width: 12.w),
      _statCard(Icons.check_circle_outline, '${docStats['approved']}',
          'Approved', AppColors.successAlt, colors),
      SizedBox(width: 12.w),
      _statCard(Icons.hourglass_bottom_outlined, '${docStats['pending']}',
          'Pending', AppColors.warningAlt, colors),
    ]);
  }

  Widget _statCard(IconData icon, String value, String label, Color color,
      AppColorScheme colors,
      {VoidCallback? onTap}) {
    return Expanded(
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16.r),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 12.w),
              decoration: BoxDecoration(
                color: colors.cardSurface,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: .04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(children: [
                Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: .1)),
                    child: Icon(icon, size: 22.sp, color: color)),
                SizedBox(height: 10.h),
                Text(value,
                    style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary)),
                SizedBox(height: 2.h),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textMuted,
                        height: 1.3)),
              ]),
            )));
  }

  Widget _buildPersonalInfoCard(User? user, AppColorScheme colors) {
    return _buildCard(
      'Personal Information',
      colors,
      trailing: TextButton.icon(
        onPressed: () async {
          if (_isEditing) {
            setState(() => _isEditing = false);
          } else {
            final saved = await showEditProfileSheet(context, user);
            if (saved == true && mounted) setState(() => _isEditing = false);
          }
        },
        icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined, size: 18.sp),
        label: Text(_isEditing ? 'Cancel' : 'Edit',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
      ),
      children: [
        _infoRow(Icons.person_outline, 'Full Name', user?.name ?? '—', colors),
        _infoRow(Icons.email_outlined, 'Email', user?.email ?? '—', colors),
        _infoRow(Icons.phone_outlined, 'Phone', user?.phone ?? '—', colors),
        _infoRow(Icons.location_on_outlined, 'Address', user?.address ?? '—',
            colors),
      ],
    );
  }

  Widget _infoRow(
      IconData icon, String label, String value, AppColorScheme colors) {
    return Padding(
        padding: EdgeInsets.only(bottom: 16.h),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                  color: AppColors.heritagePurple.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10.r)),
              child: Icon(icon, size: 20.sp, color: AppColors.heritagePurple)),
          SizedBox(width: 14.w),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textMuted,
                        letterSpacing: .2)),
                SizedBox(height: 2.h),
                Text(value,
                    style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        height: 1.4)),
              ])),
        ]));
  }

  // FIX — this used to jump straight to CreateNewPasswordScreen (the same
  // screen the OTP-verified forgot-password flow lands on), skipping the
  // OTP step entirely. Anyone with the phone unlocked and the app open
  // could silently take over the account's password — no re-verification
  // of any kind. Now it sends the same recovery code used by "Forgot
  // Password" and requires it before letting the new-password form show,
  // whether the request came from a signed-in session or not.
  Future<void> _startChangePassword(User? user) async {
    final email = user?.email;
    if (email == null || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Could not find your account email. Please try again later.')),
      );
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpVerificationScreen(email: email)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Could not send a verification code. Please try again.')),
      );
    }
  }

  Widget _buildAccountActionsCard(User? user, AppColorScheme colors) =>
      _buildCard('Account', colors, children: [
        _actionTile(
            Icons.receipt_long_outlined,
            'My Document Requests',
            'Track your requests in real time',
            () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DocumentTrackingScreen())),
            colors),
        _actionTile(
            Icons.edit_outlined,
            'Edit Profile',
            'Update your personal information',
            () => showEditProfileSheet(context, user),
            colors),
        _actionTile(
            Icons.lock_outline,
            'Change Password',
            'Secure your account with a new password',
            () => _startChangePassword(user),
            colors),
        _actionTile(
            Icons.security_outlined,
            'Privacy & Security',
            'Manage your data and account security',
            () => showPrivacySecuritySheet(context),
            colors),
      ]);

  Widget _buildAppSettingsCard(AppColorScheme colors) {
    final settings = ref.watch(appSettingsProvider);
    return _buildCard('App Settings', colors, children: [
      _actionTile(
          Icons.notifications_outlined,
          'Notification Preferences',
          'Manage alerts and push notifications',
          () => showNotificationPreferencesSheet(context),
          colors),
      // Dark mode inline toggle
      Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
          child: Row(children: [
            Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                    color: AppColors.heritagePurple.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12.r)),
                child: Icon(
                    settings.isDarkMode
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    size: 22.sp,
                    color: AppColors.heritagePurple)),
            SizedBox(width: 14.w),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Dark Mode',
                      style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary)),
                  SizedBox(height: 2.h),
                  Text(
                      settings.isDarkMode
                          ? 'Dark theme active'
                          : 'Light theme active',
                      style:
                          TextStyle(fontSize: 13.sp, color: colors.textMuted)),
                ])),
            Switch(
              value: settings.isDarkMode,
              activeColor: AppColors.heritagePurple,
              onChanged: (val) async {
                ref.read(appSettingsProvider.notifier).toggleDarkMode();
                await LocalStorage.setDarkMode(val);
              },
            ),
          ])),
      _actionTile(
          Icons.help_outline,
          'Help & Support',
          'FAQs, guides, and contact support',
          () => showHelpSupportSheet(context),
          colors),
      _actionTile(
          Icons.info_outline,
          'About Maylaud',
          'App version, terms, and privacy policy',
          () => showAboutMilaudSheet(context),
          colors,
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
                color: AppColors.heritagePurple.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(8.r)),
            child: Text('v1.0.0',
                style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.heritagePurple)),
          )),
    ]);
  }

  Widget _actionTile(IconData icon, String title, String subtitle,
      VoidCallback onTap, AppColorScheme colors,
      {Widget? trailing}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 4.w),
          child: Row(children: [
            Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                    color: AppColors.heritagePurple.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(12.r)),
                child:
                    Icon(icon, size: 22.sp, color: AppColors.heritagePurple)),
            SizedBox(width: 14.w),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary)),
                  SizedBox(height: 2.h),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 13.sp, color: colors.textMuted)),
                ])),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    size: 22.sp, color: colors.iconMuted),
          ])),
    );
  }

  Widget _buildCard(String title, AppColorScheme colors,
      {required List<Widget> children, Widget? trailing}) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  letterSpacing: -.3)),
          if (trailing != null) trailing,
        ]),
        SizedBox(height: 16.h),
        ...children,
      ]),
    );
  }

  Widget _buildLogoutButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: OutlinedButton.icon(
        onPressed: _showLogoutConfirmation,
        icon: Icon(Icons.logout_rounded, size: 20.sp),
        label: Text('Logout',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.errorDark,
          side: BorderSide(
              color: AppColors.errorDark.withValues(alpha: 0.35), width: 1.2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          backgroundColor: AppColors.of(context).errorSurface,
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    final userName = ref.read(authProvider).user?.name ?? 'user';
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r)),
              title: Text('Confirm Logout',
                  style:
                      TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700)),
              content: Text(
                  'Are you sure you want to sign out, $userName? You\'ll need to sign in again to access your account.',
                  style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.of(context).textMuted,
                      height: 1.5)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.of(context).textMuted))),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(authProvider.notifier).logout();
                    if (mounted) {
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/', (r) => false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                      padding: EdgeInsets.symmetric(
                          horizontal: 20.w, vertical: 10.h)),
                  child: Text('Logout',
                      style: TextStyle(
                          fontSize: 15.sp, fontWeight: FontWeight.w600)),
                ),
              ],
            ));
  }
}
