@Timeout(Duration(seconds: 30))
library;

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/transaction_provider.dart';
import 'package:familyledger/domain/providers/family_provider.dart';
import 'package:familyledger/generated/proto/transaction.pb.dart' as pb;
import 'package:familyledger/generated/proto/transaction.pbenum.dart' as pbe;
import 'package:familyledger/generated/proto/transaction.pbgrpc.dart' as pbgrpc;
import 'package:familyledger/generated/proto/family.pb.dart' as pb_model;
import 'package:familyledger/generated/proto/family.pbgrpc.dart'
    as pb_family_grpc;
import 'package:familyledger/generated/proto/sync.pb.dart' as sync_pb;
import 'package:familyledger/generated/proto/sync.pbgrpc.dart';
import 'package:familyledger/sync/sync_engine.dart';

// ─── Fake gRPC ResponseFuture ────────────────────────────────

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

// ─── Fake TransactionServiceClient ───────────────────────────

class FakeTransactionClient implements pbgrpc.TransactionServiceClient {
  Object? createError;
  Object? updateError;
  Object? deleteError;
  Object? listError;

  @override
  ResponseFuture<pb.ListTransactionsResponse> listTransactions(
    pbgrpc.ListTransactionsRequest request, {
    CallOptions? options,
  }) {
    if (listError != null) return FakeResponseFuture.error(listError!);
    return FakeResponseFuture.value(
        pb.ListTransactionsResponse(transactions: [], nextPageToken: ''));
  }

  @override
  ResponseFuture<pb.CreateTransactionResponse> createTransaction(
    pbgrpc.CreateTransactionRequest request, {
    CallOptions? options,
  }) {
    if (createError != null) return FakeResponseFuture.error(createError!);
    return FakeResponseFuture.value(pb.CreateTransactionResponse(
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
    ));
  }

  @override
  ResponseFuture<pb.UpdateTransactionResponse> updateTransaction(
    pbgrpc.UpdateTransactionRequest request, {
    CallOptions? options,
  }) {
    if (updateError != null) return FakeResponseFuture.error(updateError!);
    return FakeResponseFuture.value(pb.UpdateTransactionResponse());
  }

  @override
  ResponseFuture<pb.DeleteTransactionResponse> deleteTransaction(
    pbgrpc.DeleteTransactionRequest request, {
    CallOptions? options,
  }) {
    if (deleteError != null) return FakeResponseFuture.error(deleteError!);
    return FakeResponseFuture.value(pb.DeleteTransactionResponse());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented in fake');
}

// ─── Fake FamilyServiceClient ────────────────────────────────

class FakeFamilyClient implements pb_family_grpc.FamilyServiceClient {
  Object? joinError;
  Object? leaveError;
  Object? createError;

  @override
  ResponseFuture<pb_model.CreateFamilyResponse> createFamily(
      pb_model.CreateFamilyRequest request,
      {CallOptions? options}) {
    if (createError != null) return FakeResponseFuture.error(createError!);
    return FakeResponseFuture.value(pb_model.CreateFamilyResponse(
      family: pb_model.Family(
        id: 'server_fam_1',
        name: request.name,
        ownerId: 'user1',
      ),
    ));
  }

  @override
  ResponseFuture<pb_model.JoinFamilyResponse> joinFamily(
      pb_model.JoinFamilyRequest request,
      {CallOptions? options}) {
    if (joinError != null) return FakeResponseFuture.error(joinError!);
    return FakeResponseFuture.value(pb_model.JoinFamilyResponse(
      family: pb_model.Family(
        id: 'joined_fam',
        name: 'Test Family',
        ownerId: 'owner1',
      ),
    ));
  }

  @override
  ResponseFuture<pb_model.LeaveFamilyResponse> leaveFamily(
      pb_model.LeaveFamilyRequest request,
      {CallOptions? options}) {
    if (leaveError != null) return FakeResponseFuture.error(leaveError!);
    return FakeResponseFuture.value(pb_model.LeaveFamilyResponse());
  }

