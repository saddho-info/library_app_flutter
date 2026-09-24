import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/core/network/api_client.dart';
import 'package:library_app/features/auth/data/token_storage.dart';

Map<String, dynamic> get _libraryUser => {
  'id': '1',
  'email': 'lib@test.com',
  'firstName': 'Lib',
  'lastName': 'Admin',
  'role': 'LIBRARY_ADMIN',
};

String fakeJwt({required DateTime exp}) {
  final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}'));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({'exp': exp.toUtc().millisecondsSinceEpoch ~/ 1000}),
    ),
  );
  return '$header.$payload.sig';
}

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
  test('retries the original call after a successful refresh', () async {
    final tokens = MemoryTokenStorage();
    await tokens.save(accessToken: 'expired', refreshToken: 'refresh-1');

    final api = ApiClient(
      tokenStorage: tokens,
      dio: _dioWith(
        _FakeAdapter((options) async {
          final auth = options.headers['Authorization'];
          if (auth == 'Bearer new-access') {
            return jsonBody(200, {'ok': true});
          }
          return jsonBody(401);
        }),
      ),
      refreshDio: _dioWith(
        _FakeAdapter((options) async {
          return jsonBody(200, {
            'accessToken': 'new-access',
            'refreshToken': 'new-refresh',
            'expiresIn': 900,
            'user': _libraryUser,
          });
        }),
      ),
    );

    final response = await api.raw.get<Map<String, dynamic>>('/api/v1/sales');
    expect(response.statusCode, 200);
    expect(await tokens.readAccess(), 'new-access');
    expect(await tokens.readRefresh(), 'new-refresh');
  });

  test('keeps tokens when refresh times out', () async {
    final tokens = MemoryTokenStorage();
    await tokens.save(accessToken: 'expired', refreshToken: 'refresh-1');
    var expired = false;

    final api = ApiClient(
      tokenStorage: tokens,
      dio: _dioWith(_FakeAdapter((options) async => jsonBody(401))),
      refreshDio: _dioWith(
        _FakeAdapter((options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          );
        }),
      ),
      onSessionExpired: () => expired = true,
    );

    await expectLater(
      api.raw.get<Map<String, dynamic>>('/api/v1/sales'),
      throwsA(isA<DioException>()),
    );
    expect(await tokens.readRefresh(), 'refresh-1');
    expect(await tokens.readAccess(), 'expired');
    expect(expired, isFalse);
  });

  test('clears tokens when refresh is rejected', () async {
    final tokens = MemoryTokenStorage();
    await tokens.save(accessToken: 'expired', refreshToken: 'refresh-1');
    var expired = false;

    final api = ApiClient(
      tokenStorage: tokens,
      dio: _dioWith(_FakeAdapter((options) async => jsonBody(401))),
      refreshDio: _dioWith(_FakeAdapter((options) async => jsonBody(401))),
      onSessionExpired: () => expired = true,
    );

    await expectLater(
      api.raw.get<Map<String, dynamic>>('/api/v1/sales'),
      throwsA(isA<DioException>()),
    );
    expect(await tokens.readRefresh(), isNull);
    expect(await tokens.readAccess(), isNull);
    expect(expired, isTrue);
  });

  test(
    'refreshes before sending a request when access is about to expire',
    () async {
      final tokens = MemoryTokenStorage();
      await tokens.save(
        accessToken: fakeJwt(
          exp: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
        ),
        refreshToken: 'refresh-1',
        accessExpiresAt: DateTime.now().toUtc().subtract(
          const Duration(minutes: 1),
        ),
      );

      final api = ApiClient(
        tokenStorage: tokens,
        dio: _dioWith(
          _FakeAdapter((options) async {
            final auth = options.headers['Authorization'];
            if (auth == 'Bearer new-access') {
              return jsonBody(200, {'ok': true});
            }
            return jsonBody(401);
          }),
        ),
        refreshDio: _dioWith(
          _FakeAdapter((options) async {
            return jsonBody(200, {
              'accessToken': 'new-access',
              'refreshToken': 'new-refresh',
              'expiresIn': 900,
              'user': _libraryUser,
            });
          }),
        ),
      );

      final response = await api.raw.get<Map<String, dynamic>>('/api/v1/sales');
      expect(response.statusCode, 200);
      expect(await tokens.readAccess(), 'new-access');
    },
  );
}
