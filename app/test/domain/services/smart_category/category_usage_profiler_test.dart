import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/domain/services/smart_category/category_usage_profiler.dart';
import 'package:familyledger/domain/services/smart_category/category_usage_profile.dart';

void main() {
  group('CategoryUsageProfiler.tokenize', () {
    test('chinese text produces bigrams', () {
      final tokens = CategoryUsageProfiler.tokenize('午餐外卖');
      expect(tokens, contains('午餐'));
      expect(tokens, contains('餐外'));
      expect(tokens, contains('外卖'));
    });

    test('latin text produces words', () {
      final tokens = CategoryUsageProfiler.tokenize('KFC meal');
      expect(tokens, contains('kfc'));
      expect(tokens, contains('meal'));
    });

    test('mixed text produces both', () {
      final tokens = CategoryUsageProfiler.tokenize('星巴克Starbucks');
      expect(tokens, contains('starbucks'));
      expect(tokens, contains('星巴'));
      expect(tokens, contains('巴克'));
    });

    test('short complete match added', () {
      final tokens = CategoryUsageProfiler.tokenize('早餐');
      expect(tokens, contains('早餐')); // both bigram and complete match
    });

    test('single char skipped for latin', () {
      final tokens = CategoryUsageProfiler.tokenize('a test');
      expect(tokens, isNot(contains('a')));
      expect(tokens, contains('test'));
    });
  });

  group('CategoryUsageProfiler.extractTopKeywords', () {
    test('extracts frequent tokens', () {
      final notes = [
        '美团外卖',
        '饿了么外卖',
        '美团午餐',
        '美团晚餐',
        '外卖',
      ];
      final keywords = CategoryUsageProfiler.extractTopKeywords(notes);
      // '外卖' appears in bigrams of multiple notes, should be top
      expect(keywords, contains('外卖'));
      expect(keywords, contains('美团'));
    });

    test('single occurrence excluded', () {
      final notes = ['独特词汇'];
      final keywords = CategoryUsageProfiler.extractTopKeywords(notes);
      // Only appears once, should be excluded (min freq = 2)
      expect(keywords, isEmpty);
    });

    test('stopwords excluded', () {
      final notes = ['的的的的', '的了在是'];
      final keywords = CategoryUsageProfiler.extractTopKeywords(notes);
      expect(keywords, isNot(contains('的')));
    });

    test('numeric tokens excluded', () {
      final notes = ['2024年12月', '2024年1月'];
      final keywords = CategoryUsageProfiler.extractTopKeywords(notes);
      expect(keywords, isNot(contains('2024')));
      expect(keywords, isNot(contains('12')));
    });
  });

  group('CategoryUsageProfile.amountToBucket', () {
    test('< 20 yuan → bucket 0', () {
      expect(CategoryUsageProfile.amountToBucket(1500), 0); // 15 yuan
    });

    test('20-50 yuan → bucket 1', () {
      expect(CategoryUsageProfile.amountToBucket(3500), 1); // 35 yuan
    });

    test('50-100 yuan → bucket 2', () {
      expect(CategoryUsageProfile.amountToBucket(7500), 2); // 75 yuan
    });

    test('100-500 yuan → bucket 3', () {
      expect(CategoryUsageProfile.amountToBucket(25000), 3); // 250 yuan
    });

    test('500-2000 yuan → bucket 4', () {
      expect(CategoryUsageProfile.amountToBucket(100000), 4); // 1000 yuan
    });

    test('>= 2000 yuan → bucket 5', () {
      expect(CategoryUsageProfile.amountToBucket(500000), 5); // 5000 yuan
    });
  });
}
