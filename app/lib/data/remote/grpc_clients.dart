import 'dart:async';
import 'dart:convert';
import 'package:grpc/grpc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/providers/app_providers.dart';
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

/// gRPC channel singleton
final grpcChannelProvider = Provider<ClientChannel>((ref) {
  final channel = ClientChannel(
    AppConstants.serverHost,
    port: AppConstants.grpcPort,
    options: const ChannelOptions(
      credentials: ChannelCredentials.insecure(),
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
  final SharedPreferences _prefs;
  final ClientChannel _channel;

  /// Guards concurrent refresh — only one in-flight at a time.
  Completer<bool>? _refreshCompleter;

  AuthInterceptor(this._prefs, this._channel);

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
            final token = _prefs.getString(AppConstants.accessTokenKey);
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
    final accessToken = _prefs.getString(AppConstants.accessTokenKey);
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
      final refreshToken = _prefs.getString(AppConstants.refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }

      // Use a bare client (no interceptor) to avoid infinite recursion
      final bareClient = AuthServiceClient(_channel);
      final resp = await bareClient.refreshToken(
        RefreshTokenRequest(refreshToken: refreshToken),
      );

      // Store new tokens
      await _prefs.setString(AppConstants.accessTokenKey, resp.accessToken);
      await _prefs.setString(AppConstants.refreshTokenKey, resp.refreshToken);

      _refreshCompleter!.complete(true);
      return true;
    } catch (_) {
      // Refresh failed — clear tokens, user needs to re-login
      await _prefs.remove(AppConstants.accessTokenKey);
      await _prefs.remove(AppConstants.refreshTokenKey);
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
final _authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final channel = ref.watch(grpcChannelProvider);
  return AuthInterceptor(prefs, channel);
});

/// Auth gRPC client
final authClientProvider = Provider<AuthServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final interceptor = ref.watch(_authInterceptorProvider);
  return AuthServiceClient(channel, interceptors: [interceptor]);
});

/// Transaction gRPC client
final transactionClientProvider = Provider<TransactionServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final interceptor = ref.watch(_authInterceptorProvider);
  return TransactionServiceClient(channel, interceptors: [interceptor]);
});

/// Sync gRPC client
final syncClientProvider = Provider<SyncServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final interceptor = ref.watch(_authInterceptorProvider);
  return SyncServiceClient(channel, interceptors: [interceptor]);
});

/// Family gRPC client
final familyClientProvider = Provider<FamilyServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final interceptor = ref.watch(_authInterceptorProvider);
  return FamilyServiceClient(channel, interceptors: [interceptor]);
});

/// Account gRPC client
final accountClientProvider = Provider<AccountServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final interceptor = ref.watch(_authInterceptorProvider);
  return AccountServiceClient(channel, interceptors: [interceptor]);
});

/// Budget gRPC client
final budgetClientProvider = Provider<BudgetServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final interceptor = ref.watch(_authInterceptorProvider);
  return BudgetServiceClient(channel, interceptors: [interceptor]);
});

/// Notify gRPC client
final notifyClientProvider = Provider<NotifyServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final interceptor = ref.watch(_authInterceptorProvider);
  return NotifyServiceClient(channel, interceptors: [interceptor]);
});

/// Loan gRPC client
final loanClientProvider = Provider<LoanServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final interceptor = ref.watch(_authInterceptorProvider);
  return LoanServiceClient(channel, interceptors: [interceptor]);
});

/// Investment gRPC client
final investmentClientProvider = Provider<InvestmentServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final interceptor = ref.watch(_authInterceptorProvider);
  return InvestmentServiceClient(channel, interceptors: [interceptor]);
});

/// MarketData gRPC client
final marketDataClientProvider = Provider<MarketDataServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final interceptor = ref.watch(_authInterceptorProvider);
  return MarketDataServiceClient(channel, interceptors: [interceptor]);
});

/// Asset gRPC client
final assetClientProvider = Provider<AssetServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final interceptor = ref.watch(_authInterceptorProvider);
  return AssetServiceClient(channel, interceptors: [interceptor]);
});

/// Dashboard gRPC client
final dashboardClientProvider = Provider<DashboardServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final interceptor = ref.watch(_authInterceptorProvider);
  return DashboardServiceClient(channel, interceptors: [interceptor]);
});

/// Export gRPC client
final exportClientProvider = Provider<ExportServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final interceptor = ref.watch(_authInterceptorProvider);
  return ExportServiceClient(channel, interceptors: [interceptor]);
});

/// Import gRPC client
final importClientProvider = Provider<ImportServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final interceptor = ref.watch(_authInterceptorProvider);
  return ImportServiceClient(channel, interceptors: [interceptor]);
});
