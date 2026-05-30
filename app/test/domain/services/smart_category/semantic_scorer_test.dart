import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:familyledger/domain/services/smart_category/nl_embedding_bridge.dart';
import 'package:familyledger/domain/services/smart_category/semantic_scorer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NLEmbeddingBridge', () {
    test('pairKey sorts alphabetically', () {
      expect(NLEmbeddingBridge.pairKey('饮食', '交通'), '交通|饮食');
      expect(NLEmbeddingBridge.pairKey('abc', 'xyz'), 'abc|xyz');
      expect(NLEmbeddingBridge.pairKey('xyz', 'abc'), 'abc|xyz');
    });
  });

  group('SemanticScorer', () {
    group('when platform unavailable', () {
      late SemanticScorer scorer;

      setUp(() {
        scorer = SemanticScorer();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('familyledger/nl_embedding'),
          (call) async {
            if (call.method == 'isAvailable') return false;
            return null;
          },
        );
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('familyledger/nl_embedding'),
          null,
        );
      });

      test('isAvailable returns false', () async {
        expect(await scorer.isAvailable, false);
      });

      test('score returns null', () async {
        expect(await scorer.score('餐饮', '饮食'), null);
      });

      test('precompute does nothing', () async {
        // Should not throw
        await scorer.precompute(['餐饮', '饮食', '交通']);
      });
    });

    group('when platform available', () {
      late SemanticScorer scorer;
      final mockDistances = <String, double>{
        '交通|餐饮': 0.8,
        '交通|饮食': 1.2,
        '餐饮|饮食': 0.3,
      };

      setUp(() {
        scorer = SemanticScorer();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('familyledger/nl_embedding'),
          (call) async {
            switch (call.method) {
              case 'isAvailable':
                return true;
              case 'distance':
                final args = call.arguments as Map;
                final w1 = args['word1'] as String;
                final w2 = args['word2'] as String;
                final key = NLEmbeddingBridge.pairKey(w1, w2);
                return mockDistances[key];
              case 'batchDistances':
                return mockDistances;
              default:
                return null;
            }
          },
        );
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('familyledger/nl_embedding'),
          null,
        );
      });

      test('isAvailable returns true', () async {
        expect(await scorer.isAvailable, true);
      });

      test('score converts distance to similarity', () async {
        // distance 0.3 → similarity = 1.0 - 0.3/2 = 0.85
        final s = await scorer.score('餐饮', '饮食');
        expect(s, closeTo(0.85, 0.01));
      });

      test('score with far distance returns low similarity', () async {
        // distance 1.2 → similarity = 1.0 - 1.2/2 = 0.4
        final s = await scorer.score('饮食', '交通');
        expect(s, closeTo(0.4, 0.01));
      });

      test('precompute caches batch results', () async {
        await scorer.precompute(['餐饮', '饮食', '交通']);
        // Should use cached value
        final s = await scorer.score('餐饮', '饮食');
        expect(s, closeTo(0.85, 0.01));
      });

      test('clearCache forces re-fetch', () async {
        await scorer.precompute(['餐饮', '饮食', '交通']);
        scorer.clearCache();
        // Still works via single call fallback
        final s = await scorer.score('餐饮', '交通');
        expect(s, closeTo(0.6, 0.01));
      });

      test('distance 0 → similarity 1.0', () async {
        // Override mock for identical words
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('familyledger/nl_embedding'),
          (call) async {
            if (call.method == 'isAvailable') return true;
            if (call.method == 'distance') return 0.0;
            return null;
          },
        );
        final fresh = SemanticScorer();
        expect(await fresh.score('餐饮', '餐饮'), 1.0);
      });

      test('distance 2 → similarity 0.0', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('familyledger/nl_embedding'),
          (call) async {
            if (call.method == 'isAvailable') return true;
            if (call.method == 'distance') return 2.0;
            return null;
          },
        );
        final fresh = SemanticScorer();
        expect(await fresh.score('汽车', '冰激凌'), 0.0);
      });
    });
  });
}
