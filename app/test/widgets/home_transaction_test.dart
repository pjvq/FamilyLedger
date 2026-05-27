import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familyledger/core/theme/design_tokens.dart';
import 'package:familyledger/core/widgets/micro_interactions.dart';
import 'package:familyledger/core/utils/category_uuid.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/features/transaction/widgets/category_grid.dart';
import 'package:familyledger/features/transaction/widgets/number_pad.dart';

// ─── Helpers ───────────────────────────────────────────────────────────

/// Wrap a widget in MaterialApp for testing.
Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

/// Wrap a widget in MaterialApp + ProviderScope.
Widget _wrapWithProviders(
  Widget child, {
  ThemeData? theme,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: theme ?? ThemeData.light(useMaterial3: true),
      home: Scaffold(body: child),
    ),
  );
}

/// Create a test Transaction with required drift fields.
Transaction _makeTransaction({
  String id = 'txn_1',
  String userId = 'u1',
  String accountId = 'acc1',
  String? categoryId,
  int amount = 2500,
  String currency = 'CNY',
  int amountCny = 2500,
  double exchangeRate = 1.0,
  String type = 'expense',
  String note = '',
  String tags = '',
  String imageUrls = '',
  DateTime? txnDate,
  DateTime? createdAt,
  DateTime? updatedAt,
  String syncStatus = 'pending',
}) {
  final now = DateTime.now();
  final effectiveCategoryId = categoryId ?? CategoryUUID.generate('test-user', 'expense', '餐饮');
  return Transaction(
    id: id,
    userId: userId,
    accountId: accountId,
    categoryId: effectiveCategoryId,
    amount: amount,
    currency: currency,
    amountCny: amountCny,
    exchangeRate: exchangeRate,
    type: type,
    note: note,
    tags: tags,
    imageUrls: imageUrls,
    txnDate: txnDate ?? now,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    syncStatus: syncStatus,
  );
}

/// Create a test Category.
Category _makeCategory({
  String? id,
  String name = '餐饮',
  String type = 'expense',
  bool isPreset = true,
  int sortOrder = 1,
}) {
  return Category(
    id: id ?? CategoryUUID.generate('test-user', type, name),
    name: name,
    type: type,
    isPreset: isPreset,
    sortOrder: sortOrder,
    iconKey: '',
  );
}

