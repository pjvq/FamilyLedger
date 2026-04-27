/// Frame metrics test — measures build/render times for key pages.
///
/// Run with: flutter test integration_test/frame_metrics_test.dart --profile
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Frame metrics', () {
    testWidgets('Home page frame timings', (tester) async {
      await pumpTestApp(tester);

      final timings = <FrameTiming>[];
      // Collect frame timings during interaction
      SchedulerBinding.instance.addTimingsCallback((list) {
        timings.addAll(list);
      });

      // Interact with the page to generate frames
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        for (var i = 0; i < 5; i++) {
          await tester.fling(scrollable.first, const Offset(0, -300), 800);
          await tester.pumpAndSettle();
        }
      } else {
        // If no scrollable, just pump frames
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }

      if (timings.isNotEmpty) {
        final buildTimes = timings
            .map((t) => t.buildDuration.inMicroseconds / 1000.0)
            .toList()
          ..sort();
        final rasterTimes = timings
            .map((t) => t.rasterDuration.inMicroseconds / 1000.0)
            .toList()
          ..sort();

        final avgBuild =
            buildTimes.reduce((a, b) => a + b) / buildTimes.length;
        final p90Build = buildTimes[(buildTimes.length * 0.9).floor()];
        final worstBuild = buildTimes.last;

        final avgRaster =
            rasterTimes.reduce((a, b) => a + b) / rasterTimes.length;
        final p90Raster = rasterTimes[(rasterTimes.length * 0.9).floor()];
        final worstRaster = rasterTimes.last;

        binding.reportData = <String, dynamic>{
          'frame_count': timings.length,
          'build_time_avg_ms': avgBuild,
          'build_time_p90_ms': p90Build,
          'build_time_worst_ms': worstBuild,
          'raster_time_avg_ms': avgRaster,
          'raster_time_p90_ms': p90Raster,
          'raster_time_worst_ms': worstRaster,
        };
      } else {
        binding.reportData = <String, dynamic>{
          'frame_count': 0,
          'note': 'No frame timings captured — may need real device',
        };
      }
    });

    testWidgets('Navigation transition frame timings', (tester) async {
      await pumpTestApp(tester);

      final timings = <FrameTiming>[];
      SchedulerBinding.instance.addTimingsCallback((list) {
        timings.addAll(list);
      });

      // Trigger navigation to settings and back
      final settingsIcon = find.byIcon(Icons.settings);
      final moreIcon = find.byIcon(Icons.more_horiz);

      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon.first);
        await tester.pumpAndSettle();
        // Navigate back
        final back = find.byType(BackButton);
        if (back.evaluate().isNotEmpty) {
          await tester.tap(back.first);
          await tester.pumpAndSettle();
        }
      } else if (moreIcon.evaluate().isNotEmpty) {
        await tester.tap(moreIcon.first);
        await tester.pumpAndSettle();
      }

      if (timings.isNotEmpty) {
        final totalFrames = timings.length;
        final jankFrames = timings
            .where((t) =>
                t.buildDuration.inMilliseconds +
                    t.rasterDuration.inMilliseconds >
                16)
            .length;

        binding.reportData = <String, dynamic>{
          'navigation_frame_count': totalFrames,
          'navigation_jank_frames': jankFrames,
          'navigation_jank_percentage':
              totalFrames > 0 ? (jankFrames / totalFrames * 100) : 0,
        };
      }
    });
  });
}
