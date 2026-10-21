// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:may_laud/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:may_laud/providers/auth_provider.dart';
import 'package:may_laud/screens/sign_up/registration_screen.dart';
import 'package:may_laud/screens/password/forgot_password_screen.dart';
import 'package:may_laud/screens/home/nav_bar_button.dart';

class WelcomeBackScreen extends ConsumerStatefulWidget {
  const WelcomeBackScreen({super.key});

  @override
  ConsumerState<WelcomeBackScreen> createState() => _WelcomeBackScreenState();
}

class _WelcomeBackScreenState extends ConsumerState<WelcomeBackScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    final authNotifier = ref.read(authProvider.notifier);
    await authNotifier.login(
        _emailController.text.trim(), _passwordController.text);

    if (mounted && ref.read(authProvider).isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainApp()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    // Adaptive colors
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
    final inputBg = isDark ? cs.background : AppColors.neutralWhite;
    final inputBorder =
        isDark ? cs.onSurface.withOpacity(0.15) : AppColors.neutralGray200;
    final inputIconColor =
        isDark ? cs.onSurface.withOpacity(0.5) : AppColors.neutralGray500;
    final labelColor =
        isDark ? cs.onSurface.withOpacity(0.85) : AppColors.neutralGray800;
    final hintColor =
        isDark ? cs.onSurface.withOpacity(0.45) : AppColors.neutralGray500;
    final accentPurple = isDark ? cs.primary : AppColors.heritagePurple;
    final guestBg = isDark ? cs.surface : AppColors.neutralWhite;
    final guestText = isDark ? cs.primary : AppColors.heritagePurple;
    final linkColor =
        isDark ? cs.onBackground.withOpacity(0.6) : Colors.black54;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // Background decorations
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
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 30.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 30.h),
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
                    "Welcome to Maylaud",
                    style: TextStyle(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w700,
                        color: titleColor),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "Enter your email and password",
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
                          color: AppColors.riverFlow
                              .withOpacity(isDark ? 0.05 : 0.08),
                          blurRadius: 20.r,
                          offset: Offset(0, 8.h),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Email",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                                color: labelColor)),
                        SizedBox(height: 6.h),
                        Text("We'll use this to sign you in",
                            style:
                                TextStyle(fontSize: 12.sp, color: hintColor)),
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
                              Icon(Icons.email_outlined, color: inputIconColor),
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
                        SizedBox(height: 20.h),
                        Text("Password",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                                color: labelColor)),
                        SizedBox(height: 6.h),
                        Text("Enter your password to access your account",
                            style:
                                TextStyle(fontSize: 12.sp, color: hintColor)),
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
                              Icon(Icons.lock_outline, color: inputIconColor),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: TextStyle(color: cs.onSurface),
                                  decoration: InputDecoration(
                                    hintText: "Enter your password",
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(
                                        color: cs.onSurface.withOpacity(0.4)),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: inputIconColor),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 15.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  activeColor: accentPurple,
                                  onChanged: (val) => setState(
                                      () => _rememberMe = val ?? false),
                                ),
                                Text("Remember me",
                                    style: TextStyle(
                                        fontSize: 14.sp, color: cs.onSurface)),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordScreen()),
                                );
                              },
                              child: Text(
                                "Forgot password?",
                                style: TextStyle(
                                    color: accentPurple,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.sp),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),
                        if (authState.isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          GestureDetector(
                            onTap: _login,
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 16.h),
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
                                  "Sign in",
                                  style: TextStyle(
                                      color: AppColors.neutralWhite,
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        if (authState.error != null)
                          Padding(
                            padding: EdgeInsets.only(top: 12.h),
                            child: Text(
                              authState.error!,
                              style: TextStyle(
                                  color: AppColors.error, fontSize: 13.sp),
                            ),
                          ),
                        SizedBox(height: 14.h),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen()),
                            );
                          },
                          child: Center(
                            child: RichText(
                              text: TextSpan(
                                text: "Don't have an account? ",
                                style: TextStyle(
                                    color: linkColor, fontSize: 14.sp),
                                children: [
                                  TextSpan(
                                    text: "Create Account",
                                    style: TextStyle(
                                        color: accentPurple,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 40.h),
                        GestureDetector(
                          onTap: () async {
                            final authNotifier =
                                ref.read(authProvider.notifier);
                            await authNotifier.loginAsGuest();
                            if (mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const MainApp()),
                              );
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40.r),
                              color: guestBg,
                              border: isDark
                                  ? Border.all(
                                      color: cs.primary.withOpacity(0.4),
                                      width: 1)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.heritagePurple
                                      .withOpacity(isDark ? 0.08 : 0.15),
                                  blurRadius: 12.r,
                                  offset: Offset(0, 4.h),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                "Continue as Guest",
                                style: TextStyle(
                                    color: guestText,
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold),
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
