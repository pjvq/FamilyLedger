import 'dart:developer' as developer;

import '../local/database.dart';

/// Manages category seeding with retry and error reporting.
///
/// Replaces the fire-and-forget `_db.seedCategoriesForOwner(userId)`
/// pattern which silently fails and leaves users with empty category lists.
class CategorySeedService {
  final AppDatabase _db;

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  const CategorySeedService(this._db);

  /// Seeds default categories for the given user.
  ///
  /// Retries up to [_maxRetries] times with exponential backoff.
  /// Returns true if seeding succeeded, false if all retries exhausted.
  ///
  /// This is idempotent — calling multiple times is safe (uses INSERT OR IGNORE).
  Future<bool> seedForUser(String userId) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        await _db.seedCategoriesForOwner(userId);
        developer.log(
          'CategorySeedService: seeded for user=$userId (attempt $attempt)',
          name: 'seed',
        );
        return true;
      } catch (e, stack) {
        developer.log(
          'CategorySeedService: attempt $attempt/$_maxRetries failed: $e',
          name: 'seed',
          level: 900,
          error: e,
          stackTrace: stack,
        );
        if (attempt < _maxRetries) {
          await Future<void>.delayed(_retryDelay * attempt);
        }
      }
    }
    developer.log(
      'CategorySeedService: all retries exhausted for user=$userId',
      name: 'seed',
      level: 1000,
    );
    return false;
  }
}
