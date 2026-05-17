/// 金额以 **分** 为单位存储，展示时 ÷ 100
class AppConstants {
  AppConstants._();

  // Server
  static const serverHost = '124.222.52.10';
  static const grpcPort = 50051;
  static const wsPort = 8080;

  /// Whether gRPC uses TLS. Must match server GRPC_TLS_CERT config.
  /// Set to true when server has TLS enabled.
  static const useTls = false; // TODO: enable when GRPC_TLS_CERT deployed

  // Auth
  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const userIdKey = 'user_id';

  // Family
  static const familyIdKey = 'current_family_id';

  // Sync
  static const syncBatchSize = 50;
  static const syncIntervalSeconds = 30;
  static const clientIdKey = 'client_id';

  // UI
  static const currencySymbol = '¥';
  static const defaultCurrency = 'CNY';
  static const pageSize = 20;
}
