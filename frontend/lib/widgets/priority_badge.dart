import 'package:flutter/material.dart';
import '../core/constants/app_text_styles.dart';

class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bgColor;
    IconData icon;

    switch (priority.toLowerCase()) {
      case 'urgent':
        color = const Color(0xFFEF4444);
        bgColor = const Color(0xFF7F1D1D);
        icon = Icons.keyboard_double_arrow_up_rounded;
        break;
      case 'high':
        color = const Color(0xFFF97316);
        bgColor = const Color(0xFF7C2D12);
        icon = Icons.arrow_upward_rounded;
        break;
      case 'medium':
        color = const Color(0xFFFBBF24);
        bgColor = const Color(0xFF78350F);
        icon = Icons.drag_handle_rounded;
        break;
      case 'low':
      default:
        color = const Color(0xFF38BDF8);
        bgColor = const Color(0xFF0C4A6E);
        icon = Icons.arrow_downward_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.35),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            priority.toUpperCase(),
            style: AppTextStyles.badge(context).copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
