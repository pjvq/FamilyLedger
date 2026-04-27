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
      // Sync family transactions from server with pagination
      if (_familyId != null && _familyId.isNotEmpty && _txnClient != null) {
        try {
          String pageToken = '';
          int pagesFetched = 0;

          do {
            final req = pb.ListTransactionsRequest()
              ..familyId = _familyId
              ..pageSize = _syncPageSize;
            if (pageToken.isNotEmpty) {
              req.pageToken = pageToken;
            }

            final resp = await _txnClient.listTransactions(
              req,
              options: _callOpts,
            );

            for (final t in resp.transactions) {
              await _db.insertOrUpdateTransaction(
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

            pageToken = resp.nextPageToken;
            pagesFetched++;

            // Safety: stop if no more pages or hit max page limit
          } while (pageToken.isNotEmpty && pagesFetched < _maxPages);
        } catch (_) {
          // Offline or timeout — continue with local data
        }
      }

      final expCats = await _db.getCategoriesByType('expense');
      final incCats = await _db.getCategoriesByType('income');
      state = state.copyWith(
        expenseCategories: expCats,
        incomeCategories: incCats,
        clearError: true,
      );
      await _refreshSummary();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      dev.log('TransactionNotifier: _load failed: $e', name: 'txn');
      state = state.copyWith(
        isLoading: false,
        error: '加载交易数据失败',
      );
    }
  }

  /// Public reload — for retry on error or pull-to-refresh
  Future<void> reload() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _load();
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

  /// 添加交易 — 先写本地，然后尝试推服务端
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
    final id = _uuid.v4();
    final account = await _db.getDefaultAccount(_userId, familyId: _familyId);
    if (account == null) {
      throw StateError('无默认账户，请先创建账户');
    }

    final effectiveAmountCny = amountCny ?? amount;

    // 1. 写本地 DB
    final companion = TransactionsCompanion.insert(
      id: id,
      userId: _userId,
      accountId: account.id,
      categoryId: categoryId,
      amount: amount,
      amountCny: effectiveAmountCny,
      type: type,
      note: Value(note),
      tags: Value(tags),
      imageUrls: Value(imageUrls),
      txnDate: txnDate ?? now,
    );
    await _db.insertTransaction(companion);

    // 2. 更新账户余额（始终用人民币计）
    final delta = type == 'income' ? effectiveAmountCny : -effectiveAmountCny;
    await _db.updateAccountBalance(account.id, delta);

    // 3. 尝试推服务端
    try {
      if (_txnClient != null) {
        final txnDate0 = txnDate ?? now;
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
          ..txnDate = _toTimestamp(txnDate0);
        final resp = await _txnClient.createTransaction(req);
        // Replace local id with server-assigned id to avoid duplicates
        if (resp.hasTransaction() && resp.transaction.id.isNotEmpty && resp.transaction.id != id) {
          await _db.hardDeleteTransaction(id);
          await _db.insertTransaction(TransactionsCompanion.insert(
            id: resp.transaction.id,
            userId: _userId,
            accountId: account.id,
            categoryId: categoryId,
            amount: amount,
            amountCny: effectiveAmountCny,
            type: type,
            note: Value(note),
            tags: Value(tags),
            imageUrls: Value(imageUrls),
            txnDate: txnDate ?? now,
          ));
        }
      }
    } catch (e) {
      // 服务端推送失败，加入同步队列
      dev.log('TransactionNotifier: createTransaction failed: $e', name: 'txn');
      await _db.insertSyncOp(SyncQueueCompanion.insert(
        id: _uuid.v4(),
        entityType: 'transaction',
        entityId: id,
        opType: 'create',
        payload: jsonEncode({
          'id': id,
          'account_id': account.id,
          'category_id': categoryId,
          'amount': amount,
          'currency': currency,
          'amount_cny': effectiveAmountCny,
          'exchange_rate': amount > 0 ? effectiveAmountCny / amount : 1.0,
          'type': type,
          'note': note,
          'txn_date': (txnDate ?? now).toIso8601String(),
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
