import 'project_model.dart';
import 'task_model.dart';

class ProjectProgressMetric {
  final int projectId;
  final String projectTitle;
  final int totalTasks;
  final int completedTasks;
  final double progressPercentage;
  final String status;
  final String? dueDate;

  ProjectProgressMetric({
    required this.projectId,
    required this.projectTitle,
    required this.totalTasks,
    required this.completedTasks,
    required this.progressPercentage,
    required this.status,
    this.dueDate,
  });

  factory ProjectProgressMetric.fromJson(Map<String, dynamic> json) {
    return ProjectProgressMetric(
      projectId: json['project_id'] as int,
      projectTitle: json['project_title'] as String,
      totalTasks: json['total_tasks'] as int,
      completedTasks: json['completed_tasks'] as int,
      progressPercentage: (json['progress_percentage'] as num).toDouble(),
      status: json['status'] as String,
      dueDate: json['due_date'] as String?,
    );
  }
}

class StatusCountMetric {
  final String status;
  final int count;

  StatusCountMetric({required this.status, required this.count});

  factory StatusCountMetric.fromJson(Map<String, dynamic> json) {
    return StatusCountMetric(
      status: json['status'] as String,
      count: json['count'] as int,
    );
  }
}

class PriorityCountMetric {
  final String priority;
  final int count;

  PriorityCountMetric({required this.priority, required this.count});

  factory PriorityCountMetric.fromJson(Map<String, dynamic> json) {
    return PriorityCountMetric(
      priority: json['priority'] as String,
      count: json['count'] as int,
    );
  }
}

class DashboardMetricsModel {
  final int totalProjects;
  final int totalTasks;
  final int activeTasks;
  final int completedTasks;
  final int overdueTasks;
  final int myTasksCount;
  final int myCompletedTasksCount;
  final int myOverdueTasksCount;
  final List<ProjectProgressMetric> projectProgress;
  final List<StatusCountMetric> tasksByStatus;
  final List<PriorityCountMetric> tasksByPriority;
  final List<TaskModel> recentTasks;
  final List<ProjectModel> recentProjects;

  DashboardMetricsModel({
    required this.totalProjects,
    required this.totalTasks,
    required this.activeTasks,
    required this.completedTasks,
    required this.overdueTasks,
    required this.myTasksCount,
    required this.myCompletedTasksCount,
    required this.myOverdueTasksCount,
    this.projectProgress = const [],
    this.tasksByStatus = const [],
    this.tasksByPriority = const [],
    this.recentTasks = const [],
    this.recentProjects = const [],
  });

  factory DashboardMetricsModel.fromJson(Map<String, dynamic> json) {
    var rawProgress = json['project_progress'] as List<dynamic>? ?? [];
    var parsedProgress = rawProgress
        .map((p) => ProjectProgressMetric.fromJson(p as Map<String, dynamic>))
        .toList();

    var rawStatus = json['tasks_by_status'] as List<dynamic>? ?? [];
    var parsedStatus = rawStatus
        .map((s) => StatusCountMetric.fromJson(s as Map<String, dynamic>))
        .toList();

    var rawPriority = json['tasks_by_priority'] as List<dynamic>? ?? [];
    var parsedPriority = rawPriority
        .map((pr) => PriorityCountMetric.fromJson(pr as Map<String, dynamic>))
        .toList();

    var rawRecentTasks = json['recent_tasks'] as List<dynamic>? ?? [];
    var parsedRecentTasks = rawRecentTasks
        .map((t) => TaskModel.fromJson(t as Map<String, dynamic>))
        .toList();

    var rawRecentProjects = json['recent_projects'] as List<dynamic>? ?? [];
    var parsedRecentProjects = rawRecentProjects
        .map((p) => ProjectModel.fromJson(p as Map<String, dynamic>))
        .toList();

    return DashboardMetricsModel(
      totalProjects: json['total_projects'] as int? ?? 0,
      totalTasks: json['total_tasks'] as int? ?? 0,
      activeTasks: json['active_tasks'] as int? ?? 0,
      completedTasks: json['completed_tasks'] as int? ?? 0,
      overdueTasks: json['overdue_tasks'] as int? ?? 0,
      myTasksCount: json['my_tasks_count'] as int? ?? 0,
      myCompletedTasksCount: json['my_completed_tasks_count'] as int? ?? 0,
      myOverdueTasksCount: json['my_overdue_tasks_count'] as int? ?? 0,
      projectProgress: parsedProgress,
      tasksByStatus: parsedStatus,
      tasksByPriority: parsedPriority,
      recentTasks: parsedRecentTasks,
      recentProjects: parsedRecentProjects,
    );
  }
}
