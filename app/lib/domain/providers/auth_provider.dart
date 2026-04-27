import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../data/local/database.dart';
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/auth.pbgrpc.dart';
import '../../generated/proto/account.pb.dart' as acc_pb;
import 'account_provider.dart' show AccountTypeHelper;
import '../../generated/proto/transaction.pb.dart' as txn_pb;
import '../../generated/proto/transaction.pbenum.dart' as txn_enum;
import 'app_providers.dart';

/// 认证状态
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? errorMessage;
  final bool isOfflineMode;

  const AuthState({
    this.status = AuthStatus.initial,
    this.userId,
    this.errorMessage,
    this.isOfflineMode = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? errorMessage,
    bool? isOfflineMode,
  }) =>
      AuthState(
        status: status ?? this.status,
        userId: userId ?? this.userId,
        errorMessage: errorMessage ?? this.errorMessage,
        isOfflineMode: isOfflineMode ?? this.isOfflineMode,
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
    developer.log('[Auth] register: attempting gRPC to ${AppConstants.serverHost}:${AppConstants.grpcPort}');
    try {
      final resp = await _authClient.register(
        RegisterRequest()
          ..email = email
          ..password = password,
        options: CallOptions(timeout: const Duration(seconds: 5)),
      );
      developer.log('[Auth] register: gRPC SUCCESS, userId=${resp.userId}');

      // 保存 tokens
      await _prefs.setString(AppConstants.accessTokenKey, resp.accessToken);
      await _prefs.setString(AppConstants.refreshTokenKey, resp.refreshToken);
      await _prefs.setString(AppConstants.userIdKey, resp.userId);

      // 本地也存一份 user（离线时需要）
      await _db.into(_db.users).insertOnConflictUpdate(UsersCompanion.insert(
            id: resp.userId,
            email: email,
          ));
      // 服务端注册时已创建默认账户+分类，同步到本地
      try {
        final accClient = _ref.read(accountClientProvider);
        final accResp = await accClient.listAccounts(acc_pb.ListAccountsRequest());
        for (final a in accResp.accounts) {
          await _db.into(_db.accounts).insertOnConflictUpdate(
            AccountsCompanion.insert(
              id: a.id,
              userId: a.userId,
              name: a.name,
              balance: Value(a.balance.toInt()),
              icon: Value(a.icon),
              currency: Value(a.currency),
              accountType: Value(AccountTypeHelper.fromProto(a.type)),
              isActive: Value(a.isActive),
            ),
          );
        }
      } catch (_) {
        // Fallback: create minimal local account
        await _db.insertAccount(AccountsCompanion.insert(
          id: 'acc_default_${resp.userId}',
          userId: resp.userId,
          name: '默认账户',
        ));
      }

      // 同步服务端分类（含子分类）
      await _syncCategoriesToLocal();

      _ref.read(currentUserIdProvider.notifier).state = resp.userId;
      state = AuthState(status: AuthStatus.authenticated, userId: resp.userId);
    } on GrpcError catch (e) {
      developer.log('[Auth] register: GrpcError code=${e.code} codeName=${e.codeName} message=${e.message}');
      if (e.code == StatusCode.alreadyExists) {
        // 邮箱已注册，自动尝试登录
        try {
          await login(email, password);
          return;
        } catch (_) {
          // 登录也失败，降级本地
          await _registerLocal(email, password);
        }
      } else if (e.code == StatusCode.unavailable || e.code == StatusCode.deadlineExceeded) {
        // 网络不通或超时，降级本地注册
        await _registerLocal(email, password);
      } else {
        // 业务错误（InvalidArgument 等），直接显示错误信息
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: e.message ?? '注册失败: ${e.codeName}',
        );
      }
    } catch (e, st) {
      developer.log('[Auth] register: non-gRPC error: $e\n$st');
      // 非 gRPC 异常，降级本地注册
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
      state = AuthState(status: AuthStatus.authenticated, userId: userId, isOfflineMode: true);
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
    developer.log('[Auth] login: attempting gRPC to ${AppConstants.serverHost}:${AppConstants.grpcPort}');
    try {
      final resp = await _authClient.login(
        LoginRequest()
          ..email = email
          ..password = password,
        options: CallOptions(timeout: const Duration(seconds: 5)),
      );
      developer.log('[Auth] login: gRPC SUCCESS, userId=${resp.userId}');

      await _prefs.setString(AppConstants.accessTokenKey, resp.accessToken);
      await _prefs.setString(AppConstants.refreshTokenKey, resp.refreshToken);
      await _prefs.setString(AppConstants.userIdKey, resp.userId);

      // 本地缓存 user
      await _db.into(_db.users).insertOnConflictUpdate(UsersCompanion.insert(
            id: resp.userId,
            email: email,
          ));

      // 先同步账户和分类，再设置 userId 触发 provider rebuild
      // 这样 TransactionNotifier rebuild 时分类已是服务端的

      // 登录成功后同步服务端账户到本地
      try {
        final accClient = _ref.read(accountClientProvider);
        final accResp = await accClient.listAccounts(acc_pb.ListAccountsRequest());
        for (final a in accResp.accounts) {
          await _db.into(_db.accounts).insertOnConflictUpdate(
            AccountsCompanion.insert(
              id: a.id,
              userId: a.userId,
              name: a.name,
              balance: Value(a.balance.toInt()),
              icon: Value(a.icon),
              currency: Value(a.currency),
              accountType: Value(AccountTypeHelper.fromProto(a.type)),
              isActive: Value(a.isActive),
            ),
          );
        }
      } catch (_) {}

      // 同步服务端分类到本地（含子分类）
      await _syncCategoriesToLocal();

      // 最后设置 userId 触发 UI rebuild
      _ref.read(currentUserIdProvider.notifier).state = resp.userId;
      state = AuthState(status: AuthStatus.authenticated, userId: resp.userId);
    } on GrpcError catch (e) {
      developer.log('[Auth] login: GrpcError code=${e.code} codeName=${e.codeName} message=${e.message}');
      if (e.code == StatusCode.unavailable || e.code == StatusCode.deadlineExceeded) {
        // 网络不通，降级本地
        await _loginLocal(email, password);
      } else {
        // 业务错误（密码错误等），显示实际错误
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: e.message ?? '登录失败: ${e.codeName}',
        );
      }
    } catch (e, st) {
      developer.log('[Auth] login: non-gRPC error: $e\n$st');
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
      state = AuthState(status: AuthStatus.authenticated, userId: user.id, isOfflineMode: true);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: '登录失败: $e',
      );
    }
  }

  Future<void> logout() async {
    // Clear local database
    await _db.clearAllData();
    // Clear preferences
    await _prefs.remove(AppConstants.userIdKey);
    await _prefs.remove(AppConstants.accessTokenKey);
    await _prefs.remove(AppConstants.refreshTokenKey);
    await _prefs.remove(AppConstants.familyIdKey);
    _ref.read(currentUserIdProvider.notifier).state = null;
    _ref.read(currentFamilyIdProvider.notifier).state = null;
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

      // 同步服务端账户到本地（新用户服务端会自动创建默认账户）
      try {
        final accClient = _ref.read(accountClientProvider);
        final accResp = await accClient.listAccounts(acc_pb.ListAccountsRequest());
        for (final a in accResp.accounts) {
          await _db.into(_db.accounts).insertOnConflictUpdate(
            AccountsCompanion.insert(
              id: a.id,
              userId: a.userId,
              name: a.name,
              balance: Value(a.balance.toInt()),
              icon: Value(a.icon),
              currency: Value(a.currency),
              accountType: Value(AccountTypeHelper.fromProto(a.type)),
              isActive: Value(a.isActive),
            ),
          );
        }
      } catch (_) {
        // Fallback: create minimal local account if server unreachable
        if (resp.isNewUser) {
          final fallbackId = const Uuid().v4();
          await _db.insertAccount(AccountsCompanion.insert(
            id: fallbackId,
            userId: resp.userId,
            name: '默认账户',
          ));
        }
      }

      // 同步服务端分类到本地（含子分类）
      await _syncCategoriesToLocal();

      // 最后设置 userId 触发 UI rebuild
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

  /// Sync categories from server to local DB, including children (subcategories)
  Future<void> _syncCategoriesToLocal() async {
    try {
      final txnClient = _ref.read(transactionClientProvider);
      final catResp = await txnClient.getCategories(txn_pb.GetCategoriesRequest());
      await (_db.delete(_db.categories)..where((c) => c.isPreset.equals(true))).go();
      for (final c in catResp.categories) {
        await _insertCategoryRecursive(c, null);
      }
    } catch (_) {}
  }

  Future<void> _insertCategoryRecursive(txn_pb.Category c, String? parentId) async {
    final typeStr = c.type == txn_enum.TransactionType.TRANSACTION_TYPE_INCOME ? 'income' : 'expense';
    await _db.into(_db.categories).insertOnConflictUpdate(
      CategoriesCompanion.insert(
        id: c.id,
        name: c.name,
        icon: c.icon,
        type: typeStr,
        isPreset: const Value(true),
        sortOrder: Value(c.sortOrder),
        parentId: Value(parentId ?? (c.parentId.isNotEmpty ? c.parentId : null)),
        iconKey: Value(c.iconKey),
      ),
    );
    // Recursively insert children
    for (final child in c.children) {
      await _insertCategoryRecursive(child, c.id);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final db = ref.watch(databaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final authClient = ref.watch(authClientProvider);
  return AuthNotifier(db, prefs, ref, authClient);
});
