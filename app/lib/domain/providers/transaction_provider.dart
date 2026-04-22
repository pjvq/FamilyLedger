import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../data/local/database.dart';
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
  final _uuid = const Uuid();
  StreamSubscription? _sub;

  TransactionNotifier(this._db, this._userId)
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

  /// 添加交易
  Future<void> addTransaction({
    required String categoryId,
    required int amount, // 分
    required String type, // 'income' | 'expense'
    String note = '',
    DateTime? txnDate,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final account = await _db.getDefaultAccount(_userId);
    if (account == null) return;

    final companion = TransactionsCompanion.insert(
      id: id,
      userId: _userId,
      accountId: account.id,
      categoryId: categoryId,
      amount: amount,
      amountCny: amount, // Phase 1 只支持 CNY
      type: type,
      note: Value(note),
      txnDate: txnDate ?? now,
    );

    await _db.insertTransaction(companion);

    // 更新账户余额
    final delta = type == 'income' ? amount : -amount;
    await _db.updateAccountBalance(account.id, delta);

    // 加入同步队列
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final transactionProvider =
    StateNotifierProvider<TransactionNotifier, TransactionState>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return TransactionNotifier(db, '');
  }
  return TransactionNotifier(db, userId);
});
