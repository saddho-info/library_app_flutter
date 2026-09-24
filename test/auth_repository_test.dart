import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/core/network/api_client.dart';
import 'package:library_app/features/auth/data/auth_repository.dart';
import 'package:library_app/features/auth/data/token_storage.dart';
import 'package:library_app/features/auth/domain/user.dart';

const _user = AuthUser(
  id: '1',
  email: 'lib@test.com',
  firstName: 'Lib',
  lastName: 'Admin',
  role: 'LIBRARY_ADMIN',
  libraryId: 'lib_1',
);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.onFetch);

  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(int status, [Object? data]) {
  return ResponseBody.fromString(
    data == null ? '' : jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Dio _dioWith(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  test('offline /auth/me keeps tokens and restores the cached user', () async {
    final tokens = MemoryTokenStorage();
    await tokens.save(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      userJson: jsonEncode(_user.toJson()),
    );

    final api = ApiClient(
      tokenStorage: tokens,
      dio: _dioWith(
        _FakeAdapter((options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }),
      ),
      refreshDio: _dioWith(
        _FakeAdapter((options) async {
          fail('refresh should not run for a connection error');
        }),
      ),
    );
    final repo = AuthRepository(apiClient: api, tokenStorage: tokens);

    final restored = await repo.restoreSession();
    expect(restored?.email, 'lib@test.com');
    expect(await tokens.readRefresh(), 'refresh-1');
    expect(await tokens.readAccess(), 'access-1');
  });

  test('restoreSession signs out when refresh is rejected', () async {
    final tokens = MemoryTokenStorage();
    await tokens.save(
      accessToken: 'expired',
      refreshToken: 'refresh-1',
      userJson: jsonEncode(_user.toJson()),
    );

    final api = ApiClient(
      tokenStorage: tokens,
      dio: _dioWith(_FakeAdapter((options) async => jsonBody(401))),
      refreshDio: _dioWith(_FakeAdapter((options) async => jsonBody(401))),
    );
    final repo = AuthRepository(apiClient: api, tokenStorage: tokens);

    final restored = await repo.restoreSession();
    expect(restored, isNull);
    expect(await tokens.readRefresh(), isNull);
  });

  test('logout posts the refresh token for this device only', () async {
    final tokens = MemoryTokenStorage();
    await tokens.save(accessToken: 'access-1', refreshToken: 'refresh-1');
    Map<String, dynamic>? body;

    final api = ApiClient(
      tokenStorage: tokens,
      dio: _dioWith(
        _FakeAdapter((options) async {
          if (options.path.contains('/auth/logout')) {
            body =
                jsonDecode(utf8.decode(await options.bodyBytes()))
                    as Map<String, dynamic>;
            return jsonBody(204);
          }
          return jsonBody(404);
        }),
      ),
    );
    final repo = AuthRepository(apiClient: api, tokenStorage: tokens);

    await repo.logout();
    expect(body, {'refreshToken': 'refresh-1'});
    expect(await tokens.readRefresh(), isNull);
  });
}

extension on RequestOptions {
  Future<List<int>> bodyBytes() async {
    final data = this.data;
    if (data is List<int>) {
      return data;
    }
    if (data is String) {
      return utf8.encode(data);
    }
    if (data is Map) {
      return utf8.encode(jsonEncode(data));
    }
    return utf8.encode(data?.toString() ?? '');
  }
}
