import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/backup/database_backup_service.dart';
import 'app_providers.dart';

/// SharedPreferences key for the last successful backup timestamp (ms).
const _lastBackupKey = 'last_backup_at_ms';

/// Days without a backup after which the UI nudges the user.
const int backupReminderThresholdDays = 14;

/// App-wide encrypted backup/restore service (local DB ↔ encrypted file).
final databaseBackupServiceProvider = Provider<DatabaseBackupService>((ref) {
  return DatabaseBackupService(ref.watch(databaseProvider));
});

/// Reads/persists the last-backup timestamp and derives the "please back up"
/// nudge. Kept tiny + injectable so the reminder logic is unit-testable.
class BackupStatus {
  BackupStatus(this._prefs);

  final SharedPreferences _prefs;

  DateTime? get lastBackupAt {
    final ms = _prefs.getInt(_lastBackupKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> markBackedUp(DateTime when) =>
      _prefs.setInt(_lastBackupKey, when.millisecondsSinceEpoch);
}

final backupStatusProvider = Provider<BackupStatus>((ref) {
  return BackupStatus(ref.watch(sharedPreferencesProvider));
});

/// Whether to nudge the user to back up: never backed up, or it's been longer
/// than [thresholdDays]. Pure — [now]/[lastBackupAt] injected for tests.
bool backupReminderDue(
  DateTime? lastBackupAt,
  DateTime now, {
  int thresholdDays = backupReminderThresholdDays,
}) {
  if (lastBackupAt == null) return true;
  return now.difference(lastBackupAt).inDays >= thresholdDays;
}
