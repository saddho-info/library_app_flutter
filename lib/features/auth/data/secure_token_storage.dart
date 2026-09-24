import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:library_app/features/auth/data/token_storage.dart';

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // v11 uses Android Keystore + AES-GCM by default (no ESP flag).
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _accessKey = 'pt_access_token';
  static const _refreshKey = 'pt_refresh_token';
  static const _userKey = 'pt_auth_user';
  static const _expiresKey = 'pt_access_expires_at';

  final FlutterSecureStorage _storage;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userJson,
    DateTime? accessExpiresAt,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    if (userJson != null) {
      await _storage.write(key: _userKey, value: userJson);
    }
    if (accessExpiresAt != null) {
      await _storage.write(
        key: _expiresKey,
        value: accessExpiresAt.toUtc().toIso8601String(),
      );
    }
  }

  @override
  Future<String?> readAccess() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  @override
  Future<String?> readUserJson() => _storage.read(key: _userKey);

  @override
  Future<DateTime?> readAccessExpiresAt() async {
    final raw = await _storage.read(key: _expiresKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  @override
  Future<void> writeUserJson(String userJson) {
    return _storage.write(key: _userKey, value: userJson);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _expiresKey);
  }
}
