import 'user_model.dart';

class TaskHistoryModel {
  final int id;
  final int taskId;
  final int? changedById;
  final UserModel? changedBy;
  final String fieldChanged;
  final String? oldValue;
  final String? newValue;
  final DateTime changedAt;

  TaskHistoryModel({
    required this.id,
    required this.taskId,
    this.changedById,
    this.changedBy,
    required this.fieldChanged,
    this.oldValue,
    this.newValue,
    required this.changedAt,
  });

  factory TaskHistoryModel.fromJson(Map<String, dynamic> json) {
    return TaskHistoryModel(
      id: json['id'] as int,
      taskId: json['task_id'] as int,
      changedById: json['changed_by_id'] as int?,
      changedBy: json['changed_by'] != null ? UserModel.fromJson(json['changed_by']) : null,
      fieldChanged: json['field_changed'] as String,
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String?,
      changedAt: DateTime.parse(json['changed_at'] as String),
    );
  }
}
