import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../data/local/database.dart';
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

  AuthNotifier(this._db, this._prefs, this._ref)
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

  /// 注册（Phase 1 本地模式：直接创建本地用户）
  /// 后续接入 gRPC 后替换为真正的服务端注册
  Future<void> register(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      // TODO: 接入 gRPC AuthService.Register
      // 目前先本地创建用户
      final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      await _db.into(_db.users).insert(UsersCompanion.insert(
            id: userId,
            email: email,
          ));
      // 创建默认账户
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

  /// 登录
  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      // TODO: 接入 gRPC AuthService.Login
      // 目前查本地用户
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
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final db = ref.watch(databaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthNotifier(db, prefs, ref);
});
