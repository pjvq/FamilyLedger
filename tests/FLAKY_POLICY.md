# Flaky Test Treatment Strategy
#
# Timeout standards:
#   - Unit tests: 5s per test
#   - Integration tests: 15s per test
#   - E2E/联调 tests: 30s per test
#
# Retry policy:
#   - CI retries each failed test up to 2 times before failing the build
#   - Tests that fail >10% of runs in a week are tagged @flaky
#
# @flaky tag workflow:
#   1. Tag test with @flaky annotation + issue link
#   2. Flaky tests run in a separate CI job (non-blocking)
#   3. Developer has 1 sprint to fix or the test is removed
#   4. Once stable for 50 consecutive runs, remove @flaky
#
# CI config:
#   Go: -count=1 -timeout=60s (total suite)
#   Dart: --timeout 5s (per test, overridable per file)
#   E2E: --timeout 30s --concurrency 1

# Usage in Dart tests:
#   @Tags(['flaky'])
#   void main() { ... }
#
# Usage in Go tests:
#   //go:build flaky
#   package flaky_test
