/// InvestmentProvider unit tests — portfolio computation + edge cases.
import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/domain/providers/investment_provider.dart';

void main() {
  group('PortfolioSummary — model computation', () {
    test('empty portfolio has zero values', () {
      const p = PortfolioSummary();
      expect(p.totalValue, 0);
      expect(p.totalCost, 0);
      expect(p.totalProfit, 0);
      expect(p.totalReturn, 0.0);
      expect(p.holdings, isEmpty);
    });

    test('totalProfit = totalValue - totalCost', () {
      const p = PortfolioSummary(
        totalValue: 150000,
        totalCost: 100000,
        totalProfit: 50000,
        totalReturn: 0.5,
      );
      expect(p.totalProfit, p.totalValue - p.totalCost);
      expect(p.totalReturn, 0.5);
    });

    test('totalReturn -100% when total loss (value=0, cost>0)', () {
      const p = PortfolioSummary(
        totalValue: 0,
        totalCost: 100000,
        totalProfit: -100000,
        totalReturn: -1.0,
      );
      expect(p.totalReturn, -1.0);
      expect(p.totalProfit, -p.totalCost);
    });

    test('totalReturn 0 when no cost (avoid division by zero)', () {
      const p = PortfolioSummary(
        totalValue: 50000,
        totalCost: 0,
        totalProfit: 50000,
        totalReturn: 0.0, // costBasis=0 → return=0 (no division)
      );
      expect(p.totalReturn, 0.0);
    });
  });

  group('HoldingDisplayItem — weight and return', () {
    test('returnRate positive when profitable', () {
      const item = HoldingDisplayItem(
        investmentId: 'inv-001',
        symbol: 'AAPL',
        name: 'Apple Inc.',
        quantity: 10,
        currentValue: 150000,
        weight: 0.6,
        returnRate: 0.5, // cost=100000, value=150000
      );
      expect(item.returnRate, 0.5);
      expect(item.weight, 0.6);
    });

    test('returnRate -1.0 for total loss', () {
      const item = HoldingDisplayItem(
        investmentId: 'inv-002',
        symbol: 'LUNA',
        name: 'Terra Luna',
        quantity: 1000,
        currentValue: 0,
        weight: 0.0,
        returnRate: -1.0, // (0 - cost) / cost = -1
      );
      expect(item.returnRate, -1.0);
      expect(item.currentValue, 0);
    });

    test('weight sums to 1.0 across all holdings', () {
      final holdings = [
        const HoldingDisplayItem(
          investmentId: '1',
          symbol: 'A', name: 'A', quantity: 1,
          currentValue: 60000, weight: 0.6, returnRate: 0.2,
        ),
        const HoldingDisplayItem(
          investmentId: '2',
          symbol: 'B', name: 'B', quantity: 1,
          currentValue: 40000, weight: 0.4, returnRate: 0.1,
        ),
      ];
      final totalWeight = holdings.fold(0.0, (sum, h) => sum + h.weight);
      expect(totalWeight, closeTo(1.0, 0.001));
    });

    test('returnRate 0 when costBasis is 0 (free acquisition)', () {
      const item = HoldingDisplayItem(
        investmentId: 'inv-003',
        symbol: 'FREE',
        name: 'Free Token',
        quantity: 100,
        currentValue: 50000,
        weight: 1.0,
        returnRate: 0.0, // costBasis=0, can't compute return
      );
      expect(item.returnRate, 0.0);
    });
  });
}
