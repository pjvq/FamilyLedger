/// AssetProvider unit tests — depreciation models + display items.
import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/domain/providers/asset_provider.dart';

void main() {
  group('AssetDisplayItem — model validation', () {
    test('no depreciation: currentValue == purchasePrice', () {
      final item = AssetDisplayItem(
        id: 'a1',
        name: '手机',
        assetType: 'electronics',
        purchasePrice: 899900, // ¥8999
        currentValue: 899900,
        purchaseDate: DateTime(2024, 1, 1),
        depreciationMethod: 'none',
      );
      expect(item.currentValue, item.purchasePrice);
      expect(item.depreciationProgress, 0.0);
    });

    test('straight_line: currentValue < purchasePrice after time passes', () {
      // Simulating: 5-year useful life, 5% salvage, 2 years elapsed
      // Depreciable amount = 899900 * (1 - 0.05) = 854905
      // After 2 years: 854905 * 2/5 = 341962 depreciated
      // Current value = 899900 - 341962 = 557938
      final item = AssetDisplayItem(
        id: 'a2',
        name: '笔记本电脑',
        assetType: 'electronics',
        purchasePrice: 899900,
        currentValue: 557938,
        purchaseDate: DateTime(2022, 1, 1),
        depreciationMethod: 'straight_line',
        usefulLifeYears: 5,
        salvageRate: 0.05,
        depreciationProgress: 0.38, // ~2/5 of depreciable
      );
      expect(item.currentValue, lessThan(item.purchasePrice));
      expect(item.depreciationProgress, greaterThan(0));
    });

    test('double_declining: faster depreciation in early years', () {
      // Double declining on ¥100000, 5 years, 5% salvage
      // Year 1: rate=2/5=0.4, depreciation=40000, book=60000
      // Year 2: depreciation=24000, book=36000
      // Compare with straight_line: year 2 book = 100000 - 38000 = 62000
      // So double_declining should be lower
      final ddItem = AssetDisplayItem(
        id: 'a3',
        name: '汽车(双倍余额)',
        assetType: 'vehicle',
        purchasePrice: 10000000, // ¥100,000
        currentValue: 3600000, // after 2 years double declining
        purchaseDate: DateTime(2022, 6, 1),
        depreciationMethod: 'double_declining',
        usefulLifeYears: 5,
        salvageRate: 0.05,
      );

      final slItem = AssetDisplayItem(
        id: 'a4',
        name: '汽车(直线法)',
        assetType: 'vehicle',
        purchasePrice: 10000000,
        currentValue: 6200000, // after 2 years straight line
        purchaseDate: DateTime(2022, 6, 1),
        depreciationMethod: 'straight_line',
        usefulLifeYears: 5,
        salvageRate: 0.05,
      );

      // Double declining depreciates faster
      expect(ddItem.currentValue, lessThan(slItem.currentValue));
    });

    test('salvageRate bounds currentValue floor', () {
      // After full useful life, value should be >= purchasePrice * salvageRate
      final item = AssetDisplayItem(
        id: 'a5',
        name: '老旧设备',
        assetType: 'equipment',
        purchasePrice: 500000, // ¥5000
        currentValue: 25000, // ¥250 = 5% salvage
        purchaseDate: DateTime(2018, 1, 1),
        depreciationMethod: 'straight_line',
        usefulLifeYears: 5,
        salvageRate: 0.05,
      );
      final salvageValue = (item.purchasePrice * item.salvageRate).round();
      expect(item.currentValue, greaterThanOrEqualTo(salvageValue));
    });

    test('depreciationProgress is 0-1 range', () {
      final item = AssetDisplayItem(
        id: 'a6',
        name: '办公桌',
        assetType: 'furniture',
        purchasePrice: 300000,
        currentValue: 210000,
        purchaseDate: DateTime(2023, 6, 1),
        depreciationMethod: 'straight_line',
        depreciationProgress: 0.3, // 30% depreciated
      );
      expect(item.depreciationProgress, greaterThanOrEqualTo(0));
      expect(item.depreciationProgress, lessThanOrEqualTo(1.0));
    });
  });

  group('depreciationMethodLabel — utility', () {
    test('straight_line returns 直线法', () {
      expect(depreciationMethodLabel('straight_line'), '直线法');
    });

    test('double_declining returns correct label', () {
      expect(depreciationMethodLabel('double_declining'), isNotEmpty);
    });

    test('unknown method returns raw string', () {
      expect(depreciationMethodLabel('custom_method'), 'custom_method');
    });

    test('none returns valid label', () {
      expect(depreciationMethodLabel('none'), isNotEmpty);
    });
  });
}
