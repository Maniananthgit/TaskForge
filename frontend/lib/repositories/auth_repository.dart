import '../core/utils/network_utils.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class AuthRepository {
  final AuthService _authService;
  final StorageService _storageService;

  AuthRepository(this._authService, this._storageService);

  bool _isNetworkFailure(dynamic error) => NetworkUtils.isNetworkOrHostFailure(error);

  UserModel _getDemoUser(String email, {UserRole? requestedRole, String? fullName}) {
    final lower = email.toLowerCase();
    UserRole role = requestedRole ?? UserRole.developer;
    String name = fullName ?? 'Demo User';

    if (lower.contains('admin')) {
      role = UserRole.admin;
      name = fullName ?? 'Enterprise Administrator (Demo)';
    } else if (lower.contains('pm') || lower.contains('manager')) {
      role = UserRole.projectManager;
      name = fullName ?? 'Sarah Connor (Demo PM)';
    } else {
      role = requestedRole ?? UserRole.developer;
      name = fullName ?? 'Alex Rivera (Demo Developer)';
    }

    return UserModel(
      id: 1,
      email: email,
      fullName: name,
      role: role,
      isActive: true,
      avatarUrl: null,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
    UserRole role = UserRole.developer,
  }) async {
    try {
      return await _authService.register(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );
    } catch (e) {
      if (_isNetworkFailure(e)) {
        final demoUser = _getDemoUser(email, requestedRole: role, fullName: fullName);
        await _storageService.saveTokens(
          accessToken: 'demo_offline_access_token',
          refreshToken: 'demo_offline_refresh_token',
        );
        await _storageService.saveUser(demoUser);
        return demoUser;
      }
      rethrow;
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _authService.login(email: email, password: password);
    } catch (e) {
      if (_isNetworkFailure(e)) {
        final demoUser = _getDemoUser(email);
        await _storageService.saveTokens(
          accessToken: 'demo_offline_access_token',
          refreshToken: 'demo_offline_refresh_token',
        );
        await _storageService.saveUser(demoUser);
        return demoUser;
      }
      rethrow;
    }
  }

  Future<UserModel?> getInitialUser() async {
    final token = await _storageService.getAccessToken();
    if (token == null) return null;

    final cachedUser = await _storageService.getUser();
    try {
      final freshUser = await _authService.getCurrentUser();
      return freshUser;
    } catch (_) {
      return cachedUser;
    }
  }

  Future<UserModel> updateProfile({
    String? fullName,
    String? password,
    String? avatarUrl,
  }) async {
    try {
      return await _authService.updateProfile(
        fullName: fullName,
        password: password,
        avatarUrl: avatarUrl,
      );
    } catch (e) {
      if (_isNetworkFailure(e)) {
        final current = await _storageService.getUser();
        final updated = UserModel(
          id: current?.id ?? 1,
          email: current?.email ?? 'admin@taskforge.internal',
          fullName: fullName ?? current?.fullName ?? 'User',
          role: current?.role ?? UserRole.admin,
          isActive: true,
          avatarUrl: avatarUrl ?? current?.avatarUrl,
        );
        await _storageService.saveUser(updated);
        return updated;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (_) {
      await _storageService.clearAuthData();
    }
  }
}
