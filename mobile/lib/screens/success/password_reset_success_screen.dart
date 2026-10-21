// ignore_for_file: unused_local_variable

import 'package:may_laud/theme/app_theme.dart';
// lib/screens/success/password_reset_success_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:may_laud/screens/sign_in/sign_in_screen.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    final scaffoldBg = AppColors.of(context).surface;
    final bubbleBg1 = AppColors.of(context).accentPurple.withOpacity(0.12);
    final bubble2Colors = [
      AppColors.of(context).accentPurple.withOpacity(0.10),
      Colors.transparent
    ];
    final bubble3Colors = [
      AppColors.of(context).accentPurple.withOpacity(0.12),
      Colors.transparent
    ];
    final titleColor = AppColors.of(context).textPrimary;
    final subtitleColor = AppColors.of(context).textMuted;
    final accentPurple = AppColors.of(context).accentPurple;
    final footerColor = AppColors.of(context).textMuted;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
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
                gradient: RadialGradient(colors: bubble2Colors),
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
                gradient: RadialGradient(colors: bubble3Colors),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 240.h,
              width: double.infinity,
              child: CustomPaint(
                  painter: _SuccessWavePainter(
                AppColors.of(context).formSurface,
                AppColors.of(context).accentPurple.withOpacity(0.25),
              )),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 40.h),
                    Container(
                      width: 120.w,
                      height: 120.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [
                          AppColors.heritagePurple,
                          AppColors.riverFlow
                        ]),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.heritagePurple.withOpacity(0.3),
                            blurRadius: 25.r,
                            offset: Offset(0, 10.h),
                          ),
                        ],
                      ),
                      child: Icon(Icons.check_rounded,
                          color: AppColors.neutralWhite, size: 60.sp),
                    ),
                    SizedBox(height: 35.h),
                    Text(
                      "Success",
                      style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w700,
                          color: titleColor),
                    ),
                    SizedBox(height: 10.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Text(
                        "Your password has been updated successfully. You can now use your new password to sign in.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15.sp, color: subtitleColor, height: 1.5),
                      ),
                    ),
                    SizedBox(height: 50.h),
                    GestureDetector(
                      onTap: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const WelcomeBackScreen()),
                        (route) => false,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40.r),
                          gradient: LinearGradient(colors: [
                            AppColors.heritagePurple,
                            AppColors.riverFlow
                          ]),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    AppColors.heritagePurple.withOpacity(0.3),
                                blurRadius: 12.r,
                                offset: Offset(0, 6.h)),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "Sign in Now",
                            style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neutralWhite),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      "You will be redirected to the Sign in screen.",
                      style: TextStyle(fontSize: 13.sp, color: footerColor),
                    ),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessWavePainter extends CustomPainter {
  final Color fillColor;
  final Color strokeColor;
  const _SuccessWavePainter(this.fillColor, this.strokeColor);

  @override
  void paint(Canvas canvas, Size size) {
    final fillWave = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final lineWave = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path1 = Path()
      ..moveTo(0, 70)
      ..quadraticBezierTo(size.width * 0.25, 20, size.width * 0.5, 90)
      ..quadraticBezierTo(size.width * 0.75, 150, size.width, 70)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path1, fillWave);

    final path2 = Path()
      ..moveTo(0, 90)
      ..quadraticBezierTo(size.width * 0.3, 40, size.width * 0.6, 110)
      ..quadraticBezierTo(size.width * 0.85, 170, size.width, 100);
    canvas.drawPath(path2, lineWave);
  }

  @override
  bool shouldRepaint(covariant _SuccessWavePainter old) =>
      old.fillColor != fillColor || old.strokeColor != strokeColor;
}
