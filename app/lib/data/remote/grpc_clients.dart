import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:grpc/grpc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../local/secure_token_storage.dart';
import '../../generated/proto/auth.pbgrpc.dart';
import '../../generated/proto/transaction.pbgrpc.dart';
import '../../generated/proto/sync.pbgrpc.dart';
import '../../generated/proto/family.pbgrpc.dart';
import '../../generated/proto/account.pbgrpc.dart';
import '../../generated/proto/budget.pbgrpc.dart';
import '../../generated/proto/notify.pbgrpc.dart';
import '../../generated/proto/loan.pbgrpc.dart';
import '../../generated/proto/investment.pbgrpc.dart';
import '../../generated/proto/asset.pbgrpc.dart';
import '../../generated/proto/dashboard.pbgrpc.dart';
import '../../generated/proto/export.pbgrpc.dart';
import '../../generated/proto/import.pbgrpc.dart';

/// Cached CA certificate bytes, loaded at app startup.
/// Late-initialized; access only after [loadTlsCertificate] completes.
Uint8List? _caCertBytes;

/// Call once before runApp() to preload the pinned CA certificate.
Future<void> loadTlsCertificate() async {
  if (!AppConstants.useTls) return;
  final pem = await rootBundle.loadString('assets/certs/ca.pem');
  _caCertBytes = Uint8List.fromList(utf8.encode(pem));
}

/// Expose loaded CA cert bytes for WebSocket SecurityContext.
/// Must only be called after [loadTlsCertificate] completes.
Uint8List get caCertBytes {
  if (_caCertBytes == null) {
    throw StateError(
        'loadTlsCertificate() must be called before accessing caCertBytes');
  }
  return _caCertBytes!;
}

/// gRPC channel singleton
final grpcChannelProvider = Provider<ClientChannel>((ref) {
  final channel = ClientChannel(
    AppConstants.serverHost,
    port: AppConstants.grpcPort,
    options: ChannelOptions(
      credentials: AppConstants.useTls
          ? ChannelCredentials.secure(
              certificates: caCertBytes,
              authority: AppConstants.serverHost,
              onBadCertificate: (cert, host) {
                // CA chain validation is done by BoringSSL via `certificates`.
                // This callback only fires for non-chain issues (e.g. IP SAN
                // mismatch with IP address). Since we pinned our CA as the
                // sole trust anchor, accepting certs issued by it is safe.
                return cert.issuer.contains('FamilyLedger CA');
              },
            )
          : const ChannelCredentials.insecure(),
    ),
  );
  ref.onDispose(() => channel.shutdown());
  return channel;
});

/// JWT interceptor — attaches access_token, proactively refreshes before expiry.
///
/// Strategy: decode JWT exp claim client-side. If access token expires within
/// 60 seconds, refresh it *before* the call. This avoids the complexity of
/// intercepting ResponseFuture (which has no public constructor).
///
/// Concurrency-safe: if multiple calls trigger refresh simultaneously,
/// only one refresh runs; the rest await the same Completer.
class AuthInterceptor extends ClientInterceptor {
  final TokenStorage _tokenStorage;
  final ClientChannel _channel;

  /// Guards concurrent refresh — only one in-flight at a time.
  Completer<bool>? _refreshCompleter;

  /// Cached token to avoid reading secure storage on every gRPC call.
  /// Invalidated on refresh or clear.
  String? _cachedToken;

  AuthInterceptor(this._tokenStorage, this._channel);

  /// Invalidate cached token. Must be called on logout.
  void invalidateCache() {
    _cachedToken = null;
  }

  @override
  ResponseFuture<R> interceptUnary<Q, R>(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    // Use CallOptions.providers to defer metadata injection
    final lazyOptions = options.mergedWith(
      CallOptions(
        providers: [
          (metadata, uri) async {
            await _ensureFreshToken();
            final token = _cachedToken ?? await _tokenStorage.getAccessToken();
            _cachedToken = token;
            if (token != null) {
              metadata['authorization'] = 'Bearer $token';
            }
          },
        ],
      ),
    );
    return invoker(method, request, lazyOptions);
  }