void main() {
  // ─── CategoryGrid Tests ───────────────────────────────────────────────

  group('CategoryGrid', () {
    final categories = [
      _makeCategory(id: CategoryUUID.generate('test-user', 'expense', '餐饮'), name: '餐饮'),
      _makeCategory(id: CategoryUUID.generate('test-user', 'expense', '交通'), name: '交通'),
      _makeCategory(id: CategoryUUID.generate('test-user', 'expense', '购物'), name: '购物'),
      _makeCategory(id: CategoryUUID.generate('test-user', 'expense', '居住'), name: '居住'),
      _makeCategory(id: CategoryUUID.generate('test-user', 'expense', '娱乐'), name: '娱乐'),
      _makeCategory(id: CategoryUUID.generate('test-user', 'expense', '医疗'), name: '医疗'),
    ];

    testWidgets('renders all categories', (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          height: 400,
          child: CategoryGrid(
            categories: categories,
            selectedId: null,
            onSelect: (_) {},
          ),
        ),
      ));

      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('交通'), findsOneWidget);
      expect(find.text('购物'), findsOneWidget);
      expect(find.text('居住'), findsOneWidget);
      expect(find.text('娱乐'), findsOneWidget);
      expect(find.text('医疗'), findsOneWidget);

      // Icons — CategoryGrid now renders Material Icons via icon_key, not emoji text
      // Just verify the category names are visible
      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('交通'), findsOneWidget);
    });

    testWidgets('highlights selected category', (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          height: 400,
          child: CategoryGrid(
            categories: categories,
            selectedId: CategoryUUID.generate('test-user', 'expense', '餐饮'),
            onSelect: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // The selected item should have border decoration
      // We can check that the '餐饮' text uses FontWeight.w600
      final textWidget = tester.widget<Text>(find.text('餐饮'));
      expect(textWidget.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('calls onSelect callback with category id', (tester) async {
      String? selectedId;
      await tester.pumpWidget(_wrap(
        SizedBox(
          height: 400,
          child: CategoryGrid(
            categories: categories,
            selectedId: null,
            onSelect: (id) => selectedId = id,
          ),
        ),
      ));

      await tester.tap(find.text('交通'));
      expect(selectedId, CategoryUUID.generate('test-user', 'expense', '交通'));
    });

    testWidgets('renders empty grid for no categories', (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          height: 400,
          child: CategoryGrid(
            categories: const [],
            selectedId: null,
            onSelect: (_) {},
          ),
        ),
      ));

      // GridView exists but has no items
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('uses grid with 5 columns', (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          height: 400,
          child: CategoryGrid(
            categories: categories,
            selectedId: null,
            onSelect: (_) {},
          ),
        ),
      ));

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 5);
    });

    testWidgets('non-selected items have normal font weight', (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          height: 400,
          child: CategoryGrid(
            categories: categories,
            selectedId: CategoryUUID.generate('test-user', 'expense', '餐饮'),
            onSelect: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('交通'));
      expect(textWidget.style?.fontWeight, FontWeight.normal);
    });
  });

  // ─── NumberPad Tests ──────────────────────────────────────────────────

  group('NumberPad', () {
    testWidgets('renders all digit buttons 0-9, dot, delete, confirm',
        (tester) async {
      await tester.pumpWidget(_wrap(
        NumberPad(
          onKey: (_) {},
          onDelete: () {},
          onConfirm: () {},
        ),
      ));

      for (var i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
      expect(find.text('.'), findsOneWidget);
      // Delete button has backspace icon
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
      // Confirm button has check icon
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('digit tap calls onKey with correct value', (tester) async {
      final keys = <String>[];
      await tester.pumpWidget(_wrap(
        NumberPad(
          onKey: (k) => keys.add(k),
          onDelete: () {},
          onConfirm: () {},
        ),
      ));

      await tester.tap(find.text('1'));
      await tester.tap(find.text('2'));
      await tester.tap(find.text('3'));
      expect(keys, ['1', '2', '3']);
    });

    testWidgets('dot tap calls onKey with "."', (tester) async {
      String? lastKey;
      await tester.pumpWidget(_wrap(
        NumberPad(
          onKey: (k) => lastKey = k,
          onDelete: () {},
          onConfirm: () {},
        ),
      ));

      await tester.tap(find.text('.'));
      expect(lastKey, '.');
    });

    testWidgets('delete button calls onDelete', (tester) async {
      bool deleted = false;
      await tester.pumpWidget(_wrap(
        NumberPad(
          onKey: (_) {},
          onDelete: () => deleted = true,
          onConfirm: () {},
        ),
      ));

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      expect(deleted, true);
    });

    testWidgets('confirm button calls onConfirm when enabled', (tester) async {
      bool confirmed = false;
      await tester.pumpWidget(_wrap(
        NumberPad(
          onKey: (_) {},
          onDelete: () {},
          onConfirm: () => confirmed = true,
          confirmEnabled: true,
        ),
      ));

      await tester.tap(find.byIcon(Icons.check_rounded));
      expect(confirmed, true);
    });

    testWidgets('confirm button disabled when confirmEnabled=false',
        (tester) async {
      bool confirmed = false;
      await tester.pumpWidget(_wrap(
        NumberPad(
          onKey: (_) {},
          onDelete: () {},
          onConfirm: () => confirmed = true,
          confirmEnabled: false,
        ),
      ));

      await tester.tap(find.byIcon(Icons.check_rounded));
      expect(confirmed, false);
    });

    testWidgets('zero button works', (tester) async {
      String? key;
      await tester.pumpWidget(_wrap(
        NumberPad(
          onKey: (k) => key = k,
          onDelete: () {},
          onConfirm: () {},
        ),
      ));

      await tester.tap(find.text('0'));
      expect(key, '0');
    });

    testWidgets('renders in dark theme', (tester) async {
      await tester.pumpWidget(_wrap(
        NumberPad(
          onKey: (_) {},
          onDelete: () {},
          onConfirm: () {},
        ),
        theme: ThemeData.dark(useMaterial3: true),
      ));

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('all number keys are pressable', (tester) async {
      final pressedKeys = <String>[];
      await tester.pumpWidget(_wrap(
        NumberPad(
          onKey: (k) => pressedKeys.add(k),
          onDelete: () {},
          onConfirm: () {},
        ),
      ));

      for (var i = 0; i <= 9; i++) {
        await tester.tap(find.text('$i'));
      }
      await tester.tap(find.text('.'));
      expect(pressedKeys, ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.']);
    });
  });

  // ─── AnimatedNumber Tests ─────────────────────────────────────────────

  group('AnimatedNumber', () {
    testWidgets('renders correct value after animation', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedNumber(
          value: 123456, // ¥1234.56
          prefix: '¥ ',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('1234.56'), findsOneWidget);
    });

    testWidgets('shows 万 format for large amounts', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedNumber(
          value: 10000000, // ¥100000.00 = 10.00万
          prefix: '¥ ',
          asWan: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('10.00万'), findsOneWidget);
    });

    testWidgets('does not show 万 when asWan=false', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedNumber(
          value: 10000000,
          prefix: '¥ ',
          asWan: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('100000.00'), findsOneWidget);
      expect(find.textContaining('万'), findsNothing);
    });

    testWidgets('zero value renders 0.00', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedNumber(
          value: 0,
          prefix: '¥ ',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('0.00'), findsOneWidget);
    });

    testWidgets('negative value renders correctly', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedNumber(
          value: -50000, // -¥500.00
          prefix: '¥ ',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('-500.00'), findsOneWidget);
    });

    testWidgets('applies suffix', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedNumber(
          value: 5000,
          suffix: ' 元',
          asWan: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('50.00 元'), findsOneWidget);
    });
  });
}
