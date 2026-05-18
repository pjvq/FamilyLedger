import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/core/utils/user_id.dart';

void main() {
  group('generateLocalUserId', () {
    test('produces valid UUID v4 format', () {
      final id = generateLocalUserId();
      // UUID v4 format: 8-4-4-4-12 hex chars with version nibble = 4
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(uuidRegex.hasMatch(id), isTrue, reason: 'Got: $id');
    });

    test('produces unique IDs on successive calls', () {
      final ids = List.generate(1000, (_) => generateLocalUserId());
      expect(ids.toSet().length, 1000);
    });

    test('does not start with legacy prefix', () {
      final id = generateLocalUserId();
      expect(id.startsWith('user_'), isFalse);
    });
  });

  group('isLegacyUserId', () {
    test('detects legacy timestamp-based IDs', () {
      expect(isLegacyUserId('user_1716048000000'), isTrue);
      expect(isLegacyUserId('user_0'), isTrue);
      expect(isLegacyUserId('user_9999999999999'), isTrue);
    });

    test('rejects proper UUIDs', () {
      expect(isLegacyUserId('f47ac10b-58cc-4372-a567-0e02b2c3d479'), isFalse);
    });

    test('rejects user_ with non-numeric suffix', () {
      expect(isLegacyUserId('user_abc'), isFalse);
      expect(isLegacyUserId('user_'), isFalse);
    });

    test('rejects empty string', () {
      expect(isLegacyUserId(''), isFalse);
    });

    test('rejects server-issued IDs', () {
      // Server IDs are UUIDs without prefix
      expect(isLegacyUserId('a1b2c3d4-e5f6-7890-abcd-ef1234567890'), isFalse);
    });
  });
}
