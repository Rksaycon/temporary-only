// ignore_for_file: unused_local_variable

import 'package:may_laud/theme/app_theme.dart';
// lib/screens/success/registration_account_succes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:may_laud/screens/home/home.dart';

// Same content as create_account_succes_screen but kept as separate file
// to preserve original routing references.
class VerifiedSuccessScreen extends StatelessWidget {
  const VerifiedSuccessScreen({super.key});

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
    final iconBg = AppColors.of(context).formSurface;
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
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 40.h),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 140.w,
                        height: 140.w,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(40.r),
                        ),
                      ),
                      Container(
                        width: 90.w,
                        height: 90.w,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentPurple, AppColors.riverFlow],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentPurple.withOpacity(0.35),
                              blurRadius: 20.r,
                              offset: Offset(0, 8.h),
                            ),
                          ],
                        ),
                        child: Icon(Icons.check_rounded,
                            color: AppColors.neutralWhite, size: 44.sp),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 45.w,
                          height: 45.w,
                          decoration: BoxDecoration(
                            color: AppColors.riverFlow,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.graphic_eq,
                              color: AppColors.neutralWhite, size: 20.sp),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 40.h),
                  Text(
                    "Phone Verified!",
                    style: TextStyle(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.bold,
                        color: titleColor),
                  ),
                  SizedBox(height: 15.h),
                  Text(
                    "Your phone number has been successfully verified. Welcome to the",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16.sp, color: subtitleColor),
                  ),
                  SizedBox(height: 5.h),
                  Text.rich(
                    TextSpan(
                      text: "May-Laud ",
                      style: TextStyle(
                          color: accentPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp),
                      children: [
                        TextSpan(
                          text: "community!",
                          style: TextStyle(
                              color: subtitleColor,
                              fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 40.h),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40.r),
                        gradient: LinearGradient(
                            colors: [accentPurple, AppColors.riverFlow]),
                        boxShadow: [
                          BoxShadow(
                              color: accentPurple.withOpacity(0.3),
                              blurRadius: 12.r,
                              offset: Offset(0, 4.h)),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "Get Started",
                          style: TextStyle(
                              color: AppColors.neutralWhite,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 40.h),
                  Container(
                    height: 180.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30.r),
                      image: const DecorationImage(
                        image: AssetImage("assets/images/globe.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 20.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: AppColors.of(context).surface.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                        child: Text(
                          "MEMBER SINCE 2026",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.of(context).textMuted),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    "SECURE VERIFICATION POWERED BY MAY-LAUD",
                    style: TextStyle(
                        fontSize: 12.sp, color: footerColor, letterSpacing: 1),
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
