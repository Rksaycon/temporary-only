import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:may_laud/theme/app_colors.dart';
import 'package:may_laud/providers/content_providers.dart';
import 'package:may_laud/services/app_services.dart';

// FIX — this screen used to render a `_notifications` list that was
// hardcoded in the widget's state (6 fake entries, seeded once from
// `DateTime.now()`), so nothing an admin did on the web dashboard (e.g.
// changing a citizen report's status to "resolved") ever showed up here.
// It's now backed by `notificationsProvider`, which is the same
// Supabase-backed provider PushNotificationService refreshes whenever a
// push arrives — and which itself listens for realtime Postgres changes
// on the `notifications` table, so a status change made on the web
// appears here immediately, with or without a push actually landing.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = 'all';
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      await ref.read(notificationServiceProvider).fetchNotifications();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;

    final filtered = notifications.where((n) {
      if (_filter == 'unread') return !n.isRead;
      if (_filter == 'alerts') return n.type == 'alert';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text('Notifications', style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'all',    child: Text('All Notifications')),
              PopupMenuItem(value: 'unread', child: Text('Unread Only')),
              PopupMenuItem(value: 'alerts', child: Text('Alerts Only')),
            ],
            icon: Icon(Icons.filter_list, size: 28.sp, color: AppColors.heritagePurple),
          ),
          SizedBox(width: 12.w),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.heritagePurple,
        child: Column(children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            color: colors.surface,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$unreadCount Unread',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.heritagePurple)),
              TextButton(
                onPressed: unreadCount == 0
                    ? null
                    : () => ref.read(notificationServiceProvider).markAllAsRead(),
                child: Text('Mark All as Read', style: TextStyle(fontSize: 14.sp, color: AppColors.riverFlow, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          SizedBox(height: 8.h),
          if (_isRefreshing) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: filtered.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: 120.h),
                      Icon(Icons.notifications_none, size: 64.sp, color: colors.iconMuted),
                      SizedBox(height: 16.h),
                      Center(child: Text('No notifications', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colors.textSecondary))),
                      SizedBox(height: 8.h),
                      Center(
                        child: Text(
                          _filter == 'unread'
                              ? 'You have no unread notifications'
                              : _filter == 'alerts'
                                  ? 'No alert notifications'
                                  : 'You have no notifications yet',
                          style: TextStyle(fontSize: 14.sp, color: colors.textMuted),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: colors.divider),
                    itemBuilder: (_, i) => _buildItem(filtered[i], colors),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _buildItem(AppNotification n, AppColorScheme colors) {
    final (icon, iconColor) = switch (n.type) {
      'alert'        => (Icons.warning,          AppColors.error),
      'event'        => (Icons.event,            AppColors.infoAlt),
      'health'       => (Icons.medical_services, AppColors.success),
      'reminder'     => (Icons.notifications,    AppColors.warning),
      'report'       => (Icons.report_problem,   AppColors.warningAlt),
      'document'     => (Icons.description,      AppColors.infoAlt),
      'announcement' => (Icons.campaign,         AppColors.heritagePurple),
      _              => (Icons.info,             AppColors.heritagePurple),
    };

    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        color: AppColors.error,
        child: Icon(Icons.delete_outline, color: Colors.white, size: 26.sp),
      ),
      confirmDismiss: (_) => _confirmDelete(n),
      onDismissed: (_) => ref.read(notificationServiceProvider).deleteNotification(n.id),
      child: InkWell(
        onTap: () {
          if (!n.isRead) ref.read(notificationServiceProvider).markAsRead(n.id);
          _showDetails(n);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          color: n.isRead ? colors.surface : AppColors.heritagePurple.withValues(alpha: .06),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44.w, height: 44.w,
              decoration: BoxDecoration(color: iconColor.withOpacity(.1), shape: BoxShape.circle),
              child: Icon(icon, size: 22.sp, color: iconColor),
            ),
            SizedBox(width: 16.w),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(n.title,
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (!n.isRead)
                  Container(width: 10.w, height: 10.w, decoration: BoxDecoration(color: AppColors.heritagePurple, shape: BoxShape.circle)),
              ]),
              SizedBox(height: 4.h),
              Text(n.message, style: TextStyle(fontSize: 14.sp, color: colors.textSecondary, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
              SizedBox(height: 8.h),
              Text(n.formattedTime, style: TextStyle(fontSize: 12.sp, color: colors.textMuted)),
            ])),
            SizedBox(width: 4.w),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20.sp, color: colors.iconMuted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () async {
                if (await _confirmDelete(n) == true) {
                  ref.read(notificationServiceProvider).deleteNotification(n.id);
                }
              },
            ),
          ]),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(AppNotification n) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete notification?'),
        content: Text('This will remove "${n.title}". This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showDetails(AppNotification n) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(n.title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n.message, style: const TextStyle(fontSize: 16)),
        SizedBox(height: 16.h),
        Text('Received: ${n.formattedTime}', style: TextStyle(fontSize: 14.sp, color: AppColors.neutralGray500)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
  }
}