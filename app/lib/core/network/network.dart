/// Network resilience utilities for gRPC communication.
///
/// Core exports:
/// - [RetryPolicy]: immutable configuration for retry behavior
/// - [grpcRetry]: free function to execute a gRPC call with retry + backoff
/// - [resilientCall]: higher-level wrapper with per-attempt timeout
/// - [defaultCallOptions]: shared timeout for direct gRPC calls
library;

import 'package:grpc/grpc.dart';

export 'resilient_call.dart';
export 'retry_policy.dart';

/// Default call options for gRPC calls throughout the app.
/// Single source of truth — change timeout here, applies everywhere.
final CallOptions defaultCallOptions = CallOptions(
  timeout: const Duration(seconds: 8),
);
