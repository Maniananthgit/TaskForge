import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static const String _keyAccessToken = 'taskforge_access_token';
  static const String _keyRefreshToken = 'taskforge_refresh_token';
  static const String _keyUser = 'taskforge_cached_user';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Save Authentication Tokens
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyAccessToken, accessToken);
        await prefs.setString(_keyRefreshToken, refreshToken);
      } else {
        await _secureStorage.write(key: _keyAccessToken, value: accessToken);
        await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
      }
    } catch (e) {
      // Fallback for desktop platforms without keystore configured
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccessToken, accessToken);
      await prefs.setString(_keyRefreshToken, refreshToken);
    }
  }

  Future<String?> getAccessToken() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_keyAccessToken);
      }
      final token = await _secureStorage.read(key: _keyAccessToken);
      if (token != null) return token;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAccessToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAccessToken);
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_keyRefreshToken);
      }
      final token = await _secureStorage.read(key: _keyRefreshToken);
      if (token != null) return token;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyRefreshToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyRefreshToken);
    }
  }

  // Save Cached User Profile
  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyUser);
    if (userJson == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(userJson));
    } catch (_) {
      return null;
    }
  }

  // Clear on Logout
  Future<void> clearAuthData() async {
    try {
      await _secureStorage.delete(key: _keyAccessToken);
      await _secureStorage.delete(key: _keyRefreshToken);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUser);
  }
}
