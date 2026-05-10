import 'dart:developer' as dev;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';
import '../../data/local/database.dart' as db;
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/budget.pb.dart' as pb;
import '../../generated/proto/budget.pbgrpc.dart';
import 'app_providers.dart';

// ── Models ──

class CategoryBudgetItem {
  final String categoryId;
  final int amount; // cents

  const CategoryBudgetItem({
    required this.categoryId,
    required this.amount,
  });
}

class BudgetExecutionData {
  final int totalBudget; // cents
  final int totalSpent; // cents
  final double executionRate;
  final List<CategoryExecutionData> categoryExecutions;

  const BudgetExecutionData({
    required this.totalBudget,
    required this.totalSpent,
    required this.executionRate,
    required this.categoryExecutions,
  });
}

class CategoryExecutionData {
  final String categoryId;
  final String categoryName;
  final int budgetAmount; // cents
  final int spentAmount; // cents
  final double executionRate;

  const CategoryExecutionData({
    required this.categoryId,
    required this.categoryName,
    required this.budgetAmount,
    required this.spentAmount,
    required this.executionRate,
  });
}

// ── State ──

class BudgetState {
  final db.Budget? currentBudget;
  final List<db.Budget> budgets;
  final List<db.CategoryBudgetsTableData> currentCategoryBudgets;
  final BudgetExecutionData? execution;
  final bool isLoading;
  final String? error;

  const BudgetState({
    this.currentBudget,
    this.budgets = const [],
    this.currentCategoryBudgets = const [],
    this.execution,
    this.isLoading = false,
    this.error,
  });

