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

// ─── Configurable Pagination Client ─────────────────────────

class PaginationTrackingClient implements pbgrpc.TransactionServiceClient {
  /// All pages to serve. Each entry is a list of transactions for that page.
  final List<List<pb.Transaction>> pages;

  /// Captured page tokens from requests
  final List<String> capturedPageTokens = [];

  /// Captured page sizes from requests
  final List<int> capturedPageSizes = [];

  /// Number of listTransactions calls made
  int callCount = 0;

  /// Optional delay to simulate network latency
  final Duration? latency;

  PaginationTrackingClient({
    this.pages = const [],
    this.latency,
  });

  @override
  ResponseFuture<pb.ListTransactionsResponse> listTransactions(
    pbgrpc.ListTransactionsRequest request, {
    CallOptions? options,
  }) {
    capturedPageTokens.add(request.pageToken);
    capturedPageSizes.add(request.pageSize);
    final pageIndex = callCount;
    callCount++;

    final transactions =
        pageIndex < pages.length ? pages[pageIndex] : <pb.Transaction>[];
    final nextPageToken =
        (pageIndex + 1 < pages.length) ? 'page_${pageIndex + 1}' : '';

    if (latency != null) {
      return _DelayedResponseFuture(
        Future.delayed(latency!, () => pb.ListTransactionsResponse(
          transactions: transactions,
          nextPageToken: nextPageToken,
        )),
      );
    }

    return FakeResponseFuture.value(pb.ListTransactionsResponse(
      transactions: transactions,
      nextPageToken: nextPageToken,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented in fake');
}

class _DelayedResponseFuture<T> implements ResponseFuture<T> {
  final Future<T> _future;
  _DelayedResponseFuture(this._future);

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

// ─── Helper: generates N transactions ────────────────────────

List<pb.Transaction> _generateTransactions(int count, {String prefix = 'txn'}) {
  return List.generate(count, (i) => pb.Transaction(
    id: '${prefix}_$i',
    userId: 'user1',
    accountId: 'acc_fam',
    categoryId: 'cat1',
    amount: Int64(1000 + i),
    amountCny: Int64(1000 + i),
    type: pbe.TransactionType.TRANSACTION_TYPE_EXPENSE,
    note: 'item $i',
    txnDate: proto_ts.Timestamp(
      seconds: Int64(DateTime(2025, 1, 1).millisecondsSinceEpoch ~/ 1000),
    ),
  ));
}

// ─── DB Setup ────────────────────────────────────────────────

Future<AppDatabase> _setupDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.customStatement(
      "INSERT OR IGNORE INTO users (id, email, created_at) "
      "VALUES ('user1', 'test@test.com', "
      "${DateTime.now().millisecondsSinceEpoch ~/ 1000})");
  await db.insertAccount(AccountsCompanion.insert(
    id: 'acc_fam',
    userId: 'user1',
    name: 'Family Account',
    familyId: const Value('fam1'),
    accountType: const Value('bank_card'),
  ));
  await db.customStatement(
      "INSERT OR IGNORE INTO categories (id, name, type, icon_key) "
      "VALUES ('cat1', '餐饮', 'expense', 'restaurant')");
  return db;
}

// ─── Tests ───────────────────────────────────────────────────

void main() {
  group('TransactionNotifier — 分页加载边界', () {
    late AppDatabase db;

    setUp(() async {
      db = await _setupDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('第一页加载（pageToken=""）正确发送请求', () async {
      final client = PaginationTrackingClient(
        pages: [
          _generateTransactions(100, prefix: 'p0'),
          _generateTransactions(50, prefix: 'p1'),
        ],
      );

      final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
      await Future.delayed(const Duration(milliseconds: 500));

      // First call should have empty pageToken
      expect(client.capturedPageTokens.first, '');
      // Second call should have 'page_1'
      expect(client.capturedPageTokens[1], 'page_1');
      // Page size should be 100 (_syncPageSize)
      expect(client.capturedPageSizes.first, 100);

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('最后一页（nextPageToken为空）→ 停止加载', () async {
      final client = PaginationTrackingClient(
        pages: [
          _generateTransactions(100, prefix: 'p0'),
          _generateTransactions(30, prefix: 'p1'), // < pageSize, last page
        ],
      );

      final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
      await Future.delayed(const Duration(milliseconds: 500));

      // Should have made exactly 2 calls (second page returns empty nextPageToken)
      expect(client.callCount, 2);

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('空页面（items=0, nextPageToken=""）→ 只调用1次', () async {
      final client = PaginationTrackingClient(
        pages: [
          [], // Empty first page with no nextPageToken
        ],
      );

      final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
      await Future.delayed(const Duration(milliseconds: 500));

      // Only 1 call, no next page
      expect(client.callCount, 1);

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('maxPages=200 保护（不会无限循环）', () async {
      // Create a client that always returns a non-empty nextPageToken
      // by providing 250 pages (exceeds _maxPages=200)
      final manyPages = List.generate(250, (i) =>
          _generateTransactions(1, prefix: 'page$i'));
      final client = PaginationTrackingClient(pages: manyPages);

      final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
      // Give it more time since it's doing 200 iterations
      await Future.delayed(const Duration(milliseconds: 2000));

      // Should stop at exactly 200 pages
      expect(client.callCount, 200);

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('并发调用 reload 不会导致问题', () async {
      final client = PaginationTrackingClient(
        pages: [
          _generateTransactions(10, prefix: 'p0'),
        ],
      );

      final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
      await Future.delayed(const Duration(milliseconds: 500));

      final initialCount = client.callCount;

      // Call reload multiple times concurrently
      await Future.wait([
        notifier.reload(),
        notifier.reload(),
        notifier.reload(),
      ]);
      await Future.delayed(const Duration(milliseconds: 500));

      // All calls should complete without error
      // Each reload triggers one page fetch (since our pages list has 1 entry)
      expect(client.callCount, greaterThan(initialCount));
      expect(notifier.state.error, isNull);

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('gRPC 分页 token 正确传递', () async {
      final client = PaginationTrackingClient(
        pages: [
          _generateTransactions(5, prefix: 'a'),
          _generateTransactions(5, prefix: 'b'),
          _generateTransactions(5, prefix: 'c'),
        ],
      );

      final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify tokens are sequential
      expect(client.callCount, 3);
      expect(client.capturedPageTokens[0], ''); // First request: empty
      expect(client.capturedPageTokens[1], 'page_1'); // From first response
      expect(client.capturedPageTokens[2], 'page_2'); // From second response

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('单页全部数据（< pageSize）→ 只调用1次', () async {
      final client = PaginationTrackingClient(
        pages: [
          _generateTransactions(50, prefix: 'single'), // less than 100
        ],
      );

      final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
      await Future.delayed(const Duration(milliseconds: 500));

      // Only 1 page fetched since nextPageToken is empty
      expect(client.callCount, 1);

      // Verify data was saved to DB
      final txn = await db.getTransactionById('single_0');
      expect(txn, isNotNull);
      expect(txn!.note, 'item 0');

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('无 familyId 时不触发分页同步', () async {
      final client = PaginationTrackingClient(
        pages: [_generateTransactions(10)],
      );

      // No familyId → no server sync
      final notifier = TransactionNotifier(db, 'user1', null, client);
      await Future.delayed(const Duration(milliseconds: 500));

      expect(client.callCount, 0);

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('空 familyId 时不触发分页同步', () async {
      final client = PaginationTrackingClient(
        pages: [_generateTransactions(10)],
      );

      // Empty familyId → no server sync
      final notifier = TransactionNotifier(db, 'user1', '', client);
      await Future.delayed(const Duration(milliseconds: 500));

      expect(client.callCount, 0);

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('gRPC 错误时优雅降级到本地数据', () async {
      // A client that throws on first call
      final client = _ErrorOnNthCallClient(errorOnCall: 0);

      final notifier = TransactionNotifier(db, 'user1', 'fam1', client);
      await Future.delayed(const Duration(milliseconds: 500));

      // Should not crash, state should not have error (it's caught)
      expect(notifier.state.isLoading, false);
      // Error in sync is caught silently (continues with local data)

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });
  });
}

/// A client that throws GrpcError on the Nth call
class _ErrorOnNthCallClient implements pbgrpc.TransactionServiceClient {
  final int errorOnCall;
  int _callCount = 0;

  _ErrorOnNthCallClient({required this.errorOnCall});

  @override
  ResponseFuture<pb.ListTransactionsResponse> listTransactions(
    pbgrpc.ListTransactionsRequest request, {
    CallOptions? options,
  }) {
    if (_callCount == errorOnCall) {
      _callCount++;
      return FakeResponseFuture.error(
          GrpcError.unavailable('Network error'));
    }
    _callCount++;
    return FakeResponseFuture.value(pb.ListTransactionsResponse(
      transactions: [],
      nextPageToken: '',
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented');
}
