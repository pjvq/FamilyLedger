import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/core/utils/category_uuid.dart';
import 'package:familyledger/data/local/database.dart';

final _catFood = CategoryUUID.generate('test-user', 'expense', '餐饮');
final _catTransport = CategoryUUID.generate('test-user', 'expense', '交通');
final _catSalary = CategoryUUID.generate('test-user', 'income', '工资');

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Since v13+, categories are seeded after auth. Seed for test user.
    await db.seedCategoriesForOwner('test-user');
  });

  tearDown(() async {
    await db.close();
  });

  group('Database schema & seed', () {
    test('creates tables and seeds preset categories with subcategories', () async {
      final cats = await db.getAllCategories();
      final parents = cats.where((c) => c.parentId == null).toList();
      final subs = cats.where((c) => c.parentId != null).toList();
      expect(parents.length, 21);
      expect(subs.length, greaterThan(0));
    });

    test('seeds 14 expense + 7 income parent categories', () async {
      final expense = await db.getCategoriesByType('expense');
      final income = await db.getCategoriesByType('income');
      final expParents = expense.where((c) => c.parentId == null).toList();
      final incParents = income.where((c) => c.parentId == null).toList();
      expect(expParents.length, 14);
      expect(incParents.length, 7);
    });

    test('clearAllData clears all data (categories re-seeded separately)', () async {
      // Verify initial seed
      var cats = await db.getAllCategories();
      var parents = cats.where((c) => c.parentId == null).toList();
      expect(parents.length, 21);

      // Clear all data
      await db.clearAllData();

      // After clearAllData, no categories (re-seed happens after next login)
      cats = await db.getAllCategories();
      expect(cats, isEmpty, reason: 'clearAllData should remove all data');

      // Re-seed manually (simulates post-login behavior)
      await db.seedCategoriesForOwner('test-user');
      cats = await db.getAllCategories();
      parents = cats.where((c) => c.parentId == null).toList();
      final subs = cats.where((c) => c.parentId != null).toList();
      expect(parents.length, 21, reason: 'seedCategoriesForOwner should seed 21 parent categories');
      expect(subs.length, greaterThan(0), reason: 'seedCategoriesForOwner should seed subcategories');

      // Verify they are all preset
      for (final cat in parents) {
        expect(cat.isPreset, true, reason: '${cat.name} should be preset after re-seed');
      }
    });

    test('categories have correct fields', () async {
      final cats = await db.getCategoriesByType('expense');
      final food = cats.firstWhere((c) => c.id == _catFood);
      expect(food.name, '餐饮');
      expect(food.iconKey, 'food');
      expect(food.isPreset, true);
    });
  });

  group('User & Account', () {
    test('register creates user and default account', () async {
      final userId = 'test_user_1';
      await db.into(db.users).insert(UsersCompanion.insert(
            id: userId,
            email: 'test@example.com',
          ));
      await db.insertAccount(AccountsCompanion.insert(
        id: 'acc_default_$userId',
        userId: userId,
        name: '默认账户',
      ));

      final accounts = await db.getAllAccounts(userId);
      expect(accounts.length, 1);
      expect(accounts.first.name, '默认账户');
      expect(accounts.first.balance, 0);
    });

    test('getDefaultAccount returns first account', () async {
      final userId = 'test_user_2';
      await db.into(db.users).insert(UsersCompanion.insert(
            id: userId,
            email: 'test2@example.com',
          ));
      await db.insertAccount(AccountsCompanion.insert(
        id: 'acc_1',
        userId: userId,
        name: '工资卡',
      ));

      final acc = await db.getDefaultAccount(userId);
      expect(acc, isNotNull);
      expect(acc!.name, '工资卡');
    });
  });

  group('Transactions', () {
    late String userId;
    late String accountId;

    setUp(() async {
      userId = 'txn_test_user';
      accountId = 'txn_test_acc';
      await db.into(db.users).insert(UsersCompanion.insert(
            id: userId,
            email: 'txn@example.com',
          ));
      await db.insertAccount(AccountsCompanion.insert(
        id: accountId,
        userId: userId,
        name: '测试账户',
      ));
    });

    test('insert expense and query', () async {
      await db.insertTransaction(TransactionsCompanion.insert(
        id: 'txn_1',
        userId: userId,
        accountId: accountId,
        categoryId: _catFood,
        amount: 3500, // ¥35.00
        amountCny: 3500,
        type: 'expense',
        txnDate: DateTime.now(),
      ));

      final txns = await db.getRecentTransactions(userId, 10);
      expect(txns.length, 1);
      expect(txns.first.amountCny, 3500);
      expect(txns.first.type, 'expense');
    });

    test('insert income and query', () async {
      await db.insertTransaction(TransactionsCompanion.insert(
        id: 'txn_2',
        userId: userId,
        accountId: accountId,
        categoryId: _catSalary,
        amount: 1000000, // ¥10,000.00
        amountCny: 1000000,
        type: 'income',
        txnDate: DateTime.now(),
      ));

      final txns = await db.getRecentTransactions(userId, 10);
      expect(txns.length, 1);
      expect(txns.first.type, 'income');
    });

    test('updateAccountBalance works', () async {
      // Income +10000 cents
      await db.updateAccountBalance(accountId, 10000);
      var acc = await db.getDefaultAccount(userId);
      expect(acc!.balance, 10000);

      // Expense -3500 cents
      await db.updateAccountBalance(accountId, -3500);
      acc = await db.getDefaultAccount(userId);
      expect(acc!.balance, 6500);
    });

    test('getTotalBalance aggregates accounts', () async {
      // getTotalBalance sums transactions, not account balances.
      // Insert income transactions to both accounts.
      await db.insertTransaction(TransactionsCompanion.insert(
        id: 'txn_bal_1',
        userId: userId,
        accountId: accountId,
        categoryId: '',
        type: 'income',
        amount: 50000,
        amountCny: 50000,
        txnDate: DateTime.now(),
      ));

      // Add another account
      await db.insertAccount(AccountsCompanion.insert(
        id: '${accountId}_2',
        userId: userId,
        name: '储蓄卡',
      ));
      await db.insertTransaction(TransactionsCompanion.insert(
        id: 'txn_bal_2',
        userId: userId,
        accountId: '${accountId}_2',
        categoryId: '',
        type: 'income',
        amount: 30000,
        amountCny: 30000,
        txnDate: DateTime.now(),
      ));

      final total = await db.getTotalBalance(userId);
      expect(total, 80000); // ¥800.00
    });

    test('getTodayExpense sums only today expenses', () async {
      // Today expense
      await db.insertTransaction(TransactionsCompanion.insert(
        id: 'txn_today_1',
        userId: userId,
        accountId: accountId,
        categoryId: _catFood,
        amount: 2000,
        amountCny: 2000,
        type: 'expense',
        txnDate: DateTime.now(),
      ));
      // Today income (should not count)
      await db.insertTransaction(TransactionsCompanion.insert(
        id: 'txn_today_2',
        userId: userId,
        accountId: accountId,
        categoryId: _catSalary,
        amount: 50000,
        amountCny: 50000,
        type: 'income',
        txnDate: DateTime.now(),
      ));
      // Yesterday expense (should not count)
      await db.insertTransaction(TransactionsCompanion.insert(
        id: 'txn_yesterday',
        userId: userId,
        accountId: accountId,
        categoryId: _catTransport,
        amount: 1500,
        amountCny: 1500,
        type: 'expense',
        txnDate: DateTime.now().subtract(const Duration(days: 1)),
      ));

      final todayExp = await db.getTodayExpense(userId);
      expect(todayExp, 2000); // Only today's expense
    });

    test('getMonthExpense sums current month expenses', () async {
      final now = DateTime.now();
      // This month
      await db.insertTransaction(TransactionsCompanion.insert(
        id: 'txn_m1',
        userId: userId,
        accountId: accountId,
        categoryId: _catFood,
        amount: 3000,
        amountCny: 3000,
        type: 'expense',
        txnDate: now,
      ));
      await db.insertTransaction(TransactionsCompanion.insert(
        id: 'txn_m2',
        userId: userId,
        accountId: accountId,
        categoryId: _catTransport,
        amount: 1000,
        amountCny: 1000,
        type: 'expense',
        txnDate: now,
      ));

      final monthExp = await db.getMonthExpense(userId);
      expect(monthExp, 4000);
    });
  });

  group('Sync Queue', () {
    test('insert and query pending ops', () async {
      await db.insertSyncOp(SyncQueueCompanion.insert(
        id: 'sync_1',
        entityType: 'transaction',
        entityId: 'txn_1',
        opType: 'create',
        payload: '{"test": true}',
        clientId: 'client_1',
        timestamp: DateTime.now(),
      ));
      await db.insertSyncOp(SyncQueueCompanion.insert(
        id: 'sync_2',
        entityType: 'transaction',
        entityId: 'txn_2',
        opType: 'create',
        payload: '{"test": true}',
        clientId: 'client_1',
        timestamp: DateTime.now(),
      ));

      final pending = await db.getPendingSyncOps(10);
      expect(pending.length, 2);
    });

    test('markSyncOpsUploaded marks as uploaded', () async {
      await db.insertSyncOp(SyncQueueCompanion.insert(
        id: 'sync_3',
        entityType: 'transaction',
        entityId: 'txn_3',
        opType: 'create',
        payload: '{}',
        clientId: 'client_1',
        timestamp: DateTime.now(),
      ));

      await db.markSyncOpsUploaded(['sync_3']);

      final pending = await db.getPendingSyncOps(10);
      expect(pending, isEmpty);
    });
  });

  // 回归：流水页右上角搜索原本只过滤已加载分页数据，未加载的搜不到。
  // searchTransactions 直接查 DB 全量，不受分页影响。
  group('searchTransactions (全量搜索)', () {
    const sUser = 'search_user';
    const sAcct = 'search_acct';
    late String catFood;
    late String catTransport;

    setUp(() async {
      await db.into(db.users).insert(UsersCompanion.insert(
            id: sUser,
            email: 'search@example.com',
          ));
      await db.seedCategoriesForOwner(sUser);
      // 从实际种子数据取分类 id（避免依赖 UUID 推算，种子器多次调用可能去重）。
      final expCats = await db.getCategoriesByType('expense', userId: sUser);
      catFood = expCats.firstWhere((c) => c.name == '餐饮').id;
      catTransport = expCats.firstWhere((c) => c.name == '交通').id;
      await db.insertAccount(AccountsCompanion.insert(
        id: sAcct,
        userId: sUser,
        name: '招商银行',
      ));
      // 插入 60 条交易（超过分页 50），验证搜索不受首页加载限制。
      // 第 55 条带独特备注“蜡烛店”，按日期排序会落在第二页之后。
      final base = DateTime(2026, 1, 1);
      for (var i = 0; i < 60; i++) {
        await db.insertTransaction(TransactionsCompanion.insert(
          id: 'stxn_$i',
          userId: sUser,
          accountId: sAcct,
          categoryId: i.isEven ? catFood : catTransport,
          amount: 1000 + i,
          amountCny: 1000 + i,
          type: 'expense',
          note: Value(i == 55 ? '蜡烛店晚餐' : '日常开销 $i'),
          // i 越大日期越早 → 按 txn_date DESC，i=55 排在较后（第二页之后）。
          txnDate: base.subtract(Duration(days: i)),
        ));
      }
    });

    test('能搜到首页之外的记录（按备注）', () async {
      // 首页只加载 50 条，i=55 不在其中；全量搜索应能找到。
      final page = await db.getTransactionPage(sUser, limit: 50, offset: 0);
      expect(page.any((t) => t.id == 'stxn_55'), isFalse,
          reason: '蜡烛店记录不在首页 50 条内');

      final result = await db.searchTransactions(sUser, '蜡烛店');
      expect(result.items.length, 1);
      expect(result.items.first.id, 'stxn_55');
      expect(result.truncated, isFalse);
    });

    test('按分类名搜索', () async {
      final result = await db.searchTransactions(sUser, '交通');
      // i 为奇数的 30 条用 交通 分类。
      expect(result.items.length, 30);
    });

    test('按账户名搜索', () async {
      final result = await db.searchTransactions(sUser, '招商');
      expect(result.items.length, 60); // 全部交易都在招商银行
    });

    test('超过展示上限时 truncated=true 且只返回 limit 条', () async {
      // 60 条都在招商银行，设 limit=10 应被截断。
      final result = await db.searchTransactions(sUser, '招商', limit: 10);
      expect(result.items.length, 10);
      expect(result.truncated, isTrue);
      // 恰好等于总数时不算截断。
      final exact = await db.searchTransactions(sUser, '招商', limit: 60);
      expect(exact.items.length, 60);
      expect(exact.truncated, isFalse);
    });

    test('空查询返回空结果', () async {
      expect((await db.searchTransactions(sUser, '')).items, isEmpty);
      expect((await db.searchTransactions(sUser, '   ')).items, isEmpty);
    });

    test('LIKE 通配符被转义（% 不匹配全部）', () async {
      // 输入 % 不应被当作“匹配一切”的通配符。
      final result = await db.searchTransactions(sUser, '%');
      expect(result.items, isEmpty, reason: '% 应被转义为字面量，无记录含字面 %');
    });

    test('软删除的记录不被搜到', () async {
      await db.softDeleteTransaction('stxn_55');
      final result = await db.searchTransactions(sUser, '蜡烛店');
      expect(result.items, isEmpty);
    });
  });
}
