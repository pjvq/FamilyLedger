import 'dart:async';

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

/// A minimal fake TransactionServiceClient that returns paginated responses.
class FakeTransactionClient implements pbgrpc.TransactionServiceClient {
  /// Pages of transactions to return. Each list element is one page.
  final List<List<pb.Transaction>> pages;
  int callCount = 0;
  final List<pbgrpc.ListTransactionsRequest> capturedRequests = [];

  FakeTransactionClient(this.pages);

  @override
  ResponseFuture<pb.ListTransactionsResponse> listTransactions(
    pbgrpc.ListTransactionsRequest request, {
    CallOptions? options,
  }) {
    capturedRequests.add(request);
    final pageIndex = callCount;
    callCount++;

    final transactions =
        pageIndex < pages.length ? pages[pageIndex] : <pb.Transaction>[];
    final nextPageToken =
        (pageIndex + 1 < pages.length) ? 'page_${pageIndex + 1}' : '';

    final response = pb.ListTransactionsResponse(
      transactions: transactions,
      nextPageToken: nextPageToken,
    );

    return _FakeResponseFuture.value(response);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented in fake');
}

/// A fake that always throws (simulating offline).
class OfflineTransactionClient implements pbgrpc.TransactionServiceClient {
  @override
  ResponseFuture<pb.ListTransactionsResponse> listTransactions(
    pbgrpc.ListTransactionsRequest request, {
    CallOptions? options,
  }) {
    return _FakeResponseFuture.error(
        GrpcError.unavailable('No connection'));
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

pb.Transaction _makeProtoTxn(String id, {int amount = 1000}) {
  return pb.Transaction(
    id: id,
    userId: 'user1',
    accountId: 'acc1',
    categoryId: 'cat1',
    amount: Int64(amount),
    currency: 'CNY',
    amountCny: Int64(amount),
    exchangeRate: 1.0,
    type: pbe.TransactionType.TRANSACTION_TYPE_EXPENSE,
    note: 'test',
    txnDate: proto_ts.Timestamp(
      seconds: Int64(DateTime(2025, 1, 1).millisecondsSinceEpoch ~/ 1000),
    ),
  );
}

Future<AppDatabase> _setupDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  // Insert required user for FK constraints
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
  group('TransactionNotifier._load() pagination', () {
    late AppDatabase db;

    setUp(() async {
      db = await _setupDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('fetches multiple pages until nextPageToken is empty', () async {
      // 3 pages: 2 items, 2 items, 1 item
      final page1 = [_makeProtoTxn('txn_1'), _makeProtoTxn('txn_2')];
      final page2 = [_makeProtoTxn('txn_3'), _makeProtoTxn('txn_4')];
      final page3 = [_makeProtoTxn('txn_5')];
      final client = FakeTransactionClient([page1, page2, page3]);

      final notifier = TransactionNotifier(db, 'user1', 'fam1', client);

      // Wait for _load() to complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Should have called listTransactions 3 times
      expect(client.callCount, 3);

      // Verify page tokens in requests
      expect(client.capturedRequests[0].pageToken, '');
      expect(client.capturedRequests[1].pageToken, 'page_1');
      expect(client.capturedRequests[2].pageToken, 'page_2');

      // All 5 transactions should be in local DB
      for (int i = 1; i <= 5; i++) {
        final txn = await db.getTransactionById('txn_$i');
        expect(txn, isNotNull, reason: 'txn_$i should exist');
      }

      notifier.dispose();
    });

    test('stops fetching when response returns empty page', () async {
      final page1 = [_makeProtoTxn('txn_1')];
      final emptyPage = <pb.Transaction>[];
      final client = FakeTransactionClient([page1, emptyPage]);

      final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
      await Future.delayed(const Duration(milliseconds: 500));

      // First page returns data with nextPageToken, second is empty
      // But FakeTransactionClient uses page index, so after page1 returns
      // nextPageToken='page_1', calling page_1 returns emptyPage with no token
      expect(client.callCount, 2);

      final txn = await db.getTransactionById('txn_1');
      expect(txn, isNotNull);

      notifier.dispose();
    });

    test('uses pageSize of 100', () async {
      final client = FakeTransactionClient([[]]);

      final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
      await Future.delayed(const Duration(milliseconds: 300));

      expect(client.capturedRequests.first.pageSize, 100);

      notifier.dispose();
    });

    test('upsert does not crash on duplicate transaction IDs', () async {
      // Pre-insert a transaction with same ID
      await db.insertOrUpdateTransaction(
        id: 'txn_dup',
        userId: 'user1',
        accountId: 'acc1',
        categoryId: 'cat1',
        amount: 500,
        amountCny: 500,
        type: 'expense',
        note: 'original',
        txnDate: DateTime(2025, 1, 1),
      );

      // Now load from server with same ID but different amount
      final client = FakeTransactionClient([
        [_makeProtoTxn('txn_dup', amount: 2000)]
      ]);

      final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
      await Future.delayed(const Duration(milliseconds: 500));

      // Should not crash, and should have updated the record
      final txn = await db.getTransactionById('txn_dup');
      expect(txn, isNotNull);
      expect(txn!.amount, 2000); // Updated via upsert

      notifier.dispose();
    });

    test('handles gRPC error gracefully (offline mode)', () async {
      final client = OfflineTransactionClient();

      // Should not throw
      final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
      await Future.delayed(const Duration(milliseconds: 300));

      // State should not be in error (offline is handled gracefully)
      expect(notifier.state.isLoading, false);

      notifier.dispose();
    });

    test('skips server sync when familyId is null', () async {
      final client = FakeTransactionClient([[_makeProtoTxn('txn_x')]]);

      final notifier = TransactionNotifier(db, 'user1', null, client);
      await Future.delayed(const Duration(milliseconds: 300));

      // Should never call the client
      expect(client.callCount, 0);

      notifier.dispose();
    });
  });
}
