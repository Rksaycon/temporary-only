import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:may_laud/providers/app_providers.dart';
import 'package:may_laud/providers/auth_provider.dart';
import 'package:may_laud/providers/content_providers.dart';
import 'package:may_laud/theme/app_theme.dart';
import '../app_features/announcement/announcements_list_screen.dart';
import '../app_features/flood_alert/flood_alert_screen.dart';

// ── Brand constants — delegates to AppColors (single source of truth) ─
/// Public alias kept for backward-compatibility with screens that
/// import home.dart and reference HomeColors.*.
abstract final class HomeColors {
  static Color get heritagePurple => AppColors.heritagePurple;
  static Color get riverFlow      => AppColors.riverFlow;
  static Color get deepAnchor     => AppColors.deepAnchor;
  static const Color successGreen   = AppColors.successAlt;
  static const Color warningAmber   = AppColors.warningAlt;
  static const Color infoBlue       = AppColors.infoAlt;
  static const Color dangerRed      = AppColors.errorAlt;

  /// Lavender wash — the warm light-mode scaffold/input background
  /// used by citizen_report, document_request, hotlines, flood_alert,
  /// announcement screens. Value: 0xFFF8F5FF.
  static const Color warmHearth = AppColors.warmHearth;

  /// Pure white card surface (light mode cards, sheets).
  static const Color cardWhite  = AppColors.cardWhite;

  /// Muted text — captions, labels, placeholders (delegates to AppColors).
  static const Color textMuted = AppColors.neutralGray500;

  static LinearGradient get headerGradient => AppColors.headerGradient;
  static LinearGradient get fabGradient    => AppColors.fabGradient;
}

