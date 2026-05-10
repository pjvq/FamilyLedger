import 'package:drift/native.dart';
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
      expect(food.iconKey, '🍜');
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
}
