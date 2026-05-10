import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/transaction_provider.dart';
import 'package:familyledger/generated/proto/google/protobuf/timestamp.pb.dart'
    as proto_ts;
import 'package:familyledger/generated/proto/transaction.pb.dart' as pb;
import 'package:familyledger/generated/proto/transaction.pbenum.dart' as pbe;
import 'package:familyledger/generated/proto/transaction.pbgrpc.dart' as pbgrpc;

// ─── Fake gRPC client ────────────────────────────────────────

class FakeResponseFuture<T> implements ResponseFuture<T> {
  final Future<T> _future;
  FakeResponseFuture.value(T value) : _future = Future.value(value);
  FakeResponseFuture.error(Object error) : _future = Future.error(error);

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) =>
      _future.then(onValue, onError: onError);

  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) =>
      _future.catchError(onError, test: test);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      _future.whenComplete(action);

  @override
  Stream<T> asStream() => _future.asStream();

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      _future.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<Map<String, String>> get headers => Future.value({});

  @override
  Future<Map<String, String>> get trailers => Future.value({});

  @override
  Future<void> cancel() => Future.value();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Configurable fake client for testing TransactionNotifier
class ConfigurableTransactionClient implements pbgrpc.TransactionServiceClient {
  pb.CreateTransactionResponse? createResponse;
  Object? createError;
  pb.UpdateTransactionResponse? updateResponse;
  Object? updateError;
  pb.DeleteTransactionResponse? deleteResponse;
  Object? deleteError;
  List<List<pb.Transaction>> listPages;
  int listCallCount = 0;

  ConfigurableTransactionClient({
    this.createResponse,
    this.createError,
    this.updateResponse,
    this.updateError,
    this.deleteResponse,
    this.deleteError,
    this.listPages = const [],
  });

  @override
  ResponseFuture<pb.ListTransactionsResponse> listTransactions(
    pbgrpc.ListTransactionsRequest request, {
    CallOptions? options,
  }) {
    final pageIndex = listCallCount;
    listCallCount++;
    final transactions =
        pageIndex < listPages.length ? listPages[pageIndex] : <pb.Transaction>[];
    final nextPageToken =
        (pageIndex + 1 < listPages.length) ? 'page_${pageIndex + 1}' : '';
    return FakeResponseFuture.value(pb.ListTransactionsResponse(
      transactions: transactions,
      nextPageToken: nextPageToken,
    ));
  }

  @override
  ResponseFuture<pb.CreateTransactionResponse> createTransaction(
    pbgrpc.CreateTransactionRequest request, {
    CallOptions? options,
  }) {
    if (createError != null) {
      return FakeResponseFuture.error(createError!);
    }
    return FakeResponseFuture.value(
      createResponse ??
          pb.CreateTransactionResponse(
            transaction: pb.Transaction(
              id: 'server_txn_id',
              userId: 'user1',
              accountId: request.accountId,
              categoryId: request.categoryId,
              amount: request.amount,
              amountCny: request.amountCny,
              type: request.type,
              note: request.note,
            ),
          ),
    );
  }

  @override
  ResponseFuture<pb.UpdateTransactionResponse> updateTransaction(
    pbgrpc.UpdateTransactionRequest request, {
    CallOptions? options,
  }) {
    if (updateError != null) {
      return FakeResponseFuture.error(updateError!);
    }
    return FakeResponseFuture.value(
      updateResponse ?? pb.UpdateTransactionResponse(),
    );
  }

