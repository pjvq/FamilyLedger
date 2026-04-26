/// 金额以 **分** 为单位存储，展示时 ÷ 100
class AppConstants {
  AppConstants._();

  // Server
  static const serverHost = '13.229.111.244';
  static const grpcPort = 50051;
  static const wsPort = 8080;

  // Auth
  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const userIdKey = 'user_id';

  // Sync
  static const syncBatchSize = 50;
  static const syncIntervalSeconds = 30;
  static const clientIdKey = 'client_id';

  // UI
  static const currencySymbol = '¥';
  static const defaultCurrency = 'CNY';
  static const pageSize = 20;
}
