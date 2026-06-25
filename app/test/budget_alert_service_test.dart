/// Tests for the localized budget overspend check (issue #144, P1-E).
///
/// Covers [BudgetAlertService] threshold detection / record-write / on-device
/// notification / dedup, plus integration through [BudgetNotifier]'s offline
/// (local DB) execution path.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/budget_provider.dart';
import 'package:familyledger/domain/services/notifications/budget_alert_service.dart';

import 'budget_provider_w4_test.dart' show OfflineBudgetClient;
import 'domain/local_notification_service_test.dart'
    show FakeLocalNotificationService;

const _userId = 'user1';

Future<void> _seedUser(AppDatabase db) async {
  await db.into(db.users).insert(
        UsersCompanion.insert(id: _userId, email: 'user1@example.com'),
      );
}

Future<void> _seedAccount(AppDatabase db, String id) async {
  await db.insertAccount(
    AccountsCompanion.insert(
      id: id,
      userId: _userId,
      name: 'Account $id',
      accountType: const Value('bank_card'),
      balance: const Value(0),
    ),
  );
}

Future<void> _seedExpense(
  AppDatabase db, {
  required String id,
  required String accountId,
  required String categoryId,
  required int amountCny,
  required DateTime txnDate,
}) async {
  await db.insertTransaction(
    TransactionsCompanion.insert(
      id: id,
      userId: _userId,
      accountId: accountId,
      categoryId: categoryId,
      amount: amountCny,
      amountCny: amountCny,
      type: 'expense',
      txnDate: txnDate,
    ),
  );
}

