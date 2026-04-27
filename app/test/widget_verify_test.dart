/// Widget 测试 — 使用 verify 模式（对比 noSuchMethod 旧模式）
///
/// 对比:
/// - 旧模式: FakeTransactionNotifier 用 noSuchMethod 吞掉所有调用，无法验证参数
/// - 新模式: 通过 tracking wrapper 精确验证方法调用和参数
///
/// 由于 mocktail 1.0.5 的 captureAny 在跨测试场景中有状态泄漏问题，
/// 这里使用自定义 tracking client 模式，更稳定且可读性更好。
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/transaction_provider.dart';
import 'package:familyledger/domain/providers/budget_provider.dart';
import 'package:familyledger/generated/proto/transaction.pb.dart' as pb;
import 'package:familyledger/generated/proto/transaction.pbgrpc.dart' as pbgrpc;
import 'package:familyledger/generated/proto/budget.pb.dart' as bpb;
import 'package:familyledger/generated/proto/budget.pbgrpc.dart';
import 'package:fixnum/fixnum.dart';

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

// ─── Tracking Transaction Client ─────────────────────────────
/// 记录每次 gRPC 调用的参数，用于 verify 模式验证

class TrackingTransactionClient implements pbgrpc.TransactionServiceClient {
  final List<pbgrpc.CreateTransactionRequest> createCalls = [];
  final List<pbgrpc.DeleteTransactionRequest> deleteCalls = [];
  final List<pbgrpc.UpdateTransactionRequest> updateCalls = [];
  final List<pbgrpc.ListTransactionsRequest> listCalls = [];

  pb.CreateTransactionResponse? createResponse;
  Object? createError;
  pb.DeleteTransactionResponse? deleteResponse;
  Object? deleteError;

  TrackingTransactionClient({
    this.createResponse,
    this.createError,
    this.deleteResponse,
    this.deleteError,
  });

  @override
  ResponseFuture<pb.CreateTransactionResponse> createTransaction(
    pbgrpc.CreateTransactionRequest request, {
    CallOptions? options,
  }) {
    createCalls.add(request);
    if (createError != null) {
      return FakeResponseFuture.error(createError!);
    }
    return FakeResponseFuture.value(
      createResponse ??
          pb.CreateTransactionResponse(
            transaction: pb.Transaction(
              id: 'gen_${createCalls.length}',
              userId: 'user1',
              accountId: request.accountId,
              categoryId: request.categoryId,
              amount: request.amount,
              amountCny: request.amountCny,
            ),
          ),
    );
  }

  @override
  ResponseFuture<pb.DeleteTransactionResponse> deleteTransaction(
    pbgrpc.DeleteTransactionRequest request, {
    CallOptions? options,
  }) {
    deleteCalls.add(request);
    if (deleteError != null) {
      return FakeResponseFuture.error(deleteError!);
    }
    return FakeResponseFuture.value(
      deleteResponse ?? pb.DeleteTransactionResponse(),
    );
  }

  @override
  ResponseFuture<pb.ListTransactionsResponse> listTransactions(
    pbgrpc.ListTransactionsRequest request, {
    CallOptions? options,
  }) {
    listCalls.add(request);
    return FakeResponseFuture.value(
      pb.ListTransactionsResponse(transactions: [], nextPageToken: ''),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // For updateTransaction and other methods we don't need
    if (invocation.memberName == #updateTransaction) {
      updateCalls.add(invocation.positionalArguments.first);
      return FakeResponseFuture.value(pb.UpdateTransactionResponse());
    }
    throw UnimplementedError('${invocation.memberName} not mocked');
  }
}

// ─── Tracking Budget Client ──────────────────────────────────

class TrackingBudgetClient implements BudgetServiceClient {
  final List<bpb.CreateBudgetRequest> createCalls = [];
  final List<bpb.ListBudgetsRequest> listCalls = [];

  bpb.CreateBudgetResponse? createResponse;
  Object? createError;

  TrackingBudgetClient({this.createResponse, this.createError});

