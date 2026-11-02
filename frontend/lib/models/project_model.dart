import 'user_model.dart';

enum ProjectStatus {
  planning,
  inProgress,
  onHold,
  completed,
  archived;

  static ProjectStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
      case 'inprogress':
        return ProjectStatus.inProgress;
      case 'on_hold':
      case 'onhold':
        return ProjectStatus.onHold;
      case 'completed':
        return ProjectStatus.completed;
      case 'archived':
        return ProjectStatus.archived;
      case 'planning':
      default:
        return ProjectStatus.planning;
    }
  }

  String get displayName {
    switch (this) {
      case ProjectStatus.planning:
        return 'Planning';
      case ProjectStatus.inProgress:
        return 'In Progress';
      case ProjectStatus.onHold:
        return 'On Hold';
      case ProjectStatus.completed:
        return 'Completed';
      case ProjectStatus.archived:
        return 'Archived';
    }
  }

  String toApiString() {
    switch (this) {
      case ProjectStatus.planning:
        return 'planning';
      case ProjectStatus.inProgress:
        return 'in_progress';
      case ProjectStatus.onHold:
        return 'on_hold';
      case ProjectStatus.completed:
        return 'completed';
      case ProjectStatus.archived:
        return 'archived';
    }
  }
}

enum ProjectPriority {
  low,
  medium,
  high,
  urgent;

  static ProjectPriority fromString(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return ProjectPriority.low;
      case 'high':
        return ProjectPriority.high;
      case 'urgent':
        return ProjectPriority.urgent;
      case 'medium':
      default:
        return ProjectPriority.medium;
    }
  }

  String get displayName {
    switch (this) {
      case ProjectPriority.low:
        return 'Low';
      case ProjectPriority.medium:
        return 'Medium';
      case ProjectPriority.high:
        return 'High';
      case ProjectPriority.urgent:
        return 'Urgent';
    }
  }

  String toApiString() {
    return name;
  }
}

class ProjectMemberModel {
  final int id;
  final int projectId;
  final int userId;
  final String roleInProject;
  final DateTime? joinedAt;
  final UserModel? user;

  ProjectMemberModel({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.roleInProject,
    this.joinedAt,
    this.user,
  });

  factory ProjectMemberModel.fromJson(Map<String, dynamic> json) {
    return ProjectMemberModel(
      id: json['id'] as int,
      projectId: json['project_id'] as int,
      userId: json['user_id'] as int,
      roleInProject: json['role_in_project'] as String? ?? 'Member',
      joinedAt: json['joined_at'] != null ? DateTime.tryParse(json['joined_at']) : null,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }
}

class ProjectModel {
  final int id;
  final String title;
  final String? description;
  final ProjectStatus status;
  final ProjectPriority priority;
  final DateTime? startDate;
  final DateTime? dueDate;
  final double budgetHours;
  final int ownerId;
  final UserModel? owner;
  final int tasksCount;
  final int completedTasksCount;
  final double progressPercentage;
  final int membersCount;
  final List<ProjectMemberModel> members;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProjectModel({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.startDate,
    this.dueDate,
    this.budgetHours = 0.0,
    required this.ownerId,
    this.owner,
    this.tasksCount = 0,
    this.completedTasksCount = 0,
    this.progressPercentage = 0.0,
    this.membersCount = 0,
    this.members = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    var rawMembers = json['members'] as List<dynamic>? ?? [];
    List<ProjectMemberModel> parsedMembers = rawMembers
        .map((m) => ProjectMemberModel.fromJson(m as Map<String, dynamic>))
        .toList();

    return ProjectModel(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: ProjectStatus.fromString(json['status'] as String? ?? 'planning'),
      priority: ProjectPriority.fromString(json['priority'] as String? ?? 'medium'),
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date']) : null,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      budgetHours: (json['budget_hours'] as num?)?.toDouble() ?? 0.0,
      ownerId: json['owner_id'] as int? ?? 0,
      owner: json['owner'] != null ? UserModel.fromJson(json['owner']) : null,
      tasksCount: json['tasks_count'] as int? ?? 0,
      completedTasksCount: json['completed_tasks_count'] as int? ?? 0,
      progressPercentage: (json['progress_percentage'] as num?)?.toDouble() ?? 0.0,
      membersCount: json['members_count'] as int? ?? 0,
      members: parsedMembers,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.toApiString(),
      'priority': priority.toApiString(),
      'start_date': startDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'budget_hours': budgetHours,
    };
  }
}
