import 'package:familyledger/domain/providers/backup_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('backupReminderDue', () {
    final now = DateTime(2026, 6, 26, 12);

    test('never backed up → due', () {
      expect(backupReminderDue(null, now), isTrue);
    });

    test('backed up today → not due', () {
      expect(backupReminderDue(now.subtract(const Duration(hours: 3)), now),
          isFalse);
    });

    test('just under threshold → not due', () {
      expect(
        backupReminderDue(now.subtract(const Duration(days: 13)), now),
        isFalse,
      );
    });

    test('at/over threshold → due', () {
      expect(
        backupReminderDue(now.subtract(const Duration(days: 14)), now),
        isTrue,
      );
      expect(
        backupReminderDue(now.subtract(const Duration(days: 60)), now),
        isTrue,
      );
    });

    test('custom threshold respected', () {
      final last = now.subtract(const Duration(days: 5));
      expect(backupReminderDue(last, now, thresholdDays: 7), isFalse);
      expect(backupReminderDue(last, now, thresholdDays: 3), isTrue);
    });
  });
}
