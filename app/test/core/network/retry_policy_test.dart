import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:familyledger/core/network/retry_policy.dart';

void main() {
  group('RetryPolicy', () {
    test('computeDelay returns Duration.zero for attempt 0', () {
      const policy = RetryPolicy();
      expect(policy.computeDelay(0), Duration.zero);
    });

    test('computeDelay grows exponentially', () {
      const policy = RetryPolicy(
        baseDelay: Duration(milliseconds: 100),
        maxDelay: Duration(seconds: 10),
        jitterFactor: 0.0, // Disable jitter for deterministic test
      );
      expect(policy.computeDelay(1), const Duration(milliseconds: 100));
      expect(policy.computeDelay(2), const Duration(milliseconds: 200));
      expect(policy.computeDelay(3), const Duration(milliseconds: 400));
      expect(policy.computeDelay(4), const Duration(milliseconds: 800));
    });

    test('computeDelay caps at maxDelay', () {
      const policy = RetryPolicy(
        baseDelay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 3),
        jitterFactor: 0.0,
      );
      // 2^3 = 8s > 3s cap
      expect(policy.computeDelay(4), const Duration(seconds: 3));
    });

    test('computeDelay adds jitter within bounds', () {
      const policy = RetryPolicy(
        baseDelay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 10),
        jitterFactor: 0.5,
      );
      // Run multiple times to ensure jitter is bounded
      for (int i = 0; i < 100; i++) {
        final delay = policy.computeDelay(1);
        // Base = 1s, jitter up to 50% of base = 500ms
        expect(delay.inMilliseconds, greaterThanOrEqualTo(1000));
        expect(delay.inMilliseconds, lessThanOrEqualTo(1500));
      }
    });

    test('isRetryable returns true for configured codes', () {
      const policy = RetryPolicy();
      expect(policy.isRetryable(GrpcError.unavailable()), isTrue);
      expect(policy.isRetryable(GrpcError.deadlineExceeded()), isTrue);
      expect(policy.isRetryable(GrpcError.resourceExhausted()), isTrue);
      expect(policy.isRetryable(GrpcError.aborted()), isTrue);
    });

    test('isRetryable returns false for non-retryable codes', () {
      const policy = RetryPolicy();
      expect(policy.isRetryable(GrpcError.invalidArgument()), isFalse);
      expect(policy.isRetryable(GrpcError.notFound()), isFalse);
      expect(policy.isRetryable(GrpcError.permissionDenied()), isFalse);
      expect(policy.isRetryable(GrpcError.unauthenticated()), isFalse);
    });

    test('noRetry has maxAttempts=1', () {
      expect(RetryPolicy.noRetry.maxAttempts, 1);
    });
  });

  group('grpcRetry', () {
    test('returns result on first attempt success', () async {
      int callCount = 0;
      final result = await grpcRetry(() async {
        callCount++;
        return 'success';
      });
      expect(result, 'success');
      expect(callCount, 1);
    });

    test('retries on retryable error and eventually succeeds', () async {
      int callCount = 0;
      final result = await grpcRetry(
        () async {
          callCount++;
          if (callCount < 3) throw GrpcError.unavailable();
          return 'recovered';
        },
        policy: const RetryPolicy(
          maxAttempts: 3,
          baseDelay: Duration(milliseconds: 1), // Fast for tests
          jitterFactor: 0.0,
        ),
      );
      expect(result, 'recovered');
      expect(callCount, 3);
    });

    test('throws after exhausting all attempts', () async {
      int callCount = 0;
      await expectLater(
        grpcRetry(
          () async {
            callCount++;
            throw GrpcError.unavailable();
          },
          policy: const RetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration(milliseconds: 1),
            jitterFactor: 0.0,
          ),
        ),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unavailable)),
      );
      expect(callCount, 3);
    });

    test('does not retry on non-retryable error', () async {
      int callCount = 0;
      await expectLater(
        grpcRetry(
          () async {
            callCount++;
            throw GrpcError.invalidArgument('bad input');
          },
          policy: const RetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration(milliseconds: 1),
          ),
        ),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.invalidArgument)),
      );
      expect(callCount, 1); // No retry
    });

    test('calls onRetry callback before each retry', () async {
      final retryLog = <int>[];
      int callCount = 0;
      await grpcRetry(
        () async {
          callCount++;
          if (callCount < 3) throw GrpcError.unavailable();
          return 'ok';
        },
        policy: const RetryPolicy(
          maxAttempts: 3,
          baseDelay: Duration(milliseconds: 1),
          jitterFactor: 0.0,
        ),
        onRetry: (attempt, error, delay) {
          retryLog.add(attempt);
        },
      );
      expect(retryLog, [1, 2]);
    });

    test('noRetry policy fails immediately without retry', () async {
      int callCount = 0;
      await expectLater(
        grpcRetry(
          () async {
            callCount++;
            throw GrpcError.unavailable();
          },
          policy: RetryPolicy.noRetry,
        ),
        throwsA(isA<GrpcError>()),
      );
      expect(callCount, 1);
    });
  });
}
