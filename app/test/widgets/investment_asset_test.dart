import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:familyledger/features/asset/update_valuation_dialog.dart';
import 'package:familyledger/features/asset/assets_page.dart';
import 'package:familyledger/features/asset/add_asset_page.dart';
import 'package:familyledger/features/asset/asset_detail_page.dart';
import 'package:familyledger/features/investment/investments_page.dart';
import 'package:familyledger/features/investment/add_investment_page.dart';
import 'package:familyledger/features/investment/investment_detail_page.dart';
import 'package:familyledger/features/investment/portfolio_chart.dart';
import 'package:familyledger/features/investment/trade_page.dart';
import 'package:familyledger/domain/providers/investment_provider.dart';

Widget wrap(Widget child) => MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(body: child),
    );

Widget wrapDialog(Widget dialog) => MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => dialog,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

void main() {
  // ══════════════════════════════════════════════════════════════════
  // Group 1: UpdateValuationDialog — full widget tests
  // ══════════════════════════════════════════════════════════════════
  group('UpdateValuationDialog', () {
    late Completer<int> submitCompleter;

    Future<void> pumpDialog(WidgetTester tester) async {
      submitCompleter = Completer<int>();
      await tester.pumpWidget(wrapDialog(
        UpdateValuationDialog(
          assetId: 'test-asset-1',
          onSubmit: (value) async {
            submitCompleter.complete(value);
          },
        ),
      ));
      // Tap button to open the dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('renders title and form elements', (tester) async {
      await pumpDialog(tester);

      expect(find.text('更新估值'), findsOneWidget);
      expect(find.text('当前估值（元）'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);
    });

    testWidgets('shows ¥ prefix in text field', (tester) async {
      await pumpDialog(tester);

      expect(find.text('¥ '), findsOneWidget);
    });

    testWidgets('shows hint text', (tester) async {
      await pumpDialog(tester);

      expect(find.text('0.00'), findsOneWidget);
    });

    testWidgets('cancel button closes dialog', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('更新估值'), findsNothing);
    });

    testWidgets('submit with empty text does nothing', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      // Dialog should still be open
      expect(find.text('更新估值'), findsOneWidget);
      expect(submitCompleter.isCompleted, isFalse);
    });

    testWidgets('submit converts yuan to cents correctly', (tester) async {
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField), '123.45');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(submitCompleter.isCompleted, isTrue);
      expect(await submitCompleter.future, 12345);
    });

    testWidgets('submit with integer value works', (tester) async {
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField), '100');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(await submitCompleter.future, 10000);
    });

    testWidgets('submit with small decimal value works', (tester) async {
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField), '0.01');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(await submitCompleter.future, 1);
    });

    testWidgets('submit with zero value does nothing', (tester) async {
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      // 0 is not > 0, so submit should be rejected
      expect(find.text('更新估值'), findsOneWidget);
      expect(submitCompleter.isCompleted, isFalse);
    });

    testWidgets('submit with negative value does nothing', (tester) async {
      await pumpDialog(tester);

      // The input formatter only allows digits and dot, so negative can't be typed
      // but testing the logic: enterText bypasses formatters in tests
      await tester.enterText(find.byType(TextField), '-10');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(submitCompleter.isCompleted, isFalse);
    });

    testWidgets('submit with non-numeric text does nothing', (tester) async {
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(submitCompleter.isCompleted, isFalse);
    });

    testWidgets('dialog closes after successful submit', (tester) async {
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField), '50');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('更新估值'), findsNothing);
    });

    testWidgets('shows loading indicator during submission', (tester) async {
      final slowCompleter = Completer<void>();
      await tester.pumpWidget(wrapDialog(
        UpdateValuationDialog(
          assetId: 'test-asset-1',
          onSubmit: (value) async {
            await slowCompleter.future;
          },
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '100');
      await tester.tap(find.text('确认'));
      await tester.pump(); // just one frame, don't settle

      // Should show CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to clean up
      slowCompleter.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('button is disabled during submission', (tester) async {
      final slowCompleter = Completer<void>();
      await tester.pumpWidget(wrapDialog(
        UpdateValuationDialog(
          assetId: 'test-asset-1',
          onSubmit: (value) async {
            await slowCompleter.future;
          },
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '100');
      await tester.tap(find.text('确认'));
      await tester.pump();

      // The FilledButton should be disabled (onPressed is null)
      final filledButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(filledButton.onPressed, isNull);

      slowCompleter.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('text field has autofocus', (tester) async {
      await pumpDialog(tester);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.autofocus, isTrue);
    });

    testWidgets('text field has number keyboard type', (tester) async {
      await pumpDialog(tester);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(
        textField.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
    });

    testWidgets('has Semantics widget for accessibility', (tester) async {
      await pumpDialog(tester);

      // Verify Semantics widget exists wrapping the text field
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == '输入新的估值金额',
        ),
        findsOneWidget,
      );
    });

    testWidgets('submit with one decimal place works', (tester) async {
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField), '99.9');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(await submitCompleter.future, 9990);
    });

    testWidgets('submit with large value works', (tester) async {
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField), '999999.99');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(await submitCompleter.future, 99999999);
    });
  });

  // ══════════════════════════════════════════════════════════════════
  // Group 2: Domain model tests — PortfolioSummary & HoldingDisplayItem
  // ══════════════════════════════════════════════════════════════════
  group('PortfolioSummary', () {
    test('default values', () {
      const summary = PortfolioSummary();
      expect(summary.totalValue, 0);
      expect(summary.totalCost, 0);
      expect(summary.totalProfit, 0);
      expect(summary.totalReturn, 0.0);
      expect(summary.holdings, isEmpty);
    });

    test('with custom values', () {
      final summary = PortfolioSummary(
        totalValue: 100000,
        totalCost: 80000,
        totalProfit: 20000,
        totalReturn: 0.25,
        holdings: [
          const HoldingDisplayItem(
            investmentId: 'inv-1',
            symbol: 'AAPL',
            name: 'Apple Inc.',
            quantity: 10,
            currentValue: 100000,
            weight: 1.0,
            returnRate: 0.25,
          ),
        ],
      );

      expect(summary.totalValue, 100000);
      expect(summary.totalCost, 80000);
      expect(summary.totalProfit, 20000);
      expect(summary.totalReturn, 0.25);
      expect(summary.holdings.length, 1);
    });
  });

  group('HoldingDisplayItem', () {
    test('stores all fields correctly', () {
      const item = HoldingDisplayItem(
        investmentId: 'inv-1',
        symbol: 'TSLA',
        name: 'Tesla Inc.',
        quantity: 5.5,
        currentValue: 550000,
        weight: 0.6,
        returnRate: -0.1,
      );

      expect(item.investmentId, 'inv-1');
      expect(item.symbol, 'TSLA');
      expect(item.name, 'Tesla Inc.');
      expect(item.quantity, 5.5);
      expect(item.currentValue, 550000);
      expect(item.weight, 0.6);
      expect(item.returnRate, -0.1);
    });

    test('supports zero weight and return rate', () {
      const item = HoldingDisplayItem(
        investmentId: 'inv-2',
        symbol: 'BTC',
        name: 'Bitcoin',
        quantity: 0.001,
        currentValue: 0,
        weight: 0.0,
        returnRate: 0.0,
      );

      expect(item.weight, 0.0);
      expect(item.returnRate, 0.0);
    });
  });

  // ══════════════════════════════════════════════════════════════════
  // Group 3: Class existence checks for Riverpod-dependent widgets
  // ══════════════════════════════════════════════════════════════════
  group('Widget classes exist', () {
    test('InvestmentsPage class exists', () {
      expect(InvestmentsPage, isNotNull);
    });

    test('AddInvestmentPage class exists', () {
      expect(AddInvestmentPage, isNotNull);
    });

    test('InvestmentDetailPage class exists', () {
      expect(InvestmentDetailPage, isNotNull);
    });

    test('PortfolioChart class exists', () {
      expect(PortfolioChart, isNotNull);
    });

    test('TradePage class exists', () {
      expect(TradePage, isNotNull);
    });

    test('AssetsPage class exists', () {
      expect(AssetsPage, isNotNull);
    });

    test('AddAssetPage class exists', () {
      expect(AddAssetPage, isNotNull);
    });

    test('AssetDetailPage class exists', () {
      expect(AssetDetailPage, isNotNull);
    });

    test('UpdateValuationDialog class exists', () {
      expect(UpdateValuationDialog, isNotNull);
    });
  });
}
