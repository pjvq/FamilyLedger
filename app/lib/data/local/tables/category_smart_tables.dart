import 'package:drift/drift.dart';

import 'core_tables.dart';

/// 分类使用分布槽位（拆行模型，原子更新）
/// slot_type: 'hour' (0-23), 'weekday' (0-6), 'amount' (0-5)
class CategoryUsageSlots extends Table {
  @override
  String get tableName => 'category_usage_slots';

  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get slotType => text()(); // 'hour' | 'weekday' | 'amount'
  IntColumn get slotIndex =>
      integer()(); // hour: 0-23, weekday: 0-6, amount: 0-5
  IntColumn get count => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {categoryId, slotType, slotIndex};
}

/// 分类使用摘要（低频更新字段）
class CategoryUsageSummary extends Table {
  @override
  String get tableName => 'category_usage_summary';

  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get totalCount => integer().withDefault(const Constant(0))();
  IntColumn get last30dCount => integer().withDefault(const Constant(0))();
  IntColumn get last7dCount => integer().withDefault(const Constant(0))();
  TextColumn get topKeywords =>
      text().withDefault(const Constant('[]'))(); // JSON array
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {categoryId};
}

/// 分类合并日志（支持 7 天撤销）
/// 注意：撤销时必须检查 targetCategoryId 是否仍存在，
/// 若 target 已被删除则撤销失败（抛 UndoTargetDeletedException）
class CategoryMergeLog extends Table {
  @override
  String get tableName => 'category_merge_log';

  TextColumn get id => text()();
  TextColumn get sourceCategoryId => text()();
  TextColumn get targetCategoryId => text()();
  TextColumn get sourceCategoryName => text()(); // 留存名字用于撤销重建
  TextColumn get sourceIconKey => text().withDefault(const Constant(''))();
  TextColumn get sourceParentId => text().nullable()();
  IntColumn get affectedCount => integer().withDefault(const Constant(0))();

  /// JSON array of child category IDs that were reparented during merge
  TextColumn get reparentedChildIds =>
      text().withDefault(const Constant('[]'))();

  /// simple / crossParent / parentMerge / moveOnly
  TextColumn get mergeType => text().withDefault(const Constant('simple'))();
  DateTimeColumn get mergedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get undoneAt => dateTime().nullable()(); // 非空=已撤销
  DateTimeColumn get expiresAt => dateTime()(); // mergedAt + 7 days

  @override
  Set<Column> get primaryKey => {id};
}

/// 用户已忽略的合并建议对（30 天内不再提示）
class CategoryMergeDismissals extends Table {
  @override
  String get tableName => 'category_merge_dismissals';

  TextColumn get id => text()();

  /// 字典序排列的两个 categoryId，用 '|' 分隔
  TextColumn get pairKey => text().unique()();
  DateTimeColumn get dismissedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// dismissedAt + 30 days
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
