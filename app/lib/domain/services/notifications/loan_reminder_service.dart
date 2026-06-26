import 'dart:convert';
import 'dart:developer' as dev;

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../data/local/database.dart' as db;
import 'local_notification_service.dart';

/// Repeat rule for a recurring reminder, mirroring the server's
/// `custom_reminders.repeat_rule` vocabulary so localized scheduling matches
/// the previous server behaviour.
enum RepeatRule {
  none,
  daily,
  weekly,
  monthly,
  yearly;

  static RepeatRule parse(String raw) {
    switch (raw) {
      case 'daily':
        return RepeatRule.daily;
      case 'weekly':
        return RepeatRule.weekly;
      case 'monthly':
        return RepeatRule.monthly;
      case 'yearly':
        return RepeatRule.yearly;
      default:
        return RepeatRule.none;
    }
  }
}

/// Pure next-occurrence calculation, ported from the server's `nextOccurrence`
/// (`server/internal/notify/service.go`). No side effects — directly unit
/// testable.
///
/// For [RepeatRule.none] the same instant is returned (the caller treats it as
/// a one-shot). For monthly/yearly, day-of-month overflow follows Dart's
/// `DateTime` normalization (e.g. Jan 31 + 1 month → Mar 3, not Feb 28) — this
/// is overflow normalization, not clamping.
DateTime nextOccurrence(DateTime current, RepeatRule rule) {
  switch (rule) {
    case RepeatRule.daily:
      return current.add(const Duration(days: 1));
    case RepeatRule.weekly:
      return current.add(const Duration(days: 7));
    case RepeatRule.monthly:
      return DateTime(
        current.year,
        current.month + 1,
        current.day,
        current.hour,
        current.minute,
      );
    case RepeatRule.yearly:
      return DateTime(
        current.year + 1,
        current.month,
        current.day,
        current.hour,
        current.minute,
      );
    case RepeatRule.none:
      return current;
  }
}

/// The wall-clock time of day at which date-based reminders fire.
///
/// Reminders are date-level (a due *day*), so we pick a fixed, user-friendly
/// hour rather than midnight. 9:00 local matches the server's previous
/// once-a-day batch cadence closely enough for a personal-finance reminder.
const int reminderHour = 9;

/// Computes the next fire time for a date-based reminder: [daysBefore] days
/// before [dueDate], at [reminderHour] local time. Pure.
DateTime reminderFireTime(DateTime dueDate, int daysBefore) {
  final day = DateTime(dueDate.year, dueDate.month, dueDate.day)
      .subtract(Duration(days: daysBefore));
  return DateTime(day.year, day.month, day.day, reminderHour);
}

/// Which kind of credit-card reminder a given day represents.
enum CreditCardReminderKind {
  billingDay,
  paymentDue;

  String get notificationType => this == CreditCardReminderKind.billingDay
      ? 'billing_day_reminder'
      : 'payment_due_reminder';
}

/// Resolves a monthly recurring day-of-month (e.g. billing day 31) to the
/// effective date in [reference]'s month, clamping to the month's length the
/// way the server does (31st billing day fires on Feb 28). Pure.
DateTime effectiveMonthlyDate(int dayOfMonth, DateTime reference) {
  final daysInMonth = DateTime(reference.year, reference.month + 1, 0).day;
  final day = dayOfMonth.clamp(1, daysInMonth);
  return DateTime(reference.year, reference.month, day);
}

/// Localized port of the server `notify` reminder jobs
/// (`CheckLoanReminders` / `CheckCreditCardReminders`), issue #145 / P1-F.
///
/// Instead of a server cron creating notification rows that get pushed, the
/// client pre-schedules **date-based** on-device notifications
/// (`UNCalendarNotificationTrigger` on iOS — survives without Background App
/// Refresh) for upcoming loan payments and credit-card billing/payment days.
///
/// Mirrors [BudgetAlertService] structurally: each fired reminder also writes a
/// row into the local `notifications` table so the in-app notification list
/// renders identically regardless of origin, and dedup runs against that table
/// via a narrow typed query.
class LoanReminderService {
  LoanReminderService(this._db, this._notifications);

  final db.AppDatabase _db;
  final LocalNotificationService _notifications;

  static const _uuid = Uuid();

  /// Serializes overlapping [scheduleLoanReminders] runs. The reactive
  /// scheduler provider can rebuild rapidly (loan list changes); chaining
  /// keeps runs sequential so they don't race on the dedup read + insert.
  Future<void> _loanRun = Future<void>.value();

  /// Notification `type` for loan-payment reminders (matches the server).
  static const loanType = 'loan_reminder';

  /// Default days-before window (server default `reminder_days_before`).
  static const int defaultDaysBefore = 3;

