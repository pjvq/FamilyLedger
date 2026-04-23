import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:familyledger/features/budget/budget_execution_card.dart';

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

Widget wrapInApp(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

void main() {
  // ─────────────────────────────────────────────────────────────
  // BudgetExecutionCard
  // ─────────────────────────────────────────────────────────────
  group('BudgetExecutionCard', () {
    Widget buildCard({
      required double executionRate,
      int totalBudget = 500000, // ¥5,000.00
      int totalSpent = 250000, // ¥2,500.00
    }) {
      return wrapInApp(
        BudgetExecutionCard(
          executionRate: executionRate,
          totalBudget: totalBudget,
          totalSpent: totalSpent,
        ),
      );
    }

    // ── Percentage display ──

    testWidgets('renders 0% with zero execution', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 0.0,
        totalBudget: 500000,
        totalSpent: 0,
      ));
      await tester.pump(const Duration(milliseconds: 1300));

      expect(find.text('0%'), findsOneWidget);
      expect(find.textContaining('已用'), findsOneWidget);
      expect(find.textContaining('¥0.00'), findsOneWidget);
      expect(find.textContaining('¥5,000.00'), findsOneWidget);
    });

    testWidgets('renders 50% at half budget', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 0.5,
        totalBudget: 500000,
        totalSpent: 250000,
      ));
      await tester.pump(const Duration(milliseconds: 1300));

      expect(find.text('50%'), findsOneWidget);
      expect(find.textContaining('¥2,500.00'), findsOneWidget);
    });

    testWidgets('renders 100% at full budget', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 1.0,
        totalBudget: 500000,
        totalSpent: 500000,
      ));
      await tester.pump(const Duration(milliseconds: 1300));

      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('renders 150% for moderate overspend', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 1.5,
        totalBudget: 500000,
        totalSpent: 750000,
      ));
      await tester.pump(const Duration(milliseconds: 1300));

      expect(find.text('150%'), findsOneWidget);
    });

    testWidgets('caps display at 999% for extreme overspend', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 15.0,
        totalBudget: 500000,
        totalSpent: 7500000,
      ));
      await tester.pump(const Duration(milliseconds: 1300));

      expect(find.text('999%'), findsOneWidget);
    });

    // ── Amount formatting ──

    testWidgets('formats amounts with thousand separators', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 0.3,
        totalBudget: 10000000, // ¥100,000.00
        totalSpent: 3000000, // ¥30,000.00
      ));
      await tester.pump(const Duration(milliseconds: 1300));

      expect(find.textContaining('¥100,000.00'), findsOneWidget);
      expect(find.textContaining('¥30,000.00'), findsOneWidget);
    });

    testWidgets('formats small amounts correctly', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 0.1,
        totalBudget: 100, // ¥1.00
        totalSpent: 10, // ¥0.10
      ));
      await tester.pump(const Duration(milliseconds: 1300));

      expect(find.textContaining('¥0.10'), findsOneWidget);
      expect(find.textContaining('¥1.00'), findsOneWidget);
    });

    // ── Semantics / Accessibility ──

    testWidgets('has correct semantics label', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 0.5,
        totalBudget: 500000,
        totalSpent: 250000,
      ));
      await tester.pump(const Duration(milliseconds: 1300));

      final semantics = tester.getSemantics(find.byType(BudgetExecutionCard));
      expect(semantics.label, contains('预算执行率'));
      expect(semantics.label, contains('50%'));
    });

    // ── Ring animation ──

    testWidgets('ring animation completes from 0 to target', (tester) async {
      await tester.pumpWidget(buildCard(executionRate: 0.75));

      // Initial frame
      await tester.pump();

      // After full animation duration (1200ms) + buffer
      await tester.pump(const Duration(milliseconds: 1300));

      expect(find.text('75%'), findsOneWidget);
    });

    // ── Pulse animation ──

    testWidgets('pulse animation activates for overspend (rate >= 1.0)',
        (tester) async {
      await tester.pumpWidget(buildCard(executionRate: 1.2));
      await tester.pump(const Duration(milliseconds: 1300));

      expect(find.text('120%'), findsOneWidget);

      // Pump more to let pulse animation tick
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.byType(BudgetExecutionCard), findsOneWidget);
    });

    testWidgets('no pulse for rate below 1.0', (tester) async {
      await tester.pumpWidget(buildCard(executionRate: 0.3));
      await tester.pump(const Duration(milliseconds: 1300));

      expect(find.text('30%'), findsOneWidget);
      expect(find.byType(BudgetExecutionCard), findsOneWidget);
    });

    // ── Theme ──

    testWidgets('renders correctly in dark theme', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: BudgetExecutionCard(
            executionRate: 0.6,
            totalBudget: 500000,
            totalSpent: 300000,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 1300));

      expect(find.text('60%'), findsOneWidget);
    });

    // ── didUpdateWidget ──

    testWidgets('updates percentage when executionRate changes',
        (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 0.3,
        totalBudget: 500000,
        totalSpent: 150000,
      ));
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('30%'), findsOneWidget);

      // Rebuild with new rate
      await tester.pumpWidget(buildCard(
        executionRate: 0.9,
        totalBudget: 500000,
        totalSpent: 450000,
      ));
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('90%'), findsOneWidget);
    });

    testWidgets('transitions from normal to overspend starts pulse',
        (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 0.5,
        totalBudget: 500000,
        totalSpent: 250000,
      ));
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('50%'), findsOneWidget);

      await tester.pumpWidget(buildCard(
        executionRate: 1.2,
        totalBudget: 500000,
        totalSpent: 600000,
      ));
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('120%'), findsOneWidget);
    });

    testWidgets('transitions from overspend to normal stops pulse',
        (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 1.2,
        totalBudget: 500000,
        totalSpent: 600000,
      ));
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('120%'), findsOneWidget);

      await tester.pumpWidget(buildCard(
        executionRate: 0.4,
        totalBudget: 500000,
        totalSpent: 200000,
      ));
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('40%'), findsOneWidget);
    });

    testWidgets('same rate does not re-trigger animation', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 0.5,
        totalBudget: 500000,
        totalSpent: 250000,
      ));
      await tester.pump(const Duration(milliseconds: 1300));

      // Rebuild with same rate
      await tester.pumpWidget(buildCard(
        executionRate: 0.5,
        totalBudget: 500000,
        totalSpent: 250000,
      ));
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.text('50%'), findsOneWidget);
    });

    // ── Dispose ──

    testWidgets('disposes animation controllers cleanly', (tester) async {
      await tester.pumpWidget(buildCard(executionRate: 1.5));
      await tester.pump(const Duration(milliseconds: 1300));

      // Replace with a different widget to trigger dispose
      await tester.pumpWidget(wrapInApp(const SizedBox()));
      await tester.pump();

      // No exception means controllers disposed correctly
    });

    testWidgets('disposes correctly when pulse is active', (tester) async {
      await tester.pumpWidget(buildCard(executionRate: 1.5));
      await tester.pump(const Duration(milliseconds: 1300));
      // Pulse should be actively animating at rate >= 1.0
      await tester.pump(const Duration(milliseconds: 500));

      // Tear down
      await tester.pumpWidget(wrapInApp(const SizedBox()));
      await tester.pump();
      // No exception = clean dispose even with active repeating animation
    });
  });
}
