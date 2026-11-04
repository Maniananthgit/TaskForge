import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import '../models/user_metrics_model.dart';
import '../models/user_audit_log_model.dart';
import 'api_client.dart';

class UserService {
  final ApiClient _apiClient;

  UserService(this._apiClient);

  /// Backwards-compatible lightweight user fetch
  Future<List<UserModel>> getUsers({String? query, UserRole? role, int limit = 100}) async {
    final params = <String, dynamic>{
      'limit': limit,
    };
    if (query != null && query.trim().isNotEmpty) {
      params['query'] = query.trim();
      params['search'] = query.trim();
    }
    if (role != null) params['role'] = role.toApiString();

    final response = await _apiClient.get(ApiConstants.users, queryParameters: params);
    if (response is Map<String, dynamic> && response.containsKey('items')) {
      final items = response['items'] as List<dynamic>;
      return items.map((u) => UserModel.fromJson(u as Map<String, dynamic>)).toList();
    } else if (response is List<dynamic>) {
      return response.map((u) => UserModel.fromJson(u as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Paginated and filtered users fetch for Admin User Management table
  Future<PaginatedUsersResponse> getUsersPaginated({
    int page = 1,
    int pageSize = 15,
    String? search,
    UserRole? role,
    UserStatus? status,
    bool includeDeleted = false,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      'include_deleted': includeDeleted,
    };
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (role != null) {
      params['role'] = role.toApiString();
    }
    if (status != null) {
      params['status'] = status.toApiString();
    }

    final response = await _apiClient.get(ApiConstants.users, queryParameters: params);
    if (response is Map<String, dynamic>) {
      return PaginatedUsersResponse.fromJson(response);
    }
    return PaginatedUsersResponse(items: [], total: 0, page: page, pageSize: pageSize);
  }

  /// Summary metrics for top KPI cards
  Future<UserSummaryMetricsModel> getSummaryMetrics() async {
    final response = await _apiClient.get(ApiConstants.userMetrics);
    if (response is Map<String, dynamic>) {
      return UserSummaryMetricsModel.fromJson(response);
    }
    return UserSummaryMetricsModel.empty();
  }

  /// Get comprehensive user details including project assignments and pending invite info
  Future<UserModel> getUserDetail(int userId) async {
    final response = await _apiClient.get(ApiConstants.userDetail(userId));
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  /// Invite a new user with email, role, and optional project assignments
  Future<UserModel> inviteUser({
    required String email,
    required String fullName,
    required UserRole role,
    String? phoneNumber,
    String? company,
    String? department,
    String? jobTitle,
    List<int>? assignedProjectIds,
  }) async {
    final body = <String, dynamic>{
      'email': email.trim(),
      'full_name': fullName.trim(),
      'role': role.toApiString(),
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) 'phone_number': phoneNumber.trim(),
      if (company != null && company.trim().isNotEmpty) 'company': company.trim(),
      if (department != null && department.trim().isNotEmpty) 'department': department.trim(),
      if (jobTitle != null && jobTitle.trim().isNotEmpty) 'job_title': jobTitle.trim(),
      if (assignedProjectIds != null && assignedProjectIds.isNotEmpty)
        'assigned_project_ids': assignedProjectIds,
    };

    final response = await _apiClient.post(ApiConstants.userInvite, body: body);
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  /// Resend invitation email & regenerate secure 24-hr token
  Future<UserModel> resendInvitation(int userId) async {
    final response = await _apiClient.post(ApiConstants.resendInvitation(userId));
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  /// Update user profile metadata
  Future<UserModel> updateUserProfile(
    int userId, {
    String? fullName,
    String? phoneNumber,
    String? company,
    String? department,
    String? jobTitle,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{
      if (fullName != null) 'full_name': fullName.trim(),
      if (phoneNumber != null) 'phone_number': phoneNumber.trim(),
      if (company != null) 'company': company.trim(),
      if (department != null) 'department': department.trim(),
      if (jobTitle != null) 'job_title': jobTitle.trim(),
      if (avatarUrl != null) 'avatar_url': avatarUrl.trim(),
    };

    final response = await _apiClient.put(ApiConstants.userDetail(userId), body: body);
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  /// Change user role (Admin safeguard protected)
  Future<UserModel> updateUserRole(int userId, UserRole newRole) async {
    final response = await _apiClient.patch(
      ApiConstants.updateUserRole(userId),
      body: {'role': newRole.toApiString()},
    );
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  /// Change user status (Active, Inactive, Suspended)
  Future<UserModel> updateUserStatus(int userId, UserStatus newStatus) async {
    final response = await _apiClient.patch(
      ApiConstants.updateUserStatus(userId),
      body: {'status': newStatus.toApiString()},
    );
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  /// Soft-delete user account
  Future<void> softDeleteUser(int userId) async {
    await _apiClient.delete(ApiConstants.userDetail(userId));
  }

  /// Restore soft-deleted user account
  Future<UserModel> restoreUser(int userId) async {
    final response = await _apiClient.post(ApiConstants.restoreUser(userId));
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  /// Trigger single-use admin password reset
  Future<Map<String, dynamic>> resetPassword(int userId) async {
    final response = await _apiClient.post(ApiConstants.resetPassword(userId));
    return response as Map<String, dynamic>;
  }

  /// Fetch user project memberships
  Future<List<UserProjectAssignmentModel>> getUserProjects(int userId) async {
    final response = await _apiClient.get(ApiConstants.userProjects(userId));
    final list = response as List<dynamic>? ?? [];
    return list.map((p) => UserProjectAssignmentModel.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// Assign user to a project with a specific project role
  Future<UserProjectAssignmentModel> assignProject(
    int userId,
    int projectId, {
    String roleInProject = 'Member',
  }) async {
    final response = await _apiClient.post(
      ApiConstants.userProjects(userId),
      body: {'project_id': projectId, 'role_in_project': roleInProject},
    );
    return UserProjectAssignmentModel.fromJson(response as Map<String, dynamic>);
  }

  /// Remove user from a project
  Future<void> removeProject(int userId, int projectId) async {
    await _apiClient.delete(ApiConstants.removeUserProject(userId, projectId));
  }

  /// Fetch user audit log history
  Future<List<UserAuditLogModel>> getUserActivity(int userId, {int limit = 50}) async {
    final response = await _apiClient.get(
      ApiConstants.userActivity(userId),
      queryParameters: {'limit': limit},
    );
    final list = response as List<dynamic>? ?? [];
    return list.map((a) => UserAuditLogModel.fromJson(a as Map<String, dynamic>)).toList();
  }
}
