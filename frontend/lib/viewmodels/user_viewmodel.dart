import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/user_metrics_model.dart';
import '../models/user_audit_log_model.dart';
import '../repositories/user_repository.dart';

class UserViewModel extends ChangeNotifier {
  final UserRepository _userRepository;

  UserViewModel(this._userRepository);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  // Pagination & List
  List<UserModel> _users = [];
  List<UserModel> get users => _users;

  int _totalUsers = 0;
  int get totalUsers => _totalUsers;

  int _currentPage = 1;
  int get currentPage => _currentPage;

  int _pageSize = 15;
  int get pageSize => _pageSize;

  int get totalPages => (_totalUsers / _pageSize).ceil().clamp(1, 9999);

  // Filters
  String? _searchQuery;
  String? get searchQuery => _searchQuery;

  UserRole? _selectedRoleFilter;
  UserRole? get selectedRoleFilter => _selectedRoleFilter;

  UserStatus? _selectedStatusFilter;
  UserStatus? get selectedStatusFilter => _selectedStatusFilter;

  bool _includeDeleted = false;
  bool get includeDeleted => _includeDeleted;

  // Dashboard Metrics
  UserSummaryMetricsModel _metrics = UserSummaryMetricsModel.empty();
  UserSummaryMetricsModel get metrics => _metrics;

  // Selected User Detail
  UserModel? _selectedUser;
  UserModel? get selectedUser => _selectedUser;

  List<UserProjectAssignmentModel> _selectedUserProjects = [];
  List<UserProjectAssignmentModel> get selectedUserProjects => _selectedUserProjects;

  List<UserAuditLogModel> _selectedUserAuditLogs = [];
  List<UserAuditLogModel> get selectedUserAuditLogs => _selectedUserAuditLogs;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void setSearch(String? query) {
    _searchQuery = query;
    _currentPage = 1;
    loadUsers();
  }

  void setRoleFilter(UserRole? role) {
    _selectedRoleFilter = role;
    _currentPage = 1;
    loadUsers();
  }

  void setStatusFilter(UserStatus? status) {
    _selectedStatusFilter = status;
    _currentPage = 1;
    loadUsers();
  }

  void toggleIncludeDeleted(bool value) {
    _includeDeleted = value;
    _currentPage = 1;
    loadUsers();
  }

  void setPage(int page) {
    if (page < 1 || (page > totalPages && totalPages > 0)) return;
    _currentPage = page;
    loadUsers();
  }

  Future<void> loadSummaryMetrics() async {
    final res = await _userRepository.getSummaryMetrics();
    if (res.isSuccess && res.data != null) {
      _metrics = res.data!;
      notifyListeners();
    }
  }

