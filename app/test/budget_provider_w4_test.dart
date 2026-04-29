/// BudgetProvider unit tests — execution rate computation + offline fallback.
import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/budget_provider.dart';
import 'package:familyledger/generated/proto/budget.pb.dart' as pb;
import 'package:familyledger/generated/proto/budget.pbgrpc.dart';
import 'package:fixnum/fixnum.dart';

// ─── Fake gRPC ResponseFuture ──────────────────────────────────────────────

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
}

// ─── Fake BudgetServiceClient (offline = always throws) ────────────────────

class OfflineBudgetClient extends BudgetServiceClient {
  OfflineBudgetClient() : super(ClientChannel('localhost', port: 1));

  @override
  ResponseFuture<pb.ListBudgetsResponse> listBudgets(
    pb.ListBudgetsRequest request, {CallOptions? options}) =>
      FakeResponseFuture.error(GrpcError.unavailable('offline'));

  @override
  ResponseFuture<pb.GetBudgetExecutionResponse> getBudgetExecution(
    pb.GetBudgetExecutionRequest request, {CallOptions? options}) =>
      FakeResponseFuture.error(GrpcError.unavailable('offline'));

  @override
  ResponseFuture<pb.CreateBudgetResponse> createBudget(
    pb.CreateBudgetRequest request, {CallOptions? options}) =>
      FakeResponseFuture.error(GrpcError.unavailable('offline'));

  @override
  ResponseFuture<pb.DeleteBudgetResponse> deleteBudget(
    pb.DeleteBudgetRequest request, {CallOptions? options}) =>
      FakeResponseFuture.error(GrpcError.unavailable('offline'));

  @override
  ResponseFuture<pb.UpdateBudgetResponse> updateBudget(
    pb.UpdateBudgetRequest request, {CallOptions? options}) =>
      FakeResponseFuture.error(GrpcError.unavailable('offline'));
}

// ─── Fake BudgetServiceClient (online with mock data) ──────────────────────

class OnlineBudgetClient extends BudgetServiceClient {
  final List<pb.Budget> budgets;
  pb.BudgetExecution? execution;

  OnlineBudgetClient({this.budgets = const [], this.execution})
      : super(ClientChannel('localhost', port: 1));

  @override
  ResponseFuture<pb.ListBudgetsResponse> listBudgets(
    pb.ListBudgetsRequest request, {CallOptions? options}) {
    final resp = pb.ListBudgetsResponse()..budgets.addAll(budgets);
    return FakeResponseFuture.value(resp);
  }

  @override
  ResponseFuture<pb.GetBudgetExecutionResponse> getBudgetExecution(
    pb.GetBudgetExecutionRequest request, {CallOptions? options}) {
    if (execution == null) {
      return FakeResponseFuture.error(GrpcError.notFound('no execution'));
    }
    final resp = pb.GetBudgetExecutionResponse()..execution = execution!;
    return FakeResponseFuture.value(resp);
  }
}

void main() {
  group('BudgetNotifier — offline fallback (local DB)', () {
    late AppDatabase db;
    late BudgetNotifier notifier;
    const userId = 'test-user-id';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      notifier = BudgetNotifier(db, OfflineBudgetClient(), userId, '');
    });

    tearDown(() async {
      await db.close();
    });

    test('initial state is loading then resolves (offline = no data)', () async {
      // Wait for loadCurrentMonth to complete
      await Future.delayed(const Duration(milliseconds: 200));
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.currentBudget, isNull);
    });

    test('loadCurrentMonth offline falls back to local DB (empty)', () async {
      await Future.delayed(const Duration(milliseconds: 200));
      expect(notifier.state.budgets, isEmpty);
    });
  });

  group('BudgetNotifier — online with execution data', () {
    late AppDatabase db;
    late BudgetNotifier notifier;
    const userId = 'test-user-id';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final now = DateTime.now();
      final budgetProto = pb.Budget()
        ..id = 'budget-001'
        ..year = now.year
        ..month = now.month
        ..totalAmount = Int64(100000);
      final exec = pb.BudgetExecution()
        ..totalBudget = Int64(100000)
        ..totalSpent = Int64(80000)
        ..executionRate = 0.8;
      notifier = BudgetNotifier(
        db,
        OnlineBudgetClient(budgets: [budgetProto], execution: exec),
        userId,
        '',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('loads budget and execution from gRPC', () async {
      await Future.delayed(const Duration(milliseconds: 500));
      expect(notifier.state.currentBudget, isNotNull);
      expect(notifier.state.execution, isNotNull);
      expect(notifier.state.execution!.executionRate, 0.8);
      expect(notifier.state.execution!.totalSpent, 80000);
    });

    test('execution rate 80% indicates warning threshold', () async {
      await Future.delayed(const Duration(milliseconds: 500));
      expect(notifier.state.execution!.executionRate >= 0.8, isTrue);
    });
  });

  group('BudgetExecutionData — model logic', () {
    test('executionRate 0 when no spending', () {
      const exec = BudgetExecutionData(
        totalBudget: 100000,
        totalSpent: 0,
        executionRate: 0,
        categoryExecutions: [],
      );
      expect(exec.executionRate, 0);
      expect(exec.totalBudget, 100000);
    });

    test('executionRate > 1.0 when overspent', () {
      const exec = BudgetExecutionData(
        totalBudget: 100000,
        totalSpent: 120000,
        executionRate: 1.2,
        categoryExecutions: [],
      );
      expect(exec.executionRate, greaterThan(1.0));
    });

    test('category execution data holds correct structure', () {
      const catExec = CategoryExecutionData(
        categoryId: 'cat-001',
        categoryName: '餐饮',
        budgetAmount: 30000,
        spentAmount: 25000,
        executionRate: 0.833,
      );
      expect(catExec.categoryId, 'cat-001');
      expect(catExec.executionRate, closeTo(0.833, 0.001));
    });
  });
}
