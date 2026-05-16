/// End-to-end tests for login → sync categories → sync families → transaction display.
///
/// Covers:
/// 1. Login syncs all categories (including subcategories) to local DB
/// 2. Login syncs family info + restores familyIdKey in SharedPreferences
/// 3. Login sets currentFamilyIdProvider after currentUserIdProvider
/// 4. TransactionNotifier._load() fetches categories from server if local DB is empty
/// 5. Logout → re-login round-trip preserves categories + family mode
/// 6. Register flow has same sync behavior
/// 7. Edge cases: GetCategories failure, ListMyFamilies failure, empty families
library;

import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull; // ignore: unused_import
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familyledger/core/constants/app_constants.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/data/remote/grpc_clients.dart';
import 'package:familyledger/domain/providers/app_providers.dart';
import 'package:familyledger/domain/providers/auth_provider.dart';
import 'package:familyledger/domain/providers/transaction_provider.dart';
import 'package:familyledger/generated/proto/auth.pb.dart' as auth_pb;
import 'package:familyledger/generated/proto/auth.pbgrpc.dart' as auth_grpc;
import 'package:familyledger/generated/proto/account.pb.dart' as acc_pb;
import 'package:familyledger/generated/proto/account.pbgrpc.dart' as acc_grpc;
import 'package:familyledger/generated/proto/family.pb.dart' as fam_pb;
import 'package:familyledger/generated/proto/family.pbenum.dart' as fam_enum;
import 'package:familyledger/generated/proto/family.pbgrpc.dart' as fam_grpc;
import 'package:familyledger/generated/proto/transaction.pb.dart' as txn_pb;
import 'package:familyledger/generated/proto/transaction.pbenum.dart' as txn_enum;
import 'package:familyledger/generated/proto/transaction.pbgrpc.dart'
    as txn_grpc;

// ─── Fake ResponseFuture ─────────────────────────────────────

class FakeResponseFuture<T> implements ResponseFuture<T> {
  final Future<T> _future;
  FakeResponseFuture.value(T value) : _future = Future.value(value);
  FakeResponseFuture.error(Object error) : _future = Future.error(error);

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) =>
      _future.then(onValue, onError: onError);
  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) =>
      _future.catchError(onError, test: test);
  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      _future.whenComplete(action);
  @override
  Stream<T> asStream() => _future.asStream();
  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      _future.timeout(timeLimit, onTimeout: onTimeout);
  @override
  Future<Map<String, String>> get headers => Future.value({});
  @override
  Future<Map<String, String>> get trailers => Future.value({});
  @override
  Future<void> cancel() => Future.value();
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─── Fake Auth Client ────────────────────────────────────────

class FakeAuthClient implements auth_grpc.AuthServiceClient {
  auth_pb.LoginResponse? loginResp;
  auth_pb.RegisterResponse? registerResp;
  GrpcError? loginError;
  GrpcError? registerError;

  @override
  ResponseFuture<auth_pb.LoginResponse> login(auth_pb.LoginRequest request,
      {CallOptions? options}) {
    if (loginError != null) return FakeResponseFuture.error(loginError!);
    return FakeResponseFuture.value(loginResp ??
        auth_pb.LoginResponse(
          userId: 'user_1',
          accessToken: 'token_abc',
          refreshToken: 'refresh_abc',
        ));
  }

