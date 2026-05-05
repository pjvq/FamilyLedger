/// W14 Bug Regression Test — BUG-006: Offline Queue Persistence
///
/// @neverSkip BUG-006: Frontend offline queue must not lose entries on app restart.
///
/// Regression: The SyncQueue table entries were not being persisted correctly,
/// causing operations queued while offline to be lost when the app restarted.
/// This test verifies that entries written to the SyncQueue survive a database
/// close/reopen cycle (simulating app restart).

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/data/local/database.dart';

void main() {
  // @neverSkip BUG-006: Offline queue persistence — entries must survive app restart
  group('BUG-006: Offline queue persistence', () {
    test('SyncQueue entries persist across database close/reopen', () async {
      // Step 1: Create an in-memory database with a shared name so we can reopen it
      // For a real persistence test we use a temporary file
      final tempDir = Directory.systemTemp.createTempSync('bug006_test_');
      final dbPath = '${tempDir.path}/test.db';

      // First "app session": create DB and insert queue entries
      var db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));

      final now = DateTime.now();

      // Insert 3 offline operations into the sync queue
      await db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
        id: 'op-001',
        entityType: 'transaction',
        entityId: 'txn-aaa',
        opType: 'create',
        payload: '{"amount":100,"note":"groceries"}',
        clientId: 'device-1',
        timestamp: now.subtract(const Duration(minutes: 3)),
      ));
      await db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
        id: 'op-002',
        entityType: 'account',
        entityId: 'acct-bbb',
        opType: 'update',
        payload: '{"name":"Updated Account"}',
        clientId: 'device-1',
        timestamp: now.subtract(const Duration(minutes: 2)),
      ));
      await db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
        id: 'op-003',
        entityType: 'transaction',
        entityId: 'txn-ccc',
        opType: 'delete',
        payload: '{}',
        clientId: 'device-1',
        timestamp: now.subtract(const Duration(minutes: 1)),
      ));

      // Verify entries exist
      var entries = await db.select(db.syncQueue).get();
      expect(entries.length, 3, reason: 'Should have 3 queue entries before restart');

      // Verify none are marked as uploaded
      for (final entry in entries) {
        expect(entry.uploaded, false,
            reason: 'Entries should be un-uploaded (offline)');
      }

      // Step 2: Close database (simulating app kill)
      await db.close();

      // Step 3: Reopen database (simulating app restart)
      db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));

      // Step 4: Verify all 3 entries survived
      entries = await db.select(db.syncQueue).get();
      expect(entries.length, 3,
          reason:
              'BUG-006: All 3 queue entries must survive after database close/reopen');

      // Verify data integrity
      final op1 = entries.firstWhere((e) => e.id == 'op-001');
      expect(op1.entityType, 'transaction');
      expect(op1.entityId, 'txn-aaa');
      expect(op1.opType, 'create');
      expect(op1.payload, '{"amount":100,"note":"groceries"}');
      expect(op1.uploaded, false);

      final op2 = entries.firstWhere((e) => e.id == 'op-002');
      expect(op2.entityType, 'account');
      expect(op2.entityId, 'acct-bbb');
      expect(op2.opType, 'update');

      final op3 = entries.firstWhere((e) => e.id == 'op-003');
      expect(op3.entityType, 'transaction');
      expect(op3.entityId, 'txn-ccc');
      expect(op3.opType, 'delete');

      // Step 5: Mark one as uploaded, close, reopen, verify mixed state
      await (db.update(db.syncQueue)
            ..where((q) => q.id.equals('op-001')))
          .write(const SyncQueueCompanion(uploaded: Value(true)));

      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));

      entries = await db.select(db.syncQueue).get();
      expect(entries.length, 3,
          reason: 'BUG-006: Entries must persist after second restart');

      final op1After = entries.firstWhere((e) => e.id == 'op-001');
      expect(op1After.uploaded, true,
          reason: 'BUG-006: Upload status must persist across restart');

      final pendingEntries =
          entries.where((e) => !e.uploaded).toList();
      expect(pendingEntries.length, 2,
          reason:
              'BUG-006: 2 entries should still be pending upload after restart');

      // Cleanup
      await db.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('SyncQueue entries are ordered by timestamp for correct replay',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      final now = DateTime.now();

      // Insert entries out of order
      await db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
        id: 'late-op',
        entityType: 'transaction',
        entityId: 'txn-late',
        opType: 'create',
        payload: '{}',
        clientId: 'device-1',
        timestamp: now.add(const Duration(minutes: 10)),
      ));
      await db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
        id: 'early-op',
        entityType: 'transaction',
        entityId: 'txn-early',
        opType: 'create',
        payload: '{}',
        clientId: 'device-1',
        timestamp: now.subtract(const Duration(minutes: 10)),
      ));
      await db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
        id: 'mid-op',
        entityType: 'transaction',
        entityId: 'txn-mid',
        opType: 'create',
        payload: '{}',
        clientId: 'device-1',
        timestamp: now,
      ));

      // Query with timestamp ordering
      final entries = await (db.select(db.syncQueue)
            ..orderBy([
              (q) => OrderingTerm.asc(q.timestamp),
            ]))
          .get();

      expect(entries.length, 3);
      expect(entries[0].id, 'early-op',
          reason: 'BUG-006: Earliest entry must come first for correct replay');
      expect(entries[1].id, 'mid-op');
      expect(entries[2].id, 'late-op',
          reason: 'BUG-006: Latest entry must come last');

      await db.close();
    });

    test('SyncQueue un-uploaded entries can be queried for retry', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      final now = DateTime.now();

      // Insert mix of uploaded and un-uploaded
      await db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
        id: 'done-1',
        entityType: 'transaction',
        entityId: 'txn-done',
        opType: 'create',
        payload: '{}',
        clientId: 'device-1',
        timestamp: now,
        uploaded: const Value(true),
      ));
      await db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
        id: 'pending-1',
        entityType: 'account',
        entityId: 'acct-pending',
        opType: 'update',
        payload: '{"name":"test"}',
        clientId: 'device-1',
        timestamp: now.add(const Duration(seconds: 1)),
      ));
      await db.into(db.syncQueue).insert(SyncQueueCompanion.insert(
        id: 'pending-2',
        entityType: 'transaction',
        entityId: 'txn-pending',
        opType: 'delete',
        payload: '{}',
        clientId: 'device-1',
        timestamp: now.add(const Duration(seconds: 2)),
      ));

      // Query only un-uploaded entries (what the sync engine does on restart)
      final pending = await (db.select(db.syncQueue)
            ..where((q) => q.uploaded.equals(false))
            ..orderBy([(q) => OrderingTerm.asc(q.timestamp)]))
          .get();

      expect(pending.length, 2,
          reason: 'BUG-006: Only un-uploaded entries should be returned for retry');
      expect(pending[0].id, 'pending-1');
      expect(pending[1].id, 'pending-2');

      await db.close();
    });
  });
}
