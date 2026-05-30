import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/domain/services/smart_category/text_similarity_scorer.dart';

void main() {
  group('TextSimilarityScorer', () {
    test('identical strings → 1.0', () {
      expect(TextSimilarityScorer.score('餐饮', '餐饮'), 1.0);
    });

    test('empty string → 0.0', () {
      expect(TextSimilarityScorer.score('', '餐饮'), 0.0);
      expect(TextSimilarityScorer.score('餐饮', ''), 0.0);
    });

    test('contains relationship → high score', () {
      final score = TextSimilarityScorer.score('点外卖', '外卖');
      expect(score, greaterThanOrEqualTo(0.79));
    });

    test('similar names → high score', () {
      final score = TextSimilarityScorer.score('早点', '早餐');
      expect(score, greaterThanOrEqualTo(0.4));
    });

    test('completely different → low score', () {
      final score = TextSimilarityScorer.score('餐饮', '交通');
      expect(score, lessThan(0.4));
    });

    test('打车 vs 打的 → reasonably high', () {
      final score = TextSimilarityScorer.score('打车', '打的');
      expect(score, greaterThanOrEqualTo(0.4));
    });

    test('single char difference → high score via edit distance', () {
      final score = TextSimilarityScorer.score('购物', '购买');
      expect(score, greaterThanOrEqualTo(0.4));
    });

    test('english words: food vs foods', () {
      final score = TextSimilarityScorer.score('food', 'foods');
      expect(score, greaterThanOrEqualTo(0.7));
    });

    test('mixed: 餐饮 vs 美食 → relatively low (different characters)', () {
      final score = TextSimilarityScorer.score('餐饮', '美食');
      expect(score, lessThan(0.5));
    });
  });
}