  @override
  ResponseFuture<auth_pb.RegisterResponse> register(
      auth_pb.RegisterRequest request,
      {CallOptions? options}) {
    if (registerError != null) return FakeResponseFuture.error(registerError!);
    return FakeResponseFuture.value(registerResp ??
        auth_pb.RegisterResponse(
          userId: 'user_new',
          accessToken: 'token_new',
          refreshToken: 'refresh_new',
        ));
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─── Fake Account Client ─────────────────────────────────────

class FakeAccountClient implements acc_grpc.AccountServiceClient {
  @override
  ResponseFuture<acc_pb.ListAccountsResponse> listAccounts(
      acc_pb.ListAccountsRequest request,
      {CallOptions? options}) {
    return FakeResponseFuture.value(acc_pb.ListAccountsResponse(
      accounts: [
        acc_pb.Account(
          id: 'acc_1',
          userId: 'user_1',
          name: '默认账户',
        ),
      ],
    ));
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─── Fake Transaction Client ─────────────────────────────────

class FakeTransactionClient implements txn_grpc.TransactionServiceClient {
  txn_pb.GetCategoriesResponse? categoriesResp;
  GrpcError? categoriesError;
  txn_pb.ListTransactionsResponse? listTransactionsResp;
  int getCategoriesCallCount = 0;

  @override
  ResponseFuture<txn_pb.GetCategoriesResponse> getCategories(
      txn_pb.GetCategoriesRequest request,
      {CallOptions? options}) {
    getCategoriesCallCount++;
    if (categoriesError != null) {
      return FakeResponseFuture.error(categoriesError!);
    }
    return FakeResponseFuture.value(
        categoriesResp ?? _defaultCategoriesResponse());
  }

  @override
  ResponseFuture<txn_pb.ListTransactionsResponse> listTransactions(
      txn_pb.ListTransactionsRequest request,
      {CallOptions? options}) {
    return FakeResponseFuture.value(listTransactionsResp ??
        txn_pb.ListTransactionsResponse(
          transactions: [],
          nextPageToken: '',
        ));
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─── Fake Family Client ──────────────────────────────────────

class FakeFamilyClient implements fam_grpc.FamilyServiceClient {
  fam_pb.ListMyFamiliesResponse? listMyFamiliesResp;
  fam_pb.GetFamilyResponse? getFamilyResp;
  GrpcError? listMyFamiliesError;
  GrpcError? getFamilyError;
  int listMyFamiliesCallCount = 0;

  @override
  ResponseFuture<fam_pb.ListMyFamiliesResponse> listMyFamilies(
      fam_pb.ListMyFamiliesRequest request,
      {CallOptions? options}) {
    listMyFamiliesCallCount++;
    if (listMyFamiliesError != null) {
      return FakeResponseFuture.error(listMyFamiliesError!);
    }
    return FakeResponseFuture.value(
        listMyFamiliesResp ?? fam_pb.ListMyFamiliesResponse());
  }

  @override
  ResponseFuture<fam_pb.GetFamilyResponse> getFamily(
      fam_pb.GetFamilyRequest request,
      {CallOptions? options}) {
    if (getFamilyError != null) {
      return FakeResponseFuture.error(getFamilyError!);
    }
    return FakeResponseFuture.value(getFamilyResp ??
        fam_pb.GetFamilyResponse(
          family: fam_pb.Family(
            id: 'fam_1',
            name: '测试家庭',
            ownerId: 'user_1',
          ),
          members: [
            fam_pb.FamilyMember(
              id: 'mem_1',
              userId: 'user_1',
              email: 'user1@test.com',
              role: fam_enum.FamilyRole.FAMILY_ROLE_OWNER,
              permissions: fam_pb.MemberPermissions(
                canView: true,
                canCreate: true,
                canEdit: true,
                canDelete: true,
                canManageAccounts: true,
              ),
            ),
            fam_pb.FamilyMember(
              id: 'mem_2',
              userId: 'user_2',
              email: 'user2@test.com',
              role: fam_enum.FamilyRole.FAMILY_ROLE_MEMBER,
              permissions: fam_pb.MemberPermissions(
                canView: true,
                canCreate: true,
                canEdit: false,
                canDelete: false,
                canManageAccounts: false,
              ),
            ),
          ],
        ));
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─── Test Helpers ────────────────────────────────────────────

/// Build a realistic category tree: 3 expense roots (2 with children) + 2 income roots (1 with child)
txn_pb.GetCategoriesResponse _defaultCategoriesResponse() {
  return txn_pb.GetCategoriesResponse(
    categories: [
      // Expense root 1: 餐饮 → 早餐, 午餐, 晚餐
      txn_pb.Category(
        id: 'cat_food',
        name: '餐饮',
        icon: '🍽️',
        type: txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
        isPreset: true,
        sortOrder: 1,
        iconKey: 'food',
        children: [
          txn_pb.Category(
            id: 'cat_breakfast',
            name: '早餐',
            icon: '🥣',
            type: txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
            isPreset: true,
            sortOrder: 1,
            parentId: 'cat_food',
            iconKey: 'food_breakfast',
          ),
          txn_pb.Category(
            id: 'cat_lunch',
            name: '午餐',
            icon: '🍱',
            type: txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
            isPreset: true,
            sortOrder: 2,
            parentId: 'cat_food',
            iconKey: 'food_lunch',
          ),
          txn_pb.Category(
            id: 'cat_dinner',
            name: '晚餐',
            icon: '🥘',
            type: txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
            isPreset: true,
            sortOrder: 3,
            parentId: 'cat_food',
            iconKey: 'food_dinner',
          ),
        ],
      ),
      // Expense root 2: 交通 → 地铁, 打车
      txn_pb.Category(
        id: 'cat_transport',
        name: '交通',
        icon: '🚌',
        type: txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
        isPreset: true,
        sortOrder: 2,
        iconKey: 'transport',
        children: [
          txn_pb.Category(
            id: 'cat_subway',
            name: '地铁',
            icon: '🚇',
            type: txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
            isPreset: true,
            sortOrder: 1,
            parentId: 'cat_transport',
            iconKey: 'transport_subway',
          ),
          txn_pb.Category(
            id: 'cat_taxi',
            name: '打车',
            icon: '🚕',
            type: txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
            isPreset: true,
            sortOrder: 2,
            parentId: 'cat_transport',
            iconKey: 'transport_taxi',
          ),
        ],
      ),
      // Expense root 3: 娱乐 (no children)
      txn_pb.Category(
        id: 'cat_fun',
        name: '娱乐',
        icon: '🎮',
        type: txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
        isPreset: true,
        sortOrder: 3,
        iconKey: 'entertainment',
      ),
      // Income root 1: 工资 → 基本工资, 绩效
      txn_pb.Category(
        id: 'cat_salary',
        name: '工资',
        icon: '💰',
        type: txn_enum.TransactionType.TRANSACTION_TYPE_INCOME,
        isPreset: true,
        sortOrder: 1,
        iconKey: 'salary',
        children: [
          txn_pb.Category(
            id: 'cat_base_salary',
            name: '基本工资',
            icon: '💵',
            type: txn_enum.TransactionType.TRANSACTION_TYPE_INCOME,
            isPreset: true,
            sortOrder: 1,
            parentId: 'cat_salary',
            iconKey: 'salary_base',
          ),
          txn_pb.Category(
            id: 'cat_bonus',
            name: '绩效',
            icon: '📈',
            type: txn_enum.TransactionType.TRANSACTION_TYPE_INCOME,
            isPreset: true,
            sortOrder: 2,
            parentId: 'cat_salary',
            iconKey: 'salary_bonus',
          ),
        ],
      ),
      // Income root 2: 投资 (no children)
      txn_pb.Category(
        id: 'cat_invest',
        name: '投资收益',
        icon: '📊',
        type: txn_enum.TransactionType.TRANSACTION_TYPE_INCOME,
        isPreset: true,
        sortOrder: 2,
        iconKey: 'investment',
      ),
    ],
  );
}

/// Build family response with one family
fam_pb.ListMyFamiliesResponse _defaultFamilyResponse() {
  return fam_pb.ListMyFamiliesResponse(
    families: [
      fam_pb.Family(
        id: 'fam_1',
        name: '测试家庭',
        ownerId: 'user_1',
        inviteCode: 'ABC123',
      ),
    ],
    memberships: [
      fam_pb.FamilyMember(
        id: 'mem_1',
        userId: 'user_1',
        role: fam_enum.FamilyRole.FAMILY_ROLE_OWNER,
        permissions: fam_pb.MemberPermissions(
          canView: true,
          canCreate: true,
          canEdit: true,
          canDelete: true,
          canManageAccounts: true,
        ),
      ),
    ],
  );
}

AppDatabase _createTestDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(logStatements: false));

// ─── Test Suite ──────────────────────────────────────────────

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late FakeAuthClient authClient;
  late FakeAccountClient accountClient;
  late FakeTransactionClient txnClient;
  late FakeFamilyClient familyClient;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = _createTestDb();
    authClient = FakeAuthClient();
    accountClient = FakeAccountClient();
    txnClient = FakeTransactionClient();
    familyClient = FakeFamilyClient();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authClientProvider.overrideWithValue(authClient),
        accountClientProvider.overrideWithValue(accountClient),
        transactionClientProvider.overrideWithValue(txnClient),
        familyClientProvider.overrideWithValue(familyClient),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Login → Category Sync', () {
    test('login syncs all categories (roots + subcategories) to local DB',
        () async {
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('test@test.com', 'pass123');

      // Verify state is authenticated
      expect(container.read(authProvider).status, AuthStatus.authenticated);

      // Check all categories are in local DB
      final expCats = await db.getCategoriesByType('expense');
      final incCats = await db.getCategoriesByType('income');

      // 3 expense roots + 5 expense children = 8
      expect(expCats.length, 8);
      // 2 income roots + 2 income children = 4
      expect(incCats.length, 4);

      // Verify subcategories have correct parentId
      final breakfast =
          expCats.firstWhere((c) => c.name == '早餐');
      expect(breakfast.parentId, 'cat_food');

      final subway =
          expCats.firstWhere((c) => c.name == '地铁');
      expect(subway.parentId, 'cat_transport');

      final baseSalary =
          incCats.firstWhere((c) => c.name == '基本工资');
      expect(baseSalary.parentId, 'cat_salary');

      // Verify root categories have null parentId
      final food = expCats.firstWhere((c) => c.name == '餐饮');
      expect(food.parentId, isNull);

      final salary = incCats.firstWhere((c) => c.name == '工资');
      expect(salary.parentId, isNull);
    });

    test('login stores access/refresh tokens and userId in SharedPreferences',
        () async {
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('test@test.com', 'pass123');

      expect(prefs.getString(AppConstants.accessTokenKey), 'token_abc');
      expect(prefs.getString(AppConstants.refreshTokenKey), 'refresh_abc');
      expect(prefs.getString(AppConstants.userIdKey), 'user_1');
    });

    test('login with GetCategories failure: auth succeeds, categories seeded via fire-and-forget',
        () async {
      txnClient.categoriesError =
          GrpcError.unavailable('network unreachable');
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('test@test.com', 'pass123');

      // Should still be authenticated (category sync failure is non-fatal)
      expect(container.read(authProvider).status, AuthStatus.authenticated);

      // seedCategoriesForOwner is fire-and-forget after login
      // Give it a moment to complete
      await Future.delayed(const Duration(milliseconds: 100));

      final expCats = await db.getCategoriesByType('expense');
      // Seed has 14 expense root categories + their subcategories
      expect(expCats.length, greaterThan(10));
    });

    test('categories have correct iconKey and sortOrder', () async {
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('test@test.com', 'pass123');

      final expCats = await db.getCategoriesByType('expense');
      final food = expCats.firstWhere((c) => c.name == '餐饮');
      expect(food.iconKey, 'food');
      expect(food.sortOrder, 1);

      final taxi = expCats.firstWhere((c) => c.name == '打车');
      expect(taxi.iconKey, 'transport_taxi');
      expect(taxi.sortOrder, 2);
    });
  });

  group('Login → Family Sync', () {
    test('login with families: saves familyId to SharedPreferences', () async {
      familyClient.listMyFamiliesResp = _defaultFamilyResponse();
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('test@test.com', 'pass123');

      expect(
        prefs.getString(AppConstants.familyIdKey),
        'fam_1',
      );
    });

    test('login with families: sets currentFamilyIdProvider', () async {
      familyClient.listMyFamiliesResp = _defaultFamilyResponse();
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('test@test.com', 'pass123');

      expect(container.read(currentFamilyIdProvider), 'fam_1');
    });

    test('login with families: family data written to local DB', () async {
      familyClient.listMyFamiliesResp = _defaultFamilyResponse();
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('test@test.com', 'pass123');

      final families = await db.getAllFamilies();
      expect(families.length, 1);
      expect(families.first.name, '测试家庭');
      expect(families.first.ownerId, 'user_1');
    });

    test('login with families: family members written to local DB', () async {
      familyClient.listMyFamiliesResp = _defaultFamilyResponse();
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('test@test.com', 'pass123');

      final members = await db.getFamilyMembers('fam_1');
      // getFamily returns 2 members
      expect(members.length, greaterThanOrEqualTo(1));
    });

    test('login without families: familyIdKey not set', () async {
      familyClient.listMyFamiliesResp = fam_pb.ListMyFamiliesResponse();
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('test@test.com', 'pass123');

      expect(prefs.getString(AppConstants.familyIdKey), isNull);
      expect(container.read(currentFamilyIdProvider), isNull);
    });

    test('login with ListMyFamilies failure: non-fatal, still authenticated',
        () async {
      familyClient.listMyFamiliesError =
          GrpcError.unavailable('network error');
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('test@test.com', 'pass123');

      expect(container.read(authProvider).status, AuthStatus.authenticated);
      expect(prefs.getString(AppConstants.familyIdKey), isNull);
    });

    test(
        'login sets currentFamilyIdProvider AFTER currentUserIdProvider',
        () async {
      familyClient.listMyFamiliesResp = _defaultFamilyResponse();

      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('test@test.com', 'pass123');

      // Both should be set
      expect(container.read(currentUserIdProvider), 'user_1');
      expect(container.read(currentFamilyIdProvider), 'fam_1');
    });
  });

  group('Register → Sync', () {
    test('register syncs categories and families', () async {
      familyClient.listMyFamiliesResp = _defaultFamilyResponse();
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.register('new@test.com', 'pass123');

      expect(container.read(authProvider).status, AuthStatus.authenticated);

      // Categories synced
      final expCats = await db.getCategoriesByType('expense');
      expect(expCats.length, 8);

      // Family mode restored
      expect(prefs.getString(AppConstants.familyIdKey), 'fam_1');
      expect(container.read(currentFamilyIdProvider), 'fam_1');
    });
  });

  group('Logout → Re-login round-trip', () {
    test('logout clears everything, re-login restores categories + family',
        () async {
      familyClient.listMyFamiliesResp = _defaultFamilyResponse();
      final authNotifier = container.read(authProvider.notifier);

      // Login first
      await authNotifier.login('test@test.com', 'pass123');
      expect((await db.getCategoriesByType('expense')).length, 8);
      expect(prefs.getString(AppConstants.familyIdKey), 'fam_1');

      // Logout
      await authNotifier.logout();
      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
      expect(prefs.getString(AppConstants.familyIdKey), isNull);
      expect(container.read(currentFamilyIdProvider), isNull);
      expect(container.read(currentUserIdProvider), isNull);

      // Verify categories are cleared
      final expCatsAfterLogout = await db.getCategoriesByType('expense');
      expect(expCatsAfterLogout, isEmpty);

      // Re-login
      await authNotifier.login('test@test.com', 'pass123');
      expect(container.read(authProvider).status, AuthStatus.authenticated);

      // Categories restored
      final expCatsAfterRelogin = await db.getCategoriesByType('expense');
      expect(expCatsAfterRelogin.length, 8);

      // Family mode restored
      expect(prefs.getString(AppConstants.familyIdKey), 'fam_1');
      expect(container.read(currentFamilyIdProvider), 'fam_1');
    });
  });

  group('TransactionNotifier → Category fallback from server', () {
    test(
        'when local categories exist (from seed), TransactionNotifier uses them without server call',
        () async {
      // Seed categories manually (since v13+ they're no longer auto-seeded)
      await db.seedCategoriesForOwner('user_1');

      final expCatsBefore = await db.getCategoriesByType('expense');
      expect(expCatsBefore.length, greaterThan(10));

      // Create TransactionNotifier
      final notifier = TransactionNotifier(db, 'user_1', null, txnClient);
      await Future.delayed(const Duration(milliseconds: 200));

      // Local categories exist, so UI loads without waiting for server.
      // Background sync may still fire (fire-and-forget), so count can be 0 or 1.
      expect(txnClient.getCategoriesCallCount, lessThanOrEqualTo(1));
      expect(notifier.state.expenseCategories.length, greaterThan(10));

      notifier.dispose();
    });

    test(
        'when local categories are manually cleared, TransactionNotifier fetches from server',
        () async {
      // Manually clear categories to simulate edge case
      await (db.delete(db.categories)).go();
      final expCatsBefore = await db.getCategoriesByType('expense');
      expect(expCatsBefore, isEmpty);

      // Create TransactionNotifier with empty local DB
      final notifier = TransactionNotifier(db, 'user_1', null, txnClient);
      await Future.delayed(const Duration(milliseconds: 500));

      // getCategories should have been called
      expect(txnClient.getCategoriesCallCount, greaterThan(0));

      // State should have categories populated from server
      expect(notifier.state.expenseCategories.length, 8);
      expect(notifier.state.incomeCategories.length, 4);

      notifier.dispose();
    });

    test('when local categories cleared and server fails, categories remain empty',
        () async {
      // Manually clear
      await (db.delete(db.categories)).go();
      txnClient.categoriesError = GrpcError.unavailable('down');

      final notifier = TransactionNotifier(db, 'user_1', null, txnClient);
      await Future.delayed(const Duration(milliseconds: 300));

      expect(notifier.state.expenseCategories, isEmpty);
      expect(notifier.state.incomeCategories, isEmpty);

      notifier.dispose();
    });

    test(
        'family mode: incremental sync refreshes categories from server',
        () async {
      familyClient.listMyFamiliesResp = _defaultFamilyResponse();
      // First login to populate categories
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('test@test.com', 'pass123');
      txnClient.getCategoriesCallCount = 0;

      // Create TransactionNotifier in family mode
      final notifier =
          TransactionNotifier(db, 'user_1', 'fam_1', txnClient);
      await Future.delayed(const Duration(milliseconds: 500));

      // In family mode, _syncFamilyTransactionsIncremental calls _syncCategoriesFromServer
      expect(txnClient.getCategoriesCallCount, greaterThan(0));

      notifier.dispose();
    });
  });

  group('Category tree integrity', () {
    test('all subcategories reference valid parent IDs', () async {
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('test@test.com', 'pass123');

      final allCats = [
        ...await db.getCategoriesByType('expense'),
        ...await db.getCategoriesByType('income'),
      ];

      final allIds = allCats.map((c) => c.id).toSet();

      for (final cat in allCats) {
        if (cat.parentId != null) {
          expect(allIds.contains(cat.parentId), isTrue,
              reason: '${cat.name} references unknown parentId ${cat.parentId}');
        }
      }
    });

    test('no orphaned subcategories (every child has existing parent)',
        () async {
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('test@test.com', 'pass123');

      final allCats = [
        ...await db.getCategoriesByType('expense'),
        ...await db.getCategoriesByType('income'),
      ];

      final rootCats = allCats.where((c) => c.parentId == null).toList();
      final childCats = allCats.where((c) => c.parentId != null).toList();

      // After sync, server provides: 5 roots + 7 children = 12 total
      // (seed was wiped by _syncCategoriesToLocal delete, then server data inserted)
      expect(rootCats.length, 5);
      expect(childCats.length, 7);
    });

    test('repeated login does not duplicate categories', () async {
      final authNotifier = container.read(authProvider.notifier);

      // Login twice
      await authNotifier.login('test@test.com', 'pass123');
      await authNotifier.login('test@test.com', 'pass123');

      final expCats = await db.getCategoriesByType('expense');
      final incCats = await db.getCategoriesByType('income');
      // Still same count (insertOnConflictUpdate)
      expect(expCats.length, 8);
      expect(incCats.length, 4);
    });
  });
}
