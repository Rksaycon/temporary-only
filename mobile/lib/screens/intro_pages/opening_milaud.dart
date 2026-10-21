import 'package:may_laud/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:may_laud/screens/intro_pages/intro_page_design.dart';

class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key});

  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  double progress = 0;
  bool isNavigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(_controller);
    _scaleAnim = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    startLoading();
  }

  void startLoading() async {
    for (int i = 0; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 40)); // speed control

      if (!mounted) return;

      setState(() {
        progress = i / 100;
      });
    }

    //Delay opening to onboard screen1
    await Future.delayed(const Duration(milliseconds: 500)); // pause on READY

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get loadingText {
    if (progress < 0.3) return "INITIALIZING...";
    if (progress < 0.7) return "CONNECTING...";
    if (progress < 0.9) return "SECURING DATA...";
    return "READY!";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-0.32, 0.14),
                    end: Alignment(1.32, 0.86),
                    colors: [
                      AppColors.heritagePurple,
                      AppColors.riverFlow,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(),

                      // CENTER SECTION (IMAGE + TEXT TOGETHER)
                      Column(
                        children: [
                          //IMAGE (TRANSPARENT)
                          ScaleTransition(
                            scale: _scaleAnim,
                            child: Image.asset(
                              'assets/images/milaudlogo.png',
                              width: 140.w,
                              height: 140.h,
                              fit: BoxFit.contain,
                            ),
                          ),

                          SizedBox(height: 20.h),

                          // TEXT
                          Text(
                            'MAYLAUD',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: AppColors.neutralWhite,
                              fontSize: 45.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            'MILAOR, CAMARINES SUR',
                            style: TextStyle(
                              color: AppColors.neutralWhite.withValues(alpha: 0.8),
                              fontSize: 12.sp,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),

                      //LOADING SECTION
                      Padding(
                        padding: EdgeInsets.only(bottom: 30.h),
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40.w),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4.h,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.neutralWhite),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              loadingText,
                              style: TextStyle(
                                fontSize: 12.sp,
                                letterSpacing: 2,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}