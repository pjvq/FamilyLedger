/// App-level performance benchmarks using Flutter integration_test.
///
/// Run with: flutter test integration_test/app_performance_test.dart --profile
/// Requires a connected device or simulator.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Performance benchmarks', () {
    testWidgets('App startup time', (tester) async {
      await binding.traceAction(() async {
        await pumpTestApp(tester);
      }, reportKey: 'app_startup');
    });

    testWidgets('Transaction list scroll performance', (tester) async {
      await pumpTestApp(tester);

      await binding.traceAction(() async {
        // Try to find a scrollable list (ListView or CustomScrollView)
        final listFinder = find.byType(ListView);
        final scrollFinder = find.byType(CustomScrollView);

        Finder? scrollable;
        if (listFinder.evaluate().isNotEmpty) {
          scrollable = listFinder.first;
        } else if (scrollFinder.evaluate().isNotEmpty) {
          scrollable = scrollFinder.first;
        }

        if (scrollable != null) {
          // Perform multiple flings to stress the rendering pipeline
          for (var i = 0; i < 3; i++) {
            await tester.fling(scrollable, const Offset(0, -500), 1500);
            await tester.pumpAndSettle();
          }
          // Scroll back up
          for (var i = 0; i < 3; i++) {
            await tester.fling(scrollable, const Offset(0, 500), 1500);
            await tester.pumpAndSettle();
          }
        }
      }, reportKey: 'transaction_list_scroll');
    });

    testWidgets('Dashboard render performance', (tester) async {
      await pumpTestApp(tester);

      await binding.traceAction(() async {
        // The app starts on HomePage with IndexedStack.
        // Tab 0 should be the dashboard. Just measure the initial render.
        await tester.pumpAndSettle();
      }, reportKey: 'dashboard_render');
    });

    testWidgets('Tab switch performance', (tester) async {
      await pumpTestApp(tester);

      await binding.traceAction(() async {
        // Find bottom navigation bar items and cycle through them
        final bottomNav = find.byType(BottomNavigationBar);
        if (bottomNav.evaluate().isNotEmpty) {
          final navBar =
              bottomNav.evaluate().first.widget as BottomNavigationBar;
          final itemCount = navBar.items.length;

          for (var i = 0; i < itemCount; i++) {
            // Tap each tab icon
            final icons = find.descendant(
              of: bottomNav,
              matching: find.byType(InkResponse),
            );
            if (icons.evaluate().length > i) {
              await tester.tap(icons.at(i));
              await tester.pumpAndSettle();
            }
          }
        }
      }, reportKey: 'tab_switch');
    });

    testWidgets('Add transaction page open/close', (tester) async {
      await pumpTestApp(tester);

      await binding.traceAction(() async {
        // Look for a FAB or add button
        final fab = find.byType(FloatingActionButton);
        if (fab.evaluate().isNotEmpty) {
          await tester.tap(fab.first);
          await tester.pumpAndSettle();

          // Go back
          final backButton = find.byType(BackButton);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton.first);
          } else {
            // Try system back via Navigator
            final navigator = tester.state<NavigatorState>(
              find.byType(Navigator).last,
            );
            navigator.pop();
          }
          await tester.pumpAndSettle();
        }
      }, reportKey: 'add_transaction_open_close');
    });
  });
}