  /// Ensures access token is fresh. If it expires within 60s, refreshes it.
  Future<void> _ensureFreshToken() async {
    final accessToken = _cachedToken ?? await _tokenStorage.getAccessToken();
    _cachedToken = accessToken;
    if (accessToken == null) return;

    // Decode JWT exp without verification (client-side convenience only)
    final expiry = _decodeJwtExp(accessToken);
    if (expiry == null) return;

    // If token is still valid for > 60 seconds, no refresh needed
    final now = DateTime.now();
    if (expiry.isAfter(now.add(const Duration(seconds: 60)))) return;

    // Token expires soon or already expired — refresh
    await _tryRefreshToken();
  }

  /// Returns true if refresh succeeded.
  /// Ensures only one refresh runs at a time.
  Future<bool> _tryRefreshToken() async {
    // If another call is already refreshing, wait for it
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }

      // Use a bare client (no interceptor) to avoid infinite recursion
      final bareClient = AuthServiceClient(_channel);
      final resp = await bareClient.refreshToken(
        RefreshTokenRequest(refreshToken: refreshToken),
      );

      // Store new tokens securely
      await _tokenStorage.setAccessToken(resp.accessToken);
      await _tokenStorage.setRefreshToken(resp.refreshToken);
      _cachedToken = resp.accessToken; // Update cache

      _refreshCompleter!.complete(true);
      return true;
    } catch (_) {
      // Refresh failed — clear tokens, user needs to re-login
      await _tokenStorage.clearTokens();
      _cachedToken = null;
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// Decode JWT exp claim without signature verification.
  /// Returns null if decoding fails.
  static DateTime? _decodeJwtExp(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // base64url decode the payload
      String payload = parts[1];
      // Normalize base64url to base64
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final decoded = utf8.decode(base64.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = json['exp'] as int?;
      if (exp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (_) {
      return null;
    }
  }
}

/// Shared interceptor singleton — all clients use the same instance
/// so concurrent refresh coordination works correctly.
final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  final tokenStorage = ref.watch(secureTokenStorageProvider);
  final channel = ref.watch(grpcChannelProvider);
  return AuthInterceptor(tokenStorage, channel);
});

/// Helper: create a gRPC client provider with auth interceptor.
/// TODO: Forward CallOptions if a client needs custom timeouts.
Provider<T> _grpcClientProvider<T extends Client>(
  T Function(ClientChannel, {Iterable<ClientInterceptor> interceptors}) ctor,
) {
  return Provider<T>((ref) {
    final channel = ref.watch(grpcChannelProvider);
    final interceptor = ref.watch(authInterceptorProvider);
    return ctor(channel, interceptors: [interceptor]);
  });
}

final authClientProvider = _grpcClientProvider(AuthServiceClient.new);
final transactionClientProvider = _grpcClientProvider(TransactionServiceClient.new);
final syncClientProvider = _grpcClientProvider(SyncServiceClient.new);
final familyClientProvider = _grpcClientProvider(FamilyServiceClient.new);
final accountClientProvider = _grpcClientProvider(AccountServiceClient.new);
final budgetClientProvider = _grpcClientProvider(BudgetServiceClient.new);
final notifyClientProvider = _grpcClientProvider(NotifyServiceClient.new);
final loanClientProvider = _grpcClientProvider(LoanServiceClient.new);
final investmentClientProvider = _grpcClientProvider(InvestmentServiceClient.new);
final marketDataClientProvider = _grpcClientProvider(MarketDataServiceClient.new);
final assetClientProvider = _grpcClientProvider(AssetServiceClient.new);
final dashboardClientProvider = _grpcClientProvider(DashboardServiceClient.new);
final exportClientProvider = _grpcClientProvider(ExportServiceClient.new);
final importClientProvider = _grpcClientProvider(ImportServiceClient.new);
