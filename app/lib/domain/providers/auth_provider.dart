import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../data/local/database.dart';
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/auth.pbgrpc.dart';
import 'app_providers.dart';

/// 认证状态
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.userId,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? errorMessage,
  }) =>
      AuthState(
        status: status ?? this.status,
        userId: userId ?? this.userId,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AppDatabase _db;
  final SharedPreferences _prefs;
  final Ref _ref;
  final AuthServiceClient _authClient;

  AuthNotifier(this._db, this._prefs, this._ref, this._authClient)
      : super(const AuthState()) {
    _init();
  }

  void _init() {
    final userId = _prefs.getString(AppConstants.userIdKey);
    if (userId != null) {
      state = AuthState(status: AuthStatus.authenticated, userId: userId);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// 注册 — 调用 gRPC，失败时降级到本地
  Future<void> register(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final resp = await _authClient.register(
        RegisterRequest()
          ..email = email
          ..password = password,
      );

      // 保存 tokens
      await _prefs.setString(AppConstants.accessTokenKey, resp.accessToken);
      await _prefs.setString(AppConstants.refreshTokenKey, resp.refreshToken);
      await _prefs.setString(AppConstants.userIdKey, resp.userId);

      // 本地也存一份 user（离线时需要）
      await _db.into(_db.users).insertOnConflictUpdate(UsersCompanion.insert(
            id: resp.userId,
            email: email,
          ));
      // 服务端注册时已创建默认账户，本地也同步创建一个
      await _db.insertAccount(AccountsCompanion.insert(
        id: 'acc_default_${resp.userId}',
        userId: resp.userId,
        name: '默认账户',
      ));

      _ref.read(currentUserIdProvider.notifier).state = resp.userId;
      state = AuthState(status: AuthStatus.authenticated, userId: resp.userId);
    } on GrpcError {
      // gRPC 失败，降级本地注册
      await _registerLocal(email, password);
    } catch (e) {
      // 网络不通等，降级本地注册
      await _registerLocal(email, password);
    }
  }

  /// 本地注册降级
  Future<void> _registerLocal(String email, String password) async {
    try {
      final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      await _db.into(_db.users).insert(UsersCompanion.insert(
            id: userId,
            email: email,
          ));
      await _db.insertAccount(AccountsCompanion.insert(
        id: 'acc_default_$userId',
        userId: userId,
        name: '默认账户',
      ));
      await _prefs.setString(AppConstants.userIdKey, userId);
      _ref.read(currentUserIdProvider.notifier).state = userId;
      state = AuthState(status: AuthStatus.authenticated, userId: userId);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: '注册失败: $e',
      );
    }
  }

  /// 登录 — 调用 gRPC，失败时降级到本地
  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final resp = await _authClient.login(
        LoginRequest()
          ..email = email
          ..password = password,
      );

      await _prefs.setString(AppConstants.accessTokenKey, resp.accessToken);
      await _prefs.setString(AppConstants.refreshTokenKey, resp.refreshToken);
      await _prefs.setString(AppConstants.userIdKey, resp.userId);

      // 本地缓存 user
      await _db.into(_db.users).insertOnConflictUpdate(UsersCompanion.insert(
            id: resp.userId,
            email: email,
          ));

      _ref.read(currentUserIdProvider.notifier).state = resp.userId;
      state = AuthState(status: AuthStatus.authenticated, userId: resp.userId);
    } on GrpcError {
      // gRPC 失败，降级本地
      await _loginLocal(email, password);
    } catch (e) {
      await _loginLocal(email, password);
    }
  }

  /// 本地登录降级
  Future<void> _loginLocal(String email, String password) async {
    try {
      final users = await _db.select(_db.users).get();
      final user = users.where((u) => u.email == email).firstOrNull;
      if (user == null) {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: '用户不存在，请先注册',
        );
        return;
      }
      await _prefs.setString(AppConstants.userIdKey, user.id);
      _ref.read(currentUserIdProvider.notifier).state = user.id;
      state = AuthState(status: AuthStatus.authenticated, userId: user.id);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: '登录失败: $e',
      );
    }
  }

  Future<void> logout() async {
    await _prefs.remove(AppConstants.userIdKey);
    await _prefs.remove(AppConstants.accessTokenKey);
    await _prefs.remove(AppConstants.refreshTokenKey);
    _ref.read(currentUserIdProvider.notifier).state = null;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// OAuth 登录 — 调用 gRPC OAuthLogin
  Future<void> oauthLogin({
    required String provider,
    required String code,
    String redirectUri = '',
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final resp = await _authClient.oAuthLogin(
        OAuthLoginRequest()
          ..provider = provider
          ..code = code
          ..redirectUri = redirectUri,
      );

      await _prefs.setString(AppConstants.accessTokenKey, resp.accessToken);
      await _prefs.setString(AppConstants.refreshTokenKey, resp.refreshToken);
      await _prefs.setString(AppConstants.userIdKey, resp.userId);

      // Cache user locally
      await _db.into(_db.users).insertOnConflictUpdate(UsersCompanion.insert(
            id: resp.userId,
            email: '$provider@oauth',
          ));

      if (resp.isNewUser) {
        // Create default account for new OAuth users
        await _db.insertAccount(AccountsCompanion.insert(
          id: 'acc_default_${resp.userId}',
          userId: resp.userId,
          name: '默认账户',
        ));
      }

      _ref.read(currentUserIdProvider.notifier).state = resp.userId;
      state = AuthState(status: AuthStatus.authenticated, userId: resp.userId);
    } on GrpcError catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: '第三方登录失败: ${e.message}',
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: '第三方登录失败: $e',
      );
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final db = ref.watch(databaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final authClient = ref.watch(authClientProvider);
  return AuthNotifier(db, prefs, ref, authClient);
});
