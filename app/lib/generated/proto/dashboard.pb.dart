//
//  Generated code. Do not modify.
//  source: dashboard.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

class GetNetWorthRequest extends $pb.GeneratedMessage {
  factory GetNetWorthRequest({
    $core.String? familyId,
  }) {
    final $result = create();
    if (familyId != null) {
      $result.familyId = familyId;
    }
    return $result;
  }
  GetNetWorthRequest._() : super();
  factory GetNetWorthRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetNetWorthRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetNetWorthRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.dashboard.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetNetWorthRequest clone() => GetNetWorthRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetNetWorthRequest copyWith(void Function(GetNetWorthRequest) updates) => super.copyWith((message) => updates(message as GetNetWorthRequest)) as GetNetWorthRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetNetWorthRequest create() => GetNetWorthRequest._();
  GetNetWorthRequest createEmptyInstance() => create();
  static $pb.PbList<GetNetWorthRequest> createRepeated() => $pb.PbList<GetNetWorthRequest>();
  @$core.pragma('dart2js:noInline')
  static GetNetWorthRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetNetWorthRequest>(create);
  static GetNetWorthRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get familyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set familyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamilyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamilyId() => clearField(1);
}

class NetWorth extends $pb.GeneratedMessage {
  factory NetWorth({
    $fixnum.Int64? total,
    $fixnum.Int64? cashAndBank,
    $fixnum.Int64? investmentValue,
    $fixnum.Int64? fixedAssetValue,
    $fixnum.Int64? loanBalance,
    $fixnum.Int64? changeFromLastMonth,
    $core.double? changePercent,
    $core.Iterable<AssetComposition>? composition,
  }) {
    final $result = create();
    if (total != null) {
      $result.total = total;
    }
    if (cashAndBank != null) {
      $result.cashAndBank = cashAndBank;
    }
    if (investmentValue != null) {
      $result.investmentValue = investmentValue;
    }
    if (fixedAssetValue != null) {
      $result.fixedAssetValue = fixedAssetValue;
    }
    if (loanBalance != null) {
      $result.loanBalance = loanBalance;
    }
    if (changeFromLastMonth != null) {
      $result.changeFromLastMonth = changeFromLastMonth;
    }
    if (changePercent != null) {
      $result.changePercent = changePercent;
    }
    if (composition != null) {
      $result.composition.addAll(composition);
    }
    return $result;
  }
  NetWorth._() : super();
  factory NetWorth.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory NetWorth.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'NetWorth', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.dashboard.v1'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'total')
    ..aInt64(2, _omitFieldNames ? '' : 'cashAndBank')
    ..aInt64(3, _omitFieldNames ? '' : 'investmentValue')
    ..aInt64(4, _omitFieldNames ? '' : 'fixedAssetValue')
    ..aInt64(5, _omitFieldNames ? '' : 'loanBalance')
    ..aInt64(6, _omitFieldNames ? '' : 'changeFromLastMonth')
    ..a<$core.double>(7, _omitFieldNames ? '' : 'changePercent', $pb.PbFieldType.OD)
    ..pc<AssetComposition>(8, _omitFieldNames ? '' : 'composition', $pb.PbFieldType.PM, subBuilder: AssetComposition.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  NetWorth clone() => NetWorth()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  NetWorth copyWith(void Function(NetWorth) updates) => super.copyWith((message) => updates(message as NetWorth)) as NetWorth;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NetWorth create() => NetWorth._();
  NetWorth createEmptyInstance() => create();
  static $pb.PbList<NetWorth> createRepeated() => $pb.PbList<NetWorth>();
  @$core.pragma('dart2js:noInline')
  static NetWorth getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NetWorth>(create);
  static NetWorth? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get total => $_getI64(0);
  @$pb.TagNumber(1)
  set total($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTotal() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotal() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get cashAndBank => $_getI64(1);
  @$pb.TagNumber(2)
  set cashAndBank($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCashAndBank() => $_has(1);
  @$pb.TagNumber(2)
  void clearCashAndBank() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get investmentValue => $_getI64(2);
  @$pb.TagNumber(3)
  set investmentValue($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasInvestmentValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearInvestmentValue() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get fixedAssetValue => $_getI64(3);
  @$pb.TagNumber(4)
  set fixedAssetValue($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasFixedAssetValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearFixedAssetValue() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get loanBalance => $_getI64(4);
  @$pb.TagNumber(5)
  set loanBalance($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasLoanBalance() => $_has(4);
  @$pb.TagNumber(5)
  void clearLoanBalance() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get changeFromLastMonth => $_getI64(5);
  @$pb.TagNumber(6)
  set changeFromLastMonth($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasChangeFromLastMonth() => $_has(5);
  @$pb.TagNumber(6)
  void clearChangeFromLastMonth() => clearField(6);

  @$pb.TagNumber(7)
  $core.double get changePercent => $_getN(6);
  @$pb.TagNumber(7)
  set changePercent($core.double v) { $_setDouble(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasChangePercent() => $_has(6);
  @$pb.TagNumber(7)
  void clearChangePercent() => clearField(7);

  @$pb.TagNumber(8)
  $core.List<AssetComposition> get composition => $_getList(7);
}

class AssetComposition extends $pb.GeneratedMessage {
  factory AssetComposition({
    $core.String? category,
    $core.String? label,
    $fixnum.Int64? value,
    $core.double? weight,
  }) {
    final $result = create();
    if (category != null) {
      $result.category = category;
    }
    if (label != null) {
      $result.label = label;
    }
    if (value != null) {
      $result.value = value;
    }
    if (weight != null) {
      $result.weight = weight;
    }
    return $result;
  }
  AssetComposition._() : super();
  factory AssetComposition.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AssetComposition.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AssetComposition', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.dashboard.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'category')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aInt64(3, _omitFieldNames ? '' : 'value')
    ..a<$core.double>(4, _omitFieldNames ? '' : 'weight', $pb.PbFieldType.OD)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AssetComposition clone() => AssetComposition()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AssetComposition copyWith(void Function(AssetComposition) updates) => super.copyWith((message) => updates(message as AssetComposition)) as AssetComposition;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssetComposition create() => AssetComposition._();
  AssetComposition createEmptyInstance() => create();
  static $pb.PbList<AssetComposition> createRepeated() => $pb.PbList<AssetComposition>();
  @$core.pragma('dart2js:noInline')
  static AssetComposition getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AssetComposition>(create);
  static AssetComposition? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get category => $_getSZ(0);
  @$pb.TagNumber(1)
  set category($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCategory() => $_has(0);
  @$pb.TagNumber(1)
  void clearCategory() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get value => $_getI64(2);
  @$pb.TagNumber(3)
  set value($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearValue() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get weight => $_getN(3);
  @$pb.TagNumber(4)
  set weight($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasWeight() => $_has(3);
  @$pb.TagNumber(4)
  void clearWeight() => clearField(4);
}

class TrendRequest extends $pb.GeneratedMessage {
  factory TrendRequest({
    $core.String? userId,
    $core.String? familyId,
    $core.String? period,
    $core.int? count,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (familyId != null) {
      $result.familyId = familyId;
    }
    if (period != null) {
      $result.period = period;
    }
    if (count != null) {
      $result.count = count;
    }
    return $result;
  }
  TrendRequest._() : super();
  factory TrendRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TrendRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TrendRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.dashboard.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'familyId')
    ..aOS(3, _omitFieldNames ? '' : 'period')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'count', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TrendRequest clone() => TrendRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TrendRequest copyWith(void Function(TrendRequest) updates) => super.copyWith((message) => updates(message as TrendRequest)) as TrendRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrendRequest create() => TrendRequest._();
  TrendRequest createEmptyInstance() => create();
  static $pb.PbList<TrendRequest> createRepeated() => $pb.PbList<TrendRequest>();
  @$core.pragma('dart2js:noInline')
  static TrendRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TrendRequest>(create);
  static TrendRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get familyId => $_getSZ(1);
  @$pb.TagNumber(2)
  set familyId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasFamilyId() => $_has(1);
  @$pb.TagNumber(2)
  void clearFamilyId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get period => $_getSZ(2);
  @$pb.TagNumber(3)
  set period($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPeriod() => $_has(2);
  @$pb.TagNumber(3)
  void clearPeriod() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get count => $_getIZ(3);
  @$pb.TagNumber(4)
  set count($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearCount() => clearField(4);
}

class TrendResponse extends $pb.GeneratedMessage {
  factory TrendResponse({
    $core.Iterable<TrendPoint>? points,
  }) {
    final $result = create();
    if (points != null) {
      $result.points.addAll(points);
    }
    return $result;
  }
  TrendResponse._() : super();
  factory TrendResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TrendResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TrendResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.dashboard.v1'), createEmptyInstance: create)
    ..pc<TrendPoint>(1, _omitFieldNames ? '' : 'points', $pb.PbFieldType.PM, subBuilder: TrendPoint.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TrendResponse clone() => TrendResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TrendResponse copyWith(void Function(TrendResponse) updates) => super.copyWith((message) => updates(message as TrendResponse)) as TrendResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrendResponse create() => TrendResponse._();
  TrendResponse createEmptyInstance() => create();
  static $pb.PbList<TrendResponse> createRepeated() => $pb.PbList<TrendResponse>();
  @$core.pragma('dart2js:noInline')
  static TrendResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TrendResponse>(create);
  static TrendResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<TrendPoint> get points => $_getList(0);
}

class TrendPoint extends $pb.GeneratedMessage {
  factory TrendPoint({
    $core.String? label,
    $fixnum.Int64? income,
    $fixnum.Int64? expense,
    $fixnum.Int64? net,
  }) {
    final $result = create();
    if (label != null) {
      $result.label = label;
    }
    if (income != null) {
      $result.income = income;
    }
    if (expense != null) {
      $result.expense = expense;
    }
    if (net != null) {
      $result.net = net;
    }
    return $result;
  }
  TrendPoint._() : super();
  factory TrendPoint.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TrendPoint.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TrendPoint', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.dashboard.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aInt64(2, _omitFieldNames ? '' : 'income')
    ..aInt64(3, _omitFieldNames ? '' : 'expense')
    ..aInt64(4, _omitFieldNames ? '' : 'net')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TrendPoint clone() => TrendPoint()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TrendPoint copyWith(void Function(TrendPoint) updates) => super.copyWith((message) => updates(message as TrendPoint)) as TrendPoint;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrendPoint create() => TrendPoint._();
  TrendPoint createEmptyInstance() => create();
  static $pb.PbList<TrendPoint> createRepeated() => $pb.PbList<TrendPoint>();
  @$core.pragma('dart2js:noInline')
  static TrendPoint getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TrendPoint>(create);
  static TrendPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get income => $_getI64(1);
  @$pb.TagNumber(2)
  set income($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasIncome() => $_has(1);
  @$pb.TagNumber(2)
  void clearIncome() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get expense => $_getI64(2);
  @$pb.TagNumber(3)
  set expense($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasExpense() => $_has(2);
  @$pb.TagNumber(3)
  void clearExpense() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get net => $_getI64(3);
  @$pb.TagNumber(4)
  set net($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasNet() => $_has(3);
  @$pb.TagNumber(4)
  void clearNet() => clearField(4);
}

class CategoryBreakdownRequest extends $pb.GeneratedMessage {
  factory CategoryBreakdownRequest({
    $core.String? userId,
    $core.String? familyId,
    $core.int? year,
    $core.int? month,
    $core.String? type,
  }) {
    final $result = create();
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
    if (type != null) {
      $result.type = type;
    }
    return $result;
  }
  CategoryBreakdownRequest._() : super();
  factory CategoryBreakdownRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CategoryBreakdownRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CategoryBreakdownRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.dashboard.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'familyId')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'year', $pb.PbFieldType.O3)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'month', $pb.PbFieldType.O3)
    ..aOS(5, _omitFieldNames ? '' : 'type')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CategoryBreakdownRequest clone() => CategoryBreakdownRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CategoryBreakdownRequest copyWith(void Function(CategoryBreakdownRequest) updates) => super.copyWith((message) => updates(message as CategoryBreakdownRequest)) as CategoryBreakdownRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CategoryBreakdownRequest create() => CategoryBreakdownRequest._();
  CategoryBreakdownRequest createEmptyInstance() => create();
  static $pb.PbList<CategoryBreakdownRequest> createRepeated() => $pb.PbList<CategoryBreakdownRequest>();
  @$core.pragma('dart2js:noInline')
  static CategoryBreakdownRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CategoryBreakdownRequest>(create);
  static CategoryBreakdownRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get familyId => $_getSZ(1);
  @$pb.TagNumber(2)
  set familyId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasFamilyId() => $_has(1);
  @$pb.TagNumber(2)
  void clearFamilyId() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get year => $_getIZ(2);
  @$pb.TagNumber(3)
  set year($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasYear() => $_has(2);
  @$pb.TagNumber(3)
  void clearYear() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get month => $_getIZ(3);
  @$pb.TagNumber(4)
  set month($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasMonth() => $_has(3);
  @$pb.TagNumber(4)
  void clearMonth() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get type => $_getSZ(4);
  @$pb.TagNumber(5)
  set type($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasType() => $_has(4);
  @$pb.TagNumber(5)
  void clearType() => clearField(5);
}

class CategoryBreakdownResponse extends $pb.GeneratedMessage {
  factory CategoryBreakdownResponse({
    $fixnum.Int64? total,
    $core.Iterable<CategoryItem>? items,
  }) {
    final $result = create();
    if (total != null) {
      $result.total = total;
    }
    if (items != null) {
      $result.items.addAll(items);
    }
    return $result;
  }
  CategoryBreakdownResponse._() : super();
  factory CategoryBreakdownResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CategoryBreakdownResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CategoryBreakdownResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.dashboard.v1'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'total')
    ..pc<CategoryItem>(2, _omitFieldNames ? '' : 'items', $pb.PbFieldType.PM, subBuilder: CategoryItem.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CategoryBreakdownResponse clone() => CategoryBreakdownResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CategoryBreakdownResponse copyWith(void Function(CategoryBreakdownResponse) updates) => super.copyWith((message) => updates(message as CategoryBreakdownResponse)) as CategoryBreakdownResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CategoryBreakdownResponse create() => CategoryBreakdownResponse._();
  CategoryBreakdownResponse createEmptyInstance() => create();
  static $pb.PbList<CategoryBreakdownResponse> createRepeated() => $pb.PbList<CategoryBreakdownResponse>();
  @$core.pragma('dart2js:noInline')
  static CategoryBreakdownResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CategoryBreakdownResponse>(create);
  static CategoryBreakdownResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get total => $_getI64(0);
  @$pb.TagNumber(1)
  set total($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTotal() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotal() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<CategoryItem> get items => $_getList(1);
}

class CategoryItem extends $pb.GeneratedMessage {
  factory CategoryItem({
    $core.String? categoryId,
    $core.String? categoryName,
    $core.String? icon,
    $fixnum.Int64? amount,
    $core.double? weight,
  }) {
    final $result = create();
    if (categoryId != null) {
      $result.categoryId = categoryId;
    }
    if (categoryName != null) {
      $result.categoryName = categoryName;
    }
    if (icon != null) {
      $result.icon = icon;
    }
    if (amount != null) {
      $result.amount = amount;
    }
    if (weight != null) {
      $result.weight = weight;
    }
    return $result;
  }
  CategoryItem._() : super();
  factory CategoryItem.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CategoryItem.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CategoryItem', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.dashboard.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'categoryId')
    ..aOS(2, _omitFieldNames ? '' : 'categoryName')
    ..aOS(3, _omitFieldNames ? '' : 'icon')
    ..aInt64(4, _omitFieldNames ? '' : 'amount')
    ..a<$core.double>(5, _omitFieldNames ? '' : 'weight', $pb.PbFieldType.OD)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CategoryItem clone() => CategoryItem()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CategoryItem copyWith(void Function(CategoryItem) updates) => super.copyWith((message) => updates(message as CategoryItem)) as CategoryItem;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CategoryItem create() => CategoryItem._();
  CategoryItem createEmptyInstance() => create();
  static $pb.PbList<CategoryItem> createRepeated() => $pb.PbList<CategoryItem>();
  @$core.pragma('dart2js:noInline')
  static CategoryItem getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CategoryItem>(create);
  static CategoryItem? _defaultInstance;

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
  $core.String get icon => $_getSZ(2);
  @$pb.TagNumber(3)
  set icon($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get amount => $_getI64(3);
  @$pb.TagNumber(4)
  set amount($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAmount() => $_has(3);
  @$pb.TagNumber(4)
  void clearAmount() => clearField(4);

  @$pb.TagNumber(5)
  $core.double get weight => $_getN(4);
  @$pb.TagNumber(5)
  set weight($core.double v) { $_setDouble(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasWeight() => $_has(4);
  @$pb.TagNumber(5)
  void clearWeight() => clearField(5);
}

class BudgetSummaryRequest extends $pb.GeneratedMessage {
  factory BudgetSummaryRequest({
    $core.String? familyId,
    $core.int? year,
    $core.int? month,
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
    return $result;
  }
  BudgetSummaryRequest._() : super();
  factory BudgetSummaryRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BudgetSummaryRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BudgetSummaryRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.dashboard.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'year', $pb.PbFieldType.O3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'month', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BudgetSummaryRequest clone() => BudgetSummaryRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BudgetSummaryRequest copyWith(void Function(BudgetSummaryRequest) updates) => super.copyWith((message) => updates(message as BudgetSummaryRequest)) as BudgetSummaryRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BudgetSummaryRequest create() => BudgetSummaryRequest._();
  BudgetSummaryRequest createEmptyInstance() => create();
  static $pb.PbList<BudgetSummaryRequest> createRepeated() => $pb.PbList<BudgetSummaryRequest>();
  @$core.pragma('dart2js:noInline')
  static BudgetSummaryRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BudgetSummaryRequest>(create);
  static BudgetSummaryRequest? _defaultInstance;

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
}

class BudgetSummaryResponse extends $pb.GeneratedMessage {
  factory BudgetSummaryResponse({
    $fixnum.Int64? totalBudget,
    $fixnum.Int64? totalSpent,
    $core.double? executionRate,
    $core.Iterable<CategoryBudgetItem>? categories,
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
    if (categories != null) {
      $result.categories.addAll(categories);
    }
    return $result;
  }
  BudgetSummaryResponse._() : super();
  factory BudgetSummaryResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BudgetSummaryResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BudgetSummaryResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.dashboard.v1'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'totalBudget')
    ..aInt64(2, _omitFieldNames ? '' : 'totalSpent')
    ..a<$core.double>(3, _omitFieldNames ? '' : 'executionRate', $pb.PbFieldType.OD)
    ..pc<CategoryBudgetItem>(4, _omitFieldNames ? '' : 'categories', $pb.PbFieldType.PM, subBuilder: CategoryBudgetItem.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BudgetSummaryResponse clone() => BudgetSummaryResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BudgetSummaryResponse copyWith(void Function(BudgetSummaryResponse) updates) => super.copyWith((message) => updates(message as BudgetSummaryResponse)) as BudgetSummaryResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BudgetSummaryResponse create() => BudgetSummaryResponse._();
  BudgetSummaryResponse createEmptyInstance() => create();
  static $pb.PbList<BudgetSummaryResponse> createRepeated() => $pb.PbList<BudgetSummaryResponse>();
  @$core.pragma('dart2js:noInline')
  static BudgetSummaryResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BudgetSummaryResponse>(create);
  static BudgetSummaryResponse? _defaultInstance;

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
  $core.List<CategoryBudgetItem> get categories => $_getList(3);
}

class CategoryBudgetItem extends $pb.GeneratedMessage {
  factory CategoryBudgetItem({
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
  CategoryBudgetItem._() : super();
  factory CategoryBudgetItem.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CategoryBudgetItem.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CategoryBudgetItem', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.dashboard.v1'), createEmptyInstance: create)
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
  CategoryBudgetItem clone() => CategoryBudgetItem()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CategoryBudgetItem copyWith(void Function(CategoryBudgetItem) updates) => super.copyWith((message) => updates(message as CategoryBudgetItem)) as CategoryBudgetItem;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CategoryBudgetItem create() => CategoryBudgetItem._();
  CategoryBudgetItem createEmptyInstance() => create();
  static $pb.PbList<CategoryBudgetItem> createRepeated() => $pb.PbList<CategoryBudgetItem>();
  @$core.pragma('dart2js:noInline')
  static CategoryBudgetItem getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CategoryBudgetItem>(create);
  static CategoryBudgetItem? _defaultInstance;

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


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
