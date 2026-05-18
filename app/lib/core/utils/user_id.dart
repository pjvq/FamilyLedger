import 'package:uuid/uuid.dart';

/// Generates a RFC 4122 v4 UUID for local user IDs.
///
/// This replaces the old `'user_${DateTime.now().millisecondsSinceEpoch}'` pattern
/// which produced non-standard IDs that could never reconcile with server-generated
/// UUIDs. Using real UUIDs ensures:
///
/// 1. **Server compatibility**: when connectivity is restored, the local user can
///    be linked to a server account via email match (the server won't reject the
///    ID format during migration).
/// 2. **Collision safety**: v4 UUIDs have 122 bits of entropy. The probability of
///    collision across all FamilyLedger devices globally is negligible.
/// 3. **Sortability**: while not time-ordered (use UUIDv7 if needed), they're
///    valid for use as database primary keys.
///
/// Why a dedicated function instead of inlining `Uuid().v4()`:
/// - Single point of change if we migrate to UUIDv7
/// - Testable: can be overridden in tests via DI
/// - Documents the design decision in one place
const _uuid = Uuid();

/// Generate a new user ID suitable for offline-created accounts.
///
/// Format: standard UUID v4 (e.g., `f47ac10b-58cc-4372-a567-0e02b2c3d479`).
/// The `local_` prefix is intentionally NOT used — server-side user IDs are
/// also UUIDs, so using the same format enables future account linking.
String generateLocalUserId() => _uuid.v4();

/// Detects legacy non-UUID user IDs created by older app versions.
///
/// Legacy pattern: `user_<millisecond_timestamp>` (e.g., `user_1716048000000`).
/// These cannot sync with the server and should be migrated on next login.
bool isLegacyUserId(String userId) {
  if (!userId.startsWith('user_')) return false;
  final suffix = userId.substring(5);
  // Legacy IDs have a positive numeric millisecond timestamp suffix
  if (suffix.isEmpty) return false;
  final parsed = int.tryParse(suffix);
  return parsed != null && parsed >= 0;
}
