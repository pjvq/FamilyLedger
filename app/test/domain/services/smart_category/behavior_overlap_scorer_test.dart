import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/domain/services/smart_category/behavior_overlap_scorer.dart';
import 'package:familyledger/domain/services/smart_category/category_usage_profile.dart';

void main() {
  group('BehaviorOverlapScorer', () {
    test('identical distributions → score ≈ 1.0', () {
      final profile = CategoryUsageProfile(
        categoryId: 'a',
        totalCount: 100,
        hourDistribution: List.generate(24, (i) => i == 12 ? 50 : 2),
        weekdayDistribution: [10, 20, 15, 15, 20, 10, 10],
        amountBuckets: [30, 20, 20, 15, 10, 5],
      );
      final score = BehaviorOverlapScorer.score(profile, profile);
      expect(score, closeTo(1.0, 0.01));
    });

    test('completely different distributions → low score', () {
      final profileA = CategoryUsageProfile(
        categoryId: 'a',
        totalCount: 100,
        hourDistribution: List.generate(24, (i) => i < 6 ? 15 : 0),
        weekdayDistribution: [50, 50, 0, 0, 0, 0, 0],
        amountBuckets: [100, 0, 0, 0, 0, 0],
      );
      final profileB = CategoryUsageProfile(
        categoryId: 'b',
        totalCount: 100,
        hourDistribution: List.generate(24, (i) => i >= 18 ? 15 : 0),
        weekdayDistribution: [0, 0, 0, 0, 0, 50, 50],
        amountBuckets: [0, 0, 0, 0, 0, 100],
      );
      final score = BehaviorOverlapScorer.score(profileA, profileB);
      expect(score, lessThan(0.3));
    });

    test('one empty profile → 0.0', () {
      final profileA = CategoryUsageProfile(
        categoryId: 'a',
        totalCount: 100,
        hourDistribution: List.generate(24, (i) => 4),
      );
      final profileB = CategoryUsageProfile(categoryId: 'b');
      final score = BehaviorOverlapScorer.score(profileA, profileB);
      expect(score, 0.0);
    });

    test('similar lunch-time patterns → high score', () {
      final profileA = CategoryUsageProfile(
        categoryId: 'a',
        totalCount: 50,
        hourDistribution: List.generate(
          24,
          (i) => (i >= 11 && i <= 13) ? 15 : 1,
        ),
        weekdayDistribution: [2, 10, 10, 10, 10, 10, 2],
        amountBuckets: [5, 30, 10, 5, 0, 0],
      );
      final profileB = CategoryUsageProfile(
        categoryId: 'b',
        totalCount: 40,
        hourDistribution: List.generate(
          24,
          (i) => (i >= 11 && i <= 13) ? 12 : 1,
        ),
        weekdayDistribution: [3, 8, 8, 9, 8, 8, 3],
        amountBuckets: [8, 25, 7, 5, 0, 0],
      );
      final score = BehaviorOverlapScorer.score(profileA, profileB);
      expect(score, greaterThan(0.7));
    });
  });

  group('JensenShannonDivergence', () {
    test('identical distributions → 0', () {
      final p = [0.25, 0.25, 0.25, 0.25];
      final jsd = BehaviorOverlapScorer.jensenShannonDivergence(p, p);
      expect(jsd, closeTo(0.0, 0.001));
    });

    test('maximally different → close to 1', () {
      final p = [1.0, 0.0, 0.0, 0.0];
      final q = [0.0, 0.0, 0.0, 1.0];
      final jsd = BehaviorOverlapScorer.jensenShannonDivergence(p, q);
      expect(jsd, greaterThan(0.8));
    });
  });

  group('CosineSimilarity', () {
    test('parallel vectors → 1.0', () {
      final a = [1.0, 2.0, 3.0];
      final b = [2.0, 4.0, 6.0];
      expect(BehaviorOverlapScorer.cosineSimilarity(a, b), closeTo(1.0, 0.001));
    });

    test('orthogonal vectors → 0.0', () {
      final a = [1.0, 0.0, 0.0];
      final b = [0.0, 1.0, 0.0];
      expect(BehaviorOverlapScorer.cosineSimilarity(a, b), closeTo(0.0, 0.001));
    });

    test('zero vector → 0.0', () {
      final a = [0.0, 0.0, 0.0];
      final b = [1.0, 2.0, 3.0];
      expect(BehaviorOverlapScorer.cosineSimilarity(a, b), 0.0);
    });
  });
}
