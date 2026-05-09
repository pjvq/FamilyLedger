import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/core/utils/category_uuid.dart';
import 'package:familyledger/core/widgets/virtual_list.dart';
import 'package:familyledger/data/local/database.dart';

// ─── Helpers ───────────────────────────────────────────────────────────

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

/// Create a test Transaction with minimal required fields.
Transaction _makeTransaction({
  required int index,
  String userId = 'u1',
  String accountId = 'acc1',
}) {
  final now = DateTime.now();
  // Spread across last 12 months
  final txnDate = now.subtract(Duration(days: index % 365));
  // Cycle through category types
  final categories = [
    ('expense', '餐饮'),
    ('expense', '交通'),
    ('expense', '购物'),
    ('expense', '居住'),
    ('expense', '娱乐'),
    ('expense', '医疗'),
    ('expense', '教育'),
    ('income', '工资'),
    ('income', '奖金'),
    ('income', '投资收益'),
  ];
  final cat = categories[index % categories.length];
  final type = cat.$1;
  final catName = cat.$2;
  final categoryId = CategoryUUID.generate('test-user', type, catName);
  // Random-ish amount based on index
  final amount = 100 + (index * 37 % 99900); // 100-100000 range

  return Transaction(
    id: 'txn_perf_$index',
    userId: userId,
    accountId: accountId,
    categoryId: categoryId,
    amount: amount,
    currency: 'CNY',
    amountCny: amount,
    exchangeRate: 1.0,
    type: type,
    note: 'perf_test_$index',
    tags: '',
    imageUrls: '',
    txnDate: txnDate,
    createdAt: now,
    updatedAt: now,
    synced: false,
    syncStatus: 'pending',
  );
}

// ─── Performance Tests ─────────────────────────────────────────────────

void main() {
  group('VirtualList — 1000+ items performance', () {
    late List<Transaction> transactions;
    late ScrollController controller;

    setUp(() {
      transactions = List.generate(1100, (i) => _makeTransaction(index: i));
      controller = ScrollController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('builds 1000+ items without error', (tester) async {
      await tester.pumpWidget(_wrap(
        VirtualList<Transaction>(
          items: transactions,
          itemBuilder: (ctx, txn, index) => SizedBox(
            height: 72,
            child: ListTile(
              leading: Text(txn.type == 'expense' ? '📉' : '📈'),
              title: Text(txn.note),
              subtitle: Text('¥${(txn.amountCny / 100).toStringAsFixed(2)}'),
              trailing: Text('${txn.txnDate.month}/${txn.txnDate.day}'),
            ),
          ),
          itemExtent: 72,
          controller: controller,
        ),
      ));
      await tester.pumpAndSettle();

      // VirtualList should build successfully
      expect(find.byType(ListView), findsOneWidget);
      // Only visible items are rendered, not all 1100
      expect(find.text('perf_test_0'), findsOneWidget);
    });

    testWidgets('scrolls to bottom successfully', (tester) async {
      await tester.pumpWidget(_wrap(
        VirtualList<Transaction>(
          items: transactions,
          itemBuilder: (ctx, txn, index) => SizedBox(
            height: 72,
            child: ListTile(
              key: ValueKey('txn_item_$index'),
              title: Text(txn.note),
              subtitle: Text('¥${(txn.amountCny / 100).toStringAsFixed(2)}'),
            ),
          ),
          itemExtent: 72,
          controller: controller,
        ),
      ));
      await tester.pumpAndSettle();

      // Jump to the very bottom
      final maxScroll = controller.position.maxScrollExtent;
      controller.jumpTo(maxScroll);
      await tester.pumpAndSettle();

      // The last item should now be visible
      final lastNote = transactions.last.note;
      expect(find.text(lastNote), findsOneWidget);
    });

    testWidgets('only visible items are built (virtualization works)',
        (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(_wrap(
        VirtualList<Transaction>(
          items: transactions,
          itemBuilder: (ctx, txn, index) {
            buildCount++;
            return SizedBox(
              height: 72,
              child: Text(txn.note),
            );
          },
          itemExtent: 72,
          controller: controller,
        ),
      ));
      await tester.pumpAndSettle();

      // With itemExtent=72 and typical screen ~800px,
      // only ~11-15 items should be built (not 1100).
      // Allow generous margin for caching.
      expect(buildCount, lessThan(50),
          reason: 'VirtualList should only build visible items, '
              'got $buildCount builds for ${transactions.length} items');
    });

    testWidgets('measures build time for 1000+ items', (tester) async {
      final sw = Stopwatch()..start();

      await tester.pumpWidget(_wrap(
        VirtualList<Transaction>(
          items: transactions,
          itemBuilder: (ctx, txn, index) => SizedBox(
            height: 72,
            child: ListTile(
              title: Text(txn.note),
              subtitle: Text('¥${(txn.amountCny / 100).toStringAsFixed(2)}'),
            ),
          ),
          itemExtent: 72,
          controller: controller,
        ),
      ));
      await tester.pumpAndSettle();

      sw.stop();
      final buildTimeMs = sw.elapsedMilliseconds;

      // Should be very fast since only visible items are built
      // In test environment, allow generous timeout
      expect(buildTimeMs, lessThan(5000),
          reason: 'VirtualList build took ${buildTimeMs}ms, expected < 5000ms');

      // ignore: avoid_print
      print('VirtualList build time (1100 items): ${buildTimeMs}ms');
    });

    testWidgets('scroll to middle then to bottom', (tester) async {
      await tester.pumpWidget(_wrap(
        VirtualList<Transaction>(
          items: transactions,
          itemBuilder: (ctx, txn, index) => SizedBox(
            height: 72,
            child: Text(txn.note, key: ValueKey('note_$index')),
          ),
          itemExtent: 72,
          controller: controller,
        ),
      ));
      await tester.pumpAndSettle();

      // Scroll to middle (~item 550)
      controller.jumpTo(550 * 72.0);
      await tester.pumpAndSettle();
      expect(find.text('perf_test_550'), findsOneWidget);

      // Scroll to bottom
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text(transactions.last.note), findsOneWidget);

      // Scroll back to top
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('perf_test_0'), findsOneWidget);
    });

    testWidgets('handles rapid scrolling without crash', (tester) async {
      await tester.pumpWidget(_wrap(
        VirtualList<Transaction>(
          items: transactions,
          itemBuilder: (ctx, txn, index) => SizedBox(
            height: 72,
            child: Text(txn.note),
          ),
          itemExtent: 72,
          controller: controller,
        ),
      ));
      await tester.pumpAndSettle();

      // Rapid scroll through multiple positions
      for (var pos = 0.0;
          pos < controller.position.maxScrollExtent;
          pos += 5000) {
        controller.jumpTo(pos);
        await tester.pump();
      }
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      // Should still be intact
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text(transactions.last.note), findsOneWidget);
    });
  });
}
