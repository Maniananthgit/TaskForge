class UserSummaryMetricsModel {
  final int totalUsers;
  final int activeUsers;
  final int inactiveUsers;
  final int suspendedUsers;
  final int pendingInvitations;
  final int adminsCount;
  final int projectManagersCount;
  final int developersCount;

  UserSummaryMetricsModel({
    required this.totalUsers,
    required this.activeUsers,
    required this.inactiveUsers,
    required this.suspendedUsers,
    required this.pendingInvitations,
    required this.adminsCount,
    required this.projectManagersCount,
    required this.developersCount,
  });

  factory UserSummaryMetricsModel.empty() {
    return UserSummaryMetricsModel(
      totalUsers: 0,
      activeUsers: 0,
      inactiveUsers: 0,
      suspendedUsers: 0,
      pendingInvitations: 0,
      adminsCount: 0,
      projectManagersCount: 0,
      developersCount: 0,
    );
  }

  factory UserSummaryMetricsModel.fromJson(Map<String, dynamic> json) {
    return UserSummaryMetricsModel(
      totalUsers: json['total_users'] as int? ?? 0,
      activeUsers: json['active_users'] as int? ?? 0,
      inactiveUsers: json['inactive_users'] as int? ?? 0,
      suspendedUsers: json['suspended_users'] as int? ?? 0,
      pendingInvitations: json['pending_invitations'] as int? ?? 0,
      adminsCount: json['admins_count'] as int? ?? 0,
      projectManagersCount: json['project_managers_count'] as int? ?? 0,
      developersCount: json['developers_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_users': totalUsers,
      'active_users': activeUsers,
      'inactive_users': inactiveUsers,
      'suspended_users': suspendedUsers,
      'pending_invitations': pendingInvitations,
      'admins_count': adminsCount,
      'project_managers_count': projectManagersCount,
      'developers_count': developersCount,
    };
  }
}