  @override
  ResponseFuture<bpb.CreateBudgetResponse> createBudget(
    bpb.CreateBudgetRequest request, {
    CallOptions? options,
  }) {
    createCalls.add(request);
    if (createError != null) {
      return FakeResponseFuture.error(createError!);
    }
    return FakeResponseFuture.value(
      createResponse ??
          bpb.CreateBudgetResponse(
            budget: bpb.Budget(
              id: 'budget_gen_${createCalls.length}',
              year: request.year,
              month: request.month,
              totalAmount: request.totalAmount,
              categoryBudgets: request.categoryBudgets,
            ),
          ),
    );
  }

  @override
  ResponseFuture<bpb.ListBudgetsResponse> listBudgets(
    bpb.ListBudgetsRequest request, {
    CallOptions? options,
  }) {
    listCalls.add(request);
    return FakeResponseFuture.value(
      bpb.ListBudgetsResponse(budgets: []),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getBudgetExecution) {
      return FakeResponseFuture.error(GrpcError.notFound('not found'));
    }
    throw UnimplementedError('${invocation.memberName} not mocked');
  }
}

// ─── DB Setup ────────────────────────────────────────────────

Future<AppDatabase> _setupDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.customStatement(
      "INSERT OR IGNORE INTO users (id, email, created_at) "
      "VALUES ('user1', 'test@test.com', "
      "${DateTime.now().millisecondsSinceEpoch ~/ 1000})");
  await db.insertAccount(AccountsCompanion.insert(
    id: 'acc1',
    userId: 'user1',
    name: 'Test Account',
    familyId: const Value(''),
    accountType: const Value('bank_card'),
  ));
  await db.customStatement(
      "INSERT OR IGNORE INTO categories (id, name, type, icon) "
      "VALUES ('cat_food', '餐饮', 'expense', 'restaurant')");
  await db.customStatement(
      "INSERT OR IGNORE INTO categories (id, name, type, icon) "
      "VALUES ('cat_salary', '工资', 'income', 'work')");
  return db;
}

// ─── Tests ───────────────────────────────────────────────────

