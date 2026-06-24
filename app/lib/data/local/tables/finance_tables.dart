import 'package:drift/drift.dart';

import 'core_tables.dart';

/// 投资持仓表
class Investments extends Table {
  @override
  String get tableName => 'investments';

  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get familyId => text().withDefault(const Constant(''))();
  TextColumn get symbol => text()();
  TextColumn get name => text()();
  TextColumn get marketType => text()();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  IntColumn get costBasis => integer().withDefault(const Constant(0))();
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
  TextColumn get tradeType => text()(); // buy, sell, dividend
  RealColumn get quantity => real()();
  IntColumn get price => integer()();
  IntColumn get totalAmount => integer()();
  IntColumn get fee => integer().withDefault(const Constant(0))();
  DateTimeColumn get tradeDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 行情报价缓存表
class MarketQuotes extends Table {
  @override
  String get tableName => 'market_quotes';

  TextColumn get symbol => text()();
  TextColumn get marketType => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get currentPrice => integer().withDefault(const Constant(0))();
  IntColumn get changeAmount => integer().withDefault(const Constant(0))();
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
  TextColumn get familyId => text().withDefault(const Constant(''))();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get assetType => text().withDefault(const Constant('other'))();
  IntColumn get purchasePrice => integer()();
  IntColumn get currentValue => integer()();
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
  IntColumn get value => integer()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
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
  TextColumn get method => text().withDefault(
    const Constant('none'),
  )(); // none, straight_line, declining_balance
  IntColumn get usefulLifeYears => integer().withDefault(const Constant(5))();
  RealColumn get salvageRate => real().withDefault(const Constant(0.05))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
