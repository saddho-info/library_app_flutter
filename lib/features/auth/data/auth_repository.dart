import 'dart:convert';

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
        userJson: jsonEncode(tokens.user.toJson()),
        accessExpiresAt: DateTime.now().toUtc().add(
          Duration(seconds: tokens.expiresIn),
        ),
      );
      return tokens.user;
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error));
    }
  }

  Future<AuthUser?> restoreSession() async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null || refresh.isEmpty) {
      return null;
    }
    try {
      final response = await _api.raw.get<Map<String, dynamic>>(
        '/api/v1/auth/me',
      );
      final user = AuthUser.fromJson(response.data!);
      await _tokens.writeUserJson(jsonEncode(user.toJson()));
      return user;
    } on DioException {
      final remaining = await _tokens.readRefresh();
      if (remaining == null || remaining.isEmpty) {
        return null;
      }
      return _readCachedUser();
    }
  }

  Future<void> logout() async {
    final refresh = await _tokens.readRefresh();
    try {
      await _api.raw.post<void>(
        '/api/v1/auth/logout',
        data: {
          if (refresh != null && refresh.isNotEmpty) 'refreshToken': refresh,
        },
      );
    } on DioException {
      // Still clear local tokens.
    } finally {
      await _tokens.clear();
    }
  }

  Future<AuthUser?> _readCachedUser() async {
    final raw = await _tokens.readUserJson();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AuthUser.fromJson(decoded);
      }
      if (decoded is Map) {
        return AuthUser.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return null;
    }
    return null;
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
