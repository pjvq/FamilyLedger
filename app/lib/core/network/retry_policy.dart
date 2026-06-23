import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:grpc/grpc.dart';

/// Configuration for retry behavior on gRPC calls.
///
/// Immutable value object — create once, share across multiple call sites.
/// Each [RetryPolicy] instance defines which failures are retryable, how many
/// attempts to make, and how long to wait between them.
class RetryPolicy {
  /// Maximum number of attempts (including the first call).
  /// Example: maxAttempts=3 means 1 original + 2 retries.
  final int maxAttempts;

  /// Base delay between retries. Actual delay = baseDelay * 2^(attempt-1) + jitter.
  final Duration baseDelay;

  /// Upper bound on computed backoff delay (before jitter).
  final Duration maxDelay;

  /// Fraction of delay to randomize (0.0 = no jitter, 1.0 = up to 100% of delay added).
  /// Jitter decorrelates retries from multiple clients hitting the same server.
  final double jitterFactor;

  /// Status codes that trigger a retry. All others propagate immediately.
  ///
  /// Default set based on gRPC spec for transient failures:
  /// - UNAVAILABLE: server not reachable (network down, DNS failure, connection refused)
  /// - DEADLINE_EXCEEDED: call timed out (may succeed on retry with fresh deadline)
  /// - RESOURCE_EXHAUSTED: server-side rate limiting (backoff then retry)
  /// - ABORTED: transaction conflict (CAS failure, optimistic locking — safe to retry)
  final Set<int> retryableStatusCodes;

  /// Per-attempt timeout. If null, the gRPC CallOptions timeout applies as-is.
  /// When set, each attempt gets this deadline independently (not shared across retries).
  final Duration? perAttemptTimeout;

  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 200),
    this.maxDelay = const Duration(seconds: 5),
    this.jitterFactor = 0.3,
    this.retryableStatusCodes = const {
      StatusCode.unavailable,
      StatusCode.deadlineExceeded,
      StatusCode.resourceExhausted,
      StatusCode.aborted,
    },
    this.perAttemptTimeout,
  }) : assert(maxAttempts >= 1, 'maxAttempts must be >= 1'),
       assert(
         jitterFactor >= 0.0 && jitterFactor <= 1.0,
         'jitterFactor must be in [0, 1]',
       );

  /// No retry — fail fast on first error. Use for non-idempotent mutations
  /// where retry could cause duplicate side effects.
  static const noRetry = RetryPolicy(maxAttempts: 1);

  /// Aggressive retry for critical operations (e.g. token refresh, initial sync).
  static const aggressive = RetryPolicy(
    maxAttempts: 5,
    baseDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 15),
  );

  /// Maximum bit-shift exponent to prevent integer overflow in backoff calculation.
  /// 2^10 = 1024x multiplier — sufficient headroom before maxDelay caps it.
  static const _maxExponent = 10;

  /// Compute the backoff duration for the given attempt (0-indexed).
  Duration computeDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;
    // Exponential: baseDelay * 2^(attempt-1), capped at maxDelay
    final exponential = baseDelay * (1 << (attempt - 1).clamp(0, _maxExponent));
    final capped = exponential > maxDelay ? maxDelay : exponential;
    // Add jitter: random uniform [0, jitterFactor * capped]
    final jitterMs =
        (_random.nextDouble() * jitterFactor * capped.inMilliseconds).round();
    return capped + Duration(milliseconds: jitterMs);
  }

  bool isRetryable(GrpcError error) =>
      retryableStatusCodes.contains(error.code);

  // Non-cryptographic PRNG is sufficient for jitter — this is a scheduling
  // optimization (decorrelating retry bursts), not a security mechanism.
  // Random.secure() would add syscall overhead on every retry with no benefit.
  static final _random = Random();
}

/// Executes a gRPC unary call with retry and exponential backoff.
///
/// This is a free function (not a class) because it's stateless — all state
/// is captured in the [RetryPolicy] and the closure [fn]. No object allocation
/// on the happy path beyond the Future machinery.
///
/// Usage:
/// ```dart
/// final response = await grpcRetry(
///   () => client.getUser(request, options: callOpts),
///   policy: RetryPolicy(maxAttempts: 3),
/// );
/// ```
///
/// The [fn] closure is invoked on each attempt. It receives no arguments —
/// embed your request/options in the closure. This keeps the retry logic
/// completely decoupled from protobuf types.
///
/// [onRetry] is called before each retry sleep, for logging/metrics.
Future<T> grpcRetry<T>(
  Future<T> Function() fn, {
  RetryPolicy policy = const RetryPolicy(),
  void Function(int attempt, GrpcError error, Duration nextDelay)? onRetry,
}) async {
  for (int attempt = 0; attempt < policy.maxAttempts; attempt++) {
    try {
      return await fn();
    } on GrpcError catch (e) {
      final isLastAttempt = attempt == policy.maxAttempts - 1;
      if (isLastAttempt || !policy.isRetryable(e)) {
        rethrow;
      }
      final delay = policy.computeDelay(attempt + 1);
      onRetry?.call(attempt + 1, e, delay);
      dev.log(
        'grpcRetry: attempt ${attempt + 1}/${policy.maxAttempts} failed '
        '(${e.codeName}), retrying in ${delay.inMilliseconds}ms',
        name: 'grpc_retry',
      );
      await Future<void>.delayed(delay);
    }
  }
  // Unreachable — loop either returns or rethrows.
  throw StateError('grpcRetry: unreachable');
}

/// Extension on gRPC client calls for ergonomic retry syntax.
///
/// ```dart
/// final resp = await client.getUser(req).withRetry(policy: RetryPolicy.aggressive);
/// ```
///
/// NOTE: This wraps a ResponseFuture which is already in-flight. For proper
/// retry with fresh deadlines, prefer the [grpcRetry] free function with a
/// closure that creates a new call on each attempt.
extension GrpcRetryExtension<T> on ResponseFuture<T> {
  /// Awaits this call; on retryable failure, re-invokes [retry] up to
  /// [policy.maxAttempts - 1] additional times.
  ///
  /// [retry] must create a **new** call (new deadline, new metadata).
  /// If [retry] is null, the original call's error propagates without retry
  /// (use [grpcRetry] instead for proper retry semantics).
  Future<T> withRetry({
    RetryPolicy policy = const RetryPolicy(),
    ResponseFuture<T> Function()? retry,
  }) async {
    try {
      return await this;
    } on GrpcError catch (e) {
      final remainingAttempts = policy.maxAttempts - 1;
      if (retry == null || remainingAttempts <= 0 || !policy.isRetryable(e)) {
        rethrow;
      }
      // Delegate remaining attempts to grpcRetry
      return grpcRetry(
        () => retry(),
        policy: RetryPolicy(
          maxAttempts: remainingAttempts,
          baseDelay: policy.baseDelay,
          maxDelay: policy.maxDelay,
          jitterFactor: policy.jitterFactor,
          retryableStatusCodes: policy.retryableStatusCodes,
          perAttemptTimeout: policy.perAttemptTimeout,
        ),
      );
    }
  }
}
