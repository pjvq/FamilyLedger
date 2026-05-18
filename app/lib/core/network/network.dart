/// Network resilience utilities for gRPC communication.
///
/// Core exports:
/// - [RetryPolicy]: immutable configuration for retry behavior
/// - [grpcRetry]: free function to execute a gRPC call with retry + backoff
/// - [resilientCall]: higher-level wrapper with per-attempt timeout
library;

export 'resilient_call.dart';
export 'retry_policy.dart';
