import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notifications/local_notification_service.dart';

/// Provides the app-wide [LocalNotificationService].
///
/// Overridden in `main()` with an already-initialized
/// [FlutterLocalNotificationService] (same pattern as the SharedPreferences
/// provider). Tests override it with a fake.
final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  throw UnimplementedError(
    'localNotificationServiceProvider must be overridden in main() '
    'with an initialized LocalNotificationService',
  );
});
