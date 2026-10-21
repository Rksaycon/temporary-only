// lib/screens/app_features/document/document_request_modal.dart
//
// A reusable modal that shows a single document request. It is where the
// realtime / push flow lands: when an office admin changes a request's status
// in the web admin (Maylaud_Web), the mobile app both (a) refreshes the
// tracker live over Supabase Realtime and (b) pops this sheet, so the resident
// sees the update without hunting for it — whether the app was already open
// (realtime event) or was just opened from a background/terminated push.
//
// Shown from:
//   * DocumentTrackingScreen — tapping a request card.
//   * main.dart — a live status change while the app is open, or a tapped
//     `document_request` push notification.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:may_laud/providers/content_providers.dart';
import 'package:may_laud/theme/app_colors.dart';

/// The four stages a request moves through — kept in sync with
/// [DocumentRequest.timelineStep] and the private copy in
/// document_tracking_screen.dart.
const List<String> _kTimelineLabels = [
  'Submitted',
  'Processing',
  'Ready',
  'Released',
];

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

/// Presents [request] in a modal bottom sheet.
///
/// [highlightUpdate] adds a "status updated" banner (used when the sheet is
/// opened because of a live change rather than a manual tap). [onViewDetails]
/// is invoked after the sheet closes if the caller wants to open the full
/// document-request detail screen.
Future<void> showDocumentRequestModal(
  BuildContext context, {
  required DocumentRequest request,
  bool highlightUpdate = false,
  VoidCallback? onViewDetails,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DocumentRequestModal(
      requestId: request.id,
      fallback: request,
      highlightUpdate: highlightUpdate,
      onViewDetails: onViewDetails,
    ),
  );
}

class _DocumentRequestModal extends ConsumerWidget {
  const _DocumentRequestModal({
    required this.requestId,
    required this.fallback,
    required this.highlightUpdate,
    this.onViewDetails,
  });

  final String requestId;
  final DocumentRequest fallback;
  final bool highlightUpdate;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    // Re-read from the live provider so a realtime update landing while this
    // sheet is open updates it in place instead of showing a stale snapshot.
    final current = ref.watch(documentRequestsProvider).firstWhere(
          (r) => r.id == requestId,
          orElse: () => fallback,
        );

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(20.r),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (highlightUpdate) ...[
                        _updateBanner(colors),
                        SizedBox(height: 16.h),
                      ],
                      _statusHero(colors, current),
                      SizedBox(height: 18.h),
                      _sectionLabel(colors, 'Progress'),
                      SizedBox(height: 14.h),
                      if (current.isRejected)
                        _rejectedNotice(colors, current)
                      else
                        _timeline(colors, current),
                      SizedBox(height: 20.h),
                      _sectionLabel(colors, 'Request Details'),
                      SizedBox(height: 14.h),
                      _details(colors, current),
                    ],
                  ),
                ),
              ),
              _actions(context, colors),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SECTIONS ─────────────────────────────────────────

  Widget _updateBanner(AppColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.heritagePurple.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14.r),
        border:
            Border.all(color: AppColors.heritagePurple.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_rounded,
              size: 20.sp, color: AppColors.heritagePurple),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Your document request was just updated.',
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusHero(AppColorScheme colors, DocumentRequest r) {
    final color = _statusColor(r.normalizedStatus);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(
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
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
                SizedBox(height: 2.h),
                Text(
                  r.documentType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 13.sp, color: colors.textSecondary),
                ),
                SizedBox(height: 2.h),
                Text(
                  r.reference,
                  style: TextStyle(
                      fontSize: 11.5.sp,
                      color: colors.textMuted,
                      letterSpacing: .3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rejectedNotice(AppColorScheme colors, DocumentRequest r) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.errorDark.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        r.statusMessage,
        style: TextStyle(
            fontSize: 13.sp, color: AppColors.errorDark, height: 1.35),
      ),
    );
  }

  Widget _timeline(AppColorScheme colors, DocumentRequest r) {
    final active = r.timelineStep;
    final color = _statusColor(r.normalizedStatus);
    return Column(
      children: [
        Row(
          children: List.generate(_kTimelineLabels.length, (i) {
            final done = i <= active;
            return Expanded(
              child: Container(
                height: 5.h,
                margin: EdgeInsets.symmetric(horizontal: 2.w),
                decoration: BoxDecoration(
                  color: done ? color : colors.border,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 10.h),
        Row(
          children: List.generate(_kTimelineLabels.length, (i) {
            final done = i <= active;
            return Expanded(
              child: Text(
                _kTimelineLabels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: i == active ? FontWeight.w700 : FontWeight.w500,
                  color: done ? color : colors.textMuted,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _details(AppColorScheme colors, DocumentRequest r) {
    return Column(
      children: [
        _infoRow(colors, Icons.description_outlined, 'Document', r.documentType),
        _infoRow(colors, Icons.flag_outlined, 'Purpose', r.purpose),
        if (r.urgency != null && r.urgency!.isNotEmpty)
          _infoRow(colors, Icons.speed_rounded, 'Urgency', r.urgency!),
        if (r.fee != null && r.fee!.isNotEmpty)
          _infoRow(colors, Icons.receipt_long_outlined, 'Fee', r.fee!),
        if (r.address != null && r.address!.isNotEmpty)
          _infoRow(colors, Icons.home_outlined, 'Address', r.address!),
        if (r.hasAttachments)
          _infoRow(
            colors,
            Icons.attach_file_rounded,
            'Attachments',
            '${r.attachmentUrls.length} file'
                '${r.attachmentUrls.length > 1 ? 's' : ''} uploaded',
          ),
        _infoRow(colors, Icons.schedule_outlined, 'Submitted', r.submittedLabel),
        if (r.updatedLabel != null)
          _infoRow(
              colors, Icons.update_outlined, 'Last Updated', r.updatedLabel!),
      ],
    );
  }

  Widget _infoRow(
      AppColorScheme colors, IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: colors.iconMuted),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textMuted,
                      letterSpacing: .2),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(AppColorScheme colors, String text) => Text(
        text.toUpperCase(),
        style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: colors.textMuted,
            letterSpacing: .8),
      );

  Widget _actions(BuildContext context, AppColorScheme colors) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (onViewDetails != null) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onViewDetails!.call();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.heritagePurple,
                  side: BorderSide(
                      color: AppColors.heritagePurple.withValues(alpha: .4)),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r)),
                ),
                child: Text(
                  'View full details',
                  style:
                      TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SizedBox(width: 12.w),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.heritagePurple,
                foregroundColor: AppColors.neutralWhite,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r)),
              ),
              child: Text(
                'Close',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
