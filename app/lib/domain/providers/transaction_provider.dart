import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';
import '../../generated/proto/google/protobuf/timestamp.pb.dart'
    as proto_ts;
import '../../data/local/database.dart';
import 'package:grpc/grpc.dart';
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/transaction.pbgrpc.dart' as pb;
import '../../generated/proto/transaction.pbenum.dart' as pbe;
import 'app_providers.dart';

class TransactionState {
  final List<Transaction> transactions;
  final List<Category> expenseCategories;
  final List<Category> incomeCategories;
  final int totalBalance; // 分
  final int todayExpense; // 分
  final int monthExpense; // 分
  final bool isLoading;
  final String? error;

  const TransactionState({
    this.transactions = const [],
    this.expenseCategories = const [],
    this.incomeCategories = const [],
    this.totalBalance = 0,
    this.todayExpense = 0,
    this.monthExpense = 0,
    this.isLoading = true,
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
    String? error,
    bool clearError = false,
  }) =>
      TransactionState(
        transactions: transactions ?? this.transactions,
        expenseCategories: expenseCategories ?? this.expenseCategories,
        incomeCategories: incomeCategories ?? this.incomeCategories,
        totalBalance: totalBalance ?? this.totalBalance,
        todayExpense: todayExpense ?? this.todayExpense,
        monthExpense: monthExpense ?? this.monthExpense,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class TransactionNotifier extends StateNotifier<TransactionState> {
  final AppDatabase _db;
  final String _userId;
  final String? _familyId;
  final pb.TransactionServiceClient? _txnClient;
  final _uuid = const Uuid();
  StreamSubscription? _sub;
  static final _callOpts = CallOptions(timeout: const Duration(seconds: 5));

  TransactionNotifier(this._db, this._userId, this._familyId, this._txnClient)
      : super(const TransactionState()) {
    _load();
    _sub = _db.watchTransactions(_userId, familyId: _familyId).listen((txns) {
      state = state.copyWith(transactions: txns);
      _refreshSummary();
    });
  }

  /// Page size for paginated family transaction sync
  static const _syncPageSize = 100;

  /// Maximum pages to fetch to prevent infinite loops
  static const _maxPages = 200;

  Future<void> _load() async {
    try {
      // Load categories first (fast, local only)
      var expCats = await _db.getCategoriesByType('expense');
      var incCats = await _db.getCategoriesByType('income');

      // If local categories are empty, fetch from server before showing UI
      if (expCats.isEmpty && incCats.isEmpty && _txnClient != null) {
        await _syncCategoriesFromServer();
        expCats = await _db.getCategoriesByType('expense');
        incCats = await _db.getCategoriesByType('income');
      }

      state = state.copyWith(
        expenseCategories: expCats,
        incomeCategories: incCats,
        clearError: true,
      );
      await _refreshSummary();
      // Show local data immediately — don't block on network
      state = state.copyWith(isLoading: false);

      // Background incremental sync for family mode
      if (_familyId != null && _familyId.isNotEmpty && _txnClient != null) {
        _syncFamilyTransactionsIncremental();
      }
    } catch (e) {
      dev.log('TransactionNotifier: _load failed: $e', name: 'txn');
      state = state.copyWith(
        isLoading: false,
        error: '加载交易数据失败',
      );
    }
  }

  /// Incremental sync: only fetch records updated after last sync time.
  /// Includes tombstones (deleted records) so local DB stays consistent.
  Future<void> _syncFamilyTransactionsIncremental() async {
    try {
      // Refresh categories first — other members may have created new ones
      await _syncCategoriesFromServer();

      final lastSync = await _db.getFamilySyncTime(_familyId!);
      String pageToken = '';
      int pagesFetched = 0;

      do {
        final req = pb.ListTransactionsRequest()
          ..familyId = _familyId
          ..pageSize = _syncPageSize
          ..includeDeleted = true;
        if (lastSync != null) {
          req.updatedSince = _toTimestamp(lastSync);
        }
        if (pageToken.isNotEmpty) {
          req.pageToken = pageToken;
        }

        final resp = await _txnClient!.listTransactions(
          req,
          options: _callOpts,
        );

        // Separate alive records from tombstones
        final toUpsert = <pb.Transaction>[];
        final toDelete = <String>[];

        for (final t in resp.transactions) {
          if (t.hasDeletedAt()) {
            toDelete.add(t.id);
          } else {
            toUpsert.add(t);
          }
        }

        // Batch upsert alive records
        if (toUpsert.isNotEmpty) {
          await _db.batchUpsertTransactions(
            toUpsert.map((t) => _protoToUpsertParams(t)).toList(),
          );
        }

        // Batch hard-delete tombstones locally
        if (toDelete.isNotEmpty) {
          await _db.batchHardDeleteTransactions(toDelete);
        }

        pageToken = resp.nextPageToken;
        pagesFetched++;
      } while (pageToken.isNotEmpty && pagesFetched < _maxPages);

      // Record sync timestamp
      await _db.setFamilySyncTime(_familyId, DateTime.now());
      dev.log('TransactionNotifier: incremental sync done (pages=$pagesFetched)',
          name: 'txn');
    } catch (e) {
      // Offline or timeout — no-op, local data is still shown
      dev.log('TransactionNotifier: incremental sync failed: $e', name: 'txn');
    }
  }

  /// Refresh categories from server (all levels)
  Future<void> _syncCategoriesFromServer() async {
    try {
      if (_txnClient == null) return;
      final resp = await _txnClient.getCategories(
        pb.GetCategoriesRequest(),
        options: _callOpts,
      );
      for (final c in resp.categories) {
        await _insertCategoryRecursive(c, null);
      }
      // Refresh local state
      final expCats = await _db.getCategoriesByType('expense');
      final incCats = await _db.getCategoriesByType('income');
      state = state.copyWith(
        expenseCategories: expCats,
        incomeCategories: incCats,
      );
    } catch (_) {}
  }

  Future<void> _insertCategoryRecursive(pb.Category c, String? parentId) async {
    final typeStr = c.type == pbe.TransactionType.TRANSACTION_TYPE_INCOME
        ? 'income'
        : 'expense';
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
    for (final child in c.children) {
      await _insertCategoryRecursive(child, c.id);
    }
  }

  /// Convert a proto Transaction to upsert parameters
  _TransactionUpsertParams _protoToUpsertParams(pb.Transaction t) {
    return _TransactionUpsertParams(
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
    );
  }

  /// Public reload — for retry on error or pull-to-refresh.
  /// Does full sync (updatedSince=null) to guarantee consistency.
  Future<void> reload() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Reset sync time to force full re-sync
      if (_familyId != null && _familyId.isNotEmpty) {
        await _db.clearFamilySyncTime(_familyId);
      }
      await _load();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '刷新失败');
    }
  }

  Future<void> _refreshSummary() async {
    final balance = await _db.getTotalBalance(_userId);
    final today = await _db.getTodayExpense(_userId);
    final month = await _db.getMonthExpense(_userId);
    state = state.copyWith(
      totalBalance: balance,
      todayExpense: today,
      monthExpense: month,
    );
  }

  /// 添加交易 — 在线时先获取服务端 ID，避免 delete+re-insert 闪烁
  Future<void> addTransaction({
    required String categoryId,
    required int amount, // 分
    required String type, // 'income' | 'expense'
    String note = '',
    DateTime? txnDate,
    String currency = 'CNY',
    int? amountCny,
    String tags = '',
    String imageUrls = '',
  }) async {
    final now = DateTime.now();
    final account = await _db.getDefaultAccount(_userId, familyId: _familyId);
    if (account == null) {
      throw StateError('无默认账户，请先创建账户');
    }

    final effectiveAmountCny = amountCny ?? amount;
    final effectiveTxnDate = txnDate ?? now;

    // Try server-first approach to avoid ID mismatch flicker
    String transactionId;
    bool syncedToServer = false;

    if (_txnClient != null) {
      try {
        final req = pb.CreateTransactionRequest()
          ..accountId = account.id
          ..categoryId = categoryId
          ..amount = Int64(amount)
          ..currency = currency
          ..amountCny = Int64(effectiveAmountCny)
          ..exchangeRate = amount > 0 ? effectiveAmountCny / amount : 1.0
          ..type = type == 'income'
              ? pbe.TransactionType.TRANSACTION_TYPE_INCOME
              : pbe.TransactionType.TRANSACTION_TYPE_EXPENSE
          ..note = note
          ..txnDate = _toTimestamp(effectiveTxnDate);
        final resp = await _txnClient.createTransaction(req, options: _callOpts);
        // Use server-assigned ID directly — no delete+re-insert needed
        transactionId = resp.transaction.id;
        syncedToServer = true;
      } catch (e) {
        // Server unavailable — fall through to offline mode
        dev.log('TransactionNotifier: server-first create failed, using local ID: $e', name: 'txn');
        transactionId = _uuid.v4();
      }
    } else {
      transactionId = _uuid.v4();
    }

    // Insert into local DB with the final ID (either server-assigned or local UUID)
    final companion = TransactionsCompanion.insert(
      id: transactionId,
      userId: _userId,
      accountId: account.id,
      categoryId: categoryId,
      amount: amount,
      amountCny: effectiveAmountCny,
      type: type,
      note: Value(note),
      tags: Value(tags),
      imageUrls: Value(imageUrls),
      txnDate: effectiveTxnDate,
    );
    await _db.insertTransaction(companion);

    // Update account balance (始终用人民币计)
    final delta = type == 'income' ? effectiveAmountCny : -effectiveAmountCny;
    await _db.updateAccountBalance(account.id, delta);

    // If offline, queue for later sync
    if (!syncedToServer) {
      await _db.insertSyncOp(SyncQueueCompanion.insert(
        id: _uuid.v4(),
        entityType: 'transaction',
        entityId: transactionId,
        opType: 'create',
        payload: jsonEncode({
          'id': transactionId,
          'account_id': account.id,
          'category_id': categoryId,
          'amount': amount,
          'currency': currency,
          'amount_cny': effectiveAmountCny,
          'exchange_rate': amount > 0 ? effectiveAmountCny / amount : 1.0,
          'type': type,
          'note': note,
          'txn_date': effectiveTxnDate.toIso8601String(),
        }),
        clientId: 'client_$_userId',
        timestamp: now,
      ));
    }
  }

  /// 更新交易 — 先写本地，然后尝试推服务端
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
  }) async {
    // 1. 获取旧交易记录（用于回退余额）
    final oldTxn = await _db.getTransactionById(id);
    if (oldTxn == null) return;

    // 2. 构建更新 companion
    final companion = TransactionsCompanion(
      categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
      amount: amount != null ? Value(amount) : const Value.absent(),
      amountCny: amountCny != null
          ? Value(amountCny)
          : (amount != null ? Value(amount) : const Value.absent()),
      type: type != null ? Value(type) : const Value.absent(),
      note: note != null ? Value(note) : const Value.absent(),
      currency: currency != null ? Value(currency) : const Value.absent(),
      tags: tags != null ? Value(tags) : const Value.absent(),
      imageUrls: imageUrls != null ? Value(imageUrls) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );
    await _db.updateTransactionFields(id, companion);

    // 3. 重算账户余额（旧金额回退 + 新金额扣减）
    final effectiveNewAmountCny = amountCny ?? amount ?? oldTxn.amountCny;
    final effectiveNewType = type ?? oldTxn.type;
    final oldDelta = oldTxn.type == 'income' ? oldTxn.amountCny : -oldTxn.amountCny;
    final newDelta = effectiveNewType == 'income'
        ? effectiveNewAmountCny
        : -effectiveNewAmountCny;
    final balanceDiff = newDelta - oldDelta;
    if (balanceDiff != 0) {
      await _db.updateAccountBalance(oldTxn.accountId, balanceDiff);
    }

    // 4. 尝试推 gRPC
    try {
      if (_txnClient != null) {
        final req = pb.UpdateTransactionRequest(
          transactionId: id,
        );
        if (amount != null) req.amount = Int64(amount);
        if (categoryId != null) req.categoryId = categoryId;
        if (note != null) req.note = note;
        if (tags != null) req.tags = tags;
        if (currency != null) req.currency = currency;
        if (type != null) {
          req.type = type == 'income'
              ? pbe.TransactionType.TRANSACTION_TYPE_INCOME
              : pbe.TransactionType.TRANSACTION_TYPE_EXPENSE;
        }
        await _txnClient.updateTransaction(req);
      }
    } catch (e) {
      dev.log('TransactionNotifier: updateTransaction gRPC failed: $e',
          name: 'txn');
      await _db.insertSyncOp(SyncQueueCompanion.insert(
        id: _uuid.v4(),
        entityType: 'transaction',
        entityId: id,
        opType: 'update',
        payload: jsonEncode({
          'id': id,
          if (categoryId != null) 'category_id': categoryId,
          if (amount != null) 'amount': amount,
          if (amountCny != null) 'amount_cny': amountCny,
          if (currency != null) 'currency': currency,
          if (type != null) 'type': type,
          if (note != null) 'note': note,
          if (tags != null) 'tags': tags,
        }),
        clientId: 'client_$_userId',
        timestamp: DateTime.now(),
      ));
    }

    // 5. 刷新摘要
    await _refreshSummary();
  }

  /// 删除交易 — 先删本地，然后尝试推服务端
  Future<void> deleteTransaction(String id) async {
    // 1. 查找本地交易记录（获取金额用于回退）
    final txn = await _db.getTransactionById(id);
    if (txn == null) return;

    // 2. 本地 DB 软删除
    await _db.softDeleteTransaction(id);

    // 3. 回退账户余额
    final delta = txn.type == 'income' ? -txn.amountCny : txn.amountCny;
    await _db.updateAccountBalance(txn.accountId, delta);

    // 4. 尝试推 gRPC
    try {
      if (_txnClient != null) {
        final req = pb.DeleteTransactionRequest(
          transactionId: id,
        );
        await _txnClient.deleteTransaction(req);
      }
    } catch (e) {
      dev.log('TransactionNotifier: deleteTransaction gRPC failed: $e',
          name: 'txn');
      await _db.insertSyncOp(SyncQueueCompanion.insert(
        id: _uuid.v4(),
        entityType: 'transaction',
        entityId: id,
        opType: 'delete',
        payload: jsonEncode({'id': id}),
        clientId: 'client_$_userId',
        timestamp: DateTime.now(),
      ));
    }

    // 5. 刷新摘要
    await _refreshSummary();
  }

  /// 批量删除交易
  Future<int> batchDeleteTransactions(List<String> ids) async {
    if (ids.isEmpty) return 0;

    // 1. 本地批量软删除 + 余额回退
    for (final id in ids) {
      final txn = await _db.getTransactionById(id);
      if (txn == null) continue;
      await _db.softDeleteTransaction(id);
      final delta = txn.type == 'income' ? -txn.amountCny : txn.amountCny;
      await _db.updateAccountBalance(txn.accountId, delta);
    }

    // 2. 尝试 gRPC 批量删除
    try {
      if (_txnClient != null) {
        final req = pb.BatchDeleteTransactionsRequest(
          transactionIds: ids,
        );
        await _txnClient.batchDeleteTransactions(req);
      }
    } catch (e) {
      dev.log('TransactionNotifier: batchDelete gRPC failed: $e', name: 'txn');
      for (final id in ids) {
        await _db.insertSyncOp(SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entityType: 'transaction',
          entityId: id,
          opType: 'delete',
          payload: jsonEncode({'id': id}),
          clientId: 'client_$_userId',
          timestamp: DateTime.now(),
        ));
      }
    }

    // 3. 刷新摘要
    await _refreshSummary();
    return ids.length;
  }

  /// 上传图片到服务端，返回服务端 URL，失败返回 null
  Future<String?> uploadImage(pb.UploadTransactionImageRequest req) async {
    try {
      if (_txnClient != null) {
        final resp = await _txnClient.uploadTransactionImage(req);
        return resp.imageUrl;
      }
    } catch (e) {
      dev.log('TransactionNotifier: uploadImage failed: $e', name: 'txn');
    }
    return null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

proto_ts.Timestamp _toTimestamp(DateTime dt) {
  final seconds = dt.millisecondsSinceEpoch ~/ 1000;
  final nanos = (dt.millisecondsSinceEpoch % 1000) * 1000000;
  return proto_ts.Timestamp()
    ..seconds = Int64(seconds)
    ..nanos = nanos;
}

/// Parameters for batch upserting transactions from server.
class _TransactionUpsertParams {
  final String id;
  final String userId;
  final String accountId;
  final String categoryId;
  final int amount;
  final int amountCny;
  final String type;
  final String note;
  final DateTime txnDate;

  const _TransactionUpsertParams({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.amountCny,
    required this.type,
    required this.note,
    required this.txnDate,
  });
}

final transactionProvider =
    StateNotifierProvider<TransactionNotifier, TransactionState>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  final familyId = ref.watch(currentFamilyIdProvider);
  pb.TransactionServiceClient? txnClient;
  try {
    txnClient = ref.watch(transactionClientProvider);
  } catch (_) {
    // gRPC 未初始化时忽略
  }
  if (userId == null) {
    return TransactionNotifier(db, '', null, null);
  }
  return TransactionNotifier(db, userId, familyId, txnClient);
});
