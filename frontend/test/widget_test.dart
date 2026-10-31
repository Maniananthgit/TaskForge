import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskforge_app/core/constants/app_colors.dart';
import 'package:taskforge_app/models/task_model.dart';
import 'package:taskforge_app/widgets/stat_card.dart';
import 'package:taskforge_app/widgets/status_badge.dart';
import 'package:taskforge_app/widgets/priority_badge.dart';
import 'package:taskforge_app/widgets/task_card.dart';

void main() {
  group('TaskForge UI Widget Tests', () {
    testWidgets('StatCard displays title, value, and subtitle properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Active Tasks',
              value: '42',
              icon: Icons.check_circle_rounded,
              iconColor: AppColors.primary,
              subtitle: 'Current sprint items',
            ),
          ),
        ),
      );

      expect(find.text('Active Tasks'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Current sprint items'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('StatusBadge renders for TaskStatus and ProjectStatus', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.forTaskStatus('in_progress'),
                StatusBadge.forProjectStatus('completed'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('PriorityBadge renders Urgent and High badges', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PriorityBadge(priority: 'urgent'),
                PriorityBadge(priority: 'high'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('URGENT'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
    });

    testWidgets('TaskCard renders title, status and overdue indicator when overdue', (WidgetTester tester) async {
      final task = TaskModel(
        id: 1,
        projectId: 1,
        title: 'Fix High Priority Memory Leak',
        description: 'Profile heap usage on worker instances',
        status: TaskStatus.inProgress,
        priority: TaskPriority.urgent,
        isOverdue: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(task: task),
          ),
        ),
      );

      expect(find.text('Fix High Priority Memory Leak'), findsOneWidget);
      expect(find.text('Profile heap usage on worker instances'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('URGENT'), findsOneWidget);
      expect(find.text('OVERDUE'), findsOneWidget);
    });
  });
}