void main() {
  group('BudgetAlertService.levelFor (pure threshold logic)', () {
    test('below 80% is no alert', () {
      expect(BudgetAlertService.levelFor(0.0), isNull);
      expect(BudgetAlertService.levelFor(0.5), isNull);
      expect(BudgetAlertService.levelFor(0.7999), isNull);
    });

    test('80%–<100% is a warning', () {
      expect(BudgetAlertService.levelFor(0.8), BudgetAlertLevel.warning);
      expect(BudgetAlertService.levelFor(0.95), BudgetAlertLevel.warning);
      expect(BudgetAlertService.levelFor(0.9999), BudgetAlertLevel.warning);
    });

    test('>=100% is exceeded', () {
      expect(BudgetAlertService.levelFor(1.0), BudgetAlertLevel.exceeded);
      expect(BudgetAlertService.levelFor(1.5), BudgetAlertLevel.exceeded);
    });
  });

  group('BudgetAlertService.checkBudget', () {
    late AppDatabase db;
    late FakeLocalNotificationService notifier;
    late BudgetAlertService svc;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedUser(db);
      notifier = FakeLocalNotificationService();
      svc = BudgetAlertService(db, notifier);
    });

    tearDown(() async => db.close());

    test('no alert below 80%', () async {
      await svc.checkBudget(
        userId: _userId,
        budgetId: 'b1',
        year: 2026,
        month: 6,
        totalBudget: 100000,
        totalSpent: 50000,
      );
      expect(notifier.shown, isEmpty);
      expect(await db.getNotifications(_userId, 100, 0), isEmpty);
    });

    test('warning at 80%: writes record + fires notification', () async {
      await svc.checkBudget(
        userId: _userId,
        budgetId: 'b1',
        year: 2026,
        month: 6,
        totalBudget: 100000,
        totalSpent: 80000,
      );

      expect(notifier.shown, hasLength(1));
      expect(notifier.shown.single.title, '预算预警提醒');
      expect(notifier.shown.single.body, contains('80%'));

      final records = await db.getNotifications(_userId, 100, 0);
      expect(records, hasLength(1));
      expect(records.single.type, 'budget_warning');
      final data = jsonDecode(records.single.dataJson) as Map<String, dynamic>;
      expect(data['budget_id'], 'b1');
      expect(data['year'], 2026);
      expect(data['month'], 6);
    });

    test('exceeded at 100%: budget_exceeded type', () async {
      await svc.checkBudget(
        userId: _userId,
        budgetId: 'b1',
        year: 2026,
        month: 6,
        totalBudget: 100000,
        totalSpent: 120000,
      );

      expect(notifier.shown, hasLength(1));
      expect(notifier.shown.single.title, '预算超支提醒');
      final records = await db.getNotifications(_userId, 100, 0);
      expect(records.single.type, 'budget_exceeded');
    });

    test('dedup: same budget/period/level alerts only once', () async {
      Future<void> run() => svc.checkBudget(
            userId: _userId,
            budgetId: 'b1',
            year: 2026,
            month: 6,
            totalBudget: 100000,
            totalSpent: 85000,
          );
      await run();
      await run();
      await run();

      expect(notifier.shown, hasLength(1));
      expect(await db.getNotifications(_userId, 100, 0), hasLength(1));
    });

    test('warning then exceeded both fire (distinct levels)', () async {
      await svc.checkBudget(
        userId: _userId,
        budgetId: 'b1',
        year: 2026,
        month: 6,
        totalBudget: 100000,
        totalSpent: 85000,
      );
      await svc.checkBudget(
        userId: _userId,
        budgetId: 'b1',
        year: 2026,
        month: 6,
        totalBudget: 100000,
        totalSpent: 110000,
      );

      expect(notifier.shown, hasLength(2));
      final records = await db.getNotifications(_userId, 100, 0);
      expect(
        records.map((n) => n.type).toSet(),
        {'budget_warning', 'budget_exceeded'},
      );
    });

    test('different periods are independent', () async {
      await svc.checkBudget(
        userId: _userId,
        budgetId: 'b1',
        year: 2026,
        month: 6,
        totalBudget: 100000,
        totalSpent: 90000,
      );
      await svc.checkBudget(
        userId: _userId,
        budgetId: 'b1',
        year: 2026,
        month: 7,
        totalBudget: 100000,
        totalSpent: 90000,
      );
      expect(notifier.shown, hasLength(2));
    });

    test('zero budget is ignored (no division)', () async {
      await svc.checkBudget(
        userId: _userId,
        budgetId: 'b1',
        year: 2026,
        month: 6,
        totalBudget: 0,
        totalSpent: 5000,
      );
      expect(notifier.shown, isEmpty);
    });

    test('notificationId is stable and in the budget band', () {
      final id1 = BudgetAlertService.notificationId(
        'b1',
        2026,
        6,
        BudgetAlertLevel.warning,
      );
      final id2 = BudgetAlertService.notificationId(
        'b1',
        2026,
        6,
        BudgetAlertLevel.warning,
      );
      expect(id1, id2);
      expect(id1, greaterThanOrEqualTo(100000));
      expect(id1, lessThan(200000));
    });

    test('dedup ignores a same-period notification of a different type',
        () async {
      // A warning for b1/2026-6 already exists.
      await svc.checkBudget(
        userId: _userId,
        budgetId: 'b1',
        year: 2026,
        month: 6,
        totalBudget: 100000,
        totalSpent: 85000,
      );
      // An exceeded check for the same budget/period must still fire: the typed
      // dedup query filters by type, so the warning record does not mask it.
      await svc.checkBudget(
        userId: _userId,
        budgetId: 'b1',
        year: 2026,
        month: 6,
        totalBudget: 100000,
        totalSpent: 110000,
      );

      final warnings =
          await db.getNotificationsByType(_userId, 'budget_warning');
      final exceeded =
          await db.getNotificationsByType(_userId, 'budget_exceeded');
      expect(warnings, hasLength(1));
      expect(exceeded, hasLength(1));
    });
  });

  group('AppDatabase.getNotificationsByType', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedUser(db);
    });

    tearDown(() async => db.close());

    Future<void> insert(String id, String type, {DateTime? createdAt}) =>
        db.insertNotification(
          NotificationsCompanion.insert(
            id: id,
            userId: _userId,
            type: type,
            title: 't',
            body: 'b',
            createdAt:
                createdAt == null ? const Value.absent() : Value(createdAt),
          ),
        );

    test('returns only rows of the requested type, newest first', () async {
      await insert('w1', 'budget_warning',
          createdAt: DateTime(2026, 6, 1));
      await insert('e1', 'budget_exceeded',
          createdAt: DateTime(2026, 6, 2));
      await insert('w2', 'budget_warning',
          createdAt: DateTime(2026, 6, 3));

      final warnings =
          await db.getNotificationsByType(_userId, 'budget_warning');
      expect(warnings.map((n) => n.id), ['w2', 'w1']);

      final exceeded =
          await db.getNotificationsByType(_userId, 'budget_exceeded');
      expect(exceeded.map((n) => n.id), ['e1']);
    });

    test('honors the limit', () async {
      await insert('w1', 'budget_warning');
      await insert('w2', 'budget_warning');
      await insert('w3', 'budget_warning');

      final rows =
          await db.getNotificationsByType(_userId, 'budget_warning', limit: 2);
      expect(rows, hasLength(2));
    });

    test('empty when no rows of that type exist', () async {
      await insert('e1', 'budget_exceeded');
      final rows = await db.getNotificationsByType(_userId, 'budget_warning');
      expect(rows, isEmpty);
    });
  });

  group('BudgetNotifier integration (offline local execution)', () {
    late AppDatabase db;
    late FakeLocalNotificationService notifier;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedUser(db);
      await _seedAccount(db, 'acc1');
      notifier = FakeLocalNotificationService();
    });

    tearDown(() async => db.close());

    test('fires a warning when monthly spend crosses 80%', () async {
      final now = DateTime.now();
      // Budget 1000.00, spend 850.00 (85%) this month.
      await db.insertBudget(
        BudgetsCompanion.insert(
          id: 'budget-1',
          userId: _userId,
          year: now.year,
          month: now.month,
          totalAmount: 100000,
        ),
      );
      await _seedExpense(
        db,
        id: 'txn-1',
        accountId: 'acc1',
        categoryId: 'cat-1',
        amountCny: 85000,
        txnDate: DateTime(now.year, now.month, now.day),
      );

      BudgetNotifier(
        db,
        OfflineBudgetClient(),
        _userId,
        '',
        alertService: BudgetAlertService(db, notifier),
      );

      // Allow loadCurrentMonth() (offline fallback -> local execution) to run.
      await Future.delayed(const Duration(milliseconds: 300));

      expect(notifier.shown, hasLength(1));
      expect(notifier.shown.single.title, '预算预警提醒');
      final records = await db.getNotifications(_userId, 100, 0);
      expect(records.single.type, 'budget_warning');
    });

    test('no alert when under threshold', () async {
      final now = DateTime.now();
      await db.insertBudget(
        BudgetsCompanion.insert(
          id: 'budget-1',
          userId: _userId,
          year: now.year,
          month: now.month,
          totalAmount: 100000,
        ),
      );
      await _seedExpense(
        db,
        id: 'txn-1',
        accountId: 'acc1',
        categoryId: 'cat-1',
        amountCny: 30000,
        txnDate: DateTime(now.year, now.month, now.day),
      );

      BudgetNotifier(
        db,
        OfflineBudgetClient(),
        _userId,
        '',
        alertService: BudgetAlertService(db, notifier),
      );
      await Future.delayed(const Duration(milliseconds: 300));

      expect(notifier.shown, isEmpty);
    });
  });
}
