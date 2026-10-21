import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../home/home.dart';

const _faqs = [
  (
    q: 'How do I request a barangay document?',
    a: 'Go to the + button on Home, select "Document Request", fill in the form, and submit. You will receive a reference number to track your request.',
  ),
  (
    q: 'How do I report a community issue?',
    a: 'Tap the + button, choose "Citizen Report", describe the issue, attach photos if needed, and submit. Reports are reviewed within 3–5 business days.',
  ),
  (
    q: 'What do I do during a flood alert?',
    a: 'Go to Flood Alert from the + button to see current risk levels and nearest evacuation centers. Follow local authority instructions.',
  ),
  (
    q: 'How do I contact emergency hotlines?',
    a: 'Tap the + button and select "Milaor Hotlines". Tap any contact to call them directly from your phone.',
  ),
  (
    q: 'How do I update my profile information?',
    a: 'Go to Profile → Edit Profile. Update your name, phone, or address and tap Save Changes.',
  ),
];

class HelpSupportSheet extends StatelessWidget {
  const HelpSupportSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final backgroundColor = isDark ? colorScheme.surface : Colors.white;
    final titleColor = isDark ? colorScheme.onSurface : HomeColors.deepAnchor;
    final subtitleColor = isDark ? colorScheme.onSurface.withOpacity(0.6) : const Color(0xFF9E9E9E);
    final answerTextColor = isDark ? colorScheme.onSurface.withOpacity(0.8) : const Color(0xFF424242);
    final handleColor = isDark ? colorScheme.onSurface.withOpacity(0.2) : Colors.grey[300]!;
    final contactCardBg = isDark 
        ? HomeColors.heritagePurple.withOpacity(0.12) 
        : HomeColors.heritagePurple.withOpacity(0.06);
    
    // Fixed purple accent – matches ProfileScreen
    final accentColor = HomeColors.heritagePurple;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (ctx, scrollCtrl) => Padding(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHandle(handleColor),
              SizedBox(height: 20.h),
              Text(
                'Help & Support',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Frequently asked questions',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: subtitleColor,
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: _faqs.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (ctx, i) => _FaqTile(
                    question: _faqs[i].q,
                    answer: _faqs[i].a,
                    titleColor: titleColor,
                    answerTextColor: answerTextColor,
                    accentColor: accentColor,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              _buildContactCard(
                titleColor: titleColor,
                accentColor: accentColor,
                subtitleColor: subtitleColor,
                backgroundColor: contactCardBg,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(Color color) {
    return Center(
      child: Container(
        width: 40.w,
        height: 4.h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2.r),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required Color titleColor,
    required Color accentColor,
    required Color subtitleColor,
    required Color backgroundColor,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.support_agent_outlined,
            color: accentColor,
            size: 24.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need more help?',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                Text(
                  'Contact the Barangay Hall directly.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: subtitleColor,
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

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  final Color titleColor;
  final Color answerTextColor;
  final Color accentColor;

  const _FaqTile({
    required this.question,
    required this.answer,
    required this.titleColor,
    required this.answerTextColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 4.w),
        childrenPadding: EdgeInsets.only(
          left: 4.w, 
          right: 4.w, 
          bottom: 12.h,
        ),
        title: Text(
          question,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        iconColor: accentColor,
        collapsedIconColor: isDark 
            ? theme.colorScheme.onSurface.withOpacity(0.4)
            : const Color(0xFF9E9E9E),
        children: [
          Text(
            answer,
            style: TextStyle(
              fontSize: 13.sp,
              color: answerTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to show this sheet from anywhere
Future<void> showHelpSupportSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent, // Use our container's background
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (_) => const HelpSupportSheet(),
  );
}