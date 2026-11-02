import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/api_response.dart';
import 'storage_service.dart';

class ApiClient {
  final StorageService _storageService;
  final http.Client _client = http.Client();

  ApiClient(this._storageService);

  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await _storageService.getAccessToken();
      if (token != null) {
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

  // GET Request
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    Uri uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final stringParams = queryParameters.map((k, v) => MapEntry(k, v.toString()));
      uri = uri.replace(queryParameters: stringParams);
    }

    final headers = await _getHeaders(requiresAuth: requiresAuth);
    try {
      final response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 30));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Connection failed: ${e.toString()}');
    }
  }

  // POST Request
  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requiresAuth: requiresAuth);

    try {
      final response = await _client
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Request failed: ${e.toString()}');
    }
  }

  // PUT Request
  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requiresAuth: requiresAuth);

    try {
      final response = await _client
          .put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Update failed: ${e.toString()}');
    }
  }

  // PATCH Request
  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requiresAuth: requiresAuth);

    try {
      final response = await _client
          .patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Patch failed: ${e.toString()}');
    }
  }

  // DELETE Request
  Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requiresAuth: requiresAuth);

    try {
      final response = await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 30));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Delete failed: ${e.toString()}');
    }
  }
}
