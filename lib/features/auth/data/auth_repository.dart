import 'package:dio/dio.dart';
import 'package:library_app/core/network/api_client.dart';
import 'package:library_app/features/auth/data/token_storage.dart';
import 'package:library_app/features/auth/domain/user.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  }) : _api = apiClient,
       _tokens = tokenStorage;

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _api.raw.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
      );
      final tokens = AuthTokens.fromJson(response.data!);
      if (!tokens.user.isLibraryRole) {
        throw AuthException(
          'This account cannot use the library app. Use the Publisher Dashboard.',
        );
      }
      await _tokens.save(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return tokens.user;
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error));
    }
  }

  Future<AuthUser?> restoreSession() async {
    final access = await _tokens.readAccess();
    if (access == null || access.isEmpty) {
      return null;
    }
    try {
      final response = await _api.raw.get<Map<String, dynamic>>(
        '/api/v1/auth/me',
      );
      return AuthUser.fromJson(response.data!);
    } on DioException {
      await _tokens.clear();
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _api.raw.post<void>('/api/v1/auth/logout');
    } on DioException {
      // Still clear local tokens.
    } finally {
      await _tokens.clear();
    }
  }

  String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final message = data['message'];
      if (message is List) {
        return message.join(' ');
      }
      return message.toString();
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Unable to reach the server.';
    }
    return 'Unable to sign in.';
  }
}
