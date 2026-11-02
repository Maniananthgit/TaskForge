import '../core/utils/network_utils.dart';
import '../models/dashboard_metrics_model.dart';
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../services/dashboard_service.dart';

class DashboardRepository {
  final DashboardService _dashboardService;

  DashboardRepository(this._dashboardService);

  bool _isNetworkFailure(dynamic error) => NetworkUtils.isNetworkOrHostFailure(error);

  Future<DashboardMetricsModel> getMetrics() async {
    try {
      return await _dashboardService.getMetrics();
    } catch (e) {
      if (_isNetworkFailure(e)) {
        return _getDemoMetrics();
      }
      rethrow;
    }
  }

  DashboardMetricsModel _getDemoMetrics() {
    return DashboardMetricsModel(
      totalProjects: 5,
      totalTasks: 18,
      activeTasks: 11,
      completedTasks: 5,
      overdueTasks: 2,
      myTasksCount: 6,
      myCompletedTasksCount: 2,
      myOverdueTasksCount: 1,
      tasksByStatus: [
        StatusCountMetric(status: 'todo', count: 4),
        StatusCountMetric(status: 'in_progress', count: 5),
        StatusCountMetric(status: 'in_review', count: 2),
        StatusCountMetric(status: 'done', count: 5),
        StatusCountMetric(status: 'backlog', count: 2),
      ],
      tasksByPriority: [
        PriorityCountMetric(priority: 'low', count: 3),
        PriorityCountMetric(priority: 'medium', count: 7),
        PriorityCountMetric(priority: 'high', count: 5),
        PriorityCountMetric(priority: 'urgent', count: 3),
      ],
      projectProgress: [
        ProjectProgressMetric(
          projectId: 1,
          projectTitle: 'Cloud Infrastructure & Kubernetes',
          status: 'in_progress',
          totalTasks: 8,
          completedTasks: 5,
          progressPercentage: 62.5,
        ),
        ProjectProgressMetric(
          projectId: 2,
          projectTitle: 'TaskForge Flutter Web App Redesign',
          status: 'in_progress',
          totalTasks: 6,
          completedTasks: 2,
          progressPercentage: 33.3,
        ),
        ProjectProgressMetric(
          projectId: 3,
          projectTitle: 'PostgreSQL RBAC Security Hardening',
          status: 'completed',
          totalTasks: 4,
          completedTasks: 4,
          progressPercentage: 100.0,
        ),
      ],
      recentTasks: [
        TaskModel(
          id: 101,
          projectId: 1,
          title: 'Implement Redis Token Blacklist Revocation',
          description: 'Ensure token blacklist persists in Redis with TTL matching JWT expiration.',
          status: TaskStatus.inProgress,
          priority: TaskPriority.urgent,
          dueDate: DateTime.now().add(const Duration(days: 1)),
          estimatedHours: 8.0,
          actualHours: 4.5,
        ),
        TaskModel(
          id: 102,
          projectId: 2,
          title: 'Design Responsive Mobile Navigation Shell',
          description: 'Adaptive bottom navigation for mobile and navigation rail for wide desktop screens.',
          status: TaskStatus.todo,
          priority: TaskPriority.high,
          dueDate: DateTime.now().add(const Duration(days: 3)),
          estimatedHours: 12.0,
          actualHours: 2.0,
        ),
        TaskModel(
          id: 103,
          projectId: 3,
          title: 'Alembic Database Migration Script Review',
          description: 'Verify foreign keys, cascading deletes, and default timestamp triggers.',
          status: TaskStatus.done,
          priority: TaskPriority.medium,
          dueDate: DateTime.now().subtract(const Duration(days: 2)),
          estimatedHours: 6.0,
          actualHours: 5.5,
        ),
      ],
      recentProjects: [
        ProjectModel(
          id: 1,
          title: 'Cloud Infrastructure & Kubernetes',
          status: ProjectStatus.inProgress,
          priority: ProjectPriority.urgent,
          ownerId: 1,
          progressPercentage: 62.5,
        ),
        ProjectModel(
          id: 2,
          title: 'TaskForge Flutter Web App Redesign',
          status: ProjectStatus.inProgress,
          priority: ProjectPriority.high,
          ownerId: 2,
          progressPercentage: 33.3,
        ),
      ],
    );
  }
}