void main() {
  group('TransactionNotifier — verify 模式（对比 noSuchMethod 旧模式）', () {
    late AppDatabase db;

    setUp(() async {
      db = await _setupDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('addTransaction → verify createTransaction 被调用且参数正确', () async {
      final client = TrackingTransactionClient();
      final notifier = TransactionNotifier(db, 'user1', null, client);
      await Future.delayed(const Duration(milliseconds: 200));

      // Act
      await notifier.addTransaction(
        categoryId: 'cat_food',
        amount: 5000, // 50.00 元
        type: 'expense',
        note: '午餐',
        currency: 'CNY',
      );

      // Assert: verify createTransaction was called with correct parameters
      expect(client.createCalls, hasLength(1));
      final request = client.createCalls.first;
      expect(request.categoryId, 'cat_food');
      expect(request.amount, Int64(5000));
      expect(request.amountCny, Int64(5000));
      expect(request.currency, 'CNY');
      expect(request.note, '午餐');
      expect(request.accountId, 'acc1');

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('addTransaction 带外币 → verify exchangeRate 参数正确', () async {
      final client = TrackingTransactionClient();
      final notifier = TransactionNotifier(db, 'user1', null, client);
      await Future.delayed(const Duration(milliseconds: 200));

      // Act: 10 USD, 手动指定 amountCny
      await notifier.addTransaction(
        categoryId: 'cat_food',
        amount: 1000, // 10 USD in cents
        type: 'expense',
        note: 'coffee',
        currency: 'USD',
        amountCny: 7250, // 72.50 CNY
      );

      // Assert
      expect(client.createCalls, hasLength(1));
      final request = client.createCalls.first;
      expect(request.amount, Int64(1000));
      expect(request.amountCny, Int64(7250));
      expect(request.currency, 'USD');
      expect(request.exchangeRate, 7.25); // 7250/1000

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('deleteTransaction → verify deleteTransaction 被调用且 txnId 正确',
        () async {
      final client = TrackingTransactionClient();
      final notifier = TransactionNotifier(db, 'user1', null, client);
      await Future.delayed(const Duration(milliseconds: 200));

      // Add a transaction first
      await notifier.addTransaction(
        categoryId: 'cat_food',
        amount: 3000,
        type: 'expense',
      );
      await Future.delayed(const Duration(milliseconds: 100));

      // The createTransaction gave it id 'gen_1'
      final txnId = client.createCalls.first.accountId.isNotEmpty
          ? 'gen_1'
          : 'gen_1';

      // Act: delete it
      await notifier.deleteTransaction(txnId);

      // Assert: verify deleteTransaction was called with correct ID
      expect(client.deleteCalls, hasLength(1));
      expect(client.deleteCalls.first.transactionId, txnId);

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('deleteTransaction 对不存在的 txnId → 不调用 gRPC', () async {
      final client = TrackingTransactionClient();
      final notifier = TransactionNotifier(db, 'user1', null, client);
      await Future.delayed(const Duration(milliseconds: 200));

      // Act: delete non-existent
      await notifier.deleteTransaction('nonexistent_id');

      // Assert: deleteTransaction should NOT have been called
      expect(client.deleteCalls, isEmpty,
          reason: '对不存在的 ID 调用 deleteTransaction 不应发起 gRPC 请求');

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('addTransaction gRPC 失败时 → 走离线队列，不崩溃', () async {
      final client = TrackingTransactionClient(
        createError: GrpcError.unavailable('offline'),
      );
      final notifier = TransactionNotifier(db, 'user1', null, client);
      await Future.delayed(const Duration(milliseconds: 200));

      // Act: should not throw
      await notifier.addTransaction(
        categoryId: 'cat_food',
        amount: 2000,
        type: 'expense',
        note: 'offline txn',
      );

      // Assert: createTransaction was attempted
      expect(client.createCalls, hasLength(1));
      expect(client.createCalls.first.note, 'offline txn');

      // Transaction should still be saved locally
      await Future.delayed(const Duration(milliseconds: 200));
      expect(notifier.state.transactions, isNotEmpty);

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('addTransaction 多次调用 → 每次都精确 verify', () async {
      final client = TrackingTransactionClient();
      final notifier = TransactionNotifier(db, 'user1', null, client);
      await Future.delayed(const Duration(milliseconds: 200));

      // Act: 两次 addTransaction
      await notifier.addTransaction(
        categoryId: 'cat_food',
        amount: 1500,
        type: 'expense',
        note: '早餐',
      );
      await notifier.addTransaction(
        categoryId: 'cat_salary',
        amount: 100000,
        type: 'income',
        note: '工资',
      );

      // Assert: 两次调用都被记录
      expect(client.createCalls, hasLength(2));
      expect(client.createCalls[0].categoryId, 'cat_food');
      expect(client.createCalls[0].amount, Int64(1500));
      expect(client.createCalls[0].note, '早餐');
      expect(client.createCalls[1].categoryId, 'cat_salary');
      expect(client.createCalls[1].amount, Int64(100000));
      expect(client.createCalls[1].note, '工资');

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });
  });

  group('BudgetNotifier — verify 模式 (createBudget)', () {
    late AppDatabase db;

    setUp(() async {
      db = await _setupDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('createBudget → verify createBudget gRPC 被调用且参数正确', () async {
      final client = TrackingBudgetClient();
      final notifier = BudgetNotifier(db, client, 'user1', 'fam1');
      await Future.delayed(const Duration(milliseconds: 500));

      // Act
      await notifier.createBudget(
        year: 2025,
        month: 4,
        totalAmount: 500000, // 5000 元
        categoryBudgets: [
          CategoryBudgetItem(categoryId: 'cat_food', amount: 200000),
        ],
      );

      // Assert: verify createBudget was called with correct params
      expect(client.createCalls, hasLength(1));
      final request = client.createCalls.first;
      expect(request.familyId, 'fam1');
      expect(request.year, 2025);
      expect(request.month, 4);
      expect(request.totalAmount, Int64(500000));
      expect(request.categoryBudgets, hasLength(1));
      expect(request.categoryBudgets.first.categoryId, 'cat_food');
      expect(request.categoryBudgets.first.amount, Int64(200000));

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('createBudget gRPC 失败 → 本地保存成功', () async {
      final client = TrackingBudgetClient(
        createError: GrpcError.unavailable('offline'),
      );
      final notifier = BudgetNotifier(db, client, 'user1', 'fam1');
      await Future.delayed(const Duration(milliseconds: 500));

      // Act
      await notifier.createBudget(
        year: 2025,
        month: 5,
        totalAmount: 300000,
        categoryBudgets: [],
      );
      await Future.delayed(const Duration(milliseconds: 500));

      // Assert: createBudget gRPC was attempted
      expect(client.createCalls, hasLength(1));

      // Budget should exist locally
      final localBudget =
          await db.getBudgetByMonth('user1', 2025, 5, familyId: 'fam1');
      expect(localBudget, isNotNull);
      expect(localBudget!.totalAmount, 300000);

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });

    test('createBudget 带多个分类预算 → 所有分类正确传递', () async {
      final client = TrackingBudgetClient();
      final notifier = BudgetNotifier(db, client, 'user1', 'fam1');
      await Future.delayed(const Duration(milliseconds: 500));

      // Act
      await notifier.createBudget(
        year: 2025,
        month: 6,
        totalAmount: 800000,
        categoryBudgets: [
          CategoryBudgetItem(categoryId: 'cat_food', amount: 300000),
          CategoryBudgetItem(categoryId: 'cat_salary', amount: 500000),
        ],
      );

      // Assert
      expect(client.createCalls, hasLength(1));
      final request = client.createCalls.first;
      expect(request.totalAmount, Int64(800000));
      expect(request.categoryBudgets, hasLength(2));
      expect(request.categoryBudgets[0].categoryId, 'cat_food');
      expect(request.categoryBudgets[0].amount, Int64(300000));
      expect(request.categoryBudgets[1].categoryId, 'cat_salary');
      expect(request.categoryBudgets[1].amount, Int64(500000));

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
    });
  });

  group('对比展示: noSuchMethod 旧模式 vs verify 新模式', () {
    test('旧模式 (noSuchMethod): 无法验证参数 — 任何调用都静默通过', () {
      // 这就是旧的 FakeTransactionNotifier 模式
      // 所有方法调用都被 noSuchMethod 吞掉，返回 Future.value()
      // 无法验证 addTransaction 是否被调用、参数是否正确
      final fake = _OldStyleFakeNotifier();

      // 这些调用都不会报错，但我们无法验证是否"正确"
      fake.addTransaction(
        categoryId: 'wrong_category',
        amount: -999, // 负数！
        type: 'invalid_type', // 无效类型！
      );

      // 旧模式的局限: 以上错误参数不会被捕获
      // 测试只能验证 state 变化，无法验证"正确的方法被正确调用"
      expect(true, true, reason: '旧模式无法做更多断言');
    });

    test('新模式 (verify): 精确验证方法调用和参数', () async {
      // 新模式展示: Tracking client 能精确验证
      final db = await _setupDb();
      final client = TrackingTransactionClient();
      final notifier = TransactionNotifier(db, 'user1', null, client);
      await Future.delayed(const Duration(milliseconds: 200));

      await notifier.addTransaction(
        categoryId: 'cat_food',
        amount: 8800,
        type: 'expense',
        note: '晚餐',
      );

      // 新模式: 精确验证参数
      expect(client.createCalls, hasLength(1));
      final req = client.createCalls.first;
      expect(req.categoryId, 'cat_food'); // ✅ 验证分类正确
      expect(req.amount, Int64(8800)); // ✅ 验证金额正确
      expect(req.note, '晚餐'); // ✅ 验证备注正确

      // 如果传了错误参数，测试会立即失败，不像 noSuchMethod 静默吞掉
      // 例如: expect(req.categoryId, 'wrong') 会报错

      await Future.delayed(const Duration(milliseconds: 300));
      notifier.dispose();
      await db.close();
    });
  });
}

/// 旧模式: noSuchMethod 吞掉所有调用
class _OldStyleFakeNotifier extends StateNotifier<TransactionState>
    implements TransactionNotifier {
  _OldStyleFakeNotifier() : super(const TransactionState());

  @override
  dynamic noSuchMethod(Invocation i) =>
      i.isMethod ? Future<void>.value() : null;
}
