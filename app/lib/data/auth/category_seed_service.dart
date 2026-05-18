import 'dart:async';
import 'dart:developer' as developer;

import '../local/database.dart';

/// Manages category seeding with retry and error reporting.
///
/// The first attempt is synchronous (awaited by caller).
/// Subsequent retries run in the background to avoid blocking login flow.
class CategorySeedService {
  final AppDatabase _db;

  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(seconds: 2);

  const CategorySeedService(this._db);

  /// Seeds default categories for the given user.
  ///
  /// **First attempt is immediate (awaited).** If it fails, spawns
  /// background retries so the login flow is not blocked (max ~6s total
  /// background wait, invisible to user).
  ///
  /// Returns true if the first (synchronous) attempt succeeded.
  /// Background retries log failures independently.
  ///
  /// This is idempotent — calling multiple times is safe (uses INSERT OR IGNORE).
  Future<bool> seedForUser(String userId) async {
    // First attempt — synchronous, fast-fail
    try {
      await _db.seedCategoriesForOwner(userId);
      developer.log(
        'CategorySeedService: seeded for user=$userId (immediate)',
        name: 'seed',
      );
      return true;
    } catch (e) {
      developer.log(
        'CategorySeedService: immediate seed failed, scheduling retries: $e',
        name: 'seed',
        level: 900,
      );
      // Launch background retries — do NOT await
      unawaited(_retryInBackground(userId));
      return false;
    }
  }

  Future<void> _retryInBackground(String userId) async {
    for (int attempt = 2; attempt <= _maxRetries; attempt++) {
      await Future<void>.delayed(_baseDelay * (attempt - 1));
      try {
        await _db.seedCategoriesForOwner(userId);
        developer.log(
          'CategorySeedService: seeded for user=$userId (retry $attempt)',
          name: 'seed',
        );
        return; // Success — stop retrying
      } catch (e, stack) {
        developer.log(
          'CategorySeedService: retry $attempt/$_maxRetries failed: $e',
          name: 'seed',
          level: 900,
          error: e,
          stackTrace: stack,
        );
      }
    }
    developer.log(
      'CategorySeedService: all retries exhausted for user=$userId. '
      'User may see empty categories until next login.',
      name: 'seed',
      level: 1000,
    );
  }
}
