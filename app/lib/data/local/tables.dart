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
  TextColumn get familyId => text().withDefault(const Constant(''))(); // 空=个人账户
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get accountType => text().withDefault(const Constant('other'))(); // cash, bank_card, credit_card, alipay, wechat_pay, investment, other
  TextColumn get icon => text().withDefault(const Constant('💳'))();
  IntColumn get balance => integer().withDefault(const Constant(0))(); // 分
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

/// 家庭表
class Families extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get ownerId => text()();
  TextColumn get inviteCode => text().withDefault(const Constant(''))();
  DateTimeColumn get inviteExpiresAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 家庭成员表
class FamilyMembers extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text().references(Families, #id)();
  TextColumn get userId => text()();
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get role => text().withDefault(const Constant('member'))(); // owner, admin, member
  BoolColumn get canView => boolean().withDefault(const Constant(true))();
  BoolColumn get canCreate => boolean().withDefault(const Constant(true))();
  BoolColumn get canEdit => boolean().withDefault(const Constant(false))();
  BoolColumn get canDelete => boolean().withDefault(const Constant(false))();
  BoolColumn get canManageAccounts => boolean().withDefault(const Constant(false))();
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 转账记录表
class Transfers extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get fromAccountId => text().references(Accounts, #id)();
  TextColumn get toAccountId => text().references(Accounts, #id)();
  IntColumn get amount => integer()(); // 分
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 预算表
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get familyId => text().withDefault(const Constant(''))();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  IntColumn get totalAmount => integer()(); // 分
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
  IntColumn get amount => integer()(); // 分

  @override
  Set<Column> get primaryKey => {id};
}

/// 通知表
class Notifications extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
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

  TextColumn get userId => text()();
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
