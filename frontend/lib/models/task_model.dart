import 'user_model.dart';
import 'comment_model.dart';
import 'task_history_model.dart';

enum TaskStatus {
  backlog,
  todo,
  inProgress,
  inReview,
  done;

  static TaskStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'backlog':
        return TaskStatus.backlog;
      case 'todo':
        return TaskStatus.todo;
      case 'in_progress':
      case 'inprogress':
        return TaskStatus.inProgress;
      case 'in_review':
      case 'inreview':
        return TaskStatus.inReview;
      case 'done':
        return TaskStatus.done;
      default:
        return TaskStatus.todo;
    }
  }

  String get displayName {
    switch (this) {
      case TaskStatus.backlog:
        return 'Backlog';
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.inReview:
        return 'In Review';
      case TaskStatus.done:
        return 'Done';
    }
  }

  String toApiString() {
    switch (this) {
      case TaskStatus.backlog:
        return 'backlog';
      case TaskStatus.todo:
        return 'todo';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.inReview:
        return 'in_review';
      case TaskStatus.done:
        return 'done';
    }
  }
}

enum TaskPriority {
  low,
  medium,
  high,
  urgent;

  static TaskPriority fromString(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return TaskPriority.low;
      case 'high':
        return TaskPriority.high;
      case 'urgent':
        return TaskPriority.urgent;
      case 'medium':
      default:
        return TaskPriority.medium;
    }
  }

  String get displayName {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }

  String toApiString() {
    return name;
  }
}

class TaskModel {
  final int id;
  final int projectId;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final double estimatedHours;
  final double actualHours;
  final int? creatorId;
  final UserModel? creator;
  final int? assigneeId;
  final UserModel? assignee;
  final bool isOverdue;
  final int commentsCount;
  final List<CommentModel> comments;
  final List<TaskHistoryModel> history;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.dueDate,
    this.estimatedHours = 0.0,
    this.actualHours = 0.0,
    this.creatorId,
    this.creator,
    this.assigneeId,
    this.assignee,
    this.isOverdue = false,
    this.commentsCount = 0,
    this.comments = const [],
    this.history = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    var rawComments = json['comments'] as List<dynamic>? ?? [];
    List<CommentModel> parsedComments = rawComments
        .map((c) => CommentModel.fromJson(c as Map<String, dynamic>))
        .toList();

    var rawHistory = json['history'] as List<dynamic>? ?? [];
    List<TaskHistoryModel> parsedHistory = rawHistory
        .map((h) => TaskHistoryModel.fromJson(h as Map<String, dynamic>))
        .toList();

    return TaskModel(
      id: json['id'] as int,
      projectId: json['project_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: TaskStatus.fromString(json['status'] as String? ?? 'todo'),
      priority: TaskPriority.fromString(json['priority'] as String? ?? 'medium'),
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      estimatedHours: (json['estimated_hours'] as num?)?.toDouble() ?? 0.0,
      actualHours: (json['actual_hours'] as num?)?.toDouble() ?? 0.0,
      creatorId: json['creator_id'] as int?,
      creator: json['creator'] != null ? UserModel.fromJson(json['creator']) : null,
      assigneeId: json['assignee_id'] as int?,
      assignee: json['assignee'] != null ? UserModel.fromJson(json['assignee']) : null,
      isOverdue: json['is_overdue'] as bool? ?? false,
      commentsCount: json['comments_count'] as int? ?? 0,
      comments: parsedComments,
      history: parsedHistory,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'title': title,
      'description': description,
      'status': status.toApiString(),
      'priority': priority.toApiString(),
      'due_date': dueDate?.toIso8601String(),
      'estimated_hours': estimatedHours,
      'actual_hours': actualHours,
      'assignee_id': assigneeId,
    };
  }
}
