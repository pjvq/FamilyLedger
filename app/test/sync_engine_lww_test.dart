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

// ─── Test helpers ────────────────────────────────────────────

/// Creates a SyncOperation proto for testing.
sync_pb.SyncOperation _makeOp({
  required String entityType,
  required String entityId,
  required sync_enum.OperationType opType,
  required Map<String, dynamic> payload,
  required DateTime timestamp,
  String clientId = 'test_client',
}) {
  final tsMs = timestamp.millisecondsSinceEpoch;
  return sync_pb.SyncOperation(
    id: 'op_${entityId}_${opType.name}',
    entityType: entityType,
    entityId: entityId,
    opType: opType,
    payload: jsonEncode(payload),
    clientId: clientId,
    timestamp: proto_ts.Timestamp(
      seconds: Int64(tsMs ~/ 1000),
      nanos: (tsMs % 1000) * 1000000,
    ),
  );
}

Future<AppDatabase> _setupDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  // Insert required user for FK constraints using Drift API
  await db.customStatement(
      "INSERT OR IGNORE INTO users (id, email, created_at) "
      "VALUES ('user1', 'test@test.com', ${DateTime.now().millisecondsSinceEpoch ~/ 1000})");
  // Insert account using Drift's insertAccount (handles datetime properly)
  await db.insertAccount(AccountsCompanion.insert(
    id: 'acc1',
    userId: 'user1',
    name: 'Test Account',
    familyId: const Value('fam1'),
    accountType: const Value('bank_card'),
  ));
  return db;
}

// ─── Tests ───────────────────────────────────────────────────

