import 'dart:developer' as dev;

import 'package:grpc/grpc.dart';
import 'retry_policy.dart';

/// Default [CallOptions] with per-attempt timeout.
///
/// Each gRPC call gets a fresh deadline. This replaces the old
/// `static final _callOpts = CallOptions(timeout: Duration(seconds: 5))`.
///
/// Why 8 seconds: accounts for TLS handshake + server processing + serialization.
/// Too short → spurious timeouts on cold connections.
/// Too long → user perceives the app as hung.
const _defaultPerAttemptTimeout = Duration(seconds: 8);

/// Creates [CallOptions] with a per-attempt deadline.
/// If the caller already set a timeout, their value wins.
CallOptions callOptionsWithTimeout({Duration? timeout}) {
  return CallOptions(
    timeout: timeout ?? _defaultPerAttemptTimeout,
  );
}

/// Invokes a gRPC unary RPC with retry, per-attempt timeout, and structured logging.
///
/// This is the single point of enforcement for retry policy across the entire app.
/// All provider-level gRPC calls should route through this.
///
/// Type parameters:
/// - [T] is the response type (inferred from [fn])
///
/// Parameters:
/// - [fn]: Closure that invokes the gRPC stub method with appropriate [CallOptions].
///   The closure receives a [CallOptions] argument with the per-attempt timeout set.
/// - [policy]: Retry behavior. Defaults to 3 attempts with exponential backoff.
/// - [operationName]: For structured logging/metrics. Example: "TransactionService.Create".
///
/// Returns the successful response, or throws [GrpcError] if all attempts fail.
///
/// Example:
/// ```dart
/// final resp = await resilientCall(
///   (opts) => _client.createTransaction(request, options: opts),
///   operationName: 'CreateTransaction',
///   policy: RetryPolicy.noRetry, // non-idempotent
/// );
/// ```
Future<T> resilientCall<T>(
  Future<T> Function(CallOptions options) fn, {
  RetryPolicy policy = const RetryPolicy(),
  String? operationName,
}) {
  return grpcRetry(
    () => fn(callOptionsWithTimeout(timeout: policy.perAttemptTimeout)),
    policy: policy,
    onRetry: operationName != null
        ? (attempt, error, delay) {
            // Structured retry logging tied to operation name for observability.
            dev.log(
              '$operationName: retry $attempt/${policy.maxAttempts} '
              'after ${error.codeName}, next in ${delay.inMilliseconds}ms',
              name: 'grpc_retry',
            );
          }
        : null,
  );
}
