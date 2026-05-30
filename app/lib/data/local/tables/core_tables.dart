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
  TextColumn get familyId => text().withDefault(const Constant(''))();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get accountType => text().withDefault(const Constant('other'))(); // cash, bank_card, alipay, wechat, credit_card, investment, other
  TextColumn get icon => text().withDefault(const Constant('💳'))(); // emoji icon
  IntColumn get balance => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 分类表
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get type => text()(); // income, expense
  BoolColumn get isPreset => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get parentId => text().nullable().references(Categories, #id)();
  TextColumn get userId => text().nullable()();
  TextColumn get iconKey => text().withDefault(const Constant(''))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 交易记录表
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get amount => integer()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  IntColumn get amountCny => integer()();
  RealColumn get exchangeRate => real().withDefault(const Constant(1.0))();
  TextColumn get type => text()(); // income, expense, transfer
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant(''))();
  TextColumn get imageUrls => text().withDefault(const Constant(''))();
  DateTimeColumn get txnDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))(); // pending, synced, failed
  TextColumn get mergeLogId => text().nullable()(); // 合并日志 ID，用于撤销合并
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 转账记录表
class Transfers extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get fromAccountId => text().references(Accounts, #id)();
  TextColumn get toAccountId => text().references(Accounts, #id)();
  IntColumn get amount => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