// Internal shorthand (private — only used inside home.dart)
typedef _Brand = HomeColors;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  int _feedbackRating = 0;
  final TextEditingController _feedbackController = TextEditingController();
  bool _feedbackSubmitted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > 10 != _isScrolled) {
        setState(() => _isScrolled = _scrollController.position.pixels > 10);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user      = authState.user;
    final userName  = user?.name ?? 'Resident';
    final isGuest   = authState.isGuest;
    final colors    = AppColors.of(context); // ← single palette lookup

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Header — keeps brand gradient in both modes
        SliverAppBar(
          expandedHeight: 210.h,
          pinned: true,
          elevation: 0,
          automaticallyImplyLeading: false,
          backgroundColor: _Brand.deepAnchor,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: EdgeInsets.zero,
            background: Container(
              decoration: BoxDecoration(gradient: _Brand.headerGradient),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(children: [
                        Container(
                          width: 52.w, height: 52.w,
                          decoration: BoxDecoration(
                            color: AppColors.neutralWhite.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(15.r),
                          ),
                          child: Icon(Icons.person_rounded, size: 28.sp, color: AppColors.neutralWhite),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good ${_timeOfDay()}, ${isGuest ? 'Guest' : userName.split(' ').first}!',
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: AppColors.neutralWhite.withValues(alpha: 0.7)),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              isGuest ? 'Guest Mode' : userName,
                              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: AppColors.neutralWhite, letterSpacing: -.3),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )),
                        // FIX — this bell used to be purely decorative: a
                        // static red dot that showed regardless of whether
                        // there was anything unread, and tapping it did
                        // nothing. It now reflects the real count from
                        // `unreadNotificationsCountProvider` (which watches
                        // the same Supabase-backed, realtime-updated
                        // `notificationsProvider` the Notifications tab
                        // uses) and jumps straight to that tab on tap.
                        Builder(builder: (context) {
                          final unread = ref.watch(unreadNotificationsCountProvider);
                          return InkWell(
                            borderRadius: BorderRadius.circular(22.r),
                            onTap: () => ref.read(bottomNavProvider.notifier).state = 2,
                            child: Container(
                              width: 44.w, height: 44.w,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.neutralWhite.withValues(alpha: .15)),
                              child: Stack(children: [
                                Center(child: Icon(Icons.notifications_outlined, size: 22.sp, color: AppColors.neutralWhite)),
                                if (unread > 0)
                                  Positioned(
                                    top: 6.h, right: 6.w,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: unread > 9 ? 4.w : 0),
                                      width: unread > 9 ? null : 16.w,
                                      height: 16.w,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: unread > 9 ? BoxShape.rectangle : BoxShape.circle,
                                        borderRadius: unread > 9 ? BorderRadius.circular(8.r) : null,
                                        color: _Brand.dangerRed,
                                        border: Border.all(color: _Brand.deepAnchor, width: 1.5),
                                      ),
                                      child: Text(
                                        unread > 9 ? '9+' : '$unread',
                                        style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700, color: Colors.white, height: 1),
                                      ),
                                    ),
                                  ),
                              ]),
                            ),
                          );
                        }),
                      ]),
                      SizedBox(height: 14.h),
                      Row(children: [
                        Icon(Icons.location_on, size: 14.sp, color: AppColors.neutralWhite.withValues(alpha: 0.6)),
                        SizedBox(width: 4.w),
                        Text('Milaor, Camarines Sur', style: TextStyle(fontSize: 12.sp, color: Colors.white60)),
                        const Spacer(),
                        Icon(Icons.cloud_outlined, size: 14.sp, color: AppColors.neutralWhite.withValues(alpha: 0.6)),
                        SizedBox(width: 4.w),
                        Text('32°C  •  Partly Cloudy', style: TextStyle(fontSize: 12.sp, color: Colors.white60)),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        SliverPadding(
          // Scaffold already keeps this CustomScrollView's body above
          // the bottomNavigationBar automatically — this padding was
          // reserving a *second*, redundant chunk of clearance on top
          // of that, which is what left a large dead gap of empty
          // white space after the last card.
          padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 24.h, bottom: 24.h),
          sliver: SliverList(delegate: SliverChildListDelegate([
            _buildDashboardStats(colors),
            SizedBox(height: 28.h),
            _buildFloodStatusBanner(context),
            SizedBox(height: 28.h),
            _buildCitizenFeedback(context, colors),
            SizedBox(height: 28.h),
            _buildSectionLabel('Announcements', 'Latest news from the LGU', colors),
            SizedBox(height: 16.h),
            _buildAnnouncementFeed(colors),
            if (ref.watch(announcementsProvider).isNotEmpty) ...[
              SizedBox(height: 8.h),
              _buildViewAllButton(colors),
            ],
          ])),
        ),
      ],
    );
  }

  String _timeOfDay() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 18) return 'Afternoon';
    return 'Evening';
  }

  // ─── DASHBOARD STATS ─────────────────────────────────
  Widget _buildDashboardStats(AppColorScheme colors) {
    final stats = ref.watch(dashboardStatsProvider);
    final loading = stats.isLoading;
    return Row(children: [
      _statCard('Active\nProjects', loading ? null : '${stats.activeProjects}',
          Icons.engineering_rounded, _Brand.heritagePurple, colors),
      SizedBox(width: 12.w),
      _statCard('Budget\nUtilized',
          loading ? null : '${stats.budgetUtilizedPercent.round()}%',
          Icons.account_balance_wallet_rounded, _Brand.successGreen, colors),
      SizedBox(width: 12.w),
      _statCard('Resolved\nReports', loading ? null : '${stats.resolvedReports}',
          Icons.feedback_rounded, _Brand.infoBlue, colors),
      SizedBox(width: 12.w),
      _statCard('Barangay\nAssemblies',
          loading ? null : '${stats.barangayAssemblies}',
          Icons.groups_rounded, _Brand.warningAmber, colors),
    ]);
  }

  /// [value] is null while the figures are still loading — a small
  /// shimmer placeholder is shown instead of a fake number.
  Widget _statCard(String label, String? value, IconData icon, Color color, AppColorScheme colors) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 10.w),
        decoration: BoxDecoration(
          color: colors.cardSurface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: colors.border),
          boxShadow: [BoxShadow(color: AppColors.neutralBlack.withValues(alpha: .03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Container(
            width: 38.w, height: 38.w,
            decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(12.r)),
            child: Icon(icon, size: 20.sp, color: color),
          ),
          SizedBox(height: 10.h),
          value == null
              ? SizedBox(
                  width: 28.w, height: 18.h,
                  child: Center(child: SizedBox(
                    width: 14.w, height: 14.w,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color.withValues(alpha: .5)),
                  )),
                )
              : Text(value, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: colors.textPrimary, height: 1)),
          SizedBox(height: 4.h),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w500, color: colors.textMuted, height: 1.3)),
        ]),
      ),
    );
  }

  // ─── SECTION LABEL ────────────────────────────────────
  Widget _buildSectionLabel(String title, String subtitle, AppColorScheme colors) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: colors.textPrimary)),
      SizedBox(height: 3.h),
      Text(subtitle, style: TextStyle(fontSize: 13.sp, color: colors.textMuted)),
    ]);
  }

  // ─── FLOOD STATUS BANNER ──────────────────────────────
  Widget _buildFloodStatusBanner(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20.r),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FloodAlertScreen())),
      child: Container(
        width: double.infinity, padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_Brand.successGreen, Color(0xFF15803D)],
          ),
          boxShadow: [BoxShadow(color: _Brand.successGreen.withValues(alpha: .25), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Container(
            width: 50.w, height: 50.w,
            decoration: BoxDecoration(color: AppColors.neutralWhite.withValues(alpha: .2), borderRadius: BorderRadius.circular(16.r)),
            child: Icon(Icons.water_drop_rounded, size: 28.sp, color: AppColors.neutralWhite),
          ),
          SizedBox(width: 16.w),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bicol River Status', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.neutralWhite.withValues(alpha: .8), letterSpacing: 1.2)),
            SizedBox(height: 4.h),
            Text('Normal Water Level', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: AppColors.neutralWhite)),
            SizedBox(height: 4.h),
            Text('Safely within limits • All routes clear • Updated 14m ago', style: TextStyle(fontSize: 12.sp, color: AppColors.neutralWhite.withValues(alpha: .8))),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 18.sp, color: AppColors.neutralWhite.withValues(alpha: .7)),
        ]),
      ),
    );
  }

  // ─── CITIZEN FEEDBACK ─────────────────────────────────
  Widget _buildCitizenFeedback(BuildContext context, AppColorScheme colors) {
    return Container(
      width: double.infinity, padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: colors.border),
        boxShadow: [BoxShadow(color: AppColors.neutralBlack.withValues(alpha: .03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.rate_review_rounded, size: 22.sp, color: _Brand.heritagePurple),
          SizedBox(width: 8.w),
          Flexible(child: Text('Your Voice, Our Action',
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: colors.textPrimary))),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(color: _Brand.successGreen.withValues(alpha: .1), borderRadius: BorderRadius.circular(20.r)),
            child: Text('Voice of the People', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: _Brand.successGreen)),
          ),
        ]),
        SizedBox(height: 16.h),
        Text('How is the LGU service?', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        SizedBox(height: 12.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) => GestureDetector(
            onTap: _feedbackSubmitted ? null : () => setState(() => _feedbackRating = i + 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 6.w),
              child: Icon(
                i < _feedbackRating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 36.sp,
                color: i < _feedbackRating ? _Brand.warningAmber : colors.border,
              ),
            ),
          )),
        ),
        SizedBox(height: 4.h),
        Center(child: Text(
          _feedbackRating == 0 ? 'Tap the stars to rate' : _ratingLabel(_feedbackRating),
          style: TextStyle(
            fontSize: 12.sp,
            color: _feedbackRating > 0 ? _Brand.heritagePurple : colors.textMuted,
            fontWeight: _feedbackRating > 0 ? FontWeight.w600 : FontWeight.w400,
          ),
        )),
        if (_feedbackRating > 0 && !_feedbackSubmitted) ...[
          SizedBox(height: 14.h),
          TextField(
            controller: _feedbackController,
            maxLines: 2,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Any other suggestions? Write here...',
              hintStyle: TextStyle(fontSize: 12.sp, color: colors.textMuted),
              filled: true, fillColor: colors.background,
              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: _Brand.heritagePurple.withValues(alpha: .5)),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _feedbackSubmitted = true);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Thank you for your feedback! Long live Milaor!'),
                  backgroundColor: _Brand.successGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _Brand.heritagePurple, foregroundColor: AppColors.neutralWhite,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: 0,
              ),
              child: Text('Submit Feedback', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
        if (_feedbackSubmitted) ...[
          SizedBox(height: 14.h),
          Container(
            width: double.infinity, padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(color: _Brand.successGreen.withValues(alpha: .08), borderRadius: BorderRadius.circular(12.r)),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, size: 22.sp, color: _Brand.successGreen),
              SizedBox(width: 10.w),
              Expanded(child: Text(
                'Thank you! Your feedback has been received. Together we serve for Milaor!',
                style: TextStyle(fontSize: 12.sp, height: 1.4, color: _Brand.successGreen, fontWeight: FontWeight.w500),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  String _ratingLabel(int r) {
    const labels = ['', 'Needs improvement', 'Could be better', 'Okay, decent service', 'Good service!', 'Excellent! Keep it up!'];
    return labels[r];
  }

  // ─── ANNOUNCEMENT FEED ────────────────────────────────
  Widget _buildAnnouncementFeed(AppColorScheme colors) {
    final announcements = ref.watch(announcementsProvider);
    if (announcements.isEmpty) {
      return Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Text('No announcements yet.', style: TextStyle(fontSize: 14.sp, color: colors.textMuted)),
      ));
    }
    final preview = announcements.take(3).toList();
    return Column(children: [
      for (int i = 0; i < preview.length; i++) ...[
        if (i > 0) SizedBox(height: 16.h),
        _buildAnnouncementCard(
          category:    preview[i].category.toUpperCase(),
          // Was hard-coded to _Brand.heritagePurple, which is a deep
          // saturated purple tuned for light backgrounds. At low alpha
          // over the dark card surface it washed out to near-black —
          // colors.accentPurple resolves to a lighter lavender in dark
          // mode so the cover art, badge, and "Read More" pill stay
          // visible in both themes.
          accentColor: preview[i].isImportant ? _Brand.dangerRed : colors.accentPurple,
          icon:        preview[i].isImportant ? Icons.priority_high_rounded : Icons.campaign_rounded,
          title:       preview[i].title,
          excerpt:     preview[i].description,
          date:        preview[i].formattedDate,
          isUnread:    !preview[i].isRead,
          imageUrl:    preview[i].imageUrl,
          colors:      colors,
          onTap: () {
            ref.read(announcementsProvider.notifier).markAsRead(preview[i].id);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => AnnouncementDetailScreen(announcement: preview[i]),
            ));
          },
        ),
      ],
    ]);
  }

  Widget _buildAnnouncementCard({
    required String category, required Color accentColor, required IconData icon,
    required String title, required String excerpt, required String date,
    required bool isUnread, required AppColorScheme colors,
    String? imageUrl, VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.cardSurface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: colors.border),
          boxShadow: [BoxShadow(color: AppColors.neutralBlack.withValues(alpha: .04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
            child: Stack(children: [
              SizedBox(
                height: 170.h, width: double.infinity,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _cardFallback(accentColor, icon))
                    : _cardFallback(accentColor, icon),
              ),
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.neutralBlack.withValues(alpha: .15), AppColors.neutralBlack.withValues(alpha: .5)],
              )))),
              Positioned(left: 12.w, bottom: 12.h, child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: accentColor, borderRadius: BorderRadius.circular(8.r),
                  boxShadow: [BoxShadow(color: accentColor.withValues(alpha: .4), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 13.sp, color: AppColors.neutralWhite),
                  SizedBox(width: 5.w),
                  Text(category, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w800, color: AppColors.neutralWhite, letterSpacing: .8)),
                ]),
              )),
              if (isUnread) Positioned(top: 12.h, right: 12.w, child: Container(
                width: 12.w, height: 12.w,
                decoration: BoxDecoration(
                  color: _Brand.infoBlue, shape: BoxShape.circle,
                  border: Border.all(color: AppColors.neutralWhite, width: 2),
                  boxShadow: [BoxShadow(color: _Brand.infoBlue.withValues(alpha: .5), blurRadius: 6)],
                ),
              )),
            ]),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colors.textPrimary, height: 1.3)),
              SizedBox(height: 8.h),
              Text(excerpt, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.sp, height: 1.5, color: colors.textSecondary)),
              SizedBox(height: 14.h),
              Row(children: [
                Icon(Icons.access_time_rounded, size: 14.sp, color: colors.textMuted),
                SizedBox(width: 5.w),
                Text(date, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textMuted)),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(color: accentColor.withValues(alpha: .08), borderRadius: BorderRadius.circular(8.r)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Read More', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: accentColor)),
                    SizedBox(width: 4.w),
                    Icon(Icons.arrow_forward_rounded, size: 14.sp, color: accentColor),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _cardFallback(Color accentColor, IconData icon) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [accentColor.withValues(alpha: .7), accentColor.withValues(alpha: .35)],
      )),
      child: Center(child: Icon(icon, size: 48.sp, color: AppColors.neutralWhite.withValues(alpha: .9))),
    );
  }

  // ─── VIEW ALL BUTTON ──────────────────────────────────
  Widget _buildViewAllButton(AppColorScheme colors) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsListScreen())),
      child: Container(
        width: double.infinity, padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: colors.cardSurface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: _Brand.heritagePurple.withValues(alpha: .2)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.campaign_outlined, size: 18.sp, color: _Brand.heritagePurple),
          SizedBox(width: 8.w),
          Text('View All Announcements', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: _Brand.heritagePurple)),
          SizedBox(width: 6.w),
          Icon(Icons.arrow_forward_ios_rounded, size: 14.sp, color: _Brand.heritagePurple),
        ]),
      ),
    );
  }
}