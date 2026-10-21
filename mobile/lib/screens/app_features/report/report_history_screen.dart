// lib/screens/app_features/report/report_history_screen.dart
//
// The resident's citizen-report history. Watches [citizenReportsProvider],
// which is kept live by a Supabase realtime subscription (see
// CitizenReportsProvider in content_providers.dart) — so when the web admin
// reviews a report and moves it received → assigned → in_progress →
// resolved/closed, the card here updates itself with no manual refresh. The
// same admin action also lands as a system notification via the `push` Edge
// Function, even while the app is minimized (see
// supabase/citizen_reports_status_tracking.sql).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:may_laud/providers/content_providers.dart';
import 'package:may_laud/theme/app_colors.dart';

/// The four stages a citizen report moves through, in order. Kept in sync
/// with [CitizenReport.timelineStep] in content_providers.dart.
const List<String> _kTimelineLabels = [
  'Received',
  'Assigned',
  'Ongoing',
  'Resolved',
];

/// Accent color for a report's status (already-normalized — see
/// [CitizenReport.normalizedStatus]).
Color _statusColor(String status) {
  switch (status) {
    case 'received':
      return AppColors.warningAlt;
    case 'assigned':
      return AppColors.infoAlt;
    case 'in_progress':
      return AppColors.heritagePurple;
    case 'resolved':
    case 'closed':
      return AppColors.success;
    default:
      return AppColors.infoAlt;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'received':
      return Icons.hourglass_bottom_rounded;
    case 'assigned':
      return Icons.assignment_turned_in_rounded;
    case 'in_progress':
      return Icons.engineering_rounded;
    case 'resolved':
      return Icons.check_circle_rounded;
    case 'closed':
      return Icons.archive_rounded;
    default:
      return Icons.report_problem_rounded;
  }
}

/// A resident-facing history for every citizen report they've submitted,
/// with live status tracking (ongoing / solved) driven by realtime updates.
class ReportHistoryScreen extends ConsumerStatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  ConsumerState<ReportHistoryScreen> createState() =>
      _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends ConsumerState<ReportHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // The provider is constructed once at app start, when nobody may be
    // signed in yet — so its constructor-time fetch/subscribe can silently
    // no-op. Re-fetching here guarantees the history always opens with this
    // resident's current reports (and attaches the realtime channel for
    // whoever is signed in now), even after a login/logout without restart.
    Future.microtask(
      () => ref.read(citizenReportsProvider.notifier).fetchReports(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reports = ref.watch(citizenReportsProvider);
    final stats = ref.watch(citizenReportStatsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          'My Reports',
          style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w700),
        ),
        actions: [
          const _LiveBadge(),
          SizedBox(width: 16.w),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.heritagePurple,
        onRefresh: () =>
            ref.read(citizenReportsProvider.notifier).fetchReports(),
        child: reports.isEmpty
            ? _buildEmptyState(colors)
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
                itemCount: reports.length + 2,
                separatorBuilder: (_, __) => SizedBox(height: 14.h),
                itemBuilder: (context, index) {
                  if (index == 0) return _buildIntroBanner(colors);
                  if (index == 1) return _buildStatsRow(colors, stats);
                  return _ReportCard(report: reports[index - 2]);
                },
              ),
      ),
    );
  }

  /// Total / Ongoing / Solved counters — the quick "is anything still being
  /// worked on?" answer at the top of the history.
  Widget _buildStatsRow(AppColorScheme colors, Map<String, int> stats) {
    Widget stat(String label, int value, Color color, IconData icon) {
      return Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: colors.cardSurface,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: color.withValues(alpha: .18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15.sp, color: color),
                  SizedBox(width: 6.w),
                  Text(
                    '$value',
                    style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary),
                  ),
                ],
              ),
              SizedBox(height: 3.h),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        stat('Total', stats['total'] ?? 0, AppColors.infoAlt,
            Icons.receipt_long_rounded),
        SizedBox(width: 10.w),
        stat('Ongoing', stats['ongoing'] ?? 0, AppColors.warningAlt,
            Icons.pending_actions_rounded),
        SizedBox(width: 10.w),
        stat('Solved', stats['resolved'] ?? 0, AppColors.success,
            Icons.verified_rounded),
      ],
    );
  }

  Widget _buildEmptyState(AppColorScheme colors) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(32.w, 72.h, 32.w, 32.h),
      children: [
        Icon(Icons.report_problem_outlined,
            size: 72.sp, color: colors.iconMuted),
        SizedBox(height: 18.h),
        Text(
          'No reports yet',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary),
        ),
        SizedBox(height: 8.h),
        Text(
          'Reports you submit will appear here and update live — Received, '
          'Ongoing, Solved — as officials review them.',
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 13.sp, color: colors.textMuted, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildIntroBanner(AppColorScheme colors) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.heritagePurple.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16.r),
        border:
            Border.all(color: AppColors.heritagePurple.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_rounded,
              size: 20.sp, color: AppColors.heritagePurple),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Statuses update automatically — no need to refresh. You will '
              'also get a notification when a report is reviewed or solved.',
              style: TextStyle(
                  fontSize: 12.5.sp,
                  color: colors.textSecondary,
                  height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// A green "LIVE" pill so residents know the list is realtime, not static.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.successAlt.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.sp,
            height: 7.sp,
            decoration: const BoxDecoration(
                color: AppColors.success, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Text(
            'LIVE',
            style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
                color: AppColors.success),
          ),
        ],
      ),
    );
  }
}

