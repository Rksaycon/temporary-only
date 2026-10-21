// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:may_laud/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:may_laud/screens/otp_verification/forgot_password_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return;
    }

    // Basic email format check
    final emailRegex = RegExp(r'^[\w\.\+\-]+@[\w\-]+(\.[\w\-]+)+$',
        caseSensitive: false);
    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await _client.auth.resetPasswordForEmail(email);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(email: email),
        ),
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    // Adaptive colors matching sign-in screen
    final scaffoldBg = isDark ? cs.background : AppColors.neutralWhite;
    final bubbleBg1 = isDark ? cs.primary.withOpacity(0.12) : AppColors.heritagePurple.withValues(alpha: 0.12);
    final bubbleBg2Gradient = isDark
        ? [cs.primary.withOpacity(0.10), Colors.transparent]
        : [AppColors.riverFlow.withOpacity(0.35), Colors.transparent];
    final titleColor = isDark ? cs.onBackground : AppColors.deepAnchor;
    final subtitleColor = isDark ? cs.onBackground.withOpacity(0.6) : AppColors.neutralGray500;
    final formBg = isDark ? cs.surface : AppColors.warmHearth;
    final inputBg = isDark ? cs.background : AppColors.neutralWhite;
    final inputBorder = isDark ? cs.onSurface.withOpacity(0.15) : AppColors.neutralGray200;
    final inputIconColor = isDark ? cs.onSurface.withOpacity(0.5) : AppColors.neutralGray500;
    final labelColor = isDark ? cs.onSurface.withOpacity(0.85) : AppColors.neutralGray800;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // Background decorations matching sign-in screen
          Positioned(
            top: -120.h,
            left: -120.w,
            child: Container(
              width: 280.w,
              height: 280.w,
              decoration: BoxDecoration(shape: BoxShape.circle, color: bubbleBg1),
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
                gradient: RadialGradient(
                  colors: isDark
                      ? [cs.primary.withOpacity(0.12), Colors.transparent]
                      : [AppColors.riverFlow.withOpacity(0.4), Colors.transparent],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 240.h,
              width: double.infinity,
              child: CustomPaint(painter: _WavePainter(isDark: isDark, cs: cs)),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 30.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 30.h),
                  
                  // Logo
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.riverFlow.withOpacity(0.18),
                          blurRadius: 25.r,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset('assets/images/milaudlogo.png',
                        height: 100.h),
                  ),
                  SizedBox(height: 15.h),
                  
                  Text(
                    "Forgot Password?",
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  
                  Text(
                    "Enter your registered email address",
                    style: TextStyle(fontSize: 14.sp, color: subtitleColor),
                  ),
                  SizedBox(height: 30.h),
                  
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: formBg,
                      borderRadius: BorderRadius.circular(28.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.riverFlow.withOpacity(isDark ? 0.05 : 0.08),
                          blurRadius: 20.r,
                          offset: Offset(0, 8.h),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Email Address",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.sp,
                            color: labelColor,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          "We'll send a verification code to reset your password",
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: subtitleColor,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: inputBorder, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.email_outlined,
                                  color: inputIconColor),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: TextStyle(color: cs.onSurface),
                                  decoration: InputDecoration(
                                    hintText: "Enter your email",
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(
                                        color: cs.onSurface.withOpacity(0.4)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        if (_errorMessage != null) ...[
                          SizedBox(height: 10.h),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                        
                        SizedBox(height: 30.h),
                        
                        GestureDetector(
                          onTap: _isLoading ? null : _sendResetCode,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40.r),
                              gradient: _isLoading
                                  ? LinearGradient(
                                      colors: [AppColors.neutralGray200, AppColors.neutralGray500])
                                  : LinearGradient(
                                      colors: [AppColors.heritagePurple, AppColors.riverFlow],
                                    ),
                              boxShadow: _isLoading
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: AppColors.heritagePurple.withOpacity(0.3),
                                        blurRadius: 12.r,
                                        offset: Offset(0, 4.h),
                                      ),
                                    ],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? SizedBox(
                                      width: 24.w,
                                      height: 24.w,
                                      child: const CircularProgressIndicator(
                                        color: AppColors.neutralWhite,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      "Send Reset Code",
                                      style: TextStyle(
                                        color: AppColors.neutralWhite,
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
    final fillColor =
        isDark ? cs.primary.withOpacity(0.08) : AppColors.warmHearth;
    final strokeColor =
        isDark ? cs.primary.withOpacity(0.25) : AppColors.riverFlow;

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