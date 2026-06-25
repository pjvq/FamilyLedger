/// Tests for the localized loan / credit-card reminder scheduling
/// (issue #145, P1-F).
///
/// Covers the pure repeat-rule / next-occurrence / fire-time helpers and
/// [LoanReminderService] scheduling + record-write + dedup against the local
/// `notifications` table, using [FakeLocalNotificationService].
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/services/notifications/loan_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'domain/local_notification_service_test.dart'
    show FakeLocalNotificationService;

const _userId = 'user1';

Future<void> _seedUser(AppDatabase db) async {
  await db.into(db.users).insert(
        UsersCompanion.insert(id: _userId, email: 'user1@example.com'),
      );
}

Future<void> _seedLoan(
  AppDatabase db, {
  required String id,
  required String name,
  int totalMonths = 12,
  int paymentDay = 10,
}) async {
  await db.into(db.loans).insert(
        LoansCompanion.insert(
          id: id,
          userId: _userId,
          name: name,
          principal: 1200000,
          remainingPrincipal: 1200000,
          annualRate: 0.04,
          totalMonths: totalMonths,
          paymentDay: paymentDay,
          startDate: DateTime(2026, 1, 1),
        ),
      );
}

Future<void> _seedSchedule(
  AppDatabase db, {
  required String id,
  required String loanId,
  required int monthNumber,
  required int payment,
  required DateTime dueDate,
  bool isPaid = false,
}) async {
  await db.insertLoanSchedule(
    LoanSchedulesCompanion.insert(
      id: id,
      loanId: loanId,
      monthNumber: monthNumber,
      payment: payment,
      principalPart: payment,
      interestPart: 0,
      remainingPrincipal: 0,
      dueDate: dueDate,
      isPaid: Value(isPaid),
    ),
  );
}