  @override
  ResponseFuture<pb_model.ListFamilyMembersResponse> listFamilyMembers(
      pb_model.ListFamilyMembersRequest request,
      {CallOptions? options}) {
    return FakeResponseFuture.value(pb_model.ListFamilyMembersResponse());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not implemented');
}

// ─── Fake SyncServiceClient ──────────────────────────────────

class FakeSyncClient implements SyncServiceClient {
  Object? pushError;

  @override
  ResponseFuture<sync_pb.PushOperationsResponse> pushOperations(
      sync_pb.PushOperationsRequest request,
      {CallOptions? options}) {
    if (pushError != null) return FakeResponseFuture.error(pushError!);
    return FakeResponseFuture.value(sync_pb.PushOperationsResponse());
  }

  @override
  ResponseFuture<sync_pb.PullChangesResponse> pullChanges(
      sync_pb.PullChangesRequest request,
      {CallOptions? options}) {
    return FakeResponseFuture.value(sync_pb.PullChangesResponse());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not implemented');
}

// ─── Mock Connectivity ───────────────────────────────────────

class MockConnectivity extends Mock implements Connectivity {}

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

  // Insert default categories
  await db.upsertCategory(
    id: 'cat1',
    name: 'Food',
    type: 'expense',
    isPreset: true,
    sortOrder: 1,
  );
  await db.upsertCategory(
    id: 'cat_income',
    name: 'Salary',
    type: 'income',
    isPreset: true,
    sortOrder: 1,
  );

