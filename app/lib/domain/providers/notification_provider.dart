import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../data/local/database.dart' as db;
import 'app_providers.dart';

// ── Settings Model ──

class NotificationSettingsModel {
  final bool budgetAlert;
  final bool budgetWarning;
  final bool dailySummary;
  final bool loanReminder;
  final int reminderDaysBefore;

  const NotificationSettingsModel({
    this.budgetAlert = true,
    this.budgetWarning = true,
    this.dailySummary = false,
    this.loanReminder = true,
    this.reminderDaysBefore = 3,
  });

  NotificationSettingsModel copyWith({
    bool? budgetAlert,
    bool? budgetWarning,
    bool? dailySummary,
    bool? loanReminder,
    int? reminderDaysBefore,
  }) => NotificationSettingsModel(
    budgetAlert: budgetAlert ?? this.budgetAlert,
    budgetWarning: budgetWarning ?? this.budgetWarning,
    dailySummary: dailySummary ?? this.dailySummary,
    loanReminder: loanReminder ?? this.loanReminder,
    reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
  );
}

// ── State ──

class NotificationState {
  final List<db.Notification> notifications;
  final int unreadCount;
  final NotificationSettingsModel settings;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.settings = const NotificationSettingsModel(),
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<db.Notification>? notifications,
    int? unreadCount,
    NotificationSettingsModel? settings,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => NotificationState(
    notifications: notifications ?? this.notifications,
    unreadCount: unreadCount ?? this.unreadCount,
    settings: settings ?? this.settings,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

// ── Notifier ──

/// Local-first notification center.
///
/// Notifications are produced on-device by the localized budget / loan /
/// billing reminder services (P1-E/F), which write into the local
/// `notifications` table; this notifier only reads/marks them. Settings are
/// stored locally too. No server / gRPC involvement ("去服务化" Phase 1,
/// issue #147).
class NotificationNotifier extends StateNotifier<NotificationState> {
  final db.AppDatabase _db;
  final String? _userId;

  NotificationNotifier(this._db, this._userId)
    : super(const NotificationState()) {
    if (_userId != null) {
      _init();
    }
  }

  Future<void> _init() async {
    await loadSettings();
    await loadNotifications(0);
  }

  Future<void> loadNotifications(int page) async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);

    const pageSize = 20;
    final notifications = await _db.getNotifications(
      _userId,
      pageSize,
      page * pageSize,
    );
    final unread = await _db.getUnreadNotificationCount(_userId);

    state = state.copyWith(
      notifications: page == 0
          ? notifications
          : [...state.notifications, ...notifications],
      unreadCount: unread,
      isLoading: false,
    );
  }

  Future<void> markAsRead(List<String> ids) async {
    if (_userId == null || ids.isEmpty) return;

    await _db.markNotificationsAsRead(ids);

    final updated = state.notifications.map((n) {
      if (ids.contains(n.id)) {
        // Reconstruct with isRead = true
        return db.Notification(
          id: n.id,
          userId: n.userId,
          type: n.type,
          title: n.title,
          body: n.body,
          dataJson: n.dataJson,
          isRead: true,
          createdAt: n.createdAt,
        );
      }
      return n;
    }).toList();

    final unread = await _db.getUnreadNotificationCount(_userId);
    state = state.copyWith(notifications: updated, unreadCount: unread);
  }

  Future<void> loadSettings() async {
    if (_userId == null) return;

    final local = await _db.getNotificationSettings(_userId);
    if (local != null) {
      state = state.copyWith(
        settings: NotificationSettingsModel(
          budgetAlert: local.budgetAlert,
          budgetWarning: local.budgetWarning,
          dailySummary: local.dailySummary,
          loanReminder: local.loanReminder,
          reminderDaysBefore: local.reminderDaysBefore,
        ),
      );
    }
  }

  Future<void> updateSettings(NotificationSettingsModel settings) async {
    if (_userId == null) return;

    await _db.upsertNotificationSettings(
      db.NotificationSettingsTableCompanion.insert(
        userId: _userId,
        budgetAlert: Value(settings.budgetAlert),
        budgetWarning: Value(settings.budgetWarning),
        dailySummary: Value(settings.dailySummary),
        loanReminder: Value(settings.loanReminder),
        reminderDaysBefore: Value(settings.reminderDaysBefore),
      ),
    );

    state = state.copyWith(settings: settings);
  }
}

// ── Provider ──

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
      final database = ref.watch(databaseProvider);
      final userId = ref.watch(currentUserIdProvider);
      return NotificationNotifier(database, userId);
    });
