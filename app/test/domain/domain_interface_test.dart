import 'dart:async';

import 'package:familyledger/domain/entities/entities.dart';
import 'package:familyledger/domain/interfaces/interfaces.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/balance_calculator_testable.dart';
import 'mocks/mocks.dart';

/// Pure domain logic tests — zero Drift/SQLite/Flutter dependency.
///
/// Tests exercise:
/// 1. TransactionRepository CRUD + edge cases
/// 2. AccountRepository balance adjustments
/// 3. CategoryRepository hierarchy
/// 4. BalanceCalculator parallel computation
/// 5. Boundary conditions: empty state, duplicates, concurrent ops
void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Transaction Repository
  // ═══════════════════════════════════════════════════════════════════════════

  group('ITransactionRepository', () {
    late InMemoryTransactionRepository repo;

    setUp(() {
      repo = InMemoryTransactionRepository();
    });

    tearDown(() {
      repo.dispose();
    });

    TransactionEntity _makeTxn({
      String id = 'txn-1',
      String userId = 'user-1',
      String accountId = 'acc-1',
      String categoryId = 'cat-1',
      int amountCny = 5000, // ¥50.00
      String type = 'expense',
      DateTime? txnDate,
    }) {
      return TransactionEntity(
        id: id,
        userId: userId,
        accountId: accountId,
        categoryId: categoryId,
        amount: amountCny,
        amountCny: amountCny,
        type: type,
        txnDate: txnDate ?? DateTime.now(),
      );
    }

    test('insert stores transaction and is retrievable by ID', () async {
      final txn = _makeTxn();
      await repo.insert(txn);

      final found = await repo.getById('txn-1');
      expect(found, isNotNull);
      expect(found!.id, 'txn-1');
      expect(found.amountCny, 5000);
    });

    test('insert is idempotent (last-write-wins on duplicate ID)', () async {
      final txn1 = _makeTxn(amountCny: 1000);
      final txn2 = _makeTxn(amountCny: 2000); // same ID

      await repo.insert(txn1);
      await repo.insert(txn2);

      expect(repo.store.length, 1);
      final found = await repo.getById('txn-1');
      expect(found!.amountCny, 2000);
    });

    test('softDelete sets deletedAt, getById returns null for soft-deleted', () async {
      await repo.insert(_makeTxn());
      await repo.softDelete('txn-1');

      final found = await repo.getById('txn-1');
      expect(found, isNull);

      // But still in raw store
      expect(repo.store.length, 1);
      expect(repo.store.first.deletedAt, isNotNull);
    });

    test('hardDelete removes permanently', () async {
      await repo.insert(_makeTxn());
      await repo.hardDelete('txn-1');

      expect(repo.store.length, 0);
      expect(await repo.getById('txn-1'), isNull);
    });

    test('softDelete on non-existent ID is no-op', () async {
      await repo.softDelete('does-not-exist');
      expect(repo.store.length, 0);
    });

    test('hardDelete on non-existent ID is no-op', () async {
      await repo.hardDelete('does-not-exist');
      expect(repo.store.length, 0);
    });

    test('getRecent returns user transactions sorted by date desc', () async {
      final now = DateTime.now();
      await repo.insert(_makeTxn(id: 'a', txnDate: now.subtract(const Duration(days: 2))));
      await repo.insert(_makeTxn(id: 'b', txnDate: now.subtract(const Duration(days: 1))));
      await repo.insert(_makeTxn(id: 'c', txnDate: now));

      final recent = await repo.getRecent('user-1', 10);
      expect(recent.map((t) => t.id).toList(), ['c', 'b', 'a']);
    });

    test('getRecent respects limit', () async {
      for (int i = 0; i < 20; i++) {
        await repo.insert(_makeTxn(
          id: 'txn-$i',
          txnDate: DateTime.now().subtract(Duration(hours: i)),
        ));
      }

      final page = await repo.getRecent('user-1', 5);
      expect(page.length, 5);
    });

    test('getRecent filters by userId', () async {
      await repo.insert(_makeTxn(id: 'a', userId: 'user-1'));
      await repo.insert(_makeTxn(id: 'b', userId: 'user-2'));

      final result = await repo.getRecent('user-1', 10);
      expect(result.length, 1);
      expect(result.first.id, 'a');
    });

    test('getRecent excludes soft-deleted', () async {
      await repo.insert(_makeTxn(id: 'a'));
      await repo.insert(_makeTxn(id: 'b'));
      await repo.softDelete('a');

      final result = await repo.getRecent('user-1', 10);
      expect(result.length, 1);
      expect(result.first.id, 'b');
    });

    test('batchUpsert inserts multiple, overwrites existing', () async {
      await repo.insert(_makeTxn(id: 'existing', amountCny: 100));

      await repo.batchUpsert([
        _makeTxn(id: 'existing', amountCny: 999),
        _makeTxn(id: 'new-1', amountCny: 200),
        _makeTxn(id: 'new-2', amountCny: 300),
      ]);

      expect(repo.store.length, 3);
      final existing = await repo.getById('existing');
      expect(existing!.amountCny, 999);
    });

    test('batchUpsert with empty list is no-op', () async {
      await repo.insert(_makeTxn());
      await repo.batchUpsert([]);
      expect(repo.store.length, 1);
    });

    test('batchHardDelete removes multiple', () async {
      await repo.insert(_makeTxn(id: 'a'));
      await repo.insert(_makeTxn(id: 'b'));
      await repo.insert(_makeTxn(id: 'c'));

      await repo.batchHardDelete(['a', 'c']);
      expect(repo.store.length, 1);
      expect(repo.store.first.id, 'b');
    });

    test('batchHardDelete with non-existent IDs is safe', () async {
      await repo.insert(_makeTxn(id: 'a'));
      await repo.batchHardDelete(['does-not-exist', 'also-missing']);
      expect(repo.store.length, 1);
    });

    test('markSynced updates syncStatus to synced', () async {
      await repo.insert(_makeTxn(id: 'a'));
      await repo.insert(_makeTxn(id: 'b'));

      await repo.markSynced(['a']);

      expect(repo.store.firstWhere((t) => t.id == 'a').syncStatus, 'synced');
      expect(repo.store.firstWhere((t) => t.id == 'b').syncStatus, 'pending');
    });

    test('markFailed updates syncStatus to failed', () async {
      await repo.insert(_makeTxn(id: 'a'));
      await repo.markFailed(['a']);
      expect(repo.store.firstWhere((t) => t.id == 'a').syncStatus, 'failed');
    });

    // ─── Balance Queries ─────────────────────────────────────────────────

    test('getTodayExpense sums only today expense transactions', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      await repo.insert(_makeTxn(id: 'a', amountCny: 1000, type: 'expense', txnDate: today));
      await repo.insert(_makeTxn(id: 'b', amountCny: 2000, type: 'expense', txnDate: today));
      await repo.insert(_makeTxn(id: 'c', amountCny: 500, type: 'income', txnDate: today));
      await repo.insert(_makeTxn(id: 'd', amountCny: 3000, type: 'expense', txnDate: yesterday));

      final todayExp = await repo.getTodayExpense('user-1');
      expect(todayExp, 3000); // 1000 + 2000, ignores income and yesterday
    });

    test('getMonthExpense sums current month expenses', () async {
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 5);
      final lastMonth = DateTime(now.year, now.month - 1, 15);

      await repo.insert(_makeTxn(id: 'a', amountCny: 1000, type: 'expense', txnDate: thisMonth));
      await repo.insert(_makeTxn(id: 'b', amountCny: 2000, type: 'expense', txnDate: thisMonth));
      await repo.insert(_makeTxn(id: 'c', amountCny: 9000, type: 'expense', txnDate: lastMonth));

      final monthExp = await repo.getMonthExpense('user-1');
      expect(monthExp, 3000);
    });

    test('getTotalBalance computes income minus expense', () async {
      await repo.insert(_makeTxn(id: 'income-1', amountCny: 10000, type: 'income'));
      await repo.insert(_makeTxn(id: 'expense-1', amountCny: 3000, type: 'expense'));
      await repo.insert(_makeTxn(id: 'expense-2', amountCny: 2000, type: 'expense'));

      final balance = await repo.getTotalBalance('user-1');
      expect(balance, 5000); // 10000 - 3000 - 2000
    });

    test('balance queries on empty store return 0', () async {
      expect(await repo.getTodayExpense('user-1'), 0);
      expect(await repo.getMonthExpense('user-1'), 0);
      expect(await repo.getTotalBalance('user-1'), 0);
    });

    test('balance queries exclude soft-deleted transactions', () async {
      await repo.insert(_makeTxn(id: 'a', amountCny: 5000, type: 'expense'));
      await repo.softDelete('a');

      expect(await repo.getTodayExpense('user-1'), 0);
      expect(await repo.getTotalBalance('user-1'), 0);
    });

    // ─── Watch Stream ────────────────────────────────────────────────────

    test('watch emits updates after insert', () async {
      final emissions = <List<TransactionEntity>>[];
      final sub = repo.watch('user-1').listen(emissions.add);

      await repo.insert(_makeTxn(id: 'a'));
      await Future.delayed(Duration.zero); // Let stream propagate

      await repo.insert(_makeTxn(id: 'b'));
      await Future.delayed(Duration.zero);

      await sub.cancel();

      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.last.length, 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Account Repository
  // ═══════════════════════════════════════════════════════════════════════════

  group('IAccountRepository', () {
    late InMemoryAccountRepository repo;

    setUp(() {
      repo = InMemoryAccountRepository();
    });

    AccountEntity _makeAccount({
      String id = 'acc-1',
      String userId = 'user-1',
      String name = '银行卡',
      int balance = 100000,
      String? familyId,
    }) {
      return AccountEntity(
        id: id,
        userId: userId,
        name: name,
        type: 'bank_card',
        balance: balance,
        familyId: familyId,
      );
    }

    test('upsert stores account, getById retrieves it', () async {
      await repo.upsert(_makeAccount());

      final found = await repo.getById('acc-1');
      expect(found, isNotNull);
      expect(found!.balance, 100000);
    });

    test('upsert overwrites existing (last-write-wins)', () async {
      await repo.upsert(_makeAccount(balance: 100));
      await repo.upsert(_makeAccount(balance: 999));

      expect(repo.store.length, 1);
      expect((await repo.getById('acc-1'))!.balance, 999);
    });

    test('getActive returns personal accounts only (no family)', () async {
      await repo.upsert(_makeAccount(id: 'personal', familyId: null));
      await repo.upsert(_makeAccount(id: 'family-acc', familyId: 'fam-1'));

      final active = await repo.getActive('user-1');
      expect(active.length, 1);
      expect(active.first.id, 'personal');
    });

    test('getActive filters empty familyId as personal', () async {
      await repo.upsert(_makeAccount(id: 'empty-family', familyId: ''));
      final active = await repo.getActive('user-1');
      expect(active.length, 1);
    });

    test('getByFamily returns only family accounts', () async {
      await repo.upsert(_makeAccount(id: 'a', familyId: 'fam-1'));
      await repo.upsert(_makeAccount(id: 'b', familyId: 'fam-1'));
      await repo.upsert(_makeAccount(id: 'c', familyId: 'fam-2'));

      final result = await repo.getByFamily('fam-1');
      expect(result.length, 2);
    });

    test('adjustBalance adds delta (positive)', () async {
      await repo.upsert(_makeAccount(balance: 10000));
      await repo.adjustBalance('acc-1', 5000);

      final account = await repo.getById('acc-1');
      expect(account!.balance, 15000);
    });

    test('adjustBalance subtracts (negative delta)', () async {
      await repo.upsert(_makeAccount(balance: 10000));
      await repo.adjustBalance('acc-1', -3000);

      final account = await repo.getById('acc-1');
      expect(account!.balance, 7000);
    });

    test('adjustBalance allows overdraft (negative balance)', () async {
      await repo.upsert(_makeAccount(balance: 1000));
      await repo.adjustBalance('acc-1', -5000);

      final account = await repo.getById('acc-1');
      expect(account!.balance, -4000);
    });

    test('adjustBalance on non-existent account is no-op', () async {
      await repo.adjustBalance('does-not-exist', 1000);
      expect(repo.store.length, 0);
    });

    test('delete removes account', () async {
      await repo.upsert(_makeAccount());
      await repo.delete('acc-1');

      expect(await repo.getById('acc-1'), isNull);
      expect(repo.store.length, 0);
    });

    test('delete non-existent account is no-op', () async {
      await repo.delete('does-not-exist');
      expect(repo.store.length, 0);
    });

    test('getActive on empty store returns empty list', () async {
      expect(await repo.getActive('user-1'), isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Category Repository
  // ═══════════════════════════════════════════════════════════════════════════

  group('ICategoryRepository', () {
    late InMemoryCategoryRepository repo;

    setUp(() {
      repo = InMemoryCategoryRepository();
    });

    test('upsert stores category', () async {
      const cat = CategoryEntity(id: 'c1', name: '餐饮', type: 'expense');
      await repo.upsert(cat);

      final found = await repo.getById('c1');
      expect(found, isNotNull);
      expect(found!.name, '餐饮');
    });

    test('getByType filters correctly', () async {
      await repo.upsert(const CategoryEntity(id: 'e1', name: '餐饮', type: 'expense'));
      await repo.upsert(const CategoryEntity(id: 'e2', name: '交通', type: 'expense'));
      await repo.upsert(const CategoryEntity(id: 'i1', name: '工资', type: 'income'));

      final expenses = await repo.getByType('expense');
      expect(expenses.length, 2);

      final incomes = await repo.getByType('income');
      expect(incomes.length, 1);
    });

    test('getAll returns everything', () async {
      await repo.upsert(const CategoryEntity(id: 'a', name: 'A', type: 'expense'));
      await repo.upsert(const CategoryEntity(id: 'b', name: 'B', type: 'income'));

      final all = await repo.getAll();
      expect(all.length, 2);
    });

    test('batchUpsert handles multiple with overwrites', () async {
      await repo.upsert(const CategoryEntity(id: 'c1', name: 'Old', type: 'expense'));

      await repo.batchUpsert(const [
        CategoryEntity(id: 'c1', name: 'New', type: 'expense'),
        CategoryEntity(id: 'c2', name: 'Added', type: 'income'),
      ]);

      expect(repo.store.length, 2);
      final c1 = await repo.getById('c1');
      expect(c1!.name, 'New');
    });

    test('seedForOwner creates default categories', () async {
      await repo.seedForOwner('user-1');

      final all = await repo.getAll();
      expect(all.length, greaterThanOrEqualTo(4));
      expect(all.any((c) => c.type == 'income'), isTrue);
      expect(all.any((c) => c.type == 'expense'), isTrue);
    });

    test('seedForOwner is idempotent', () async {
      await repo.seedForOwner('user-1');
      final count1 = (await repo.getAll()).length;

      await repo.seedForOwner('user-1');
      final count2 = (await repo.getAll()).length;

      expect(count1, count2);
    });

    test('getById non-existent returns null', () async {
      expect(await repo.getById('does-not-exist'), isNull);
    });

    test('getByType on empty store returns empty list', () async {
      expect(await repo.getByType('expense'), isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // BalanceCalculator (parallel computation)
  // ═══════════════════════════════════════════════════════════════════════════

  group('BalanceCalculator', () {
    late InMemoryTransactionRepository txnRepo;
    late BalanceCalculatorTestable calculator;

    setUp(() {
      txnRepo = InMemoryTransactionRepository();
      calculator = BalanceCalculatorTestable(txnRepo);
    });

    tearDown(() {
      txnRepo.dispose();
    });

    test('compute returns zero summary on empty repository', () async {
      final result = await calculator.compute('user-1');
      expect(result.totalBalance, 0);
      expect(result.todayExpense, 0);
      expect(result.monthExpense, 0);
    });

    test('compute aggregates income and expense correctly', () async {
      final now = DateTime.now();
      txnRepo.seed([
        TransactionEntity(
          id: 'i1', userId: 'user-1', accountId: 'a', categoryId: 'c',
          amount: 100000, amountCny: 100000, type: 'income', txnDate: now,
        ),
        TransactionEntity(
          id: 'e1', userId: 'user-1', accountId: 'a', categoryId: 'c',
          amount: 30000, amountCny: 30000, type: 'expense', txnDate: now,
        ),
        TransactionEntity(
          id: 'e2', userId: 'user-1', accountId: 'a', categoryId: 'c',
          amount: 20000, amountCny: 20000, type: 'expense', txnDate: now,
        ),
      ]);

      final result = await calculator.compute('user-1');
      expect(result.totalBalance, 50000); // 100k - 30k - 20k
      expect(result.todayExpense, 50000); // 30k + 20k
      expect(result.monthExpense, 50000);
    });

    test('compute isolates per user (no cross-contamination)', () async {
      final now = DateTime.now();
      txnRepo.seed([
        TransactionEntity(
          id: 'u1', userId: 'user-1', accountId: 'a', categoryId: 'c',
          amount: 5000, amountCny: 5000, type: 'expense', txnDate: now,
        ),
        TransactionEntity(
          id: 'u2', userId: 'user-2', accountId: 'a', categoryId: 'c',
          amount: 99000, amountCny: 99000, type: 'expense', txnDate: now,
        ),
      ]);

      final r1 = await calculator.compute('user-1');
      final r2 = await calculator.compute('user-2');

      expect(r1.totalBalance, -5000);
      expect(r2.totalBalance, -99000);
    });

    test('compute executes three queries in parallel (timing sanity)', () async {
      // All three queries resolve instantly in-memory.
      // Primarily verifies no deadlock in parallel execution.
      txnRepo.seed([
        TransactionEntity(
          id: 'x', userId: 'u', accountId: 'a', categoryId: 'c',
          amount: 1, amountCny: 1, type: 'expense', txnDate: DateTime.now(),
        ),
      ]);

      // Should not throw or hang.
      final result = await calculator.compute('u').timeout(
        const Duration(seconds: 1),
        onTimeout: () => throw TimeoutException('Deadlock detected'),
      );
      expect(result.totalBalance, -1);
    });

    test('compute excludes soft-deleted from all summaries', () async {
      final now = DateTime.now();
      txnRepo.seed([
        TransactionEntity(
          id: 'alive', userId: 'u', accountId: 'a', categoryId: 'c',
          amount: 1000, amountCny: 1000, type: 'expense', txnDate: now,
        ),
        TransactionEntity(
          id: 'dead', userId: 'u', accountId: 'a', categoryId: 'c',
          amount: 9999, amountCny: 9999, type: 'expense', txnDate: now,
          deletedAt: now, // soft-deleted
        ),
      ]);

      final result = await calculator.compute('u');
      expect(result.todayExpense, 1000); // 9999 excluded
      expect(result.totalBalance, -1000);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // OfflineSyncQueue (enqueue/dequeue semantics)
  // ═══════════════════════════════════════════════════════════════════════════

  group('OfflineSyncQueue (interface-level behavior)', () {
    // OfflineSyncQueue currently depends on AppDatabase directly.
    // These tests verify the INTERFACE CONTRACT that any replacement must honor.
    // Once DIP lands (#4), these will test the real queue through its interface.

    late InMemoryTransactionRepository repo;

    setUp(() {
      repo = InMemoryTransactionRepository();
    });

    tearDown(() {
      repo.dispose();
    });

    test('insert followed by markSynced transitions status correctly', () async {
      final txn = TransactionEntity(
        id: 'q1', userId: 'u', accountId: 'a', categoryId: 'c',
        amount: 100, amountCny: 100, type: 'expense',
        txnDate: DateTime.now(), syncStatus: 'pending',
      );
      await repo.insert(txn);
      expect(repo.store.first.syncStatus, 'pending');

      await repo.markSynced(['q1']);
      expect(repo.store.first.syncStatus, 'synced');
    });

    test('markFailed then markSynced recovers to synced', () async {
      final txn = TransactionEntity(
        id: 'q2', userId: 'u', accountId: 'a', categoryId: 'c',
        amount: 100, amountCny: 100, type: 'expense',
        txnDate: DateTime.now(), syncStatus: 'pending',
      );
      await repo.insert(txn);
      await repo.markFailed(['q2']);
      expect(repo.store.first.syncStatus, 'failed');

      await repo.markSynced(['q2']);
      expect(repo.store.first.syncStatus, 'synced');
    });

    test('sync status transitions: pending → synced, pending → failed → synced', () async {
      // State machine verification
      await repo.insert(TransactionEntity(
        id: 's1', userId: 'u', accountId: 'a', categoryId: 'c',
        amount: 1, amountCny: 1, type: 'expense',
        txnDate: DateTime.now(), syncStatus: 'pending',
      ));

      // pending → synced
      await repo.markSynced(['s1']);
      expect(repo.store.first.syncStatus, 'synced');

      // synced → failed (re-sync attempt failed)
      await repo.markFailed(['s1']);
      expect(repo.store.first.syncStatus, 'failed');

      // failed → synced (retry succeeded)
      await repo.markSynced(['s1']);
      expect(repo.store.first.syncStatus, 'synced');
    });
  });
}
