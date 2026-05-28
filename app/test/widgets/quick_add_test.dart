import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familyledger/features/transaction/widgets/quick_amount_display.dart';
import 'package:familyledger/features/transaction/widgets/quick_number_pad.dart';
import 'package:familyledger/features/transaction/widgets/quick_add_components.dart';

void main() {
  Widget wrapInApp(Widget child) {
    return ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('QuickAmountDisplay', () {
    testWidgets('shows zero by default', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const QuickAmountDisplay(expression: '0'),
      ));
      expect(find.text('0'), findsOneWidget);
      expect(find.text('¥'), findsOneWidget);
    });

    testWidgets('shows expression with operator and computed result', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const QuickAmountDisplay(expression: '100+50'),
      ));
      expect(find.text('100+50'), findsOneWidget);
      expect(find.text('= ¥150'), findsOneWidget);
    });

    testWidgets('shows note when provided', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const QuickAmountDisplay(expression: '88', note: '午餐'),
      ));
      expect(find.text('午餐'), findsOneWidget);
    });

    testWidgets('shows placeholder when no note', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const QuickAmountDisplay(expression: '0'),
      ));
      expect(find.text('添加备注...'), findsOneWidget);
    });
  });

  group('QuickNumberPad', () {
    testWidgets('renders all digit keys', (tester) async {
      await tester.pumpWidget(wrapInApp(
        QuickNumberPad(
          onDigit: (_) {},
          onDelete: () {},
          onClear: () {},
          onConfirm: () {},
          onDateTap: () {},
          onOperator: (_) {},
        ),
      ));
      for (var i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
      expect(find.text('.'), findsOneWidget);
      expect(find.text('+'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
    });

    testWidgets('calls onDigit when digit tapped', (tester) async {
      String? tapped;
      await tester.pumpWidget(wrapInApp(
        QuickNumberPad(
          onDigit: (d) => tapped = d,
          onDelete: () {},
          onClear: () {},
          onConfirm: () {},
          onDateTap: () {},
          onOperator: (_) {},
        ),
      ));
      await tester.tap(find.text('5'));
      expect(tapped, '5');
    });

    testWidgets('calls onOperator when + tapped', (tester) async {
      String? op;
      await tester.pumpWidget(wrapInApp(
        QuickNumberPad(
          onDigit: (_) {},
          onDelete: () {},
          onClear: () {},
          onConfirm: () {},
          onDateTap: () {},
          onOperator: (o) => op = o,
        ),
      ));
      await tester.tap(find.text('+'));
      expect(op, '+');
    });

    testWidgets('confirm button disabled when confirmEnabled=false', (tester) async {
      bool called = false;
      await tester.pumpWidget(wrapInApp(
        QuickNumberPad(
          onDigit: (_) {},
          onDelete: () {},
          onClear: () {},
          onConfirm: () => called = true,
          onDateTap: () {},
          onOperator: (_) {},
          confirmEnabled: false,
        ),
      ));
      await tester.tap(find.text('完成'));
      expect(called, false);
    });
  });

  group('TransactionTypeSelector', () {
    testWidgets('renders two types', (tester) async {
      await tester.pumpWidget(wrapInApp(
        TransactionTypeSelector(
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('支出'), findsOneWidget);
      expect(find.text('收入'), findsOneWidget);
    });

    testWidgets('calls onChanged when tapped', (tester) async {
      int? selected;
      await tester.pumpWidget(wrapInApp(
        TransactionTypeSelector(
          selectedIndex: 0,
          onChanged: (i) => selected = i,
        ),
      ));
      await tester.tap(find.text('收入'));
      expect(selected, 1);
    });
  });

  group('AccountPill', () {
    testWidgets('shows account name', (tester) async {
      await tester.pumpWidget(wrapInApp(
        AccountPill(
          accountName: '招商银行',
          onTap: () {},
        ),
      ));
      expect(find.text('招商银行'), findsOneWidget);
    });
  });
}
