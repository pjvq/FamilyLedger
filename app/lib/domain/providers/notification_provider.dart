import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../data/local/database.dart' as db;
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/notify.pb.dart' as pb;
import '../../generated/proto/notify.pbgrpc.dart';
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
  }) =>
      NotificationSettingsModel(
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
  }) =>
      NotificationState(
        notifications: notifications ?? this.notifications,
        unreadCount: unreadCount ?? this.unreadCount,
        settings: settings ?? this.settings,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── Notifier ──

class NotificationNotifier extends StateNotifier<NotificationState> {
  final db.AppDatabase _db;
  final NotifyServiceClient _client;
  final String? _userId;

  NotificationNotifier(this._db, this._client, this._userId)
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

    try {
      // Try gRPC first
      final resp = await _client.listNotifications(
        pb.ListNotificationsRequest()
          ..page = page
          ..pageSize = pageSize,
      );

      // Cache locally
      for (final n in resp.notifications) {
        await _db.insertNotification(db.NotificationsCompanion.insert(
          id: n.id,
          userId: _userId,
          type: n.type,
          title: n.title,
          body: n.body,
          dataJson: Value(n.dataJson),
          isRead: Value(n.isRead),
          createdAt: Value(n.createdAt.toDateTime()),
        ));
      }
    } catch (_) {
      // fallback to local
    }

    // Load from local DB
    final notifications =
        await _db.getNotifications(_userId, pageSize, page * pageSize);
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

    try {
      await _client.markAsRead(
        pb.MarkAsReadRequest()..notificationIds.addAll(ids),
      );
    } catch (_) {
      // offline
    }

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

    try {
      final resp = await _client.getNotificationSettings(
        pb.GetNotificationSettingsRequest(),
      );
      final s = resp.settings;
      final model = NotificationSettingsModel(
        budgetAlert: s.budgetAlert,
        budgetWarning: s.budgetWarning,
        dailySummary: s.dailySummary,
        loanReminder: s.loanReminder,
        reminderDaysBefore: s.reminderDaysBefore,
      );

      // Cache locally
      await _db.upsertNotificationSettings(
        db.NotificationSettingsTableCompanion.insert(
          userId: _userId,
          budgetAlert: Value(model.budgetAlert),
          budgetWarning: Value(model.budgetWarning),
          dailySummary: Value(model.dailySummary),
          loanReminder: Value(model.loanReminder),
          reminderDaysBefore: Value(model.reminderDaysBefore),
        ),
      );
      state = state.copyWith(settings: model);
    } catch (_) {
      // Load from local
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
  }

  Future<void> updateSettings(NotificationSettingsModel settings) async {
    if (_userId == null) return;

    try {
      await _client.updateNotificationSettings(
        pb.UpdateNotificationSettingsRequest()
          ..settings = (pb.NotificationSettings()
            ..budgetAlert = settings.budgetAlert
            ..budgetWarning = settings.budgetWarning
            ..dailySummary = settings.dailySummary
            ..loanReminder = settings.loanReminder
            ..reminderDaysBefore = settings.reminderDaysBefore),
      );
    } catch (_) {
      // offline
    }

    // Save locally
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
  final client = ref.watch(notifyClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  return NotificationNotifier(database, client, userId);
});