  /// Stable OS-notification-slot id within the loan band, keyed on loan + due
  /// date so re-scheduling the same payment reuses one slot. The durable dedup
  /// key is the persisted `data_json` (see [_existingKeys]); this id being
  /// ephemeral, `hashCode % band` is acceptable (see [BudgetAlertService]).
  ///
  /// NOTE: native-only invariant — `String.hashCode` differs between the Dart
  /// VM and dart2js, so this slot id is only stable within a single platform.
  /// FamilyLedger ships iOS/Android only; if Web is ever added, replace with a
  /// deterministic hash (e.g. md5 low-32).
  static int loanNotificationId(String loanId, DateTime dueDate) {
    final key = '$loanId|${_dateKey(dueDate)}';
    final hash = key.hashCode & 0x7fffffff;
    return NotificationIdRange.loan + (hash % 100000);
  }

  /// Stable OS-notification-slot id within the billing band, keyed on account +
  /// kind + due date.
  static int creditCardNotificationId(
    String accountId,
    CreditCardReminderKind kind,
    DateTime date,
  ) {
    final key = '$accountId|${kind.notificationType}|${_dateKey(date)}';
    final hash = key.hashCode & 0x7fffffff;
    return NotificationIdRange.billing + (hash % 100000);
  }

  /// Schedule reminders for all unpaid upcoming payments of the given loans.
  ///
  /// For each loan we read its local schedule rows (one per month — the local
  /// expression of the "monthly repeat" rule) and schedule a date-based
  /// notification [daysBefore] days before each unpaid `due_date` that is still
  /// in the future. Idempotent: dedup ensures each loan/due-date schedules once.
  ///
  /// Dedup state is read ONCE per run into an in-memory key set (instead of a
  /// DB query per schedule row), so cost is 1 query + N×M in-memory lookups.
  /// Overlapping calls are serialized via [_loanRun].
  ///
  /// [userId] owns the written notification records. [now] is injectable for
  /// tests. The returned future completes when this run finishes (awaitable in
  /// tests even though the scheduler provider fires it unawaited).
  Future<void> scheduleLoanReminders({
    required String userId,
    required List<db.Loan> loans,
    int daysBefore = defaultDaysBefore,
    DateTime? now,
  }) {
    final run = _loanRun.then(
      (_) => _runLoanReminders(
        userId: userId,
        loans: loans,
        daysBefore: daysBefore,
        now: now ?? DateTime.now(),
      ),
    );
    // Keep the chain alive but swallow errors so one failed run doesn't poison
    // the next; per-loan errors are already logged inside the run.
    _loanRun = run.catchError((_) {});
    return run;
  }

  Future<void> _runLoanReminders({
    required String userId,
    required List<db.Loan> loans,
    required int daysBefore,
    required DateTime now,
  }) async {
    // One read of existing loan-reminder keys for the whole run.
    final seen = await _existingKeys(userId, loanType, 'loan_id');
    for (final loan in loans) {
      try {
        final schedules = await _db.getLoanSchedules(loan.id);
        for (final s in schedules) {
          if (s.isPaid) continue;
          await _scheduleLoanPayment(
            userId: userId,
            loan: loan,
            schedule: s,
            daysBefore: daysBefore,
            now: now,
            seen: seen,
          );
        }
      } catch (e) {
        // Reminder scheduling must never break loan loading.
        dev.log(
          '[LoanReminder] scheduleLoanReminders failed for ${loan.id}: $e',
          name: 'LoanReminderService',
        );
      }
    }
  }

  Future<void> _scheduleLoanPayment({
    required String userId,
    required db.Loan loan,
    required db.LoanSchedule schedule,
    required int daysBefore,
    required DateTime now,
    required Set<String> seen,
  }) async {
    final dueDate = schedule.dueDate;
    final fireAt = reminderFireTime(dueDate, daysBefore);
    // Past payments (incl. fire time already elapsed) are not scheduled — the
    // OS rejects past triggers and we shouldn't surface stale records.
    if (!fireAt.isAfter(now)) return;

    final dueKey = _dateKey(dueDate);
    final dedupKey = '${loan.id}|$dueKey';
    if (!seen.add(dedupKey)) return; // already scheduled (persisted or this run)

    final amountYuan = (schedule.payment / 100).toStringAsFixed(2);
    const title = '贷款还款提醒';
    final body =
        '您的贷款「${loan.name}」第${schedule.monthNumber}期还款 ¥$amountYuan 将于 $dueKey 到期';

    await _db.insertNotification(
      db.NotificationsCompanion.insert(
        id: _uuid.v4(),
        userId: userId,
        type: loanType,
        title: title,
        body: body,
        dataJson: Value(
          jsonEncode({
            'loan_id': loan.id,
            'month_number': schedule.monthNumber,
            'payment': schedule.payment,
            'due_date': dueKey,
          }),
        ),
      ),
    );

    await _notifications.scheduleAt(
      id: loanNotificationId(loan.id, dueDate),
      when: fireAt,
      title: title,
      body: body,
      payload: 'loan:${loan.id}',
    );
  }