void main() {
  group('nextOccurrence (pure repeat rules)', () {
    final base = DateTime(2026, 1, 31, 9);

    test('none returns the same instant', () {
      expect(nextOccurrence(base, RepeatRule.none), base);
    });

    test('daily advances one day', () {
      expect(nextOccurrence(base, RepeatRule.daily), DateTime(2026, 2, 1, 9));
    });

    test('weekly advances seven days', () {
      expect(nextOccurrence(base, RepeatRule.weekly), DateTime(2026, 2, 7, 9));
    });

    test('monthly advances one month (clamps end-of-month overflow)', () {
      // Jan 31 + 1 month overflows Feb -> DateTime normalizes to early March.
      final next = nextOccurrence(base, RepeatRule.monthly);
      expect(next.month, 3);
    });

    test('monthly on a safe day stays on the same day', () {
      final next = nextOccurrence(DateTime(2026, 1, 10, 9), RepeatRule.monthly);
      expect(next, DateTime(2026, 2, 10, 9));
    });

    test('yearly advances one year', () {
      expect(
        nextOccurrence(DateTime(2026, 5, 10, 9), RepeatRule.yearly),
        DateTime(2027, 5, 10, 9),
      );
    });

    test('parse maps known strings, defaults to none', () {
      expect(RepeatRule.parse('monthly'), RepeatRule.monthly);
      expect(RepeatRule.parse('weekly'), RepeatRule.weekly);
      expect(RepeatRule.parse('bogus'), RepeatRule.none);
    });
  });

  group('reminderFireTime (pure)', () {
    test('fires daysBefore days ahead at the reminder hour', () {
      final fire = reminderFireTime(DateTime(2026, 6, 10), 3);
      expect(fire, DateTime(2026, 6, 7, reminderHour));
    });

    test('zero daysBefore fires on the due date', () {
      final fire = reminderFireTime(DateTime(2026, 6, 10, 18), 0);
      expect(fire, DateTime(2026, 6, 10, reminderHour));
    });
  });

  group('effectiveMonthlyDate / nextCreditCardDate (pure)', () {
    test('clamps day 31 to the last day of February', () {
      final d = effectiveMonthlyDate(31, DateTime(2026, 2, 15));
      expect(d, DateTime(2026, 2, 28));
    });

    test('uses this month when the day has not passed', () {
      final d = LoanReminderService.nextCreditCardDate(20, DateTime(2026, 6, 5));
      expect(d, DateTime(2026, 6, 20));
    });

    test('rolls to next month when the day has passed', () {
      final d =
          LoanReminderService.nextCreditCardDate(5, DateTime(2026, 6, 20));
      expect(d, DateTime(2026, 7, 5));
    });
  });

  group('LoanReminderService.scheduleLoanReminders', () {
    late AppDatabase db;
    late FakeLocalNotificationService notifier;
    late LoanReminderService svc;
    final now = DateTime(2026, 6, 1, 8);

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedUser(db);
      notifier = FakeLocalNotificationService();
      svc = LoanReminderService(db, notifier);
    });

    tearDown(() async => db.close());

    Future<List<Loan>> loans() => db.getStandaloneLoans(_userId);

    test('schedules a future unpaid payment at daysBefore the due date',
        () async {
      await _seedLoan(db, id: 'loan1', name: '房贷');
      await _seedSchedule(
        db,
        id: 's1',
        loanId: 'loan1',
        monthNumber: 6,
        payment: 500000,
        dueDate: DateTime(2026, 6, 10),
      );

      await svc.scheduleLoanReminders(
        userId: _userId,
        loans: await loans(),
        daysBefore: 3,
        now: now,
      );

      // Scheduled at 2026-06-07 09:00 (3 days before due, at reminder hour).
      final id =
          LoanReminderService.loanNotificationId('loan1', DateTime(2026, 6, 10));
      expect(notifier.scheduled.containsKey(id), isTrue);
      expect(notifier.scheduled[id]!.when, DateTime(2026, 6, 7, reminderHour));
      expect(notifier.scheduled[id]!.title, '贷款还款提醒');
      expect(notifier.scheduled[id]!.body, contains('第6期'));
      expect(notifier.scheduled[id]!.body, contains('¥5000.00'));

      final records = await db.getNotifications(_userId, 100, 0);
      expect(records, hasLength(1));
      expect(records.single.type, 'loan_reminder');
      final data = jsonDecode(records.single.dataJson) as Map<String, dynamic>;
      expect(data['loan_id'], 'loan1');
      expect(data['due_date'], '2026-06-10');
      expect(data['month_number'], 6);
    });

    test('skips paid schedules', () async {
      await _seedLoan(db, id: 'loan1', name: '房贷');
      await _seedSchedule(
        db,
        id: 's1',
        loanId: 'loan1',
        monthNumber: 6,
        payment: 500000,
        dueDate: DateTime(2026, 6, 10),
        isPaid: true,
      );

      await svc.scheduleLoanReminders(
        userId: _userId,
        loans: await loans(),
        now: now,
      );

      expect(notifier.scheduled, isEmpty);
      expect(await db.getNotifications(_userId, 100, 0), isEmpty);
    });

    test('skips past due dates (fire time already elapsed)', () async {
      await _seedLoan(db, id: 'loan1', name: '房贷');
      await _seedSchedule(
        db,
        id: 's1',
        loanId: 'loan1',
        monthNumber: 5,
        payment: 500000,
        dueDate: DateTime(2026, 5, 10), // before `now`
      );

      await svc.scheduleLoanReminders(
        userId: _userId,
        loans: await loans(),
        now: now,
      );

      expect(notifier.scheduled, isEmpty);
      expect(await db.getNotifications(_userId, 100, 0), isEmpty);
    });

    test('schedules each unpaid month (monthly repeat via schedule rows)',
        () async {
      await _seedLoan(db, id: 'loan1', name: '房贷');
      await _seedSchedule(
        db,
        id: 's6',
        loanId: 'loan1',
        monthNumber: 6,
        payment: 500000,
        dueDate: DateTime(2026, 6, 10),
      );
      await _seedSchedule(
        db,
        id: 's7',
        loanId: 'loan1',
        monthNumber: 7,
        payment: 500000,
        dueDate: DateTime(2026, 7, 10),
      );

      await svc.scheduleLoanReminders(
        userId: _userId,
        loans: await loans(),
        now: now,
      );

      expect(notifier.scheduled.length, 2);
      expect(await db.getNotifications(_userId, 100, 0), hasLength(2));
    });

    test('dedup: re-running does not duplicate records or notifications',
        () async {
      await _seedLoan(db, id: 'loan1', name: '房贷');
      await _seedSchedule(
        db,
        id: 's1',
        loanId: 'loan1',
        monthNumber: 6,
        payment: 500000,
        dueDate: DateTime(2026, 6, 10),
      );

      Future<void> run() => svc.scheduleLoanReminders(
            userId: _userId,
            loans: await loans(),
            now: now,
          );
      await run();
      await run();
      await run();

      expect(await db.getNotifications(_userId, 100, 0), hasLength(1));
      expect(notifier.scheduled.length, 1);
    });
  });

  group('LoanReminderService.scheduleCreditCardReminder', () {
    late AppDatabase db;
    late FakeLocalNotificationService notifier;
    late LoanReminderService svc;
    final now = DateTime(2026, 6, 1, 8);

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedUser(db);
      notifier = FakeLocalNotificationService();
      svc = LoanReminderService(db, notifier);
    });

    tearDown(() async => db.close());

    test('billing day fires on the day, billing type', () async {
      await svc.scheduleCreditCardReminder(
        userId: _userId,
        accountId: 'acc1',
        accountName: '招行卡',
        kind: CreditCardReminderKind.billingDay,
        dayOfMonth: 18,
        now: now,
      );

      final id = LoanReminderService.creditCardNotificationId(
        'acc1',
        CreditCardReminderKind.billingDay,
        DateTime(2026, 6, 18),
      );
      expect(notifier.scheduled[id]!.when, DateTime(2026, 6, 18, reminderHour));
      final records =
          await db.getNotificationsByType(_userId, 'billing_day_reminder');
      expect(records, hasLength(1));
      expect(records.single.title, '信用卡账单日提醒');
    });

    test('payment due fires daysBefore the due day, payment type', () async {
      await svc.scheduleCreditCardReminder(
        userId: _userId,
        accountId: 'acc1',
        accountName: '招行卡',
        kind: CreditCardReminderKind.paymentDue,
        dayOfMonth: 18,
        daysBefore: 3,
        now: now,
      );

      final id = LoanReminderService.creditCardNotificationId(
        'acc1',
        CreditCardReminderKind.paymentDue,
        DateTime(2026, 6, 18),
      );
      // 3 days before the 18th = the 15th.
      expect(notifier.scheduled[id]!.when, DateTime(2026, 6, 15, reminderHour));
      final records =
          await db.getNotificationsByType(_userId, 'payment_due_reminder');
      expect(records, hasLength(1));
      expect(records.single.title, '信用卡还款日提醒');
    });

    test('billing-day and payment-due are independent (distinct types)',
        () async {
      await svc.scheduleCreditCardReminder(
        userId: _userId,
        accountId: 'acc1',
        accountName: '招行卡',
        kind: CreditCardReminderKind.billingDay,
        dayOfMonth: 18,
        now: now,
      );
      await svc.scheduleCreditCardReminder(
        userId: _userId,
        accountId: 'acc1',
        accountName: '招行卡',
        kind: CreditCardReminderKind.paymentDue,
        dayOfMonth: 25,
        now: now,
      );

      expect(notifier.scheduled.length, 2);
      expect(
        await db.getNotificationsByType(_userId, 'billing_day_reminder'),
        hasLength(1),
      );
      expect(
        await db.getNotificationsByType(_userId, 'payment_due_reminder'),
        hasLength(1),
      );
    });

    test('dedup: same account/kind/due date schedules once', () async {
      Future<void> run() => svc.scheduleCreditCardReminder(
            userId: _userId,
            accountId: 'acc1',
            accountName: '招行卡',
            kind: CreditCardReminderKind.billingDay,
            dayOfMonth: 18,
            now: now,
          );
      await run();
      await run();

      expect(
        await db.getNotificationsByType(_userId, 'billing_day_reminder'),
        hasLength(1),
      );
      expect(notifier.scheduled.length, 1);
    });
  });

  group('LoanReminderService notification ids', () {
    test('loan ids are stable and within the loan band', () {
      final due = DateTime(2026, 6, 10);
      final a = LoanReminderService.loanNotificationId('loan1', due);
      final b = LoanReminderService.loanNotificationId('loan1', due);
      expect(a, b);
      expect(a, greaterThanOrEqualTo(NotificationIdRange.loan));
      expect(a, lessThan(NotificationIdRange.billing));
    });

    test('credit-card ids are within the billing band', () {
      final id = LoanReminderService.creditCardNotificationId(
        'acc1',
        CreditCardReminderKind.billingDay,
        DateTime(2026, 6, 18),
      );
      expect(id, greaterThanOrEqualTo(NotificationIdRange.billing));
      expect(id, lessThan(NotificationIdRange.custom));
    });
  });
}
