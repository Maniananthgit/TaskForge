import 'package:flutter_test/flutter_test.dart';
import 'package:taskforge_app/models/user_model.dart';
import 'package:taskforge_app/repositories/auth_repository.dart';
import 'package:taskforge_app/viewmodels/auth_viewmodel.dart';

class MockAuthRepository implements AuthRepository {
  UserModel? mockUser;
  bool shouldFail = false;

  @override
  Future<UserModel> login({required String email, required String password}) async {
    if (shouldFail) throw Exception('Invalid credentials');
    return mockUser ??
        UserModel(
          id: 1,
          email: email,
          fullName: 'Test User',
          role: UserRole.developer,
        );
  }

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
    UserRole role = UserRole.developer,
  }) async {
    if (shouldFail) throw Exception('Email already exists');
    return UserModel(id: 2, email: email, fullName: fullName, role: role);
  }

  @override
  Future<UserModel?> getInitialUser() async {
    return mockUser;
  }

  @override
  Future<UserModel> updateProfile({String? fullName, String? password, String? avatarUrl}) async {
    return mockUser!;
  }

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    if (shouldFail) throw Exception('Incorrect password');
  }

  @override
  Future<void> logout() async {
    mockUser = null;
  }
}

void main() {
  group('AuthViewModel Unit Tests', () {
    late MockAuthRepository mockRepo;
    late AuthViewModel viewModel;

    setUp(() {
      mockRepo = MockAuthRepository();
    });

    test('Initializes to unauthenticated when no stored session exists', () async {
      viewModel = AuthViewModel(mockRepo);
      await viewModel.initialize();

      expect(viewModel.status, AuthStatus.unauthenticated);
      expect(viewModel.isAuthenticated, false);
      expect(viewModel.currentUser, isNull);
    });

    test('Initializes to authenticated when stored user exists', () async {
      mockRepo.mockUser = UserModel(
        id: 99,
        email: 'saved@taskforge.internal',
        fullName: 'Saved User',
        role: UserRole.admin,
      );
      viewModel = AuthViewModel(mockRepo);
      await viewModel.initialize();

      expect(viewModel.status, AuthStatus.authenticated);
      expect(viewModel.isAuthenticated, true);
      expect(viewModel.currentUser?.email, 'saved@taskforge.internal');
      expect(viewModel.currentUser?.role, UserRole.admin);
    });

    test('Successful login transitions to authenticated state', () async {
      viewModel = AuthViewModel(mockRepo);
      final success = await viewModel.login(
        email: 'alex@company.com',
        password: 'Password123!',
      );

      expect(success, true);
      expect(viewModel.status, AuthStatus.authenticated);
      expect(viewModel.isAuthenticated, true);
      expect(viewModel.currentUser?.email, 'alex@company.com');
      expect(viewModel.errorMessage, isNull);
    });

    test('Failed login transitions to unauthenticated with error message', () async {
      mockRepo.shouldFail = true;
      viewModel = AuthViewModel(mockRepo);

      final success = await viewModel.login(
        email: 'wrong@company.com',
        password: 'badpassword',
      );

      expect(success, false);
      expect(viewModel.status, AuthStatus.unauthenticated);
      expect(viewModel.isAuthenticated, false);
      expect(viewModel.errorMessage, contains('Invalid credentials'));
    });

    test('Logout clears current user and sets unauthenticated', () async {
      mockRepo.mockUser = UserModel(
        id: 1,
        email: 'user@taskforge.internal',
        fullName: 'Active User',
        role: UserRole.projectManager,
      );
      viewModel = AuthViewModel(mockRepo);
      await viewModel.initialize();
      expect(viewModel.isAuthenticated, true);

      await viewModel.logout();
      expect(viewModel.status, AuthStatus.unauthenticated);
      expect(viewModel.currentUser, isNull);
      expect(viewModel.isAuthenticated, false);
    });

    test('Change password delegates to repository and handles errors', () async {
      viewModel = AuthViewModel(mockRepo);
      final ok = await viewModel.changePassword(
        currentPassword: 'OldPassword123!',
        newPassword: 'NewPassword123!',
      );
      expect(ok, true);
      expect(viewModel.errorMessage, isNull);

      mockRepo.shouldFail = true;
      final fail = await viewModel.changePassword(
        currentPassword: 'Wrong!',
        newPassword: 'NewPassword123!',
      );
      expect(fail, false);
      expect(viewModel.errorMessage, contains('Incorrect password'));
    });
  });
}
