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

  const TransactionState({
    this.transactions = const [],
    this.expenseCategories = const [],
    this.incomeCategories = const [],
    this.totalBalance = 0,
    this.todayExpense = 0,
    this.monthExpense = 0,
    this.isLoading = true,
  });

  TransactionState copyWith({
    List<Transaction>? transactions,
    List<Category>? expenseCategories,
    List<Category>? incomeCategories,
    int? totalBalance,
    int? todayExpense,
    int? monthExpense,
    bool? isLoading,
  }) =>
      TransactionState(
        transactions: transactions ?? this.transactions,
        expenseCategories: expenseCategories ?? this.expenseCategories,
        incomeCategories: incomeCategories ?? this.incomeCategories,
        totalBalance: totalBalance ?? this.totalBalance,
        todayExpense: todayExpense ?? this.todayExpense,
        monthExpense: monthExpense ?? this.monthExpense,
        isLoading: isLoading ?? this.isLoading,
      );
}

class TransactionNotifier extends StateNotifier<TransactionState> {
  final AppDatabase _db;
  final String _userId;
  final pb.TransactionServiceClient? _txnClient;
  final _uuid = const Uuid();
  StreamSubscription? _sub;

  TransactionNotifier(this._db, this._userId, this._txnClient)
      : super(const TransactionState()) {
    _load();
    _sub = _db.watchTransactions(_userId).listen((txns) {
      state = state.copyWith(transactions: txns);
      _refreshSummary();
    });
  }

  Future<void> _load() async {
    final expCats = await _db.getCategoriesByType('expense');
    final incCats = await _db.getCategoriesByType('income');
    state = state.copyWith(
      expenseCategories: expCats,
      incomeCategories: incCats,
    );
    await _refreshSummary();
    state = state.copyWith(isLoading: false);
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
    final account = await _db.getDefaultAccount(_userId);
    if (account == null) return;

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
        await _txnClient.createTransaction(req);
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
          'currency': 'CNY',
          'amount_cny': amount,
          'exchange_rate': 1.0,
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
        opType: 'update_transaction',
        payload: jsonEncode({
          'id': id,
          if (categoryId != null) 'category_id': categoryId,
          if (amount != null) 'amount': amount,
          if (type != null) 'type': type,
          if (note != null) 'note': note,
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

    // 2. 本地 DB 删除
    // TODO: 等 Transactions 表加了 deletedAt 字段后改为软删除
    await _db.deleteTransaction(id);

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
        opType: 'delete_transaction',
        payload: jsonEncode({'id': id}),
        clientId: 'client_$_userId',
        timestamp: DateTime.now(),
      ));
    }

    // 5. 刷新摘要
    await _refreshSummary();
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
  pb.TransactionServiceClient? txnClient;
  try {
    txnClient = ref.watch(transactionClientProvider);
  } catch (_) {
    // gRPC 未初始化时忽略
  }
  if (userId == null) {
    return TransactionNotifier(db, '', null);
  }
  return TransactionNotifier(db, userId, txnClient);
});
