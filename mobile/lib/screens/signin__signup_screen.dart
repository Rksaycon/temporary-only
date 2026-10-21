import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:may_laud/screens/sign_in/sign_in_screen.dart';
import 'package:may_laud/screens/sign_up/registration_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:may_laud/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  void handleSignIn() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeBackScreen()),
    );
  }

  void handleRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    // Same adaptive palette as sign-in & register screens
    final scaffoldBg = isDark ? cs.background : Colors.white;
    final bubbleBg1 = isDark
        ? cs.primary.withValues(alpha: 0.12)
        : AppColors.heritagePurple.withValues(alpha: 0.08);
    final bubbleBg2Gradient = isDark
        ? [cs.primary.withValues(alpha: 0.10), Colors.transparent]
        : [
            AppColors.heritagePurple.withValues(alpha: 0.35),
            Colors.transparent
          ];
    final bubbleBg3Gradient = isDark
        ? [cs.primary.withValues(alpha: 0.12), Colors.transparent]
        : [AppColors.heritagePurple.withValues(alpha: 0.4), Colors.transparent];
    final titleColor = isDark ? cs.onSurface : AppColors.deepAnchor;
    final subtitleColor = isDark
        ? cs.onSurface.withValues(alpha: 0.6)
        : AppColors.of(context).textMuted;
    final formBg = isDark ? cs.surface : AppColors.of(context).formSurface;
    final guestBg = isDark ? cs.surface : Colors.white;
    final guestText = isDark ? cs.primary : AppColors.heritagePurple;
    final footerColor = isDark
        ? cs.onSurface.withValues(alpha: 0.45)
        : AppColors.of(context).textMuted;
    final footerLinkColor = isDark
        ? cs.primary.withValues(alpha: 0.8)
        : AppColors.of(context).accentPurple.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // Background decorations — identical to sign-in
          Positioned(
            top: -120.h,
            left: -120.w,
            child: Container(
              width: 280.w,
              height: 280.w,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: bubbleBg1),
            ),
          ),
          Positioned(
            top: 100.h,
            right: -60.w,
            child: Container(
              width: 160.w,
              height: 160.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: bubbleBg2Gradient),
              ),
            ),
          ),
          Positioned(
            bottom: 180.h,
            right: -80.w,
            child: Container(
              width: 180.w,
              height: 180.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: bubbleBg3Gradient),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 240.h,
              width: double.infinity,
              child: CustomPaint(
                painter: _WavePainter(isDark: isDark, cs: cs),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 30.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 30.h),

                  // Logo with glow shadow
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.heritagePurple.withValues(alpha: 0.18),
                          blurRadius: 25.r,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/milaudlogo.png',
                      height: 100.h,
                      fit: BoxFit.contain,
                    ),
                  ),

                  SizedBox(height: 15.h),

                  Text(
                    "Welcome to Maylaud",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  Text(
                    "Sign in to your account or create a new one.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.sp, color: subtitleColor),
                  ),

                  SizedBox(height: 30.h),

                  // Buttons card — same formBg card as sign-in
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: formBg,
                      borderRadius: BorderRadius.circular(28.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.heritagePurple
                              .withValues(alpha: isDark ? 0.05 : 0.08),
                          blurRadius: 20.r,
                          offset: Offset(0, 8.h),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Sign In button
                        GestureDetector(
                          onTap: handleSignIn,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40.r),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.heritagePurple,
                                  AppColors.riverFlow,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.heritagePurple
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12.r,
                                  offset: Offset(0, 4.h),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                "Sign In",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 16.h),

                        // Register button — outline style to differentiate
                        GestureDetector(
                          onTap: handleRegister,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40.r),
                              color: guestBg,
                              border: Border.all(
                                color: isDark
                                    ? cs.primary.withValues(alpha: 0.4)
                                    : AppColors.heritagePurple
                                        .withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.heritagePurple
                                      .withValues(alpha: isDark ? 0.08 : 0.10),
                                  blurRadius: 12.r,
                                  offset: Offset(0, 4.h),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                "Create Account",
                                style: TextStyle(
                                  color: guestText,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30.h),

                  // Footer
                  Text(
                    "By continuing, you agree to our",
                    style: TextStyle(color: footerColor, fontSize: 12.sp),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Terms & Conditions",
                        style: TextStyle(
                          color: footerLinkColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text("•",
                          style:
                              TextStyle(color: footerColor, fontSize: 12.sp)),
                      SizedBox(width: 12.w),
                      Text(
                        "Privacy Policy",
                        style: TextStyle(
                          color: footerLinkColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    "© 2026 Maylaud Municipality. All rights reserved.",
                    style: TextStyle(color: footerColor, fontSize: 12.sp),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final bool isDark;
  final ColorScheme cs;

  _WavePainter({required this.isDark, required this.cs});

  @override
  void paint(Canvas canvas, Size size) {
    final fillColor = isDark
        ? cs.primary.withValues(alpha: 0.08)
        : AppColors.heritagePurple.withValues(alpha: 0.06);
    final strokeColor = isDark
        ? cs.primary.withValues(alpha: 0.25)
        : AppColors.heritagePurple.withValues(alpha: 0.25);

    final fillWave = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final lineWave = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path1 = Path();
    path1.moveTo(0, 70);
    path1.quadraticBezierTo(size.width * 0.25, 20, size.width * 0.5, 90);
    path1.quadraticBezierTo(size.width * 0.75, 150, size.width, 70);
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();

    canvas.drawPath(path1, fillWave);

    final path2 = Path();
    path2.moveTo(0, 90);
    path2.quadraticBezierTo(size.width * 0.3, 40, size.width * 0.6, 110);
    path2.quadraticBezierTo(size.width * 0.85, 170, size.width, 100);

    canvas.drawPath(path2, lineWave);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
