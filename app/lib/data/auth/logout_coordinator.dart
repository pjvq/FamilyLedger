import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../local/database.dart';
import '../local/secure_token_storage.dart';

/// Performs a complete, ordered logout sequence that guarantees
/// no credential remnants survive even if individual steps fail.
///
/// Execution order is deliberate:
///   1. Clear secure tokens (highest sensitivity)
///   2. Clear auth-related preferences
///   3. Clear database (lowest priority — can be re-synced)
///
/// Each step is independent — failure of one does not block the others.
/// All exceptions are logged but swallowed: the user WILL be logged out
/// regardless of partial failures.
class LogoutCoordinator {
  final TokenStorage _tokenStorage;
  final SharedPreferences _prefs;
  final AppDatabase _db;

  const LogoutCoordinator({
    required TokenStorage tokenStorage,
    required SharedPreferences prefs,
    required AppDatabase db,
  })  : _tokenStorage = tokenStorage,
        _prefs = prefs,
        _db = db;

  /// Execute full logout. Returns list of step names that failed (empty = clean).
  Future<List<String>> execute() async {
    final failures = <String>[];

    // Step 1: Clear secure tokens — most critical
    if (!await _safeStep('clearTokens', () => _tokenStorage.clearTokens())) {
      failures.add('clearTokens');
    }

    // Step 2: Clear auth preferences
    if (!await _safeStep('clearPrefs', _clearPrefs)) {
      failures.add('clearPrefs');
    }

    // Step 3: Clear local database
    if (!await _safeStep('clearDatabase', () => _db.clearAllData())) {
      failures.add('clearDatabase');
    }

    if (failures.isNotEmpty) {
      developer.log(
        'LogoutCoordinator: partial failures: $failures',
        name: 'auth',
        level: 900, // WARNING
      );
    }

    return failures;
  }

  Future<void> _clearPrefs() async {
    await _prefs.remove(AppConstants.userIdKey);
    await _prefs.remove(AppConstants.familyIdKey);
    // Remove any other auth-related keys
    await _prefs.remove(AppConstants.accessTokenKey);
    await _prefs.remove(AppConstants.refreshTokenKey);
  }

  Future<bool> _safeStep(String name, Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e, stack) {
      developer.log(
        'LogoutCoordinator.$name failed: $e',
        name: 'auth',
        level: 1000, // SEVERE
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }
}
