// lib/screens/app_features/document/document_tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:may_laud/providers/content_providers.dart';
import 'package:may_laud/theme/app_colors.dart';

import 'document_request_modal.dart';

/// The four stages a document request moves through, in order. Kept in sync
/// with [DocumentRequest.timelineStep] in content_providers.dart.
const List<String> _kTimelineLabels = [
  'Submitted',
  'Processing',
  'Ready',
  'Released',
];

/// Accent color for a request's status. Takes the already-normalized status
/// (see [DocumentRequest.normalizedStatus]).
Color _statusColor(String status) {
  switch (status) {
    case 'pending':
      return AppColors.warningAlt;
    case 'processing':
      return AppColors.infoAlt;
    case 'ready':
      return AppColors.successAlt;
    case 'released':
    case 'completed':
      return AppColors.success;
    case 'rejected':
      return AppColors.errorDark;
    default:
      return AppColors.infoAlt;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'pending':
      return Icons.hourglass_bottom_rounded;
    case 'processing':
      return Icons.autorenew_rounded;
    case 'ready':
      return Icons.inventory_2_rounded;
    case 'released':
      return Icons.verified_rounded;
    case 'completed':
      return Icons.check_circle_rounded;
    case 'rejected':
      return Icons.cancel_rounded;
    default:
      return Icons.receipt_long_rounded;
  }
}

/// A resident-facing tracker for every document request they've submitted.
///
/// Watches [documentRequestsProvider], which is kept live by a Supabase
/// realtime subscription (see DocumentRequestsProvider) — so when the office
/// changes a request's status it appears here automatically, without any
/// manual refresh.
class DocumentTrackingScreen extends ConsumerStatefulWidget {
  const DocumentTrackingScreen({super.key});

  @override
  ConsumerState<DocumentTrackingScreen> createState() =>
      _DocumentTrackingScreenState();
}

