import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/domain/services/smart_category/keyword_overlap_scorer.dart';
import 'package:familyledger/domain/services/smart_category/category_usage_profile.dart';

void main() {
  group('KeywordOverlapScorer', () {
    test('identical keywords → 1.0', () {
      final a = CategoryUsageProfile(
        categoryId: 'a',
        topKeywords: ['外卖', '午餐', '美团'],
      );
      final b = CategoryUsageProfile(
        categoryId: 'b',
        topKeywords: ['外卖', '午餐', '美团'],
      );
      expect(KeywordOverlapScorer.score(a, b), 1.0);
    });

    test('no overlap → 0.0', () {
      final a = CategoryUsageProfile(
        categoryId: 'a',
        topKeywords: ['外卖', '午餐', '美团'],
      );
      final b = CategoryUsageProfile(
        categoryId: 'b',
        topKeywords: ['公交', '地铁', '打车'],
      );
      expect(KeywordOverlapScorer.score(a, b), 0.0);
    });

    test('partial overlap → correct Jaccard', () {
      final a = CategoryUsageProfile(
        categoryId: 'a',
        topKeywords: ['外卖', '午餐', '美团', '饿了么'],
      );
      final b = CategoryUsageProfile(
        categoryId: 'b',
        topKeywords: ['外卖', '晚餐', '美团', '点餐'],
      );
      // intersection: {外卖, 美团} = 2
      // union: {外卖, 午餐, 美团, 饿了么, 晚餐, 点餐} = 6
      expect(KeywordOverlapScorer.score(a, b), closeTo(2 / 6, 0.001));
    });

    test('one empty → 0.0', () {
      final a = CategoryUsageProfile(categoryId: 'a', topKeywords: ['外卖']);
      final b = CategoryUsageProfile(categoryId: 'b');
      expect(KeywordOverlapScorer.score(a, b), 0.0);
    });
  });
}
