import 'package:flutter/material.dart';
import 'package:may_laud/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:may_laud/screens/intro_pages/intro_page1.dart';
import 'package:may_laud/screens/intro_pages/intro_page2.dart';
import 'package:may_laud/screens/intro_pages/intro_page3.dart';
import 'package:may_laud/screens/signin__signup_screen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OnboardingScreen(),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();

  bool onLastPage = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildBottomBar() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: onLastPage
          ? Padding(
              key: const ValueKey('get_started'),
              padding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 12.h,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 42.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neutralWhite,
                    foregroundColor: AppColors.heritagePurple,
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Get Started',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Padding(
              key: const ValueKey('navigation'),
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () {
                      _controller.jumpToPage(2);
                    },
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: AppColors.neutralWhite,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SmoothPageIndicator(
                    controller: _controller,
                    count: 3,
                    effect: JumpingDotEffect(
                      activeDotColor: AppColors.neutralWhite,
                      dotColor: AppColors.neutralWhite.withValues(alpha: 0.54),
                      dotHeight: 20.h,
                      dotWidth: 20.w,
                      spacing: 15.w,
                      verticalOffset: 20.h,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Text(
                      'Next',
                      style: TextStyle(
                        color: AppColors.neutralWhite,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SafeArea(bottom: true) keeps the "Skip/Next" bar above the
      // system gesture nav bar — without it, Align(0, 1) below sits
      // flush against the physical screen edge and gets clipped on
      // devices with a gesture bar (top stays false so the page-view
      // artwork can still bleed to the very top of the screen).
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // PAGE VIEW
            PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() {
                  onLastPage = (index == 2);
                });
              },
              children: const [
                IntroPage1(),
                IntroPage2(),
                IntroPage3(),
              ],
            ),

            // BOTTOM CONTAINER
            Align(
              alignment: const Alignment(0, 1),
              child: Container(
                height: 100.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.heritagePurple,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30.r),
                    topRight: Radius.circular(30.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10.r,
                      color: AppColors.neutralBlack.withValues(alpha: 0.26),
                      offset: Offset(0, -2.h),
                    ),
                  ],
                ),
                child: Center(
                  child: _buildBottomBar(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
