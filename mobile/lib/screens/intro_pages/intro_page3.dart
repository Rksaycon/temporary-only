import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class IntroPage3 extends StatelessWidget {
  const IntroPage3({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final titleColor = isDark ? cs.primary : const Color(0xFF4C229C);
    final bodyColor = isDark ? cs.onBackground.withOpacity(0.85) : Colors.black87;
    final sloganColor = isDark ? cs.primary.withOpacity(0.8) : const Color(0xFF6A4BC4);

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
                    "assets/images/intro_page/intro_page3.png",
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              // Bottom padding reserves room for the purple Skip/Next/
              // Get Started bar that intro_page_design.dart overlays on
              // top of this page via a Stack — without it, the slogan
              // line gets physically covered by that bar (this is the
              // page where it was happening).
              padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 120.h),
              child: Column(
                children: [
                  SizedBox(height: 20.h),
                  Text(
                    "Your Maylaud\nCommunity Assistant",
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
                    "Access local information, public services,\n"
                    "and community help with just a tap - designed\n"
                    "to make life in Milaor easier.\n",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      height: 1.6,
                      color: bodyColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    "Oragon kita! Let's build Milaor together.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: sloganColor,
                      fontWeight: FontWeight.w600,
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