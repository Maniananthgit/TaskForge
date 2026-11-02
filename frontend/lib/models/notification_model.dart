class NotificationModel {
  final int id;
  final int userId;
  final String title;
  final String message;
  final String notificationType;
  final bool isRead;
  final String? linkUrl;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.notificationType,
    this.isRead = false,
    this.linkUrl,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      message: json['message'] as String,
      notificationType: json['notification_type'] as String? ?? 'info',
      isRead: json['is_read'] as bool? ?? false,
      linkUrl: json['link_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
