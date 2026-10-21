// ignore_for_file: unused_local_variable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:may_laud/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../success/password_reset_success_screen.dart';

/// ---------------- NEW PASSWORD CREATION----------------
class CreateNewPasswordScreen extends StatefulWidget {
  const CreateNewPasswordScreen({super.key});

  @override
  State<CreateNewPasswordScreen> createState() =>
      _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final TextEditingController pass1 = TextEditingController();
  final TextEditingController pass2 = TextEditingController();

  bool obscure1 = true;
  bool obscure2 = true;
  bool _isLoading = false;

  String strength = "Weak";
  Color strengthColor = AppColors.error;

  String errorText = "";

  SupabaseClient get _client => Supabase.instance.client;

  void checkStrength(String value) {
    if (value.isEmpty) {
      strength = "Weak";
      strengthColor = AppColors.error;
    } else if (value.length < 6) {
      strength = "Weak";
      strengthColor = AppColors.error;
    } else if (value.length < 10) {
      strength = "Medium";
      strengthColor = Colors.orange;
    } else {
      strength = "Strong";
      strengthColor = Colors.green;
    }
    setState(() {});
  }

  void validatePasswords() {
    if (pass2.text.isNotEmpty && pass1.text != pass2.text) {
      errorText = "Passwords do not match";
    } else {
      errorText = "";
    }
    setState(() {});
  }

  Future<void> handleSubmit() async {
    validatePasswords();

    if (errorText.isEmpty && pass1.text.isNotEmpty) {
      setState(() => _isLoading = true);

      try {
        // Update the user's password
        await _client.auth.updateUser(
          UserAttributes(password: pass1.text),
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const SuccessScreen(),
          ),
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            errorText = 'Failed to update password. Please try again.';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    pass1.dispose();
    pass2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    // Adaptive colors — always use heritagePurple as accent in both modes
    final accentPurple = AppColors.heritagePurple;
    final scaffoldBg = isDark ? cs.background : AppColors.neutralWhite;
    final bubbleBg1 = AppColors.heritagePurple.withOpacity(0.12);
    final bubbleBg2Gradient = [
      AppColors.riverFlow.withOpacity(isDark ? 0.10 : 0.35),
      Colors.transparent
    ];
    final bubbleBg3Gradient = [
      AppColors.heritagePurple.withOpacity(isDark ? 0.12 : 0.4),
      Colors.transparent
    ];
    final titleColor = isDark ? cs.onBackground : AppColors.deepAnchor;
    final subtitleColor =
        isDark ? cs.onBackground.withOpacity(0.6) : AppColors.neutralGray500;
    final formBg = isDark ? cs.surface : AppColors.warmHearth;
    final inputBg = isDark ? cs.background : AppColors.neutralWhite;
    final inputBorder =
        isDark ? cs.onSurface.withOpacity(0.15) : AppColors.neutralGray200;
    final inputIconColor = isDark
        ? AppColors.heritagePurple.withOpacity(0.7)
        : AppColors.neutralGray500;
    final labelColor =
        isDark ? cs.onSurface.withOpacity(0.85) : AppColors.neutralGray800;
    final hintColor =
        isDark ? cs.onSurface.withOpacity(0.45) : AppColors.neutralGray500;
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
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 30.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 30.h),

                  // Back button + Title
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: Icon(Icons.arrow_back_ios,
                              color: AppColors.heritagePurple),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Text(
                        "Create New Password",
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20.h),

                  // Icon
                  Container(
                    width: 100.w,
                    height: 100.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [accentPurple, AppColors.riverFlow],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentPurple.withOpacity(0.3),
                          blurRadius: 20.r,
                          offset: Offset(0, 8.h),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.lock_reset,
                      size: 50.sp,
                      color: AppColors.neutralWhite,
                    ),
                  ),

                  SizedBox(height: 32.h),

                  Text(
                    "Create New Password",
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),

                  SizedBox(height: 12.h),

                  Text(
                    "Your new password must be different from previous",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: subtitleColor,
                      height: 1.5,
                    ),
                  ),

                  SizedBox(height: 30.h),

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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // New Password Field
                        Text("New Password",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                                color: labelColor)),
                        SizedBox(height: 6.h),
                        Text(
                            "Create a strong password with at least 8 characters",
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
                                  controller: pass1,
                                  obscureText: obscure1,
                                  onChanged: (val) {
                                    checkStrength(val);
                                    validatePasswords();
                                  },
                                  style: TextStyle(color: cs.onSurface),
                                  decoration: InputDecoration(
                                    hintText: "Enter new password",
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(
                                        color: cs.onSurface.withOpacity(0.4)),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                    obscure1
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: inputIconColor),
                                onPressed: () =>
                                    setState(() => obscure1 = !obscure1),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 10.h),

                        // Strength Indicator
                        Row(
                          children: [
                            Text(
                              "Strength: ",
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: hintColor,
                              ),
                            ),
                            Text(
                              strength,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: strengthColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 20.h),

                        // Confirm Password Field
                        Text("Confirm Password",
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                                color: labelColor)),
                        SizedBox(height: 6.h),
                        Text("Re-enter your password to confirm",
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
                                  controller: pass2,
                                  obscureText: obscure2,
                                  onChanged: (val) => validatePasswords(),
                                  style: TextStyle(color: cs.onSurface),
                                  decoration: InputDecoration(
                                    hintText: "Confirm your password",
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(
                                        color: cs.onSurface.withOpacity(0.4)),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                    obscure2
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: inputIconColor),
                                onPressed: () =>
                                    setState(() => obscure2 = !obscure2),
                              ),
                            ],
                          ),
                        ),

                        // Error message
                        if (errorText.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          Text(
                            errorText,
                            style: TextStyle(
                                color: AppColors.error, fontSize: 13.sp),
                          ),
                        ],

                        SizedBox(height: 20.h),

                        // Reset Password Button
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          GestureDetector(
                            onTap: handleSubmit,
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40.r),
                                gradient: LinearGradient(
                                  colors: [accentPurple, AppColors.riverFlow],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentPurple.withOpacity(0.3),
                                    blurRadius: 12.r,
                                    offset: Offset(0, 4.h),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  "Reset Password",
                                  style: TextStyle(
                                      color: AppColors.neutralWhite,
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),

                        SizedBox(height: 20.h),

                        // Security note
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 16.w,
                              color: AppColors.heritagePurple.withOpacity(0.6),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'End-to-end encrypted',
                              style: TextStyle(
                                color:
                                    AppColors.heritagePurple.withOpacity(0.6),
                                fontSize: 13.sp,
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
    final fillColor = isDark
        ? AppColors.heritagePurple.withOpacity(0.08)
        : AppColors.warmHearth;
    final strokeColor = isDark
        ? AppColors.heritagePurple.withOpacity(0.25)
        : AppColors.riverFlow;

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
