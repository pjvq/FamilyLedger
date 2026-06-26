import 'dart:async';
import '../../sync/sync_backend_factory.dart' show syncEnabled;
import 'dart:developer' as dev;

import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network.dart';
import '../../core/utils/input_sanitizer.dart';
import '../../data/local/database.dart';
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/transaction.pbgrpc.dart' as pb;
import '../../generated/proto/transaction.pbenum.dart' as pbe;
import '../../generated/proto/google/protobuf/timestamp.pb.dart' as proto_ts;
import '../../sync/sync_engine.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/category_repository.dart';
import '../interfaces/interfaces.dart';
import '../services/balance_calculator.dart';
import '../services/category_sync_service.dart';
import '../services/offline_sync_queue.dart';
import 'app_providers.dart';

// ─── State ─────────────────────────────────────────────────────────────────

class TransactionState {
  final List<Transaction> transactions;
  final List<Category> expenseCategories;
  final List<Category> incomeCategories;
  final int totalBalance; // cents (CNY)
  final int todayExpense; // cents (CNY)
  final int monthExpense; // cents (CNY)
  final bool isLoading;
  final bool hasMore; // pagination: more pages available
  final String? error;

  const TransactionState({
    this.transactions = const [],
    this.expenseCategories = const [],
    this.incomeCategories = const [],
    this.totalBalance = 0,
    this.todayExpense = 0,
    this.monthExpense = 0,
    this.isLoading = true,
    this.hasMore = true,
    this.error,
  });

  TransactionState copyWith({
    List<Transaction>? transactions,
    List<Category>? expenseCategories,
    List<Category>? incomeCategories,
    int? totalBalance,
    int? todayExpense,
    int? monthExpense,
    bool? isLoading,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) => TransactionState(
    transactions: transactions ?? this.transactions,
    expenseCategories: expenseCategories ?? this.expenseCategories,
    incomeCategories: incomeCategories ?? this.incomeCategories,
    totalBalance: totalBalance ?? this.totalBalance,
    todayExpense: todayExpense ?? this.todayExpense,
    monthExpense: monthExpense ?? this.monthExpense,
    isLoading: isLoading ?? this.isLoading,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : (error ?? this.error),
  );
}

// ─── Notifier ──────────────────────────────────────────────────────────────

/// Thin coordinator that delegates to:
/// - [TransactionRepository] for local persistence + balance
/// - [BalanceCalculator] for summary computations
/// - [CategorySyncService] for remote category sync
/// - [OfflineSyncQueue] for offline operation queueing
///
/// This class owns ONLY:
/// 1. UI state management (TransactionState)
/// 2. Orchestration flow (online-first → fallback to offline queue)
/// 3. Stream subscription to reactive DB changes
///
/// ~200 lines (down from 672) — each concern is independently testable.
class TransactionNotifier extends StateNotifier<TransactionState> {
  final TransactionRepository _repo;
  final IAccountRepository _accountRepo;
  final BalanceCalculator _balanceCalc;
  final OfflineSyncQueue _syncQueue;
  final CategorySyncService? _categorySvc;
  final pb.TransactionServiceClient? _txnClient;
  final String _userId;
  final String? _familyId;

  StreamSubscription? _dbSub;

  /// Page size for transaction loading.
  static const int _pageSize = kTransactionPageSize;

  TransactionNotifier({
    required TransactionRepository repo,
    required IAccountRepository accountRepo,
    required BalanceCalculator balanceCalc,
    required OfflineSyncQueue syncQueue,
    CategorySyncService? categorySvc,
    pb.TransactionServiceClient? txnClient,
    required String userId,
    String? familyId,
  }) : _repo = repo,
       _accountRepo = accountRepo,
       _balanceCalc = balanceCalc,
       _syncQueue = syncQueue,
       _categorySvc = categorySvc,
       _txnClient = txnClient,
       _userId = userId,
       _familyId = familyId,
       super(const TransactionState()) {
    _init();
  }

  /// Convenience constructor for tests that only have a DB and client.
  /// Creates internal dependencies from the DB automatically.
  /// [categoryRepo] allows DI override; defaults to `CategoryRepository(db)`.
  factory TransactionNotifier.fromDb(
    AppDatabase db,
    String userId,
    String? familyId,
    pb.TransactionServiceClient? txnClient, {
    ICategoryRepository? categoryRepo,
  }) {
    final repo = TransactionRepository(db);
    final accountRepo = AccountRepository(db);
    final balanceCalc = BalanceCalculator(repo);
    final syncQueue = OfflineSyncQueue(db);
    CategorySyncService? categorySvc;
    if (txnClient != null && userId.isNotEmpty) {
      categorySvc = CategorySyncService(
        categoryRepo ?? CategoryRepository(db),
        txnClient,
        userId,
      );
    }
    return TransactionNotifier(
      repo: repo,
      accountRepo: accountRepo,
      balanceCalc: balanceCalc,
      syncQueue: syncQueue,
      categorySvc: categorySvc,
      txnClient: txnClient,
      userId: userId,
      familyId: familyId,
    );
  }

