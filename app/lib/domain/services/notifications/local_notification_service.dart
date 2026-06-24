import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// On-device notification scheduling, abstracted behind an interface so that
/// business logic (budget / loan / reminder localization) can fire alerts
/// without depending on the plugin directly, and so tests can substitute a
/// fake.
///
/// Two delivery modes:
/// - [showNow] — fire immediately (e.g. "budget exceeded" detected on launch).
/// - [scheduleAt] — fire at an absolute local wall-clock time. On iOS this maps
///   to a `UNCalendarNotificationTrigger`, so it survives without Background App
///   Refresh; on Android it uses an exact alarm.
abstract class LocalNotificationService {
  /// Initialize the plugin and the timezone database. Call once before use.
  Future<void> init();

  /// Request OS notification permission. Returns whether it is granted.
  Future<bool> requestPermissions();

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// Schedule [title]/[body] to fire at [when] (local wall-clock). Times not in
  /// the future are ignored.
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  });

  Future<void> cancel(int id);

  Future<void> cancelAll();

  /// IDs of notifications currently scheduled (not yet delivered).
  Future<List<int>> pendingIds();
}

/// Default [LocalNotificationService] backed by `flutter_local_notifications`.
class FlutterLocalNotificationService implements LocalNotificationService {
  FlutterLocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// Single Android channel for all app reminders.
  static const _androidChannel = AndroidNotificationChannel(
    'familyledger_reminders',
    '提醒',
    description: '预算、贷款、账单与自定义提醒',
    importance: Importance.high,
  );

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      'familyledger_reminders',
      '提醒',
      channelDescription: '预算、贷款、账单与自定义提醒',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone.identifier));
    } catch (_) {
      // Fall back to UTC+8 if the device timezone can't be resolved.
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // Permission is requested explicitly via [requestPermissions].
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);

    // Pre-create the Android channel so notifications surface reliably.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) {
    return _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
      payload: payload,
    );
  }

  @override
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
      // Don't schedule past times; caller decides whether to showNow instead.
      return;
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: _details,
      // Inexact is enough for date-level reminders (budget/loan/billing) and
      // avoids the policy-restricted SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM
      // permissions on Android 13+.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<List<int>> pendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((p) => p.id).toList(growable: false);
  }
}
