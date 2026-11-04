import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/api_response.dart';
import 'storage_service.dart';

class ApiClient {
  final StorageService _storageService;
  final http.Client _client = http.Client();

  /// Optional callback invoked when the user's session permanently expires
  VoidCallback? onSessionExpired;

  /// Single-flight completer to prevent duplicate token refresh requests
  Completer<String?>? _refreshCompleter;

  ApiClient(this._storageService, {this.onSessionExpired});

  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await _storageService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  dynamic _processResponse(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      body = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is String) {
        final trimmed = body.trimLeft().toLowerCase();
        if (trimmed.startsWith('<!doctype') || trimmed.startsWith('<html')) {
          throw ApiException(
            message: 'Backend API service is not connected (host returned HTML page instead of API JSON).',
            statusCode: 503,
          );
        }
      }
      return body;
    }

    String message = 'An unexpected error occurred.';
    String? errorCode;

    if (body is Map<String, dynamic>) {
      if (body.containsKey('detail')) {
        message = body['detail'].toString();
      } else if (body.containsKey('message')) {
        message = body['message'].toString();
      }
      errorCode = body['error_code'] as String?;
    }

    throw ApiException(
      message: message,
      statusCode: response.statusCode,
      errorCode: errorCode,
    );
  }

  Future<http.Response> _executeRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    dynamic body,
  ) async {
    const timeout = Duration(seconds: 30);
    final encodedBody = body != null ? jsonEncode(body) : null;

    switch (method.toUpperCase()) {
      case 'GET':
        return await _client.get(uri, headers: headers).timeout(timeout);
      case 'POST':
        return await _client.post(uri, headers: headers, body: encodedBody).timeout(timeout);
      case 'PUT':
        return await _client.put(uri, headers: headers, body: encodedBody).timeout(timeout);
      case 'PATCH':
        return await _client.patch(uri, headers: headers, body: encodedBody).timeout(timeout);
      case 'DELETE':
        return await _client.delete(uri, headers: headers).timeout(timeout);
      default:
        throw ApiException(message: 'Unsupported HTTP method: $method');
    }
  }

  Future<dynamic> _sendWithAutoRefresh({
    required String method,
    required String endpoint,
    dynamic body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    Uri uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final stringParams = queryParameters.map((k, v) => MapEntry(k, v.toString()));
      uri = uri.replace(queryParameters: stringParams);
    }

    final headers = await _getHeaders(requiresAuth: requiresAuth);

    http.Response response;
    try {
      response = await _executeRequest(method, uri, headers, body);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network request failed: ${e.toString()}');
    }

    final isRefreshEndpoint = endpoint == ApiConstants.refresh;
    final isLoginEndpoint = endpoint == ApiConstants.login;

    // Intercept 401 Unauthorized for authenticated endpoints to perform automatic token refresh
    if (response.statusCode == 401 && requiresAuth && !isRefreshEndpoint && !isLoginEndpoint) {
      final newToken = await _attemptTokenRefresh();
      if (newToken != null) {
        // Retry the original request with the fresh access token
        final retryHeaders = await _getHeaders(requiresAuth: requiresAuth);
        try {
          final retryResponse = await _executeRequest(method, uri, retryHeaders, body);
          return _processResponse(retryResponse);
        } catch (e) {
          if (e is ApiException) rethrow;
          throw ApiException(message: 'Request retry failed: ${e.toString()}');
        }
      } else {
        _handleSessionExpired();
        throw ApiException(
          message: 'Your session has expired. Please log in again.',
          statusCode: 401,
          errorCode: 'SESSION_EXPIRED',
        );
      }
    }

    return _processResponse(response);
  }

  Future<String?> _attemptTokenRefresh() async {
    // If a refresh is already in-flight from another concurrent request, await its completion
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final currentRefreshToken = await _storageService.getRefreshToken();
      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        completer.complete(null);
        return null;
      }

      final refreshUri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refresh}');
      final response = await _client.post(
        refreshUri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh_token': currentRefreshToken}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic> && data.containsKey('access_token')) {
          final newAccessToken = data['access_token'] as String;
          final newRefreshToken = (data['refresh_token'] as String?) ?? currentRefreshToken;

          await _storageService.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          completer.complete(newAccessToken);
          return newAccessToken;
        }
      }

      completer.complete(null);
      return null;
    } catch (_) {
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  void _handleSessionExpired() {
    _storageService.clearAuthData();
    onSessionExpired?.call();
  }

  // GET Request
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _sendWithAutoRefresh(
      method: 'GET',
      endpoint: endpoint,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  // POST Request
  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) {
    return _sendWithAutoRefresh(
      method: 'POST',
      endpoint: endpoint,
      body: body,
      requiresAuth: requiresAuth,
    );
  }

  // PUT Request
  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) {
    return _sendWithAutoRefresh(
      method: 'PUT',
      endpoint: endpoint,
      body: body,
      requiresAuth: requiresAuth,
    );
  }

  // PATCH Request
  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) {
    return _sendWithAutoRefresh(
      method: 'PATCH',
      endpoint: endpoint,
      body: body,
      requiresAuth: requiresAuth,
    );
  }

  // DELETE Request
  Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) {
    return _sendWithAutoRefresh(
      method: 'DELETE',
      endpoint: endpoint,
      requiresAuth: requiresAuth,
    );
  }
}
