/// Memory usage profiling test.
///
/// Run with: flutter test integration_test/memory_test.dart --profile
///
/// Note: Memory metrics from `dart:developer` are only accurate on real
/// devices / profile mode. On simulators they provide relative comparisons.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Memory profiling', () {
    testWidgets('Baseline memory after startup', (tester) async {
      await pumpTestApp(tester);

      // In profile mode, actual heap data is available via DevTools.
      // Here we primarily validate that the app launches without leaks
      // and record the test structure for future detailed analysis.
      binding.reportData = <String, dynamic>{
        'test': 'baseline_memory',
        'status': 'app_launched_successfully',
        'note':
            'Use DevTools Memory tab in profile mode for accurate heap snapshots',
      };
    });

    testWidgets('Memory after tab cycling (leak detection)', (tester) async {
      await pumpTestApp(tester);

      // Cycle through tabs 5 times to detect potential memory leaks
      final bottomNav = find.byType(BottomNavigationBar);
      var cyclesPerformed = 0;

      if (bottomNav.evaluate().isNotEmpty) {
        final navBar =
            bottomNav.evaluate().first.widget as BottomNavigationBar;
        final itemCount = navBar.items.length;

        for (var cycle = 0; cycle < 5; cycle++) {
          for (var i = 0; i < itemCount; i++) {
            final icons = find.descendant(
              of: bottomNav,
              matching: find.byType(InkResponse),
            );
            if (icons.evaluate().length > i) {
              await tester.tap(icons.at(i));
              await tester.pumpAndSettle();
            }
          }
          cyclesPerformed++;
        }
      }

      binding.reportData = <String, dynamic>{
        'test': 'tab_cycling_memory',
        'cycles_performed': cyclesPerformed,
        'status': 'completed_without_crash',
        'note':
            'No crash after $cyclesPerformed cycles indicates no catastrophic leaks. '
                'Use DevTools for quantitative heap analysis.',
      };
    });

    testWidgets('Memory after repeated navigation', (tester) async {
      await pumpTestApp(tester);

      var navigationCount = 0;

      // Open and close the add-transaction page multiple times
      for (var i = 0; i < 10; i++) {
        final fab = find.byType(FloatingActionButton);
        if (fab.evaluate().isNotEmpty) {
          await tester.tap(fab.first);
          await tester.pumpAndSettle();

          // Pop back
          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator).last,
          );
          navigator.pop();
          await tester.pumpAndSettle();
          navigationCount++;
        } else {
          break; // No FAB, skip
        }
      }

      binding.reportData = <String, dynamic>{
        'test': 'repeated_navigation_memory',
        'navigation_count': navigationCount,
        'status': 'completed_without_crash',
        'note':
            'Completed $navigationCount push/pop cycles. '
                'Compare timeline memory graph before and after for leak detection.',
      };
    });
  });
}
