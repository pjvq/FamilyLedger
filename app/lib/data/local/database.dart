import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/category_uuid.dart';
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
  LoanGroups,
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
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Seed preset categories + subcategories
          await _seedCategories();
          await _seedSubcategories();
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
          if (from < 8) {
            // v7 → v8: loan groups table + loans new columns + sync queue
            await m.createTable(loanGroups);
            await m.addColumn(loans, loans.groupId);
            await m.addColumn(loans, loans.subType);
            await m.addColumn(loans, loans.rateType);
            await m.addColumn(loans, loans.lprBase);
            await m.addColumn(loans, loans.lprSpread);
            await m.addColumn(loans, loans.rateAdjustMonth);
            await m.createTable(syncQueue);
          }
          if (from < 9) {
            // v8 → v9: add deletedAt to transactions for soft-delete
            await m.addColumn(transactions, transactions.deletedAt);
          }
          if (from < 10) {
            // v9 → v10: migrate category IDs from cat_xxx strings to UUID v5
            await _migrateCategoryUUIDs();
          }
          if (from < 11) {
            // v10 → v11: add subcategory support to categories
            await m.addColumn(categories, categories.parentId);
            await m.addColumn(categories, categories.userId);
            await m.addColumn(categories, categories.iconKey);
            await m.addColumn(categories, categories.deletedAt);
            // Seed subcategories
            await _seedSubcategories();
          }
        },
        beforeOpen: (details) async {
          // One-time cleanup: deduplicate categories created by import
          await _deduplicateCategories();
          // Backfill iconKey for preset parent categories that were seeded without it
          await _backfillParentIconKeys();
        },
      );

  /// Remove duplicate categories (same name+type+parentId).
  /// Keeps the one with isPreset=true, or earliest createdAt.
  /// Reassigns transactions from removed duplicates to the keeper.
  Future<void> _deduplicateCategories() async {
    final allCats = await (select(categories)
          ..where((c) => c.deletedAt.isNull()))
        .get();

    // Phase 1: Merge orphan top-level categories into existing subcategories.
    // e.g. import created "衣服" (parentId=null, iconKey='') but seed already
    // has "衣服" as a child of "服饰" (parentId!=null, iconKey='clothing_clothes').
    // Move transactions from the orphan to the real subcategory, then delete orphan.
    final byNameType = <String, List<Category>>{};
    for (final c in allCats) {
      byNameType.putIfAbsent('${c.name}|${c.type}', () => []).add(c);
    }
    for (final group in byNameType.values) {
      if (group.length < 2) continue;
      final orphans = group.where((c) => c.parentId == null && !c.isPreset).toList();
      final subs = group.where((c) => c.parentId != null).toList();
      if (orphans.isEmpty || subs.isEmpty) continue;
      // Prefer preset subcategory as keeper
      subs.sort((a, b) {
        if (a.isPreset && !b.isPreset) return -1;
        if (!a.isPreset && b.isPreset) return 1;
        return a.sortOrder.compareTo(b.sortOrder);
      });
      final keeper = subs.first;
      for (final orphan in orphans) {
        await (update(transactions)..where((t) => t.categoryId.equals(orphan.id)))
            .write(TransactionsCompanion(categoryId: Value(keeper.id)));
        await (update(categories)..where((c) => c.parentId.equals(orphan.id)))
            .write(CategoriesCompanion(parentId: Value(keeper.id)));
        await (delete(categories)..where((c) => c.id.equals(orphan.id))).go();
      }
    }

    // Phase 2: Standard dedup — same (name, type, parentId)
    // Re-fetch after Phase 1 mutations
    final remaining = await (select(categories)
          ..where((c) => c.deletedAt.isNull()))
        .get();
    final groups = <String, List<Category>>{};
    for (final c in remaining) {
      final key = '${c.name}|${c.type}|${c.parentId ?? ""}';
      groups.putIfAbsent(key, () => []).add(c);
    }

    for (final group in groups.values) {
      if (group.length <= 1) continue;

      // Pick keeper: prefer isPreset, then smallest sortOrder (preset=small, import=999)
      group.sort((a, b) {
        if (a.isPreset && !b.isPreset) return -1;
        if (!a.isPreset && b.isPreset) return 1;
        return a.sortOrder.compareTo(b.sortOrder);
      });
      final keeper = group.first;
      final duplicates = group.skip(1).toList();

      for (final dup in duplicates) {
        // Reassign transactions
        await (update(transactions)..where((t) => t.categoryId.equals(dup.id)))
            .write(TransactionsCompanion(categoryId: Value(keeper.id)));
        // Reassign child categories
        await (update(categories)..where((c) => c.parentId.equals(dup.id)))
            .write(CategoriesCompanion(parentId: Value(keeper.id)));
        // Delete duplicate
        await (delete(categories)..where((c) => c.id.equals(dup.id))).go();
      }
    }
  }

  Future<void> _backfillParentIconKeys() async {
    const nameToIconKey = {
      // Expense
      '餐饮': 'food',
      '交通': 'transport',
      '购物': 'shopping',
      '居住': 'housing',
      '娱乐': 'entertainment',
      '医疗': 'medical',
      '教育': 'education',
      '通讯': 'communication',
      '人情': 'gift',
      '服饰': 'clothing',
      '日用': 'daily',
      '旅行': 'travel',
      '宠物': 'pet',
      // Income
      '工资': 'salary',
      '奖金': 'bonus',
      '投资收益': 'investment_income',
      '兼职': 'freelance',
      '红包': 'red_packet',
      '报销': 'reimbursement',
      '其他': 'other',
    };
    final parents = await (select(categories)
          ..where((c) => c.parentId.isNull() & c.iconKey.equals('')))
        .get();
    for (final cat in parents) {
      final key = nameToIconKey[cat.name];
      if (key != null) {
        await (update(categories)..where((c) => c.id.equals(cat.id)))
            .write(CategoriesCompanion(iconKey: Value(key)));
      }
    }
  }

  Future<void> _seedCategories() async {
    final presets = [
      // Expense
      _cat(CategoryUUID.generate('expense', '餐饮'), '餐饮', '🍜', 'expense', true, 1, 'food'),
      _cat(CategoryUUID.generate('expense', '交通'), '交通', '🚗', 'expense', true, 2, 'transport'),
      _cat(CategoryUUID.generate('expense', '购物'), '购物', '🛍️', 'expense', true, 3, 'shopping'),
      _cat(CategoryUUID.generate('expense', '居住'), '居住', '🏠', 'expense', true, 4, 'housing'),
      _cat(CategoryUUID.generate('expense', '娱乐'), '娱乐', '🎮', 'expense', true, 5, 'entertainment'),
      _cat(CategoryUUID.generate('expense', '医疗'), '医疗', '🏥', 'expense', true, 6, 'medical'),
      _cat(CategoryUUID.generate('expense', '教育'), '教育', '📚', 'expense', true, 7, 'education'),
      _cat(CategoryUUID.generate('expense', '通讯'), '通讯', '📱', 'expense', true, 8, 'communication'),
      _cat(CategoryUUID.generate('expense', '人情'), '人情', '🎁', 'expense', true, 9, 'gift'),
      _cat(CategoryUUID.generate('expense', '服饰'), '服饰', '👔', 'expense', true, 10, 'clothing'),
      _cat(CategoryUUID.generate('expense', '日用'), '日用', '🧴', 'expense', true, 11, 'daily'),
      _cat(CategoryUUID.generate('expense', '旅行'), '旅行', '✈️', 'expense', true, 12, 'travel'),
      _cat(CategoryUUID.generate('expense', '宠物'), '宠物', '🐱', 'expense', true, 13, 'pet'),
      _cat(CategoryUUID.generate('expense', '其他'), '其他', '📦', 'expense', true, 14, 'other'),
      // Income
      _cat(CategoryUUID.generate('income', '工资'), '工资', '💰', 'income', true, 1, 'salary'),
      _cat(CategoryUUID.generate('income', '奖金'), '奖金', '🏆', 'income', true, 2, 'bonus'),
      _cat(CategoryUUID.generate('income', '投资收益'), '投资收益', '📈', 'income', true, 3, 'investment_income'),
      _cat(CategoryUUID.generate('income', '兼职'), '兼职', '💼', 'income', true, 4, 'freelance'),
      _cat(CategoryUUID.generate('income', '红包'), '红包', '🧧', 'income', true, 5, 'red_packet'),
      _cat(CategoryUUID.generate('income', '报销'), '报销', '🧾', 'income', true, 6, 'reimbursement'),
      _cat(CategoryUUID.generate('income', '其他'), '其他', '💵', 'income', true, 7, 'other'),
    ];
    await batch((b) {
      b.insertAllOnConflictUpdate(categories, presets);
    });
  }

  CategoriesCompanion _cat(
          String id, String name, String icon, String type, bool isPreset, int sort, [String iconKey = '']) =>
      CategoriesCompanion.insert(
        id: id,
        name: name,
        icon: icon,
        type: type,
        isPreset: Value(isPreset),
        sortOrder: Value(sort),
        iconKey: Value(iconKey),
      );

  CategoriesCompanion _subcat(
          String parentType, String parentName, String childName, String iconKey, int sort) {
    final id = CategoryUUID.generate(parentType, '$parentName/$childName');
    final parentId = CategoryUUID.generate(parentType, parentName);
    return CategoriesCompanion.insert(
      id: id,
      name: childName,
      icon: '',
      type: parentType,
      isPreset: const Value(true),
      sortOrder: Value(sort),
      parentId: Value(parentId),
      iconKey: Value(iconKey),
    );
  }

  Future<void> _seedSubcategories() async {
    final subs = [
      // 餐饮
      _subcat('expense', '餐饮', '早餐', 'food_breakfast', 1),
      _subcat('expense', '餐饮', '午餐', 'food_lunch', 2),
      _subcat('expense', '餐饮', '晚餐', 'food_dinner', 3),
      _subcat('expense', '餐饮', '夜宵', 'food_midnight', 4),
      _subcat('expense', '餐饮', '饮品', 'food_drink', 5),
      _subcat('expense', '餐饮', '水果零食', 'food_snack', 6),
      // 交通
      _subcat('expense', '交通', '地铁公交', 'transport_metro', 1),
      _subcat('expense', '交通', '打车', 'transport_taxi', 2),
      _subcat('expense', '交通', '加油', 'transport_fuel', 3),
      _subcat('expense', '交通', '停车', 'transport_parking', 4),
      // 购物
      _subcat('expense', '购物', '电器数码', 'shopping_digital', 1),
      _subcat('expense', '购物', '日用百货', 'shopping_daily', 2),
      _subcat('expense', '购物', '美妆护肤', 'shopping_beauty', 3),
      // 居住
      _subcat('expense', '居住', '房租', 'housing_rent', 1),
      _subcat('expense', '居住', '物业', 'housing_property', 2),
      _subcat('expense', '居住', '水电燃气', 'housing_utility', 3),
      _subcat('expense', '居住', '家政服务', 'housing_cleaning', 4),
      // 娱乐
      _subcat('expense', '娱乐', '电影演出', 'entertainment_movie', 1),
      _subcat('expense', '娱乐', '游戏', 'entertainment_game', 2),
      _subcat('expense', '娱乐', '运动健身', 'entertainment_sport', 3),
      _subcat('expense', '娱乐', '书籍', 'entertainment_book', 4),
      // 医疗
      _subcat('expense', '医疗', '门诊', 'medical_clinic', 1),
      _subcat('expense', '医疗', '住院', 'medical_hospital', 2),
      _subcat('expense', '医疗', '买药', 'medical_pharmacy', 3),
      _subcat('expense', '医疗', '保健', 'medical_health', 4),
      // 教育
      _subcat('expense', '教育', '培训课程', 'education_course', 1),
      _subcat('expense', '教育', '书籍资料', 'education_book', 2),
      _subcat('expense', '教育', '学费', 'education_tuition', 3),
      // 通讯
      _subcat('expense', '通讯', '话费', 'communication_phone', 1),
      _subcat('expense', '通讯', '宽带', 'communication_broadband', 2),
      _subcat('expense', '通讯', '会员订阅', 'communication_subscription', 3),
      // 人情
      _subcat('expense', '人情', '红包礼金', 'gift_red_packet', 1),
      _subcat('expense', '人情', '请客', 'gift_treat', 2),
      _subcat('expense', '人情', '份子钱', 'gift_wedding', 3),
      // 服饰
      _subcat('expense', '服饰', '衣服', 'clothing_clothes', 1),
      _subcat('expense', '服饰', '鞋包', 'clothing_shoes', 2),
      _subcat('expense', '服饰', '配饰', 'clothing_accessory', 3),
      // 日用
      _subcat('expense', '日用', '清洁用品', 'daily_cleaning', 1),
      _subcat('expense', '日用', '个人护理', 'daily_personal', 2),
      // 旅行
      _subcat('expense', '旅行', '住宿', 'travel_hotel', 1),
      _subcat('expense', '旅行', '机票火车', 'travel_ticket', 2),
      _subcat('expense', '旅行', '门票景点', 'travel_attraction', 3),
      // 宠物
      _subcat('expense', '宠物', '口粮用品', 'pet_food', 1),
      _subcat('expense', '宠物', '宠物医疗', 'pet_medical', 2),
      // 收入
      _subcat('income', '工资', '基本工资', 'salary_base', 1),
      _subcat('income', '工资', '绩效', 'salary_performance', 2),
      _subcat('income', '工资', '加班费', 'salary_overtime', 3),
      _subcat('income', '奖金', '年终奖', 'bonus_annual', 1),
      _subcat('income', '奖金', '项目奖', 'bonus_project', 2),
      _subcat('income', '投资收益', '股票', 'investment_stock', 1),
      _subcat('income', '投资收益', '基金', 'investment_fund', 2),
      _subcat('income', '投资收益', '利息', 'investment_interest', 3),
    ];
    await batch((b) {
      b.insertAllOnConflictUpdate(categories, subs);
    });
  }

  Future<void> _migrateCategoryUUIDs() async {
    // Map of old string IDs to (type, name) for UUID generation
    const oldToTypeAndName = {
      'cat_food': ('expense', '餐饮'),
      'cat_transport': ('expense', '交通'),
      'cat_shopping': ('expense', '购物'),
      'cat_housing': ('expense', '居住'),
      'cat_entertainment': ('expense', '娱乐'),
      'cat_medical': ('expense', '医疗'),
      'cat_education': ('expense', '教育'),
      'cat_telecom': ('expense', '通讯'),
      'cat_social': ('expense', '人情'),
      'cat_clothing': ('expense', '服饰'),
      'cat_daily': ('expense', '日用'),
      'cat_travel': ('expense', '旅行'),
      'cat_pet': ('expense', '宠物'),
      'cat_other_exp': ('expense', '其他'),
      'cat_salary': ('income', '工资'),
      'cat_bonus': ('income', '奖金'),
      'cat_investment': ('income', '投资收益'),
      'cat_sidejob': ('income', '兼职'),
      'cat_redpacket': ('income', '红包'),
      'cat_reimburse': ('income', '报销'),
      'cat_other_inc': ('income', '其他'),
    };

    for (final entry in oldToTypeAndName.entries) {
      final oldId = entry.key;
      final (type, name) = entry.value;
      final newId = CategoryUUID.generate(type, name);
      // Update transactions referencing old category ID
      await customStatement(
          'UPDATE transactions SET category_id = ? WHERE category_id = ?',
          [newId, oldId]);
      // Update category_budgets if they reference old ID
      await customStatement(
          'UPDATE category_budgets SET category_id = ? WHERE category_id = ?',
          [newId, oldId]);
      // Update the category itself
      await customStatement(
          'UPDATE categories SET id = ? WHERE id = ?', [newId, oldId]);
    }
  }

  // ---- Queries ----

  // Accounts
  Future<List<Account>> getAllAccounts(String userId) =>
      (select(accounts)..where((a) => a.userId.equals(userId))).get();

  Future<Account?> getDefaultAccount(String userId, {String? familyId}) {
    if (familyId != null && familyId.isNotEmpty) {
      return (select(accounts)
            ..where((a) => a.familyId.equals(familyId) & a.isActive.equals(true))
            ..limit(1))
          .getSingleOrNull();
    }
    return (select(accounts)
          ..where((a) => a.userId.equals(userId) &
              (a.familyId.equals('') | a.familyId.isNull()) &
              a.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> insertAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry, mode: InsertMode.insertOrReplace);

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
      String userId, int limit, {String? familyId}) async {
    if (familyId != null && familyId.isNotEmpty) {
      // Family mode: get family account IDs, then filter all transactions
      final familyAccounts = await getAccountsByFamily(familyId);
      final familyAccountIds = familyAccounts.map((a) => a.id).toSet();
      final rows = await (select(transactions)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.txnDate)]))
          .get();
      return rows
          .where((t) => familyAccountIds.contains(t.accountId))
          .take(limit)
          .toList();
    }
    // Personal mode: exclude family accounts
    final familyAccountIds = await _getFamilyAccountIds(userId);
    final rows = await (select(transactions)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.txnDate)])
          ..limit(limit * 2))
        .get();
    return rows
        .where((t) => !familyAccountIds.contains(t.accountId))
        .take(limit)
        .toList();
  }

  Future<Set<String>> _getFamilyAccountIds(String userId) async {
    final rows = await (select(accounts)
          ..where((a) =>
              a.userId.equals(userId) &
              a.familyId.isNotNull() &
              a.familyId.equals('').not()))
        .get();
    return rows.map((a) => a.id).toSet();
  }

  Future<int> insertTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry, mode: InsertMode.insertOrReplace);

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

  /// 软删除交易记录
  Future<int> softDeleteTransaction(String id) async {
    return (update(transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(deletedAt: Value(DateTime.now())));
  }

  /// 硬删除（仅供远程同步清理用）
  Future<int> hardDeleteTransaction(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  /// 根据 ID 查找单条交易
  Future<Transaction?> getTransactionById(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// 更新交易的指定字段
  Future<void> updateTransactionFields(
      String id, TransactionsCompanion entry) async {
    await (update(transactions)..where((t) => t.id.equals(id)))
        .write(entry);
  }

  Stream<List<Transaction>> watchTransactions(String userId, {String? familyId}) {
    if (familyId != null && familyId.isNotEmpty) {
      // Family mode: all transactions from family accounts (all members)
      return customSelect(
        'SELECT t.* FROM transactions t '
        'JOIN accounts a ON a.id = t.account_id '
        'WHERE t.deleted_at IS NULL AND a.family_id = ? '
        'ORDER BY t.txn_date DESC',
        variables: [Variable.withString(familyId)],
        readsFrom: {transactions, accounts},
      ).watch().map((rows) => rows.map((row) {
        return transactions.map(row.data);
      }).toList());
    }
    // Personal mode: only transactions from personal accounts (no family)
    return customSelect(
      'SELECT t.* FROM transactions t '
      'JOIN accounts a ON a.id = t.account_id '
      'WHERE t.user_id = ? AND t.deleted_at IS NULL AND (a.family_id IS NULL OR a.family_id = \'\') '
      'ORDER BY t.txn_date DESC',
      variables: [Variable.withString(userId)],
      readsFrom: {transactions, accounts},
    ).watch().map((rows) => rows.map((row) {
      return transactions.map(row.data);
    }).toList());
  }

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
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull()))
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
              t.txnDate.isBiggerOrEqualValue(startOfDay) &
              t.deletedAt.isNull()))
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
              t.txnDate.isBiggerOrEqualValue(startOfMonth) &
              t.deletedAt.isNull()))
        .get();
    return rows.fold<int>(0, (sum, t) => sum + t.amountCny);
  }

  // ---- Family CRUD ----

  Future<List<Family>> getAllFamilies() =>
      select(families).get();

  Future<Family?> getFamilyById(String id) =>
      (select(families)..where((f) => f.id.equals(id))).getSingleOrNull();

  Future<int> insertFamily(FamiliesCompanion entry) =>
      into(families).insert(entry, mode: InsertMode.insertOrReplace);

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
      into(familyMembers).insert(entry, mode: InsertMode.insertOrReplace);

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
      (select(accounts)..where((a) => a.userId.equals(userId) & a.isActive.equals(true) & (a.familyId.equals('') | a.familyId.isNull()))).get();

  Future<Account?> getAccountById(String accountId) =>
      (select(accounts)..where((a) => a.id.equals(accountId))).getSingleOrNull();

  Future<void> updateAccountFields(String accountId, AccountsCompanion entry) async {
    await (update(accounts)..where((a) => a.id.equals(accountId))).write(entry);
  }

  /// Upsert account from remote sync payload.
  Future<void> upsertAccount({
    required String id,
    required String userId,
    required String name,
    String accountType = 'other',
    String icon = '💳',
    int balance = 0,
    String currency = 'CNY',
    bool isActive = true,
  }) async {
    final existing = await getAccountById(id);
    if (existing != null) {
      await (update(accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(
          name: Value(name),
          accountType: Value(accountType),
          icon: Value(icon),
          balance: Value(balance),
          currency: Value(currency),
          isActive: Value(isActive),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } else {
      await into(accounts).insert(AccountsCompanion.insert(
        id: id,
        userId: userId,
        name: name,
        accountType: Value(accountType),
        icon: Value(icon),
        balance: Value(balance),
        currency: Value(currency),
        isActive: Value(isActive),
      ));
    }
  }

  /// Upsert category from remote sync payload.
  Future<void> upsertCategory({
    required String id,
    required String name,
    required String icon,
    required String type,
    bool isPreset = false,
    int sortOrder = 0,
    String? parentId,
    String? userId,
    String iconKey = '',
  }) async {
    final existing = await (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();
    if (existing != null) {
      await (update(categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(name),
          icon: Value(icon),
          iconKey: Value(iconKey),
          type: Value(type),
          sortOrder: Value(sortOrder),
          parentId: Value(parentId),
          deletedAt: const Value(null), // un-delete if re-synced
        ),
      );
    } else {
      await into(categories).insert(CategoriesCompanion.insert(
        id: id,
        name: name,
        icon: icon,
        iconKey: Value(iconKey),
        type: type,
        isPreset: Value(isPreset),
        sortOrder: Value(sortOrder),
        parentId: Value(parentId),
        userId: Value(userId),
      ));
    }
  }

  Future<int> softDeleteAccount(String accountId) async {
    await (update(accounts)..where((a) => a.id.equals(accountId)))
        .write(const AccountsCompanion(isActive: Value(false)));
    return 1;
  }

  Future<void> softDeleteCategory(String categoryId) async {
    final now = DateTime.now();
    // Soft delete the category and its children
    await (update(categories)..where((c) => c.id.equals(categoryId)))
        .write(CategoriesCompanion(deletedAt: Value(now)));
    await (update(categories)..where((c) => c.parentId.equals(categoryId)))
        .write(CategoriesCompanion(deletedAt: Value(now)));
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
      into(budgets).insert(entry, mode: InsertMode.insertOrReplace);

  Future<Budget?> getBudgetByMonth(String userId, int year, int month,
      {String familyId = ''}) async {
    final results = await (select(budgets)
          ..where((b) =>
              b.userId.equals(userId) &
              b.year.equals(year) &
              b.month.equals(month) &
              b.familyId.equals(familyId))
          ..orderBy([(b) => OrderingTerm.desc(b.updatedAt)])
          ..limit(1))
        .get();
    return results.firstOrNull;
  }

  Future<Budget?> getBudgetById(String id) =>
      (select(budgets)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<List<Budget>> getBudgetsByYear(String userId, int year,
      {String familyId = ''}) =>
      (select(budgets)
            ..where((b) => b.userId.equals(userId) &
                b.year.equals(year) &
                b.familyId.equals(familyId))
            ..orderBy([(b) => OrderingTerm.asc(b.month)]))
          .get();

  Future<bool> updateBudget(BudgetsCompanion entry) =>
      update(budgets).replace(entry);

  Future<int> deleteBudget(String id) =>
      (delete(budgets)..where((b) => b.id.equals(id))).go();

  /// Remove duplicate budgets for same user+year+month+familyId, keeping only
  /// the one with the given [keepId]. Call before insert to avoid duplicates.
  Future<void> deleteBudgetDuplicates(
      String userId, int year, int month, String familyId,
      {String? keepId}) async {
    final dupes = await (select(budgets)
          ..where((b) =>
              b.userId.equals(userId) &
              b.year.equals(year) &
              b.month.equals(month) &
              b.familyId.equals(familyId)))
        .get();
    for (final d in dupes) {
      if (d.id != keepId) {
        await deleteBudget(d.id);
        await deleteCategoryBudgets(d.id);
      }
    }
  }

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
      String userId, int year, int month, {String? familyId}) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth =
        DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1));

    // Use raw SQL to JOIN accounts for family filtering
    final isFamilyMode = familyId != null && familyId.isNotEmpty;
    final familyFilter = isFamilyMode
        ? "AND a.family_id = '" + familyId.replaceAll("'", "''") + "'"
        : "AND (a.family_id IS NULL OR a.family_id = '')";
    final userFilter = isFamilyMode ? '' : 'AND t.user_id = ?';
    final rows = await customSelect(
      'SELECT t.category_id, SUM(t.amount_cny) as total FROM transactions t '
      'JOIN accounts a ON a.id = t.account_id '
      'WHERE t.type = \'expense\' '
      '$userFilter '
      'AND t.txn_date >= ? AND t.txn_date <= ? '
      'AND t.deleted_at IS NULL '
      '$familyFilter '
      'GROUP BY t.category_id',
      variables: [
        if (!isFamilyMode) Variable.withString(userId),
        Variable.withDateTime(startOfMonth),
        Variable.withDateTime(endOfMonth),
      ],
      readsFrom: {transactions, accounts},
    ).get();
    final map = <String, int>{};
    for (final row in rows) {
      map[row.data['category_id'] as String] =
          (row.data['total'] as int?) ?? 0;
    }
    return map;
  }

  Future<Map<String, int>> getYearCategoryExpenses(
      String userId, int year, {String? familyId}) async {
    final startOfYear = DateTime(year, 1, 1);
    final endOfYear =
        DateTime(year + 1, 1, 1).subtract(const Duration(milliseconds: 1));

    final isFamilyMode = familyId != null && familyId.isNotEmpty;
    final familyFilter = isFamilyMode
        ? "AND a.family_id = '" + familyId.replaceAll("'", "''") + "'"
        : "AND (a.family_id IS NULL OR a.family_id = '')";
    final userFilter = isFamilyMode ? '' : 'AND t.user_id = ?';
    final rows = await customSelect(
      'SELECT t.category_id, SUM(t.amount_cny) as total FROM transactions t '
      'JOIN accounts a ON a.id = t.account_id '
      'WHERE t.type = \'expense\' '
      '$userFilter '
      'AND t.txn_date >= ? AND t.txn_date <= ? '
      'AND t.deleted_at IS NULL '
      '$familyFilter '
      'GROUP BY t.category_id',
      variables: [
        if (!isFamilyMode) Variable.withString(userId),
        Variable.withDateTime(startOfYear),
        Variable.withDateTime(endOfYear),
      ],
      readsFrom: {transactions, accounts},
    ).get();
    final map = <String, int>{};
    for (final row in rows) {
      map[row.data['category_id'] as String] =
          (row.data['total'] as int?) ?? 0;
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

  /// Get standalone loans (not in any group)
  Future<List<Loan>> getStandaloneLoans(String userId) =>
      (select(loans)
            ..where((l) =>
                l.userId.equals(userId) &
                l.deletedAt.isNull() &
                (l.groupId.equals('') | l.groupId.isNull()))
            ..orderBy([(l) => OrderingTerm.desc(l.createdAt)]))
          .get();

  /// Get loans belonging to a specific group
  Future<List<Loan>> getLoansByGroupId(String groupId) =>
      (select(loans)
            ..where((l) => l.groupId.equals(groupId) & l.deletedAt.isNull())
            ..orderBy([(l) => OrderingTerm.asc(l.createdAt)]))
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

  // ---- Loan Group CRUD ----

  Future<int> insertLoanGroup(LoanGroupsCompanion entry) =>
      into(loanGroups).insert(entry);

  Future<void> upsertLoanGroup(LoanGroupsCompanion entry) async {
    await into(loanGroups).insertOnConflictUpdate(entry);
  }

  Future<List<LoanGroup>> getLoanGroups(String userId) =>
      (select(loanGroups)
            ..where((g) => g.userId.equals(userId) & g.deletedAt.isNull())
            ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
          .get();

  Future<LoanGroup?> getLoanGroupById(String id) =>
      (select(loanGroups)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<void> updateLoanGroupFields(String groupId, LoanGroupsCompanion entry) async {
    await (update(loanGroups)..where((g) => g.id.equals(groupId))).write(entry);
  }

  Future<int> softDeleteLoanGroup(String groupId) async {
    await (update(loanGroups)..where((g) => g.id.equals(groupId))).write(
      LoanGroupsCompanion(deletedAt: Value(DateTime.now())),
    );
    // Also soft-delete all sub-loans
    await (update(loans)..where((l) => l.groupId.equals(groupId))).write(
      LoansCompanion(deletedAt: Value(DateTime.now())),
    );
    return 1;
  }

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

  /// Clear all data from all tables. Used on logout.
  Future<void> clearAllData() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'familyledger.db'));
    return NativeDatabase.createInBackground(file);
  });
}