  void _init() {
    _dbSub = _repo
        .watchAll(_userId, familyId: _familyId, limit: _pageSize)
        .listen((txns) {
          // Only update from stream when we haven't loaded extra pages.
          // Once loadMore() is called, stream is cancelled to avoid conflicts.
          state = state.copyWith(
            transactions: txns,
            hasMore: txns.length >= _pageSize,
          );
          _refreshSummary();
        });
    _load();
  }

  /// Load more transactions (infinite scroll).
  /// Cancels the reactive stream to avoid state conflicts between
  /// stream-driven first page and manually-appended subsequent pages.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;

    // Cancel stream — from now on, state is manually managed.
    _dbSub?.cancel();
    _dbSub = null;

    try {
      final more = await _repo.getPage(
        _userId,
        familyId: _familyId,
        limit: _pageSize,
        offset: state.transactions.length,
      );
      if (more.isEmpty) {
        state = state.copyWith(hasMore: false);
      } else {
        state = state.copyWith(
          transactions: [...state.transactions, ...more],
          hasMore: more.length >= _pageSize,
        );
      }
    } catch (e) {
      dev.log('loadMore failed: $e', name: 'TransactionNotifier');
    }
  }

  /// Re-subscribe to the first-page watch stream (e.g. after adding a txn).
  /// Resets pagination state.
  void _resubscribeWatch() {
    _dbSub?.cancel();
    _dbSub = _repo
        .watchAll(_userId, familyId: _familyId, limit: _pageSize)
        .listen((txns) {
          state = state.copyWith(
            transactions: txns,
            hasMore: txns.length >= _pageSize,
          );
          _refreshSummary();
        });
  }

  // ─── Load ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      var expCats = await _repo.getCategoriesByType('expense', userId: _userId);
      var incCats = await _repo.getCategoriesByType('income', userId: _userId);

      // If categories are empty, try server sync before showing UI
      if (expCats.isEmpty && incCats.isEmpty && _categorySvc != null) {
        await _categorySvc.syncFromServer();
        expCats = await _repo.getCategoriesByType('expense', userId: _userId);
        incCats = await _repo.getCategoriesByType('income', userId: _userId);
      }

      state = state.copyWith(
        expenseCategories: expCats,
        incomeCategories: incCats,
        isLoading: false,
        clearError: true,
      );
      await _refreshSummary();

      // Background: sync categories (covers newly added remote categories)
      _categorySvc
          ?.syncFromServer()
          .then((_) => _reloadCategories())
          .catchError(
            (Object e, StackTrace st) =>
                dev.log('Background category sync failed: $e', name: 'txn'),
          );

