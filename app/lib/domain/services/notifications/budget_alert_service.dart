import 'dart:convert';
import 'dart:developer' as dev;

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../data/local/database.dart' as db;
import 'local_notification_service.dart';

/// Budget overspend / warning threshold (fraction of total budget spent).
enum BudgetAlertLevel {
  /// >= 80% but < 100% of the budget consumed.
  warning,

  /// >= 100% of the budget consumed.
  exceeded;

  /// Notification `type`, mirroring the server's `notify` service so the
  /// notification list renders identically regardless of origin.
  String get notificationType =>
      this == BudgetAlertLevel.exceeded ? 'budget_exceeded' : 'budget_warning';
}

/// Localized port of the server `notify.CheckBudgets` logic (issue #144).
///
/// Given a budget's monthly execution rate, decides whether it has crossed the
/// 80% warning or 100% exceeded threshold and, if so:
///   1. writes a local notification record (same shape as the server's
///      `notifications` table — type/title/body/data_json), and
///   2. fires an on-device notification via [LocalNotificationService.showNow].
///
/// De-duplicates per budget + period (year/month) + threshold by inspecting
/// already-stored local notifications, so the same budget/month/level only
/// alerts once. This mirrors the server's `hasNotification` check, but runs
/// entirely against the local Drift DB.
class BudgetAlertService {
  BudgetAlertService(this._db, this._notifications);

  final db.AppDatabase _db;
  final LocalNotificationService _notifications;

  static const _uuid = Uuid();

  /// 80% warning threshold.
  static const double warningThreshold = 0.8;

  /// 100% exceeded threshold.
  static const double exceededThreshold = 1.0;

  /// Classify [rate] (spent / budget) into an alert level, or null if below the
  /// warning threshold. Pure function — no side effects.
  static BudgetAlertLevel? levelFor(double rate) {
    if (rate >= exceededThreshold) return BudgetAlertLevel.exceeded;
    if (rate >= warningThreshold) return BudgetAlertLevel.warning;
    return null;
  }

  /// Stable notification id within the budget band so repeated checks for the
  /// same budget/period/level reuse one OS notification slot.
  static int notificationId(
    String budgetId,
    int year,
    int month,
    BudgetAlertLevel level,
  ) {
    final key = '$budgetId|$year-$month|${level.notificationType}';
    final hash = key.hashCode & 0x7fffffff; // non-negative
    return NotificationIdRange.budget + (hash % 100000);
  }

  /// Check a single budget's monthly execution and alert if a threshold is
  /// crossed. Safe to call repeatedly: dedup ensures at most one notification
  /// per budget/period/level.
  ///
  /// [userId] is the recipient (notification owner). [totalBudget] / [totalSpent]
  /// are in cents.
  Future<void> checkBudget({
    required String userId,
    required String budgetId,
    required int year,
    required int month,
    required int totalBudget,
    required int totalSpent,
  }) async {
    if (totalBudget <= 0) return;

    final rate = totalSpent / totalBudget;
    final level = levelFor(rate);
    if (level == null) return;

    try {
      if (await _alreadyNotified(userId, budgetId, year, month, level)) {
        return;
      }

      final pct = (rate * 100).round();
      final (title, body) = _message(level, year, month, pct);

      await _db.insertNotification(
        db.NotificationsCompanion.insert(
          id: _uuid.v4(),
          userId: userId,
          type: level.notificationType,
          title: title,
          body: body,
          dataJson: Value(
            jsonEncode({
              'budget_id': budgetId,
              'execution_rate': rate,
              'year': year,
              'month': month,
            }),
          ),
        ),
      );

      await _notifications.showNow(
        id: notificationId(budgetId, year, month, level),
        title: title,
        body: body,
        payload: 'budget:$budgetId',
      );
    } catch (e) {
      // Alerting must never break budget loading.
      dev.log(
        '[BudgetAlert] checkBudget failed: $e',
        name: 'BudgetAlertService',
      );
    }
  }

  /// Returns whether a notification of [level] for this budget/period already
  /// exists locally — the dedup gate. Mirrors server `hasNotification`, but
  /// matches on the `data_json` `budget_id`/`year`/`month` fields we store.
  Future<bool> _alreadyNotified(
    String userId,
    String budgetId,
    int year,
    int month,
    BudgetAlertLevel level,
  ) async {
    // Page through recent notifications for this user; budget alerts are few.
    final existing = await _db.getNotifications(userId, 200, 0);
    for (final n in existing) {
      if (n.type != level.notificationType) continue;
      if (n.dataJson.isEmpty) continue;
      try {
        final data = jsonDecode(n.dataJson) as Map<String, dynamic>;
        if (data['budget_id'] == budgetId &&
            data['year'] == year &&
            data['month'] == month) {
          return true;
        }
      } catch (_) {
        // Ignore malformed payloads.
      }
    }
    return false;
  }

  (String, String) _message(
    BudgetAlertLevel level,
    int year,
    int month,
    int pct,
  ) {
    switch (level) {
      case BudgetAlertLevel.exceeded:
        return ('预算超支提醒', '您 $year年$month月 的预算已超支，执行率 $pct%');
      case BudgetAlertLevel.warning:
        return ('预算预警提醒', '您 $year年$month月 的预算已使用 $pct%，请注意控制支出');
    }
  }
}
