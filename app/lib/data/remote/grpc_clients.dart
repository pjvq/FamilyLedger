import 'package:grpc/grpc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/providers/app_providers.dart';
import '../../generated/proto/auth.pbgrpc.dart';
import '../../generated/proto/transaction.pbgrpc.dart';
import '../../generated/proto/sync.pbgrpc.dart';

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

/// JWT interceptor — attaches access_token to every gRPC call
class AuthInterceptor extends ClientInterceptor {
  final SharedPreferences _prefs;

  AuthInterceptor(this._prefs);

  @override
  ResponseFuture<R> interceptUnary<Q, R>(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    final token = _prefs.getString(AppConstants.accessTokenKey);
    final newOptions = token != null
        ? options.mergedWith(CallOptions(metadata: {'authorization': 'Bearer $token'}))
        : options;
    return invoker(method, request, newOptions);
  }
}

/// Auth gRPC client
final authClientProvider = Provider<AuthServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthServiceClient(channel, interceptors: [AuthInterceptor(prefs)]);
});

/// Transaction gRPC client
final transactionClientProvider = Provider<TransactionServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return TransactionServiceClient(channel, interceptors: [AuthInterceptor(prefs)]);
});

/// Sync gRPC client
final syncClientProvider = Provider<SyncServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return SyncServiceClient(channel, interceptors: [AuthInterceptor(prefs)]);
});
