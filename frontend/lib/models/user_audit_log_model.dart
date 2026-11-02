class UserAuditLogModel {
  final int id;
  final int? actorId;
  final String? actorName;
  final int targetUserId;
  final String action;
  final Map<String, dynamic>? details;
  final String? ipAddress;
  final DateTime createdAt;

  UserAuditLogModel({
    required this.id,
    this.actorId,
    this.actorName,
    required this.targetUserId,
    required this.action,
    this.details,
    this.ipAddress,
    required this.createdAt,
  });

  factory UserAuditLogModel.fromJson(Map<String, dynamic> json) {
    return UserAuditLogModel(
      id: json['id'] as int? ?? 0,
      actorId: json['actor_id'] as int?,
      actorName: json['actor_name'] as String?,
      targetUserId: json['target_user_id'] as int? ?? 0,
      action: json['action'] as String? ?? 'unknown',
      details: json['details'] as Map<String, dynamic>?,
      ipAddress: json['ip_address'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actor_id': actorId,
      'actor_name': actorName,
      'target_user_id': targetUserId,
      'action': action,
      'details': details,
      'ip_address': ipAddress,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