  Future<void> loadUsers({int? page, bool refreshMetrics = true}) async {
    _isLoading = true;
    _errorMessage = null;
    if (page != null) _currentPage = page;
    notifyListeners();

    try {
      final res = await _userRepository.getUsersPaginated(
        page: _currentPage,
        pageSize: _pageSize,
        search: _searchQuery,
        role: _selectedRoleFilter,
        status: _selectedStatusFilter,
        includeDeleted: _includeDeleted,
      );

      if (res.isSuccess && res.data != null) {
        _users = res.data!.items;
        _totalUsers = res.data!.total;
        _currentPage = res.data!.page;
        _pageSize = res.data!.pageSize;
      } else {
        _errorMessage = res.message ?? 'Failed to load users';
      }

      if (refreshMetrics) {
        await loadSummaryMetrics();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserDetail(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _userRepository.getUserDetail(userId);
      if (res.isSuccess && res.data != null) {
        _selectedUser = res.data;
        _selectedUserProjects = res.data!.assignedProjects;
      } else {
        _errorMessage = res.message ?? 'Failed to load user details';
      }

      // Also load activity logs
      final activityRes = await _userRepository.getUserActivity(userId);
      if (activityRes.isSuccess && activityRes.data != null) {
        _selectedUserAuditLogs = activityRes.data!;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> inviteUser({
    required String email,
    required String fullName,
    required UserRole role,
    String? phoneNumber,
    String? company,
    String? department,
    String? jobTitle,
    List<int>? assignedProjectIds,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _userRepository.inviteUser(
        email: email,
        fullName: fullName,
        role: role,
        phoneNumber: phoneNumber,
        company: company,
        department: department,
        jobTitle: jobTitle,
        assignedProjectIds: assignedProjectIds,
      );

      if (res.isSuccess) {
        _successMessage = res.message ?? 'Invitation sent successfully.';
        await loadUsers(refreshMetrics: true);
        return true;
      } else {
        _errorMessage = res.message ?? 'Failed to send invitation';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resendInvitation(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _userRepository.resendInvitation(userId);
      if (res.isSuccess) {
        _successMessage = res.message ?? 'Invitation resent with new 24-hr token.';
        await loadUsers(refreshMetrics: false);
        if (_selectedUser?.id == userId) {
          await loadUserDetail(userId);
        }
        return true;
      } else {
        _errorMessage = res.message ?? 'Failed to resend invitation';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateUserProfile(
    int userId, {
    String? fullName,
    String? phoneNumber,
    String? company,
    String? department,
    String? jobTitle,
    String? avatarUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _userRepository.updateUserProfile(
        userId,
        fullName: fullName,
        phoneNumber: phoneNumber,
        company: company,
        department: department,
        jobTitle: jobTitle,
        avatarUrl: avatarUrl,
      );

      if (res.isSuccess) {
        _successMessage = res.message ?? 'Profile updated successfully.';
        await loadUsers(refreshMetrics: false);
        if (_selectedUser?.id == userId) {
          await loadUserDetail(userId);
        }
        return true;
      } else {
        _errorMessage = res.message ?? 'Failed to update profile';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateUserRole(int userId, UserRole newRole) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _userRepository.updateUserRole(userId, newRole);
      if (res.isSuccess) {
        _successMessage = res.message ?? 'Role updated successfully.';
        await loadUsers(refreshMetrics: true);
        if (_selectedUser?.id == userId) {
          await loadUserDetail(userId);
        }
        return true;
      } else {
        _errorMessage = res.message ?? 'Failed to update user role';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateUserStatus(int userId, UserStatus newStatus) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _userRepository.updateUserStatus(userId, newStatus);
      if (res.isSuccess) {
        _successMessage = res.message ?? 'Status updated successfully.';
        await loadUsers(refreshMetrics: true);
        if (_selectedUser?.id == userId) {
          await loadUserDetail(userId);
        }
        return true;
      } else {
        _errorMessage = res.message ?? 'Failed to update user status';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> softDeleteUser(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _userRepository.softDeleteUser(userId);
      if (res.isSuccess) {
        _successMessage = res.message ?? 'User deleted successfully.';
        await loadUsers(refreshMetrics: true);
        return true;
      } else {
        _errorMessage = res.message ?? 'Failed to delete user';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restoreUser(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _userRepository.restoreUser(userId);
      if (res.isSuccess) {
        _successMessage = res.message ?? 'User restored successfully.';
        await loadUsers(refreshMetrics: true);
        if (_selectedUser?.id == userId) {
          await loadUserDetail(userId);
        }
        return true;
      } else {
        _errorMessage = res.message ?? 'Failed to restore user';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> resetPassword(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _userRepository.resetPassword(userId);
      if (res.isSuccess && res.data != null) {
        final token = res.data!['reset_token'] as String?;
        _successMessage = res.message ?? 'Password reset token issued.';
        return token;
      } else {
        _errorMessage = res.message ?? 'Failed to reset password';
        return null;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> assignProject(int userId, int projectId, {String roleInProject = 'Member'}) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _userRepository.assignProject(userId, projectId, roleInProject: roleInProject);
      if (res.isSuccess) {
        _successMessage = res.message ?? 'Project assigned.';
        if (_selectedUser?.id == userId) {
          await loadUserDetail(userId);
        }
        return true;
      } else {
        _errorMessage = res.message ?? 'Failed to assign project';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> removeProject(int userId, int projectId) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _userRepository.removeProject(userId, projectId);
      if (res.isSuccess) {
        _successMessage = res.message ?? 'Removed from project.';
        if (_selectedUser?.id == userId) {
          await loadUserDetail(userId);
        }
        return true;
      } else {
        _errorMessage = res.message ?? 'Failed to remove project assignment';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
