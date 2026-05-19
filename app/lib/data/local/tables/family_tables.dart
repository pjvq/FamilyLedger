import 'package:drift/drift.dart';

import 'core_tables.dart';

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