      // Background: incremental sync for family mode
      if (_familyId != null && _familyId.isNotEmpty && _txnClient != null) {
        _syncFamilyTransactionsIncremental();
      }
    } catch (e) {
      dev.log('TransactionNotifier._load failed: $e', name: 'txn');
      state = state.copyWith(isLoading: false, error: '加载交易数据失败');
    }
  }

  Future<void> _reloadCategories() async {
    final expCats = await _repo.getCategoriesByType('expense', userId: _userId);
    final incCats = await _repo.getCategoriesByType('income', userId: _userId);
    state = state.copyWith(
      expenseCategories: expCats,
      incomeCategories: incCats,
    );
  }

  /// Sync categories from server then reload local state.
  /// Use after creating/editing categories via gRPC.
  Future<void> syncAndReloadCategories() async {
    await _categorySvc?.syncFromServer();
    await _reloadCategories();
  }

  Future<void> _refreshSummary() async {
    final summary = await _balanceCalc.compute(_userId);
    state = state.copyWith(
      totalBalance: summary.totalBalance,
      todayExpense: summary.todayExpense,
      monthExpense: summary.monthExpense,
    );
  }

  // ─── Family Incremental Sync ─────────────────────────────────────────

  static const _syncPageSize = 100;
  static const _maxPages = 200;

  /// Pull incremental changes for family transactions from server.
  Future<void> _syncFamilyTransactionsIncremental() async {
    try {
      await _categorySvc?.syncFromServer();

      final lastSync = await _repo.getFamilySyncTime(_familyId!);
      String pageToken = '';
      int pagesFetched = 0;

      do {
        final req = pb.ListTransactionsRequest()
          ..familyId = _familyId
          ..pageSize = _syncPageSize
          ..includeDeleted = true;
        if (lastSync != null) req.updatedSince = _toTimestamp(lastSync);
        if (pageToken.isNotEmpty) req.pageToken = pageToken;

        final resp = await _txnClient!.listTransactions(
          req,
          options: defaultCallOptions,
        );

        final toUpsert = <TransactionUpsertParams>[];
        final toDelete = <String>[];

        for (final t in resp.transactions) {
          if (t.hasDeletedAt()) {
            toDelete.add(t.id);
          } else {
            toUpsert.add(
              TransactionUpsertParams(
                id: t.id,
                userId: t.userId,
                accountId: t.accountId,
                categoryId: t.categoryId,
                amount: t.amount.toInt(),
                amountCny: t.amountCny.toInt(),
                type: t.type == pbe.TransactionType.TRANSACTION_TYPE_INCOME
                    ? 'income'
                    : 'expense',
                note: t.note,
                txnDate: t.txnDate.toDateTime().toLocal(),
              ),
            );
          }
        }

        await _repo.batchUpsertParams(toUpsert);
        await _repo.batchHardDelete(toDelete);

        pageToken = resp.nextPageToken;
        pagesFetched++;
      } while (pageToken.isNotEmpty && pagesFetched < _maxPages);

      await _repo.setFamilySyncTime(_familyId!, DateTime.now());
      dev.log(
        'Family incremental sync done (pages=$pagesFetched)',
        name: 'txn',
      );
    } catch (e) {
      dev.log('Family incremental sync failed: $e', name: 'txn');
    }
  }

  // ─── Public: Reload ──────────────────────────────────────────────────

  Future<void> reload() async {
    state = state.copyWith(isLoading: true, clearError: true);
    _resubscribeWatch();
    if (_familyId != null && _familyId.isNotEmpty) {
      await _repo.clearFamilySyncTime(_familyId);
    }
    await _load();
  }

  // ─── CRUD ────────────────────────────────────────────────────────────

  Future<void> addTransaction({
    required String categoryId,
    required int amount,
    required String type,
    String? accountId,
    String note = '',
    DateTime? txnDate,
    String currency = 'CNY',
    int? amountCny,
    String tags = '',
    String imageUrls = '',
  }) async {
    final cleanNote = sanitizeNote(note);
    final cleanTags = sanitizeTags(tags);
    final cleanImageUrls = sanitizeImageUrls(imageUrls);
    final now = DateTime.now();
    final effectiveAmountCny = amountCny ?? amount;
    final effectiveTxnDate = txnDate ?? now;
    _validateTxnDate(effectiveTxnDate);

    final Account? account;
    if (accountId != null) {
      final existing = await _accountRepo.getById(accountId);
      if (existing == null) {
        throw StateError('指定账户不存在（已被删除？）');
      }
      // Use default account query to get the drift Account type,
      // but override ID below for the gRPC request.
      account = await _repo.getDefaultAccount(_userId, familyId: _familyId);
    } else {
      account = await _repo.getDefaultAccount(_userId, familyId: _familyId);
    }
    if (account == null) throw StateError('无默认账户，请先创建账户');
    // effectiveAccountId: prefer explicitly selected, fall back to default
    final effectiveAccountId = accountId ?? account.id;

    // Online-first: try server to get canonical ID
    String transactionId;
    bool syncedToServer = false;

    if (_txnClient != null) {
      try {
        final req = pb.CreateTransactionRequest()
          ..accountId = effectiveAccountId
          ..categoryId = categoryId
          ..amount = Int64(amount)
          ..currency = currency
          ..amountCny = Int64(effectiveAmountCny)
          ..exchangeRate = amount > 0 ? effectiveAmountCny / amount : 1.0
          ..type = type == 'income'
              ? pbe.TransactionType.TRANSACTION_TYPE_INCOME
              : pbe.TransactionType.TRANSACTION_TYPE_EXPENSE
          ..note = cleanNote
          ..txnDate = _toTimestamp(effectiveTxnDate);
        final resp = await _txnClient.createTransaction(
          req,
          options: defaultCallOptions,
        );
        transactionId = resp.transaction.id;
        syncedToServer = true;
      } catch (e) {
        dev.log(
          'addTransaction: server-first failed, offline mode: $e',
          name: 'txn',
        );
        transactionId = _repo.generateId();
      }
    } else {
      transactionId = _repo.generateId();
    }

    // Persist locally
    await _repo.insertWithBalance(
      id: transactionId,
      userId: _userId,
      accountId: effectiveAccountId,
      categoryId: categoryId,
      amount: amount,
      amountCny: effectiveAmountCny,
      type: type,
      txnDate: effectiveTxnDate,
      note: cleanNote,
      currency: currency,
      tags: cleanTags,
      imageUrls: cleanImageUrls,
    );

    // Queue for sync if offline
    if (!syncedToServer) {
      await _syncQueue.enqueueCreate(
        entityType: 'transaction',
        entityId: transactionId,
        payload: {
          'id': transactionId,
          'account_id': effectiveAccountId,
          'category_id': categoryId,
          'amount': amount,
          'currency': currency,
          'amount_cny': effectiveAmountCny,
          'exchange_rate': amount > 0 ? effectiveAmountCny / amount : 1.0,
          'type': type,
          'note': cleanNote,
          'txn_date': effectiveTxnDate.toUtc().toIso8601String(),
        },
      );
    }
  }

  Future<void> updateTransaction({
    required String id,
    String? categoryId,
    int? amount,
    String? type,
    String? note,
    String? currency,
    int? amountCny,
    String? tags,
    String? imageUrls,
    DateTime? txnDate,
    String? accountId,
  }) async {
    if (txnDate != null) _validateTxnDate(txnDate);

    final cleanNote = note != null ? sanitizeNote(note) : null;
    final cleanTags = tags != null ? sanitizeTags(tags) : null;
    final cleanImageUrls = imageUrls != null
        ? sanitizeImageUrls(imageUrls)
        : null;

    final oldTxn = await _repo.update(
      id: id,
      categoryId: categoryId,
      amount: amount,
      amountCny: amountCny,
      type: type,
      note: cleanNote,
      currency: currency,
      tags: cleanTags,
      imageUrls: cleanImageUrls,
      txnDate: txnDate,
      accountId: accountId,
    );
    if (oldTxn == null) return;

    // Try server
    try {
      if (_txnClient != null) {
        final req = pb.UpdateTransactionRequest(transactionId: id);
        if (amount != null) req.amount = Int64(amount);
        if (categoryId != null) req.categoryId = categoryId;
        if (cleanNote != null) req.note = cleanNote;
        if (cleanTags != null) req.tags = cleanTags;
        if (currency != null) req.currency = currency;
        if (type != null) {
          req.type = type == 'income'
              ? pbe.TransactionType.TRANSACTION_TYPE_INCOME
              : pbe.TransactionType.TRANSACTION_TYPE_EXPENSE;
        }
        if (txnDate != null) req.txnDate = _toTimestamp(txnDate);
        await _txnClient.updateTransaction(req);
      }
    } catch (e) {
      dev.log('updateTransaction: gRPC failed, queueing: $e', name: 'txn');
      await _syncQueue.enqueueUpdate(
        entityType: 'transaction',
        entityId: id,
        payload: {
          'id': id,
          if (categoryId != null) 'category_id': categoryId,
          if (amount != null) 'amount': amount,
          if (amountCny != null) 'amount_cny': amountCny,
          if (currency != null) 'currency': currency,
          if (type != null) 'type': type,
          if (cleanNote != null) 'note': cleanNote,
          if (cleanTags != null) 'tags': cleanTags,
          if (txnDate != null) 'txn_date': txnDate.toUtc().toIso8601String(),
          if (accountId != null) 'account_id': accountId,
        },
      );
    }

    await _refreshSummary();
  }

  Future<void> deleteTransaction(String id) async {
    final txn = await _repo.softDeleteWithBalance(id);
    if (txn == null) return;

    try {
      if (_txnClient != null) {
        await _txnClient.deleteTransaction(
          pb.DeleteTransactionRequest(transactionId: id),
        );
      }
    } catch (e) {
      dev.log('deleteTransaction: gRPC failed, queueing: $e', name: 'txn');
      await _syncQueue.enqueueDelete(entityType: 'transaction', entityId: id);
    }

    await _refreshSummary();
  }

  Future<int> batchDeleteTransactions(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final count = await _repo.batchSoftDelete(ids);

    try {
      if (_txnClient != null) {
        await _txnClient.batchDeleteTransactions(
          pb.BatchDeleteTransactionsRequest(transactionIds: ids),
        );
      }
    } catch (e) {
      dev.log('batchDelete: gRPC failed, queueing: $e', name: 'txn');
      await _syncQueue.enqueueBatchDelete(
        entityType: 'transaction',
        entityIds: ids,
      );
    }

    await _refreshSummary();
    return count;
  }

  /// Upload image to server. Returns server URL or null on failure.
  Future<String?> uploadImage(pb.UploadTransactionImageRequest req) async {
    try {
      if (_txnClient != null) {
        final resp = await _txnClient.uploadTransactionImage(req);
        return resp.imageUrl;
      }
    } catch (e) {
      dev.log('uploadImage failed: $e', name: 'txn');
    }
    return null;
  }

  @override
  void dispose() {
    _dbSub?.cancel();
    super.dispose();
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────

void _validateTxnDate(DateTime txnDate) {
  final earliest = DateTime.utc(2000);
  final latest = DateTime.now().toUtc().add(const Duration(days: 1));
  final utc = txnDate.toUtc();
  if (utc.isBefore(earliest) || utc.isAfter(latest)) {
    throw ArgumentError('txnDate out of range: ${utc.toIso8601String()}');
  }
}

proto_ts.Timestamp _toTimestamp(DateTime dt) {
  final ms = dt.millisecondsSinceEpoch;
  return proto_ts.Timestamp()
    ..seconds = Int64(ms ~/ 1000)
    ..nanos = (ms % 1000) * 1000000;
}

// ─── Provider Wiring ───────────────────────────────────────────────────────

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionRepository(db);
});

