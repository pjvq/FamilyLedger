//
//  Generated code. Do not modify.
//  source: budget.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'google/protobuf/timestamp.pb.dart' as $2;

class Budget extends $pb.GeneratedMessage {
  factory Budget({
    $core.String? id,
    $core.String? userId,
    $core.String? familyId,
    $core.int? year,
    $core.int? month,
    $fixnum.Int64? totalAmount,
    $core.Iterable<CategoryBudget>? categoryBudgets,
    $2.Timestamp? createdAt,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    if (familyId != null) {
      $result.familyId = familyId;
    }
    if (year != null) {
      $result.year = year;
    }
    if (month != null) {
      $result.month = month;
    }
    if (totalAmount != null) {
      $result.totalAmount = totalAmount;
    }
    if (categoryBudgets != null) {
      $result.categoryBudgets.addAll(categoryBudgets);
    }
    if (createdAt != null) {
      $result.createdAt = createdAt;
    }
    return $result;
  }
  Budget._() : super();
  factory Budget.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Budget.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Budget', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'familyId')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'year', $pb.PbFieldType.O3)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'month', $pb.PbFieldType.O3)
    ..aInt64(6, _omitFieldNames ? '' : 'totalAmount')
    ..pc<CategoryBudget>(7, _omitFieldNames ? '' : 'categoryBudgets', $pb.PbFieldType.PM, subBuilder: CategoryBudget.create)
    ..aOM<$2.Timestamp>(8, _omitFieldNames ? '' : 'createdAt', subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Budget clone() => Budget()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Budget copyWith(void Function(Budget) updates) => super.copyWith((message) => updates(message as Budget)) as Budget;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Budget create() => Budget._();
  Budget createEmptyInstance() => create();
  static $pb.PbList<Budget> createRepeated() => $pb.PbList<Budget>();
  @$core.pragma('dart2js:noInline')
  static Budget getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Budget>(create);
  static Budget? _defaultInstance;

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
  $core.String get familyId => $_getSZ(2);
  @$pb.TagNumber(3)
  set familyId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasFamilyId() => $_has(2);
  @$pb.TagNumber(3)
  void clearFamilyId() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get year => $_getIZ(3);
  @$pb.TagNumber(4)
  set year($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasYear() => $_has(3);
  @$pb.TagNumber(4)
  void clearYear() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get month => $_getIZ(4);
  @$pb.TagNumber(5)
  set month($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasMonth() => $_has(4);
  @$pb.TagNumber(5)
  void clearMonth() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get totalAmount => $_getI64(5);
  @$pb.TagNumber(6)
  set totalAmount($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasTotalAmount() => $_has(5);
  @$pb.TagNumber(6)
  void clearTotalAmount() => clearField(6);

  @$pb.TagNumber(7)
  $core.List<CategoryBudget> get categoryBudgets => $_getList(6);

  @$pb.TagNumber(8)
  $2.Timestamp get createdAt => $_getN(7);
  @$pb.TagNumber(8)
  set createdAt($2.Timestamp v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasCreatedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedAt() => clearField(8);
  @$pb.TagNumber(8)
  $2.Timestamp ensureCreatedAt() => $_ensure(7);
}

class CategoryBudget extends $pb.GeneratedMessage {
  factory CategoryBudget({
    $core.String? categoryId,
    $fixnum.Int64? amount,
  }) {
    final $result = create();
    if (categoryId != null) {
      $result.categoryId = categoryId;
    }
    if (amount != null) {
      $result.amount = amount;
    }
    return $result;
  }
  CategoryBudget._() : super();
  factory CategoryBudget.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CategoryBudget.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CategoryBudget', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'categoryId')
    ..aInt64(2, _omitFieldNames ? '' : 'amount')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CategoryBudget clone() => CategoryBudget()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CategoryBudget copyWith(void Function(CategoryBudget) updates) => super.copyWith((message) => updates(message as CategoryBudget)) as CategoryBudget;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CategoryBudget create() => CategoryBudget._();
  CategoryBudget createEmptyInstance() => create();
  static $pb.PbList<CategoryBudget> createRepeated() => $pb.PbList<CategoryBudget>();
  @$core.pragma('dart2js:noInline')
  static CategoryBudget getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CategoryBudget>(create);
  static CategoryBudget? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get categoryId => $_getSZ(0);
  @$pb.TagNumber(1)
  set categoryId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCategoryId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCategoryId() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get amount => $_getI64(1);
  @$pb.TagNumber(2)
  set amount($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAmount() => $_has(1);
  @$pb.TagNumber(2)
  void clearAmount() => clearField(2);
}

class BudgetExecution extends $pb.GeneratedMessage {
  factory BudgetExecution({
    $fixnum.Int64? totalBudget,
    $fixnum.Int64? totalSpent,
    $core.double? executionRate,
    $core.Iterable<CategoryExecution>? categoryExecutions,
  }) {
    final $result = create();
    if (totalBudget != null) {
      $result.totalBudget = totalBudget;
    }
    if (totalSpent != null) {
      $result.totalSpent = totalSpent;
    }
    if (executionRate != null) {
      $result.executionRate = executionRate;
    }
    if (categoryExecutions != null) {
      $result.categoryExecutions.addAll(categoryExecutions);
    }
    return $result;
  }
  BudgetExecution._() : super();
  factory BudgetExecution.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BudgetExecution.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BudgetExecution', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'totalBudget')
    ..aInt64(2, _omitFieldNames ? '' : 'totalSpent')
    ..a<$core.double>(3, _omitFieldNames ? '' : 'executionRate', $pb.PbFieldType.OD)
    ..pc<CategoryExecution>(4, _omitFieldNames ? '' : 'categoryExecutions', $pb.PbFieldType.PM, subBuilder: CategoryExecution.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BudgetExecution clone() => BudgetExecution()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BudgetExecution copyWith(void Function(BudgetExecution) updates) => super.copyWith((message) => updates(message as BudgetExecution)) as BudgetExecution;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BudgetExecution create() => BudgetExecution._();
  BudgetExecution createEmptyInstance() => create();
  static $pb.PbList<BudgetExecution> createRepeated() => $pb.PbList<BudgetExecution>();
  @$core.pragma('dart2js:noInline')
  static BudgetExecution getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BudgetExecution>(create);
  static BudgetExecution? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get totalBudget => $_getI64(0);
  @$pb.TagNumber(1)
  set totalBudget($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTotalBudget() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotalBudget() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get totalSpent => $_getI64(1);
  @$pb.TagNumber(2)
  set totalSpent($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTotalSpent() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalSpent() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get executionRate => $_getN(2);
  @$pb.TagNumber(3)
  set executionRate($core.double v) { $_setDouble(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasExecutionRate() => $_has(2);
  @$pb.TagNumber(3)
  void clearExecutionRate() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<CategoryExecution> get categoryExecutions => $_getList(3);
}

class CategoryExecution extends $pb.GeneratedMessage {
  factory CategoryExecution({
    $core.String? categoryId,
    $core.String? categoryName,
    $fixnum.Int64? budgetAmount,
    $fixnum.Int64? spentAmount,
    $core.double? executionRate,
  }) {
    final $result = create();
    if (categoryId != null) {
      $result.categoryId = categoryId;
    }
    if (categoryName != null) {
      $result.categoryName = categoryName;
    }
    if (budgetAmount != null) {
      $result.budgetAmount = budgetAmount;
    }
    if (spentAmount != null) {
      $result.spentAmount = spentAmount;
    }
    if (executionRate != null) {
      $result.executionRate = executionRate;
    }
    return $result;
  }
  CategoryExecution._() : super();
  factory CategoryExecution.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CategoryExecution.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CategoryExecution', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'categoryId')
    ..aOS(2, _omitFieldNames ? '' : 'categoryName')
    ..aInt64(3, _omitFieldNames ? '' : 'budgetAmount')
    ..aInt64(4, _omitFieldNames ? '' : 'spentAmount')
    ..a<$core.double>(5, _omitFieldNames ? '' : 'executionRate', $pb.PbFieldType.OD)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CategoryExecution clone() => CategoryExecution()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CategoryExecution copyWith(void Function(CategoryExecution) updates) => super.copyWith((message) => updates(message as CategoryExecution)) as CategoryExecution;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CategoryExecution create() => CategoryExecution._();
  CategoryExecution createEmptyInstance() => create();
  static $pb.PbList<CategoryExecution> createRepeated() => $pb.PbList<CategoryExecution>();
  @$core.pragma('dart2js:noInline')
  static CategoryExecution getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CategoryExecution>(create);
  static CategoryExecution? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get categoryId => $_getSZ(0);
  @$pb.TagNumber(1)
  set categoryId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCategoryId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCategoryId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get categoryName => $_getSZ(1);
  @$pb.TagNumber(2)
  set categoryName($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCategoryName() => $_has(1);
  @$pb.TagNumber(2)
  void clearCategoryName() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get budgetAmount => $_getI64(2);
  @$pb.TagNumber(3)
  set budgetAmount($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasBudgetAmount() => $_has(2);
  @$pb.TagNumber(3)
  void clearBudgetAmount() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get spentAmount => $_getI64(3);
  @$pb.TagNumber(4)
  set spentAmount($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSpentAmount() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpentAmount() => clearField(4);

  @$pb.TagNumber(5)
  $core.double get executionRate => $_getN(4);
  @$pb.TagNumber(5)
  set executionRate($core.double v) { $_setDouble(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasExecutionRate() => $_has(4);
  @$pb.TagNumber(5)
  void clearExecutionRate() => clearField(5);
}

class CreateBudgetRequest extends $pb.GeneratedMessage {
  factory CreateBudgetRequest({
    $core.String? familyId,
    $core.int? year,
    $core.int? month,
    $fixnum.Int64? totalAmount,
    $core.Iterable<CategoryBudget>? categoryBudgets,
  }) {
    final $result = create();
    if (familyId != null) {
      $result.familyId = familyId;
    }
    if (year != null) {
      $result.year = year;
    }
    if (month != null) {
      $result.month = month;
    }
    if (totalAmount != null) {
      $result.totalAmount = totalAmount;
    }
    if (categoryBudgets != null) {
      $result.categoryBudgets.addAll(categoryBudgets);
    }
    return $result;
  }
  CreateBudgetRequest._() : super();
  factory CreateBudgetRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CreateBudgetRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CreateBudgetRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'year', $pb.PbFieldType.O3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'month', $pb.PbFieldType.O3)
    ..aInt64(4, _omitFieldNames ? '' : 'totalAmount')
    ..pc<CategoryBudget>(5, _omitFieldNames ? '' : 'categoryBudgets', $pb.PbFieldType.PM, subBuilder: CategoryBudget.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CreateBudgetRequest clone() => CreateBudgetRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CreateBudgetRequest copyWith(void Function(CreateBudgetRequest) updates) => super.copyWith((message) => updates(message as CreateBudgetRequest)) as CreateBudgetRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateBudgetRequest create() => CreateBudgetRequest._();
  CreateBudgetRequest createEmptyInstance() => create();
  static $pb.PbList<CreateBudgetRequest> createRepeated() => $pb.PbList<CreateBudgetRequest>();
  @$core.pragma('dart2js:noInline')
  static CreateBudgetRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CreateBudgetRequest>(create);
  static CreateBudgetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get familyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set familyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamilyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamilyId() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get year => $_getIZ(1);
  @$pb.TagNumber(2)
  set year($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasYear() => $_has(1);
  @$pb.TagNumber(2)
  void clearYear() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get month => $_getIZ(2);
  @$pb.TagNumber(3)
  set month($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasMonth() => $_has(2);
  @$pb.TagNumber(3)
  void clearMonth() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get totalAmount => $_getI64(3);
  @$pb.TagNumber(4)
  set totalAmount($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasTotalAmount() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalAmount() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<CategoryBudget> get categoryBudgets => $_getList(4);
}

class CreateBudgetResponse extends $pb.GeneratedMessage {
  factory CreateBudgetResponse({
    Budget? budget,
  }) {
    final $result = create();
    if (budget != null) {
      $result.budget = budget;
    }
    return $result;
  }
  CreateBudgetResponse._() : super();
  factory CreateBudgetResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CreateBudgetResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CreateBudgetResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..aOM<Budget>(1, _omitFieldNames ? '' : 'budget', subBuilder: Budget.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CreateBudgetResponse clone() => CreateBudgetResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CreateBudgetResponse copyWith(void Function(CreateBudgetResponse) updates) => super.copyWith((message) => updates(message as CreateBudgetResponse)) as CreateBudgetResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateBudgetResponse create() => CreateBudgetResponse._();
  CreateBudgetResponse createEmptyInstance() => create();
  static $pb.PbList<CreateBudgetResponse> createRepeated() => $pb.PbList<CreateBudgetResponse>();
  @$core.pragma('dart2js:noInline')
  static CreateBudgetResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CreateBudgetResponse>(create);
  static CreateBudgetResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Budget get budget => $_getN(0);
  @$pb.TagNumber(1)
  set budget(Budget v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasBudget() => $_has(0);
  @$pb.TagNumber(1)
  void clearBudget() => clearField(1);
  @$pb.TagNumber(1)
  Budget ensureBudget() => $_ensure(0);
}

class GetBudgetRequest extends $pb.GeneratedMessage {
  factory GetBudgetRequest({
    $core.String? budgetId,
  }) {
    final $result = create();
    if (budgetId != null) {
      $result.budgetId = budgetId;
    }
    return $result;
  }
  GetBudgetRequest._() : super();
  factory GetBudgetRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetBudgetRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetBudgetRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'budgetId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetBudgetRequest clone() => GetBudgetRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetBudgetRequest copyWith(void Function(GetBudgetRequest) updates) => super.copyWith((message) => updates(message as GetBudgetRequest)) as GetBudgetRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetBudgetRequest create() => GetBudgetRequest._();
  GetBudgetRequest createEmptyInstance() => create();
  static $pb.PbList<GetBudgetRequest> createRepeated() => $pb.PbList<GetBudgetRequest>();
  @$core.pragma('dart2js:noInline')
  static GetBudgetRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetBudgetRequest>(create);
  static GetBudgetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get budgetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set budgetId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasBudgetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBudgetId() => clearField(1);
}

class GetBudgetResponse extends $pb.GeneratedMessage {
  factory GetBudgetResponse({
    Budget? budget,
    BudgetExecution? execution,
  }) {
    final $result = create();
    if (budget != null) {
      $result.budget = budget;
    }
    if (execution != null) {
      $result.execution = execution;
    }
    return $result;
  }
  GetBudgetResponse._() : super();
  factory GetBudgetResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetBudgetResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetBudgetResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..aOM<Budget>(1, _omitFieldNames ? '' : 'budget', subBuilder: Budget.create)
    ..aOM<BudgetExecution>(2, _omitFieldNames ? '' : 'execution', subBuilder: BudgetExecution.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetBudgetResponse clone() => GetBudgetResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetBudgetResponse copyWith(void Function(GetBudgetResponse) updates) => super.copyWith((message) => updates(message as GetBudgetResponse)) as GetBudgetResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetBudgetResponse create() => GetBudgetResponse._();
  GetBudgetResponse createEmptyInstance() => create();
  static $pb.PbList<GetBudgetResponse> createRepeated() => $pb.PbList<GetBudgetResponse>();
  @$core.pragma('dart2js:noInline')
  static GetBudgetResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetBudgetResponse>(create);
  static GetBudgetResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Budget get budget => $_getN(0);
  @$pb.TagNumber(1)
  set budget(Budget v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasBudget() => $_has(0);
  @$pb.TagNumber(1)
  void clearBudget() => clearField(1);
  @$pb.TagNumber(1)
  Budget ensureBudget() => $_ensure(0);

  @$pb.TagNumber(2)
  BudgetExecution get execution => $_getN(1);
  @$pb.TagNumber(2)
  set execution(BudgetExecution v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasExecution() => $_has(1);
  @$pb.TagNumber(2)
  void clearExecution() => clearField(2);
  @$pb.TagNumber(2)
  BudgetExecution ensureExecution() => $_ensure(1);
}

class ListBudgetsRequest extends $pb.GeneratedMessage {
  factory ListBudgetsRequest({
    $core.String? familyId,
    $core.int? year,
  }) {
    final $result = create();
    if (familyId != null) {
      $result.familyId = familyId;
    }
    if (year != null) {
      $result.year = year;
    }
    return $result;
  }
  ListBudgetsRequest._() : super();
  factory ListBudgetsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListBudgetsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListBudgetsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'year', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListBudgetsRequest clone() => ListBudgetsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListBudgetsRequest copyWith(void Function(ListBudgetsRequest) updates) => super.copyWith((message) => updates(message as ListBudgetsRequest)) as ListBudgetsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListBudgetsRequest create() => ListBudgetsRequest._();
  ListBudgetsRequest createEmptyInstance() => create();
  static $pb.PbList<ListBudgetsRequest> createRepeated() => $pb.PbList<ListBudgetsRequest>();
  @$core.pragma('dart2js:noInline')
  static ListBudgetsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListBudgetsRequest>(create);
  static ListBudgetsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get familyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set familyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamilyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamilyId() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get year => $_getIZ(1);
  @$pb.TagNumber(2)
  set year($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasYear() => $_has(1);
  @$pb.TagNumber(2)
  void clearYear() => clearField(2);
}

class ListBudgetsResponse extends $pb.GeneratedMessage {
  factory ListBudgetsResponse({
    $core.Iterable<Budget>? budgets,
  }) {
    final $result = create();
    if (budgets != null) {
      $result.budgets.addAll(budgets);
    }
    return $result;
  }
  ListBudgetsResponse._() : super();
  factory ListBudgetsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListBudgetsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListBudgetsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..pc<Budget>(1, _omitFieldNames ? '' : 'budgets', $pb.PbFieldType.PM, subBuilder: Budget.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListBudgetsResponse clone() => ListBudgetsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListBudgetsResponse copyWith(void Function(ListBudgetsResponse) updates) => super.copyWith((message) => updates(message as ListBudgetsResponse)) as ListBudgetsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListBudgetsResponse create() => ListBudgetsResponse._();
  ListBudgetsResponse createEmptyInstance() => create();
  static $pb.PbList<ListBudgetsResponse> createRepeated() => $pb.PbList<ListBudgetsResponse>();
  @$core.pragma('dart2js:noInline')
  static ListBudgetsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListBudgetsResponse>(create);
  static ListBudgetsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<Budget> get budgets => $_getList(0);
}

class UpdateBudgetRequest extends $pb.GeneratedMessage {
  factory UpdateBudgetRequest({
    $core.String? budgetId,
    $fixnum.Int64? totalAmount,
    $core.Iterable<CategoryBudget>? categoryBudgets,
  }) {
    final $result = create();
    if (budgetId != null) {
      $result.budgetId = budgetId;
    }
    if (totalAmount != null) {
      $result.totalAmount = totalAmount;
    }
    if (categoryBudgets != null) {
      $result.categoryBudgets.addAll(categoryBudgets);
    }
    return $result;
  }
  UpdateBudgetRequest._() : super();
  factory UpdateBudgetRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdateBudgetRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UpdateBudgetRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'budgetId')
    ..aInt64(2, _omitFieldNames ? '' : 'totalAmount')
    ..pc<CategoryBudget>(3, _omitFieldNames ? '' : 'categoryBudgets', $pb.PbFieldType.PM, subBuilder: CategoryBudget.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdateBudgetRequest clone() => UpdateBudgetRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdateBudgetRequest copyWith(void Function(UpdateBudgetRequest) updates) => super.copyWith((message) => updates(message as UpdateBudgetRequest)) as UpdateBudgetRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateBudgetRequest create() => UpdateBudgetRequest._();
  UpdateBudgetRequest createEmptyInstance() => create();
  static $pb.PbList<UpdateBudgetRequest> createRepeated() => $pb.PbList<UpdateBudgetRequest>();
  @$core.pragma('dart2js:noInline')
  static UpdateBudgetRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateBudgetRequest>(create);
  static UpdateBudgetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get budgetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set budgetId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasBudgetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBudgetId() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get totalAmount => $_getI64(1);
  @$pb.TagNumber(2)
  set totalAmount($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTotalAmount() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalAmount() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<CategoryBudget> get categoryBudgets => $_getList(2);
}

class UpdateBudgetResponse extends $pb.GeneratedMessage {
  factory UpdateBudgetResponse({
    Budget? budget,
  }) {
    final $result = create();
    if (budget != null) {
      $result.budget = budget;
    }
    return $result;
  }
  UpdateBudgetResponse._() : super();
  factory UpdateBudgetResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdateBudgetResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UpdateBudgetResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..aOM<Budget>(1, _omitFieldNames ? '' : 'budget', subBuilder: Budget.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdateBudgetResponse clone() => UpdateBudgetResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdateBudgetResponse copyWith(void Function(UpdateBudgetResponse) updates) => super.copyWith((message) => updates(message as UpdateBudgetResponse)) as UpdateBudgetResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateBudgetResponse create() => UpdateBudgetResponse._();
  UpdateBudgetResponse createEmptyInstance() => create();
  static $pb.PbList<UpdateBudgetResponse> createRepeated() => $pb.PbList<UpdateBudgetResponse>();
  @$core.pragma('dart2js:noInline')
  static UpdateBudgetResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateBudgetResponse>(create);
  static UpdateBudgetResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Budget get budget => $_getN(0);
  @$pb.TagNumber(1)
  set budget(Budget v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasBudget() => $_has(0);
  @$pb.TagNumber(1)
  void clearBudget() => clearField(1);
  @$pb.TagNumber(1)
  Budget ensureBudget() => $_ensure(0);
}

class DeleteBudgetRequest extends $pb.GeneratedMessage {
  factory DeleteBudgetRequest({
    $core.String? budgetId,
  }) {
    final $result = create();
    if (budgetId != null) {
      $result.budgetId = budgetId;
    }
    return $result;
  }
  DeleteBudgetRequest._() : super();
  factory DeleteBudgetRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeleteBudgetRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeleteBudgetRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'budgetId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeleteBudgetRequest clone() => DeleteBudgetRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeleteBudgetRequest copyWith(void Function(DeleteBudgetRequest) updates) => super.copyWith((message) => updates(message as DeleteBudgetRequest)) as DeleteBudgetRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteBudgetRequest create() => DeleteBudgetRequest._();
  DeleteBudgetRequest createEmptyInstance() => create();
  static $pb.PbList<DeleteBudgetRequest> createRepeated() => $pb.PbList<DeleteBudgetRequest>();
  @$core.pragma('dart2js:noInline')
  static DeleteBudgetRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeleteBudgetRequest>(create);
  static DeleteBudgetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get budgetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set budgetId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasBudgetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBudgetId() => clearField(1);
}

class DeleteBudgetResponse extends $pb.GeneratedMessage {
  factory DeleteBudgetResponse() => create();
  DeleteBudgetResponse._() : super();
  factory DeleteBudgetResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeleteBudgetResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeleteBudgetResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeleteBudgetResponse clone() => DeleteBudgetResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeleteBudgetResponse copyWith(void Function(DeleteBudgetResponse) updates) => super.copyWith((message) => updates(message as DeleteBudgetResponse)) as DeleteBudgetResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteBudgetResponse create() => DeleteBudgetResponse._();
  DeleteBudgetResponse createEmptyInstance() => create();
  static $pb.PbList<DeleteBudgetResponse> createRepeated() => $pb.PbList<DeleteBudgetResponse>();
  @$core.pragma('dart2js:noInline')
  static DeleteBudgetResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeleteBudgetResponse>(create);
  static DeleteBudgetResponse? _defaultInstance;
}

class GetBudgetExecutionRequest extends $pb.GeneratedMessage {
  factory GetBudgetExecutionRequest({
    $core.String? budgetId,
  }) {
    final $result = create();
    if (budgetId != null) {
      $result.budgetId = budgetId;
    }
    return $result;
  }
  GetBudgetExecutionRequest._() : super();
  factory GetBudgetExecutionRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetBudgetExecutionRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetBudgetExecutionRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'budgetId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetBudgetExecutionRequest clone() => GetBudgetExecutionRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetBudgetExecutionRequest copyWith(void Function(GetBudgetExecutionRequest) updates) => super.copyWith((message) => updates(message as GetBudgetExecutionRequest)) as GetBudgetExecutionRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetBudgetExecutionRequest create() => GetBudgetExecutionRequest._();
  GetBudgetExecutionRequest createEmptyInstance() => create();
  static $pb.PbList<GetBudgetExecutionRequest> createRepeated() => $pb.PbList<GetBudgetExecutionRequest>();
  @$core.pragma('dart2js:noInline')
  static GetBudgetExecutionRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetBudgetExecutionRequest>(create);
  static GetBudgetExecutionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get budgetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set budgetId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasBudgetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBudgetId() => clearField(1);
}

class GetBudgetExecutionResponse extends $pb.GeneratedMessage {
  factory GetBudgetExecutionResponse({
    BudgetExecution? execution,
  }) {
    final $result = create();
    if (execution != null) {
      $result.execution = execution;
    }
    return $result;
  }
  GetBudgetExecutionResponse._() : super();
  factory GetBudgetExecutionResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetBudgetExecutionResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetBudgetExecutionResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.budget.v1'), createEmptyInstance: create)
    ..aOM<BudgetExecution>(1, _omitFieldNames ? '' : 'execution', subBuilder: BudgetExecution.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetBudgetExecutionResponse clone() => GetBudgetExecutionResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetBudgetExecutionResponse copyWith(void Function(GetBudgetExecutionResponse) updates) => super.copyWith((message) => updates(message as GetBudgetExecutionResponse)) as GetBudgetExecutionResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetBudgetExecutionResponse create() => GetBudgetExecutionResponse._();
  GetBudgetExecutionResponse createEmptyInstance() => create();
  static $pb.PbList<GetBudgetExecutionResponse> createRepeated() => $pb.PbList<GetBudgetExecutionResponse>();
  @$core.pragma('dart2js:noInline')
  static GetBudgetExecutionResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetBudgetExecutionResponse>(create);
  static GetBudgetExecutionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  BudgetExecution get execution => $_getN(0);
  @$pb.TagNumber(1)
  set execution(BudgetExecution v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasExecution() => $_has(0);
  @$pb.TagNumber(1)
  void clearExecution() => clearField(1);
  @$pb.TagNumber(1)
  BudgetExecution ensureExecution() => $_ensure(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
