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

/// Family gRPC client
final familyClientProvider = Provider<FamilyServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return FamilyServiceClient(channel, interceptors: [AuthInterceptor(prefs)]);
});

/// Account gRPC client
final accountClientProvider = Provider<AccountServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AccountServiceClient(channel, interceptors: [AuthInterceptor(prefs)]);
});

/// Budget gRPC client
final budgetClientProvider = Provider<BudgetServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return BudgetServiceClient(channel, interceptors: [AuthInterceptor(prefs)]);
});

/// Notify gRPC client
final notifyClientProvider = Provider<NotifyServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return NotifyServiceClient(channel, interceptors: [AuthInterceptor(prefs)]);
});

/// Loan gRPC client
final loanClientProvider = Provider<LoanServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return LoanServiceClient(channel, interceptors: [AuthInterceptor(prefs)]);
});

/// Investment gRPC client
final investmentClientProvider = Provider<InvestmentServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return InvestmentServiceClient(channel, interceptors: [AuthInterceptor(prefs)]);
});

/// MarketData gRPC client
final marketDataClientProvider = Provider<MarketDataServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return MarketDataServiceClient(channel, interceptors: [AuthInterceptor(prefs)]);
});

/// Asset gRPC client
final assetClientProvider = Provider<AssetServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AssetServiceClient(channel, interceptors: [AuthInterceptor(prefs)]);
});

/// Dashboard gRPC client
final dashboardClientProvider = Provider<DashboardServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return DashboardServiceClient(channel, interceptors: [AuthInterceptor(prefs)]);
});

/// Export gRPC client
final exportClientProvider = Provider<ExportServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return ExportServiceClient(channel, interceptors: [AuthInterceptor(prefs)]);
});

/// Import gRPC client
final importClientProvider = Provider<ImportServiceClient>((ref) {
  final channel = ref.watch(grpcChannelProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return ImportServiceClient(channel, interceptors: [AuthInterceptor(prefs)]);
});
