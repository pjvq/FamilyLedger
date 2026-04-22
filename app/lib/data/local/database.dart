import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Users,
  Accounts,
  Categories,
  Transactions,
  Families,
  FamilyMembers,
  Transfers,
  Budgets,
  CategoryBudgetsTable,
  Notifications,
  NotificationSettingsTable,
  Loans,
  LoanSchedules,
  LoanRateChanges,
  Investments,
  InvestmentTrades,
  MarketQuotes,
  FixedAssets,
  AssetValuations,
  DepreciationRules,
  SyncQueue,
  ExchangeRates,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Seed preset categories
          await _seedCategories();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 → v2: add new tables & columns
            await m.createTable(families);
            await m.createTable(familyMembers);
            await m.createTable(transfers);
            await m.addColumn(accounts, accounts.familyId);
            await m.addColumn(accounts, accounts.accountType);
            await m.addColumn(accounts, accounts.isActive);
          }
          if (from < 3) {
            // v2 → v3: budget + notification tables
            await m.createTable(budgets);
            await m.createTable(categoryBudgetsTable);
            await m.createTable(notifications);
            await m.createTable(notificationSettingsTable);
          }
          if (from < 4) {
            // v3 → v4: loan tables
            await m.createTable(loans);
            await m.createTable(loanSchedules);
            await m.createTable(loanRateChanges);
          }
          if (from < 5) {
            // v4 → v5: investment + market tables
            await m.createTable(investments);
            await m.createTable(investmentTrades);
            await m.createTable(marketQuotes);
          }
          if (from < 6) {
            // v5 → v6: fixed asset tables
            await m.createTable(fixedAssets);
            await m.createTable(assetValuations);
            await m.createTable(depreciationRules);
          }
          if (from < 7) {
            // v6 → v7: transaction tags/images + exchange rates
            await m.addColumn(transactions, transactions.tags);
            await m.addColumn(transactions, transactions.imageUrls);
            await m.createTable(exchangeRates);
          }
        },
      );

  Future<void> _seedCategories() async {
    final presets = [
      // Expense
      _cat('cat_food', '餐饮', '🍜', 'expense', true, 1),
      _cat('cat_transport', '交通', '🚗', 'expense', true, 2),
      _cat('cat_shopping', '购物', '🛍️', 'expense', true, 3),
      _cat('cat_housing', '居住', '🏠', 'expense', true, 4),
      _cat('cat_entertainment', '娱乐', '🎮', 'expense', true, 5),
      _cat('cat_medical', '医疗', '🏥', 'expense', true, 6),
      _cat('cat_education', '教育', '📚', 'expense', true, 7),
      _cat('cat_telecom', '通讯', '📱', 'expense', true, 8),
      _cat('cat_social', '人情', '🎁', 'expense', true, 9),
      _cat('cat_clothing', '服饰', '👔', 'expense', true, 10),
      _cat('cat_daily', '日用', '🧴', 'expense', true, 11),
      _cat('cat_travel', '旅行', '✈️', 'expense', true, 12),
      _cat('cat_pet', '宠物', '🐱', 'expense', true, 13),
      _cat('cat_other_exp', '其他', '📦', 'expense', true, 14),
      // Income
      _cat('cat_salary', '工资', '💰', 'income', true, 1),
      _cat('cat_bonus', '奖金', '🏆', 'income', true, 2),
      _cat('cat_investment', '投资收益', '📈', 'income', true, 3),
      _cat('cat_sidejob', '兼职', '💼', 'income', true, 4),
      _cat('cat_redpacket', '红包', '🧧', 'income', true, 5),
      _cat('cat_reimburse', '报销', '🧾', 'income', true, 6),
      _cat('cat_other_inc', '其他', '💵', 'income', true, 7),
    ];
    await batch((b) {
      b.insertAll(categories, presets);
    });
  }

  CategoriesCompanion _cat(
          String id, String name, String icon, String type, bool isPreset, int sort) =>
      CategoriesCompanion.insert(
        id: id,
        name: name,
        icon: icon,
        type: type,
        isPreset: Value(isPreset),
        sortOrder: Value(sort),
      );

  // ---- Queries ----

  // Accounts
  Future<List<Account>> getAllAccounts(String userId) =>
      (select(accounts)..where((a) => a.userId.equals(userId))).get();

  Future<Account?> getDefaultAccount(String userId) =>
      (select(accounts)
            ..where((a) => a.userId.equals(userId))
            ..limit(1))
          .getSingleOrNull();

  Future<int> insertAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<void> updateAccountBalance(String accountId, int delta) async {
    final acc = await (select(accounts)..where((a) => a.id.equals(accountId)))
        .getSingle();
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(balance: Value(acc.balance + delta)),
    );
  }

  // Categories
  Future<List<Category>> getCategoriesByType(String type) =>
      (select(categories)
            ..where((c) => c.type.equals(type))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();

  Future<List<Category>> getAllCategories() =>
      (select(categories)..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();

  // Transactions
  Future<List<Transaction>> getRecentTransactions(
      String userId, int limit) async {
    return (select(transactions)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.txnDate)])
          ..limit(limit))
        .get();
  }

  Future<int> insertTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  /// Upsert: 远程同步时使用，有则更新无则插入
  Future<void> insertOrUpdateTransaction({
    required String id,
    required String userId,
    required String accountId,
    required String categoryId,
    required int amount,
    required int amountCny,
    required String type,
    required String note,
    required DateTime txnDate,
  }) async {
    await into(transactions).insertOnConflictUpdate(
      TransactionsCompanion.insert(
        id: id,
        userId: userId,
        accountId: accountId,
        categoryId: categoryId,
        amount: amount,
        amountCny: amountCny,
        type: type,
        note: Value(note),
        txnDate: txnDate,
      ),
    );
  }

  /// 删除指定交易（远程同步删除时使用）
  Future<int> deleteTransaction(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Stream<List<Transaction>> watchTransactions(String userId) =>
      (select(transactions)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.txnDate)]))
          .watch();

  // Sync queue
  Future<List<SyncQueueData>> getPendingSyncOps(int limit) =>
      (select(syncQueue)
            ..where((s) => s.uploaded.equals(false))
            ..orderBy([(s) => OrderingTerm.asc(s.timestamp)])
            ..limit(limit))
          .get();

  Future<int> insertSyncOp(SyncQueueCompanion entry) =>
      into(syncQueue).insert(entry);

  Future<void> markSyncOpsUploaded(List<String> ids) async {
    await (update(syncQueue)..where((s) => s.id.isIn(ids)))
        .write(const SyncQueueCompanion(uploaded: Value(true)));
  }

  // Balance summary
  /// 总余额 = 所有收入 - 所有支出（从交易记录直接聚合，不依赖 account.balance）
  Future<int> getTotalBalance(String userId) async {
    final allTxns = await (select(transactions)
          ..where((t) => t.userId.equals(userId)))
        .get();
    return allTxns.fold<int>(0, (sum, t) {
      return sum + (t.type == 'income' ? t.amountCny : -t.amountCny);
    });
  }

  Future<int> getTodayExpense(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final rows = await (select(transactions)
          ..where((t) =>
              t.userId.equals(userId) &
              t.type.equals('expense') &
              t.txnDate.isBiggerOrEqualValue(startOfDay)))
        .get();
    return rows.fold<int>(0, (sum, t) => sum + t.amountCny);
  }

  Future<int> getMonthExpense(String userId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final rows = await (select(transactions)
          ..where((t) =>
              t.userId.equals(userId) &
              t.type.equals('expense') &
              t.txnDate.isBiggerOrEqualValue(startOfMonth)))
        .get();
    return rows.fold<int>(0, (sum, t) => sum + t.amountCny);
  }

  // ---- Family CRUD ----

  Future<List<Family>> getAllFamilies() =>
      select(families).get();

  Future<Family?> getFamilyById(String id) =>
      (select(families)..where((f) => f.id.equals(id))).getSingleOrNull();

  Future<int> insertFamily(FamiliesCompanion entry) =>
      into(families).insert(entry);

  Future<bool> updateFamily(FamiliesCompanion entry) =>
      update(families).replace(entry);

  Future<int> deleteFamily(String id) =>
      (delete(families)..where((f) => f.id.equals(id))).go();

  // ---- Family Members CRUD ----

  Future<List<FamilyMember>> getFamilyMembers(String familyId) =>
      (select(familyMembers)..where((m) => m.familyId.equals(familyId))).get();

  Future<FamilyMember?> getFamilyMember(String familyId, String userId) =>
      (select(familyMembers)
            ..where((m) => m.familyId.equals(familyId) & m.userId.equals(userId)))
          .getSingleOrNull();

  Future<int> insertFamilyMember(FamilyMembersCompanion entry) =>
      into(familyMembers).insert(entry);

  Future<void> updateFamilyMemberRole(String familyId, String userId, String role) async {
    await (update(familyMembers)
          ..where((m) => m.familyId.equals(familyId) & m.userId.equals(userId)))
        .write(FamilyMembersCompanion(role: Value(role)));
  }

  Future<void> updateFamilyMemberPermissions({
    required String familyId,
    required String userId,
    required bool canView,
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
    required bool canManageAccounts,
  }) async {
    await (update(familyMembers)
          ..where((m) => m.familyId.equals(familyId) & m.userId.equals(userId)))
        .write(FamilyMembersCompanion(
      canView: Value(canView),
      canCreate: Value(canCreate),
      canEdit: Value(canEdit),
      canDelete: Value(canDelete),
      canManageAccounts: Value(canManageAccounts),
    ));
  }

  Future<int> deleteFamilyMember(String familyId, String userId) =>
      (delete(familyMembers)
            ..where((m) => m.familyId.equals(familyId) & m.userId.equals(userId)))
          .go();

  Future<int> deleteAllFamilyMembers(String familyId) =>
      (delete(familyMembers)..where((m) => m.familyId.equals(familyId))).go();

  // ---- Account extended CRUD ----

  Future<List<Account>> getAccountsByFamily(String familyId) =>
      (select(accounts)..where((a) => a.familyId.equals(familyId) & a.isActive.equals(true))).get();

  Future<List<Account>> getActiveAccounts(String userId) =>
      (select(accounts)..where((a) => a.userId.equals(userId) & a.isActive.equals(true))).get();

  Future<Account?> getAccountById(String accountId) =>
      (select(accounts)..where((a) => a.id.equals(accountId))).getSingleOrNull();

  Future<void> updateAccountFields(String accountId, AccountsCompanion entry) async {
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(entry);
  }

  Future<int> softDeleteAccount(String accountId) async {
    await (update(accounts)..where((a) => a.id.equals(accountId)))
        .write(const AccountsCompanion(isActive: Value(false)));
    return 1;
  }

  // ---- Transfer CRUD ----

  Future<int> insertTransfer(TransfersCompanion entry) =>
      into(transfers).insert(entry);

  Future<List<Transfer>> getRecentTransfers(String userId, int limit) =>
      (select(transfers)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .get();

  // ---- Budget CRUD ----

  Future<int> insertBudget(BudgetsCompanion entry) =>
      into(budgets).insert(entry);

  Future<Budget?> getBudgetByMonth(String userId, int year, int month) =>
      (select(budgets)
            ..where((b) =>
                b.userId.equals(userId) &
                b.year.equals(year) &
                b.month.equals(month)))
          .getSingleOrNull();

  Future<Budget?> getBudgetById(String id) =>
      (select(budgets)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<List<Budget>> getBudgetsByYear(String userId, int year) =>
      (select(budgets)
            ..where((b) => b.userId.equals(userId) & b.year.equals(year))
            ..orderBy([(b) => OrderingTerm.asc(b.month)]))
          .get();

  Future<bool> updateBudget(BudgetsCompanion entry) =>
      update(budgets).replace(entry);

  Future<int> deleteBudget(String id) =>
      (delete(budgets)..where((b) => b.id.equals(id))).go();

  // Category Budgets
  Future<int> insertCategoryBudget(CategoryBudgetsTableCompanion entry) =>
      into(categoryBudgetsTable).insert(entry);

  Future<List<CategoryBudgetsTableData>> getCategoryBudgets(String budgetId) =>
      (select(categoryBudgetsTable)
            ..where((cb) => cb.budgetId.equals(budgetId)))
          .get();

  Future<int> deleteCategoryBudgets(String budgetId) =>
      (delete(categoryBudgetsTable)
            ..where((cb) => cb.budgetId.equals(budgetId)))
          .go();

  /// Get expense sum per category for a given month
  Future<Map<String, int>> getMonthCategoryExpenses(
      String userId, int year, int month) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth =
        DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1));
    final rows = await (select(transactions)
          ..where((t) =>
              t.userId.equals(userId) &
              t.type.equals('expense') &
              t.txnDate.isBiggerOrEqualValue(startOfMonth) &
              t.txnDate.isSmallerOrEqualValue(endOfMonth)))
        .get();
    final map = <String, int>{};
    for (final t in rows) {
      map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amountCny;
    }
    return map;
  }

  // ---- Notification CRUD ----

  Future<int> insertNotification(NotificationsCompanion entry) =>
      into(notifications).insert(entry);

  Future<List<Notification>> getNotifications(
      String userId, int limit, int offset) =>
      (select(notifications)
            ..where((n) => n.userId.equals(userId))
            ..orderBy([(n) => OrderingTerm.desc(n.createdAt)])
            ..limit(limit, offset: offset))
          .get();

  Future<int> getUnreadNotificationCount(String userId) async {
    final rows = await (select(notifications)
          ..where(
              (n) => n.userId.equals(userId) & n.isRead.equals(false)))
        .get();
    return rows.length;
  }

  Future<void> markNotificationsAsRead(List<String> ids) async {
    await (update(notifications)..where((n) => n.id.isIn(ids)))
        .write(const NotificationsCompanion(isRead: Value(true)));
  }

  // Notification Settings
  Future<NotificationSettingsTableData?> getNotificationSettings(
          String userId) =>
      (select(notificationSettingsTable)
            ..where((s) => s.userId.equals(userId)))
          .getSingleOrNull();

  Future<void> upsertNotificationSettings(
      NotificationSettingsTableCompanion entry) async {
    await into(notificationSettingsTable).insertOnConflictUpdate(entry);
  }

  // ---- Loan CRUD ----

  Future<int> insertLoan(LoansCompanion entry) =>
      into(loans).insert(entry);

  Future<void> upsertLoan(LoansCompanion entry) async {
    await into(loans).insertOnConflictUpdate(entry);
  }

  Future<List<Loan>> getLoans(String userId) =>
      (select(loans)
            ..where((l) => l.userId.equals(userId) & l.deletedAt.isNull())
            ..orderBy([(l) => OrderingTerm.desc(l.createdAt)]))
          .get();

  Future<Loan?> getLoanById(String id) =>
      (select(loans)..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<void> updateLoanFields(String loanId, LoansCompanion entry) async {
    await (update(loans)..where((l) => l.id.equals(loanId))).write(entry);
  }

  Future<int> softDeleteLoan(String loanId) async {
    await (update(loans)..where((l) => l.id.equals(loanId))).write(
      LoansCompanion(deletedAt: Value(DateTime.now())),
    );
    return 1;
  }

  // Loan Schedules
  Future<void> insertLoanSchedule(LoanSchedulesCompanion entry) async {
    await into(loanSchedules).insert(entry);
  }

  Future<void> upsertLoanSchedule(LoanSchedulesCompanion entry) async {
    await into(loanSchedules).insertOnConflictUpdate(entry);
  }

  Future<List<LoanSchedule>> getLoanSchedules(String loanId) =>
      (select(loanSchedules)
            ..where((s) => s.loanId.equals(loanId))
            ..orderBy([(s) => OrderingTerm.asc(s.monthNumber)]))
          .get();

  Future<void> deleteLoanSchedules(String loanId) async {
    await (delete(loanSchedules)..where((s) => s.loanId.equals(loanId))).go();
  }

  Future<void> markSchedulePaid(String scheduleId) async {
    await (update(loanSchedules)..where((s) => s.id.equals(scheduleId))).write(
      LoanSchedulesCompanion(
        isPaid: const Value(true),
        paidDate: Value(DateTime.now()),
      ),
    );
  }

  // Loan Rate Changes
  Future<int> insertLoanRateChange(LoanRateChangesCompanion entry) =>
      into(loanRateChanges).insert(entry);

  Future<List<LoanRateChange>> getLoanRateChanges(String loanId) =>
      (select(loanRateChanges)
            ..where((r) => r.loanId.equals(loanId))
            ..orderBy([(r) => OrderingTerm.desc(r.effectiveDate)]))
          .get();

  // ---- Investment CRUD ----

  Future<void> upsertInvestment(InvestmentsCompanion entry) async {
    await into(investments).insertOnConflictUpdate(entry);
  }

  Future<List<Investment>> getInvestments(String userId) =>
      (select(investments)
            ..where((i) => i.userId.equals(userId) & i.deletedAt.isNull())
            ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]))
          .get();

  Future<Investment?> getInvestmentById(String id) =>
      (select(investments)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<void> updateInvestmentFields(String id, InvestmentsCompanion entry) async {
    await (update(investments)..where((i) => i.id.equals(id))).write(entry);
  }

  Future<int> softDeleteInvestment(String id) async {
    await (update(investments)..where((i) => i.id.equals(id))).write(
      InvestmentsCompanion(deletedAt: Value(DateTime.now())),
    );
    return 1;
  }

  // Investment Trades
  Future<int> insertInvestmentTrade(InvestmentTradesCompanion entry) =>
      into(investmentTrades).insert(entry);

  Future<List<InvestmentTrade>> getInvestmentTrades(String investmentId) =>
      (select(investmentTrades)
            ..where((t) => t.investmentId.equals(investmentId))
            ..orderBy([(t) => OrderingTerm.desc(t.tradeDate)]))
          .get();

  // Market Quotes cache
  Future<void> upsertMarketQuote(MarketQuotesCompanion entry) async {
    await into(marketQuotes).insertOnConflictUpdate(entry);
  }

  Future<MarketQuote?> getMarketQuote(String symbol, String marketType) =>
      (select(marketQuotes)
            ..where((q) => q.symbol.equals(symbol) & q.marketType.equals(marketType)))
          .getSingleOrNull();

  Future<List<MarketQuote>> getAllMarketQuotes() =>
      select(marketQuotes).get();

  // ---- Fixed Asset CRUD ----

  Future<void> upsertFixedAsset(FixedAssetsCompanion entry) async {
    await into(fixedAssets).insertOnConflictUpdate(entry);
  }

  Future<List<FixedAsset>> getFixedAssets(String userId) =>
      (select(fixedAssets)
            ..where((a) => a.userId.equals(userId) & a.deletedAt.isNull())
            ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
          .get();

  Future<FixedAsset?> getFixedAssetById(String id) =>
      (select(fixedAssets)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<void> updateFixedAssetFields(String id, FixedAssetsCompanion entry) async {
    await (update(fixedAssets)..where((a) => a.id.equals(id))).write(entry);
  }

  Future<int> softDeleteFixedAsset(String id) async {
    await (update(fixedAssets)..where((a) => a.id.equals(id))).write(
      FixedAssetsCompanion(deletedAt: Value(DateTime.now())),
    );
    return 1;
  }

  // Asset Valuations
  Future<int> insertAssetValuation(AssetValuationsCompanion entry) =>
      into(assetValuations).insert(entry);

  Future<List<AssetValuation>> getAssetValuations(String assetId) =>
      (select(assetValuations)
            ..where((v) => v.assetId.equals(assetId))
            ..orderBy([(v) => OrderingTerm.asc(v.valuationDate)]))
          .get();

  // Depreciation Rules
  Future<void> upsertDepreciationRule(DepreciationRulesCompanion entry) async {
    await into(depreciationRules).insertOnConflictUpdate(entry);
  }

  Future<DepreciationRule?> getDepreciationRule(String assetId) =>
      (select(depreciationRules)
            ..where((r) => r.assetId.equals(assetId))
            ..orderBy([(r) => OrderingTerm.desc(r.createdAt)])
            ..limit(1))
          .getSingleOrNull();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'familyledger.db'));
    return NativeDatabase.createInBackground(file);
  });
}
