import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:may_laud/providers/auth_provider.dart';
import 'package:may_laud/screens/signin__signup_screen.dart';
import 'package:may_laud/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Wait for auth to resolve, then navigate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _waitForAuthAndNavigate();
    });
  }

  Future<void> _waitForAuthAndNavigate() async {
    // Minimum splash display duration (2 seconds)
    await Future.delayed(const Duration(seconds: 2));

    // Wait until auth is no longer loading
    while (mounted && ref.read(authProvider).isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      // Navigate to main app
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      // Navigate to login screen
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.milaorBlue,
      body: Stack(
        children: [
          // Animated background painter
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _SplashBackgroundPainter(progress: _controller.value),
                size: Size.infinite,
              );
            },
          ),
          // Centered content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with scale animation
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 150.w,
                    height: 150.h,
                    decoration: BoxDecoration(
                      color: AppColors.neutralWhite,
                      borderRadius: BorderRadius.circular(30.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20.r,
                          spreadRadius: 2.r,
                          offset: Offset(0, 10.h),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/milaudlogo.png',
                        width: 120.w,
                        height: 120.h,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 40.h),
                // App name
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'MAYLAUD',
                      style: TextStyle(
                        fontSize: 42.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neutralWhite,
                        letterSpacing: 2.w,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10.r,
                            offset: Offset(0, 5.h),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                // Tagline
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Participatory Governance for Milaor',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.5.w,
                    ),
                  ),
                ),
                SizedBox(height: 60.h),
                // Loading indicator
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SizedBox(
                    width: 50.w,
                    height: 50.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.w,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.philippineGold,
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                // Loading text
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackgroundPainter extends CustomPainter {
  final double progress;

  _SplashBackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Animated circles
    final circlePaint = Paint()
      ..color = AppTheme.philippineGold.withValues(alpha: 0.1 * progress)
      ..style = PaintingStyle.fill;

    final radius = 100.0 * progress;
    canvas.drawCircle(center, radius, circlePaint);

    // Wave effect
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05 * progress)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.7 - 50 * progress,
      size.width * 0.5,
      size.height * 0.7,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.7 + 50 * progress,
      size.width,
      size.height * 0.7,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _SplashBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}