  /// Schedule a credit-card billing-day or payment-due reminder for the next
  /// occurrence of [dayOfMonth].
  ///
  /// Kept parameterized (rather than reading accounts) because the local
  /// Drift `accounts` table does not yet carry billing/payment-due columns;
  /// callers that have those values pass them in. The computation — clamp the
  /// recurring day to the month, roll to next month if this month's day has
  /// passed, then fire [daysBefore] days ahead for payment-due / on-day for
  /// billing — is pure and fully tested.
  Future<void> scheduleCreditCardReminder({
    required String userId,
    required String accountId,
    required String accountName,
    required CreditCardReminderKind kind,
    required int dayOfMonth,
    int daysBefore = defaultDaysBefore,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final dueDate = nextCreditCardDate(dayOfMonth, effectiveNow);

    // Billing day fires *on* the day; payment-due fires [daysBefore] ahead.
    final lead = kind == CreditCardReminderKind.billingDay ? 0 : daysBefore;
    final fireAt = reminderFireTime(dueDate, lead);
    if (!fireAt.isAfter(effectiveNow)) return;

    final dueKey = _dateKey(dueDate);
    try {
      if (await _alreadyScheduled(
        userId: userId,
        type: kind.notificationType,
        matchKey: 'account_id',
        matchValue: accountId,
        dueDate: dueKey,
      )) {
        return;
      }

      final (title, body) = _creditCardMessage(kind, accountName, dayOfMonth);

      await _db.insertNotification(
        db.NotificationsCompanion.insert(
          id: _uuid.v4(),
          userId: userId,
          type: kind.notificationType,
          title: title,
          body: body,
          dataJson: Value(
            jsonEncode({
              'account_id': accountId,
              'day_of_month': dayOfMonth,
              'due_date': dueKey,
            }),
          ),
        ),
      );

      await _notifications.scheduleAt(
        id: creditCardNotificationId(accountId, kind, dueDate),
        when: fireAt,
        title: title,
        body: body,
        payload: 'account:$accountId',
      );
    } catch (e) {
      dev.log(
        '[LoanReminder] scheduleCreditCardReminder failed for $accountId: $e',
        name: 'LoanReminderService',
      );
    }
  }

  /// The next date a monthly [dayOfMonth] falls on, relative to [now]: this
  /// month if not yet passed, otherwise next month. Clamps to month length.
  /// Pure.
  static DateTime nextCreditCardDate(int dayOfMonth, DateTime now) {
    final thisMonth = effectiveMonthlyDate(dayOfMonth, now);
    final today = DateTime(now.year, now.month, now.day);
    if (!thisMonth.isBefore(today)) return thisMonth;
    final next = DateTime(now.year, now.month + 1, 1);
    return effectiveMonthlyDate(dayOfMonth, next);
  }

  (String, String) _creditCardMessage(
    CreditCardReminderKind kind,
    String accountName,
    int dayOfMonth,
  ) {
    switch (kind) {
      case CreditCardReminderKind.billingDay:
        return (
          '信用卡账单日提醒',
          '您的信用卡「$accountName」今天是账单日，请查看本期账单',
        );
      case CreditCardReminderKind.paymentDue:
        return (
          '信用卡还款日提醒',
          '您的信用卡「$accountName」即将到还款日（每月$dayOfMonth日），请及时还款',
        );
    }
  }

  /// Loads all existing `data_json` dedup keys (`matchValue|due_date`) for
  /// notifications of [type] in ONE query, for in-memory O(1) dedup across a
  /// whole scheduling run. Mirrors the server's `has*Notification` semantics.
  Future<Set<String>> _existingKeys(
    String userId,
    String type,
    String matchKey,
  ) async {
    final existing = await _db.getNotificationsByType(userId, type, limit: 1000);
    final keys = <String>{};
    for (final n in existing) {
      if (n.dataJson.isEmpty) continue;
      try {
        final data = jsonDecode(n.dataJson) as Map<String, dynamic>;
        final mv = data[matchKey];
        final due = data['due_date'];
        if (mv != null && due != null) keys.add('$mv|$due');
      } catch (_) {
        // Ignore malformed payloads.
      }
    }
    return keys;
  }

  /// Dedup gate: returns whether a notification of [type] for this entity and
  /// [dueDate] already exists locally. Mirrors the server's `hasLoanNotification`
  /// / `hasCreditCardNotification`, matching on the persisted `data_json`.
  Future<bool> _alreadyScheduled({
    required String userId,
    required String type,
    required String matchKey,
    required String matchValue,
    required String dueDate,
  }) async {
    final existing = await _db.getNotificationsByType(userId, type, limit: 200);
    for (final n in existing) {
      if (n.dataJson.isEmpty) continue;
      try {
        final data = jsonDecode(n.dataJson) as Map<String, dynamic>;
        if (data[matchKey] == matchValue && data['due_date'] == dueDate) {
          return true;
        }
      } catch (_) {
        // Ignore malformed payloads.
      }
    }
    return false;
  }

  static String _dateKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
