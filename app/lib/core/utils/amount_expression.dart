/// Expression parser for amount input — shared between display and submission.
///
/// Operates in **cents** (integer) to avoid floating-point precision issues.
/// Supports only `+` and `-` operators.
class AmountExpression {
  AmountExpression._();

  /// Parse an expression string and return the result in cents.
  ///
  /// Examples:
  /// - '100' → 10000
  /// - '100+50' → 15000
  /// - '33.33-0.01' → 3332
  /// - '0' → 0
  /// - '' → 0
  /// - '100+' → 10000 (trailing operator ignored)
  static int evaluateCents(String expression) {
    if (expression.isEmpty) return 0;

    int result = 0;
    String current = '';
    String op = '+';

    for (int i = 0; i <= expression.length; i++) {
      final char = i < expression.length ? expression[i] : '\0';
      if (char == '+' || char == '-' || i == expression.length) {
        if (current.isNotEmpty) {
          final cents = _parseCents(current);
          result = op == '+' ? result + cents : result - cents;
        }
        if (i < expression.length) op = char;
        current = '';
      } else {
        current += char;
      }
    }
    return result;
  }

  /// Parse a single number string to cents without floating-point math.
  ///
  /// '33.33' → 3333, '100' → 10000, '0.5' → 50
  static int _parseCents(String s) {
    if (s.isEmpty) return 0;
    final parts = s.split('.');
    final intPart = int.tryParse(parts[0]) ?? 0;
    int fracPart = 0;
    if (parts.length > 1) {
      final frac = parts[1].padRight(2, '0').substring(0, 2);
      fracPart = int.tryParse(frac) ?? 0;
    }
    return intPart * 100 + fracPart;
  }

  /// Evaluate and return as double (for display purposes only).
  static double evaluateDouble(String expression) {
    return evaluateCents(expression) / 100.0;
  }

  /// Whether the expression contains an operator.
  static bool hasOperator(String expression) {
    // Skip first char to allow negative numbers in future
    for (int i = 1; i < expression.length; i++) {
      if (expression[i] == '+' || expression[i] == '-') return true;
    }
    return false;
  }

  /// Format cents to display string (e.g. 3333 → '33.33', 10000 → '100').
  static String formatCents(int cents) {
    if (cents % 100 == 0) {
      return (cents ~/ 100).toString();
    }
    final intPart = cents ~/ 100;
    final fracPart = cents % 100;
    return '$intPart.${fracPart.toString().padLeft(2, '0')}';
  }
}
