import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:grpc/grpc.dart' show CallOptions;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/app_constants.dart';
import '../data/local/secure_token_storage.dart';
import '../data/remote/grpc_clients.dart';
import '../generated/proto/sync.pb.dart' as sync_pb;
import '../generated/proto/sync.pbgrpc.dart';
import 'sync_backend.dart';

/// gRPC + WebSocket implementation of [SyncBackend].
///
/// This is a verbatim extraction of the transport code that previously lived
/// inline in `SyncEngine`: push/pull go over gRPC `SyncServiceClient`, realtime
/// change notifications arrive over a WebSocket with first-message auth, TLS
/// pinning, and exponential-backoff reconnect. Behaviour is unchanged — only
/// the home of the code moved.
class GrpcSyncBackend implements SyncBackend {
  final SyncServiceClient _syncClient;
  final TokenStorage? _tokenStorage;

  GrpcSyncBackend(this._syncClient, {TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage;

  bool _disposed = false;

  @override
  bool get isActive => true;

  @override
  void Function()? onRealtimeChange;

  @override
  void Function(int serverTimeMs)? onRealtimeWatermark;

  @override
  void Function(bool connected)? onConnectionStateChanged;

  // ─────────── Push / Pull (gRPC) ───────────

  @override
  Future<sync_pb.PushOperationsResponse> push(
    sync_pb.PushOperationsRequest request,
  ) {
    return _syncClient.pushOperations(
      request,
      options: CallOptions(timeout: const Duration(seconds: 10)),
    );
  }

  @override
  Future<sync_pb.PullChangesResponse> pull(
    sync_pb.PullChangesRequest request,
  ) {
    return _syncClient.pullChanges(request);
  }

  // ─────────── WebSocket realtime channel ───────────

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  int _reconnectAttempts = 0;

  /// Cached SecurityContext for WebSocket TLS (avoids re-parsing PEM on every reconnect).
  SecurityContext? _securityContext;

  /// Cached HttpClient for WebSocket TLS (avoids connection pool leaks on reconnect).
  HttpClient? _secureHttpClient;

  static const _wsReconnectBaseDelay = 1; // seconds
  static const _wsReconnectMaxDelay = 60; // seconds
  static const _wsReconnectMaxTotalDelay = 90; // seconds (includes jitter)

  /// Auth-ok wait timeout - longer than server's AuthTimeout (5s) to account
  /// for network latency. Server closes with 4002 before this fires normally.
  static const _authOkTimeout = Duration(seconds: 10);

  /// Set during auth phase to prevent onDone/onError from triggering reconnect
  /// (the auth catch block handles reconnect itself).
  bool _awaitingAuth = false;
  Completer<void>? _authCompleter;

  @override
  void connectRealtime() => unawaited(_connectWebSocket());

  @override
  void disconnectRealtime() => _disconnectWebSocket();

  @override
  void onAppResumed() {
    if (_disposed) return;
    if (_wsChannel == null) unawaited(_connectWebSocket());
  }

  Future<void> _connectWebSocket() async {
    if (_disposed) return;
    _disconnectWebSocket();

    final token = await _tokenStorage?.getAccessToken();
    if (token == null) {
      dev.log('[WS] _connectWebSocket: no token, skipping');
      return;
    }

    try {
      final scheme = AppConstants.useTls ? 'wss' : 'ws';
      // First-message auth: connect without token in URL
      final uri = Uri.parse(
        '$scheme://${AppConstants.serverHost}:${AppConstants.wsPort}/ws',
      );
      dev.log('[WS] connecting to $uri ...');
      _wsChannel = IOWebSocketChannel.connect(
        uri,
        customClient: AppConstants.useTls ? _createSecureHttpClient() : null,
      );

      // Await the ready future to catch connection failures early
      try {
        await _wsChannel!.ready;
        dev.log('[WS] connected successfully');
      } catch (e) {
        dev.log('[WS] handshake failed: $e');
        _scheduleReconnect();
        return;
      }

      if (_disposed) return;

      // Enter auth phase - suppress onDone/onError reconnect
      _awaitingAuth = true;
      _authCompleter = Completer<void>();

      // Subscribe BEFORE sending auth (so we don't miss auth_ok)
      _wsSub = _wsChannel!.stream.listen(
        (message) {
          if (message is! String) {
            dev.log('[WS] ignoring non-text frame (${message.runtimeType})');
            return;
          }
          dev.log('[WS] message received (${message.length} chars)');
          _handleWsMessage(message);
        },
        onError: (error) {
          dev.log('[WS] error: $error');
          if (_awaitingAuth) {
            _authCompleter?.completeError(error);
          } else {
            _scheduleReconnect();
          }
        },
        onDone: () {
          dev.log('[WS] closed');
          if (_awaitingAuth) {
            if (_authCompleter != null && !_authCompleter!.isCompleted) {
              _authCompleter!.completeError('connection closed before auth_ok');
            }
          } else {
            _scheduleReconnect();
          }
        },
      );

      // Send auth message after listen is registered
      _wsChannel!.sink.add(jsonEncode({'type': 'auth', 'token': token}));

      // Wait for auth_ok with timeout
      try {
        await _authCompleter!.future.timeout(
          _authOkTimeout,
          onTimeout: () {
            throw TimeoutException('auth_ok timeout', _authOkTimeout);
          },
        );
      } catch (e) {
        dev.log('[Sync] auth_ok not received: $e');
        _awaitingAuth = false;
        _authCompleter = null;
        _disconnectWebSocket();
        _scheduleReconnect();
        return;
      }

      // Auth succeeded - exit auth phase
      _awaitingAuth = false;
      _authCompleter = null;
      dev.log('[WS] authenticated');
    } catch (e) {
      dev.log('[WS] connect failed: $e');
      _awaitingAuth = false;
      _authCompleter = null;
      _scheduleReconnect();
    }
  }

  void _handleWsMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'auth_ok') {
        dev.log('[WS] auth_ok received');
        _reconnectAttempts = 0;
        onConnectionStateChanged?.call(true);
        if (_authCompleter != null && !_authCompleter!.isCompleted) {
          _authCompleter!.complete();
        }
        // Pull immediately after auth to catch up on changes
        onRealtimeChange?.call();
        return;
      }

      if (type == 'sync_notify' || type == 'change') {
        // 服务端通知有新变更,触发增量拉取
        onRealtimeChange?.call();
      } else if (type == 'heartbeat' || type == 'ping') {
        // Server heartbeat with watermark: engine decides whether to pull.
        final serverTimeMs = (data['server_time'] as num?)?.toInt();
        if (serverTimeMs != null) {
          onRealtimeWatermark?.call(serverTimeMs);
        }
      }
    } catch (e) {
      dev.log('[WS] failed to parse message: $e');
    }
  }

  /// Create or reuse an HttpClient with our pinned CA for WebSocket TLS.
  HttpClient _createSecureHttpClient() {
    if (_secureHttpClient != null) return _secureHttpClient!;
    _securityContext ??= SecurityContext()
      ..setTrustedCertificatesBytes(caCertBytes);
    _secureHttpClient = HttpClient(context: _securityContext!)
      ..badCertificateCallback = (cert, host, port) {
        // CA chain validated by SecurityContext (pinned CA only).
        // This callback fires only for non-chain issues (e.g. IP SAN
        // mismatch). Accept if issued by our pinned CA.
        return cert.issuer.contains(AppConstants.pinnedCaIssuer);
      };
    return _secureHttpClient!;
  }

  void _disconnectWebSocket() {
    // Cancel any pending auth wait
    if (_awaitingAuth) {
      _awaitingAuth = false;
      if (_authCompleter != null && !_authCompleter!.isCompleted) {
        _authCompleter!.completeError('disconnected');
      }
      _authCompleter = null;
    }
    _wsSub?.cancel();
    _wsSub = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
    onConnectionStateChanged?.call(false);
  }

  void _scheduleReconnect() {
    if (_disposed) return;

    final exponentialDelay =
        _wsReconnectBaseDelay * (1 << _reconnectAttempts.clamp(0, 6));
    final delay = exponentialDelay.clamp(
      _wsReconnectBaseDelay,
      _wsReconnectMaxDelay,
    );
    final jitter = Random().nextInt((delay * 0.5).ceil() + 1);
    final totalDelay = (delay + jitter).clamp(0, _wsReconnectMaxTotalDelay);

    dev.log(
      '[WS] reconnecting in ${totalDelay}s (attempt ${_reconnectAttempts + 1})',
    );
    _reconnectAttempts++;

    Future.delayed(Duration(seconds: totalDelay), () {
      if (!_disposed) _connectWebSocket();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectAttempts = 0;
    _disconnectWebSocket();
    _secureHttpClient?.close();
    _secureHttpClient = null;
  }
}
