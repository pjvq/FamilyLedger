/// DashboardProvider aggregation logic tests.
///
/// Tests local computation of net worth, income/expense trend,
/// and category breakdown using a real in-memory Drift database.
import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/dashboard_provider.dart';
import 'package:familyledger/generated/proto/dashboard.pb.dart' as pb;
import 'package:familyledger/generated/proto/dashboard.pbgrpc.dart';
import 'package:familyledger/generated/proto/investment.pb.dart' as inv_pb;
import 'package:familyledger/generated/proto/investment.pbgrpc.dart';

// ─── Fake gRPC client (all methods throw to force local fallback) ──

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

/// All gRPC calls fail, forcing DashboardNotifier to use local DB only.
class FailingDashboardClient implements DashboardServiceClient {
  @override
  ResponseFuture<pb.NetWorth> getNetWorth(pb.GetNetWorthRequest request,
      {CallOptions? options}) {
    return FakeResponseFuture.error(
        GrpcError.unavailable('test: no server'));
  }

  @override
  ResponseFuture<pb.TrendResponse> getIncomeExpenseTrend(
      pb.TrendRequest request,
      {CallOptions? options}) {
    return FakeResponseFuture.error(
        GrpcError.unavailable('test: no server'));
  }

  @override
  ResponseFuture<pb.CategoryBreakdownResponse> getCategoryBreakdown(
      pb.CategoryBreakdownRequest request,
      {CallOptions? options}) {
    return FakeResponseFuture.error(
        GrpcError.unavailable('test: no server'));
  }

  @override
  ResponseFuture<pb.BudgetSummaryResponse> getBudgetSummary(
      pb.BudgetSummaryRequest request,
      {CallOptions? options}) {
    return FakeResponseFuture.error(
        GrpcError.unavailable('test: no server'));
  }

