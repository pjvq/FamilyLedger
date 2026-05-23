import 'package:drift/drift.dart';

import 'core_tables.dart';

/// 预算表
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get familyId => text().withDefault(const Constant(''))();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  IntColumn get totalAmount => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 分类预算表
class CategoryBudgetsTable extends Table {
  @override
  String get tableName => 'category_budgets';

  TextColumn get id => text()();
  TextColumn get budgetId => text().references(Budgets, #id)();
  TextColumn get categoryId => text()();
  IntColumn get amount => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 通知表
class Notifications extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get dataJson => text().withDefault(const Constant(''))();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 通知设置表
class NotificationSettingsTable extends Table {
  @override
  String get tableName => 'notification_settings';

  TextColumn get userId => text().references(Users, #id)();
  BoolColumn get budgetAlert => boolean().withDefault(const Constant(true))();
  BoolColumn get budgetWarning => boolean().withDefault(const Constant(true))();
  BoolColumn get dailySummary => boolean().withDefault(const Constant(false))();
  BoolColumn get loanReminder => boolean().withDefault(const Constant(true))();
  IntColumn get reminderDaysBefore => integer().withDefault(const Constant(3))();

  @override
  Set<Column> get primaryKey => {userId};
}

/// 离线同步队列
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get opType => text()(); // create, update, delete
  TextColumn get payload => text()();
  TextColumn get clientId => text()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get uploaded => boolean().withDefault(const Constant(false))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 汇率缓存表
class ExchangeRates extends Table {
  @override
  String get tableName => 'exchange_rates';

  TextColumn get currencyPair => text()();
  RealColumn get rate => real()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {currencyPair};
}

/// Dead-letter table for malformed ops that failed during pull.
/// Stores ops that could not be applied so sync can continue.
/// Periodically retried (may succeed after app update fixes the handler).
class SyncDeadLetters extends Table {
  @override
  String get tableName => 'sync_dead_letter';

  TextColumn get opId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  /// Original proto opType (e.g. 'OPERATION_TYPE_CREATE').
  TextColumn get opType => text()();
  /// Original operation timestamp in milliseconds since epoch.
  IntColumn get timestampMs => integer().withDefault(const Constant(0))();
  TextColumn get error => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  /// Next allowed retry time (NOT "last retry time"). Null = immediately eligible.
  DateTimeColumn get nextRetryAfter => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {opId};
}

/// Simple key-value table for sync metadata (e.g. lastSyncTs).
/// Stored in SQLite so it can participate in the same transaction as ops.
class SyncMetadata extends Table {
  @override
  String get tableName => 'sync_metadata';

  TextColumn get key => text()();
  IntColumn get value => integer()();

  @override
  Set<Column> get primaryKey => {key};
}