final balanceCalculatorProvider = Provider<BalanceCalculator>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return BalanceCalculator(repo);
});

final offlineSyncQueueProvider = Provider<OfflineSyncQueue>((ref) {
  final db = ref.watch(databaseProvider);
  final queue = OfflineSyncQueue(db);
  ref.onDispose(() => queue.dispose());
  return queue;
});

final transactionProvider =
    StateNotifierProvider<TransactionNotifier, TransactionState>((ref) {
      final repo = ref.watch(transactionRepositoryProvider);
      final accountRepo = ref.watch(accountRepositoryProvider);
      final balanceCalc = ref.watch(balanceCalculatorProvider);
      final syncQueue = ref.watch(offlineSyncQueueProvider);
      final userId = ref.watch(currentUserIdProvider);
      final familyId = ref.watch(currentFamilyIdProvider);

      pb.TransactionServiceClient? txnClient;
      try {
        txnClient = (syncEnabled ? ref.watch(transactionClientProvider) : null);
      } catch (_) {}

      CategorySyncService? categorySvc;
      if (txnClient != null && userId != null) {
        final categoryRepo = ref.watch(categoryRepositoryProvider);
        categorySvc = CategorySyncService(categoryRepo, txnClient, userId);
      }

      if (userId == null) {
        return TransactionNotifier(
          repo: repo,
          accountRepo: accountRepo,
          balanceCalc: balanceCalc,
          syncQueue: syncQueue,
          userId: '',
          familyId: null,
        );
      }

      final notifier = TransactionNotifier(
        repo: repo,
        accountRepo: accountRepo,
        balanceCalc: balanceCalc,
        syncQueue: syncQueue,
        categorySvc: categorySvc,
        txnClient: txnClient,
        userId: userId,
        familyId: familyId,
      );

      // Forward sync queue notifications to SyncEngine
      StreamSubscription<void>? syncSub;
      syncSub = syncQueue.onEnqueued.listen((_) {
        try {
          final engine = ref.read(syncEngineProvider);
          unawaited(
            engine.syncNow().catchError(
              (Object e, StackTrace st) =>
                  dev.log('SyncEngine.syncNow() failed: $e', name: 'txn'),
            ),
          );
        } on StateError catch (_) {}
      });
      ref.onDispose(() => syncSub?.cancel());

      return notifier;
    });

/// Recent transactions (last 5) — derived provider with stable identity.
///
/// Compares the first 5 transaction IDs to avoid unnecessary rebuilds
/// when the full list reference changes but the recent items are the same.
final recentTransactionsProvider = Provider<List<Transaction>>((ref) {
  final allTxns = ref.watch(transactionProvider.select((s) => s.transactions));
  if (allTxns.length <= 5) return allTxns;
  return allTxns.sublist(0, 5);
}, dependencies: [transactionProvider]);

/// Selector that extracts only the IDs of recent transactions.
/// Widgets that only care about whether the recent list changed
/// can watch this for a cheap equality check.
final recentTransactionIdsProvider = Provider<List<String>>((ref) {
  final recent = ref.watch(recentTransactionsProvider);
  return recent.map((t) => t.id).toList();
});
