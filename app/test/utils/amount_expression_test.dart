import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/core/utils/amount_expression.dart';

void main() {
  group('AmountExpression.evaluateCents', () {
    test('simple integer', () {
      expect(AmountExpression.evaluateCents('100'), 10000);
    });

    test('simple decimal', () {
      expect(AmountExpression.evaluateCents('33.33'), 3333);
    });

    test('addition', () {
      expect(AmountExpression.evaluateCents('100+50'), 15000);
    });

    test('subtraction', () {
      expect(AmountExpression.evaluateCents('100-30'), 7000);
    });

    test('mixed operators', () {
      expect(AmountExpression.evaluateCents('100+50-20'), 13000);
    });

    test('decimal addition avoids floating-point issues', () {
      // 10.1 + 10.2 should be exactly 2030 cents
      expect(AmountExpression.evaluateCents('10.1+10.2'), 2030);
    });

    test('0.1+0.2 precision', () {
      expect(AmountExpression.evaluateCents('0.1+0.2'), 30);
    });

    test('trailing operator ignored', () {
      expect(AmountExpression.evaluateCents('100+'), 10000);
    });

    test('empty string', () {
      expect(AmountExpression.evaluateCents(''), 0);
    });

    test('zero', () {
      expect(AmountExpression.evaluateCents('0'), 0);
    });

    test('single digit decimal', () {
      // '0.5' → 50 cents
      expect(AmountExpression.evaluateCents('0.5'), 50);
    });

    test('consecutive operators treated as empty segment', () {
      // '100+-50' → 100 + 0 - 50 = 50
      expect(AmountExpression.evaluateCents('100+-50'), 5000);
    });
  });

  group('AmountExpression.hasOperator', () {
    test('no operator', () {
      expect(AmountExpression.hasOperator('100'), false);
    });

    test('has plus', () {
      expect(AmountExpression.hasOperator('100+50'), true);
    });

    test('has minus', () {
      expect(AmountExpression.hasOperator('100-50'), true);
    });

    test('single char no crash', () {
      expect(AmountExpression.hasOperator('5'), false);
    });
  });

  group('AmountExpression.formatCents', () {
    test('whole number', () {
      expect(AmountExpression.formatCents(10000), '100');
    });

    test('with fractional', () {
      expect(AmountExpression.formatCents(3333), '33.33');
    });

    test('trailing zero preserved', () {
      expect(AmountExpression.formatCents(1050), '10.50');
    });

    test('zero', () {
      expect(AmountExpression.formatCents(0), '0');
    });
  });
}
