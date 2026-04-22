import 'package:drift/drift.dart';

/// 用户表
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 资金账户表
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get icon => text().withDefault(const Constant('💳'))();
  IntColumn get balance => integer().withDefault(const Constant(0))(); // 分
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 分类表
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get icon => text()();
  TextColumn get type => text()(); // 'income' | 'expense'
  BoolColumn get isPreset => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 交易记录表
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get amount => integer()(); // 原始金额（分）
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  IntColumn get amountCny => integer()(); // 人民币（分）
  RealColumn get exchangeRate =>
      real().withDefault(const Constant(1.0))();
  TextColumn get type => text()(); // 'income' | 'expense'
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get txnDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 离线同步队列
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()(); // 'transaction', 'account', 'category'
  TextColumn get entityId => text()();
  TextColumn get opType => text()(); // 'create', 'update', 'delete'
  TextColumn get payload => text()(); // JSON
  TextColumn get clientId => text()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get uploaded => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
