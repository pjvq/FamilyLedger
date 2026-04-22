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
  SyncQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Seed preset categories
          await _seedCategories();
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'familyledger.db'));
    return NativeDatabase.createInBackground(file);
  });
}
