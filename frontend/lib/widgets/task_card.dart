import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import '../core/utils/date_formatter.dart';
import '../models/task_model.dart';
import 'status_badge.dart';
import 'priority_badge.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  final ValueChanged<TaskStatus>? onStatusChanged;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fast complete toggle
                  Transform.scale(
                    scale: 0.9,
                    child: Checkbox(
                      value: task.status == TaskStatus.done,
                      activeColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: onStatusChanged != null
                          ? (checked) {
                              onStatusChanged!(
                                checked == true ? TaskStatus.done : TaskStatus.inProgress,
                              );
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: AppTextStyles.bodyBold(context).copyWith(
                            decoration: task.status == TaskStatus.done
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.status == TaskStatus.done
                                ? (isDark ? AppColors.textMutedDark : AppColors.textMutedLight)
                                : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.description != null && task.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description!,
                            style: AppTextStyles.caption(context).copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PriorityBadge(priority: task.priority.name),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusBadge.forTaskStatus(task.status.name),
                  Row(
                    children: [
                      if (task.isOverdue) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.danger),
                              const SizedBox(width: 3),
                              Text(
                                'OVERDUE',
                                style: AppTextStyles.badge(context).copyWith(
                                  color: AppColors.danger,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (task.dueDate != null) ...[
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: task.isOverdue ? AppColors.danger : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormatter.formatShortDate(task.dueDate),
                          style: AppTextStyles.caption(context).copyWith(
                            color: task.isOverdue ? AppColors.danger : null,
                            fontWeight: task.isOverdue ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (task.commentsCount > 0) ...[
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 13,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${task.commentsCount}',
                          style: AppTextStyles.caption(context),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (task.assignee != null)
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          child: Text(
                            task.assignee!.fullName.isNotEmpty
                                ? task.assignee!.fullName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
