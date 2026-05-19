/// 金额以 **分** 为单位存储，展示时 ÷ 100
class AppConstants {
  AppConstants._();

  // ─── Server Configuration ─────────────────────────────────────────────────
  // Resolved at compile-time via --dart-define or .env flavor.
  // Usage: flutter run --dart-define=SERVER_HOST=192.168.1.100
  //
  // Defaults are production values; override for dev/staging.

  static const serverHost = String.fromEnvironment(
    'SERVER_HOST',
    defaultValue: '124.222.52.10',
  );

  static const grpcPort = int.fromEnvironment(
    'GRPC_PORT',
    defaultValue: 50051,
  );

  static const wsPort = int.fromEnvironment(
    'WS_PORT',
    defaultValue: 8080,
  );

  /// Whether to use TLS for gRPC and WebSocket connections.
  /// Override: --dart-define=USE_TLS=true
  static const useTls = bool.fromEnvironment(
    'USE_TLS',
    defaultValue: false,
  );

  // ─── Auth ─────────────────────────────────────────────────────────────────
  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const userIdKey = 'user_id';

  // ─── Family ───────────────────────────────────────────────────────────────
  static const familyIdKey = 'current_family_id';

  // ─── Sync ─────────────────────────────────────────────────────────────────
  static const syncBatchSize = 50;
  static const syncIntervalSeconds = 30;
  static const clientIdKey = 'client_id';

  // ─── UI ───────────────────────────────────────────────────────────────────
  static const currencySymbol = '¥';
  static const defaultCurrency = 'CNY';
  static const pageSize = 20;
}
