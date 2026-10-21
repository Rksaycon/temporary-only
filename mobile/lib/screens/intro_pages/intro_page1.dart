import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class IntroPage1 extends StatelessWidget {
  const IntroPage1({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final titleColor = isDark ? cs.primary : const Color(0xFF4C229C);
    final bodyColor = isDark ? cs.onBackground.withOpacity(0.85) : Colors.black87;

    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 0.6.sh,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/intro_page/intro_page1.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              // Bottom padding reserves room for the purple Skip/Next
              // bar that intro_page_design.dart overlays on top of
              // this page via a Stack — without it, the last line of
              // text gets physically covered by that bar.
              padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 120.h),
              child: Column(
                children: [
                  SizedBox(height: 20.h),
                  Text(
                    "Welcome to Maylaud",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 30.sp,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    "Serving all 20 barangays of Milaor\n"
                    "connects every resident to faster services,\n"
                    "clearer communication, and a community\n"
                    "updates, with essentials local services\n"
                    "all in one app.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: bodyColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}