  BudgetState copyWith({
    db.Budget? currentBudget,
    List<db.Budget>? budgets,
    List<db.CategoryBudgetsTableData>? currentCategoryBudgets,
    BudgetExecutionData? execution,
    bool? isLoading,
    String? error,
    bool clearCurrentBudget = false,
    bool clearExecution = false,
    bool clearError = false,
  }) =>
      BudgetState(
        currentBudget:
            clearCurrentBudget ? null : (currentBudget ?? this.currentBudget),
        budgets: budgets ?? this.budgets,
        currentCategoryBudgets:
            currentCategoryBudgets ?? this.currentCategoryBudgets,
        execution: clearExecution ? null : (execution ?? this.execution),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── Notifier ──

class BudgetNotifier extends StateNotifier<BudgetState> {
  final db.AppDatabase _db;
  final BudgetServiceClient _client;
  final String? _userId;
  final String _familyId;
  static final _callOpts = CallOptions(
      timeout: const Duration(seconds: 5));

  BudgetNotifier(this._db, this._client, this._userId, this._familyId)
      : super(const BudgetState()) {
    if (_userId != null) {
      loadCurrentMonth();
    }
  }

  Future<void> loadCurrentMonth() async {
    if (_userId == null) return;
    dev.log('[Budget] loadCurrentMonth START', name: 'BudgetProvider');
    state = state.copyWith(isLoading: true, clearError: true);

    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    try {
      // Try gRPC first
      dev.log('[Budget] loadCurrentMonth: listBudgets gRPC...', name: 'BudgetProvider');
      final resp = await _client.listBudgets(
        pb.ListBudgetsRequest()
          ..familyId = _familyId
          ..year = year,
        options: _callOpts,
      );
      dev.log('[Budget] loadCurrentMonth: listBudgets OK, ${resp.budgets.length} budgets', name: 'BudgetProvider');

      // Cache all budgets locally
      for (final b in resp.budgets) {
        // Clean up duplicates before caching
        await _db.deleteBudgetDuplicates(
            _userId, b.year, b.month, _familyId, keepId: b.id);
        await _db.insertBudget(db.BudgetsCompanion.insert(
          id: b.id,
          userId: _userId,
          familyId: Value(_familyId),
          year: b.year,
          month: b.month,
          totalAmount: b.totalAmount.toInt(),
        ));
        // Cache category budgets
        await _db.deleteCategoryBudgets(b.id);
        for (final cb in b.categoryBudgets) {
          await _db.insertCategoryBudget(
            db.CategoryBudgetsTableCompanion.insert(
              id: const Uuid().v4(),
              budgetId: b.id,
              categoryId: cb.categoryId,
              amount: cb.amount.toInt(),
            ),
          );
        }
      }

      final budgetsList = await _db.getBudgetsByYear(_userId, year,
          familyId: _familyId);
      final current = await _db.getBudgetByMonth(_userId, year, month,
          familyId: _familyId);
      List<db.CategoryBudgetsTableData> catBudgets = [];

      if (current != null) {
        catBudgets = await _db.getCategoryBudgets(current.id);
        // Fetch execution from gRPC
        try {
          dev.log('[Budget] loadCurrentMonth: getBudgetExecution gRPC...', name: 'BudgetProvider');
          final execResp = await _client.getBudgetExecution(
            pb.GetBudgetExecutionRequest()..budgetId = current.id,
            options: _callOpts,
          );
          dev.log('[Budget] loadCurrentMonth: getBudgetExecution OK', name: 'BudgetProvider');
          final exec = execResp.execution;
          state = state.copyWith(
            currentBudget: current,
            budgets: budgetsList,
            currentCategoryBudgets: catBudgets,
            execution: BudgetExecutionData(
              totalBudget: exec.totalBudget.toInt(),
              totalSpent: exec.totalSpent.toInt(),
              executionRate: exec.executionRate,
              categoryExecutions: exec.categoryExecutions
                  .map((ce) => CategoryExecutionData(
                        categoryId: ce.categoryId,
                        categoryName: ce.categoryName,
                        budgetAmount: ce.budgetAmount.toInt(),
                        spentAmount: ce.spentAmount.toInt(),
                        executionRate: ce.executionRate,
                      ))
                  .toList(),
            ),
            isLoading: false,
          );
          dev.log('[Budget] loadCurrentMonth: DONE via gRPC execution, isLoading=false', name: 'BudgetProvider');
          return;
        } catch (e) {
          dev.log('[Budget] loadCurrentMonth: getBudgetExecution failed: $e', name: 'BudgetProvider');
        }
      }

      // Local execution calculation
      dev.log('[Budget] loadCurrentMonth: falling back to local execution', name: 'BudgetProvider');
      await _loadLocalExecution(current, budgetsList, catBudgets);
      dev.log('[Budget] loadCurrentMonth: DONE via local, isLoading=${state.isLoading}', name: 'BudgetProvider');
    } catch (e) {
      dev.log('[Budget] loadCurrentMonth: outer catch: $e', name: 'BudgetProvider');
      await _loadFromLocal(year, month);
      dev.log('[Budget] loadCurrentMonth: DONE via _loadFromLocal, isLoading=${state.isLoading}', name: 'BudgetProvider');
    }
  }

  Future<void> _loadFromLocal(int year, int month) async {
    if (_userId == null) return;
    try {
      final budgetsList = await _db.getBudgetsByYear(_userId, year,
          familyId: _familyId);
      final current = await _db.getBudgetByMonth(_userId, year, month,
          familyId: _familyId);
      List<db.CategoryBudgetsTableData> catBudgets = [];
      if (current != null) {
        catBudgets = await _db.getCategoryBudgets(current.id);
      }
      await _loadLocalExecution(current, budgetsList, catBudgets);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadLocalExecution(
    db.Budget? current,
    List<db.Budget> budgetsList,
    List<db.CategoryBudgetsTableData> catBudgets,
  ) async {
    if (_userId == null) return;

    BudgetExecutionData? exec;
    if (current != null) {
      final now = DateTime.now();
      final categoryExpenses = await _db.getMonthCategoryExpenses(
          _userId, now.year, now.month);
      final totalSpent =
          categoryExpenses.values.fold<int>(0, (sum, v) => sum + v);
      final totalBudget = current.totalAmount;
      final rate = totalBudget > 0 ? totalSpent / totalBudget : 0.0;

      final categories = await _db.getAllCategories();
      final catMap = {for (final c in categories) c.id: c};

      // Build parent→children map for aggregation
      final childrenOf = <String, List<String>>{};
      for (final c in categories) {
        if (c.parentId != null) {
          childrenOf.putIfAbsent(c.parentId!, () => []).add(c.id);
        }
      }

      final catExecs = catBudgets.map((cb) {
        final cat = catMap[cb.categoryId];
        int spent;
        if (cat != null && cat.parentId == null && childrenOf.containsKey(cb.categoryId)) {
          // Parent category: aggregate own + ALL children (including those without budgets)
          spent = categoryExpenses[cb.categoryId] ?? 0;
          for (final childId in childrenOf[cb.categoryId]!) {
            spent += categoryExpenses[childId] ?? 0;
          }
        } else {
          spent = categoryExpenses[cb.categoryId] ?? 0;
        }
        final catRate = cb.amount > 0 ? spent / cb.amount : 0.0;
        return CategoryExecutionData(
          categoryId: cb.categoryId,
          categoryName: cat?.name ?? '未知',
          budgetAmount: cb.amount,
          spentAmount: spent,
          executionRate: catRate,
        );
      }).toList();

      exec = BudgetExecutionData(
        totalBudget: totalBudget,
        totalSpent: totalSpent,
        executionRate: rate,
        categoryExecutions: catExecs,
      );
    }

    state = state.copyWith(
      currentBudget: current,
      budgets: budgetsList,
      currentCategoryBudgets: catBudgets,
      execution: exec,
      isLoading: false,
      clearCurrentBudget: current == null,
      clearExecution: exec == null,
    );
  }

  Future<void> createBudget({
    required int year,
    required int month,
    required int totalAmount,
    required List<CategoryBudgetItem> categoryBudgets,
  }) async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Try gRPC first
      final resp = await _client.createBudget(
        pb.CreateBudgetRequest()
          ..familyId = _familyId
          ..year = year
          ..month = month
          ..totalAmount = Int64(totalAmount)
          ..categoryBudgets.addAll(
            categoryBudgets.map((cb) => pb.CategoryBudget()
              ..categoryId = cb.categoryId
              ..amount = Int64(cb.amount)),
          ),
        options: _callOpts,
      );

      final b = resp.budget;
      // Cache locally
      await _db.insertBudget(db.BudgetsCompanion.insert(
        id: b.id,
        userId: _userId,
        familyId: Value(_familyId),
        year: b.year,
        month: b.month,
        totalAmount: b.totalAmount.toInt(),
      ));
      await _db.deleteCategoryBudgets(b.id);
      for (final cb in b.categoryBudgets) {
        await _db.insertCategoryBudget(
          db.CategoryBudgetsTableCompanion.insert(
            id: const Uuid().v4(),
            budgetId: b.id,
            categoryId: cb.categoryId,
            amount: cb.amount.toInt(),
          ),
        );
      }
    } catch (_) {
      // Offline: save locally
      final id = const Uuid().v4();
      // Remove any existing budget for same month to prevent duplicates
      await _db.deleteBudgetDuplicates(
          _userId, year, month, _familyId);
      await _db.insertBudget(db.BudgetsCompanion.insert(
        id: id,
        userId: _userId,
        familyId: Value(_familyId),
        year: year,
        month: month,
        totalAmount: totalAmount,
      ));
      for (final cb in categoryBudgets) {
        await _db.insertCategoryBudget(
          db.CategoryBudgetsTableCompanion.insert(
            id: const Uuid().v4(),
            budgetId: id,
            categoryId: cb.categoryId,
            amount: cb.amount,
          ),
        );
      }
    }

    await loadCurrentMonth();
  }

  Future<void> updateBudget({
    required String id,
    int? totalAmount,
    List<CategoryBudgetItem>? categoryBudgets,
  }) async {
    if (_userId == null) return;
    dev.log('[Budget] updateBudget START id=$id amount=$totalAmount', name: 'BudgetProvider');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final req = pb.UpdateBudgetRequest()..budgetId = id;
      if (totalAmount != null) req.totalAmount = Int64(totalAmount);
      if (categoryBudgets != null) {
        req.categoryBudgets.addAll(
          categoryBudgets.map((cb) => pb.CategoryBudget()
            ..categoryId = cb.categoryId
            ..amount = Int64(cb.amount)),
        );
      }
      dev.log('[Budget] updateBudget gRPC call...', name: 'BudgetProvider');
      await _client.updateBudget(req, options: _callOpts);
      dev.log('[Budget] updateBudget gRPC OK', name: 'BudgetProvider');
    } catch (e) {
      dev.log('[Budget] updateBudget gRPC failed: $e', name: 'BudgetProvider');
    }

    dev.log('[Budget] updateBudget local update...', name: 'BudgetProvider');
    final existing = await _db.getBudgetById(id);
    if (existing != null) {
      await _db.insertBudget(db.BudgetsCompanion.insert(
        id: id,
        userId: _userId,
        familyId: Value(_familyId),
        year: existing.year,
        month: existing.month,
        totalAmount: totalAmount ?? existing.totalAmount,
      ));
      if (categoryBudgets != null) {
        await _db.deleteCategoryBudgets(id);
        for (final cb in categoryBudgets) {
          await _db.insertCategoryBudget(
            db.CategoryBudgetsTableCompanion.insert(
              id: const Uuid().v4(),
              budgetId: id,
              categoryId: cb.categoryId,
              amount: cb.amount,
            ),
          );
        }
      }
    } else {
      dev.log('[Budget] updateBudget: existing budget not found in DB!', name: 'BudgetProvider');
    }

    dev.log('[Budget] updateBudget -> loadCurrentMonth...', name: 'BudgetProvider');
    await loadCurrentMonth();
    dev.log('[Budget] updateBudget DONE, isLoading=${state.isLoading}', name: 'BudgetProvider');
  }

  Future<void> deleteBudget(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _client.deleteBudget(pb.DeleteBudgetRequest()..budgetId = id, options: _callOpts);
    } catch (_) {
      // offline
    }

    await _db.deleteCategoryBudgets(id);
    await _db.deleteBudget(id);
    await loadCurrentMonth();
  }
}

// ── Provider ──

final budgetProvider =
    StateNotifierProvider<BudgetNotifier, BudgetState>((ref) {
  final database = ref.watch(databaseProvider);
  final client = ref.watch(budgetClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  final familyId = ref.watch(currentFamilyIdProvider) ?? '';
  return BudgetNotifier(database, client, userId, familyId);
});