  @override
  ResponseFuture<pb.TrendResponse> getNetWorthTrend(pb.TrendRequest request,
      {CallOptions? options}) {
    return FakeResponseFuture.error(
        GrpcError.unavailable('test: no server'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented in fake');
}

class FailingMarketDataClient implements MarketDataServiceClient {
  @override
  ResponseFuture<inv_pb.MarketQuote> getQuote(inv_pb.GetQuoteRequest request,
      {CallOptions? options}) {
    return FakeResponseFuture.error(
        GrpcError.unavailable('test: no server'));
  }

  @override
  ResponseFuture<inv_pb.BatchGetQuotesResponse> batchGetQuotes(
      inv_pb.BatchGetQuotesRequest request,
      {CallOptions? options}) {
    return FakeResponseFuture.error(
        GrpcError.unavailable('test: no server'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented in fake');
}

// ─── Helpers ──

Future<AppDatabase> _setupDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());

  // Insert user
  await db.customStatement(
      "INSERT OR IGNORE INTO users (id, email, created_at) "
      "VALUES ('user1', 'test@test.com', "
      "${DateTime.now().millisecondsSinceEpoch ~/ 1000})");

  return db;
}

Future<void> _insertAccount(AppDatabase db, {
  required String id,
  required int balance,
  String familyId = '',
}) async {
  await db.insertAccount(AccountsCompanion.insert(
    id: id,
    userId: 'user1',
    name: 'Account $id',
    familyId: Value(familyId),
    accountType: const Value('bank_card'),
    balance: Value(balance),
  ));
}

Future<void> _insertCategory(AppDatabase db, {
  required String id,
  required String name,
  required String type,
}) async {
  await db.upsertCategory(
    id: id,
    name: name,
    type: type,
    isPreset: true,
    sortOrder: 1,
  );
}

Future<void> _insertTransaction(AppDatabase db, {
  required String id,
  required String accountId,
  required String categoryId,
  required int amountCny,
  required String type,
  required DateTime txnDate,
}) async {
  await db.insertTransaction(TransactionsCompanion.insert(
    id: id,
    userId: 'user1',
    accountId: accountId,
    categoryId: categoryId,
    amount: amountCny,
    amountCny: amountCny,
    type: type,
    txnDate: txnDate,
  ));
}

// ─── Tests ──

void main() {
  group('DashboardNotifier — net worth computation', () {
    late AppDatabase db;

    setUp(() async {
      db = await _setupDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('net worth = sum of account balances (no investments/loans)', () async {
      await _insertAccount(db, id: 'acc1', balance: 10000000); // 10万
      await _insertAccount(db, id: 'acc2', balance: 5000000);  // 5万

      final notifier = DashboardNotifier(
          db, FailingDashboardClient(), FailingMarketDataClient(), 'user1', null);
      await notifier.loadAll();
      // Allow async ops to complete
      await Future.delayed(const Duration(milliseconds: 300));

      final state = notifier.state;
      expect(state.netWorth.cashAndBank, 15000000);
      expect(state.netWorth.total, 15000000);

      notifier.dispose();
    });

    test('empty data does not crash', () async {
      final notifier = DashboardNotifier(
          db, FailingDashboardClient(), FailingMarketDataClient(), 'user1', null);
      await notifier.loadAll();
      await Future.delayed(const Duration(milliseconds: 300));

      final state = notifier.state;
      expect(state.netWorth.total, 0);
      expect(state.netWorth.cashAndBank, 0);
      expect(state.isLoading, false);
      expect(state.error, isNull);

      notifier.dispose();
    });

    test('family mode uses family accounts only', () async {
      // Personal account
      await _insertAccount(db, id: 'acc_personal', balance: 10000000);
      // Family account
      await _insertAccount(db, id: 'acc_family', balance: 20000000, familyId: 'fam1');

      final notifier = DashboardNotifier(
          db, FailingDashboardClient(), FailingMarketDataClient(), 'user1', 'fam1');
      await notifier.loadAll();
      await Future.delayed(const Duration(milliseconds: 300));

      // Should only count family account
      expect(notifier.state.netWorth.cashAndBank, 20000000);

      notifier.dispose();
    });

    test('personal mode excludes family accounts', () async {
      await _insertAccount(db, id: 'acc_personal', balance: 10000000);
      await _insertAccount(db, id: 'acc_family', balance: 20000000, familyId: 'fam1');

      final notifier = DashboardNotifier(
          db, FailingDashboardClient(), FailingMarketDataClient(), 'user1', null);
      await notifier.loadAll();
      await Future.delayed(const Duration(milliseconds: 300));

      // Should only count personal account
      expect(notifier.state.netWorth.cashAndBank, 10000000);

      notifier.dispose();
    });
  });

  group('DashboardNotifier — income/expense trend', () {
    late AppDatabase db;

    setUp(() async {
      db = await _setupDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('monthly trend aggregates income and expense', () async {
      await _insertAccount(db, id: 'acc1', balance: 0);
      await _insertCategory(db, id: 'cat_food', name: '食物', type: 'expense');
      await _insertCategory(db, id: 'cat_salary', name: '工资', type: 'income');

      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 10);

      await _insertTransaction(db,
        id: 'tx1',
        accountId: 'acc1',
        categoryId: 'cat_food',
        amountCny: 5000, // 50 yuan
        type: 'expense',
        txnDate: thisMonth,
      );
      await _insertTransaction(db,
        id: 'tx2',
        accountId: 'acc1',
        categoryId: 'cat_salary',
        amountCny: 100000, // 1000 yuan
        type: 'income',
        txnDate: thisMonth,
      );

      final notifier = DashboardNotifier(
          db, FailingDashboardClient(), FailingMarketDataClient(), 'user1', null);
      await notifier.loadAll();
      await Future.delayed(const Duration(milliseconds: 300));

      // The last point in the trend should reflect this month
      final trend = notifier.state.incomeExpenseTrend;
      expect(trend, isNotEmpty);

      final currentMonthPoint = trend.last;
      expect(currentMonthPoint.income, 100000);
      expect(currentMonthPoint.expense, 5000);
      expect(currentMonthPoint.net, 95000);

      notifier.dispose();
    });

    test('empty month shows zero values', () async {
      await _insertAccount(db, id: 'acc1', balance: 0);

      final notifier = DashboardNotifier(
          db, FailingDashboardClient(), FailingMarketDataClient(), 'user1', null);
      await notifier.loadAll();
      await Future.delayed(const Duration(milliseconds: 300));

      final trend = notifier.state.incomeExpenseTrend;
      // All points should have 0 income and 0 expense
      for (final point in trend) {
        expect(point.income, 0);
        expect(point.expense, 0);
        expect(point.net, 0);
      }

      notifier.dispose();
    });
  });

  group('DashboardNotifier — category breakdown', () {
    late AppDatabase db;

    setUp(() async {
      db = await _setupDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('groups expenses by category for current month', () async {
      await _insertAccount(db, id: 'acc1', balance: 0);
      await _insertCategory(db, id: 'cat_food', name: '食物', type: 'expense');
      await _insertCategory(db, id: 'cat_transport', name: '交通', type: 'expense');

      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 5);

      await _insertTransaction(db,
        id: 'tx1',
        accountId: 'acc1',
        categoryId: 'cat_food',
        amountCny: 10000,
        type: 'expense',
        txnDate: thisMonth,
      );
      await _insertTransaction(db,
        id: 'tx2',
        accountId: 'acc1',
        categoryId: 'cat_food',
        amountCny: 5000,
        type: 'expense',
        txnDate: thisMonth,
      );
      await _insertTransaction(db,
        id: 'tx3',
        accountId: 'acc1',
        categoryId: 'cat_transport',
        amountCny: 3000,
        type: 'expense',
        txnDate: thisMonth,
      );

      final notifier = DashboardNotifier(
          db, FailingDashboardClient(), FailingMarketDataClient(), 'user1', null);
      await notifier.loadAll();
      await Future.delayed(const Duration(milliseconds: 300));

      final breakdown = notifier.state.categoryBreakdown;
      expect(breakdown, isNotEmpty);

      // Total should be 18000
      expect(notifier.state.categoryBreakdownTotal, 18000);

      // Find food category — amount should be 15000
      final foodItem = breakdown.where((b) => b.categoryId == 'cat_food').firstOrNull;
      expect(foodItem, isNotNull);
      expect(foodItem!.amount, 15000);

      // Find transport — amount should be 3000
      final transportItem = breakdown.where((b) => b.categoryId == 'cat_transport').firstOrNull;
      expect(transportItem, isNotNull);
      expect(transportItem!.amount, 3000);

      notifier.dispose();
    });

    test('empty month returns empty breakdown without crashing', () async {
      await _insertAccount(db, id: 'acc1', balance: 0);

      final notifier = DashboardNotifier(
          db, FailingDashboardClient(), FailingMarketDataClient(), 'user1', null);
      await notifier.loadAll();
      await Future.delayed(const Duration(milliseconds: 300));

      expect(notifier.state.categoryBreakdown, isEmpty);
      expect(notifier.state.categoryBreakdownTotal, 0);

      notifier.dispose();
    });
  });

  group('DashboardNotifier — null user', () {
    late AppDatabase db;

    setUp(() async {
      db = await _setupDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('null userId does not crash and stays in initial state', () async {
      final notifier = DashboardNotifier(
          db, FailingDashboardClient(), FailingMarketDataClient(), null, null);
      await Future.delayed(const Duration(milliseconds: 300));

      expect(notifier.state.isLoading, false);
      expect(notifier.state.netWorth.total, 0);

      notifier.dispose();
    });
  });
}
