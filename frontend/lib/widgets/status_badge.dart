import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color backgroundColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  factory StatusBadge.forTaskStatus(String status) {
    switch (status.toLowerCase()) {
      case 'backlog':
        return const StatusBadge(
          label: 'Backlog',
          color: Color(0xFF94A3B8),
          backgroundColor: Color(0xFF1E293B),
        );
      case 'todo':
        return const StatusBadge(
          label: 'To Do',
          color: Color(0xFF38BDF8),
          backgroundColor: Color(0xFF0C4A6E),
        );
      case 'in_progress':
      case 'inprogress':
        return const StatusBadge(
          label: 'In Progress',
          color: Color(0xFFFBBF24),
          backgroundColor: Color(0xFF78350F),
        );
      case 'in_review':
      case 'inreview':
        return const StatusBadge(
          label: 'In Review',
          color: Color(0xFFA78BFA),
          backgroundColor: Color(0xFF4C1D95),
        );
      case 'done':
        return const StatusBadge(
          label: 'Done',
          color: Color(0xFF34D399),
          backgroundColor: Color(0xFF064E3B),
        );
      default:
        return StatusBadge(
          label: status,
          color: AppColors.primary,
          backgroundColor: AppColors.primaryDark.withOpacity(0.3),
        );
    }
  }

  factory StatusBadge.forProjectStatus(String status) {
    switch (status.toLowerCase()) {
      case 'planning':
        return const StatusBadge(
          label: 'Planning',
          color: Color(0xFF38BDF8),
          backgroundColor: Color(0xFF0C4A6E),
        );
      case 'in_progress':
      case 'inprogress':
        return const StatusBadge(
          label: 'In Progress',
          color: Color(0xFFFBBF24),
          backgroundColor: Color(0xFF78350F),
        );
      case 'on_hold':
      case 'onhold':
        return const StatusBadge(
          label: 'On Hold',
          color: Color(0xFFF87171),
          backgroundColor: Color(0xFF7F1D1D),
        );
      case 'completed':
        return const StatusBadge(
          label: 'Completed',
          color: Color(0xFF34D399),
          backgroundColor: Color(0xFF064E3B),
        );
      case 'archived':
        return const StatusBadge(
          label: 'Archived',
          color: Color(0xFF94A3B8),
          backgroundColor: Color(0xFF1E293B),
        );
      default:
        return StatusBadge(
          label: status,
          color: AppColors.primary,
          backgroundColor: AppColors.primaryDark.withOpacity(0.3),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        label,
        style: AppTextStyles.badge(context).copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
