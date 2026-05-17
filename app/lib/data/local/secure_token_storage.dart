import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/providers/app_providers.dart';

/// Abstract interface for token storage — enables testing without platform channels.
abstract class TokenStorage {
  Future<void> migrateIfNeeded();
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> setAccessToken(String token);
  Future<void> setRefreshToken(String token);
  Future<void> clearTokens();
}

/// Secure token storage — uses Keychain (iOS) / EncryptedSharedPreferences (Android).
/// Migrates tokens from plain SharedPreferences on first access.
class SecureTokenStorage implements TokenStorage {
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _migratedKey = 'secure_storage_migrated';

  final SharedPreferences _prefs;

  SecureTokenStorage(this._prefs);

  /// Migrate tokens from SharedPreferences to secure storage (one-time).
  ///
  /// Strategy: write-first, then mark migrated, then clean old.
  /// If crash after write but before mark → next launch re-writes (idempotent).
  /// If crash after mark but before clean → old keys linger harmlessly.
  /// Tokens are never lost.
  @override
  Future<void> migrateIfNeeded() async {
    if (_prefs.getBool(_migratedKey) == true) return;

    final accessToken = _prefs.getString(AppConstants.accessTokenKey);
    final refreshToken = _prefs.getString(AppConstants.refreshTokenKey);

    // Step 1: Write to secure storage (idempotent — safe to repeat)
    if (accessToken != null) {
      await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
    }
    if (refreshToken != null) {
      await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
    }

    // Step 2: Mark migration complete
    await _prefs.setBool(_migratedKey, true);

    // Step 3: Clean up old plaintext keys (non-critical — harmless if skipped)
    await _prefs.remove(AppConstants.accessTokenKey);
    await _prefs.remove(AppConstants.refreshTokenKey);
  }

  @override
  Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.accessTokenKey);

  @override
  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.refreshTokenKey);

  @override
  Future<void> setAccessToken(String token) =>
      _storage.write(key: AppConstants.accessTokenKey, value: token);

  @override
  Future<void> setRefreshToken(String token) =>
      _storage.write(key: AppConstants.refreshTokenKey, value: token);

  @override
  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }
}

/// In-memory implementation for tests (no platform channels needed).
class FakeSecureTokenStorage implements TokenStorage {
  final Map<String, String> _store = {};
  final SharedPreferences _prefs;

  FakeSecureTokenStorage(this._prefs);

  @override
  Future<void> migrateIfNeeded() async {
    final accessToken = _prefs.getString(AppConstants.accessTokenKey);
    final refreshToken = _prefs.getString(AppConstants.refreshTokenKey);
    if (accessToken != null) _store[AppConstants.accessTokenKey] = accessToken;
    if (refreshToken != null) _store[AppConstants.refreshTokenKey] = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async =>
      _store[AppConstants.accessTokenKey];

  @override
  Future<String?> getRefreshToken() async =>
      _store[AppConstants.refreshTokenKey];

  @override
  Future<void> setAccessToken(String token) async =>
      _store[AppConstants.accessTokenKey] = token;

  @override
  Future<void> setRefreshToken(String token) async =>
      _store[AppConstants.refreshTokenKey] = token;

  @override
  Future<void> clearTokens() async {
    _store.remove(AppConstants.accessTokenKey);
    _store.remove(AppConstants.refreshTokenKey);
  }

  /// Test helper — read stored tokens
  Map<String, String> get storedTokens => Map.unmodifiable(_store);
}

final secureTokenStorageProvider = Provider<TokenStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SecureTokenStorage(prefs);
});
