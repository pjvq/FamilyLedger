import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/providers/app_providers.dart';

/// Secure token storage — uses Keychain (iOS) / EncryptedSharedPreferences (Android).
/// Migrates tokens from plain SharedPreferences on first access.
class SecureTokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _migratedKey = 'secure_storage_migrated';

  final SharedPreferences _prefs;

  SecureTokenStorage(this._prefs);

  /// Migrate tokens from SharedPreferences to secure storage (one-time).
  Future<void> migrateIfNeeded() async {
    if (_prefs.getBool(_migratedKey) == true) return;

    final accessToken = _prefs.getString(AppConstants.accessTokenKey);
    final refreshToken = _prefs.getString(AppConstants.refreshTokenKey);

    if (accessToken != null) {
      await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
      await _prefs.remove(AppConstants.accessTokenKey);
    }
    if (refreshToken != null) {
      await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
      await _prefs.remove(AppConstants.refreshTokenKey);
    }

    await _prefs.setBool(_migratedKey, true);
  }

  Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.accessTokenKey);

  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.refreshTokenKey);

  Future<void> setAccessToken(String token) =>
      _storage.write(key: AppConstants.accessTokenKey, value: token);

  Future<void> setRefreshToken(String token) =>
      _storage.write(key: AppConstants.refreshTokenKey, value: token);

  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }
}

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SecureTokenStorage(prefs);
});
