import 'package:dio/dio.dart';
import 'package:library_app/core/network/api_config.dart';
import 'package:library_app/features/auth/data/token_storage.dart';

typedef SessionExpiredCallback = void Function();

class ApiClient {
  ApiClient({
    required this._tokenStorage,
    Dio? dio,
    String? baseUrl,
    this._onSessionExpired,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? ApiConfig.baseUrl,
               headers: {'Content-Type': 'application/json'},
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 15),
             ),
           ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
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
          if (status != 401 || alreadyRetried || path.contains('/auth/')) {
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
          } catch (_) {
            await _expireSession();
            handler.next(error);
          }
        },
      ),
    );
  }

  final TokenStorage _tokenStorage;
  final SessionExpiredCallback? _onSessionExpired;
  final Dio _dio;
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
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/refresh',
      data: {'refreshToken': refresh},
      options: Options(
        headers: {'Authorization': null},
        extra: {'retried': true},
      ),
    );
    final data = response.data;
    final accessToken = data?['accessToken'] as String?;
    final refreshToken = data?['refreshToken'] as String?;
    if (accessToken == null || refreshToken == null) {
      return false;
    }
    await _tokenStorage.save(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    return true;
  }
}
