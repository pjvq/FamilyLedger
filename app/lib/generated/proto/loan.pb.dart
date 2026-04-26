//
//  Generated code. Do not modify.
//  source: loan.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'google/protobuf/timestamp.pb.dart' as $4;
import 'loan.pbenum.dart';

export 'loan.pbenum.dart';

class Loan extends $pb.GeneratedMessage {
  factory Loan({
    $core.String? id,
    $core.String? userId,
    $core.String? name,
    LoanType? loanType,
    $fixnum.Int64? principal,
    $fixnum.Int64? remainingPrincipal,
    $core.double? annualRate,
    $core.int? totalMonths,
    $core.int? paidMonths,
    RepaymentMethod? repaymentMethod,
    $core.int? paymentDay,
    $4.Timestamp? startDate,
    $4.Timestamp? createdAt,
    $4.Timestamp? updatedAt,
    $core.String? accountId,
    $core.String? groupId,
    LoanSubType? subType,
    RateType? rateType,
    $core.double? lprBase,
    $core.double? lprSpread,
    $core.int? rateAdjustMonth,
    $core.String? familyId,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    if (name != null) {
      $result.name = name;
    }
    if (loanType != null) {
      $result.loanType = loanType;
    }
    if (principal != null) {
      $result.principal = principal;
    }
    if (remainingPrincipal != null) {
      $result.remainingPrincipal = remainingPrincipal;
    }
    if (annualRate != null) {
      $result.annualRate = annualRate;
    }
    if (totalMonths != null) {
      $result.totalMonths = totalMonths;
    }
    if (paidMonths != null) {
      $result.paidMonths = paidMonths;
    }
    if (repaymentMethod != null) {
      $result.repaymentMethod = repaymentMethod;
    }
    if (paymentDay != null) {
      $result.paymentDay = paymentDay;
    }
    if (startDate != null) {
      $result.startDate = startDate;
    }
    if (createdAt != null) {
      $result.createdAt = createdAt;
    }
    if (updatedAt != null) {
      $result.updatedAt = updatedAt;
    }
    if (accountId != null) {
      $result.accountId = accountId;
    }
    if (groupId != null) {
      $result.groupId = groupId;
    }
    if (subType != null) {
      $result.subType = subType;
    }
    if (rateType != null) {
      $result.rateType = rateType;
    }
    if (lprBase != null) {
      $result.lprBase = lprBase;
    }
    if (lprSpread != null) {
      $result.lprSpread = lprSpread;
    }
    if (rateAdjustMonth != null) {
      $result.rateAdjustMonth = rateAdjustMonth;
    }
    if (familyId != null) {
      $result.familyId = familyId;
    }
    return $result;
  }
  Loan._() : super();
  factory Loan.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Loan.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Loan', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..e<LoanType>(4, _omitFieldNames ? '' : 'loanType', $pb.PbFieldType.OE, defaultOrMaker: LoanType.LOAN_TYPE_UNSPECIFIED, valueOf: LoanType.valueOf, enumValues: LoanType.values)
    ..aInt64(5, _omitFieldNames ? '' : 'principal')
    ..aInt64(6, _omitFieldNames ? '' : 'remainingPrincipal')
    ..a<$core.double>(7, _omitFieldNames ? '' : 'annualRate', $pb.PbFieldType.OD)
    ..a<$core.int>(8, _omitFieldNames ? '' : 'totalMonths', $pb.PbFieldType.O3)
    ..a<$core.int>(9, _omitFieldNames ? '' : 'paidMonths', $pb.PbFieldType.O3)
    ..e<RepaymentMethod>(10, _omitFieldNames ? '' : 'repaymentMethod', $pb.PbFieldType.OE, defaultOrMaker: RepaymentMethod.REPAYMENT_METHOD_UNSPECIFIED, valueOf: RepaymentMethod.valueOf, enumValues: RepaymentMethod.values)
    ..a<$core.int>(11, _omitFieldNames ? '' : 'paymentDay', $pb.PbFieldType.O3)
    ..aOM<$4.Timestamp>(12, _omitFieldNames ? '' : 'startDate', subBuilder: $4.Timestamp.create)
    ..aOM<$4.Timestamp>(13, _omitFieldNames ? '' : 'createdAt', subBuilder: $4.Timestamp.create)
    ..aOM<$4.Timestamp>(14, _omitFieldNames ? '' : 'updatedAt', subBuilder: $4.Timestamp.create)
    ..aOS(15, _omitFieldNames ? '' : 'accountId')
    ..aOS(16, _omitFieldNames ? '' : 'groupId')
    ..e<LoanSubType>(17, _omitFieldNames ? '' : 'subType', $pb.PbFieldType.OE, defaultOrMaker: LoanSubType.LOAN_SUB_TYPE_UNSPECIFIED, valueOf: LoanSubType.valueOf, enumValues: LoanSubType.values)
    ..e<RateType>(18, _omitFieldNames ? '' : 'rateType', $pb.PbFieldType.OE, defaultOrMaker: RateType.RATE_TYPE_UNSPECIFIED, valueOf: RateType.valueOf, enumValues: RateType.values)
    ..a<$core.double>(19, _omitFieldNames ? '' : 'lprBase', $pb.PbFieldType.OD)
    ..a<$core.double>(20, _omitFieldNames ? '' : 'lprSpread', $pb.PbFieldType.OD)
    ..a<$core.int>(21, _omitFieldNames ? '' : 'rateAdjustMonth', $pb.PbFieldType.O3)
    ..aOS(22, _omitFieldNames ? '' : 'familyId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Loan clone() => Loan()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Loan copyWith(void Function(Loan) updates) => super.copyWith((message) => updates(message as Loan)) as Loan;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Loan create() => Loan._();
  Loan createEmptyInstance() => create();
  static $pb.PbList<Loan> createRepeated() => $pb.PbList<Loan>();
  @$core.pragma('dart2js:noInline')
  static Loan getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Loan>(create);
  static Loan? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => clearField(3);

  @$pb.TagNumber(4)
  LoanType get loanType => $_getN(3);
  @$pb.TagNumber(4)
  set loanType(LoanType v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasLoanType() => $_has(3);
  @$pb.TagNumber(4)
  void clearLoanType() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get principal => $_getI64(4);
  @$pb.TagNumber(5)
  set principal($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasPrincipal() => $_has(4);
  @$pb.TagNumber(5)
  void clearPrincipal() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get remainingPrincipal => $_getI64(5);
  @$pb.TagNumber(6)
  set remainingPrincipal($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasRemainingPrincipal() => $_has(5);
  @$pb.TagNumber(6)
  void clearRemainingPrincipal() => clearField(6);

  @$pb.TagNumber(7)
  $core.double get annualRate => $_getN(6);
  @$pb.TagNumber(7)
  set annualRate($core.double v) { $_setDouble(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasAnnualRate() => $_has(6);
  @$pb.TagNumber(7)
  void clearAnnualRate() => clearField(7);

  @$pb.TagNumber(8)
  $core.int get totalMonths => $_getIZ(7);
  @$pb.TagNumber(8)
  set totalMonths($core.int v) { $_setSignedInt32(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasTotalMonths() => $_has(7);
  @$pb.TagNumber(8)
  void clearTotalMonths() => clearField(8);

  @$pb.TagNumber(9)
  $core.int get paidMonths => $_getIZ(8);
  @$pb.TagNumber(9)
  set paidMonths($core.int v) { $_setSignedInt32(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasPaidMonths() => $_has(8);
  @$pb.TagNumber(9)
  void clearPaidMonths() => clearField(9);

  @$pb.TagNumber(10)
  RepaymentMethod get repaymentMethod => $_getN(9);
  @$pb.TagNumber(10)
  set repaymentMethod(RepaymentMethod v) { setField(10, v); }
  @$pb.TagNumber(10)
  $core.bool hasRepaymentMethod() => $_has(9);
  @$pb.TagNumber(10)
  void clearRepaymentMethod() => clearField(10);

  @$pb.TagNumber(11)
  $core.int get paymentDay => $_getIZ(10);
  @$pb.TagNumber(11)
  set paymentDay($core.int v) { $_setSignedInt32(10, v); }
  @$pb.TagNumber(11)
  $core.bool hasPaymentDay() => $_has(10);
  @$pb.TagNumber(11)
  void clearPaymentDay() => clearField(11);

  @$pb.TagNumber(12)
  $4.Timestamp get startDate => $_getN(11);
  @$pb.TagNumber(12)
  set startDate($4.Timestamp v) { setField(12, v); }
  @$pb.TagNumber(12)
  $core.bool hasStartDate() => $_has(11);
  @$pb.TagNumber(12)
  void clearStartDate() => clearField(12);
  @$pb.TagNumber(12)
  $4.Timestamp ensureStartDate() => $_ensure(11);

  @$pb.TagNumber(13)
  $4.Timestamp get createdAt => $_getN(12);
  @$pb.TagNumber(13)
  set createdAt($4.Timestamp v) { setField(13, v); }
  @$pb.TagNumber(13)
  $core.bool hasCreatedAt() => $_has(12);
  @$pb.TagNumber(13)
  void clearCreatedAt() => clearField(13);
  @$pb.TagNumber(13)
  $4.Timestamp ensureCreatedAt() => $_ensure(12);

  @$pb.TagNumber(14)
  $4.Timestamp get updatedAt => $_getN(13);
  @$pb.TagNumber(14)
  set updatedAt($4.Timestamp v) { setField(14, v); }
  @$pb.TagNumber(14)
  $core.bool hasUpdatedAt() => $_has(13);
  @$pb.TagNumber(14)
  void clearUpdatedAt() => clearField(14);
  @$pb.TagNumber(14)
  $4.Timestamp ensureUpdatedAt() => $_ensure(13);

  @$pb.TagNumber(15)
  $core.String get accountId => $_getSZ(14);
  @$pb.TagNumber(15)
  set accountId($core.String v) { $_setString(14, v); }
  @$pb.TagNumber(15)
  $core.bool hasAccountId() => $_has(14);
  @$pb.TagNumber(15)
  void clearAccountId() => clearField(15);

  @$pb.TagNumber(16)
  $core.String get groupId => $_getSZ(15);
  @$pb.TagNumber(16)
  set groupId($core.String v) { $_setString(15, v); }
  @$pb.TagNumber(16)
  $core.bool hasGroupId() => $_has(15);
  @$pb.TagNumber(16)
  void clearGroupId() => clearField(16);

  @$pb.TagNumber(17)
  LoanSubType get subType => $_getN(16);
  @$pb.TagNumber(17)
  set subType(LoanSubType v) { setField(17, v); }
  @$pb.TagNumber(17)
  $core.bool hasSubType() => $_has(16);
  @$pb.TagNumber(17)
  void clearSubType() => clearField(17);

  @$pb.TagNumber(18)
  RateType get rateType => $_getN(17);
  @$pb.TagNumber(18)
  set rateType(RateType v) { setField(18, v); }
  @$pb.TagNumber(18)
  $core.bool hasRateType() => $_has(17);
  @$pb.TagNumber(18)
  void clearRateType() => clearField(18);

  @$pb.TagNumber(19)
  $core.double get lprBase => $_getN(18);
  @$pb.TagNumber(19)
  set lprBase($core.double v) { $_setDouble(18, v); }
  @$pb.TagNumber(19)
  $core.bool hasLprBase() => $_has(18);
  @$pb.TagNumber(19)
  void clearLprBase() => clearField(19);

  @$pb.TagNumber(20)
  $core.double get lprSpread => $_getN(19);
  @$pb.TagNumber(20)
  set lprSpread($core.double v) { $_setDouble(19, v); }
  @$pb.TagNumber(20)
  $core.bool hasLprSpread() => $_has(19);
  @$pb.TagNumber(20)
  void clearLprSpread() => clearField(20);

  @$pb.TagNumber(21)
  $core.int get rateAdjustMonth => $_getIZ(20);
  @$pb.TagNumber(21)
  set rateAdjustMonth($core.int v) { $_setSignedInt32(20, v); }
  @$pb.TagNumber(21)
  $core.bool hasRateAdjustMonth() => $_has(20);
  @$pb.TagNumber(21)
  void clearRateAdjustMonth() => clearField(21);

  @$pb.TagNumber(22)
  $core.String get familyId => $_getSZ(21);
  @$pb.TagNumber(22)
  set familyId($core.String v) { $_setString(21, v); }
  @$pb.TagNumber(22)
  $core.bool hasFamilyId() => $_has(21);
  @$pb.TagNumber(22)
  void clearFamilyId() => clearField(22);
}

class LoanScheduleItem extends $pb.GeneratedMessage {
  factory LoanScheduleItem({
    $core.int? monthNumber,
    $fixnum.Int64? payment,
    $fixnum.Int64? principalPart,
    $fixnum.Int64? interestPart,
    $fixnum.Int64? remainingPrincipal,
    $core.bool? isPaid,
    $4.Timestamp? dueDate,
    $4.Timestamp? paidDate,
  }) {
    final $result = create();
    if (monthNumber != null) {
      $result.monthNumber = monthNumber;
    }
    if (payment != null) {
      $result.payment = payment;
    }
    if (principalPart != null) {
      $result.principalPart = principalPart;
    }
    if (interestPart != null) {
      $result.interestPart = interestPart;
    }
    if (remainingPrincipal != null) {
      $result.remainingPrincipal = remainingPrincipal;
    }
    if (isPaid != null) {
      $result.isPaid = isPaid;
    }
    if (dueDate != null) {
      $result.dueDate = dueDate;
    }
    if (paidDate != null) {
      $result.paidDate = paidDate;
    }
    return $result;
  }
  LoanScheduleItem._() : super();
  factory LoanScheduleItem.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LoanScheduleItem.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LoanScheduleItem', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'monthNumber', $pb.PbFieldType.O3)
    ..aInt64(2, _omitFieldNames ? '' : 'payment')
    ..aInt64(3, _omitFieldNames ? '' : 'principalPart')
    ..aInt64(4, _omitFieldNames ? '' : 'interestPart')
    ..aInt64(5, _omitFieldNames ? '' : 'remainingPrincipal')
    ..aOB(6, _omitFieldNames ? '' : 'isPaid')
    ..aOM<$4.Timestamp>(7, _omitFieldNames ? '' : 'dueDate', subBuilder: $4.Timestamp.create)
    ..aOM<$4.Timestamp>(8, _omitFieldNames ? '' : 'paidDate', subBuilder: $4.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LoanScheduleItem clone() => LoanScheduleItem()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LoanScheduleItem copyWith(void Function(LoanScheduleItem) updates) => super.copyWith((message) => updates(message as LoanScheduleItem)) as LoanScheduleItem;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoanScheduleItem create() => LoanScheduleItem._();
  LoanScheduleItem createEmptyInstance() => create();
  static $pb.PbList<LoanScheduleItem> createRepeated() => $pb.PbList<LoanScheduleItem>();
  @$core.pragma('dart2js:noInline')
  static LoanScheduleItem getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LoanScheduleItem>(create);
  static LoanScheduleItem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get monthNumber => $_getIZ(0);
  @$pb.TagNumber(1)
  set monthNumber($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMonthNumber() => $_has(0);
  @$pb.TagNumber(1)
  void clearMonthNumber() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get payment => $_getI64(1);
  @$pb.TagNumber(2)
  set payment($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPayment() => $_has(1);
  @$pb.TagNumber(2)
  void clearPayment() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get principalPart => $_getI64(2);
  @$pb.TagNumber(3)
  set principalPart($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPrincipalPart() => $_has(2);
  @$pb.TagNumber(3)
  void clearPrincipalPart() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get interestPart => $_getI64(3);
  @$pb.TagNumber(4)
  set interestPart($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasInterestPart() => $_has(3);
  @$pb.TagNumber(4)
  void clearInterestPart() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get remainingPrincipal => $_getI64(4);
  @$pb.TagNumber(5)
  set remainingPrincipal($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasRemainingPrincipal() => $_has(4);
  @$pb.TagNumber(5)
  void clearRemainingPrincipal() => clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isPaid => $_getBF(5);
  @$pb.TagNumber(6)
  set isPaid($core.bool v) { $_setBool(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasIsPaid() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsPaid() => clearField(6);

  @$pb.TagNumber(7)
  $4.Timestamp get dueDate => $_getN(6);
  @$pb.TagNumber(7)
  set dueDate($4.Timestamp v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasDueDate() => $_has(6);
  @$pb.TagNumber(7)
  void clearDueDate() => clearField(7);
  @$pb.TagNumber(7)
  $4.Timestamp ensureDueDate() => $_ensure(6);

  @$pb.TagNumber(8)
  $4.Timestamp get paidDate => $_getN(7);
  @$pb.TagNumber(8)
  set paidDate($4.Timestamp v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasPaidDate() => $_has(7);
  @$pb.TagNumber(8)
  void clearPaidDate() => clearField(8);
  @$pb.TagNumber(8)
  $4.Timestamp ensurePaidDate() => $_ensure(7);
}

class PrepaymentSimulation extends $pb.GeneratedMessage {
  factory PrepaymentSimulation({
    $fixnum.Int64? prepaymentAmount,
    $fixnum.Int64? totalInterestBefore,
    $fixnum.Int64? totalInterestAfter,
    $fixnum.Int64? interestSaved,
    $core.int? monthsReduced,
    $fixnum.Int64? newMonthlyPayment,
    $core.Iterable<LoanScheduleItem>? newSchedule,
  }) {
    final $result = create();
    if (prepaymentAmount != null) {
      $result.prepaymentAmount = prepaymentAmount;
    }
    if (totalInterestBefore != null) {
      $result.totalInterestBefore = totalInterestBefore;
    }
    if (totalInterestAfter != null) {
      $result.totalInterestAfter = totalInterestAfter;
    }
    if (interestSaved != null) {
      $result.interestSaved = interestSaved;
    }
    if (monthsReduced != null) {
      $result.monthsReduced = monthsReduced;
    }
    if (newMonthlyPayment != null) {
      $result.newMonthlyPayment = newMonthlyPayment;
    }
    if (newSchedule != null) {
      $result.newSchedule.addAll(newSchedule);
    }
    return $result;
  }
  PrepaymentSimulation._() : super();
  factory PrepaymentSimulation.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PrepaymentSimulation.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PrepaymentSimulation', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'prepaymentAmount')
    ..aInt64(2, _omitFieldNames ? '' : 'totalInterestBefore')
    ..aInt64(3, _omitFieldNames ? '' : 'totalInterestAfter')
    ..aInt64(4, _omitFieldNames ? '' : 'interestSaved')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'monthsReduced', $pb.PbFieldType.O3)
    ..aInt64(6, _omitFieldNames ? '' : 'newMonthlyPayment')
    ..pc<LoanScheduleItem>(7, _omitFieldNames ? '' : 'newSchedule', $pb.PbFieldType.PM, subBuilder: LoanScheduleItem.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PrepaymentSimulation clone() => PrepaymentSimulation()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PrepaymentSimulation copyWith(void Function(PrepaymentSimulation) updates) => super.copyWith((message) => updates(message as PrepaymentSimulation)) as PrepaymentSimulation;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PrepaymentSimulation create() => PrepaymentSimulation._();
  PrepaymentSimulation createEmptyInstance() => create();
  static $pb.PbList<PrepaymentSimulation> createRepeated() => $pb.PbList<PrepaymentSimulation>();
  @$core.pragma('dart2js:noInline')
  static PrepaymentSimulation getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PrepaymentSimulation>(create);
  static PrepaymentSimulation? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get prepaymentAmount => $_getI64(0);
  @$pb.TagNumber(1)
  set prepaymentAmount($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPrepaymentAmount() => $_has(0);
  @$pb.TagNumber(1)
  void clearPrepaymentAmount() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get totalInterestBefore => $_getI64(1);
  @$pb.TagNumber(2)
  set totalInterestBefore($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTotalInterestBefore() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalInterestBefore() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get totalInterestAfter => $_getI64(2);
  @$pb.TagNumber(3)
  set totalInterestAfter($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTotalInterestAfter() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalInterestAfter() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get interestSaved => $_getI64(3);
  @$pb.TagNumber(4)
  set interestSaved($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasInterestSaved() => $_has(3);
  @$pb.TagNumber(4)
  void clearInterestSaved() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get monthsReduced => $_getIZ(4);
  @$pb.TagNumber(5)
  set monthsReduced($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasMonthsReduced() => $_has(4);
  @$pb.TagNumber(5)
  void clearMonthsReduced() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get newMonthlyPayment => $_getI64(5);
  @$pb.TagNumber(6)
  set newMonthlyPayment($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasNewMonthlyPayment() => $_has(5);
  @$pb.TagNumber(6)
  void clearNewMonthlyPayment() => clearField(6);

  @$pb.TagNumber(7)
  $core.List<LoanScheduleItem> get newSchedule => $_getList(6);
}

class CreateLoanRequest extends $pb.GeneratedMessage {
  factory CreateLoanRequest({
    $core.String? name,
    LoanType? loanType,
    $fixnum.Int64? principal,
    $core.double? annualRate,
    $core.int? totalMonths,
    RepaymentMethod? repaymentMethod,
    $core.int? paymentDay,
    $4.Timestamp? startDate,
    $core.String? accountId,
    $core.String? familyId,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (loanType != null) {
      $result.loanType = loanType;
    }
    if (principal != null) {
      $result.principal = principal;
    }
    if (annualRate != null) {
      $result.annualRate = annualRate;
    }
    if (totalMonths != null) {
      $result.totalMonths = totalMonths;
    }
    if (repaymentMethod != null) {
      $result.repaymentMethod = repaymentMethod;
    }
    if (paymentDay != null) {
      $result.paymentDay = paymentDay;
    }
    if (startDate != null) {
      $result.startDate = startDate;
    }
    if (accountId != null) {
      $result.accountId = accountId;
    }
    if (familyId != null) {
      $result.familyId = familyId;
    }
    return $result;
  }
  CreateLoanRequest._() : super();
  factory CreateLoanRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CreateLoanRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CreateLoanRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..e<LoanType>(2, _omitFieldNames ? '' : 'loanType', $pb.PbFieldType.OE, defaultOrMaker: LoanType.LOAN_TYPE_UNSPECIFIED, valueOf: LoanType.valueOf, enumValues: LoanType.values)
    ..aInt64(3, _omitFieldNames ? '' : 'principal')
    ..a<$core.double>(4, _omitFieldNames ? '' : 'annualRate', $pb.PbFieldType.OD)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'totalMonths', $pb.PbFieldType.O3)
    ..e<RepaymentMethod>(6, _omitFieldNames ? '' : 'repaymentMethod', $pb.PbFieldType.OE, defaultOrMaker: RepaymentMethod.REPAYMENT_METHOD_UNSPECIFIED, valueOf: RepaymentMethod.valueOf, enumValues: RepaymentMethod.values)
    ..a<$core.int>(7, _omitFieldNames ? '' : 'paymentDay', $pb.PbFieldType.O3)
    ..aOM<$4.Timestamp>(8, _omitFieldNames ? '' : 'startDate', subBuilder: $4.Timestamp.create)
    ..aOS(9, _omitFieldNames ? '' : 'accountId')
    ..aOS(10, _omitFieldNames ? '' : 'familyId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CreateLoanRequest clone() => CreateLoanRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CreateLoanRequest copyWith(void Function(CreateLoanRequest) updates) => super.copyWith((message) => updates(message as CreateLoanRequest)) as CreateLoanRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateLoanRequest create() => CreateLoanRequest._();
  CreateLoanRequest createEmptyInstance() => create();
  static $pb.PbList<CreateLoanRequest> createRepeated() => $pb.PbList<CreateLoanRequest>();
  @$core.pragma('dart2js:noInline')
  static CreateLoanRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CreateLoanRequest>(create);
  static CreateLoanRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  LoanType get loanType => $_getN(1);
  @$pb.TagNumber(2)
  set loanType(LoanType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasLoanType() => $_has(1);
  @$pb.TagNumber(2)
  void clearLoanType() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get principal => $_getI64(2);
  @$pb.TagNumber(3)
  set principal($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPrincipal() => $_has(2);
  @$pb.TagNumber(3)
  void clearPrincipal() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get annualRate => $_getN(3);
  @$pb.TagNumber(4)
  set annualRate($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAnnualRate() => $_has(3);
  @$pb.TagNumber(4)
  void clearAnnualRate() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get totalMonths => $_getIZ(4);
  @$pb.TagNumber(5)
  set totalMonths($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasTotalMonths() => $_has(4);
  @$pb.TagNumber(5)
  void clearTotalMonths() => clearField(5);

  @$pb.TagNumber(6)
  RepaymentMethod get repaymentMethod => $_getN(5);
  @$pb.TagNumber(6)
  set repaymentMethod(RepaymentMethod v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasRepaymentMethod() => $_has(5);
  @$pb.TagNumber(6)
  void clearRepaymentMethod() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get paymentDay => $_getIZ(6);
  @$pb.TagNumber(7)
  set paymentDay($core.int v) { $_setSignedInt32(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasPaymentDay() => $_has(6);
  @$pb.TagNumber(7)
  void clearPaymentDay() => clearField(7);

  @$pb.TagNumber(8)
  $4.Timestamp get startDate => $_getN(7);
  @$pb.TagNumber(8)
  set startDate($4.Timestamp v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasStartDate() => $_has(7);
  @$pb.TagNumber(8)
  void clearStartDate() => clearField(8);
  @$pb.TagNumber(8)
  $4.Timestamp ensureStartDate() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.String get accountId => $_getSZ(8);
  @$pb.TagNumber(9)
  set accountId($core.String v) { $_setString(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasAccountId() => $_has(8);
  @$pb.TagNumber(9)
  void clearAccountId() => clearField(9);

  @$pb.TagNumber(10)
  $core.String get familyId => $_getSZ(9);
  @$pb.TagNumber(10)
  set familyId($core.String v) { $_setString(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasFamilyId() => $_has(9);
  @$pb.TagNumber(10)
  void clearFamilyId() => clearField(10);
}

class GetLoanRequest extends $pb.GeneratedMessage {
  factory GetLoanRequest({
    $core.String? loanId,
  }) {
    final $result = create();
    if (loanId != null) {
      $result.loanId = loanId;
    }
    return $result;
  }
  GetLoanRequest._() : super();
  factory GetLoanRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetLoanRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetLoanRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'loanId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetLoanRequest clone() => GetLoanRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetLoanRequest copyWith(void Function(GetLoanRequest) updates) => super.copyWith((message) => updates(message as GetLoanRequest)) as GetLoanRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetLoanRequest create() => GetLoanRequest._();
  GetLoanRequest createEmptyInstance() => create();
  static $pb.PbList<GetLoanRequest> createRepeated() => $pb.PbList<GetLoanRequest>();
  @$core.pragma('dart2js:noInline')
  static GetLoanRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetLoanRequest>(create);
  static GetLoanRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get loanId => $_getSZ(0);
  @$pb.TagNumber(1)
  set loanId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasLoanId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLoanId() => clearField(1);
}

class ListLoansRequest extends $pb.GeneratedMessage {
  factory ListLoansRequest({
    $core.String? familyId,
  }) {
    final $result = create();
    if (familyId != null) {
      $result.familyId = familyId;
    }
    return $result;
  }
  ListLoansRequest._() : super();
  factory ListLoansRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListLoansRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListLoansRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListLoansRequest clone() => ListLoansRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListLoansRequest copyWith(void Function(ListLoansRequest) updates) => super.copyWith((message) => updates(message as ListLoansRequest)) as ListLoansRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListLoansRequest create() => ListLoansRequest._();
  ListLoansRequest createEmptyInstance() => create();
  static $pb.PbList<ListLoansRequest> createRepeated() => $pb.PbList<ListLoansRequest>();
  @$core.pragma('dart2js:noInline')
  static ListLoansRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListLoansRequest>(create);
  static ListLoansRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get familyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set familyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamilyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamilyId() => clearField(1);
}

class ListLoansResponse extends $pb.GeneratedMessage {
  factory ListLoansResponse({
    $core.Iterable<Loan>? loans,
  }) {
    final $result = create();
    if (loans != null) {
      $result.loans.addAll(loans);
    }
    return $result;
  }
  ListLoansResponse._() : super();
  factory ListLoansResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListLoansResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListLoansResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..pc<Loan>(1, _omitFieldNames ? '' : 'loans', $pb.PbFieldType.PM, subBuilder: Loan.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListLoansResponse clone() => ListLoansResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListLoansResponse copyWith(void Function(ListLoansResponse) updates) => super.copyWith((message) => updates(message as ListLoansResponse)) as ListLoansResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListLoansResponse create() => ListLoansResponse._();
  ListLoansResponse createEmptyInstance() => create();
  static $pb.PbList<ListLoansResponse> createRepeated() => $pb.PbList<ListLoansResponse>();
  @$core.pragma('dart2js:noInline')
  static ListLoansResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListLoansResponse>(create);
  static ListLoansResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<Loan> get loans => $_getList(0);
}

class UpdateLoanRequest extends $pb.GeneratedMessage {
  factory UpdateLoanRequest({
    $core.String? loanId,
    $core.String? name,
    $core.int? paymentDay,
    $core.String? accountId,
  }) {
    final $result = create();
    if (loanId != null) {
      $result.loanId = loanId;
    }
    if (name != null) {
      $result.name = name;
    }
    if (paymentDay != null) {
      $result.paymentDay = paymentDay;
    }
    if (accountId != null) {
      $result.accountId = accountId;
    }
    return $result;
  }
  UpdateLoanRequest._() : super();
  factory UpdateLoanRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdateLoanRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UpdateLoanRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'loanId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'paymentDay', $pb.PbFieldType.O3)
    ..aOS(4, _omitFieldNames ? '' : 'accountId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdateLoanRequest clone() => UpdateLoanRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdateLoanRequest copyWith(void Function(UpdateLoanRequest) updates) => super.copyWith((message) => updates(message as UpdateLoanRequest)) as UpdateLoanRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateLoanRequest create() => UpdateLoanRequest._();
  UpdateLoanRequest createEmptyInstance() => create();
  static $pb.PbList<UpdateLoanRequest> createRepeated() => $pb.PbList<UpdateLoanRequest>();
  @$core.pragma('dart2js:noInline')
  static UpdateLoanRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateLoanRequest>(create);
  static UpdateLoanRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get loanId => $_getSZ(0);
  @$pb.TagNumber(1)
  set loanId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasLoanId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLoanId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get paymentDay => $_getIZ(2);
  @$pb.TagNumber(3)
  set paymentDay($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPaymentDay() => $_has(2);
  @$pb.TagNumber(3)
  void clearPaymentDay() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get accountId => $_getSZ(3);
  @$pb.TagNumber(4)
  set accountId($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAccountId() => $_has(3);
  @$pb.TagNumber(4)
  void clearAccountId() => clearField(4);
}

class DeleteLoanRequest extends $pb.GeneratedMessage {
  factory DeleteLoanRequest({
    $core.String? loanId,
  }) {
    final $result = create();
    if (loanId != null) {
      $result.loanId = loanId;
    }
    return $result;
  }
  DeleteLoanRequest._() : super();
  factory DeleteLoanRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeleteLoanRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeleteLoanRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'loanId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeleteLoanRequest clone() => DeleteLoanRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeleteLoanRequest copyWith(void Function(DeleteLoanRequest) updates) => super.copyWith((message) => updates(message as DeleteLoanRequest)) as DeleteLoanRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteLoanRequest create() => DeleteLoanRequest._();
  DeleteLoanRequest createEmptyInstance() => create();
  static $pb.PbList<DeleteLoanRequest> createRepeated() => $pb.PbList<DeleteLoanRequest>();
  @$core.pragma('dart2js:noInline')
  static DeleteLoanRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeleteLoanRequest>(create);
  static DeleteLoanRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get loanId => $_getSZ(0);
  @$pb.TagNumber(1)
  set loanId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasLoanId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLoanId() => clearField(1);
}

class GetLoanScheduleRequest extends $pb.GeneratedMessage {
  factory GetLoanScheduleRequest({
    $core.String? loanId,
  }) {
    final $result = create();
    if (loanId != null) {
      $result.loanId = loanId;
    }
    return $result;
  }
  GetLoanScheduleRequest._() : super();
  factory GetLoanScheduleRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetLoanScheduleRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetLoanScheduleRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'loanId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetLoanScheduleRequest clone() => GetLoanScheduleRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetLoanScheduleRequest copyWith(void Function(GetLoanScheduleRequest) updates) => super.copyWith((message) => updates(message as GetLoanScheduleRequest)) as GetLoanScheduleRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetLoanScheduleRequest create() => GetLoanScheduleRequest._();
  GetLoanScheduleRequest createEmptyInstance() => create();
  static $pb.PbList<GetLoanScheduleRequest> createRepeated() => $pb.PbList<GetLoanScheduleRequest>();
  @$core.pragma('dart2js:noInline')
  static GetLoanScheduleRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetLoanScheduleRequest>(create);
  static GetLoanScheduleRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get loanId => $_getSZ(0);
  @$pb.TagNumber(1)
  set loanId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasLoanId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLoanId() => clearField(1);
}

class LoanScheduleResponse extends $pb.GeneratedMessage {
  factory LoanScheduleResponse({
    $core.Iterable<LoanScheduleItem>? items,
  }) {
    final $result = create();
    if (items != null) {
      $result.items.addAll(items);
    }
    return $result;
  }
  LoanScheduleResponse._() : super();
  factory LoanScheduleResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LoanScheduleResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LoanScheduleResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..pc<LoanScheduleItem>(1, _omitFieldNames ? '' : 'items', $pb.PbFieldType.PM, subBuilder: LoanScheduleItem.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LoanScheduleResponse clone() => LoanScheduleResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LoanScheduleResponse copyWith(void Function(LoanScheduleResponse) updates) => super.copyWith((message) => updates(message as LoanScheduleResponse)) as LoanScheduleResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoanScheduleResponse create() => LoanScheduleResponse._();
  LoanScheduleResponse createEmptyInstance() => create();
  static $pb.PbList<LoanScheduleResponse> createRepeated() => $pb.PbList<LoanScheduleResponse>();
  @$core.pragma('dart2js:noInline')
  static LoanScheduleResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LoanScheduleResponse>(create);
  static LoanScheduleResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<LoanScheduleItem> get items => $_getList(0);
}

class SimulatePrepaymentRequest extends $pb.GeneratedMessage {
  factory SimulatePrepaymentRequest({
    $core.String? loanId,
    $fixnum.Int64? prepaymentAmount,
    PrepaymentStrategy? strategy,
  }) {
    final $result = create();
    if (loanId != null) {
      $result.loanId = loanId;
    }
    if (prepaymentAmount != null) {
      $result.prepaymentAmount = prepaymentAmount;
    }
    if (strategy != null) {
      $result.strategy = strategy;
    }
    return $result;
  }
  SimulatePrepaymentRequest._() : super();
  factory SimulatePrepaymentRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SimulatePrepaymentRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SimulatePrepaymentRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'loanId')
    ..aInt64(2, _omitFieldNames ? '' : 'prepaymentAmount')
    ..e<PrepaymentStrategy>(3, _omitFieldNames ? '' : 'strategy', $pb.PbFieldType.OE, defaultOrMaker: PrepaymentStrategy.PREPAYMENT_STRATEGY_UNSPECIFIED, valueOf: PrepaymentStrategy.valueOf, enumValues: PrepaymentStrategy.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SimulatePrepaymentRequest clone() => SimulatePrepaymentRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SimulatePrepaymentRequest copyWith(void Function(SimulatePrepaymentRequest) updates) => super.copyWith((message) => updates(message as SimulatePrepaymentRequest)) as SimulatePrepaymentRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SimulatePrepaymentRequest create() => SimulatePrepaymentRequest._();
  SimulatePrepaymentRequest createEmptyInstance() => create();
  static $pb.PbList<SimulatePrepaymentRequest> createRepeated() => $pb.PbList<SimulatePrepaymentRequest>();
  @$core.pragma('dart2js:noInline')
  static SimulatePrepaymentRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SimulatePrepaymentRequest>(create);
  static SimulatePrepaymentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get loanId => $_getSZ(0);
  @$pb.TagNumber(1)
  set loanId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasLoanId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLoanId() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get prepaymentAmount => $_getI64(1);
  @$pb.TagNumber(2)
  set prepaymentAmount($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPrepaymentAmount() => $_has(1);
  @$pb.TagNumber(2)
  void clearPrepaymentAmount() => clearField(2);

  @$pb.TagNumber(3)
  PrepaymentStrategy get strategy => $_getN(2);
  @$pb.TagNumber(3)
  set strategy(PrepaymentStrategy v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasStrategy() => $_has(2);
  @$pb.TagNumber(3)
  void clearStrategy() => clearField(3);
}

class RecordRateChangeRequest extends $pb.GeneratedMessage {
  factory RecordRateChangeRequest({
    $core.String? loanId,
    $core.double? newRate,
    $4.Timestamp? effectiveDate,
  }) {
    final $result = create();
    if (loanId != null) {
      $result.loanId = loanId;
    }
    if (newRate != null) {
      $result.newRate = newRate;
    }
    if (effectiveDate != null) {
      $result.effectiveDate = effectiveDate;
    }
    return $result;
  }
  RecordRateChangeRequest._() : super();
  factory RecordRateChangeRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RecordRateChangeRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RecordRateChangeRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'loanId')
    ..a<$core.double>(2, _omitFieldNames ? '' : 'newRate', $pb.PbFieldType.OD)
    ..aOM<$4.Timestamp>(3, _omitFieldNames ? '' : 'effectiveDate', subBuilder: $4.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RecordRateChangeRequest clone() => RecordRateChangeRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RecordRateChangeRequest copyWith(void Function(RecordRateChangeRequest) updates) => super.copyWith((message) => updates(message as RecordRateChangeRequest)) as RecordRateChangeRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordRateChangeRequest create() => RecordRateChangeRequest._();
  RecordRateChangeRequest createEmptyInstance() => create();
  static $pb.PbList<RecordRateChangeRequest> createRepeated() => $pb.PbList<RecordRateChangeRequest>();
  @$core.pragma('dart2js:noInline')
  static RecordRateChangeRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RecordRateChangeRequest>(create);
  static RecordRateChangeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get loanId => $_getSZ(0);
  @$pb.TagNumber(1)
  set loanId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasLoanId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLoanId() => clearField(1);

  @$pb.TagNumber(2)
  $core.double get newRate => $_getN(1);
  @$pb.TagNumber(2)
  set newRate($core.double v) { $_setDouble(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNewRate() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewRate() => clearField(2);

  @$pb.TagNumber(3)
  $4.Timestamp get effectiveDate => $_getN(2);
  @$pb.TagNumber(3)
  set effectiveDate($4.Timestamp v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasEffectiveDate() => $_has(2);
  @$pb.TagNumber(3)
  void clearEffectiveDate() => clearField(3);
  @$pb.TagNumber(3)
  $4.Timestamp ensureEffectiveDate() => $_ensure(2);
}

class RecordPaymentRequest extends $pb.GeneratedMessage {
  factory RecordPaymentRequest({
    $core.String? loanId,
    $core.int? monthNumber,
  }) {
    final $result = create();
    if (loanId != null) {
      $result.loanId = loanId;
    }
    if (monthNumber != null) {
      $result.monthNumber = monthNumber;
    }
    return $result;
  }
  RecordPaymentRequest._() : super();
  factory RecordPaymentRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RecordPaymentRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RecordPaymentRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'loanId')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'monthNumber', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RecordPaymentRequest clone() => RecordPaymentRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RecordPaymentRequest copyWith(void Function(RecordPaymentRequest) updates) => super.copyWith((message) => updates(message as RecordPaymentRequest)) as RecordPaymentRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordPaymentRequest create() => RecordPaymentRequest._();
  RecordPaymentRequest createEmptyInstance() => create();
  static $pb.PbList<RecordPaymentRequest> createRepeated() => $pb.PbList<RecordPaymentRequest>();
  @$core.pragma('dart2js:noInline')
  static RecordPaymentRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RecordPaymentRequest>(create);
  static RecordPaymentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get loanId => $_getSZ(0);
  @$pb.TagNumber(1)
  set loanId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasLoanId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLoanId() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get monthNumber => $_getIZ(1);
  @$pb.TagNumber(2)
  set monthNumber($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMonthNumber() => $_has(1);
  @$pb.TagNumber(2)
  void clearMonthNumber() => clearField(2);
}

class LoanGroup extends $pb.GeneratedMessage {
  factory LoanGroup({
    $core.String? id,
    $core.String? userId,
    $core.String? name,
    $core.String? groupType,
    $fixnum.Int64? totalPrincipal,
    $core.int? paymentDay,
    $4.Timestamp? startDate,
    $core.String? accountId,
    $core.Iterable<Loan>? subLoans,
    $fixnum.Int64? totalMonthlyPayment,
    $4.Timestamp? createdAt,
    $4.Timestamp? updatedAt,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    if (name != null) {
      $result.name = name;
    }
    if (groupType != null) {
      $result.groupType = groupType;
    }
    if (totalPrincipal != null) {
      $result.totalPrincipal = totalPrincipal;
    }
    if (paymentDay != null) {
      $result.paymentDay = paymentDay;
    }
    if (startDate != null) {
      $result.startDate = startDate;
    }
    if (accountId != null) {
      $result.accountId = accountId;
    }
    if (subLoans != null) {
      $result.subLoans.addAll(subLoans);
    }
    if (totalMonthlyPayment != null) {
      $result.totalMonthlyPayment = totalMonthlyPayment;
    }
    if (createdAt != null) {
      $result.createdAt = createdAt;
    }
    if (updatedAt != null) {
      $result.updatedAt = updatedAt;
    }
    return $result;
  }
  LoanGroup._() : super();
  factory LoanGroup.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LoanGroup.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LoanGroup', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'groupType')
    ..aInt64(5, _omitFieldNames ? '' : 'totalPrincipal')
    ..a<$core.int>(6, _omitFieldNames ? '' : 'paymentDay', $pb.PbFieldType.O3)
    ..aOM<$4.Timestamp>(7, _omitFieldNames ? '' : 'startDate', subBuilder: $4.Timestamp.create)
    ..aOS(8, _omitFieldNames ? '' : 'accountId')
    ..pc<Loan>(9, _omitFieldNames ? '' : 'subLoans', $pb.PbFieldType.PM, subBuilder: Loan.create)
    ..aInt64(10, _omitFieldNames ? '' : 'totalMonthlyPayment')
    ..aOM<$4.Timestamp>(11, _omitFieldNames ? '' : 'createdAt', subBuilder: $4.Timestamp.create)
    ..aOM<$4.Timestamp>(12, _omitFieldNames ? '' : 'updatedAt', subBuilder: $4.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LoanGroup clone() => LoanGroup()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LoanGroup copyWith(void Function(LoanGroup) updates) => super.copyWith((message) => updates(message as LoanGroup)) as LoanGroup;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoanGroup create() => LoanGroup._();
  LoanGroup createEmptyInstance() => create();
  static $pb.PbList<LoanGroup> createRepeated() => $pb.PbList<LoanGroup>();
  @$core.pragma('dart2js:noInline')
  static LoanGroup getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LoanGroup>(create);
  static LoanGroup? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get groupType => $_getSZ(3);
  @$pb.TagNumber(4)
  set groupType($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasGroupType() => $_has(3);
  @$pb.TagNumber(4)
  void clearGroupType() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get totalPrincipal => $_getI64(4);
  @$pb.TagNumber(5)
  set totalPrincipal($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasTotalPrincipal() => $_has(4);
  @$pb.TagNumber(5)
  void clearTotalPrincipal() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get paymentDay => $_getIZ(5);
  @$pb.TagNumber(6)
  set paymentDay($core.int v) { $_setSignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasPaymentDay() => $_has(5);
  @$pb.TagNumber(6)
  void clearPaymentDay() => clearField(6);

  @$pb.TagNumber(7)
  $4.Timestamp get startDate => $_getN(6);
  @$pb.TagNumber(7)
  set startDate($4.Timestamp v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasStartDate() => $_has(6);
  @$pb.TagNumber(7)
  void clearStartDate() => clearField(7);
  @$pb.TagNumber(7)
  $4.Timestamp ensureStartDate() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.String get accountId => $_getSZ(7);
  @$pb.TagNumber(8)
  set accountId($core.String v) { $_setString(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasAccountId() => $_has(7);
  @$pb.TagNumber(8)
  void clearAccountId() => clearField(8);

  @$pb.TagNumber(9)
  $core.List<Loan> get subLoans => $_getList(8);

  @$pb.TagNumber(10)
  $fixnum.Int64 get totalMonthlyPayment => $_getI64(9);
  @$pb.TagNumber(10)
  set totalMonthlyPayment($fixnum.Int64 v) { $_setInt64(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasTotalMonthlyPayment() => $_has(9);
  @$pb.TagNumber(10)
  void clearTotalMonthlyPayment() => clearField(10);

  @$pb.TagNumber(11)
  $4.Timestamp get createdAt => $_getN(10);
  @$pb.TagNumber(11)
  set createdAt($4.Timestamp v) { setField(11, v); }
  @$pb.TagNumber(11)
  $core.bool hasCreatedAt() => $_has(10);
  @$pb.TagNumber(11)
  void clearCreatedAt() => clearField(11);
  @$pb.TagNumber(11)
  $4.Timestamp ensureCreatedAt() => $_ensure(10);

  @$pb.TagNumber(12)
  $4.Timestamp get updatedAt => $_getN(11);
  @$pb.TagNumber(12)
  set updatedAt($4.Timestamp v) { setField(12, v); }
  @$pb.TagNumber(12)
  $core.bool hasUpdatedAt() => $_has(11);
  @$pb.TagNumber(12)
  void clearUpdatedAt() => clearField(12);
  @$pb.TagNumber(12)
  $4.Timestamp ensureUpdatedAt() => $_ensure(11);
}

class SubLoanSpec extends $pb.GeneratedMessage {
  factory SubLoanSpec({
    $core.String? name,
    LoanSubType? subType,
    $fixnum.Int64? principal,
    $core.double? annualRate,
    $core.int? totalMonths,
    RepaymentMethod? repaymentMethod,
    RateType? rateType,
    $core.double? lprBase,
    $core.double? lprSpread,
    $core.int? rateAdjustMonth,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (subType != null) {
      $result.subType = subType;
    }
    if (principal != null) {
      $result.principal = principal;
    }
    if (annualRate != null) {
      $result.annualRate = annualRate;
    }
    if (totalMonths != null) {
      $result.totalMonths = totalMonths;
    }
    if (repaymentMethod != null) {
      $result.repaymentMethod = repaymentMethod;
    }
    if (rateType != null) {
      $result.rateType = rateType;
    }
    if (lprBase != null) {
      $result.lprBase = lprBase;
    }
    if (lprSpread != null) {
      $result.lprSpread = lprSpread;
    }
    if (rateAdjustMonth != null) {
      $result.rateAdjustMonth = rateAdjustMonth;
    }
    return $result;
  }
  SubLoanSpec._() : super();
  factory SubLoanSpec.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SubLoanSpec.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SubLoanSpec', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..e<LoanSubType>(2, _omitFieldNames ? '' : 'subType', $pb.PbFieldType.OE, defaultOrMaker: LoanSubType.LOAN_SUB_TYPE_UNSPECIFIED, valueOf: LoanSubType.valueOf, enumValues: LoanSubType.values)
    ..aInt64(3, _omitFieldNames ? '' : 'principal')
    ..a<$core.double>(4, _omitFieldNames ? '' : 'annualRate', $pb.PbFieldType.OD)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'totalMonths', $pb.PbFieldType.O3)
    ..e<RepaymentMethod>(6, _omitFieldNames ? '' : 'repaymentMethod', $pb.PbFieldType.OE, defaultOrMaker: RepaymentMethod.REPAYMENT_METHOD_UNSPECIFIED, valueOf: RepaymentMethod.valueOf, enumValues: RepaymentMethod.values)
    ..e<RateType>(7, _omitFieldNames ? '' : 'rateType', $pb.PbFieldType.OE, defaultOrMaker: RateType.RATE_TYPE_UNSPECIFIED, valueOf: RateType.valueOf, enumValues: RateType.values)
    ..a<$core.double>(8, _omitFieldNames ? '' : 'lprBase', $pb.PbFieldType.OD)
    ..a<$core.double>(9, _omitFieldNames ? '' : 'lprSpread', $pb.PbFieldType.OD)
    ..a<$core.int>(10, _omitFieldNames ? '' : 'rateAdjustMonth', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SubLoanSpec clone() => SubLoanSpec()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SubLoanSpec copyWith(void Function(SubLoanSpec) updates) => super.copyWith((message) => updates(message as SubLoanSpec)) as SubLoanSpec;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubLoanSpec create() => SubLoanSpec._();
  SubLoanSpec createEmptyInstance() => create();
  static $pb.PbList<SubLoanSpec> createRepeated() => $pb.PbList<SubLoanSpec>();
  @$core.pragma('dart2js:noInline')
  static SubLoanSpec getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SubLoanSpec>(create);
  static SubLoanSpec? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  LoanSubType get subType => $_getN(1);
  @$pb.TagNumber(2)
  set subType(LoanSubType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasSubType() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubType() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get principal => $_getI64(2);
  @$pb.TagNumber(3)
  set principal($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPrincipal() => $_has(2);
  @$pb.TagNumber(3)
  void clearPrincipal() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get annualRate => $_getN(3);
  @$pb.TagNumber(4)
  set annualRate($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAnnualRate() => $_has(3);
  @$pb.TagNumber(4)
  void clearAnnualRate() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get totalMonths => $_getIZ(4);
  @$pb.TagNumber(5)
  set totalMonths($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasTotalMonths() => $_has(4);
  @$pb.TagNumber(5)
  void clearTotalMonths() => clearField(5);

  @$pb.TagNumber(6)
  RepaymentMethod get repaymentMethod => $_getN(5);
  @$pb.TagNumber(6)
  set repaymentMethod(RepaymentMethod v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasRepaymentMethod() => $_has(5);
  @$pb.TagNumber(6)
  void clearRepaymentMethod() => clearField(6);

  @$pb.TagNumber(7)
  RateType get rateType => $_getN(6);
  @$pb.TagNumber(7)
  set rateType(RateType v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasRateType() => $_has(6);
  @$pb.TagNumber(7)
  void clearRateType() => clearField(7);

  @$pb.TagNumber(8)
  $core.double get lprBase => $_getN(7);
  @$pb.TagNumber(8)
  set lprBase($core.double v) { $_setDouble(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasLprBase() => $_has(7);
  @$pb.TagNumber(8)
  void clearLprBase() => clearField(8);

  @$pb.TagNumber(9)
  $core.double get lprSpread => $_getN(8);
  @$pb.TagNumber(9)
  set lprSpread($core.double v) { $_setDouble(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasLprSpread() => $_has(8);
  @$pb.TagNumber(9)
  void clearLprSpread() => clearField(9);

  @$pb.TagNumber(10)
  $core.int get rateAdjustMonth => $_getIZ(9);
  @$pb.TagNumber(10)
  set rateAdjustMonth($core.int v) { $_setSignedInt32(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasRateAdjustMonth() => $_has(9);
  @$pb.TagNumber(10)
  void clearRateAdjustMonth() => clearField(10);
}

class CreateLoanGroupRequest extends $pb.GeneratedMessage {
  factory CreateLoanGroupRequest({
    $core.String? name,
    $core.String? groupType,
    $core.int? paymentDay,
    $4.Timestamp? startDate,
    $core.String? accountId,
    $core.Iterable<SubLoanSpec>? subLoans,
    LoanType? loanType,
    $core.String? familyId,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (groupType != null) {
      $result.groupType = groupType;
    }
    if (paymentDay != null) {
      $result.paymentDay = paymentDay;
    }
    if (startDate != null) {
      $result.startDate = startDate;
    }
    if (accountId != null) {
      $result.accountId = accountId;
    }
    if (subLoans != null) {
      $result.subLoans.addAll(subLoans);
    }
    if (loanType != null) {
      $result.loanType = loanType;
    }
    if (familyId != null) {
      $result.familyId = familyId;
    }
    return $result;
  }
  CreateLoanGroupRequest._() : super();
  factory CreateLoanGroupRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CreateLoanGroupRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CreateLoanGroupRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'groupType')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'paymentDay', $pb.PbFieldType.O3)
    ..aOM<$4.Timestamp>(4, _omitFieldNames ? '' : 'startDate', subBuilder: $4.Timestamp.create)
    ..aOS(5, _omitFieldNames ? '' : 'accountId')
    ..pc<SubLoanSpec>(6, _omitFieldNames ? '' : 'subLoans', $pb.PbFieldType.PM, subBuilder: SubLoanSpec.create)
    ..e<LoanType>(7, _omitFieldNames ? '' : 'loanType', $pb.PbFieldType.OE, defaultOrMaker: LoanType.LOAN_TYPE_UNSPECIFIED, valueOf: LoanType.valueOf, enumValues: LoanType.values)
    ..aOS(8, _omitFieldNames ? '' : 'familyId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CreateLoanGroupRequest clone() => CreateLoanGroupRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CreateLoanGroupRequest copyWith(void Function(CreateLoanGroupRequest) updates) => super.copyWith((message) => updates(message as CreateLoanGroupRequest)) as CreateLoanGroupRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateLoanGroupRequest create() => CreateLoanGroupRequest._();
  CreateLoanGroupRequest createEmptyInstance() => create();
  static $pb.PbList<CreateLoanGroupRequest> createRepeated() => $pb.PbList<CreateLoanGroupRequest>();
  @$core.pragma('dart2js:noInline')
  static CreateLoanGroupRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CreateLoanGroupRequest>(create);
  static CreateLoanGroupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get groupType => $_getSZ(1);
  @$pb.TagNumber(2)
  set groupType($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasGroupType() => $_has(1);
  @$pb.TagNumber(2)
  void clearGroupType() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get paymentDay => $_getIZ(2);
  @$pb.TagNumber(3)
  set paymentDay($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPaymentDay() => $_has(2);
  @$pb.TagNumber(3)
  void clearPaymentDay() => clearField(3);

  @$pb.TagNumber(4)
  $4.Timestamp get startDate => $_getN(3);
  @$pb.TagNumber(4)
  set startDate($4.Timestamp v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasStartDate() => $_has(3);
  @$pb.TagNumber(4)
  void clearStartDate() => clearField(4);
  @$pb.TagNumber(4)
  $4.Timestamp ensureStartDate() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.String get accountId => $_getSZ(4);
  @$pb.TagNumber(5)
  set accountId($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasAccountId() => $_has(4);
  @$pb.TagNumber(5)
  void clearAccountId() => clearField(5);

  @$pb.TagNumber(6)
  $core.List<SubLoanSpec> get subLoans => $_getList(5);

  @$pb.TagNumber(7)
  LoanType get loanType => $_getN(6);
  @$pb.TagNumber(7)
  set loanType(LoanType v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasLoanType() => $_has(6);
  @$pb.TagNumber(7)
  void clearLoanType() => clearField(7);

  @$pb.TagNumber(8)
  $core.String get familyId => $_getSZ(7);
  @$pb.TagNumber(8)
  set familyId($core.String v) { $_setString(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasFamilyId() => $_has(7);
  @$pb.TagNumber(8)
  void clearFamilyId() => clearField(8);
}

class GetLoanGroupRequest extends $pb.GeneratedMessage {
  factory GetLoanGroupRequest({
    $core.String? groupId,
  }) {
    final $result = create();
    if (groupId != null) {
      $result.groupId = groupId;
    }
    return $result;
  }
  GetLoanGroupRequest._() : super();
  factory GetLoanGroupRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetLoanGroupRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetLoanGroupRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'groupId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetLoanGroupRequest clone() => GetLoanGroupRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetLoanGroupRequest copyWith(void Function(GetLoanGroupRequest) updates) => super.copyWith((message) => updates(message as GetLoanGroupRequest)) as GetLoanGroupRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetLoanGroupRequest create() => GetLoanGroupRequest._();
  GetLoanGroupRequest createEmptyInstance() => create();
  static $pb.PbList<GetLoanGroupRequest> createRepeated() => $pb.PbList<GetLoanGroupRequest>();
  @$core.pragma('dart2js:noInline')
  static GetLoanGroupRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetLoanGroupRequest>(create);
  static GetLoanGroupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get groupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set groupId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasGroupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroupId() => clearField(1);
}

class ListLoanGroupsRequest extends $pb.GeneratedMessage {
  factory ListLoanGroupsRequest({
    $core.String? familyId,
  }) {
    final $result = create();
    if (familyId != null) {
      $result.familyId = familyId;
    }
    return $result;
  }
  ListLoanGroupsRequest._() : super();
  factory ListLoanGroupsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListLoanGroupsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListLoanGroupsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListLoanGroupsRequest clone() => ListLoanGroupsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListLoanGroupsRequest copyWith(void Function(ListLoanGroupsRequest) updates) => super.copyWith((message) => updates(message as ListLoanGroupsRequest)) as ListLoanGroupsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListLoanGroupsRequest create() => ListLoanGroupsRequest._();
  ListLoanGroupsRequest createEmptyInstance() => create();
  static $pb.PbList<ListLoanGroupsRequest> createRepeated() => $pb.PbList<ListLoanGroupsRequest>();
  @$core.pragma('dart2js:noInline')
  static ListLoanGroupsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListLoanGroupsRequest>(create);
  static ListLoanGroupsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get familyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set familyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamilyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamilyId() => clearField(1);
}

class ListLoanGroupsResponse extends $pb.GeneratedMessage {
  factory ListLoanGroupsResponse({
    $core.Iterable<LoanGroup>? groups,
  }) {
    final $result = create();
    if (groups != null) {
      $result.groups.addAll(groups);
    }
    return $result;
  }
  ListLoanGroupsResponse._() : super();
  factory ListLoanGroupsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListLoanGroupsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListLoanGroupsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..pc<LoanGroup>(1, _omitFieldNames ? '' : 'groups', $pb.PbFieldType.PM, subBuilder: LoanGroup.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListLoanGroupsResponse clone() => ListLoanGroupsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListLoanGroupsResponse copyWith(void Function(ListLoanGroupsResponse) updates) => super.copyWith((message) => updates(message as ListLoanGroupsResponse)) as ListLoanGroupsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListLoanGroupsResponse create() => ListLoanGroupsResponse._();
  ListLoanGroupsResponse createEmptyInstance() => create();
  static $pb.PbList<ListLoanGroupsResponse> createRepeated() => $pb.PbList<ListLoanGroupsResponse>();
  @$core.pragma('dart2js:noInline')
  static ListLoanGroupsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListLoanGroupsResponse>(create);
  static ListLoanGroupsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<LoanGroup> get groups => $_getList(0);
}

class SimulateGroupPrepaymentRequest extends $pb.GeneratedMessage {
  factory SimulateGroupPrepaymentRequest({
    $core.String? groupId,
    $core.String? targetLoanId,
    $fixnum.Int64? prepaymentAmount,
    PrepaymentStrategy? strategy,
  }) {
    final $result = create();
    if (groupId != null) {
      $result.groupId = groupId;
    }
    if (targetLoanId != null) {
      $result.targetLoanId = targetLoanId;
    }
    if (prepaymentAmount != null) {
      $result.prepaymentAmount = prepaymentAmount;
    }
    if (strategy != null) {
      $result.strategy = strategy;
    }
    return $result;
  }
  SimulateGroupPrepaymentRequest._() : super();
  factory SimulateGroupPrepaymentRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SimulateGroupPrepaymentRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SimulateGroupPrepaymentRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'groupId')
    ..aOS(2, _omitFieldNames ? '' : 'targetLoanId')
    ..aInt64(3, _omitFieldNames ? '' : 'prepaymentAmount')
    ..e<PrepaymentStrategy>(4, _omitFieldNames ? '' : 'strategy', $pb.PbFieldType.OE, defaultOrMaker: PrepaymentStrategy.PREPAYMENT_STRATEGY_UNSPECIFIED, valueOf: PrepaymentStrategy.valueOf, enumValues: PrepaymentStrategy.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SimulateGroupPrepaymentRequest clone() => SimulateGroupPrepaymentRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SimulateGroupPrepaymentRequest copyWith(void Function(SimulateGroupPrepaymentRequest) updates) => super.copyWith((message) => updates(message as SimulateGroupPrepaymentRequest)) as SimulateGroupPrepaymentRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SimulateGroupPrepaymentRequest create() => SimulateGroupPrepaymentRequest._();
  SimulateGroupPrepaymentRequest createEmptyInstance() => create();
  static $pb.PbList<SimulateGroupPrepaymentRequest> createRepeated() => $pb.PbList<SimulateGroupPrepaymentRequest>();
  @$core.pragma('dart2js:noInline')
  static SimulateGroupPrepaymentRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SimulateGroupPrepaymentRequest>(create);
  static SimulateGroupPrepaymentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get groupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set groupId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasGroupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroupId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get targetLoanId => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetLoanId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTargetLoanId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetLoanId() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get prepaymentAmount => $_getI64(2);
  @$pb.TagNumber(3)
  set prepaymentAmount($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPrepaymentAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearPrepaymentAmount() => clearField(3);

  @$pb.TagNumber(4)
  PrepaymentStrategy get strategy => $_getN(3);
  @$pb.TagNumber(4)
  set strategy(PrepaymentStrategy v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasStrategy() => $_has(3);
  @$pb.TagNumber(4)
  void clearStrategy() => clearField(4);
}

class GroupPrepaymentSimulation extends $pb.GeneratedMessage {
  factory GroupPrepaymentSimulation({
    $core.String? targetLoanId,
    PrepaymentSimulation? targetSim,
    $fixnum.Int64? totalInterestSaved,
  }) {
    final $result = create();
    if (targetLoanId != null) {
      $result.targetLoanId = targetLoanId;
    }
    if (targetSim != null) {
      $result.targetSim = targetSim;
    }
    if (totalInterestSaved != null) {
      $result.totalInterestSaved = totalInterestSaved;
    }
    return $result;
  }
  GroupPrepaymentSimulation._() : super();
  factory GroupPrepaymentSimulation.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GroupPrepaymentSimulation.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GroupPrepaymentSimulation', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.loan.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'targetLoanId')
    ..aOM<PrepaymentSimulation>(2, _omitFieldNames ? '' : 'targetSim', subBuilder: PrepaymentSimulation.create)
    ..aInt64(3, _omitFieldNames ? '' : 'totalInterestSaved')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GroupPrepaymentSimulation clone() => GroupPrepaymentSimulation()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GroupPrepaymentSimulation copyWith(void Function(GroupPrepaymentSimulation) updates) => super.copyWith((message) => updates(message as GroupPrepaymentSimulation)) as GroupPrepaymentSimulation;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GroupPrepaymentSimulation create() => GroupPrepaymentSimulation._();
  GroupPrepaymentSimulation createEmptyInstance() => create();
  static $pb.PbList<GroupPrepaymentSimulation> createRepeated() => $pb.PbList<GroupPrepaymentSimulation>();
  @$core.pragma('dart2js:noInline')
  static GroupPrepaymentSimulation getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GroupPrepaymentSimulation>(create);
  static GroupPrepaymentSimulation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get targetLoanId => $_getSZ(0);
  @$pb.TagNumber(1)
  set targetLoanId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTargetLoanId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTargetLoanId() => clearField(1);

  @$pb.TagNumber(2)
  PrepaymentSimulation get targetSim => $_getN(1);
  @$pb.TagNumber(2)
  set targetSim(PrepaymentSimulation v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasTargetSim() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetSim() => clearField(2);
  @$pb.TagNumber(2)
  PrepaymentSimulation ensureTargetSim() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get totalInterestSaved => $_getI64(2);
  @$pb.TagNumber(3)
  set totalInterestSaved($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTotalInterestSaved() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalInterestSaved() => clearField(3);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
