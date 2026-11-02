import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import '../core/utils/date_formatter.dart';
import '../models/project_model.dart';
import 'status_badge.dart';
import 'priority_badge.dart';

class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback? onTap;

  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
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
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      project.title,
                      style: AppTextStyles.h3(context).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  PriorityBadge(priority: project.priority.name),
                ],
              ),
              const SizedBox(height: 8),
              if (project.description != null && project.description!.isNotEmpty)
                Text(
                  project.description!,
                  style: AppTextStyles.body(context).copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 16),
              // Progress Bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: project.progressPercentage / 100,
                        backgroundColor: isDark ? const Color(0xFF24324D) : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          project.progressPercentage == 100 ? AppColors.success : AppColors.primary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${project.progressPercentage.toStringAsFixed(0)}%',
                    style: AppTextStyles.caption(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Footer info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusBadge.forProjectStatus(project.status.name),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 15,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${project.completedTasksCount}/${project.tasksCount} tasks',
                        style: AppTextStyles.caption(context),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormatter.formatShortDate(project.dueDate),
                        style: AppTextStyles.caption(context),
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
