import 'package:flutter_test/flutter_test.dart';
import 'package:taskforge_app/models/api_response.dart';
import 'package:taskforge_app/models/user_model.dart';
import 'package:taskforge_app/models/user_metrics_model.dart';
import 'package:taskforge_app/repositories/user_repository.dart';
import 'package:taskforge_app/viewmodels/user_viewmodel.dart';

class MockUserRepository implements UserRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<UserModel> users = [
    UserModel(
      id: 1,
      email: 'admin@taskforge.internal',
      fullName: 'Super Admin',
      role: UserRole.admin,
      status: UserStatus.active,
    ),
    UserModel(
      id: 2,
      email: 'pm@taskforge.internal',
      fullName: 'PM Lead',
      role: UserRole.projectManager,
      status: UserStatus.active,
    ),
    UserModel(
      id: 3,
      email: 'dev@taskforge.internal',
      fullName: 'Senior Dev',
      role: UserRole.developer,
      status: UserStatus.pendingInvitation,
    ),
  ];

  @override
  Future<ApiResponse<PaginatedUsersResponse>> getUsersPaginated({
    int page = 1,
    int pageSize = 15,
    String? search,
    UserRole? role,
    UserStatus? status,
    bool includeDeleted = false,
  }) async {
    var filtered = List<UserModel>.from(users);
    if (search != null) {
      filtered = filtered.where((u) => u.fullName.contains(search) || u.email.contains(search)).toList();
    }
    if (role != null) {
      filtered = filtered.where((u) => u.role == role).toList();
    }
    if (status != null) {
      filtered = filtered.where((u) => u.status == status).toList();
    }
    return ApiResponse.success(
      PaginatedUsersResponse(items: filtered, total: filtered.length, page: page, pageSize: pageSize),
    );
  }

  @override
  Future<ApiResponse<UserSummaryMetricsModel>> getSummaryMetrics() async {
    return ApiResponse.success(
      UserSummaryMetricsModel(
        totalUsers: users.length,
        activeUsers: users.where((u) => u.status == UserStatus.active).length,
        inactiveUsers: 0,
        suspendedUsers: 0,
        pendingInvitations: users.where((u) => u.status == UserStatus.pendingInvitation).length,
        adminsCount: users.where((u) => u.role == UserRole.admin).length,
        projectManagersCount: users.where((u) => u.role == UserRole.projectManager).length,
        developersCount: users.where((u) => u.role == UserRole.developer).length,
      ),
    );
  }

  @override
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
    final newUser = UserModel(
      id: users.length + 1,
      email: email,
      fullName: fullName,
      role: role,
      status: UserStatus.pendingInvitation,
      company: company ?? 'TaskForge Technologies',
    );
    users.add(newUser);
    return ApiResponse.success(newUser, message: 'Invitation issued');
  }

  @override
  Future<ApiResponse<UserModel>> updateUserRole(int userId, UserRole newRole) async {
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final updated = users[idx].copyWith(role: newRole);
      users[idx] = updated;
      return ApiResponse.success(updated);
    }
    return ApiResponse.error('User not found');
  }

  @override
  Future<ApiResponse<UserModel>> updateUserStatus(int userId, UserStatus newStatus) async {
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final updated = users[idx].copyWith(status: newStatus);
      users[idx] = updated;
      return ApiResponse.success(updated);
    }
    return ApiResponse.error('User not found');
  }

  @override
  Future<ApiResponse<void>> softDeleteUser(int userId) async {
    users.removeWhere((u) => u.id == userId);
    return ApiResponse.success(null);
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> resetPassword(int userId) async {
    return ApiResponse.success({'reset_token': 'test_reset_token_123'});
  }
}

void main() {
  group('UserViewModel Unit Tests', () {
    late MockUserRepository mockRepo;
    late UserViewModel viewModel;

    setUp(() {
      mockRepo = MockUserRepository();
      viewModel = UserViewModel(mockRepo);
    });

    test('Initializes with default state', () {
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.users, isEmpty);
      expect(viewModel.currentPage, equals(1));
    });

    test('loadUsers fetches paginated users and calculates totalPages', () async {
      await viewModel.loadUsers();

      expect(viewModel.users.length, equals(3));
      expect(viewModel.totalUsers, equals(3));
      expect(viewModel.currentPage, equals(1));
      expect(viewModel.totalPages, equals(1));
      expect(viewModel.metrics.totalUsers, equals(3));
      expect(viewModel.metrics.adminsCount, equals(1));
    });

    test('setRoleFilter filters users by role', () async {
      viewModel.setRoleFilter(UserRole.developer);
      await Future.delayed(Duration.zero);

      expect(viewModel.users.length, equals(1));
      expect(viewModel.users.first.role, equals(UserRole.developer));
    });

    test('inviteUser adds new pending user and updates metrics', () async {
      final success = await viewModel.inviteUser(
        email: 'alex@taskforge.internal',
        fullName: 'Alex Rivera',
        role: UserRole.developer,
      );

      expect(success, isTrue);
      expect(viewModel.users.length, equals(4));
      expect(viewModel.users.any((u) => u.email == 'alex@taskforge.internal'), isTrue);
    });

    test('updateUserRole changes role in viewmodel', () async {
      await viewModel.loadUsers();
      final success = await viewModel.updateUserRole(3, UserRole.projectManager);

      expect(success, isTrue);
      final updated = viewModel.users.firstWhere((u) => u.id == 3);
      expect(updated.role, equals(UserRole.projectManager));
    });

    test('updateUserStatus modifies user operational status', () async {
      await viewModel.loadUsers();
      final success = await viewModel.updateUserStatus(2, UserStatus.suspended);

      expect(success, isTrue);
      final updated = viewModel.users.firstWhere((u) => u.id == 2);
      expect(updated.status, equals(UserStatus.suspended));
    });

    test('softDeleteUser removes user from active list', () async {
      await viewModel.loadUsers();
      final success = await viewModel.softDeleteUser(3);

      expect(success, isTrue);
      expect(viewModel.users.any((u) => u.id == 3), isFalse);
    });

    test('resetPassword returns issued reset token', () async {
      await viewModel.loadUsers();
      final token = await viewModel.resetPassword(1);

      expect(token, equals('test_reset_token_123'));
    });
  });
}
