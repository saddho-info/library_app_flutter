import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:library_app/core/network/api_config.dart';
import 'package:library_app/features/auth/data/token_storage.dart';
import 'package:library_app/features/auth/domain/user.dart';

typedef SessionExpiredCallback = void Function();

const _proactiveRefreshWindow = Duration(seconds: 60);

class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    Dio? dio,
    Dio? refreshDio,
    String? baseUrl,
    SessionExpiredCallback? onSessionExpired,
  }) : _tokenStorage = tokenStorage,
       _onSessionExpired = onSessionExpired,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? ApiConfig.baseUrl,
               headers: {'Content-Type': 'application/json'},
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 15),
             ),
           ),
       _refreshDio =
           refreshDio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? dio?.options.baseUrl ?? ApiConfig.baseUrl,
               headers: {'Content-Type': 'application/json'},
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 15),
             ),
           ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!_isAuthPath(options.path)) {
            try {
              if (await _accessExpiringSoon()) {
                final refreshed = await _refresh();
                if (!refreshed) {
                  await _expireSession();
                }
              }
            } on DioException {
              // Keep the stored token and let the request proceed.
            }
          }

          final access = await _tokenStorage.readAccess();
          if (access != null && access.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $access';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          if (status != 401 || alreadyRetried || _isAuthPath(path)) {
            handler.next(error);
            return;
          }

          try {
            final refreshed = await _refresh();
            if (!refreshed) {
              await _expireSession();
              handler.next(error);
              return;
            }
            final access = await _tokenStorage.readAccess();
            final request = error.requestOptions;
            request.headers['Authorization'] = 'Bearer $access';
            request.extra['retried'] = true;
            final response = await _dio.fetch(request);
            handler.resolve(response);
          } on DioException {
            handler.next(error);
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );
  }

  final TokenStorage _tokenStorage;
  final SessionExpiredCallback? _onSessionExpired;
  final Dio _dio;
  final Dio _refreshDio;
  Future<bool>? _refreshInFlight;

  Dio get raw => _dio;

  Future<void> _expireSession() async {
    await _tokenStorage.clear();
    _onSessionExpired?.call();
  }

  Future<bool> _refresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
    _refreshInFlight = future;
    return future;
  }

  Future<bool> _doRefresh() async {
    final refresh = await _tokenStorage.readRefresh();
    if (refresh == null || refresh.isEmpty) {
      return false;
    }

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final data = response.data;
      final accessToken = data?['accessToken'] as String?;
      final refreshToken = data?['refreshToken'] as String?;
      if (accessToken == null || refreshToken == null) {
        return false;
      }
      final expiresIn = data?['expiresIn'];
      final userJson = _userJsonFrom(data?['user']);
      await _tokenStorage.save(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userJson: userJson,
        accessExpiresAt: _expiresAtFrom(expiresIn) ?? jwtExpiry(accessToken),
      );
      return true;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> _accessExpiringSoon() async {
    final stored = await _tokenStorage.readAccessExpiresAt();
    final expiry = stored ?? jwtExpiry(await _tokenStorage.readAccess());
    if (expiry == null) {
      return false;
    }
    return !expiry.isAfter(DateTime.now().toUtc().add(_proactiveRefreshWindow));
  }

  bool _isAuthPath(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/logout');
  }

  String? _userJsonFrom(Object? user) {
    if (user is Map<String, dynamic>) {
      return jsonEncode(AuthUser.fromJson(user).toJson());
    }
    if (user is Map) {
      return jsonEncode(
        AuthUser.fromJson(Map<String, dynamic>.from(user)).toJson(),
      );
    }
    return null;
  }

  DateTime? _expiresAtFrom(Object? expiresIn) {
    if (expiresIn is int) {
      return DateTime.now().toUtc().add(Duration(seconds: expiresIn));
    }
    if (expiresIn is num) {
      return DateTime.now().toUtc().add(Duration(seconds: expiresIn.toInt()));
    }
    return null;
  }
}

DateTime? jwtExpiry(String? token) {
  if (token == null || token.isEmpty) {
    return null;
  }
  final parts = token.split('.');
  if (parts.length < 2) {
    return null;
  }
  try {
    final normalized = base64Url.normalize(parts[1]);
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(normalized)))
            as Map<String, dynamic>;
    final exp = payload['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    }
    if (exp is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      );
    }
  } catch (_) {
    return null;
  }
  return null;
}
