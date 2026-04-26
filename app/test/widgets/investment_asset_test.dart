// Comprehensive widget tests for Investment + Asset features.
// Covers: InvestmentsPage, AddInvestmentPage, InvestmentDetailPage,
//         PortfolioChart, TradePage, AssetsPage, AddAssetPage,
//         AssetDetailPage, UpdateValuationDialog.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familyledger/data/local/database.dart' as db;
import 'package:familyledger/core/widgets/skeleton_loading.dart';
import 'package:familyledger/domain/providers/investment_provider.dart';
import 'package:familyledger/domain/providers/market_data_provider.dart';
import 'package:familyledger/domain/providers/asset_provider.dart';

import 'package:familyledger/features/investment/investments_page.dart';
import 'package:familyledger/features/investment/add_investment_page.dart';
import 'package:familyledger/features/investment/investment_detail_page.dart';
import 'package:familyledger/features/investment/portfolio_chart.dart';
import 'package:familyledger/features/investment/trade_page.dart';
import 'package:familyledger/features/asset/assets_page.dart';
import 'package:familyledger/features/asset/add_asset_page.dart';
import 'package:familyledger/features/asset/asset_detail_page.dart';
import 'package:familyledger/features/asset/update_valuation_dialog.dart';

import 'test_helpers.dart';

// ═══════════════════════════════════════════════════════════════
// Test-data factories
// ═══════════════════════════════════════════════════════════════

db.Investment _inv({
  String id = 'inv-1',
  String symbol = '600519',
  String name = '贵州茅台',
  String marketType = 'a_share',
  double quantity = 100,
  int costBasis = 18000000,
}) =>
    db.Investment(
      id: id,
      userId: 'u1',
      familyId: '',
      symbol: symbol,
      name: name,
      marketType: marketType,
      quantity: quantity,
      costBasis: costBasis,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 6, 1),
    );

db.InvestmentTrade _trade({
  String id = 'trade-1',
  String investmentId = 'inv-1',
  String tradeType = 'buy',
  double quantity = 100,
  int price = 180000,
  int totalAmount = 18000000,
  int fee = 500,
}) =>
    db.InvestmentTrade(
      id: id,
      investmentId: investmentId,
      tradeType: tradeType,
      quantity: quantity,
      price: price,
      totalAmount: totalAmount,
      fee: fee,
      tradeDate: DateTime(2024, 1, 15),
      createdAt: DateTime(2024, 1, 15),
    );

QuoteDisplay _quote({
  String symbol = '600519',
  String name = '贵州茅台',
  String marketType = 'a_share',
  int currentPrice = 190000,
  int changeAmount = 2000,
  double changePercent = 1.06,
}) =>
    QuoteDisplay(
      symbol: symbol,
      name: name,
      marketType: marketType,
      currentPrice: currentPrice,
      changeAmount: changeAmount,
      changePercent: changePercent,
      updatedAt: DateTime(2024, 6, 1),
    );

List<PricePoint> _sparkline({int count = 10}) => List.generate(
      count,
      (i) => PricePoint(
        timestamp: DateTime(2024, 5, 20 + i),
        price: 185000 + i * 500,
      ),
    );

HoldingDisplayItem _holding({
  String investmentId = 'inv-1',
  String symbol = '600519',
  String name = '贵州茅台',
  double quantity = 100,
  int currentValue = 19000000,
  double weight = 0.6,
  double returnRate = 0.056,
}) =>
    HoldingDisplayItem(
      investmentId: investmentId,
      symbol: symbol,
      name: name,
      quantity: quantity,
      currentValue: currentValue,
      weight: weight,
      returnRate: returnRate,
    );

AssetDisplayItem _asset({
  String id = 'asset-1',
  String name = '北京朝阳区公寓',
  String assetType = 'real_estate',
  int purchasePrice = 500000000,
  int currentValue = 480000000,
  String description = '90平 两居室',
  String depreciationMethod = 'none',
  int usefulLifeYears = 30,
  double salvageRate = 0.05,
  double depreciationProgress = 0.0,
}) =>
    AssetDisplayItem(
      id: id,
      name: name,
      assetType: assetType,
      purchasePrice: purchasePrice,
      currentValue: currentValue,
      purchaseDate: DateTime(2020, 6, 1),
      description: description,
      depreciationMethod: depreciationMethod,
      usefulLifeYears: usefulLifeYears,
      salvageRate: salvageRate,
      depreciationProgress: depreciationProgress,
    );