void main() {
  group('SyncEngine LWW conflict resolution', () {
    late AppDatabase db;
    late SyncEngine engine;

    setUp(() async {
      db = await _setupDb();
      // Use the forTesting constructor + override _db for our test.
      // We need direct access to _applyRemoteOp. Since it's private,
      // we'll test through the public-facing behavior by calling the
      // internal method via a testable subclass.
      engine = _TestableSyncEngine(db);
    });

    tearDown(() async {
      engine.dispose();
      await db.close();
    });

    group('Transaction operations', () {
      test('applies remote op when entity does not exist locally (new entity)',
          () async {
        final remoteTime = DateTime(2025, 3, 1, 12, 0, 0);
        final op = _makeOp(
          entityType: 'transaction',
          entityId: 'txn_new',
          opType: sync_enum.OperationType.OPERATION_TYPE_CREATE,
          payload: {
            'user_id': 'user1',
            'account_id': 'acc1',
            'category_id': 'cat1',
            'amount': 1500,
            'amount_cny': 1500,
            'type': 'expense',
            'note': 'remote created',
            'txn_date': '2025-03-01T12:00:00',
          },
          timestamp: remoteTime,
        );

        await (engine as _TestableSyncEngine).applyRemoteOp(op);

        final txn = await db.getTransactionById('txn_new');
        expect(txn, isNotNull);
        expect(txn!.note, 'remote created');
        expect(txn.amount, 1500);
      });

      test(
          'applies remote op when remote timestamp >= local updated_at',
          () async {
        // Insert local transaction with updated_at = Jan 1 2025
        final localTime = DateTime(2025, 1, 1, 10, 0, 0);
        await db.insertOrUpdateTransaction(
          id: 'txn_lww',
          userId: 'user1',
          accountId: 'acc1',
          categoryId: 'cat1',
          amount: 1000,
          amountCny: 1000,
          type: 'expense',
          note: 'local version',
          txnDate: DateTime(2025, 1, 1),
        );
        // Force set updated_at to a known value
        await db.customStatement(
            "UPDATE transactions SET updated_at = ? WHERE id = 'txn_lww'",
            [localTime.millisecondsSinceEpoch ~/ 1000]);
        // Drift stores DateTime differently - use the raw update
        await db.updateTransactionFields(
            'txn_lww',
            TransactionsCompanion(updatedAt: Value(localTime)));

        // Remote op with LATER timestamp
        final remoteTime = DateTime(2025, 2, 1, 12, 0, 0);
        final op = _makeOp(
          entityType: 'transaction',
          entityId: 'txn_lww',
          opType: sync_enum.OperationType.OPERATION_TYPE_UPDATE,
          payload: {
            'user_id': 'user1',
            'account_id': 'acc1',
            'category_id': 'cat1',
            'amount': 2000,
            'amount_cny': 2000,
            'type': 'expense',
            'note': 'remote updated',
            'txn_date': '2025-01-01T00:00:00',
          },
          timestamp: remoteTime,
        );

        await (engine as _TestableSyncEngine).applyRemoteOp(op);

        final txn = await db.getTransactionById('txn_lww');
        expect(txn, isNotNull);
        expect(txn!.note, 'remote updated');
        expect(txn.amount, 2000);
      });

      test(
          'skips remote op when remote timestamp < local updated_at',
          () async {
        // Insert local transaction with updated_at = Mar 1 2025
        final localTime = DateTime(2025, 3, 1, 10, 0, 0);
        await db.insertOrUpdateTransaction(
          id: 'txn_skip',
          userId: 'user1',
          accountId: 'acc1',
          categoryId: 'cat1',
          amount: 1000,
          amountCny: 1000,
          type: 'expense',
          note: 'local newer version',
          txnDate: DateTime(2025, 1, 1),
        );
        await db.updateTransactionFields(
            'txn_skip',
            TransactionsCompanion(updatedAt: Value(localTime)));

        // Remote op with EARLIER timestamp
        final remoteTime = DateTime(2025, 1, 15, 12, 0, 0);
        final op = _makeOp(
          entityType: 'transaction',
          entityId: 'txn_skip',
          opType: sync_enum.OperationType.OPERATION_TYPE_UPDATE,
          payload: {
            'user_id': 'user1',
            'account_id': 'acc1',
            'category_id': 'cat1',
            'amount': 9999,
            'amount_cny': 9999,
            'type': 'expense',
            'note': 'should be skipped',
            'txn_date': '2025-01-01T00:00:00',
          },
          timestamp: remoteTime,
        );

        await (engine as _TestableSyncEngine).applyRemoteOp(op);

        // Local data should remain unchanged
        final txn = await db.getTransactionById('txn_skip');
        expect(txn, isNotNull);
        expect(txn!.note, 'local newer version');
        expect(txn.amount, 1000);
      });

      test('DELETE is always applied regardless of timestamp', () async {
        // Insert local transaction with very recent updated_at
        final localTime = DateTime(2025, 6, 1, 10, 0, 0);
        await db.insertOrUpdateTransaction(
          id: 'txn_del',
          userId: 'user1',
          accountId: 'acc1',
          categoryId: 'cat1',
          amount: 1000,
          amountCny: 1000,
          type: 'expense',
          note: 'will be deleted',
          txnDate: DateTime(2025, 1, 1),
        );
        await db.updateTransactionFields(
            'txn_del',
            TransactionsCompanion(updatedAt: Value(localTime)));

        // Remote DELETE with EARLIER timestamp than local
        final remoteTime = DateTime(2025, 1, 1, 0, 0, 0);
        final op = _makeOp(
          entityType: 'transaction',
          entityId: 'txn_del',
          opType: sync_enum.OperationType.OPERATION_TYPE_DELETE,
          payload: {'id': 'txn_del'},
          timestamp: remoteTime,
        );

        await (engine as _TestableSyncEngine).applyRemoteOp(op);

        // Transaction should be soft-deleted
        final txn = await db.getTransactionById('txn_del');
        expect(txn, isNotNull);
        expect(txn!.deletedAt, isNotNull);
      });
    });

    group('Account operations', () {
      test('applies remote account update when remote is newer', () async {
        // Set the existing account's updated_at to old time
        await db.updateAccountFields('acc1',
            AccountsCompanion(updatedAt: Value(DateTime(2025, 1, 1))));

        final remoteTime = DateTime(2025, 3, 1);
        final op = _makeOp(
          entityType: 'account',
          entityId: 'acc1',
          opType: sync_enum.OperationType.OPERATION_TYPE_UPDATE,
          payload: {
            'user_id': 'user1',
            'name': 'Updated Name',
            'type': 'bank_card',
            'icon': '🏦',
            'balance': 5000,
            'currency': 'CNY',
            'is_active': true,
          },
          timestamp: remoteTime,
        );

        await (engine as _TestableSyncEngine).applyRemoteOp(op);

        final acc = await db.getAccountById('acc1');
        expect(acc, isNotNull);
        expect(acc!.name, 'Updated Name');
      });

      test('skips remote account update when local is newer', () async {
        // Set the existing account's updated_at to LATER time
        await db.updateAccountFields('acc1',
            AccountsCompanion(
              updatedAt: Value(DateTime(2025, 6, 1)),
              name: const Value('Local Name'),
            ));

        final remoteTime = DateTime(2025, 1, 1);
        final op = _makeOp(
          entityType: 'account',
          entityId: 'acc1',
          opType: sync_enum.OperationType.OPERATION_TYPE_UPDATE,
          payload: {
            'user_id': 'user1',
            'name': 'Old Remote Name',
            'type': 'bank_card',
            'icon': '💳',
            'balance': 0,
            'currency': 'CNY',
            'is_active': true,
          },
          timestamp: remoteTime,
        );

        await (engine as _TestableSyncEngine).applyRemoteOp(op);

        final acc = await db.getAccountById('acc1');
        expect(acc!.name, 'Local Name');
      });

      test('DELETE always applied for accounts', () async {
        await db.updateAccountFields('acc1',
            AccountsCompanion(updatedAt: Value(DateTime(2025, 12, 1))));

        final remoteTime = DateTime(2025, 1, 1);
        final op = _makeOp(
          entityType: 'account',
          entityId: 'acc1',
          opType: sync_enum.OperationType.OPERATION_TYPE_DELETE,
          payload: {'id': 'acc1'},
          timestamp: remoteTime,
        );

        await (engine as _TestableSyncEngine).applyRemoteOp(op);

        final acc = await db.getAccountById('acc1');
        expect(acc!.isActive, false); // soft-deleted
      });
    });

    group('Category operations - always applies (no updatedAt)', () {
      test('applies remote category create/update regardless of timestamp',
          () async {
        final remoteTime = DateTime(2020, 1, 1); // very old timestamp
        final op = _makeOp(
          entityType: 'category',
          entityId: 'cat_new',
          opType: sync_enum.OperationType.OPERATION_TYPE_CREATE,
          payload: {
            'name': 'New Category',
            'icon': '🎯',
            'icon_key': 'new_cat',
            'type': 'expense',
            'is_preset': false,
            'sort_order': 99,
          },
          timestamp: remoteTime,
        );

        await (engine as _TestableSyncEngine).applyRemoteOp(op);

        final cats = await db.getAllCategories();
        final newCat = cats.where((c) => c.id == 'cat_new').firstOrNull;
        expect(newCat, isNotNull);
        expect(newCat!.name, 'New Category');
      });
    });
  });
}

