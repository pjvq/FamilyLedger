/// Tests for Issue #72: UPDATE replay idempotency.
///
/// Verifies that replaying the same UPDATE op twice does NOT double-count
/// balance adjustments. This is the defense-in-depth layer alongside
/// per-page checkpoint advancement.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/generated/proto/google/protobuf/timestamp.pb.dart'
    as proto_ts;
import 'package:familyledger/generated/proto/sync.pb.dart' as sync_pb;
import 'package:familyledger/generated/proto/sync.pbenum.dart' as sync_enum;
import 'package:familyledger/sync/sync_engine.dart';

// ─── Helpers ─────────────────────────────────────────────────

sync_pb.SyncOperation _makeOp({
  required String entityType,
  required String entityId,
  required sync_enum.OperationType opType,
  required Map<String, dynamic> payload,
  required int timestampMs,
  String? opId,
}) {
  return sync_pb.SyncOperation(
    id: opId ?? 'op_${entityId}_${timestampMs}',
    entityType: entityType,
    entityId: entityId,
    opType: opType,
    payload: jsonEncode(payload),
    clientId: 'test_client',
    timestamp: proto_ts.Timestamp(
      seconds: Int64(timestampMs ~/ 1000),
      nanos: (timestampMs % 1000) * 1000000,
    ),
  );
}

Future<AppDatabase> _createDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  // NOTE: Drift is configured with DateTimeColumn storing unix seconds (int).
  // Raw SQL below uses seconds since epoch, matching that configuration.
  await db.customStatement(
    "INSERT OR IGNORE INTO users (id, email, created_at) "
    "VALUES ('u1', 'test@test.com', ${DateTime.now().millisecondsSinceEpoch ~/ 1000})",
  );
  await db.insertAccount(
    AccountsCompanion.insert(
      id: 'acc1',
      userId: 'u1',
      name: 'Main Account',
      familyId: const Value(''),
      accountType: const Value('bank_card'),
    ),
  );
  await db.insertAccount(
    AccountsCompanion.insert(
      id: 'acc2',
      userId: 'u1',
      name: 'Second Account',
      familyId: const Value(''),
      accountType: const Value('bank_card'),
    ),
  );
  return db;
}

// ─── Tests ───────────────────────────────────────────────────