  return db;
}

Future<AppDatabase> _setupDbWithFamily() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.customStatement(
      "INSERT OR IGNORE INTO users (id, email, created_at) "
      "VALUES ('user1', 'test@test.com', "
      "${DateTime.now().millisecondsSinceEpoch ~/ 1000})");
  await db.insertFamily(FamiliesCompanion.insert(
    id: 'existing_family',
    name: '测试家庭',
    ownerId: 'other_owner',
  ));
  await db.insertFamilyMember(FamilyMembersCompanion.insert(
    id: 'member_1',
    familyId: 'existing_family',
    userId: 'user1',
    role: const Value('member'),
    canView: const Value(true),
    canCreate: const Value(true),
    canEdit: const Value(false),
    canDelete: const Value(false),
  ));
  return db;
}

// ─── Tests ───────────────────────────────────────────────────

void main() {
  group('gRPC Error Code Handling', () {
    // ═══════════════════════════════════════════════════════════
    // NOTE ON ERROR HANDLING ARCHITECTURE:
    //
    // After reading the business code, ALL gRPC errors in TransactionNotifier
    // (addTransaction, updateTransaction, deleteTransaction) are handled via
    // generic catch-all blocks. There is NO error-code-specific branching:
    //
    //   - addTransaction: catch(e) → fallback to local UUID + queue sync op
    //   - updateTransaction: catch(e) → queue sync op
    //   - deleteTransaction: catch(e) → queue sync op
    //   - _load (family): catch(_) → continue with local data
    //
    // FamilyNotifier.joinFamily DOES propagate the error message to UI via
    // state.error, but doesn't differentiate by error code either.
    //
    // SyncEngine._pushPendingOps: catch(e) → logs, doesn't crash
    //
    // These tests verify the ACTUAL behavior (uniform catch-all), and document
    // that all error codes get the same treatment. If future code adds
    // error-code-specific handling, these tests will need to be updated.
    // ═══════════════════════════════════════════════════════════

    group('TransactionNotifier.addTransaction — error code coverage', () {
      late AppDatabase db;

      setUp(() async {
        db = await _setupDb();
      });

      tearDown(() async {
        await db.close();
      });

      test('Unauthenticated (code 16): falls back to local + queues sync op',
          () async {
        // Behavior: identical to Unavailable — generic catch-all, no special handling
        final client = FakeTransactionClient()
          ..createError = GrpcError.unauthenticated('token expired');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.addTransaction(
          categoryId: 'cat1',
          amount: 1000,
          type: 'expense',
          note: 'unauthenticated test',
        );

        // Should not crash, transaction created locally
        final ops = await db.getPendingSyncOps(10);
        expect(ops, hasLength(1));
        expect(ops.first.opType, 'create');

        final payload = jsonDecode(ops.first.payload) as Map<String, dynamic>;
        final txn = await db.getTransactionById(payload['id'] as String);
        expect(txn, isNotNull);
        expect(txn!.amount, 1000);
        // No error state set on TransactionNotifier for add failures
        // (error is silently caught and local fallback used)
        expect(notifier.state.error, isNull);

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });

      test('PermissionDenied (code 7): falls back to local + queues sync op',
          () async {
        // NOTE: Current architecture doesn't distinguish PermissionDenied.
        // A future improvement might reject the operation and show error to user.
        final client = FakeTransactionClient()
          ..createError = GrpcError.permissionDenied('no access');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.addTransaction(
          categoryId: 'cat1',
          amount: 2000,
          type: 'expense',
          note: 'permission denied test',
        );

        // Treated same as offline — local fallback
        final ops = await db.getPendingSyncOps(10);
        expect(ops, hasLength(1));
        expect(ops.first.opType, 'create');
        expect(notifier.state.error, isNull);

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });

      test('DeadlineExceeded (code 4): falls back to local + queues sync op',
          () async {
        // DeadlineExceeded is a timeout — same behavior as Unavailable
        final client = FakeTransactionClient()
          ..createError = GrpcError.deadlineExceeded('timeout');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.addTransaction(
          categoryId: 'cat1',
          amount: 3000,
          type: 'expense',
          note: 'deadline exceeded test',
        );

        final ops = await db.getPendingSyncOps(10);
        expect(ops, hasLength(1));
        expect(ops.first.opType, 'create');
        expect(notifier.state.error, isNull);

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });

      test('Internal (code 13): falls back to local + queues sync op',
          () async {
        final client = FakeTransactionClient()
          ..createError = GrpcError.internal('server crash');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.addTransaction(
          categoryId: 'cat1',
          amount: 4000,
          type: 'expense',
          note: 'internal error test',
        );

        final ops = await db.getPendingSyncOps(10);
        expect(ops, hasLength(1));
        expect(ops.first.opType, 'create');
        expect(notifier.state.error, isNull);

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });

      test('InvalidArgument (code 3): falls back to local + queues sync op',
          () async {
        // NOTE: Ideally, InvalidArgument should NOT silently fall back,
        // because the data is bad and syncing later will also fail.
        // Current code treats it the same as other errors.
        final client = FakeTransactionClient()
          ..createError = GrpcError.invalidArgument('invalid category_id');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.addTransaction(
          categoryId: 'cat1',
          amount: 500,
          type: 'expense',
          note: 'invalid argument test',
        );

        final ops = await db.getPendingSyncOps(10);
        expect(ops, hasLength(1));
        expect(ops.first.opType, 'create');
        expect(notifier.state.error, isNull);

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });

      test('NotFound (code 5): falls back to local + queues sync op',
          () async {
        final client = FakeTransactionClient()
          ..createError = GrpcError.notFound('account not found');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.addTransaction(
          categoryId: 'cat1',
          amount: 600,
          type: 'expense',
          note: 'not found test',
        );

        final ops = await db.getPendingSyncOps(10);
        expect(ops, hasLength(1));
        expect(notifier.state.error, isNull);

        await Future.delayed(const Duration(milliseconds: 300));
        notifier.dispose();
      });
    });

    group('TransactionNotifier.updateTransaction — error code coverage', () {
      late AppDatabase db;

      setUp(() async {
        db = await _setupDb();
        // Pre-insert a transaction for update tests
        await db.insertTransaction(TransactionsCompanion.insert(
          id: 'txn_update_test',
          userId: 'user1',
          accountId: 'acc1',
          categoryId: 'cat1',
          amount: 1000,
          amountCny: 1000,
          type: 'expense',
          note: Value('original'),
          txnDate: DateTime(2025, 6, 1),
        ));
      });

      tearDown(() async {
        await db.close();
      });

      test('Unauthenticated (code 16): updates locally + queues sync op',
          () async {
        final client = FakeTransactionClient()
          ..updateError = GrpcError.unauthenticated('token expired');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.updateTransaction(
          id: 'txn_update_test',
          amount: 2000,
          note: 'updated with auth error',
        );

        // Local update should succeed
        final txn = await db.getTransactionById('txn_update_test');
        expect(txn!.amount, 2000);
        expect(txn.note, 'updated with auth error');

        // Sync op queued
        final ops = await db.getPendingSyncOps(10);
        final updateOps = ops.where((o) => o.opType == 'update').toList();
        expect(updateOps, hasLength(1));
        expect(updateOps.first.entityId, 'txn_update_test');

        notifier.dispose();
      });

      test('PermissionDenied (code 7): updates locally + queues sync op',
          () async {
        // NOTE: Current behavior allows local update even if server denies permission.
        // The sync op will likely fail again when retried.
        final client = FakeTransactionClient()
          ..updateError = GrpcError.permissionDenied('not allowed');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.updateTransaction(
          id: 'txn_update_test',
          note: 'permission denied update',
        );

        final txn = await db.getTransactionById('txn_update_test');
        expect(txn!.note, 'permission denied update');

        final ops = await db.getPendingSyncOps(10);
        expect(ops.where((o) => o.opType == 'update'), hasLength(1));

        notifier.dispose();
      });

      test('DeadlineExceeded (code 4): updates locally + queues sync op',
          () async {
        final client = FakeTransactionClient()
          ..updateError = GrpcError.deadlineExceeded('timeout');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.updateTransaction(
          id: 'txn_update_test',
          amount: 5000,
        );

        final txn = await db.getTransactionById('txn_update_test');
        expect(txn!.amount, 5000);

        final ops = await db.getPendingSyncOps(10);
        expect(ops.where((o) => o.opType == 'update'), hasLength(1));

        notifier.dispose();
      });

      test('NotFound (code 5): updates locally + queues sync op', () async {
        // NOTE: NotFound on update means server doesn't have this record.
        // Could mean it was deleted on another device. Current code doesn't
        // handle this specially — it still updates locally and queues.
        final client = FakeTransactionClient()
          ..updateError = GrpcError.notFound('transaction not found on server');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.updateTransaction(
          id: 'txn_update_test',
          note: 'update on deleted server record',
        );

        final txn = await db.getTransactionById('txn_update_test');
        expect(txn!.note, 'update on deleted server record');

        final ops = await db.getPendingSyncOps(10);
        expect(ops.where((o) => o.opType == 'update'), hasLength(1));

        notifier.dispose();
      });

      test('Internal (code 13): updates locally + queues sync op', () async {
        final client = FakeTransactionClient()
          ..updateError = GrpcError.internal('500 error');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.updateTransaction(
          id: 'txn_update_test',
          amount: 9999,
        );

        final txn = await db.getTransactionById('txn_update_test');
        expect(txn!.amount, 9999);

        final ops = await db.getPendingSyncOps(10);
        expect(ops.where((o) => o.opType == 'update'), hasLength(1));

        notifier.dispose();
      });

      test('InvalidArgument (code 3): updates locally + queues sync op',
          () async {
        final client = FakeTransactionClient()
          ..updateError = GrpcError.invalidArgument('bad data');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.updateTransaction(
          id: 'txn_update_test',
          note: 'invalid arg update',
        );

        final txn = await db.getTransactionById('txn_update_test');
        expect(txn!.note, 'invalid arg update');

        final ops = await db.getPendingSyncOps(10);
        expect(ops.where((o) => o.opType == 'update'), hasLength(1));

        notifier.dispose();
      });
    });

    group('TransactionNotifier.deleteTransaction — error code coverage', () {
      late AppDatabase db;

      setUp(() async {
        db = await _setupDb();
        await db.insertTransaction(TransactionsCompanion.insert(
          id: 'txn_del_test',
          userId: 'user1',
          accountId: 'acc1',
          categoryId: 'cat1',
          amount: 3000,
          amountCny: 3000,
          type: 'expense',
          note: Value('to delete'),
          txnDate: DateTime(2025, 6, 1),
        ));
        await db.updateAccountBalance('acc1', -3000);
      });

      tearDown(() async {
        await db.close();
      });

      test('Unauthenticated (code 16): deletes locally + queues sync op',
          () async {
        final client = FakeTransactionClient()
          ..deleteError = GrpcError.unauthenticated('token expired');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.deleteTransaction('txn_del_test');

        final txn = await db.getTransactionById('txn_del_test');
        expect(txn!.deletedAt, isNotNull);

        final acc = await db.getAccountById('acc1');
        expect(acc!.balance, 0); // restored

        final ops = await db.getPendingSyncOps(10);
        expect(ops.where((o) => o.opType == 'delete'), hasLength(1));

        notifier.dispose();
      });

      test('PermissionDenied (code 7): deletes locally + queues sync op',
          () async {
        final client = FakeTransactionClient()
          ..deleteError = GrpcError.permissionDenied('no permission');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.deleteTransaction('txn_del_test');

        final txn = await db.getTransactionById('txn_del_test');
        expect(txn!.deletedAt, isNotNull);

        final ops = await db.getPendingSyncOps(10);
        expect(ops.where((o) => o.opType == 'delete'), hasLength(1));

        notifier.dispose();
      });

      test('DeadlineExceeded (code 4): deletes locally + queues sync op',
          () async {
        final client = FakeTransactionClient()
          ..deleteError = GrpcError.deadlineExceeded('timeout');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.deleteTransaction('txn_del_test');

        final txn = await db.getTransactionById('txn_del_test');
        expect(txn!.deletedAt, isNotNull);

        final ops = await db.getPendingSyncOps(10);
        expect(ops.where((o) => o.opType == 'delete'), hasLength(1));

        notifier.dispose();
      });

      test('NotFound (code 5): deletes locally + queues sync op', () async {
        // Server says not found — item may already be deleted remotely.
        // Current code still queues a delete sync op (harmless on retry).
        final client = FakeTransactionClient()
          ..deleteError = GrpcError.notFound('already deleted');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.deleteTransaction('txn_del_test');

        final txn = await db.getTransactionById('txn_del_test');
        expect(txn!.deletedAt, isNotNull);

        final ops = await db.getPendingSyncOps(10);
        expect(ops.where((o) => o.opType == 'delete'), hasLength(1));

        notifier.dispose();
      });

      test('Internal (code 13): deletes locally + queues sync op', () async {
        final client = FakeTransactionClient()
          ..deleteError = GrpcError.internal('server error');

        final notifier = TransactionNotifier(db, 'user1', null, client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.deleteTransaction('txn_del_test');

        final txn = await db.getTransactionById('txn_del_test');
        expect(txn!.deletedAt, isNotNull);

        final ops = await db.getPendingSyncOps(10);
        expect(ops.where((o) => o.opType == 'delete'), hasLength(1));

        notifier.dispose();
      });
    });

    group('TransactionNotifier._load (family mode) — error code coverage', () {
      test('Unauthenticated on listTransactions: loads local data without crash',
          () async {
        final db = await _setupDb(withFamilyAccount: true);
        final client = FakeTransactionClient()
          ..listError = GrpcError.unauthenticated('expired');

        final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
        await Future.delayed(const Duration(milliseconds: 300));

        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNull);
        expect(notifier.state.expenseCategories, isNotEmpty);

        notifier.dispose();
        await db.close();
      });

      test('PermissionDenied on listTransactions: loads local data without crash',
          () async {
        final db = await _setupDb(withFamilyAccount: true);
        final client = FakeTransactionClient()
          ..listError = GrpcError.permissionDenied('not a family member');

        final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
        await Future.delayed(const Duration(milliseconds: 300));

        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNull);

        notifier.dispose();
        await db.close();
      });

      test('DeadlineExceeded on listTransactions: loads local data without crash',
          () async {
        final db = await _setupDb(withFamilyAccount: true);
        final client = FakeTransactionClient()
          ..listError = GrpcError.deadlineExceeded('slow network');

        final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
        await Future.delayed(const Duration(milliseconds: 300));

        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNull);

        notifier.dispose();
        await db.close();
      });

      test('Internal on listTransactions: loads local data without crash',
          () async {
        final db = await _setupDb(withFamilyAccount: true);
        final client = FakeTransactionClient()
          ..listError = GrpcError.internal('server panic');

        final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
        await Future.delayed(const Duration(milliseconds: 300));

        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNull);

        notifier.dispose();
        await db.close();
      });
    });

