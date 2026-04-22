/// 金额以 **分** 为单位存储，展示时 ÷ 100
class AppConstants {
  AppConstants._();

  // Server
  static const defaultHost = '10.0.2.2'; // Android emulator → host
  static const defaultPort = 50051; // gRPC
  static const wsPort = 8080; // WebSocket

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