void main() {
  group('Issue #72: UPDATE replay idempotency', () {
    late AppDatabase db;
    late SyncEngine engine;

    setUp(() async {
      db = await _createDb();
      engine = SyncEngine.forTesting(db);
    });

    tearDown(() async {
      engine.dispose();
      await db.close();
    });

    test('replaying same UPDATE op does not double-adjust balance', () async {
      // Setup: create a transaction locally (simulating a previous CREATE op)
      await db.insertOrUpdateTransaction(
        id: 'txn1',
        userId: 'u1',
        accountId: 'acc1',
        categoryId: 'cat1',
        amount: 100,
        amountCny: 100,
        type: 'expense',
        note: 'original',
        txnDate: DateTime(2025, 1, 1),
      );
      // Set initial account balance to 1000
      await db.customStatement(
        "UPDATE accounts SET balance = 1000 WHERE id = 'acc1'",
      );
      // Set txn updatedAt to past so LWW doesn't skip the remote op
      // Drift DateTimeColumn stores unix seconds (int) in this project config.
      final pastTs = DateTime(2020, 1, 1).millisecondsSinceEpoch ~/ 1000;
      await db.customStatement(
        "UPDATE transactions SET updated_at = $pastTs WHERE id = 'txn1'",
      );

      // Remote UPDATE op: change amount from 100 to 200
      final remoteTs = DateTime.now().add(const Duration(hours: 1));
      final updateOp = _makeOp(
        entityType: 'transaction',
        entityId: 'txn1',
        opType: sync_enum.OperationType.OPERATION_TYPE_UPDATE,
        payload: {
          'user_id': 'u1',
          'account_id': 'acc1',
          'category_id': 'cat1',
          'amount': 200,
          'amount_cny': 200,
          'type': 'expense',
          'note': 'updated',
          'txn_date': '2025-01-01T00:00:00',
          'updated_at': remoteTs.toIso8601String(),
        },
        timestampMs: remoteTs.millisecondsSinceEpoch,
      );

      // Apply the UPDATE op via _applyRemoteOp (exposed through transaction)
      await db.transaction(() async {
        await engine.applyRemoteOpForTest(updateOp);
      });

      // After first apply: balance should be 1000 - (-100 revert) + (-200 apply)
      // = 1000 + 100 - 200 = 900
      var acc = await db.getAccountById('acc1');
      expect(acc!.balance, 900, reason: 'First UPDATE: revert 100, apply 200');

      // Replay the SAME op (simulating interrupted pull replay)
      await db.transaction(() async {
        await engine.applyRemoteOpForTest(updateOp);
      });

      // After replay: balance should STILL be 900 (idempotent — no change
      // because oldTxn.amountCny == newAmountCny == 200 after first apply)
      acc = await db.getAccountById('acc1');
      expect(
        acc!.balance,
        900,
        reason: 'Replay same UPDATE should be idempotent',
      );
    });

    test('UPDATE changing account moves balance between accounts', () async {
      await db.insertOrUpdateTransaction(
        id: 'txn2',
        userId: 'u1',
        accountId: 'acc1',
        categoryId: 'cat1',
        amount: 50,
        amountCny: 50,
        type: 'expense',
        note: 'on acc1',
        txnDate: DateTime(2025, 1, 1),
      );
      await db.customStatement(
        "UPDATE accounts SET balance = 1000 WHERE id = 'acc1'",
      );
      await db.customStatement(
        "UPDATE accounts SET balance = 500 WHERE id = 'acc2'",
      );
      // Set txn updatedAt to past so LWW doesn't skip
      // Drift DateTimeColumn stores unix seconds (int) in this project config.
      final pastTs = DateTime(2020, 1, 1).millisecondsSinceEpoch ~/ 1000;
      await db.customStatement(
        "UPDATE transactions SET updated_at = $pastTs WHERE id = 'txn2'",
      );

      final remoteTs = DateTime.now().add(const Duration(hours: 1));
      // Move transaction from acc1 to acc2
      final moveOp = _makeOp(
        entityType: 'transaction',
        entityId: 'txn2',
        opType: sync_enum.OperationType.OPERATION_TYPE_UPDATE,
        payload: {
          'user_id': 'u1',
          'account_id': 'acc2',
          'category_id': 'cat1',
          'amount': 50,
          'amount_cny': 50,
          'type': 'expense',
          'note': 'moved to acc2',
          'txn_date': '2025-01-01T00:00:00',
          'updated_at': remoteTs.toIso8601String(),
        },
        timestampMs: remoteTs.millisecondsSinceEpoch,
      );

      await db.transaction(() async {
        await engine.applyRemoteOpForTest(moveOp);
      });

      // acc1: 1000 + 50 (revert expense) = 1050
      // acc2: 500 - 50 (apply expense) = 450
      var acc1 = await db.getAccountById('acc1');
      var acc2 = await db.getAccountById('acc2');
      expect(acc1!.balance, 1050);
      expect(acc2!.balance, 450);

      // Replay — account differs from stored (acc2 vs acc2 now) → no change
      await db.transaction(() async {
        await engine.applyRemoteOpForTest(moveOp);
      });

      acc1 = await db.getAccountById('acc1');
      acc2 = await db.getAccountById('acc2');
      expect(acc1!.balance, 1050, reason: 'Replay should not re-revert acc1');
      expect(acc2!.balance, 450, reason: 'Replay should not re-apply acc2');
    });

    test(
      'UPDATE for non-existent txn (CREATE semantics) applies balance once',
      () async {
        await db.customStatement(
          "UPDATE accounts SET balance = 1000 WHERE id = 'acc1'",
        );

        final remoteTs = DateTime.now().add(const Duration(hours: 1));
        final op = _makeOp(
          entityType: 'transaction',
          entityId: 'txn_ghost',
          opType: sync_enum.OperationType.OPERATION_TYPE_UPDATE,
          payload: {
            'user_id': 'u1',
            'account_id': 'acc1',
            'category_id': 'cat1',
            'amount': 300,
            'amount_cny': 300,
            'type': 'income',
            'note': 'ghost update',
            'txn_date': '2025-01-01T00:00:00',
            'updated_at': remoteTs.toIso8601String(),
          },
          timestampMs: remoteTs.millisecondsSinceEpoch,
        );

        await db.transaction(() async {
          await engine.applyRemoteOpForTest(op);
        });

        // oldTxn == null, so shouldAdjustBalance == true
        // No revert, apply +300 (income)
        var acc = await db.getAccountById('acc1');
        expect(acc!.balance, 1300);

        // Replay: now oldTxn exists with same values → no change
        await db.transaction(() async {
          await engine.applyRemoteOpForTest(op);
        });

        acc = await db.getAccountById('acc1');
        expect(acc!.balance, 1300, reason: 'Replay should be idempotent');
      },
    );
  });
}
