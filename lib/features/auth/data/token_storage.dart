abstract class TokenStorage {
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  });

  Future<String?> readAccess();

  Future<String?> readRefresh();

  Future<void> clear();
}

/// In-memory tokens for tests and non-secure contexts.
class MemoryTokenStorage implements TokenStorage {
  final Map<String, String> _values = {};

  static const _accessKey = 'pt_access_token';
  static const _refreshKey = 'pt_refresh_token';

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _values[_accessKey] = accessToken;
    _values[_refreshKey] = refreshToken;
  }

  @override
  Future<String?> readAccess() async => _values[_accessKey];

  @override
  Future<String?> readRefresh() async => _values[_refreshKey];

  @override
  Future<void> clear() async {
    _values.remove(_accessKey);
    _values.remove(_refreshKey);
  }
}
