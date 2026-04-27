#!/bin/bash
# Flutter Performance Tests
# Requires a connected device or running simulator.
#
# Usage:
#   ./scripts/run_perf_tests.sh              # Run all perf tests
#   ./scripts/run_perf_tests.sh startup      # Run only app_performance_test
#   ./scripts/run_perf_tests.sh frames       # Run only frame_metrics_test
#   ./scripts/run_perf_tests.sh memory       # Run only memory_test

set -e

cd "$(dirname "$0")/.."

echo "🚀 Flutter Performance Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for connected devices
echo "📱 Available devices:"
flutter devices
echo ""

# Determine which tests to run
TEST_TARGET="integration_test/"
case "${1:-all}" in
  startup|perf)
    TEST_TARGET="integration_test/app_performance_test.dart"
    ;;
  frames|frame)
    TEST_TARGET="integration_test/frame_metrics_test.dart"
    ;;
  memory|mem)
    TEST_TARGET="integration_test/memory_test.dart"
    ;;
  all)
    TEST_TARGET="integration_test/"
    ;;
  *)
    echo "Unknown target: $1"
    echo "Valid targets: all, startup, frames, memory"
    exit 1
    ;;
esac

echo "🎯 Running: $TEST_TARGET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Run in profile mode for accurate timings
flutter test "$TEST_TARGET" \
  --profile \
  --verbose \
  2>&1 | tee perf-results.log

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Results saved to app/perf-results.log"
echo ""
echo "💡 Tips:"
echo "  - Use 'flutter run --profile' + DevTools for detailed analysis"
echo "  - Timeline data is in build/*/timeline_summary.json"
echo "  - Frame metrics are most accurate on physical devices"
