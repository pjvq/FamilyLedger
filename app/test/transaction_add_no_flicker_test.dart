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

/// A fake that returns a server-assigned ID different from client ID.
class FakeCreateTransactionClient implements pbgrpc.TransactionServiceClient {
  final String serverAssignedId;
  int createCallCount = 0;
  pbgrpc.CreateTransactionRequest? lastCreateRequest;

  FakeCreateTransactionClient({this.serverAssignedId = 'server_txn_001'});

  @override
  ResponseFuture<pb.CreateTransactionResponse> createTransaction(
    pbgrpc.CreateTransactionRequest request, {
    CallOptions? options,
  }) {
    createCallCount++;
    lastCreateRequest = request;

    final response = pb.CreateTransactionResponse(
      transaction: pb.Transaction(
        id: serverAssignedId,
        userId: 'user1',
        accountId: request.accountId,
        categoryId: request.categoryId,
        amount: request.amount,
        currency: request.currency,
        amountCny: request.amountCny,
        exchangeRate: request.exchangeRate,
        type: request.type,
        note: request.note,
        txnDate: request.txnDate,
      ),
    );

    return _FakeResponseFuture.value(response);
  }

  @override
  ResponseFuture<pb.ListTransactionsResponse> listTransactions(
    pbgrpc.ListTransactionsRequest request, {
    CallOptions? options,
  }) {
    return _FakeResponseFuture.value(pb.ListTransactionsResponse(
      transactions: [],
      nextPageToken: '',
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented in fake');
}

/// A fake that always throws (simulating offline).
class OfflineCreateTransactionClient
    implements pbgrpc.TransactionServiceClient {
  int createCallCount = 0;

  @override
  ResponseFuture<pb.CreateTransactionResponse> createTransaction(
    pbgrpc.CreateTransactionRequest request, {
    CallOptions? options,
  }) {
    createCallCount++;
    return _FakeResponseFuture.error(
        GrpcError.unavailable('No connection'));
  }

  @override
  ResponseFuture<pb.ListTransactionsResponse> listTransactions(
    pbgrpc.ListTransactionsRequest request, {
    CallOptions? options,
  }) {
    return _FakeResponseFuture.value(pb.ListTransactionsResponse(
      transactions: [],
      nextPageToken: '',
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented in fake');
}

class _FakeResponseFuture<T> implements ResponseFuture<T> {
  final Future<T> _future;
  _FakeResponseFuture.value(T value) : _future = Future.value(value);
  _FakeResponseFuture.error(Object error) : _future = Future.error(error);

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

  bool get isCancelled => false;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─── Helpers ─────────────────────────────────────────────────

Future<AppDatabase> _setupDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  // Insert required user for FK constraints
  await db.customStatement(
      "INSERT OR IGNORE INTO users (id, email) "
      "VALUES ('user1', 'test@test.com')");
  // Insert account using Drift's insertAccount
  await db.insertAccount(AccountsCompanion.insert(
    id: 'acc1',
    userId: 'user1',
    name: 'Test Account',
    familyId: const Value.absent(),
    accountType: const Value('cash'),
  ));
  // Insert a category for the test
  await db.customStatement(
      "INSERT OR IGNORE INTO categories (id, name, icon_key, type, is_preset, sort_order) "
      "VALUES ('cat1', 'Food', '🍔', 'expense', 1, 1)");
  return db;
}

// ─── Tests ───────────────────────────────────────────────────

void main() {
  group('TransactionNotifier.addTransaction (no-flicker fix)', () {
    late AppDatabase db;

    setUp(() async {
      db = await _setupDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('online: uses server-assigned ID directly (no delete+re-insert)',
        () async {
      final client =
          FakeCreateTransactionClient(serverAssignedId: 'server_txn_42');

      final notifier = TransactionNotifier(db, 'user1', null, client);
      await Future.delayed(const Duration(milliseconds: 200));

      // Collect stream events to detect flicker (delete+re-insert)
      final streamEvents = <List<Transaction>>[];
      final sub = db.watchTransactions('user1').listen((txns) {
        streamEvents.add(List.from(txns));
      });

      await notifier.addTransaction(
        categoryId: 'cat1',
        amount: 1000,
        type: 'expense',
      );

      // Give stream time to emit
      await Future.delayed(const Duration(milliseconds: 300));
      await sub.cancel();

      // Server should have been called exactly once
      expect(client.createCallCount, 1);

      // The transaction in DB should have the server-assigned ID
      final txn = await db.getTransactionById('server_txn_42');
      expect(txn, isNotNull);
      expect(txn!.amount, 1000);

      // There should be NO transaction with a local UUID (would indicate flicker)
      // Since we used server ID directly, no hardDelete happened
      // Check that stream events never show a delete+re-insert pattern
      // (i.e., we never see a transaction appear and then disappear)
      final allIds = streamEvents
          .expand((list) => list.map((t) => t.id))
          .toSet();
      // Only server_txn_42 should appear (no temporary local UUID)
      expect(allIds.contains('server_txn_42'), isTrue);
      // No other transaction IDs (local UUIDs) should appear
      final nonServerIds =
          allIds.where((id) => id != 'server_txn_42').toList();
      expect(nonServerIds, isEmpty,
          reason:
              'No temporary local ID should appear in stream events');

      notifier.dispose();
    });

    test('offline: uses local UUID and queues sync op', () async {
      final client = OfflineCreateTransactionClient();

      final notifier = TransactionNotifier(db, 'user1', null, client);
      await Future.delayed(const Duration(milliseconds: 200));

      await notifier.addTransaction(
        categoryId: 'cat1',
        amount: 2000,
        type: 'income',
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Server was attempted
      expect(client.createCallCount, 1);

      // Transaction should exist with a local UUID
      final txns = notifier.state.transactions;
      expect(txns, isNotEmpty);
      final txn = txns.first;
      expect(txn.amount, 2000);
      expect(txn.type, 'income');
      // ID should be a valid UUID (not server-assigned)
      expect(txn.id.length, 36); // UUID format

      // Sync queue should have an entry
      final syncOps = await db.customSelect(
        "SELECT * FROM sync_queue WHERE entity_id = '${txn.id}'",
      ).get();
      expect(syncOps, isNotEmpty);
      expect(syncOps.first.data['op_type'], 'create');

      notifier.dispose();
    });

    test('no client: uses local UUID without attempting server call',
        () async {
      final notifier = TransactionNotifier(db, 'user1', null, null);
      await Future.delayed(const Duration(milliseconds: 200));

      await notifier.addTransaction(
        categoryId: 'cat1',
        amount: 500,
        type: 'expense',
      );

      await Future.delayed(const Duration(milliseconds: 200));

      final txns = notifier.state.transactions;
      expect(txns, isNotEmpty);
      expect(txns.first.amount, 500);

      notifier.dispose();
    });
  });
}
