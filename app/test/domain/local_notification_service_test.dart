import 'package:familyledger/domain/services/notifications/local_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [LocalNotificationService] for tests. Records calls so downstream
/// features (budget / loan / reminder localization) can assert on scheduling
/// without touching platform channels.
class FakeLocalNotificationService implements LocalNotificationService {
  bool initialized = false;
  bool permissionGranted = true;
  final List<({int id, String title, String body, String? payload})> shown = [];
  final Map<int, ({DateTime when, String title, String body})> scheduled = {};

  @override
  Future<void> init() async => initialized = true;

  @override
  Future<bool> requestPermissions() async => permissionGranted;

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shown.add((id: id, title: title, body: body, payload: payload));
  }

  @override
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Mirror the real impl: ignore non-future times.
    if (!when.isAfter(DateTime.now())) return;
    scheduled[id] = (when: when, title: title, body: body);
  }

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);

  @override
  Future<void> cancelAll() async => scheduled.clear();

  @override
  Future<List<int>> pendingIds() async => scheduled.keys.toList();
}

void main() {
  group('LocalNotificationService contract (via fake)', () {
    late FakeLocalNotificationService svc;

    setUp(() => svc = FakeLocalNotificationService());

    test('showNow records the notification', () async {
      await svc.showNow(id: 1, title: 'T', body: 'B', payload: 'p');
      expect(svc.shown, hasLength(1));
      expect(svc.shown.single.id, 1);
      expect(svc.shown.single.payload, 'p');
    });

    test('scheduleAt keeps a future notification as pending', () async {
      final future = DateTime.now().add(const Duration(days: 1));
      await svc.scheduleAt(id: 7, when: future, title: 'Loan', body: 'Due');
      expect(await svc.pendingIds(), contains(7));
      expect(svc.scheduled[7]!.when, future);
    });

    test('scheduleAt ignores past times', () async {
      final past = DateTime.now().subtract(const Duration(minutes: 1));
      await svc.scheduleAt(id: 8, when: past, title: 'X', body: 'Y');
      expect(await svc.pendingIds(), isEmpty);
    });

    test('cancel and cancelAll remove pending notifications', () async {
      final future = DateTime.now().add(const Duration(hours: 1));
      await svc.scheduleAt(id: 1, when: future, title: 'A', body: 'a');
      await svc.scheduleAt(id: 2, when: future, title: 'B', body: 'b');
      await svc.cancel(1);
      expect(await svc.pendingIds(), [2]);
      await svc.cancelAll();
      expect(await svc.pendingIds(), isEmpty);
    });
  });
}
