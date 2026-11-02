enum UserRole {
  admin,
  projectManager,
  developer;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'project_manager':
      case 'projectmanager':
        return UserRole.projectManager;
      case 'developer':
      default:
        return UserRole.developer;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.projectManager:
        return 'Project Manager';
      case UserRole.developer:
        return 'Developer';
    }
  }

  String toApiString() {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.projectManager:
        return 'project_manager';
      case UserRole.developer:
        return 'developer';
    }
  }
}

enum UserStatus {
  pendingInvitation,
  active,
  inactive,
  suspended,
  deleted;

  static UserStatus fromString(String? status) {
    if (status == null) return UserStatus.active;
    switch (status.toLowerCase()) {
      case 'pending_invitation':
      case 'pending':
        return UserStatus.pendingInvitation;
      case 'active':
        return UserStatus.active;
      case 'inactive':
        return UserStatus.inactive;
      case 'suspended':
        return UserStatus.suspended;
      case 'deleted':
        return UserStatus.deleted;
      default:
        return UserStatus.active;
    }
  }

  String get displayName {
    switch (this) {
      case UserStatus.pendingInvitation:
        return 'Pending Invitation';
      case UserStatus.active:
        return 'Active';
      case UserStatus.inactive:
        return 'Inactive';
      case UserStatus.suspended:
        return 'Suspended';
      case UserStatus.deleted:
        return 'Deleted';
    }
  }

  String toApiString() {
    switch (this) {
      case UserStatus.pendingInvitation:
        return 'pending_invitation';
      case UserStatus.active:
        return 'active';
      case UserStatus.inactive:
        return 'inactive';
      case UserStatus.suspended:
        return 'suspended';
      case UserStatus.deleted:
        return 'deleted';
    }
  }
}

class UserProjectAssignmentModel {
  final int projectId;
  final String projectTitle;
  final String roleInProject;
  final DateTime? joinedAt;

  UserProjectAssignmentModel({
    required this.projectId,
    required this.projectTitle,
    this.roleInProject = 'Member',
    this.joinedAt,
  });

  factory UserProjectAssignmentModel.fromJson(Map<String, dynamic> json) {
    return UserProjectAssignmentModel(
      projectId: json['project_id'] as int? ?? 0,
      projectTitle: json['project_title'] as String? ?? 'Unnamed Project',
      roleInProject: json['role_in_project'] as String? ?? 'Member',
      joinedAt: json['joined_at'] != null ? DateTime.tryParse(json['joined_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'project_title': projectTitle,
      'role_in_project': roleInProject,
      'joined_at': joinedAt?.toIso8601String(),
    };
  }
}

class UserModel {
  final int id;
  final String email;
  final String fullName;
  final UserRole role;
  final UserStatus status;
  final bool isActive;
  final String? phoneNumber;
  final String? department;
  final String? jobTitle;
  final String? avatarUrl;
  final DateTime? lastLoginAt;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<UserProjectAssignmentModel> assignedProjects;
  final bool invitationPending;
  final DateTime? invitationExpiresAt;
  final String? invitationToken;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.status = UserStatus.active,
    this.isActive = true,
    this.phoneNumber,
    this.department,
    this.jobTitle,
    this.avatarUrl,
    this.lastLoginAt,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
    this.assignedProjects = const [],
    this.invitationPending = false,
    this.invitationExpiresAt,
    this.invitationToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Map status enum safely
    final rawStatus = json['status'] as String?;
    final userStatus = UserStatus.fromString(rawStatus);

    // Map projects list
    var projectsList = <UserProjectAssignmentModel>[];
    if (json['assigned_projects'] is List) {
      projectsList = (json['assigned_projects'] as List)
          .map((item) => UserProjectAssignmentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return UserModel(
      id: json['id'] as int? ?? json['user_id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'developer'),
      status: userStatus,
      isActive: json['is_active'] as bool? ?? (userStatus == UserStatus.active),
      phoneNumber: json['phone_number'] as String?,
      department: json['department'] as String?,
      jobTitle: json['job_title'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      lastLoginAt: json['last_login_at'] != null ? DateTime.tryParse(json['last_login_at']) : null,
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      assignedProjects: projectsList,
      invitationPending: json['invitation_pending'] as bool? ?? (userStatus == UserStatus.pendingInvitation),
      invitationExpiresAt: json['invitation_expires_at'] != null
          ? DateTime.tryParse(json['invitation_expires_at'])
          : null,
      invitationToken: json['invitation_token'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.toApiString(),
      'status': status.toApiString(),
      'is_active': isActive,
      'phone_number': phoneNumber,
      'department': department,
      'job_title': jobTitle,
      'avatar_url': avatarUrl,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'assigned_projects': assignedProjects.map((p) => p.toJson()).toList(),
      'invitation_pending': invitationPending,
      'invitation_expires_at': invitationExpiresAt?.toIso8601String(),
      'invitation_token': invitationToken,
    };
  }

  UserModel copyWith({
    int? id,
    String? email,
    String? fullName,
    UserRole? role,
    UserStatus? status,
    bool? isActive,
    String? phoneNumber,
    String? department,
    String? jobTitle,
    String? avatarUrl,
    DateTime? lastLoginAt,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<UserProjectAssignmentModel>? assignedProjects,
    bool? invitationPending,
    DateTime? invitationExpiresAt,
    String? invitationToken,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedProjects: assignedProjects ?? this.assignedProjects,
      invitationPending: invitationPending ?? this.invitationPending,
      invitationExpiresAt: invitationExpiresAt ?? this.invitationExpiresAt,
      invitationToken: invitationToken ?? this.invitationToken,
    );
  }
}

class PaginatedUsersResponse {
  final List<UserModel> items;
  final int total;
  final int page;
  final int pageSize;

  PaginatedUsersResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory PaginatedUsersResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>? ?? [])
        .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
        .toList();
    return PaginatedUsersResponse(
      items: list,
      total: json['total'] as int? ?? list.length,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
    );
  }
}
