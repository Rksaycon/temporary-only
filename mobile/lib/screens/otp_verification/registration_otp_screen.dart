// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:may_laud/providers/auth_provider.dart';
import 'package:may_laud/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../success/registration_verified_success_screen.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String name;
  final String phone;
  final String address;

  const VerificationScreen({
    super.key,
    required this.email,
    required this.name,
    required this.phone,
    required this.address,
  });

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final List<TextEditingController> controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());

  int secondsRemaining = 59;
  Timer? timer;
  bool _isLoading = false;
  String? _errorMessage;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    startTimer();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && focusNodes.isNotEmpty) focusNodes[0].requestFocus();
    });
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (secondsRemaining == 0) {
        t.cancel();
      } else {
        setState(() => secondsRemaining--);
      }
    });
  }

  void _onOtpChanged(String value, int index) {
    setState(() => _errorMessage = null);
    if (value.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _resendCode() async {
    if (secondsRemaining > 0) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      if (mounted) {
        setState(() {
          secondsRemaining = 59;
          _isLoading = false;
        });
        startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code resent to ${widget.email}'),
            backgroundColor: AppColors.heritagePurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to resend code. Please try again.';
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = controllers.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _client.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.signup,
      );

      if (!mounted) return;

      if (response.session != null || response.user != null) {
        // Save address and profile data now that user is confirmed
        await ref.read(authProvider.notifier).completeRegistration(
              name: widget.name,
              phone: widget.phone,
              address: widget.address,
            );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VerifiedSuccessScreen()),
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid or expired code. Please try again.';
        });
      }
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
  void dispose() {
    timer?.cancel();
    for (var c in controllers) {
      c.dispose();
    }
    for (var f in focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Widget _otpBox(int index) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        height: 56.h,
        child: TextField(
          controller: controllers[index],
          focusNode: focusNodes[index],
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.deepAnchor,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.neutralWhite,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: _errorMessage != null
                    ? AppColors.error
                    : focusNodes[index].hasFocus
                        ? AppColors.heritagePurple
                        : AppColors.neutralGray200,
                width: focusNodes[index].hasFocus ? 2 : 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: AppColors.heritagePurple,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: AppColors.error,
                width: 1.5,
              ),
            ),
          ),
          onChanged: (value) => _onOtpChanged(value, index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    final scaffoldBg = isDark ? cs.background : AppColors.neutralWhite;
    final bubbleBg1 = isDark
        ? cs.primary.withOpacity(0.12)
        : AppColors.heritagePurple.withValues(alpha: 0.12);
    final bubbleBg2Gradient = isDark
        ? [cs.primary.withOpacity(0.10), Colors.transparent]
        : [AppColors.riverFlow.withOpacity(0.35), Colors.transparent];
    final bubbleBg3Gradient = isDark
        ? [cs.primary.withOpacity(0.12), Colors.transparent]
        : [AppColors.riverFlow.withOpacity(0.4), Colors.transparent];
    final titleColor = isDark ? cs.onBackground : AppColors.deepAnchor;
    final subtitleColor =
        isDark ? cs.onBackground.withOpacity(0.6) : AppColors.neutralGray500;
    final formBg = isDark ? cs.surface : AppColors.warmHearth;
    final linkColor =
        isDark ? cs.onBackground.withOpacity(0.6) : Colors.black54;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // Background decorations (matching sign in screen)
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
              child: CustomPaint(painter: _WavePainter(isDark: isDark, cs: cs)),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 20.h),

                  // Back button + Title
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: Icon(Icons.arrow_back_ios,
                              color: isDark
                                  ? cs.primary
                                  : AppColors.heritagePurple),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Text(
                        "Verification",
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20.h),

                  // Icon - Fixed to use existing icon
                  Container(
                    width: 80.w,
                    height: 80.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.heritagePurple, AppColors.riverFlow],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.heritagePurple.withOpacity(0.3),
                          blurRadius: 20.r,
                          offset: Offset(0, 8.h),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.mark_email_read_outlined,
                      size: 40.sp,
                      color: AppColors.neutralWhite,
                    ),
                  ),

                  SizedBox(height: 24.h),

                  Text(
                    "Verify Your Email",
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),

                  SizedBox(height: 10.h),

                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: subtitleColor,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: "We've sent a 6-digit code to\n"),
                        TextSpan(
                          text: widget.email,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? cs.primary : AppColors.heritagePurple,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // Form container (matching sign in screen)
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: formBg,
                      borderRadius: BorderRadius.circular(28.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.riverFlow
                              .withOpacity(isDark ? 0.05 : 0.08),
                          blurRadius: 20.r,
                          offset: Offset(0, 8.h),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // OTP Fields - Using Row with Expanded to prevent overflow
                        Row(
                          children: List.generate(6, (index) => _otpBox(index)),
                        ),

                        if (_errorMessage != null) ...[
                          SizedBox(height: 16.h),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: AppColors.errorDark,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        SizedBox(height: 28.h),

                        // Verify Button (matching sign in button style)
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          GestureDetector(
                            onTap: _verifyOtp,
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40.r),
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.heritagePurple,
                                    AppColors.riverFlow
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.heritagePurple
                                        .withOpacity(0.3),
                                    blurRadius: 12.r,
                                    offset: Offset(0, 4.h),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  "Verify Account",
                                  style: TextStyle(
                                    color: AppColors.neutralWhite,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        SizedBox(height: 18.h),

                        // Resend Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Didn't receive the code?",
                              style: TextStyle(
                                color: linkColor,
                                fontSize: 13.sp,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            secondsRemaining > 0
                                ? Text(
                                    'Resend in 00:${secondsRemaining.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: isDark
                                          ? cs.primary
                                          : AppColors.heritagePurple,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.sp,
                                    ),
                                  )
                                : GestureDetector(
                                    onTap: _isLoading ? null : _resendCode,
                                    child: Text(
                                      'Resend now',
                                      style: TextStyle(
                                        color: isDark
                                            ? cs.primary
                                            : AppColors.heritagePurple,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.sp,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                          ],
                        ),

                        SizedBox(height: 20.h),

                        // Security note
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 14.w,
                              color: isDark
                                  ? cs.primary.withOpacity(0.6)
                                  : AppColors.heritagePurple.withOpacity(0.6),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'End-to-end encrypted',
                              style: TextStyle(
                                color: isDark
                                    ? cs.primary.withOpacity(0.6)
                                    : AppColors.heritagePurple.withOpacity(0.6),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
