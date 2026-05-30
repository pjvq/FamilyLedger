import 'package:flutter_test/flutter_test.dart';

import 'package:familyledger/domain/services/smart_category/semantic_scorer.dart';

void main() {
  group('SemanticScorer.makePairKey', () {
    test('sorts alphabetically', () {
      expect(SemanticScorer.makePairKey('饮食', '交通'), '交通|饮食');
      expect(SemanticScorer.makePairKey('abc', 'xyz'), 'abc|xyz');
      expect(SemanticScorer.makePairKey('xyz', 'abc'), 'abc|xyz');
    });
  });

  group('SemanticScorer', () {
    group('when platform unavailable', () {
      late SemanticScorer scorer;

      setUp(() {
        scorer = SemanticScorer(
          checkAvailable: () async => false,
          getDistance: (_, __) async => null,
          getBatchDistances: (_) async => null,
        );
      });

      test('isAvailable returns false', () async {
        expect(await scorer.isAvailable, false);
      });

      test('score returns null', () async {
        expect(await scorer.score('餐饮', '饮食'), null);
      });

      test('precompute does nothing', () async {
        await scorer.precompute(['餐饮', '饮食', '交通']);
        // No throw
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
        scorer = SemanticScorer(
          checkAvailable: () async => true,
          getDistance: (w1, w2) async {
            final key = SemanticScorer.makePairKey(w1, w2);
            return mockDistances[key];
          },
          getBatchDistances: (_) async => mockDistances,
        );
      });

      test('isAvailable returns true', () async {
        expect(await scorer.isAvailable, true);
      });

      test('same name short-circuits to 1.0', () async {
        expect(await scorer.score('餐饮', '餐饮'), 1.0);
      });

      test('score converts distance via sigmoid mapping', () async {
        // distance 0.3 → sigmoid: 1/(1+exp(4*(0.3-0.8))) = 1/(1+exp(-2)) ≈ 0.88
        final s = await scorer.score('餐饮', '饮食');
        expect(s, isNotNull);
        expect(s!, greaterThan(0.8));
        expect(s, lessThan(1.0));
      });

      test('score with far distance returns low similarity', () async {
        // distance 1.2 → sigmoid: 1/(1+exp(4*(1.2-0.8))) = 1/(1+exp(1.6)) ≈ 0.17
        final s = await scorer.score('饮食', '交通');
        expect(s, isNotNull);
        expect(s!, lessThan(0.3));
      });

      test('precompute caches batch results', () async {
        await scorer.precompute(['餐饮', '饮食', '交通']);
        final s = await scorer.score('餐饮', '饮食');
        expect(s, isNotNull);
        expect(s!, greaterThan(0.8));
      });

      test('clearCache forces re-fetch via single call', () async {
        await scorer.precompute(['餐饮', '饮食', '交通']);
        scorer.clearCache();
        final s = await scorer.score('餐饮', '交通');
        expect(s, isNotNull);
        // distance 0.8 → sigmoid: 1/(1+exp(0)) = 0.5
        expect(s!, closeTo(0.5, 0.05));
      });

      test('distance 0 → high similarity', () async {
        final zeroScorer = SemanticScorer(
          checkAvailable: () async => true,
          getDistance: (_, __) async => 0.0,
          getBatchDistances: (_) async => {},
        );
        final s = await zeroScorer.score('a', 'b');
        // 1/(1+exp(4*(0-0.8))) = 1/(1+exp(-3.2)) ≈ 0.96
        expect(s!, greaterThan(0.95));
      });

      test('distance 2 → very low similarity', () async {
        final farScorer = SemanticScorer(
          checkAvailable: () async => true,
          getDistance: (_, __) async => 2.0,
          getBatchDistances: (_) async => {},
        );
        final s = await farScorer.score('a', 'b');
        // 1/(1+exp(4*(2-0.8))) = 1/(1+exp(4.8)) ≈ 0.008
        expect(s!, lessThan(0.02));
      });
    });

    group('availability cache expiry', () {
      test('re-checks after cache expires', () async {
        var callCount = 0;
        final scorer = SemanticScorer(
          checkAvailable: () async {
            callCount++;
            return callCount > 1; // first call: false, second: true
          },
          getDistance: (_, __) async => 0.5,
          getBatchDistances: (_) async => {},
        );

        expect(await scorer.isAvailable, false);
        expect(callCount, 1);

        // Within cache window — still false
        expect(await scorer.isAvailable, false);
        expect(callCount, 1);

        // Reset to simulate cache expiry
        scorer.resetAvailability();
        expect(await scorer.isAvailable, true);
        expect(callCount, 2);
      });
    });
  });
}