ValuationRecord _valuation({
  String id = 'val-1',
  int value = 480000000,
  String source = 'manual',
  DateTime? date,
}) =>
    ValuationRecord(
      id: id,
      value: value,
      source: source,
      valuationDate: date ?? DateTime(2024, 3, 1),
    );

// ═══════════════════════════════════════════════════════════════
// main
// ═══════════════════════════════════════════════════════════════

void main() {
  // ─────────────────────────────────────────────────────────────
  // 1. InvestmentsPage
  // ─────────────────────────────────────────────────────────────
  group('InvestmentsPage', () {
    testWidgets('loading state shows SkeletonList',
        (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentsPage(),
        investment: const InvestmentState(isLoading: true),
      ));
      await tester.pump();
      expect(find.byType(SkeletonList), findsOneWidget);
    });

    testWidgets('empty state shows hint text', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentsPage(),
        investment: const InvestmentState(),
      ));
      await tester.pump();
      expect(find.text('还没有投资持仓'), findsOneWidget);
      expect(find.text('点击下方按钮添加第一个投资'), findsOneWidget);
    });

    testWidgets('renders portfolio summary card with total value',
        (tester) async {
      final p = PortfolioSummary(
        totalValue: 19000000,
        totalCost: 18000000,
        totalProfit: 1000000,
        totalReturn: 0.0556,
        holdings: [_holding()],
      );
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentsPage(),
        investment: InvestmentState(
          investments: [_inv()],
          portfolio: p,
        ),
        marketData: MarketDataState(
          quotes: {'600519:a_share': _quote()},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('总市值'), findsOneWidget);
    });

    testWidgets('renders investment list item with quote data',
        (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentsPage(),
        investment: InvestmentState(
          investments: [i],
          portfolio: PortfolioSummary(
            totalValue: 19000000,
            holdings: [_holding()],
          ),
        ),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('贵州茅台'), findsOneWidget);
      expect(find.text('600519'), findsOneWidget);
      expect(find.text('A股'), findsOneWidget);
      expect(find.text('+1.06%'), findsOneWidget);
    });

    testWidgets('sparkline renders CustomPaint when data present',
        (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentsPage(),
        investment: InvestmentState(
          investments: [i],
          portfolio: PortfolioSummary(holdings: [_holding()]),
        ),
        marketData: MarketDataState(
          quotes: {key: _quote()},
          sparklineCache: {key: _sparkline()},
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('sparkline placeholder when no sparkline data',
        (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentsPage(),
        investment: InvestmentState(
          investments: [i],
          portfolio: PortfolioSummary(holdings: [_holding()]),
        ),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Still renders CustomPaint (with empty prices list → painter draws nothing)
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('multiple investments render', (tester) async {
      final i1 = _inv();
      final i2 = _inv(
        id: 'inv-2',
        symbol: 'AAPL',
        name: '苹果公司',
        marketType: 'us_stock',
      );
      final k1 = MarketDataState.quoteKey(i1.symbol, i1.marketType);
      final k2 = MarketDataState.quoteKey(i2.symbol, i2.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentsPage(),
        investment: InvestmentState(
          investments: [i1, i2],
          portfolio: PortfolioSummary(holdings: [
            _holding(),
            _holding(
              investmentId: 'inv-2',
              symbol: 'AAPL',
              name: '苹果公司',
              weight: 0.4,
            ),
          ]),
        ),
        marketData: MarketDataState(quotes: {
          k1: _quote(),
          k2: _quote(
            symbol: 'AAPL',
            name: '苹果公司',
            marketType: 'us_stock',
            changePercent: -0.5,
            changeAmount: -100,
          ),
        }),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('贵州茅台'), findsOneWidget);
      expect(find.text('苹果公司'), findsOneWidget);
    });

    testWidgets('FAB shows "添加投资"', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const InvestmentsPage()));
      await tester.pump();
      expect(find.text('添加投资'), findsOneWidget);
    });

    testWidgets('profit percentage displayed for positive return',
        (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentsPage(),
        investment: InvestmentState(
          investments: [_inv()],
          portfolio: PortfolioSummary(
            totalValue: 20000000,
            totalCost: 18000000,
            totalProfit: 2000000,
            totalReturn: 0.1111,
            holdings: [_holding()],
          ),
        ),
        marketData: MarketDataState(
          quotes: {'600519:a_share': _quote()},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('+11.11%'), findsOneWidget);
    });

    testWidgets('dark theme renders without errors', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentsPage(),
        theme: ThemeData.dark(useMaterial3: true),
        investment: InvestmentState(
          investments: [_inv()],
          portfolio: PortfolioSummary(
            totalValue: 19000000,
            holdings: [_holding()],
          ),
        ),
        marketData: MarketDataState(
          quotes: {'600519:a_share': _quote()},
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('贵州茅台'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // 2. PortfolioChart
  // ─────────────────────────────────────────────────────────────
  group('PortfolioChart', () {
    testWidgets('empty holdings shows placeholder', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const PortfolioChart(),
        investment: const InvestmentState(
          portfolio: PortfolioSummary(holdings: []),
        ),
      ));
      await tester.pump();
      expect(find.text('暂无持仓数据'), findsOneWidget);
    });

    testWidgets('single holding shows pie + legend', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const PortfolioChart(),
        investment: InvestmentState(
          portfolio: PortfolioSummary(holdings: [_holding(weight: 1.0)]),
        ),
      ));
      await tester.pump();
      expect(find.text('持仓分布'), findsOneWidget);
      expect(find.text('600519'), findsOneWidget);
      expect(find.text('100.0%'), findsOneWidget);
    });

    testWidgets('diversified holdings show multiple legend entries',
        (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const PortfolioChart(),
        investment: InvestmentState(
          portfolio: PortfolioSummary(holdings: [
            _holding(symbol: '600519', weight: 0.6),
            _holding(
              investmentId: 'inv-2',
              symbol: 'AAPL',
              name: '苹果',
              weight: 0.25,
            ),
            _holding(
              investmentId: 'inv-3',
              symbol: 'BTC',
              name: '比特币',
              weight: 0.15,
            ),
          ]),
        ),
      ));
      await tester.pump();
      expect(find.text('600519'), findsOneWidget);
      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('BTC'), findsOneWidget);
    });

    testWidgets('dark theme renders', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const PortfolioChart(),
        theme: ThemeData.dark(useMaterial3: true),
        investment: InvestmentState(
          portfolio: PortfolioSummary(holdings: [_holding(weight: 1.0)]),
        ),
      ));
      await tester.pump();
      expect(find.text('持仓分布'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // 3. AddInvestmentPage
  // ─────────────────────────────────────────────────────────────
  group('AddInvestmentPage', () {
    testWidgets('renders market selector + search field', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const AddInvestmentPage()));
      await tester.pump();
      expect(find.text('添加投资'), findsOneWidget);
      expect(find.text('A股'), findsOneWidget);
      expect(find.text('港股'), findsOneWidget);
      expect(find.text('美股'), findsOneWidget);
      expect(find.text('加密货币'), findsOneWidget);
      expect(find.text('基金'), findsOneWidget);
    });

    testWidgets('search field accepts text', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const AddInvestmentPage()));
      await tester.pump();
      final field = find.byType(TextField);
      expect(field, findsOneWidget);
      await tester.enterText(field, '茅台');
      await tester.pump();
      expect(find.text('茅台'), findsWidgets);
    });

    testWidgets('shows search results dropdown', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AddInvestmentPage(),
        marketData: const MarketDataState(searchResults: [
          SymbolSearchResult(
            symbol: '600519',
            name: '贵州茅台',
            marketType: 'a_share',
          ),
        ]),
      ));
      await tester.pump();
      expect(find.text('贵州茅台'), findsOneWidget);
      expect(find.textContaining('600519'), findsOneWidget);
    });

    testWidgets('tapping search result reveals buy form', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AddInvestmentPage(),
        marketData: MarketDataState(
          searchResults: const [
            SymbolSearchResult(
              symbol: '600519',
              name: '贵州茅台',
              marketType: 'a_share',
            ),
          ],
          quotes: {'600519:a_share': _quote()},
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('贵州茅台'));
      await tester.pumpAndSettle();
      expect(find.text('买入 贵州茅台'), findsOneWidget);
      expect(find.text('确认买入'), findsOneWidget);
    });

    testWidgets('dark theme renders', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AddInvestmentPage(),
        theme: ThemeData.dark(useMaterial3: true),
      ));
      await tester.pump();
      expect(find.text('添加投资'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // 4. InvestmentDetailPage
  // ─────────────────────────────────────────────────────────────
  group('InvestmentDetailPage', () {
    testWidgets('shows "投资不存在" when not found', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentDetailPage(investmentId: 'nope'),
      ));
      await tester.pump();
      expect(find.text('投资不存在'), findsOneWidget);
    });

    testWidgets('renders header price & change', (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentDetailPage(investmentId: 'inv-1'),
        investment: InvestmentState(investments: [i]),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pump();
      expect(find.text('¥1900.00'), findsOneWidget);
      expect(find.text('+1.06%'), findsOneWidget);
      expect(find.text('持仓信息'), findsOneWidget);
    });

    testWidgets('shows empty chart text when no history', (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentDetailPage(investmentId: 'inv-1'),
        investment: InvestmentState(investments: [i]),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pump();
      expect(find.text('暂无走势数据'), findsOneWidget);
    });

    testWidgets('hides empty text when history present', (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentDetailPage(investmentId: 'inv-1'),
        investment: InvestmentState(investments: [i]),
        marketData: MarketDataState(
          quotes: {key: _quote()},
          priceHistory: _sparkline(count: 20),
        ),
      ));
      await tester.pump();
      expect(find.text('暂无走势数据'), findsNothing);
    });

    testWidgets('time range buttons present', (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentDetailPage(investmentId: 'inv-1'),
        investment: InvestmentState(investments: [i]),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pump();
      for (final label in ['1W', '1M', '3M', '6M', '1Y', '全部']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('return mode labels present', (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentDetailPage(investmentId: 'inv-1'),
        investment: InvestmentState(investments: [i]),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pump();
      expect(find.text('总收益率'), findsOneWidget);
      expect(find.text('年化收益率'), findsOneWidget);
      expect(find.text('IRR'), findsOneWidget);
    });

    testWidgets('empty trades shows placeholder', (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentDetailPage(investmentId: 'inv-1'),
        investment: InvestmentState(investments: [i]),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pump();
      expect(find.text('暂无交易记录'), findsOneWidget);
    });

    testWidgets('trade records render', (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentDetailPage(investmentId: 'inv-1'),
        investment: InvestmentState(
          investments: [i],
          currentTrades: [_trade()],
        ),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pump();
      expect(find.text('买入'), findsWidgets);
    });

    testWidgets('loss displayed with negative change', (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentDetailPage(investmentId: 'inv-1'),
        investment: InvestmentState(investments: [i]),
        marketData: MarketDataState(quotes: {
          key: _quote(
            currentPrice: 170000,
            changeAmount: -1000,
            changePercent: -0.59,
          ),
        }),
      ));
      await tester.pump();
      expect(find.text('-0.59%'), findsOneWidget);
    });

    testWidgets('dark theme renders', (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const InvestmentDetailPage(investmentId: 'inv-1'),
        theme: ThemeData.dark(useMaterial3: true),
        investment: InvestmentState(investments: [i]),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pump();
      expect(find.text('持仓信息'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // 5. TradePage
  // ─────────────────────────────────────────────────────────────
  group('TradePage', () {
    testWidgets('renders buy/sell toggle and form fields', (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const TradePage(investmentId: 'inv-1'),
        investment: InvestmentState(investments: [i]),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('买入'), findsWidgets);
      expect(find.text('卖出'), findsWidgets);
      expect(find.text('数量'), findsOneWidget);
      expect(find.text('成交价'), findsOneWidget);
      expect(find.text('手续费'), findsWidgets); // label + total row
      expect(find.text('确认买入'), findsOneWidget);
    });

    testWidgets('shows current holding quantity', (tester) async {
      final i = _inv(quantity: 200);
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const TradePage(investmentId: 'inv-1'),
        investment: InvestmentState(investments: [i]),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('当前持仓'), findsOneWidget);
      expect(find.text('200 股'), findsOneWidget);
    });

    testWidgets('switching to sell updates button text', (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const TradePage(investmentId: 'inv-1'),
        investment: InvestmentState(investments: [i]),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('卖出').first);
      await tester.pump();
      expect(find.text('确认卖出'), findsOneWidget);
    });

    testWidgets('validation snackbar on empty submit', (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const TradePage(investmentId: 'inv-1'),
        investment: InvestmentState(investments: [i]),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pumpAndSettle();
      // Clear the pre-filled price first
      final priceField = find.byType(TextField).at(1);
      await tester.enterText(priceField, '');
      await tester.pump();
      // Scroll submit button into view
      final submitButton = find.text('确认买入');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pump();
      expect(find.text('请输入有效的数量和价格'), findsOneWidget);
    });

    testWidgets('total row updates on input', (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const TradePage(investmentId: 'inv-1'),
        investment: InvestmentState(investments: [i]),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '10'); // quantity
      await tester.pump();
      await tester.enterText(fields.at(1), '100'); // price
      await tester.pump();
      // subtotal 1000, total 1000 (fee=0)
      expect(find.text('¥1000.00'), findsWidgets);
    });

    testWidgets('dark theme renders', (tester) async {
      final i = _inv();
      final key = MarketDataState.quoteKey(i.symbol, i.marketType);
      await tester.pumpWidget(wrapWithProviders(
        const TradePage(investmentId: 'inv-1'),
        theme: ThemeData.dark(useMaterial3: true),
        investment: InvestmentState(investments: [i]),
        marketData: MarketDataState(quotes: {key: _quote()}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('买入'), findsWidgets);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // 6. AssetsPage
  // ─────────────────────────────────────────────────────────────
  group('AssetsPage', () {
    testWidgets('loading state', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetsPage(),
        asset: const AssetState(isLoading: true),
      ));
      await tester.pump();
      expect(find.byType(SkeletonList), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const AssetsPage()));
      await tester.pump();
      expect(find.text('还没有固定资产'), findsOneWidget);
    });

    testWidgets('summary card shows total net value', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetsPage(),
        asset: AssetState(
          assets: [_asset()],
          totalNetValue: 480000000,
        ),
      ));
      await tester.pump();
      expect(find.text('资产总净值'), findsOneWidget);
      // Summary + card both show the value
      expect(find.textContaining('480.00万'), findsWidgets);
    });

    testWidgets('real_estate card renders type label', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetsPage(),
        asset: AssetState(assets: [_asset()], totalNetValue: 480000000),
      ));
      await tester.pump();
      expect(find.text('北京朝阳区公寓'), findsOneWidget);
      expect(find.text('房产'), findsOneWidget);
    });

    testWidgets('vehicle card with straight-line depreciation bar',
        (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetsPage(),
        asset: AssetState(
          assets: [
            _asset(
              id: 'v',
              name: '特斯拉Model Y',
              assetType: 'vehicle',
              purchasePrice: 2600000,
              currentValue: 1800000,
              depreciationMethod: 'straight_line',
              depreciationProgress: 0.31,
            ),
          ],
          totalNetValue: 1800000,
        ),
      ));
      await tester.pump();
      expect(find.text('特斯拉Model Y'), findsOneWidget);
      expect(find.text('车辆'), findsOneWidget);
      expect(find.text('已折旧'), findsOneWidget);
      expect(find.text('31.0%'), findsOneWidget);
      expect(find.text('直线法'), findsOneWidget);
    });

    testWidgets('double declining label shown', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetsPage(),
        asset: AssetState(
          assets: [
            _asset(
              depreciationMethod: 'double_declining',
              depreciationProgress: 0.2,
            ),
          ],
          totalNetValue: 480000000,
        ),
      ));
      await tester.pump();
      expect(find.text('双倍余额递减法'), findsOneWidget);
    });

    testWidgets('no depreciation bar when method is none', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetsPage(),
        asset: AssetState(
          assets: [_asset(depreciationMethod: 'none')],
          totalNetValue: 480000000,
        ),
      ));
      await tester.pump();
      expect(find.text('已折旧'), findsNothing);
    });

    testWidgets('FAB shows "添加资产"', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const AssetsPage()));
      await tester.pump();
      expect(find.text('添加资产'), findsOneWidget);
    });

    testWidgets('multiple assets render', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetsPage(),
        asset: AssetState(
          assets: [
            _asset(),
            _asset(
              id: 'a2',
              name: 'MacBook Pro',
              assetType: 'electronics',
              purchasePrice: 2400000,
              currentValue: 1500000,
            ),
          ],
          totalNetValue: 481500000,
        ),
      ));
      await tester.pump();
      expect(find.text('北京朝阳区公寓'), findsOneWidget);
      expect(find.text('MacBook Pro'), findsOneWidget);
    });

    testWidgets('dark theme renders', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetsPage(),
        theme: ThemeData.dark(useMaterial3: true),
        asset: AssetState(
          assets: [
            _asset(
              depreciationMethod: 'straight_line',
              depreciationProgress: 0.5,
            ),
          ],
          totalNetValue: 480000000,
        ),
      ));
      await tester.pump();
      expect(find.text('北京朝阳区公寓'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // 7. AddAssetPage
  // ─────────────────────────────────────────────────────────────
  group('AddAssetPage', () {
    testWidgets('renders form fields and type selector', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const AddAssetPage()));
      await tester.pump();
      expect(find.text('添加资产'), findsWidgets); // appBar + FAB text overlap
      expect(find.text('资产名称'), findsOneWidget);
      expect(find.text('资产类型'), findsOneWidget);
      expect(find.text('房产'), findsOneWidget);
      expect(find.text('车辆'), findsOneWidget);
      expect(find.text('电子'), findsOneWidget);
      expect(find.text('家具'), findsOneWidget);
      expect(find.text('珠宝'), findsOneWidget);
      expect(find.text('其他'), findsOneWidget);
    });

    testWidgets('validates empty name', (tester) async {
      // Use a tall surface so all form fields + button fit without scrolling
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapWithProviders(const AddAssetPage()));
      await tester.pump();
      // Enter price but no name — fields: name(0), price(1), description(2)
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), '10000');
      await tester.pump();
      // Tap the submit button (FilledButton.icon → find via icon)
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pump();
      expect(find.text('请输入资产名称'), findsOneWidget);
    });

    testWidgets('validates empty price', (tester) async {
      // Use a tall surface so all form fields + button fit without scrolling
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapWithProviders(const AddAssetPage()));
      await tester.pump();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '测试');
      await tester.pump();
      // Tap the submit button (FilledButton.icon → find via icon)
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pump();
      expect(find.text('请输入购入价格'), findsOneWidget);
    });

    testWidgets('depreciation section expands on tap', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const AddAssetPage()));
      await tester.pump();
      expect(find.text('折旧设置'), findsOneWidget);
      await tester.ensureVisible(find.text('折旧设置'));
      await tester.tap(find.text('折旧设置'));
      await tester.pumpAndSettle();
      expect(find.text('直线法'), findsOneWidget);
      expect(find.text('双倍余额'), findsOneWidget);
    });

    testWidgets('dark theme renders', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AddAssetPage(),
        theme: ThemeData.dark(useMaterial3: true),
      ));
      await tester.pump();
      expect(find.text('添加资产'), findsWidgets);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // 8. AssetDetailPage
  // ─────────────────────────────────────────────────────────────
  group('AssetDetailPage', () {
    testWidgets('loading spinner when no data', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetDetailPage(assetId: 'asset-1'),
        asset: const AssetState(isLoading: true),
      ));
      await tester.pump();
      expect(find.byType(SkeletonList), findsOneWidget);
    });

    testWidgets('shows "资产不存在" when null', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetDetailPage(assetId: 'asset-1'),
      ));
      await tester.pump();
      expect(find.text('资产不存在'), findsOneWidget);
    });

    testWidgets('renders asset header', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetDetailPage(assetId: 'asset-1'),
        asset: AssetState(currentAsset: _asset()),
      ));
      await tester.pump();
      expect(find.text('北京朝阳区公寓'), findsWidgets);
      expect(find.text('房产'), findsOneWidget);
      expect(find.text('当前净值'), findsOneWidget);
    });

    testWidgets('depreciation progress in header when active',
        (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetDetailPage(assetId: 'asset-1'),
        asset: AssetState(
          currentAsset: _asset(
            depreciationMethod: 'straight_line',
            depreciationProgress: 0.25,
          ),
        ),
      ));
      await tester.pump();
      expect(find.textContaining('已折旧 25.0%'), findsOneWidget);
    });

    testWidgets('chart placeholder when < 2 valuations', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetDetailPage(assetId: 'asset-1'),
        asset: AssetState(
          currentAsset: _asset(),
          valuations: [_valuation()],
        ),
      ));
      await tester.pump();
      expect(find.text('需要2条以上估值记录才能显示趋势图'), findsOneWidget);
    });

    testWidgets('chart renders with ≥ 2 valuations', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetDetailPage(assetId: 'asset-1'),
        asset: AssetState(
          currentAsset: _asset(),
          valuations: [
            _valuation(id: 'v1', date: DateTime(2023, 1, 1)),
            _valuation(id: 'v2', value: 490000000, date: DateTime(2024, 1, 1)),
          ],
        ),
      ));
      await tester.pump();
      expect(find.text('需要2条以上估值记录才能显示趋势图'), findsNothing);
    });

    testWidgets('asset info card shows correct fields', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetDetailPage(assetId: 'asset-1'),
        asset: AssetState(
          currentAsset: _asset(
            depreciationMethod: 'straight_line',
            usefulLifeYears: 30,
            salvageRate: 0.05,
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('资产信息'), findsOneWidget);
      expect(find.text('购入价格'), findsOneWidget);
      expect(find.text('购入日期'), findsOneWidget);
      expect(find.text('折旧方式'), findsOneWidget);
      expect(find.text('直线法'), findsOneWidget);
      expect(find.text('使用年限'), findsOneWidget);
      expect(find.text('30年'), findsOneWidget);
      expect(find.text('残值率'), findsOneWidget);
      expect(find.text('5%'), findsOneWidget);
    });

    testWidgets('empty valuations shows placeholder', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetDetailPage(assetId: 'asset-1'),
        asset: AssetState(currentAsset: _asset()),
      ));
      await tester.pump();
      expect(find.text('暂无估值记录'), findsOneWidget);
    });

    testWidgets('valuation records render source labels', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetDetailPage(assetId: 'asset-1'),
        asset: AssetState(
          currentAsset: _asset(),
          valuations: [
            _valuation(id: 'v1', source: 'manual'),
            _valuation(
              id: 'v2',
              source: 'depreciation',
              value: 470000000,
            ),
          ],
        ),
      ));
      await tester.pump();
      expect(find.text('手动估值'), findsOneWidget);
      expect(find.text('折旧计算'), findsOneWidget);
    });

    testWidgets('action buttons present', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetDetailPage(assetId: 'asset-1'),
        asset: AssetState(currentAsset: _asset()),
      ));
      await tester.pump();
      expect(find.text('更新估值'), findsOneWidget);
      expect(find.text('折旧规则'), findsOneWidget);
    });

    testWidgets('dark theme renders', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AssetDetailPage(assetId: 'asset-1'),
        theme: ThemeData.dark(useMaterial3: true),
        asset: AssetState(
          currentAsset: _asset(
            depreciationMethod: 'double_declining',
            depreciationProgress: 0.4,
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('北京朝阳区公寓'), findsWidgets);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // 9. UpdateValuationDialog
  // ─────────────────────────────────────────────────────────────
  group('UpdateValuationDialog', () {
    Widget buildDialog({
      Future<void> Function(int)? onSubmit,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme ?? ThemeData.light(useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => UpdateValuationDialog(
                    assetId: 'asset-1',
                    onSubmit: onSubmit ?? (_) async {},
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders title, input, buttons', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('更新估值'), findsOneWidget);
      expect(find.text('当前估值（元）'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);
    });

    testWidgets('cancel closes dialog', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('更新估值'), findsNothing);
    });

    testWidgets('valid value calls onSubmit with cents', (tester) async {
      int? submitted;
      await tester.pumpWidget(buildDialog(
        onSubmit: (v) async => submitted = v,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '5000.50');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(submitted, 500050);
    });

    testWidgets('empty input does NOT call onSubmit', (tester) async {
      bool called = false;
      await tester.pumpWidget(buildDialog(
        onSubmit: (_) async => called = true,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(called, isFalse);
    });

    testWidgets('zero value does NOT call onSubmit', (tester) async {
      bool called = false;
      await tester.pumpWidget(buildDialog(
        onSubmit: (_) async => called = true,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(called, isFalse);
    });

    testWidgets('negative input rejected by formatter', (tester) async {
      bool called = false;
      await tester.pumpWidget(buildDialog(
        onSubmit: (_) async => called = true,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '-10');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(called, isFalse);
    });

    testWidgets('shows loading spinner during submission', (tester) async {
      final blocker = Completer<void>();
      await tester.pumpWidget(buildDialog(
        onSubmit: (_) => blocker.future,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '100');
      await tester.tap(find.text('确认'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      blocker.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('dark theme renders', (tester) async {
      await tester.pumpWidget(
        buildDialog(theme: ThemeData.dark(useMaterial3: true)),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('更新估值'), findsOneWidget);
    });
  });
}
