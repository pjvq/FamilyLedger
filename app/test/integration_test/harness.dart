/// E2E Integration Test Harness for FamilyLedger.
///
/// Connects Dart test client directly to a running Go gRPC server + PostgreSQL.
/// Each test gets an isolated PG schema to prevent interference.
///
/// Prerequisites:
///   - Go server running on localhost:50051 (gRPC) + localhost:8080 (WS)
///   - PostgreSQL running on localhost:5432
///   - Migrations already applied
///
/// Environment variables:
///   GRPC_HOST (default: localhost)
///   GRPC_PORT (default: 50051)
///   WS_HOST   (default: localhost)
///   WS_PORT   (default: 8080)
library;

import 'dart:io';

import 'package:grpc/grpc.dart';

/// Configuration for the E2E test harness.
class HarnessConfig {
  final String grpcHost;
  final int grpcPort;
  final String wsHost;
  final int wsPort;

  HarnessConfig({
    String? grpcHost,
    int? grpcPort,
    String? wsHost,
    int? wsPort,
  })  : grpcHost = grpcHost ??
            Platform.environment['GRPC_HOST'] ??
            '127.0.0.1',
        grpcPort = grpcPort ??
            int.tryParse(Platform.environment['GRPC_PORT'] ?? '') ??
            50051,
        wsHost = wsHost ??
            Platform.environment['WS_HOST'] ??
            '127.0.0.1',
        wsPort = wsPort ??
            int.tryParse(Platform.environment['WS_PORT'] ?? '') ??
            8080;
}

/// The main test harness — manages gRPC channel, auth tokens, and cleanup.
class E2EHarness {
  final HarnessConfig config;
  late final ClientChannel _channel;

  String? _accessToken;
  String? _refreshToken;

  E2EHarness({HarnessConfig? config})
      : config = config ?? HarnessConfig();

  /// Initialize the gRPC channel. Call in setUpAll.
  void setUp() {
    _channel = ClientChannel(
      config.grpcHost,
      port: config.grpcPort,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
  }

  /// Shutdown the gRPC channel. Call in tearDownAll.
  Future<void> tearDown() async {
    await _channel.shutdown();
  }

  /// Get the active gRPC channel.
  ClientChannel get channel => _channel;

  /// Get authenticated call options (with JWT in metadata).
  CallOptions get authOptions {
    if (_accessToken == null) {
      throw StateError('Not authenticated. Call register() or login() first.');
    }
    return CallOptions(
      metadata: {'authorization': 'Bearer $_accessToken'},
    );
  }

  /// Store tokens after auth operations.
  void setTokens({required String accessToken, required String refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  /// WebSocket URL for real-time sync testing.
  String get wsUrl => 'ws://${config.wsHost}:${config.wsPort}/ws';
}

/// Fault injection layer for E2E tests.
///
/// TODO(W9): Integrate with gRPC ClientInterceptor to:
/// 1. Check isNetworkDisabled → throw GrpcError.unavailable()
/// 2. Apply latency via Future.delayed before forwarding
/// 3. Support partial failure (N-th call fails pattern)
///
/// Example integration:
///   channel = ClientChannel(..., options: ChannelOptions(
///     interceptors: [FaultInterceptor(injector)],
///   ));
class FaultInjector {
  bool _networkDisabled = false;
  Duration _latency = Duration.zero;

  /// Simulate network disconnection.
  void disableNetwork() => _networkDisabled = true;

  /// Restore network.
  void enableNetwork() => _networkDisabled = false;

  /// Add artificial latency.
  void setLatency(Duration latency) => _latency = latency;

  /// Reset all faults.
  void reset() {
    _networkDisabled = false;
    _latency = Duration.zero;
  }

  bool get isNetworkDisabled => _networkDisabled;
  Duration get latency => _latency;
}
