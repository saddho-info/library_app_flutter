abstract class TokenStorage {
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userJson,
    DateTime? accessExpiresAt,
  });

  Future<String?> readAccess();

  Future<String?> readRefresh();

  Future<String?> readUserJson();

  Future<DateTime?> readAccessExpiresAt();

  Future<void> writeUserJson(String userJson);

  Future<void> clear();
}

/// In-memory tokens for tests and non-secure contexts.
class MemoryTokenStorage implements TokenStorage {
  final Map<String, String> _values = {};

  static const _accessKey = 'pt_access_token';
  static const _refreshKey = 'pt_refresh_token';
  static const _userKey = 'pt_auth_user';
  static const _expiresKey = 'pt_access_expires_at';

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userJson,
    DateTime? accessExpiresAt,
  }) async {
    _values[_accessKey] = accessToken;
    _values[_refreshKey] = refreshToken;
    if (userJson != null) {
      _values[_userKey] = userJson;
    }
    if (accessExpiresAt != null) {
      _values[_expiresKey] = accessExpiresAt.toUtc().toIso8601String();
    }
  }

  @override
  Future<String?> readAccess() async => _values[_accessKey];

  @override
  Future<String?> readRefresh() async => _values[_refreshKey];

  @override
  Future<String?> readUserJson() async => _values[_userKey];

  @override
  Future<DateTime?> readAccessExpiresAt() async {
    final raw = _values[_expiresKey];
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  @override
  Future<void> writeUserJson(String userJson) async {
    _values[_userKey] = userJson;
  }

  @override
  Future<void> clear() async {
    _values.remove(_accessKey);
    _values.remove(_refreshKey);
    _values.remove(_userKey);
    _values.remove(_expiresKey);
  }
}