    group('FamilyNotifier.joinFamily — error code coverage', () {
      test('Unauthenticated (code 16): sets error state', () async {
        final db = await _setupDb();
        final client = FakeFamilyClient()
          ..joinError = GrpcError.unauthenticated('session expired');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 100));

        final result = await notifier.joinFamily('CODE123');

        expect(result, isNull);
        expect(notifier.state.error, isNotNull);
        expect(notifier.state.error, contains('加入家庭失败'));
        expect(notifier.state.isLoading, false);

        notifier.dispose();
        await db.close();
      });

      test('PermissionDenied (code 7): sets error state', () async {
        final db = await _setupDb();
        final client = FakeFamilyClient()
          ..joinError = GrpcError.permissionDenied('invite code expired');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 100));

        final result = await notifier.joinFamily('EXPIRED');

        expect(result, isNull);
        expect(notifier.state.error, isNotNull);
        expect(notifier.state.error, contains('加入家庭失败'));
        expect(notifier.state.isLoading, false);

        notifier.dispose();
        await db.close();
      });

      test('DeadlineExceeded (code 4): sets error state', () async {
        final db = await _setupDb();
        final client = FakeFamilyClient()
          ..joinError = GrpcError.deadlineExceeded('timeout');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 100));

        final result = await notifier.joinFamily('SLOW');

        expect(result, isNull);
        expect(notifier.state.error, isNotNull);
        expect(notifier.state.error, contains('加入家庭失败'));

        notifier.dispose();
        await db.close();
      });

      test('NotFound (code 5): sets error state', () async {
        final db = await _setupDb();
        final client = FakeFamilyClient()
          ..joinError = GrpcError.notFound('family does not exist');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 100));

        final result = await notifier.joinFamily('INVALID');

        expect(result, isNull);
        expect(notifier.state.error, contains('加入家庭失败'));

        notifier.dispose();
        await db.close();
      });

      test('Internal (code 13): sets error state', () async {
        final db = await _setupDb();
        final client = FakeFamilyClient()
          ..joinError = GrpcError.internal('database error');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 100));

        final result = await notifier.joinFamily('CODE');

        expect(result, isNull);
        expect(notifier.state.error, contains('加入家庭失败'));

        notifier.dispose();
        await db.close();
      });

      test('InvalidArgument (code 3): sets error state', () async {
        final db = await _setupDb();
        final client = FakeFamilyClient()
          ..joinError = GrpcError.invalidArgument('invite code format invalid');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 100));

        final result = await notifier.joinFamily('!!!');

        expect(result, isNull);
        expect(notifier.state.error, contains('加入家庭失败'));

        notifier.dispose();
        await db.close();
      });
    });

    group('FamilyNotifier.leaveFamily — error code coverage', () {
      test('Unauthenticated (code 16): sets error, does not remove locally',
          () async {
        final db = await _setupDbWithFamily();
        final client = FakeFamilyClient()
          ..leaveError = GrpcError.unauthenticated('re-login required');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.leaveFamily();
        await Future.delayed(const Duration(milliseconds: 100));

        expect(notifier.state.error, contains('退出家庭失败'));
        // Member not removed from local DB
        final members = await db.getFamilyMembers('existing_family');
        expect(members.where((m) => m.userId == 'user1'), isNotEmpty);

        notifier.dispose();
        await db.close();
      });

      test('PermissionDenied (code 7): sets error, does not remove locally',
          () async {
        final db = await _setupDbWithFamily();
        final client = FakeFamilyClient()
          ..leaveError = GrpcError.permissionDenied('cannot leave');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.leaveFamily();
        await Future.delayed(const Duration(milliseconds: 100));

        expect(notifier.state.error, contains('退出家庭失败'));
        final members = await db.getFamilyMembers('existing_family');
        expect(members.where((m) => m.userId == 'user1'), isNotEmpty);

        notifier.dispose();
        await db.close();
      });

      test('Internal (code 13): sets error, does not remove locally',
          () async {
        final db = await _setupDbWithFamily();
        final client = FakeFamilyClient()
          ..leaveError = GrpcError.internal('server error');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.leaveFamily();
        await Future.delayed(const Duration(milliseconds: 100));

        expect(notifier.state.error, contains('退出家庭失败'));

        notifier.dispose();
        await db.close();
      });
    });

    group('FamilyNotifier.createFamily — error code coverage', () {
      test('Unauthenticated (code 16): falls back to local creation',
          () async {
        // createFamily has a fallback: if gRPC fails, create locally
        final db = await _setupDb();
        final client = FakeFamilyClient()
          ..createError = GrpcError.unauthenticated('not logged in');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 100));

        final result = await notifier.createFamily('Auth Fail Family');

        // Should succeed via local fallback
        expect(result, isNotNull);
        expect(result!.length, 36); // UUID
        expect(notifier.state.error, isNull);

        notifier.dispose();
        await db.close();
      });

      test('PermissionDenied (code 7): falls back to local creation',
          () async {
        final db = await _setupDb();
        final client = FakeFamilyClient()
          ..createError = GrpcError.permissionDenied('quota exceeded');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 100));

        final result = await notifier.createFamily('Denied Family');

        expect(result, isNotNull);
        expect(result!.length, 36);
        expect(notifier.state.error, isNull);

        notifier.dispose();
        await db.close();
      });

      test('Internal (code 13): falls back to local creation', () async {
        final db = await _setupDb();
        final client = FakeFamilyClient()
          ..createError = GrpcError.internal('crash');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 100));

        final result = await notifier.createFamily('Internal Err Family');

        expect(result, isNotNull);
        expect(result!.length, 36);
        expect(notifier.state.error, isNull);

        notifier.dispose();
        await db.close();
      });
    });

    group('SyncEngine._pushPendingOps — error code coverage', () {
      // SyncEngine catches all errors in _pushPendingOps and just logs.
      // The ops remain in the queue for later retry.

      late AppDatabase db;
      late SharedPreferences prefs;
      late MockConnectivity mockConnectivity;

      setUp(() async {
        SharedPreferences.setMockInitialValues({
          'user_id': 'user1',
        });
        prefs = await SharedPreferences.getInstance();
        db = await _setupDb();
        mockConnectivity = MockConnectivity();
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);
        when(() => mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => Stream.value([ConnectivityResult.wifi]));
        // Insert a pending sync op
        await db.insertSyncOp(SyncQueueCompanion.insert(
          id: 'op_1',
          entityType: 'transaction',
          entityId: 'txn_1',
          opType: 'create',
          payload: jsonEncode({
            'id': 'txn_1',
            'account_id': 'acc1',
            'category_id': 'cat1',
            'amount': 1000,
            'type': 'expense',
          }),
          clientId: 'client_user1',
          timestamp: DateTime.now(),
        ));
      });

      tearDown(() async {
        await db.close();
      });

      test('Unauthenticated (code 16): does not crash, ops remain in queue',
          () async {
        final syncClient = FakeSyncClient()
          ..pushError = GrpcError.unauthenticated('expired token');

        final engine = SyncEngine(db, syncClient, prefs,
            connectivity: mockConnectivity);

        // Manually trigger push (normally done by timer)
        await engine.syncNow();

        // Should not throw — ops remain for retry
        final ops = await db.getPendingSyncOps(10);
        expect(ops, hasLength(1)); // still there, not marked uploaded

        engine.dispose();
      });

      test('PermissionDenied (code 7): does not crash, ops remain in queue',
          () async {
        final syncClient = FakeSyncClient()
          ..pushError = GrpcError.permissionDenied('no access');

        final engine = SyncEngine(db, syncClient, prefs,
            connectivity: mockConnectivity);

        await engine.syncNow();

        final ops = await db.getPendingSyncOps(10);
        expect(ops, hasLength(1));

        engine.dispose();
      });

      test('DeadlineExceeded (code 4): does not crash, ops remain in queue',
          () async {
        final syncClient = FakeSyncClient()
          ..pushError = GrpcError.deadlineExceeded('timeout');

        final engine = SyncEngine(db, syncClient, prefs,
            connectivity: mockConnectivity);

        await engine.syncNow();

        final ops = await db.getPendingSyncOps(10);
        expect(ops, hasLength(1));

        engine.dispose();
      });

      test('Internal (code 13): does not crash, ops remain in queue',
          () async {
        final syncClient = FakeSyncClient()
          ..pushError = GrpcError.internal('server error');

        final engine = SyncEngine(db, syncClient, prefs,
            connectivity: mockConnectivity);

        await engine.syncNow();

        final ops = await db.getPendingSyncOps(10);
        expect(ops, hasLength(1));

        engine.dispose();
      });

      test('InvalidArgument (code 3): does not crash, ops remain in queue',
          () async {
        final syncClient = FakeSyncClient()
          ..pushError = GrpcError.invalidArgument('malformed op');

        final engine = SyncEngine(db, syncClient, prefs,
            connectivity: mockConnectivity);

        await engine.syncNow();

        final ops = await db.getPendingSyncOps(10);
        expect(ops, hasLength(1));

        engine.dispose();
      });

      test('Unavailable (code 14): does not crash, ops remain in queue',
          () async {
        final syncClient = FakeSyncClient()
          ..pushError = GrpcError.unavailable('offline');

        final engine = SyncEngine(db, syncClient, prefs,
            connectivity: mockConnectivity);

        await engine.syncNow();

        final ops = await db.getPendingSyncOps(10);
        expect(ops, hasLength(1));

        engine.dispose();
      });
    });

    group('No unhandled exceptions — robustness check', () {
      // Verify that no error code causes an unhandled exception that would
      // crash the app. These are "does not throw" style assertions.

      test('All error codes in addTransaction do not throw', () async {
        final db = await _setupDb();
        final errors = [
          GrpcError.unauthenticated(),
          GrpcError.permissionDenied(),
          GrpcError.deadlineExceeded(),
          GrpcError.notFound(),
          GrpcError.internal(),
          GrpcError.invalidArgument(),
          GrpcError.unavailable(),
          GrpcError.cancelled(),
          GrpcError.unknown(),
          GrpcError.resourceExhausted(),
          GrpcError.aborted(),
          GrpcError.unimplemented(),
          GrpcError.dataLoss(),
        ];

        for (final error in errors) {
          final client = FakeTransactionClient()..createError = error;
          final notifier = TransactionNotifier(db, 'user1', null, client);
          await Future.delayed(const Duration(milliseconds: 100));

          // Should not throw
          await notifier.addTransaction(
            categoryId: 'cat1',
            amount: 100,
            type: 'expense',
            note: 'error: ${error.codeName}',
          );

          expect(notifier.state.error, isNull,
              reason: 'Error code ${error.codeName} should not set error state on add');

          await Future.delayed(const Duration(milliseconds: 300));
          notifier.dispose();
        }

        await db.close();
      });

      test('All error codes in joinFamily set error state without crash',
          () async {
        final errors = [
          GrpcError.unauthenticated(),
          GrpcError.permissionDenied(),
          GrpcError.deadlineExceeded(),
          GrpcError.notFound(),
          GrpcError.internal(),
          GrpcError.invalidArgument(),
          GrpcError.unavailable(),
          GrpcError.cancelled(),
          GrpcError.unknown(),
          GrpcError.resourceExhausted(),
          GrpcError.aborted(),
          GrpcError.unimplemented(),
          GrpcError.dataLoss(),
        ];

        for (final error in errors) {
          final db = await _setupDb();
          final client = FakeFamilyClient()..joinError = error;
          final notifier = FamilyNotifier(db, 'user1', client);
          await Future.delayed(const Duration(milliseconds: 100));

          final result = await notifier.joinFamily('TEST');

          expect(result, isNull,
              reason: 'joinFamily should return null on ${error.codeName}');
          expect(notifier.state.error, isNotNull,
              reason: 'joinFamily should set error on ${error.codeName}');
          expect(notifier.state.isLoading, false,
              reason: 'isLoading should be false after ${error.codeName}');

          notifier.dispose();
          await db.close();
        }
      });
    });
  });
}
