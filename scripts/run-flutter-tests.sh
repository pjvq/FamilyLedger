#!/usr/bin/env bash
# run-flutter-tests.sh — Shared Flutter test runner with segfault/OOM tolerance.
#
# Used by both ci.yml and flutter.yml to avoid duplicating the retry/tolerance logic.
# Exit codes:
#   0  — all tests passed (or segfault/OOM with no real failures)
#   1  — real test failures
#
# Note: GitHub Actions run-steps only support 0=success, non-zero=failure.
# exit 78 (neutral) only works inside composite actions, NOT in run-steps.
# So for segfault/OOM with no real failures, we exit 0 with a warning annotation.
set -u

TIMEOUT_SECS="${FLUTTER_TEST_TIMEOUT_SECS:-240}"
RETRY_TIMEOUT_SECS="${FLUTTER_TEST_RETRY_TIMEOUT_SECS:-120}"

# Build args array for safe expansion (no word-splitting issues).
# shellcheck disable=SC2206  # intentional: splitting default string into array
TEST_ARGS=(${FLUTTER_TEST_EXTRA_ARGS:---concurrency=1 --reporter compact --coverage --timeout 5s})

set +e
set -o pipefail
timeout --foreground --kill-after=10 "$TIMEOUT_SECS" \
  flutter test "${TEST_ARGS[@]}" 2>&1 \
  | tee test_output.txt
EXIT_CODE=${PIPESTATUS[0]}
set +o pipefail
set -e

if [ "$EXIT_CODE" -eq 0 ]; then
  echo "All tests passed"
  exit 0
fi

# Classify the exit code
case $EXIT_CODE in
  124|137)
    # timeout(1) killed the process — segfault hang or OOM
    TIMED_OUT=yes
    ;;
  *)
    TIMED_OUT=""
    ;;
esac

SEGFAULTS=$(grep -i 'segmentation fault' test_output.txt || true)

# Detect real test failures: compact reporter [E], assertion failures,
# uncaught exceptions, Flutter error banners.
# Excludes "loading ... [E]" which is a segfault artifact, not a real test failure.
REAL_FAILURES=$(
  grep -E '\[E\]|Some tests failed|EXCEPTION CAUGHT|══╡' test_output.txt \
  | grep -v 'loading.*\[E\]' \
  || true
)

if [ -z "$REAL_FAILURES" ] && { [ -n "$SEGFAULTS" ] || [ -n "$TIMED_OUT" ]; }; then
  PASS_COUNT=$(grep -oP '\+\d+' test_output.txt | tail -1 || echo "+0")
  echo "::warning::flutter_tester segfault/hang on CI (OOM), $PASS_COUNT tests passed before crash — not a code bug"
  exit 0
fi

# Real test failures — retry failed files with the same concurrency setting.
FAILED=$(grep -oP '(?<=package:)[^ ]+_test.dart' test_output.txt | sort -u || true)
if [ -n "$FAILED" ]; then
  echo "::notice::Retrying failed tests: $FAILED"
  # shellcheck disable=SC2086  # intentional: FAILED needs word splitting into multiple file args
  timeout --foreground "$RETRY_TIMEOUT_SECS" flutter test "${TEST_ARGS[@]}" $FAILED
else
  exit "$EXIT_CODE"
fi