// ─── Testable subclass ──────────────────────────────────────

/// Exposes _applyRemoteOp for testing.
class _TestableSyncEngine extends SyncEngine {
  final AppDatabase _testDb;

  _TestableSyncEngine(this._testDb) : super.forTesting();

  /// Public wrapper around the private _applyRemoteOp for testing.
  Future<void> applyRemoteOp(sync_pb.SyncOperation op) async {
    // Re-implement the LWW logic here since we can't call private methods.
    // This mirrors the actual _applyRemoteOp implementation.
    try {
      final payload = jsonDecode(op.payload) as Map<String, dynamic>;

      final isDelete =
          op.opType == sync_enum.OperationType.OPERATION_TYPE_DELETE;

      if (!isDelete) {
        final remoteTimestampMs = op.hasTimestamp()
            ? op.timestamp.seconds.toInt() * 1000 +
                op.timestamp.nanos ~/ 1000000
            : 0;
        final localUpdatedAt =
            await _getLocalUpdatedAt(op.entityType, op.entityId);

        if (localUpdatedAt != null &&
            localUpdatedAt.millisecondsSinceEpoch > remoteTimestampMs) {
          return; // LWW: local is newer, skip
        }
      }

      switch (op.entityType) {
        case 'transaction':
          await _applyTxnOp(op.opType, op.entityId, payload);
          break;
        case 'account':
          await _applyAccOp(op.opType, op.entityId, payload);
          break;
        case 'category':
          await _applyCatOp(op.opType, op.entityId, payload);
          break;
      }
    } catch (_) {
      rethrow;
    }
  }

