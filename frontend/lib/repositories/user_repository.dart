import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/network_utils.dart';
import '../models/api_response.dart';
import '../models/user_model.dart';
import '../models/user_metrics_model.dart';
import '../models/user_audit_log_model.dart';
import '../services/user_service.dart';

class UserRepository {
  final UserService _userService;
  static const String _storageKeyUsers = 'taskforge_persisted_users_v2';
  bool _storageLoaded = false;

  UserRepository(this._userService);

  bool _isNetworkFailure(dynamic error) => NetworkUtils.isNetworkOrHostFailure(error);

  Future<void> _ensureStorageLoaded() async {
    if (_storageLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKeyUsers);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        if (decoded.isNotEmpty) {
          _demoUsers.clear();
          for (final item in decoded) {
            _demoUsers.add(UserModel.fromJson(item as Map<String, dynamic>));
          }
        }
      }
    } catch (_) {}
    _storageLoaded = true;
  }

  Future<void> _persistUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_demoUsers.map((u) => u.toJson()).toList());
      await prefs.setString(_storageKeyUsers, jsonStr);
    } catch (_) {}
  }

  // Fallback demo users for graceful preview resilience
  final List<UserModel> _demoUsers = [
    UserModel(
      id: 1,
      email: 'admin@taskforge.internal',
      fullName: 'Super Admin',
      role: UserRole.admin,
      status: UserStatus.active,
      isActive: true,
      phoneNumber: '+1-555-0100',
      department: 'Platform Engineering',
      jobTitle: 'Principal Security Architect',
      lastLoginAt: DateTime.now().subtract(const Duration(minutes: 15)),
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
      assignedProjects: [
        UserProjectAssignmentModel(
          projectId: 1,
          projectTitle: 'Cloud Infrastructure & Kubernetes',
          roleInProject: 'Lead',
        ),
        UserProjectAssignmentModel(
          projectId: 3,
          projectTitle: 'PostgreSQL RBAC Security Hardening',
          roleInProject: 'Auditor',
        ),
      ],
    ),
    UserModel(
      id: 2,
      email: 'pm@taskforge.internal',
      fullName: 'Elena Rostova',
      role: UserRole.projectManager,
      status: UserStatus.active,
      isActive: true,
      phoneNumber: '+1-555-0122',
      department: 'Product Operations',
      jobTitle: 'Senior Technical Program Manager',
      lastLoginAt: DateTime.now().subtract(const Duration(hours: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      assignedProjects: [
        UserProjectAssignmentModel(
          projectId: 2,
          projectTitle: 'TaskForge Flutter Web App Redesign',
          roleInProject: 'Project Manager',
        ),
      ],
    ),
    UserModel(
      id: 3,
      email: 'dev@taskforge.internal',
      fullName: 'David Chen',
      role: UserRole.developer,
      status: UserStatus.active,
      isActive: true,
      phoneNumber: '+1-555-0133',
      department: 'Frontend Engineering',
      jobTitle: 'Senior Flutter Developer',
      lastLoginAt: DateTime.now().subtract(const Duration(hours: 4)),
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
      assignedProjects: [
        UserProjectAssignmentModel(
          projectId: 2,
          projectTitle: 'TaskForge Flutter Web App Redesign',
          roleInProject: 'Contributor',
        ),
      ],
    ),
    UserModel(
      id: 4,
      email: 'sarah.connor@taskforge.internal',
      fullName: 'Sarah Connor',
      role: UserRole.developer,
      status: UserStatus.pendingInvitation,
      isActive: false,
      phoneNumber: '+1-555-0144',
      department: 'Security Operations',
      jobTitle: 'AppSec Engineer',
      invitationPending: true,
      invitationExpiresAt: DateTime.now().add(const Duration(hours: 20)),
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    UserModel(
      id: 5,
      email: 'alex.rivera@taskforge.internal',
      fullName: 'Alex Rivera',
      role: UserRole.developer,
      status: UserStatus.inactive,
      isActive: false,
      phoneNumber: '+1-555-0155',
      department: 'QA & Automation',
      jobTitle: 'QA Automation Engineer',
      lastLoginAt: DateTime.now().subtract(const Duration(days: 14)),
      createdAt: DateTime.now().subtract(const Duration(days: 80)),
    ),
  ];

  List<UserModel> get demoUsers => List.unmodifiable(_demoUsers);

  Future<List<UserModel>> getUsers({String? query, UserRole? role}) async {
    try {
      final users = await _userService.getUsers(query: query, role: role);
      if (users.isNotEmpty) {
        return users;
      }
      await _ensureStorageLoaded();
      return List<UserModel>.from(_demoUsers);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        await _ensureStorageLoaded();
        var filtered = List<UserModel>.from(_demoUsers);
        if (query != null && query.trim().isNotEmpty) {
          final q = query.trim().toLowerCase();
          filtered = filtered.where((u) =>
            u.fullName.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q)
          ).toList();
        }
        if (role != null) {
          filtered = filtered.where((u) => u.role == role).toList();
        }
        return filtered;
      }
      await _ensureStorageLoaded();
      return List<UserModel>.from(_demoUsers);
    }
  }

  Future<ApiResponse<PaginatedUsersResponse>> getUsersPaginated({
    int page = 1,
    int pageSize = 15,
    String? search,
    UserRole? role,
    UserStatus? status,
    bool includeDeleted = false,
  }) async {
    try {
      final res = await _userService.getUsersPaginated(
        page: page,
        pageSize: pageSize,
        search: search,
        role: role,
        status: status,
        includeDeleted: includeDeleted,
      );
      return ApiResponse.success(res);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        await _ensureStorageLoaded();
        // Filter demo users
        var filtered = List<UserModel>.from(_demoUsers);
        if (search != null && search.trim().isNotEmpty) {
          final query = search.trim().toLowerCase();
          filtered = filtered.where((u) =>
            u.fullName.toLowerCase().contains(query) ||
            u.email.toLowerCase().contains(query) ||
            (u.department?.toLowerCase().contains(query) ?? false) ||
            (u.jobTitle?.toLowerCase().contains(query) ?? false)
          ).toList();
        }
        if (role != null) {
          filtered = filtered.where((u) => u.role == role).toList();
        }
        if (status != null) {
          filtered = filtered.where((u) => u.status == status).toList();
        }
        return ApiResponse.success(
          PaginatedUsersResponse(
            items: filtered,
            total: filtered.length,
            page: page,
            pageSize: pageSize,
          ),
          message: 'Offline preview mode: Showing cached sample enterprise users.',
        );
      }
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<UserSummaryMetricsModel>> getSummaryMetrics() async {
    try {
      final res = await _userService.getSummaryMetrics();
      return ApiResponse.success(res);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        await _ensureStorageLoaded();
        return ApiResponse.success(
          UserSummaryMetricsModel(
            totalUsers: _demoUsers.length,
            activeUsers: _demoUsers.where((u) => u.status == UserStatus.active).length,
            inactiveUsers: _demoUsers.where((u) => u.status == UserStatus.inactive).length,
            suspendedUsers: _demoUsers.where((u) => u.status == UserStatus.suspended).length,
            pendingInvitations: _demoUsers.where((u) => u.status == UserStatus.pendingInvitation).length,
            adminsCount: _demoUsers.where((u) => u.role == UserRole.admin).length,
            projectManagersCount: _demoUsers.where((u) => u.role == UserRole.projectManager).length,
            developersCount: _demoUsers.where((u) => u.role == UserRole.developer || u.role == UserRole.employee).length,
          ),
        );
      }
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<UserModel>> getUserDetail(int userId) async {
    try {
      final user = await _userService.getUserDetail(userId);
      return ApiResponse.success(user);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        await _ensureStorageLoaded();
        final found = _demoUsers.firstWhere(
          (u) => u.id == userId,
          orElse: () => _demoUsers.first,
        );
        return ApiResponse.success(found);
      }
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<UserModel>> inviteUser({
    required String email,
    required String fullName,
    required UserRole role,
    String? phoneNumber,
    String? company,
    String? department,
    String? jobTitle,
    List<int>? assignedProjectIds,
  }) async {
    try {
      final user = await _userService.inviteUser(
        email: email,
        fullName: fullName,
        role: role,
        phoneNumber: phoneNumber,
        company: company,
        department: department,
        jobTitle: jobTitle,
        assignedProjectIds: assignedProjectIds,
      );
      return ApiResponse.success(user, message: 'Invitation issued successfully.');
    } catch (e) {
      if (_isNetworkFailure(e)) {
        await _ensureStorageLoaded();
        final maxId = _demoUsers.fold<int>(0, (max, u) => u.id > max ? u.id : max);
        final newUser = UserModel(
          id: maxId + 1,
          email: email,
          fullName: fullName,
          role: role,
          status: UserStatus.pendingInvitation,
          isActive: false,
          phoneNumber: phoneNumber,
          company: company ?? 'TaskForge Technologies',
          department: department,
          jobTitle: jobTitle,
          invitationPending: true,
          invitationExpiresAt: DateTime.now().add(const Duration(hours: 24)),
          invitationToken: 'simulated_invite_token_123',
          createdAt: DateTime.now(),
        );
        _demoUsers.insert(0, newUser);
        await _persistUsers();
        return ApiResponse.success(
          newUser,
          message: 'User created and saved to storage. Invitation issued.',
        );
      }
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<UserModel>> resendInvitation(int userId) async {
    try {
      final user = await _userService.resendInvitation(userId);
      return ApiResponse.success(user, message: 'Invitation resent successfully.');
    } catch (e) {
      if (_isNetworkFailure(e)) {
        await _ensureStorageLoaded();
        final idx = _demoUsers.indexWhere((u) => u.id == userId);
        if (idx != -1) {
          final updated = _demoUsers[idx].copyWith(
            invitationExpiresAt: DateTime.now().add(const Duration(hours: 24)),
            invitationToken: 'simulated_new_token_456',
          );
          _demoUsers[idx] = updated;
          await _persistUsers();
          return ApiResponse.success(updated, message: 'Simulated new invitation token generated.');
        }
      }
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<UserModel>> updateUserProfile(
    int userId, {
    String? fullName,
    String? phoneNumber,
    String? company,
    String? department,
    String? jobTitle,
    String? avatarUrl,
  }) async {
    try {
      final user = await _userService.updateUserProfile(
        userId,
        fullName: fullName,
        phoneNumber: phoneNumber,
        company: company,
        department: department,
        jobTitle: jobTitle,
        avatarUrl: avatarUrl,
      );
      return ApiResponse.success(user, message: 'User profile updated.');
    } catch (e) {
      if (_isNetworkFailure(e)) {
        await _ensureStorageLoaded();
        final idx = _demoUsers.indexWhere((u) => u.id == userId);
        if (idx != -1) {
          final updated = _demoUsers[idx].copyWith(
            fullName: fullName ?? _demoUsers[idx].fullName,
            phoneNumber: phoneNumber ?? _demoUsers[idx].phoneNumber,
            company: company ?? _demoUsers[idx].company,
            department: department ?? _demoUsers[idx].department,
            jobTitle: jobTitle ?? _demoUsers[idx].jobTitle,
            avatarUrl: avatarUrl ?? _demoUsers[idx].avatarUrl,
            updatedAt: DateTime.now(),
          );
          _demoUsers[idx] = updated;
          await _persistUsers();
          return ApiResponse.success(updated, message: 'Profile updated in offline preview.');
        }
      }
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<UserModel>> updateUserRole(int userId, UserRole newRole) async {
    try {
      final user = await _userService.updateUserRole(userId, newRole);
      return ApiResponse.success(user, message: 'User role changed to ${newRole.displayName}.');
    } catch (e) {
      if (_isNetworkFailure(e)) {
        await _ensureStorageLoaded();
        final idx = _demoUsers.indexWhere((u) => u.id == userId);
        if (idx != -1) {
          final updated = _demoUsers[idx].copyWith(role: newRole, updatedAt: DateTime.now());
          _demoUsers[idx] = updated;
          await _persistUsers();
          return ApiResponse.success(updated, message: 'Role changed in offline preview.');
        }
      }
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<UserModel>> updateUserStatus(int userId, UserStatus newStatus) async {
    try {
      final user = await _userService.updateUserStatus(userId, newStatus);
      return ApiResponse.success(user, message: 'User status updated to ${newStatus.displayName}.');
    } catch (e) {
      if (_isNetworkFailure(e)) {
        await _ensureStorageLoaded();
        final idx = _demoUsers.indexWhere((u) => u.id == userId);
        if (idx != -1) {
          final updated = _demoUsers[idx].copyWith(
            status: newStatus,
            isActive: newStatus == UserStatus.active,
            updatedAt: DateTime.now(),
          );
          _demoUsers[idx] = updated;
          await _persistUsers();
          return ApiResponse.success(updated, message: 'Status updated in offline preview.');
        }
      }
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<void>> softDeleteUser(int userId) async {
    try {
      await _userService.softDeleteUser(userId);
      return ApiResponse.success(null, message: 'User account soft-deleted.');
    } catch (e) {
      if (_isNetworkFailure(e)) {
        await _ensureStorageLoaded();
        _demoUsers.removeWhere((u) => u.id == userId);
        await _persistUsers();
        return ApiResponse.success(null, message: 'User deleted in offline preview.');
      }
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<UserModel>> restoreUser(int userId) async {
    try {
      final user = await _userService.restoreUser(userId);
      return ApiResponse.success(user, message: 'User account restored to inactive status.');
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> resetPassword(int userId) async {
    try {
      final res = await _userService.resetPassword(userId);
      return ApiResponse.success(res, message: 'Password reset initiated successfully.');
    } catch (e) {
      if (_isNetworkFailure(e)) {
        return ApiResponse.success({
          'message': 'Password reset token generated (offline preview)',
          'reset_token': 'simulated_reset_token_789',
        }, message: 'Reset token generated: simulated_reset_token_789');
      }
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<List<UserProjectAssignmentModel>>> getUserProjects(int userId) async {
    try {
      final projects = await _userService.getUserProjects(userId);
      return ApiResponse.success(projects);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        final user = _demoUsers.firstWhere(
          (u) => u.id == userId,
          orElse: () => _demoUsers.first,
        );
        return ApiResponse.success(user.assignedProjects);
      }
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<UserProjectAssignmentModel>> assignProject(
    int userId,
    int projectId, {
    String roleInProject = 'Member',
  }) async {
    try {
      final assignment = await _userService.assignProject(
        userId,
        projectId,
        roleInProject: roleInProject,
      );
      return ApiResponse.success(assignment, message: 'Assigned to project.');
    } catch (e) {
      if (_isNetworkFailure(e)) {
        final dummy = UserProjectAssignmentModel(
          projectId: projectId,
          projectTitle: 'Project #$projectId',
          roleInProject: roleInProject,
          joinedAt: DateTime.now(),
        );
        return ApiResponse.success(dummy, message: 'Assigned in preview mode.');
      }
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<void>> removeProject(int userId, int projectId) async {
    try {
      await _userService.removeProject(userId, projectId);
      return ApiResponse.success(null, message: 'Project membership removed.');
    } catch (e) {
      if (_isNetworkFailure(e)) {
        return ApiResponse.success(null, message: 'Removed in preview mode.');
      }
      return ApiResponse.error(e.toString());
    }
  }

  Future<ApiResponse<List<UserAuditLogModel>>> getUserActivity(int userId, {int limit = 50}) async {
    try {
      final logs = await _userService.getUserActivity(userId, limit: limit);
      return ApiResponse.success(logs);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        return ApiResponse.success([
          UserAuditLogModel(
            id: 1,
            actorName: 'Super Admin',
            targetUserId: userId,
            action: 'user_created',
            details: {'note': 'Initial user creation'},
            ipAddress: '127.0.0.1',
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
          ),
          UserAuditLogModel(
            id: 2,
            actorName: 'Super Admin',
            targetUserId: userId,
            action: 'role_changed',
            details: {'old': 'developer', 'new': 'project_manager'},
            ipAddress: '127.0.0.1',
            createdAt: DateTime.now().subtract(const Duration(days: 10)),
          ),
        ]);
      }
      return ApiResponse.error(e.toString());
    }
  }
}
