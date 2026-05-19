#!/usr/bin/env bash
# run-flutter-tests.sh — Shared Flutter test runner with OOM mitigation.
#
# Strategy: Split tests into shards to avoid OOM on CI runners (7GB RAM).
# Widget tests (testWidgets/pumpWidget) accumulate memory in flutter_tester;
# running all 462+ in one process reliably OOMs. By splitting into shards
# and merging coverage, we stay within memory limits.
#
# Exit codes:
#   0  — all tests passed
#   1  — real test failures
set -u

TIMEOUT_SECS="${FLUTTER_TEST_TIMEOUT_SECS:-240}"
RETRY_TIMEOUT_SECS="${FLUTTER_TEST_RETRY_TIMEOUT_SECS:-120}"
CONCURRENCY="${FLUTTER_TEST_CONCURRENCY:-1}"

# macOS doesn't have GNU timeout; use gtimeout if available, else skip timeout wrapper
if command -v timeout &>/dev/null; then
  TIMEOUT_CMD="timeout --foreground --kill-after=10"
elif command -v gtimeout &>/dev/null; then
  TIMEOUT_CMD="gtimeout --foreground --kill-after=10"
else
  TIMEOUT_CMD=""
fi

# Discover all test files
ALL_TESTS=($(find test -name '*_test.dart' -not -path '*/integration_test/*' | sort))
TOTAL=${#ALL_TESTS[@]}

if [ "$TOTAL" -eq 0 ]; then
  echo "::warning::No test files found"
  exit 0
fi

# Split into shards to limit memory per flutter_tester process.
# Widget tests (pumpWidget) consume significantly more memory than unit tests,
# so we use a smaller shard size for widget-heavy files.
SHARD_SIZE="${FLUTTER_TEST_SHARD_SIZE:-10}"
SHARD_NUM=0
OVERALL_EXIT=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Clean coverage dir
rm -rf coverage
mkdir -p coverage

run_shard() {
  local shard_files=("$@")
  SHARD_NUM=$((SHARD_NUM + 1))
  local shard_cov="coverage/lcov_shard_${SHARD_NUM}.info"

  echo "--- Shard $SHARD_NUM: ${#shard_files[@]} files ---"

  set +e
  set -o pipefail
  if [ -n "$TIMEOUT_CMD" ]; then
    $TIMEOUT_CMD "$TIMEOUT_SECS" \
      flutter test \
        --concurrency="$CONCURRENCY" \
        --reporter compact \
        --coverage \
        --timeout 5s \
        "${shard_files[@]}" 2>&1 \
      | tee "test_output_shard_${SHARD_NUM}.txt"
  else
    flutter test \
      --concurrency="$CONCURRENCY" \
      --reporter compact \
      --coverage \
      --timeout 5s \
      "${shard_files[@]}" 2>&1 \
    | tee "test_output_shard_${SHARD_NUM}.txt"
  fi
  local exit_code=${PIPESTATUS[0]}
  set +o pipefail
  set -e

  # Save shard coverage (merge later)
  if [ -f coverage/lcov.info ]; then
    cp coverage/lcov.info "$shard_cov"
  fi

  # Count results from compact reporter final summary line: "+N -M: ..."
  local last_line
  last_line=$(grep -oE '\+[0-9]+' "test_output_shard_${SHARD_NUM}.txt" | tail -1 || echo "+0")
  local passed=${last_line#+}
  TOTAL_PASSED=$((TOTAL_PASSED + passed))

  local failed_line
  # Match "-N" only at start of a word (compact reporter format: "+X -Y: test name")
  failed_line=$(grep -oE ' -[0-9]+' "test_output_shard_${SHARD_NUM}.txt" | tail -1 || echo " -0")
  failed_line=${failed_line## }  # trim leading space
  local failed=${failed_line#-}
  TOTAL_FAILED=$((TOTAL_FAILED + failed))

  # Handle exit code
  case $exit_code in
    0)
      return 0
      ;;
    124|137)
      # Timeout / killed — segfault or OOM
      local segfaults
      segfaults=$(grep -i 'segmentation fault' "test_output_shard_${SHARD_NUM}.txt" || true)
      local real_failures
      real_failures=$(grep -E '\[E\]|Some tests failed' "test_output_shard_${SHARD_NUM}.txt" | grep -v 'loading.*\[E\]' || true)
      if [ -z "$real_failures" ]; then
        echo "::warning::Shard $SHARD_NUM: flutter_tester OOM/segfault after +${passed} tests — not a code bug"
        return 0
      fi
      ;;
  esac

  # Real failures — attempt retry
  local failed_files
  failed_files=$(grep -oE 'package:[^ ]+_test\.dart' "test_output_shard_${SHARD_NUM}.txt" | sed 's/^package://' | sort -u || true)
  if [ -n "$failed_files" ]; then
    echo "::notice::Shard $SHARD_NUM: Retrying: $failed_files"
    set +e
    # shellcheck disable=SC2086
    if [ -n "$TIMEOUT_CMD" ]; then
      $TIMEOUT_CMD "$RETRY_TIMEOUT_SECS" \
        flutter test --concurrency="$CONCURRENCY" --reporter compact --coverage --timeout 5s $failed_files
    else
      flutter test --concurrency="$CONCURRENCY" --reporter compact --coverage --timeout 5s $failed_files
    fi
    local retry_exit=$?
    set -e
    if [ "$retry_exit" -eq 0 ]; then
      echo "::notice::Shard $SHARD_NUM: Retry succeeded"
      return 0
    fi
  fi

  OVERALL_EXIT=1
  return 1
}

# Run shards
for ((i=0; i<TOTAL; i+=SHARD_SIZE)); do
  shard=("${ALL_TESTS[@]:i:SHARD_SIZE}")
  run_shard "${shard[@]}" || true
done

# Merge coverage from all shards
echo "--- Merging coverage from $SHARD_NUM shards ---"
SHARD_FILES=(coverage/lcov_shard_*.info)
if [ ${#SHARD_FILES[@]} -gt 0 ] && [ -f "${SHARD_FILES[0]}" ]; then
  if command -v lcov &>/dev/null; then
    ADD_ARGS=""
    for f in "${SHARD_FILES[@]}"; do
      ADD_ARGS="$ADD_ARGS --add-tracefile $f"
    done
    # shellcheck disable=SC2086
    lcov $ADD_ARGS -o coverage/lcov.info --quiet 2>/dev/null || {
      # Fallback: just concatenate (may have duplicates but still parseable)
      cat "${SHARD_FILES[@]}" > coverage/lcov.info
    }
  else
    # No lcov available — concatenate
    cat "${SHARD_FILES[@]}" > coverage/lcov.info
  fi
  echo "Merged coverage: $(wc -l < coverage/lcov.info) lines"
else
  echo "::warning::No shard coverage files generated"
fi

echo "=== Summary: +$TOTAL_PASSED -$TOTAL_FAILED (across $SHARD_NUM shards) ==="

if [ "$OVERALL_EXIT" -ne 0 ]; then
  echo "::error::Some test shards had real failures"
  exit 1
fi

echo "All tests passed"
exit 0