/// Rounded status pill — wording matches the SQL trigger's push text
/// (citizen_reports_status_label) via [CitizenReport.statusLabel].
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.report});

  final CitizenReport report;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(report.normalizedStatus);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        report.statusLabel,
        style: TextStyle(
            fontSize: 11.sp, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Compact 4-segment progress bar shown on each card — filled up to the
/// report's current stage (Received → Assigned → Ongoing → Resolved).
class _MiniTimeline extends StatelessWidget {
  const _MiniTimeline(
      {required this.report, required this.color, required this.colors});

  final CitizenReport report;
  final Color color;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final active = report.timelineStep;
    final children = <Widget>[];
    for (var i = 0; i < _kTimelineLabels.length; i++) {
      if (i > 0) children.add(SizedBox(width: 6.w));
      final done = i <= active;
      children.add(
        Expanded(
          child: Container(
            height: 4.h,
            decoration: BoxDecoration(
              color: done ? color : colors.border,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
        ),
      );
    }
    return Row(children: children);
  }
}

/// One report in the history: what was reported, its live status chip, the
/// mini timeline, the current-stage caption, and when it was submitted.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final CitizenReport report;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = _statusColor(report.normalizedStatus);

    return Material(
      color: colors.cardSurface,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportHistoryDetailScreen(report: report),
          ),
        ),
        child: Container(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 10,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46.w,
                    height: 46.w,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(13.r),
                    ),
                    child: Icon(_statusIcon(report.normalizedStatus),
                        size: 23.sp, color: color),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15.5.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          report.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          report.reference,
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: colors.textMuted,
                              letterSpacing: .3),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _StatusChip(report: report),
                ],
              ),
              SizedBox(height: 16.h),
              Text(report.verificationLabel,
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: color)),
              SizedBox(height: 6.h),
              Text(report.verificationMessage,
                  style: TextStyle(fontSize: 12.sp, color: colors.textSecondary)),
              if (report.verificationStatus != 'rejected')
                _MiniTimeline(report: report, color: color, colors: colors),
              SizedBox(height: 8.h),
              // Current-stage caption so the bar is readable at a glance —
              // same sentence the push notification uses.
              Text(
                report.verificationStatus == 'verified'
                    ? report.statusMessage : '',
                style:
                    TextStyle(fontSize: 12.sp, color: color, height: 1.3),
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 14.sp, color: colors.textMuted),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'Submitted ${report.submittedLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12.sp, color: colors.textMuted),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 20.sp, color: colors.iconMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full status details for a single report, including a vertical timeline.
/// Re-reads the report from the live provider so a realtime update arriving
/// while this screen is open (or via a tapped push notification) is reflected
/// immediately.
class ReportHistoryDetailScreen extends ConsumerWidget {
  const ReportHistoryDetailScreen({super.key, required this.report});

