import 'user_model.dart';

class CommentModel {
  final int id;
  final int taskId;
  final int authorId;
  final UserModel? author;
  final String content;
  final bool isInternal;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CommentModel({
    required this.id,
    required this.taskId,
    required this.authorId,
    this.author,
    required this.content,
    this.isInternal = false,
    this.createdAt,
    this.updatedAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as int,
      taskId: json['task_id'] as int,
      authorId: json['author_id'] as int,
      author: json['author'] != null ? UserModel.fromJson(json['author']) : null,
      content: json['content'] as String,
      isInternal: json['is_internal'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'is_internal': isInternal,
    };
  }
}
