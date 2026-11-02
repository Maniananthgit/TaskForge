import '../core/constants/api_constants.dart';
import '../models/api_response.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'storage_service.dart';

class AuthService {
  final ApiClient _apiClient;
  final StorageService _storageService;

  AuthService(this._apiClient, this._storageService);

  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
    UserRole role = UserRole.developer,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.register,
      body: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': role.toApiString(),
      },
      requiresAuth: false,
    );

    if (response is! Map<String, dynamic>) {
      throw ApiException(message: 'Backend server returned unexpected format.');
    }
    return UserModel.fromJson(response);
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.login,
      body: {
        'email': email,
        'password': password,
      },
      requiresAuth: false,
    );

    if (response is! Map<String, dynamic>) {
      throw ApiException(message: 'Backend server returned unexpected format.');
    }
    final data = response;
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

    await _storageService.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    await _storageService.saveUser(user);

    return user;
  }

  Future<UserModel> getCurrentUser() async {
    final response = await _apiClient.get(ApiConstants.me);
    if (response is! Map<String, dynamic>) {
      throw ApiException(message: 'Backend server returned unexpected format.');
    }
    final user = UserModel.fromJson(response);
    await _storageService.saveUser(user);
    return user;
  }

  Future<UserModel> updateProfile({
    String? fullName,
    String? password,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;

    final response = await _apiClient.put(ApiConstants.me, body: body);
    final user = UserModel.fromJson(response as Map<String, dynamic>);
    await _storageService.saveUser(user);
    return user;
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(ApiConstants.logout);
    } catch (_) {
      // Continue client cleanup even if network fails
    }
    await _storageService.clearAuthData();
  }
}