  final CitizenReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final current = ref.watch(citizenReportsProvider).firstWhere(
          (r) => r.id == report.id,
          orElse: () => report,
        );
    final color = _statusColor(current.normalizedStatus);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          'Track Report',
          style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
        children: [
          _buildStatusHero(colors, current, color),
          SizedBox(height: 16.h),
          if (current.verificationStatus != 'rejected')
            _buildProgressCard(colors, current, color),
          SizedBox(height: 16.h),
          _buildDetailsCard(colors, current),
        ],
      ),
    );
  }

  Widget _buildStatusHero(
      AppColorScheme colors, CitizenReport current, Color color) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13.r),
                ),
                child: Icon(_statusIcon(current.normalizedStatus),
                    size: 23.sp, color: color),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.statusLabel,
                      style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: color),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      current.reference,
                      style: TextStyle(
                          fontSize: 12.sp,
                          color: colors.textMuted,
                          letterSpacing: .3),
                    ),
                  ],
                ),
              ),
              _StatusChip(report: current),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            current.verificationStatus == 'verified'
                ? current.statusMessage : current.verificationMessage,
            style: TextStyle(
                fontSize: 13.sp, color: colors.textSecondary, height: 1.4),
          ),
          SizedBox(height: 6.h),
          Text(
            'Last updated ${current.lastUpdatedLabel}',
            style: TextStyle(fontSize: 11.5.sp, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
      AppColorScheme colors, CitizenReport current, Color color) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROGRESS',
            style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: colors.textMuted,
                letterSpacing: .6),
          ),
          SizedBox(height: 16.h),
          for (var i = 0; i < _kTimelineLabels.length; i++)
            _verticalStep(colors, current, color, i),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(AppColorScheme colors, CitizenReport current) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REPORT DETAILS',
            style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: colors.textMuted,
                letterSpacing: .6),
          ),
          SizedBox(height: 16.h),
          _infoRow(
              colors, Icons.category_rounded, 'Category', current.category),
          if (current.location.isNotEmpty)
            _infoRow(
                colors, Icons.place_rounded, 'Location', current.location),
          if (current.description.isNotEmpty)
            _infoRow(colors, Icons.notes_rounded, 'Description',
                current.description),
          _infoRow(colors, Icons.fact_check_outlined, 'Verification',
              current.verificationLabel),
          if (current.verificationNote.isNotEmpty)
            _infoRow(colors, Icons.comment_outlined, 'Admin feedback',
                current.verificationNote),
          _infoRow(colors, Icons.schedule_rounded, 'Submitted',
              current.submittedLabel),
          _infoRow(colors, Icons.update_rounded, 'Last Updated',
              current.lastUpdatedLabel,
              last: true),
        ],
      ),
    );
  }

  /// One row of the vertical timeline — icon + label, dimmed until the
  /// report reaches that stage.
  Widget _verticalStep(AppColorScheme colors, CitizenReport current,
      Color color, int i) {
    final done = i <= current.timelineStep;
    final stepColor = done ? color : colors.textMuted;
    final isLast = i == _kTimelineLabels.length - 1;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18.h),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: stepColor.withValues(alpha: done ? .14 : .07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              done ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
              size: 17.sp,
              color: stepColor,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              _kTimelineLabels[i],
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                color: done ? colors.textPrimary : colors.textMuted,
              ),
            ),
          ),
          if (i == current.timelineStep)
            Text(
              'Current',
              style: TextStyle(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(AppColorScheme colors, IconData icon, String label,
      String value,
      {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: AppColors.heritagePurple.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, size: 19.sp, color: AppColors.heritagePurple),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textMuted,
                      letterSpacing: .2),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}






