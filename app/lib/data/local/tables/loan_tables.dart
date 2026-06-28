import 'package:drift/drift.dart';

import 'core_tables.dart';

/// 贷款组表（组合贷款）
class LoanGroups extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get familyId => text().withDefault(const Constant(''))();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get groupType => text()();
  IntColumn get totalPrincipal => integer()();
  IntColumn get paymentDay => integer()();
  DateTimeColumn get startDate => dateTime()();
  TextColumn get accountId => text().withDefault(const Constant(''))();
  TextColumn get loanType => text().withDefault(const Constant('mortgage'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get hlc => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 贷款表
class Loans extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get familyId => text().withDefault(const Constant(''))();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get loanType => text().withDefault(const Constant('other'))();
  IntColumn get principal => integer()();
  IntColumn get remainingPrincipal => integer()();
  RealColumn get annualRate => real()();
  IntColumn get totalMonths => integer()();
  IntColumn get paidMonths => integer().withDefault(const Constant(0))();
  TextColumn get repaymentMethod => text().withDefault(
    const Constant('equal_installment'),
  )(); // equal_installment, equal_principal, interest_only, bullet, equal_interest
  IntColumn get paymentDay => integer()();
  DateTimeColumn get startDate => dateTime()();
  TextColumn get accountId => text().withDefault(const Constant(''))();
  TextColumn get groupId => text().withDefault(const Constant(''))();
  TextColumn get subType => text().withDefault(const Constant(''))();
  TextColumn get rateType =>
      text().withDefault(const Constant('fixed'))(); // fixed, lpr_floating
  RealColumn get lprBase => real().withDefault(const Constant(0.0))();
  RealColumn get lprSpread => real().withDefault(const Constant(0.0))();
  IntColumn get rateAdjustMonth => integer().withDefault(const Constant(1))();
  TextColumn get repaymentCategoryId =>
      text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get hlc => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 贷款还款计划表
class LoanSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get loanId => text().references(Loans, #id)();
  IntColumn get monthNumber => integer()();
  IntColumn get payment => integer()();
  IntColumn get principalPart => integer()();
  IntColumn get interestPart => integer()();
  IntColumn get remainingPrincipal => integer()();
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
