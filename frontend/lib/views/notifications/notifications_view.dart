import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationViewModel>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifVM = context.watch<NotificationViewModel>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => notifVM.fetchNotifications(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('System Notifications', style: AppTextStyles.h1(context)),
                      const SizedBox(height: 4),
                      Text(
                        'Audit alerts, task assignment notices, and deadline alerts.',
                        style: AppTextStyles.subtitle(context),
                      ),
                    ],
                  ),
                  if (notifVM.unreadCount > 0)
                    OutlinedButton.icon(
                      onPressed: () => notifVM.markAllAsRead(),
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('Mark All Read'),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              if (notifVM.isLoading && notifVM.notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: LoadingView(message: 'Loading notifications...'),
                )
              else if (notifVM.errorMessage != null && notifVM.notifications.isEmpty)
                ErrorView(
                  message: notifVM.errorMessage!,
                  onRetry: () => notifVM.fetchNotifications(),
                )
              else if (notifVM.notifications.isEmpty)
                const EmptyView(
                  title: 'No Notifications',
                  message: 'You are all caught up! No unread notifications.',
                  icon: Icons.notifications_off_outlined,
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notifVM.notifications.length,
                  itemBuilder: (context, idx) {
                    final notif = notifVM.notifications[idx];
                    IconData icon = Icons.info_outline_rounded;
                    Color iconColor = AppColors.primary;

                    switch (notif.notificationType) {
                      case 'task_assigned':
                        icon = Icons.assignment_turned_in_outlined;
                        iconColor = AppColors.primary;
                        break;
                      case 'status_changed':
                        icon = Icons.sync_rounded;
                        iconColor = AppColors.warning;
                        break;
                      case 'comment_added':
                        icon = Icons.chat_bubble_outline_rounded;
                        iconColor = AppColors.secondary;
                        break;
                      case 'deadline_approaching':
                        icon = Icons.alarm_rounded;
                        iconColor = AppColors.danger;
                        break;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: notif.isRead
                          ? null
                          : (isDark ? const Color(0xFF19253B) : const Color(0xFFEFF6FF)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: iconColor, size: 20),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                notif.title,
                                style: AppTextStyles.bodyBold(context).copyWith(
                                  fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                                ),
                              ),
                            ),
                            if (!notif.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(notif.message, style: AppTextStyles.body(context)),
                            const SizedBox(height: 4),
                            Text(
                              DateFormatter.formatTimeAgo(notif.createdAt),
                              style: AppTextStyles.caption(context),
                            ),
                          ],
                        ),
                        onTap: () {
                          if (!notif.isRead) {
                            notifVM.markAsRead(notif.id);
                          }
                          if (notif.linkUrl != null && notif.linkUrl!.isNotEmpty) {
                            context.go(notif.linkUrl!);
                          }
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