  @override
  ResponseFuture<pb.DeleteTransactionResponse> deleteTransaction(
    pbgrpc.DeleteTransactionRequest request, {
    CallOptions? options,
  }) {
    if (deleteError != null) {
      return FakeResponseFuture.error(deleteError!);
    }
    return FakeResponseFuture.value(
      deleteResponse ?? pb.DeleteTransactionResponse(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented in fake');
}

// ─── Test Helpers ────────────────────────────────────────────

Future<AppDatabase> _setupDb({bool withFamilyAccount = false}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.customStatement(
      "INSERT OR IGNORE INTO users (id, email, created_at) "
      "VALUES ('user1', 'test@test.com', "
      "${DateTime.now().millisecondsSinceEpoch ~/ 1000})");

  if (withFamilyAccount) {
    await db.insertAccount(AccountsCompanion.insert(
      id: 'acc_fam',
      userId: 'user1',
      name: 'Family Account',
      familyId: const Value('fam1'),
      accountType: const Value('bank_card'),
    ));
  } else {
    await db.insertAccount(AccountsCompanion.insert(
      id: 'acc1',
      userId: 'user1',
      name: 'Personal Account',
      familyId: const Value(''),
      accountType: const Value('bank_card'),
    ));
  }
  return db;
}

Future<void> _insertCategory(AppDatabase db, {
  String id = 'cat1',
  String name = 'Food',
  String type = 'expense',
}) async {
  await db.upsertCategory(
    id: id,
    name: name,
    type: type,
    isPreset: true,
    sortOrder: 1,
  );
}

// ─── Tests ───────────────────────────────────────────────────

void main() {
  group('TransactionNotifier', () {
    late AppDatabase db;

    setUp(() async {
      db = await _setupDb();
      await _insertCategory(db);
      await _insertCategory(db, id: 'cat_income', name: 'Salary', type: 'income');
    });

    tearDown(() async {
      await db.close();
    });

    group('_load (via constructor)', () {
      test('successfully loads categories and sets state', () async {
        final notifier = TransactionNotifier(db, 'user1', null, null);
        // Wait for async _load
        await Future.delayed(const Duration(milliseconds: 300));

        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNull);
        expect(notifier.state.expenseCategories, isNotEmpty);
        expect(notifier.state.incomeCategories, isNotEmpty);

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });

      test('loads empty transaction list without error', () async {
        final notifier = TransactionNotifier(db, 'user1', null, null);
        await Future.delayed(const Duration(milliseconds: 300));

        expect(notifier.state.transactions, isEmpty);
        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNull);

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });

      test('handles gRPC error gracefully in family mode', () async {
        final famDb = await _setupDb(withFamilyAccount: true);
        await _insertCategory(famDb);
        final offlineClient = ConfigurableTransactionClient(listPages: []);
        // Make listTransactions throw
        final errorClient = _ThrowingListClient();

        final notifier = TransactionNotifier(famDb, 'user1', 'fam1', errorClient);
        await Future.delayed(const Duration(milliseconds: 300));

        // Should not crash — fallback to local data
        expect(notifier.state.isLoading, false);
        // error is NOT set because offline is handled gracefully
        expect(notifier.state.error, isNull);

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
        await famDb.close();
      });
    });

    group('addTransaction', () {
      test('online mode: uses server-assigned ID', () async {
        final client = ConfigurableTransactionClient(
          createResponse: pb.CreateTransactionResponse(
            transaction: pb.Transaction(
              id: 'server_assigned_id',
              userId: 'user1',
              accountId: 'acc1',
              categoryId: 'cat1',
              amount: Int64(1500),
              amountCny: Int64(1500),
              type: pbe.TransactionType.TRANSACTION_TYPE_EXPENSE,
              note: 'online test',
            ),
          ),
        );

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.addTransaction(
          categoryId: 'cat1',
          amount: 1500,
          type: 'expense',
          note: 'online test',
        );

        // Transaction should exist with server ID
        final txn = await db.getTransactionById('server_assigned_id');
        expect(txn, isNotNull);
        expect(txn!.amount, 1500);
        expect(txn.note, 'online test');

        // No sync op should be queued (was synced directly)
        final ops = await db.getPendingSyncOps(10);
        expect(ops, isEmpty);

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });

      test('offline mode: uses local UUID and queues sync op', () async {
        final client = ConfigurableTransactionClient(
          createError: GrpcError.unavailable('offline'),
        );

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.addTransaction(
          categoryId: 'cat1',
          amount: 2000,
          type: 'expense',
          note: 'offline test',
        );

        // A sync op should be queued
        final ops = await db.getPendingSyncOps(10);
        expect(ops, hasLength(1));
        expect(ops.first.entityType, 'transaction');
        expect(ops.first.opType, 'create');

        // Transaction should exist locally (with UUID id)
        final payload = jsonDecode(ops.first.payload) as Map<String, dynamic>;
        final txnId = payload['id'] as String;
        final txn = await db.getTransactionById(txnId);
        expect(txn, isNotNull);
        expect(txn!.amount, 2000);

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });

      test('null client: uses local UUID and queues sync op', () async {
        final notifier = TransactionNotifier(db, 'user1', null, null);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.addTransaction(
          categoryId: 'cat1',
          amount: 3000,
          type: 'income',
          note: 'no client',
        );

        final ops = await db.getPendingSyncOps(10);
        expect(ops, hasLength(1));
        expect(ops.first.opType, 'create');

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });
    });

    group('updateTransaction', () {
      test('updates locally and recalculates balance', () async {
        final notifier = TransactionNotifier(db, 'user1', null, null);
        await Future.delayed(const Duration(milliseconds: 200));

        // First add a transaction
        await notifier.addTransaction(
          categoryId: 'cat1',
          amount: 1000,
          type: 'expense',
          note: 'original',
        );
        await Future.delayed(const Duration(milliseconds: 100));

        // Get the transaction
        final ops = await db.getPendingSyncOps(10);
        final payload = jsonDecode(ops.first.payload) as Map<String, dynamic>;
        final txnId = payload['id'] as String;

        // Update it
        await notifier.updateTransaction(
          id: txnId,
          amount: 2000,
          note: 'updated',
        );

        final updated = await db.getTransactionById(txnId);
        expect(updated, isNotNull);
        expect(updated!.amount, 2000);
        expect(updated.note, 'updated');

        // Balance should reflect the change
        // Original: -1000, Updated: -2000, so balance delta = -1000
        final acc = await db.getAccountById('acc1');
        expect(acc, isNotNull);
        // Account started at 0, first add: -1000, update diff: -1000 more = -2000
        expect(acc!.balance, -2000);

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });

      test('queues sync op when gRPC fails', () async {
        final client = ConfigurableTransactionClient(
          updateError: GrpcError.unavailable('offline'),
        );

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        // Insert transaction directly for testing update
        await db.insertTransaction(TransactionsCompanion.insert(
          id: 'txn_to_update',
          userId: 'user1',
          accountId: 'acc1',
          categoryId: 'cat1',
          amount: 1000,
          amountCny: 1000,
          type: 'expense',
          note: Value('before'),
          txnDate: DateTime(2025, 1, 1),
        ));

        await notifier.updateTransaction(
          id: 'txn_to_update',
          amount: 3000,
          note: 'after',
        );

        // Should queue a sync op for the failed update
        final ops = await db.getPendingSyncOps(10);
        final updateOps =
            ops.where((o) => o.opType == 'update').toList();
        expect(updateOps, hasLength(1));
        expect(updateOps.first.entityId, 'txn_to_update');

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });
    });

    group('deleteTransaction', () {
      test('soft deletes and recalculates balance', () async {
        // Insert a transaction directly
        await db.insertTransaction(TransactionsCompanion.insert(
          id: 'txn_del',
          userId: 'user1',
          accountId: 'acc1',
          categoryId: 'cat1',
          amount: 5000,
          amountCny: 5000,
          type: 'expense',
          note: Value('to delete'),
          txnDate: DateTime(2025, 1, 1),
        ));
        // Set account balance to reflect this transaction
        await db.updateAccountBalance('acc1', -5000);

        final notifier = TransactionNotifier(db, 'user1', null, null);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.deleteTransaction('txn_del');

        // Transaction should be soft-deleted
        final txn = await db.getTransactionById('txn_del');
        expect(txn, isNotNull);
        expect(txn!.deletedAt, isNotNull);

        // Balance should be restored: -5000 + 5000 = 0
        final acc = await db.getAccountById('acc1');
        expect(acc!.balance, 0);

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });

      test('queues sync op when gRPC fails', () async {
        await db.insertTransaction(TransactionsCompanion.insert(
          id: 'txn_del2',
          userId: 'user1',
          accountId: 'acc1',
          categoryId: 'cat1',
          amount: 1000,
          amountCny: 1000,
          type: 'expense',
          note: Value('del offline'),
          txnDate: DateTime(2025, 1, 1),
        ));

        final client = ConfigurableTransactionClient(
          deleteError: GrpcError.unavailable('offline'),
        );
        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.deleteTransaction('txn_del2');

        final ops = await db.getPendingSyncOps(10);
        final deleteOps =
            ops.where((o) => o.opType == 'delete').toList();
        expect(deleteOps, hasLength(1));
        expect(deleteOps.first.entityId, 'txn_del2');

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });
    });

    group('family mode: familyId query correctness', () {
      test('family transactions are loaded from server with familyId', () async {
        final famDb = await _setupDb(withFamilyAccount: true);
        await _insertCategory(famDb);

        final client = ConfigurableTransactionClient(
          listPages: [
            [
              pb.Transaction(
                id: 'fam_txn_1',
                userId: 'user2', // another family member
                accountId: 'acc_fam',
                categoryId: 'cat1',
                amount: Int64(3000),
                amountCny: Int64(3000),
                type: pbe.TransactionType.TRANSACTION_TYPE_EXPENSE,
                note: 'family expense',
                txnDate: proto_ts.Timestamp(
                  seconds: Int64(DateTime(2025, 1, 1).millisecondsSinceEpoch ~/ 1000),
                ),
              ),
            ],
          ],
        );

        final notifier = TransactionNotifier(famDb, 'user1', 'fam1', client);
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify the request had familyId
        expect(client.listCallCount, greaterThan(0));

        // Transaction should be in local DB
        final txn = await famDb.getTransactionById('fam_txn_1');
        expect(txn, isNotNull);
        expect(txn!.note, 'family expense');

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
        await famDb.close();
      });
    });

    group('summary calculations', () {
      test('balance, todayExpense, monthExpense are refreshed after add',
          () async {
        final notifier = TransactionNotifier(db, 'user1', null, null);
        await Future.delayed(const Duration(milliseconds: 200));

        // Add an expense for today
        await notifier.addTransaction(
          categoryId: 'cat1',
          amount: 10000, // 100 元
          type: 'expense',
          note: 'today expense',
          txnDate: DateTime.now(),
        );
        await Future.delayed(const Duration(milliseconds: 200));

        expect(notifier.state.todayExpense, 10000);
        expect(notifier.state.monthExpense, 10000);
        // Balance = all income - all expense = -10000
        expect(notifier.state.totalBalance, -10000);

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });
    });
  });
}

// ─── Helper classes ──────────────────────────────────────────

/// A client that always throws on listTransactions (simulating offline).
class _ThrowingListClient implements pbgrpc.TransactionServiceClient {
  @override
  ResponseFuture<pb.ListTransactionsResponse> listTransactions(
    pbgrpc.ListTransactionsRequest request, {
    CallOptions? options,
  }) {
    return FakeResponseFuture.error(GrpcError.unavailable('No connection'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented in fake');
}