class _DocumentTrackingScreenState
    extends ConsumerState<DocumentTrackingScreen> {
  @override
  void initState() {
    super.initState();
    // The provider is constructed once at app start, when nobody may be
    // signed in yet — so its constructor-time fetch/subscribe can silently
    // no-op. Re-fetching here guarantees the tracker always opens with this
    // resident's current requests (and attaches the realtime channel for
    // whoever is signed in now), even after a login/logout without restart.
    Future.microtask(
      () => ref.read(documentRequestsProvider.notifier).fetchRequests(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final requests = ref.watch(documentRequestsProvider);

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
          'My Document Requests',
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
            ref.read(documentRequestsProvider.notifier).fetchRequests(),
        child: requests.isEmpty
            ? _buildEmptyState(colors)
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
                itemCount: requests.length + 1,
                separatorBuilder: (_, __) => SizedBox(height: 14.h),
                itemBuilder: (context, index) {
                  if (index == 0) return _buildIntroBanner(colors);
                  return _RequestCard(request: requests[index - 1]);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState(AppColorScheme colors) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(32.w, 72.h, 32.w, 32.h),
      children: [
        Icon(Icons.receipt_long_outlined, size: 72.sp, color: colors.iconMuted),
        SizedBox(height: 18.h),
        Text(
          'No document requests yet',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary),
        ),
        SizedBox(height: 8.h),
        Text(
          'Requests you submit will appear here and update live as the office '
          'processes them.',
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
          Icon(Icons.sync_rounded, size: 20.sp, color: AppColors.heritagePurple),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Statuses update automatically — no need to refresh. Pull down '
              'anytime to check manually.',
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
            width: 7.w,
            height: 7.w,
            decoration: const BoxDecoration(
                color: AppColors.successAlt, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Text(
            'LIVE',
            style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.successAlt,
                letterSpacing: .8),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.request});

  final DocumentRequest request;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(request.normalizedStatus);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        request.statusLabel,
        style: TextStyle(
            fontSize: 11.sp, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Compact 4-segment progress bar shown on each card.
class _MiniTimeline extends StatelessWidget {
  const _MiniTimeline(
      {required this.request, required this.color, required this.colors});

  final DocumentRequest request;
  final Color color;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    if (request.isRejected) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.errorDark.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Text(
          request.statusMessage,
          style: TextStyle(
              fontSize: 12.sp, color: AppColors.errorDark, height: 1.3),
        ),
      );
    }

    final active = request.timelineStep;
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


class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final DocumentRequest request;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = _statusColor(request.normalizedStatus);

    return Material(
      color: colors.cardSurface,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: () => showDocumentRequestModal(
          context,
          request: request,
          onViewDetails: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentRequestDetailScreen(request: request),
            ),
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
                children: [
                  Container(
                    width: 46.w,
                    height: 46.w,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(13.r),
                    ),
                    child: Icon(_statusIcon(request.normalizedStatus),
                        size: 23.sp, color: color),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.documentType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15.5.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary),
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          children: [
                            Icon(Icons.person_rounded,
                                size: 12.sp, color: colors.textMuted),
                            SizedBox(width: 5.w),
                            Expanded(
                              child: Text(
                                request.requesterName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          request.reference,
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: colors.textMuted,
                              letterSpacing: .3),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _StatusChip(request: request),
                ],
              ),
              SizedBox(height: 16.h),
              _MiniTimeline(request: request, color: color, colors: colors),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 14.sp, color: colors.textMuted),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'Submitted ${request.submittedLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.sp, color: colors.textMuted),
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


/// Full status details for a single request, including a vertical timeline.
/// Re-reads the request from the live provider so a realtime update arriving
/// while this screen is open is reflected immediately.
class DocumentRequestDetailScreen extends ConsumerWidget {
  const DocumentRequestDetailScreen({super.key, required this.request});

  final DocumentRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final current = ref.watch(documentRequestsProvider).firstWhere(
          (r) => r.id == request.id,
          orElse: () => request,
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
          'Track Request',
          style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
        children: [
          _statusHero(colors, current, color),
          SizedBox(height: 16.h),
          if (!current.isRejected) ...[
            _card(colors, child: _timeline(colors, current, color)),
            SizedBox(height: 16.h),
          ],
          _card(
            colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel(colors, 'Request Details'),
                SizedBox(height: 16.h),
                _infoRow(colors, Icons.person_outline_rounded, 'Requested By',
                    current.requesterName),
                _infoRow(colors, Icons.description_outlined, 'Document',
                    current.documentType),
                _infoRow(
                    colors, Icons.flag_outlined, 'Purpose', current.purpose),
                if (current.urgency != null && current.urgency!.isNotEmpty)
                  _infoRow(colors, Icons.speed_rounded, 'Urgency',
                      current.urgency!),
                if (current.address != null && current.address!.isNotEmpty)
                  _infoRow(colors, Icons.home_outlined, 'Address',
                      current.address!),
                if (current.fee != null && current.fee!.isNotEmpty)
                  _infoRow(
                      colors, Icons.receipt_long_outlined, 'Fee', current.fee!),
                if (current.additionalNotes != null &&
                    current.additionalNotes!.isNotEmpty)
                  _infoRow(colors, Icons.sticky_note_2_outlined,
                      'Additional Notes', current.additionalNotes!),
                if (current.notes != null && current.notes!.isNotEmpty)
                  _infoRow(
                      colors, Icons.notes_outlined, 'Notes', current.notes!),
                if (current.hasAttachments)
                  _infoRow(
                      colors,
                      Icons.attach_file_rounded,
                      'Attachments',
                      '${current.attachmentUrls.length} file'
                          '${current.attachmentUrls.length > 1 ? 's' : ''} uploaded'),
                _infoRow(colors, Icons.confirmation_number_outlined, 'Reference',
                    current.reference),
                _infoRow(colors, Icons.schedule_outlined, 'Submitted',
                    current.submittedLabel,
                    last: current.updatedLabel == null),
                if (current.updatedLabel != null)
                  _infoRow(colors, Icons.update_outlined, 'Last Updated',
                      current.updatedLabel!,
                      last: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusHero(AppColorScheme colors, DocumentRequest r, Color color) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(15.r),
                ),
                child: Icon(_statusIcon(r.normalizedStatus),
                    size: 27.sp, color: color),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.statusLabel,
                      style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: color),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      r.documentType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.sp, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const _LiveBadge(),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            r.statusMessage,
            style: TextStyle(
                fontSize: 13.5.sp, color: colors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }


  Widget _timeline(AppColorScheme colors, DocumentRequest r, Color color) {
    final active = r.timelineStep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(colors, 'Progress'),
        SizedBox(height: 18.h),
        Column(
          children: List.generate(_kTimelineLabels.length, (i) {
            final done = i <= active;
            final isLast = i == _kTimelineLabels.length - 1;
            final dotColor = done ? color : colors.border;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 22.w,
                        height: 22.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done ? color : colors.surface,
                          border: Border.all(color: dotColor, width: 2),
                        ),
                        child: done
                            ? Icon(Icons.check,
                                size: 13.sp, color: Colors.white)
                            : null,
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2.w,
                            color: (done && i < active)
                                ? color
                                : colors.border,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 20.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _kTimelineLabels[i],
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight:
                                  done ? FontWeight.w700 : FontWeight.w500,
                              color: done
                                  ? colors.textPrimary
                                  : colors.textMuted,
                            ),
                          ),
                          if (i == active)
                            Padding(
                              padding: EdgeInsets.only(top: 2.h),
                              child: Text(
                                'Current status',
                                style: TextStyle(
                                    fontSize: 11.5.sp,
                                    fontWeight: FontWeight.w600,
                                    color: color),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }


  Widget _card(AppColorScheme colors, {required Widget child}) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: colors.cardSurface,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 10,
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );

  Widget _sectionLabel(AppColorScheme colors, String text) => Text(
        text,
        style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: colors.textMuted,
            letterSpacing: .6),
      );

  Widget _infoRow(AppColorScheme colors, IconData icon, String label,
      String value, {bool last = false}) {
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

