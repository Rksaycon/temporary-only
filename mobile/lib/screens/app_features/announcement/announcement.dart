import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:may_laud/theme/app_theme.dart';
import '../../../providers/content_providers.dart';
import '../../home/home.dart';

/// ─── PROFESSIONAL ANNOUNCEMENT DETAIL SCREEN ─────────────
/// Designed for Milaor residents — clear hierarchy, municipal
/// brand colors, accessible typography & actionable layout.
class AnnouncementFeedScreen extends StatelessWidget {
  final Announcement announcement;

  const AnnouncementFeedScreen({super.key, required this.announcement});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final imageHeight = 280.h;
    final cardLift = 36.h;

    return Scaffold(
      backgroundColor: HomeColors.warmHearth,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ── Hero Section (Image + Gradient + Floating Controls) ──
            _buildHeroSection(context, imageHeight, cardLift, topPadding),

            // ── Overlapping Title Card ──
            _buildTitleCard(cardLift),

            // ── Key Info Boxes ──
            _buildInfoBoxes(),

            // ── Full Description ──
            _buildDescriptionSection(),

            // ── Action Buttons ──
            _buildActionButtons(context),

            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  // ─── HERO IMAGE + GRADIENT + FLOATING BUTTONS ────────────
  Widget _buildHeroSection(
    BuildContext context,
    double imageHeight,
    double cardLift,
    double topPadding,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Image
        SizedBox(
          height: imageHeight,
          width: double.infinity,
          child: announcement.imageUrl != null
              ? Image.network(
                  announcement.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _heroPlaceholder(),
                )
              : _heroPlaceholder(),
        ),

        // Gradient overlay for readability
        SizedBox(
          height: imageHeight,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  HomeColors.deepAnchor.withValues(alpha: 0.55),
                  HomeColors.heritagePurple.withValues(alpha: 0.35),
                  HomeColors.deepAnchor.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
        ),

        // Top action buttons
        Positioned(
          top: topPadding + 8.h,
          left: 8.w,
          right: 8.w,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _iconCircle(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context),
              ),
              Row(
                children: [
                  _iconCircle(
                    icon: announcement.isRead
                        ? Icons.bookmark_outline
                        : Icons.bookmark_rounded,
                    onTap: () {},
                  ),
                  SizedBox(width: 8.w),
                  _iconCircle(
                    icon: Icons.share_outlined,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),

        // Category + Important badges (above the overlapping card)
        Positioned(
          bottom: cardLift + 12.h,
          left: 20.w,
          right: 20.w,
          child: Row(
            children: [
              _categoryBadge(announcement.category),
              if (announcement.isImportant) ...[
                SizedBox(width: 8.w),
                _importantBadge(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HomeColors.riverFlow.withValues(alpha: 0.6),
            HomeColors.heritagePurple.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.campaign_rounded,
          size: 64.sp,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  // ─── FLOATING ICON CIRCLE ──────────────────────────────
  static Widget _iconCircle({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Icon(icon, size: 20.sp, color: Colors.white),
      ),
    );
  }

  // ─── CATEGORY BADGE ────────────────────────────────────
  static Widget _categoryBadge(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: HomeColors.heritagePurple,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: HomeColors.heritagePurple.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ─── IMPORTANT BADGE ───────────────────────────────────
  static Widget _importantBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: HomeColors.dangerRed,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: HomeColors.dangerRed.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.priority_high_rounded, size: 13.sp, color: Colors.white),
          SizedBox(width: 3.w),
          Text(
            'IMPORTANT',
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── OVERLAPPING TITLE CARD ────────────────────────────
  Widget _buildTitleCard(double cardLift) {
    return Transform.translate(
      offset: Offset(0, -cardLift),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        padding: EdgeInsets.all(22.w),
        decoration: BoxDecoration(
          color: HomeColors.cardWhite,
          borderRadius: BorderRadius.circular(22.r),
          boxShadow: [
            BoxShadow(
              color: HomeColors.deepAnchor.withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date row
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14.sp, color: HomeColors.riverFlow),
                SizedBox(width: 6.w),
                Text(
                  'Published ${announcement.formattedDate}',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: HomeColors.riverFlow,
                  ),
                ),
                const Spacer(),
                if (!announcement.isRead)
                  Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      color: HomeColors.infoBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: HomeColors.infoBlue.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16.h),
            // Title
            Text(
              announcement.title,
              style: GoogleFonts.poppins(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: HomeColors.deepAnchor,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── KEY INFO BOXES ────────────────────────────────────
  Widget _buildInfoBoxes() {
    // Only show if the announcement has contextual metadata
    // For real data, these could be parsed from description or passed separately
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          SizedBox(height: 4.h),
          _infoCard(
            icon: Icons.access_time_rounded,
            iconColor: HomeColors.infoBlue,
            label: 'TIMEFRAME',
            value: 'Refer to details below',
            accentColor: HomeColors.infoBlue,
          ),
          SizedBox(height: 12.h),
          _infoCard(
            icon: Icons.location_on_rounded,
            iconColor: HomeColors.warningAmber,
            label: 'COVERAGE',
            value: 'Milaor, Camarines Sur',
            accentColor: HomeColors.warningAmber,
          ),
          SizedBox(height: 12.h),
          // Read status card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: announcement.isRead
                  ? HomeColors.successGreen.withValues(alpha: 0.06)
                  : HomeColors.warmHearth,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: announcement.isRead
                    ? HomeColors.successGreen.withValues(alpha: 0.15)
                    : HomeColors.heritagePurple.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: BoxDecoration(
                    color: announcement.isRead
                        ? HomeColors.successGreen.withValues(alpha: 0.12)
                        : HomeColors.heritagePurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    announcement.isRead
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 20.sp,
                    color: announcement.isRead
                        ? HomeColors.successGreen
                        : HomeColors.heritagePurple,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Text(
                    announcement.isRead
                        ? 'You have read this announcement'
                        : 'New announcement — tap for full details',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: announcement.isRead
                          ? HomeColors.successGreen
                          : HomeColors.riverFlow,
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

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: HomeColors.cardWhite,
        borderRadius: BorderRadius.circular(16.r),
        border: Border(
          left: BorderSide(color: accentColor, width: 3.w),
        ),
        boxShadow: [
          BoxShadow(
            color: HomeColors.deepAnchor.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15.sp, color: iconColor),
              SizedBox(width: 7.w),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: HomeColors.deepAnchor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── FULL DESCRIPTION SECTION ──────────────────────────
  Widget _buildDescriptionSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 28.h),
          // Section label
          Row(
            children: [
              Container(
                width: 4.w,
                height: 22.h,
                decoration: BoxDecoration(
                  color: HomeColors.heritagePurple,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'Full Details',
                style: GoogleFonts.poppins(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.deepAnchor,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          // Description card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(22.w),
            decoration: BoxDecoration(
              color: HomeColors.cardWhite,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: HomeColors.heritagePurple.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: HomeColors.deepAnchor.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              announcement.description,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                height: 1.75,
                color: AppColors.neutralGray800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ACTION BUTTONS ────────────────────────────────────
  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          SizedBox(height: 28.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.print_outlined, size: 17.sp),
                  label: Text(
                    'Print',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomeColors.heritagePurple,
                    side: BorderSide(
                      color: HomeColors.heritagePurple.withValues(alpha: 0.5),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.share_outlined, size: 17.sp),
                  label: Text(
                    'Share',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeColors.heritagePurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Thank you! Your concern has been forwarded to the LGU.',
                      style: GoogleFonts.inter(fontSize: 13.sp),
                    ),
                    backgroundColor: HomeColors.successGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                );
              },
              icon: Icon(Icons.flag_outlined, size: 17.sp),
              label: Text(
                'Report an Issue with this Announcement',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: HomeColors.dangerRed,
                side: BorderSide(
                  color: HomeColors.dangerRed.withValues(alpha: 0.3),
                ),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}