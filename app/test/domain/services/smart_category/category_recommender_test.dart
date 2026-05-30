import 'package:flutter_test/flutter_test.dart';

import 'package:familyledger/domain/services/smart_category/category_recommender.dart';
import 'package:familyledger/domain/services/smart_category/category_usage_profile.dart';

void main() {
  group('TimeSlotScorer', () {
    const scorer = TimeSlotScorer();

    test('returns 0 when maxHourProb is 0', () {
      final profile = CategoryUsageProfile(categoryId: 'a');
      expect(scorer.score(profile, 12, 0), 0);
    });

    test('scores high for matching hour', () {
      final hourDist = List<int>.filled(24, 0);
      hourDist[12] = 10; // noon peak
      hourDist[11] = 5;
      hourDist[13] = 5;
      final profile = CategoryUsageProfile(
        categoryId: 'lunch',
        hourDistribution: hourDist,
      );
      // maxHourProb = smoothed at noon = (5+10+5)/(20) * normalizedProb
      final hourProb = profile.hourProbability;
      final smoothed =
          (hourProb[11] + hourProb[12] + hourProb[13]) / 3;
      final score = scorer.score(profile, 12, smoothed);
      expect(score, closeTo(1.0, 0.001));
    });

    test('scores low for non-matching hour', () {
      final hourDist = List<int>.filled(24, 0);
      hourDist[12] = 10; // noon peak
      final profile = CategoryUsageProfile(
        categoryId: 'lunch',
        hourDistribution: hourDist,
      );
      final hourProb = profile.hourProbability;
      final maxSmoothed =
          (hourProb[11] + hourProb[12] + hourProb[13]) / 3;
      // Score at 3 AM — should be very low
      final score = scorer.score(profile, 3, maxSmoothed);
      expect(score, lessThan(0.1));
    });
  });

  group('RecencyScorer', () {
    const scorer = RecencyScorer();

    test('returns 0 when maxLast7d is 0', () {
      final profile = CategoryUsageProfile(categoryId: 'a', last7dCount: 5);
      expect(scorer.score(profile, 0), 0);
    });

    test('returns normalized score', () {
      final profile = CategoryUsageProfile(categoryId: 'a', last7dCount: 3);
      expect(scorer.score(profile, 10), closeTo(0.3, 0.001));
    });

    test('returns 1.0 for max category', () {
      final profile = CategoryUsageProfile(categoryId: 'a', last7dCount: 10);
      expect(scorer.score(profile, 10), 1.0);
    });
  });

  group('FrequencyScorer', () {
    const scorer = FrequencyScorer();

    test('returns 0 when maxTotal is 0', () {
      final profile = CategoryUsageProfile(categoryId: 'a', totalCount: 5);
      expect(scorer.score(profile, 0), 0);
    });

    test('returns normalized score', () {
      final profile = CategoryUsageProfile(categoryId: 'a', totalCount: 25);
      expect(scorer.score(profile, 100), closeTo(0.25, 0.001));
    });
  });

  group('AmountRangeScorer', () {
    const scorer = AmountRangeScorer();

    test('returns 0 when amountCents is null', () {
      final profile = CategoryUsageProfile(categoryId: 'a');
      expect(scorer.score(profile, null), 0);
    });

    test('returns 0 when amountCents is 0', () {
      final profile = CategoryUsageProfile(categoryId: 'a');
      expect(scorer.score(profile, 0), 0);
    });

    test('returns probability for matching bucket', () {
      // 35 yuan → bucket 1 (20-50)
      final amountDist = [0, 10, 0, 0, 0, 0]; // all in bucket 1
      final profile = CategoryUsageProfile(
        categoryId: 'food',
        amountBuckets: amountDist,
      );
      expect(scorer.score(profile, 3500), closeTo(1.0, 0.001));
    });

    test('returns low prob for non-matching bucket', () {
      final amountDist = [10, 0, 0, 0, 0, 0]; // all in bucket 0 (<20 yuan)
      final profile = CategoryUsageProfile(
        categoryId: 'food',
        amountBuckets: amountDist,
      );
      // 500 yuan → bucket 3
      expect(scorer.score(profile, 50000), closeTo(0.0, 0.001));
    });
  });

  group('SequenceScorer', () {
    test('returns 0 when lastCategoryId is null', () {
      final scorer = SequenceScorer({'a': {'b': 0.5}});
      expect(scorer.score(null, 'b'), 0);
    });

    test('returns 0 when no transitions from lastCategory', () {
      final scorer = SequenceScorer({'a': {'b': 0.5}});
      expect(scorer.score('c', 'b'), 0);
    });

    test('returns transition probability', () {
      final scorer = SequenceScorer({
        'food': {'transport': 0.4, 'coffee': 0.6},
      });
      expect(scorer.score('food', 'transport'), closeTo(0.4, 0.001));
      expect(scorer.score('food', 'coffee'), closeTo(0.6, 0.001));
    });

    test('buildMatrix creates correct transition probabilities', () {
      // Sequence (newest first): coffee, transport, food, food, transport
      // Time order (oldest first): transport, food, food, transport, coffee
      // Transitions: transport→food, food→food, food→transport, transport→coffee
      final ids = ['coffee', 'transport', 'food', 'food', 'transport'];
      final matrix = SequenceScorer.buildMatrix(ids);

      // transport → {food: 0.5, coffee: 0.5}
      expect(matrix['transport']!['food'], closeTo(0.5, 0.001));
      expect(matrix['transport']!['coffee'], closeTo(0.5, 0.001));
      // food → {food: 0.5, transport: 0.5}
      expect(matrix['food']!['food'], closeTo(0.5, 0.001));
      expect(matrix['food']!['transport'], closeTo(0.5, 0.001));
    });

    test('buildMatrix handles less than 2 items', () {
      expect(SequenceScorer.buildMatrix([]), isEmpty);
      expect(SequenceScorer.buildMatrix(['a']), isEmpty);
    });
  });

  group('KeywordScorer', () {
    const scorer = KeywordScorer();

    test('returns 0 for null noteText', () {
      final profile = CategoryUsageProfile(
        categoryId: 'a',
        topKeywords: ['外卖', '美团'],
      );
      expect(scorer.score(profile, null), 0);
    });

    test('returns 0 for empty noteText', () {
      final profile = CategoryUsageProfile(
        categoryId: 'a',
        topKeywords: ['外卖', '美团'],
      );
      expect(scorer.score(profile, ''), 0);
    });

    test('returns 0 when no keywords match', () {
      final profile = CategoryUsageProfile(
        categoryId: 'a',
        topKeywords: ['外卖', '美团'],
      );
      expect(scorer.score(profile, '加油'), 0);
    });

    test('matches Chinese 2-gram keywords', () {
      final profile = CategoryUsageProfile(
        categoryId: 'food',
        topKeywords: ['外卖', '美团'],
      );
      // "点外卖" contains 2-gram "点外" and "外卖"
      expect(scorer.score(profile, '点外卖'), closeTo(0.5, 0.001));
    });

    test('matches 2 keywords = score 1.0', () {
      final profile = CategoryUsageProfile(
        categoryId: 'food',
        topKeywords: ['外卖', '美团', '饿了'],
      );
      // "美团外卖" contains "美团" and "团外" and "外卖"
      final score = scorer.score(profile, '美团外卖');
      expect(score, 1.0);
    });

    test('matches Latin keywords', () {
      final profile = CategoryUsageProfile(
        categoryId: 'coffee',
        topKeywords: ['starbucks', 'coffee'],
      );
      expect(scorer.score(profile, 'Starbucks latte'), closeTo(0.5, 0.001));
    });
  });

  group('KeywordScorer.tokenize', () {
    test('extracts Chinese 2-grams', () {
      final tokens = KeywordScorer.tokenize('点外卖');
      expect(tokens, contains('点外'));
      expect(tokens, contains('外卖'));
    });

    test('extracts Latin words (lowercased)', () {
      final tokens = KeywordScorer.tokenize('Buy Starbucks');
      expect(tokens, contains('buy'));
      expect(tokens, contains('starbucks'));
    });

    test('extracts short clean text as full match', () {
      final tokens = KeywordScorer.tokenize('加油');
      expect(tokens, contains('加油'));
    });

    test('ignores single char Latin words', () {
      final tokens = KeywordScorer.tokenize('a B cd');
      expect(tokens, isNot(contains('a')));
      expect(tokens, isNot(contains('b')));
      expect(tokens, contains('cd'));
    });
  });

  group('CategoryRecommender', () {
    test('returns empty for empty profiles', () {
      final recommender = CategoryRecommender();
      final results = recommender.recommend(
        profiles: [],
        sequenceScorer: const SequenceScorer({}),
        input: const CategoryRecommendInput(typeIndex: 0),
      );
      expect(results, isEmpty);
    });

    test('ranks lunch category higher at noon', () {
      final lunchHours = List<int>.filled(24, 0);
      lunchHours[11] = 5;
      lunchHours[12] = 10;
      lunchHours[13] = 3;

      final morningHours = List<int>.filled(24, 0);
      morningHours[7] = 8;
      morningHours[8] = 10;

      final lunch = CategoryUsageProfile(
        categoryId: 'lunch',
        totalCount: 30,
        last7dCount: 5,
        hourDistribution: lunchHours,
      );
      final breakfast = CategoryUsageProfile(
        categoryId: 'breakfast',
        totalCount: 20,
        last7dCount: 3,
        hourDistribution: morningHours,
      );

      final recommender = CategoryRecommender();
      final results = recommender.recommend(
        profiles: [lunch, breakfast],
        sequenceScorer: const SequenceScorer({}),
        input: CategoryRecommendInput(
          typeIndex: 0,
          now: DateTime(2026, 1, 1, 12, 30), // noon
        ),
      );

      expect(results.first.categoryId, 'lunch');
    });

    test('ranks breakfast higher in the morning', () {
      final lunchHours = List<int>.filled(24, 0);
      lunchHours[12] = 10;

      final morningHours = List<int>.filled(24, 0);
      morningHours[7] = 8;
      morningHours[8] = 10;

      final lunch = CategoryUsageProfile(
        categoryId: 'lunch',
        totalCount: 30,
        last7dCount: 5,
        hourDistribution: lunchHours,
      );
      final breakfast = CategoryUsageProfile(
        categoryId: 'breakfast',
        totalCount: 20,
        last7dCount: 3,
        hourDistribution: morningHours,
      );

      final recommender = CategoryRecommender();
      final results = recommender.recommend(
        profiles: [lunch, breakfast],
        sequenceScorer: const SequenceScorer({}),
        input: CategoryRecommendInput(
          typeIndex: 0,
          now: DateTime(2026, 1, 1, 8, 0), // morning
        ),
      );

      expect(results.first.categoryId, 'breakfast');
    });

    test('amount signal boosts matching category', () {
      // Food: mostly 20-50 yuan
      final foodAmount = [0, 10, 2, 0, 0, 0];
      // Transport: mostly <20 yuan
      final transportAmount = [10, 0, 0, 0, 0, 0];

      final food = CategoryUsageProfile(
        categoryId: 'food',
        totalCount: 50,
        last7dCount: 5,
        amountBuckets: foodAmount,
      );
      final transport = CategoryUsageProfile(
        categoryId: 'transport',
        totalCount: 50,
        last7dCount: 5,
        amountBuckets: transportAmount,
      );

      final recommender = CategoryRecommender();
      final results = recommender.recommend(
        profiles: [food, transport],
        sequenceScorer: const SequenceScorer({}),
        input: CategoryRecommendInput(
          typeIndex: 0,
          amountCents: 3500, // 35 yuan → bucket 1
          now: DateTime(2026, 1, 1, 12, 0),
        ),
      );

      expect(results.first.categoryId, 'food');
    });

    test('dynamic weight redistribution when no amount', () {
      final food = CategoryUsageProfile(
        categoryId: 'food',
        totalCount: 50,
        last7dCount: 10,
      );

      final recommender = CategoryRecommender();
      final withAmount = recommender.recommend(
        profiles: [food],
        sequenceScorer: const SequenceScorer({}),
        input: CategoryRecommendInput(
          typeIndex: 0,
          amountCents: 3500,
          now: DateTime(2026, 1, 1, 12, 0),
        ),
      );
      final withoutAmount = recommender.recommend(
        profiles: [food],
        sequenceScorer: const SequenceScorer({}),
        input: CategoryRecommendInput(
          typeIndex: 0,
          now: DateTime(2026, 1, 1, 12, 0),
        ),
      );

      // Both should produce a score > 0 (frequency/recency contribute)
      expect(withAmount.first.score, greaterThan(0));
      expect(withoutAmount.first.score, greaterThan(0));
    });
  });

  group('CategoryRecommender.coldStartConfig', () {
    test('returns cold start config for < 30 transactions', () {
      final config = CategoryRecommender.coldStartConfig(10);
      expect(config.frequencyWeight, 0.30);
      expect(config.timeSlotWeight, 0.10);
    });

    test('returns default config for >= 30 transactions', () {
      final config = CategoryRecommender.coldStartConfig(100);
      expect(config.timeSlotWeight, 0.25);
    });
  });
}