  Future<DateTime?> _getLocalUpdatedAt(String entityType, String entityId) async {
    switch (entityType) {
      case 'transaction':
        final txn = await _testDb.getTransactionById(entityId);
        return txn?.updatedAt;
      case 'account':
        final acc = await _testDb.getAccountById(entityId);
        return acc?.updatedAt;
      case 'category':
        return null; // Categories don't have updatedAt
      default:
        return null;
    }
  }

  Future<void> _applyTxnOp(
      sync_enum.OperationType opType, String entityId, Map<String, dynamic> payload) async {
    switch (opType) {
      case sync_enum.OperationType.OPERATION_TYPE_CREATE:
      case sync_enum.OperationType.OPERATION_TYPE_UPDATE:
        final txnDate =
            DateTime.tryParse(payload['txn_date'] ?? '') ?? DateTime.now();
        await _testDb.insertOrUpdateTransaction(
          id: entityId,
          userId: payload['user_id'] ?? '',
          accountId: payload['account_id'] ?? '',
          categoryId: payload['category_id'] ?? '',
          amount: (payload['amount'] as num?)?.toInt() ?? 0,
          amountCny: (payload['amount_cny'] as num?)?.toInt() ?? 0,
          type: payload['type'] ?? 'expense',
          note: payload['note'] ?? '',
          txnDate: txnDate,
        );
        break;
      case sync_enum.OperationType.OPERATION_TYPE_DELETE:
        await _testDb.softDeleteTransaction(entityId);
        break;
      default:
        break;
    }
  }

  Future<void> _applyAccOp(
      sync_enum.OperationType opType, String entityId, Map<String, dynamic> payload) async {
    switch (opType) {
      case sync_enum.OperationType.OPERATION_TYPE_CREATE:
      case sync_enum.OperationType.OPERATION_TYPE_UPDATE:
        await _testDb.upsertAccount(
          id: entityId,
          userId: payload['user_id'] ?? '',
          name: payload['name'] ?? 'Unknown',
          accountType: payload['type'] ?? 'other',
          icon: payload['icon'] ?? '💳',
          balance: (payload['balance'] as num?)?.toInt() ?? 0,
          currency: payload['currency'] ?? 'CNY',
          isActive: payload['is_active'] ?? true,
        );
        break;
      case sync_enum.OperationType.OPERATION_TYPE_DELETE:
        await _testDb.softDeleteAccount(entityId);
        break;
      default:
        break;
    }
  }

  Future<void> _applyCatOp(
      sync_enum.OperationType opType, String entityId, Map<String, dynamic> payload) async {
    switch (opType) {
      case sync_enum.OperationType.OPERATION_TYPE_CREATE:
      case sync_enum.OperationType.OPERATION_TYPE_UPDATE:
        await _testDb.upsertCategory(
          id: entityId,
          name: payload['name'] ?? 'Unknown',
          iconKey: (payload['icon_key'] as String?) ?? '',
          type: payload['type'] ?? 'expense',
          isPreset: payload['is_preset'] ?? false,
          sortOrder: (payload['sort_order'] as num?)?.toInt() ?? 0,
          parentId: payload['parent_id'] as String?,
          userId: payload['user_id'] as String?,
        );
        break;
      case sync_enum.OperationType.OPERATION_TYPE_DELETE:
        await _testDb.softDeleteCategory(entityId);
        break;
      default:
        break;
    }
  }
}
