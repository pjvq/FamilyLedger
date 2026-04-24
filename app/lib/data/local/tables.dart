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
  IntColumn get amount => integer()(); // 原始金额（分）
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  IntColumn get amountCny => integer()(); // 人民币（分）
  RealColumn get exchangeRate =>
      real().withDefault(const Constant(1.0))();
  TextColumn get type => text()(); // 'income' | 'expense'
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant(''))(); // JSON array string
  TextColumn get imageUrls => text().withDefault(const Constant(''))(); // JSON array string
  DateTimeColumn get txnDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

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

/// 贷款组表（组合贷款）
class LoanGroups extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get groupType => text()(); // commercial_only / provident_only / combined
  IntColumn get totalPrincipal => integer()(); // 总贷款本金（分）
  IntColumn get paymentDay => integer()(); // 1-28
  DateTimeColumn get startDate => dateTime()();
  TextColumn get accountId => text().withDefault(const Constant(''))(); // 关联还款账户
  TextColumn get loanType => text().withDefault(const Constant('mortgage'))(); // 贷款大类
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 贷款表
class Loans extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get loanType => text().withDefault(const Constant('other'))(); // mortgage, car_loan, credit_card, consumer, business, other
  IntColumn get principal => integer()(); // 分
  IntColumn get remainingPrincipal => integer()(); // 分
  RealColumn get annualRate => real()(); // 如 4.2 表示 4.2%
  IntColumn get totalMonths => integer()();
  IntColumn get paidMonths => integer().withDefault(const Constant(0))();
  TextColumn get repaymentMethod => text().withDefault(const Constant('equal_installment'))(); // equal_installment, equal_principal
  IntColumn get paymentDay => integer()(); // 1-28
  DateTimeColumn get startDate => dateTime()();
  TextColumn get accountId => text().withDefault(const Constant(''))(); // 关联还款账户
  // 组合贷款扩展字段
  TextColumn get groupId => text().withDefault(const Constant(''))(); // 归属组合贷款（空 = 独立贷款）
  TextColumn get subType => text().withDefault(const Constant(''))(); // commercial / provident
  TextColumn get rateType => text().withDefault(const Constant('fixed'))(); // fixed / lpr_floating
  RealColumn get lprBase => real().withDefault(const Constant(0.0))(); // LPR 基准利率
  RealColumn get lprSpread => real().withDefault(const Constant(0.0))(); // 基点偏移
  IntColumn get rateAdjustMonth => integer().withDefault(const Constant(1))(); // 利率调整月 (1=一月, 0=放款月)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 贷款还款计划表
class LoanSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get loanId => text().references(Loans, #id)();
  IntColumn get monthNumber => integer()();
  IntColumn get payment => integer()(); // 分
  IntColumn get principalPart => integer()(); // 分
  IntColumn get interestPart => integer()(); // 分
  IntColumn get remainingPrincipal => integer()(); // 分
  DateTimeColumn get dueDate => dateTime()();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  DateTimeColumn get paidDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 贷款利率变更记录表
class LoanRateChanges extends Table {
  TextColumn get id => text()();
  TextColumn get loanId => text().references(Loans, #id)();
  RealColumn get oldRate => real()();
  RealColumn get newRate => real()();
  DateTimeColumn get effectiveDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 投资持仓表
class Investments extends Table {
  @override
  String get tableName => 'investments';

  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get symbol => text()();
  TextColumn get name => text()();
  TextColumn get marketType => text()();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  IntColumn get costBasis => integer().withDefault(const Constant(0))(); // 分
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 投资交易记录表
class InvestmentTrades extends Table {
  @override
  String get tableName => 'investment_trades';

  TextColumn get id => text()();
  TextColumn get investmentId => text().references(Investments, #id)();
  TextColumn get tradeType => text()(); // buy / sell
  RealColumn get quantity => real()();
  IntColumn get price => integer()(); // 成交价（分/股）
  IntColumn get totalAmount => integer()(); // 总金额（分）
  IntColumn get fee => integer().withDefault(const Constant(0))(); // 手续费（分）
  DateTimeColumn get tradeDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 行情报价缓存表（composite PK: symbol + marketType）
class MarketQuotes extends Table {
  @override
  String get tableName => 'market_quotes';

  TextColumn get symbol => text()();
  TextColumn get marketType => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get currentPrice => integer().withDefault(const Constant(0))(); // 分
  IntColumn get changeAmount => integer().withDefault(const Constant(0))(); // 分
  RealColumn get changePercent => real().withDefault(const Constant(0.0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {symbol, marketType};
}

/// 固定资产表
class FixedAssets extends Table {
  @override
  String get tableName => 'fixed_assets';

  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get assetType => text().withDefault(const Constant('other'))(); // real_estate, vehicle, electronics, furniture, jewelry, other
  IntColumn get purchasePrice => integer()(); // 分
  IntColumn get currentValue => integer()(); // 分
  DateTimeColumn get purchaseDate => dateTime()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 资产估值记录表
class AssetValuations extends Table {
  @override
  String get tableName => 'asset_valuations';

  TextColumn get id => text()();
  TextColumn get assetId => text().references(FixedAssets, #id)();
  IntColumn get value => integer()(); // 分
  TextColumn get source => text().withDefault(const Constant('manual'))(); // manual / depreciation
  DateTimeColumn get valuationDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 折旧规则表
class DepreciationRules extends Table {
  @override
  String get tableName => 'depreciation_rules';

  TextColumn get id => text()();
  TextColumn get assetId => text().references(FixedAssets, #id)();
  TextColumn get method => text().withDefault(const Constant('none'))(); // none / straight_line / double_declining
  IntColumn get usefulLifeYears => integer().withDefault(const Constant(5))();
  RealColumn get salvageRate => real().withDefault(const Constant(0.05))(); // 0-1
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

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

/// 汇率缓存表
class ExchangeRates extends Table {
  @override
  String get tableName => 'exchange_rates';

  TextColumn get currencyPair => text()(); // e.g. 'USD/CNY'
  RealColumn get rate => real()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {currencyPair};
}
