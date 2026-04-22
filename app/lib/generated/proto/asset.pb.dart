//
//  Generated code. Do not modify.
//  source: asset.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'asset.pbenum.dart';
import 'google/protobuf/timestamp.pb.dart' as $2;

export 'asset.pbenum.dart';

class Asset extends $pb.GeneratedMessage {
  factory Asset({
    $core.String? id,
    $core.String? userId,
    $core.String? name,
    AssetType? assetType,
    $fixnum.Int64? purchasePrice,
    $fixnum.Int64? currentValue,
    $2.Timestamp? purchaseDate,
    $core.String? description,
    $2.Timestamp? createdAt,
    $2.Timestamp? updatedAt,
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
    if (assetType != null) {
      $result.assetType = assetType;
    }
    if (purchasePrice != null) {
      $result.purchasePrice = purchasePrice;
    }
    if (currentValue != null) {
      $result.currentValue = currentValue;
    }
    if (purchaseDate != null) {
      $result.purchaseDate = purchaseDate;
    }
    if (description != null) {
      $result.description = description;
    }
    if (createdAt != null) {
      $result.createdAt = createdAt;
    }
    if (updatedAt != null) {
      $result.updatedAt = updatedAt;
    }
    return $result;
  }
  Asset._() : super();
  factory Asset.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Asset.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Asset', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.asset.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..e<AssetType>(4, _omitFieldNames ? '' : 'assetType', $pb.PbFieldType.OE, defaultOrMaker: AssetType.ASSET_TYPE_UNSPECIFIED, valueOf: AssetType.valueOf, enumValues: AssetType.values)
    ..aInt64(5, _omitFieldNames ? '' : 'purchasePrice')
    ..aInt64(6, _omitFieldNames ? '' : 'currentValue')
    ..aOM<$2.Timestamp>(7, _omitFieldNames ? '' : 'purchaseDate', subBuilder: $2.Timestamp.create)
    ..aOS(8, _omitFieldNames ? '' : 'description')
    ..aOM<$2.Timestamp>(9, _omitFieldNames ? '' : 'createdAt', subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(10, _omitFieldNames ? '' : 'updatedAt', subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Asset clone() => Asset()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Asset copyWith(void Function(Asset) updates) => super.copyWith((message) => updates(message as Asset)) as Asset;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Asset create() => Asset._();
  Asset createEmptyInstance() => create();
  static $pb.PbList<Asset> createRepeated() => $pb.PbList<Asset>();
  @$core.pragma('dart2js:noInline')
  static Asset getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Asset>(create);
  static Asset? _defaultInstance;

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
  AssetType get assetType => $_getN(3);
  @$pb.TagNumber(4)
  set assetType(AssetType v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasAssetType() => $_has(3);
  @$pb.TagNumber(4)
  void clearAssetType() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get purchasePrice => $_getI64(4);
  @$pb.TagNumber(5)
  set purchasePrice($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasPurchasePrice() => $_has(4);
  @$pb.TagNumber(5)
  void clearPurchasePrice() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get currentValue => $_getI64(5);
  @$pb.TagNumber(6)
  set currentValue($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasCurrentValue() => $_has(5);
  @$pb.TagNumber(6)
  void clearCurrentValue() => clearField(6);

  @$pb.TagNumber(7)
  $2.Timestamp get purchaseDate => $_getN(6);
  @$pb.TagNumber(7)
  set purchaseDate($2.Timestamp v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasPurchaseDate() => $_has(6);
  @$pb.TagNumber(7)
  void clearPurchaseDate() => clearField(7);
  @$pb.TagNumber(7)
  $2.Timestamp ensurePurchaseDate() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.String get description => $_getSZ(7);
  @$pb.TagNumber(8)
  set description($core.String v) { $_setString(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasDescription() => $_has(7);
  @$pb.TagNumber(8)
  void clearDescription() => clearField(8);

  @$pb.TagNumber(9)
  $2.Timestamp get createdAt => $_getN(8);
  @$pb.TagNumber(9)
  set createdAt($2.Timestamp v) { setField(9, v); }
  @$pb.TagNumber(9)
  $core.bool hasCreatedAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearCreatedAt() => clearField(9);
  @$pb.TagNumber(9)
  $2.Timestamp ensureCreatedAt() => $_ensure(8);

  @$pb.TagNumber(10)
  $2.Timestamp get updatedAt => $_getN(9);
  @$pb.TagNumber(10)
  set updatedAt($2.Timestamp v) { setField(10, v); }
  @$pb.TagNumber(10)
  $core.bool hasUpdatedAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearUpdatedAt() => clearField(10);
  @$pb.TagNumber(10)
  $2.Timestamp ensureUpdatedAt() => $_ensure(9);
}

class AssetValuation extends $pb.GeneratedMessage {
  factory AssetValuation({
    $core.String? id,
    $core.String? assetId,
    $fixnum.Int64? value,
    $core.String? source,
    $2.Timestamp? valuationDate,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (assetId != null) {
      $result.assetId = assetId;
    }
    if (value != null) {
      $result.value = value;
    }
    if (source != null) {
      $result.source = source;
    }
    if (valuationDate != null) {
      $result.valuationDate = valuationDate;
    }
    return $result;
  }
  AssetValuation._() : super();
  factory AssetValuation.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AssetValuation.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AssetValuation', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.asset.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'assetId')
    ..aInt64(3, _omitFieldNames ? '' : 'value')
    ..aOS(4, _omitFieldNames ? '' : 'source')
    ..aOM<$2.Timestamp>(5, _omitFieldNames ? '' : 'valuationDate', subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AssetValuation clone() => AssetValuation()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AssetValuation copyWith(void Function(AssetValuation) updates) => super.copyWith((message) => updates(message as AssetValuation)) as AssetValuation;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssetValuation create() => AssetValuation._();
  AssetValuation createEmptyInstance() => create();
  static $pb.PbList<AssetValuation> createRepeated() => $pb.PbList<AssetValuation>();
  @$core.pragma('dart2js:noInline')
  static AssetValuation getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AssetValuation>(create);
  static AssetValuation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get assetId => $_getSZ(1);
  @$pb.TagNumber(2)
  set assetId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAssetId() => $_has(1);
  @$pb.TagNumber(2)
  void clearAssetId() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get value => $_getI64(2);
  @$pb.TagNumber(3)
  set value($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearValue() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get source => $_getSZ(3);
  @$pb.TagNumber(4)
  set source($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSource() => $_has(3);
  @$pb.TagNumber(4)
  void clearSource() => clearField(4);

  @$pb.TagNumber(5)
  $2.Timestamp get valuationDate => $_getN(4);
  @$pb.TagNumber(5)
  set valuationDate($2.Timestamp v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasValuationDate() => $_has(4);
  @$pb.TagNumber(5)
  void clearValuationDate() => clearField(5);
  @$pb.TagNumber(5)
  $2.Timestamp ensureValuationDate() => $_ensure(4);
}

class DepreciationRule extends $pb.GeneratedMessage {
  factory DepreciationRule({
    $core.String? id,
    $core.String? assetId,
    DepreciationMethod? method,
    $core.int? usefulLifeYears,
    $core.double? salvageRate,
    $2.Timestamp? createdAt,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (assetId != null) {
      $result.assetId = assetId;
    }
    if (method != null) {
      $result.method = method;
    }
    if (usefulLifeYears != null) {
      $result.usefulLifeYears = usefulLifeYears;
    }
    if (salvageRate != null) {
      $result.salvageRate = salvageRate;
    }
    if (createdAt != null) {
      $result.createdAt = createdAt;
    }
    return $result;
  }
  DepreciationRule._() : super();
  factory DepreciationRule.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DepreciationRule.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DepreciationRule', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.asset.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'assetId')
    ..e<DepreciationMethod>(3, _omitFieldNames ? '' : 'method', $pb.PbFieldType.OE, defaultOrMaker: DepreciationMethod.DEPRECIATION_METHOD_UNSPECIFIED, valueOf: DepreciationMethod.valueOf, enumValues: DepreciationMethod.values)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'usefulLifeYears', $pb.PbFieldType.O3)
    ..a<$core.double>(5, _omitFieldNames ? '' : 'salvageRate', $pb.PbFieldType.OD)
    ..aOM<$2.Timestamp>(6, _omitFieldNames ? '' : 'createdAt', subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DepreciationRule clone() => DepreciationRule()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DepreciationRule copyWith(void Function(DepreciationRule) updates) => super.copyWith((message) => updates(message as DepreciationRule)) as DepreciationRule;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DepreciationRule create() => DepreciationRule._();
  DepreciationRule createEmptyInstance() => create();
  static $pb.PbList<DepreciationRule> createRepeated() => $pb.PbList<DepreciationRule>();
  @$core.pragma('dart2js:noInline')
  static DepreciationRule getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DepreciationRule>(create);
  static DepreciationRule? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get assetId => $_getSZ(1);
  @$pb.TagNumber(2)
  set assetId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAssetId() => $_has(1);
  @$pb.TagNumber(2)
  void clearAssetId() => clearField(2);

  @$pb.TagNumber(3)
  DepreciationMethod get method => $_getN(2);
  @$pb.TagNumber(3)
  set method(DepreciationMethod v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasMethod() => $_has(2);
  @$pb.TagNumber(3)
  void clearMethod() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get usefulLifeYears => $_getIZ(3);
  @$pb.TagNumber(4)
  set usefulLifeYears($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasUsefulLifeYears() => $_has(3);
  @$pb.TagNumber(4)
  void clearUsefulLifeYears() => clearField(4);

  @$pb.TagNumber(5)
  $core.double get salvageRate => $_getN(4);
  @$pb.TagNumber(5)
  set salvageRate($core.double v) { $_setDouble(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasSalvageRate() => $_has(4);
  @$pb.TagNumber(5)
  void clearSalvageRate() => clearField(5);

  @$pb.TagNumber(6)
  $2.Timestamp get createdAt => $_getN(5);
  @$pb.TagNumber(6)
  set createdAt($2.Timestamp v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasCreatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAt() => clearField(6);
  @$pb.TagNumber(6)
  $2.Timestamp ensureCreatedAt() => $_ensure(5);
}

class CreateAssetRequest extends $pb.GeneratedMessage {
  factory CreateAssetRequest({
    $core.String? name,
    AssetType? assetType,
    $fixnum.Int64? purchasePrice,
    $2.Timestamp? purchaseDate,
    $core.String? description,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (assetType != null) {
      $result.assetType = assetType;
    }
    if (purchasePrice != null) {
      $result.purchasePrice = purchasePrice;
    }
    if (purchaseDate != null) {
      $result.purchaseDate = purchaseDate;
    }
    if (description != null) {
      $result.description = description;
    }
    return $result;
  }
  CreateAssetRequest._() : super();
  factory CreateAssetRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CreateAssetRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CreateAssetRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.asset.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..e<AssetType>(2, _omitFieldNames ? '' : 'assetType', $pb.PbFieldType.OE, defaultOrMaker: AssetType.ASSET_TYPE_UNSPECIFIED, valueOf: AssetType.valueOf, enumValues: AssetType.values)
    ..aInt64(3, _omitFieldNames ? '' : 'purchasePrice')
    ..aOM<$2.Timestamp>(4, _omitFieldNames ? '' : 'purchaseDate', subBuilder: $2.Timestamp.create)
    ..aOS(5, _omitFieldNames ? '' : 'description')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CreateAssetRequest clone() => CreateAssetRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CreateAssetRequest copyWith(void Function(CreateAssetRequest) updates) => super.copyWith((message) => updates(message as CreateAssetRequest)) as CreateAssetRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateAssetRequest create() => CreateAssetRequest._();
  CreateAssetRequest createEmptyInstance() => create();
  static $pb.PbList<CreateAssetRequest> createRepeated() => $pb.PbList<CreateAssetRequest>();
  @$core.pragma('dart2js:noInline')
  static CreateAssetRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CreateAssetRequest>(create);
  static CreateAssetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  AssetType get assetType => $_getN(1);
  @$pb.TagNumber(2)
  set assetType(AssetType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasAssetType() => $_has(1);
  @$pb.TagNumber(2)
  void clearAssetType() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get purchasePrice => $_getI64(2);
  @$pb.TagNumber(3)
  set purchasePrice($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPurchasePrice() => $_has(2);
  @$pb.TagNumber(3)
  void clearPurchasePrice() => clearField(3);

  @$pb.TagNumber(4)
  $2.Timestamp get purchaseDate => $_getN(3);
  @$pb.TagNumber(4)
  set purchaseDate($2.Timestamp v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasPurchaseDate() => $_has(3);
  @$pb.TagNumber(4)
  void clearPurchaseDate() => clearField(4);
  @$pb.TagNumber(4)
  $2.Timestamp ensurePurchaseDate() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.String get description => $_getSZ(4);
  @$pb.TagNumber(5)
  set description($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasDescription() => $_has(4);
  @$pb.TagNumber(5)
  void clearDescription() => clearField(5);
}

class GetAssetRequest extends $pb.GeneratedMessage {
  factory GetAssetRequest({
    $core.String? assetId,
  }) {
    final $result = create();
    if (assetId != null) {
      $result.assetId = assetId;
    }
    return $result;
  }
  GetAssetRequest._() : super();
  factory GetAssetRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetAssetRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetAssetRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.asset.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'assetId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetAssetRequest clone() => GetAssetRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetAssetRequest copyWith(void Function(GetAssetRequest) updates) => super.copyWith((message) => updates(message as GetAssetRequest)) as GetAssetRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetAssetRequest create() => GetAssetRequest._();
  GetAssetRequest createEmptyInstance() => create();
  static $pb.PbList<GetAssetRequest> createRepeated() => $pb.PbList<GetAssetRequest>();
  @$core.pragma('dart2js:noInline')
  static GetAssetRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetAssetRequest>(create);
  static GetAssetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get assetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set assetId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAssetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAssetId() => clearField(1);
}

class ListAssetsRequest extends $pb.GeneratedMessage {
  factory ListAssetsRequest({
    AssetType? assetType,
  }) {
    final $result = create();
    if (assetType != null) {
      $result.assetType = assetType;
    }
    return $result;
  }
  ListAssetsRequest._() : super();
  factory ListAssetsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListAssetsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListAssetsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.asset.v1'), createEmptyInstance: create)
    ..e<AssetType>(1, _omitFieldNames ? '' : 'assetType', $pb.PbFieldType.OE, defaultOrMaker: AssetType.ASSET_TYPE_UNSPECIFIED, valueOf: AssetType.valueOf, enumValues: AssetType.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListAssetsRequest clone() => ListAssetsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListAssetsRequest copyWith(void Function(ListAssetsRequest) updates) => super.copyWith((message) => updates(message as ListAssetsRequest)) as ListAssetsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListAssetsRequest create() => ListAssetsRequest._();
  ListAssetsRequest createEmptyInstance() => create();
  static $pb.PbList<ListAssetsRequest> createRepeated() => $pb.PbList<ListAssetsRequest>();
  @$core.pragma('dart2js:noInline')
  static ListAssetsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListAssetsRequest>(create);
  static ListAssetsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  AssetType get assetType => $_getN(0);
  @$pb.TagNumber(1)
  set assetType(AssetType v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasAssetType() => $_has(0);
  @$pb.TagNumber(1)
  void clearAssetType() => clearField(1);
}

class ListAssetsResponse extends $pb.GeneratedMessage {
  factory ListAssetsResponse({
    $core.Iterable<Asset>? assets,
  }) {
    final $result = create();
    if (assets != null) {
      $result.assets.addAll(assets);
    }
    return $result;
  }
  ListAssetsResponse._() : super();
  factory ListAssetsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListAssetsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListAssetsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.asset.v1'), createEmptyInstance: create)
    ..pc<Asset>(1, _omitFieldNames ? '' : 'assets', $pb.PbFieldType.PM, subBuilder: Asset.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListAssetsResponse clone() => ListAssetsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListAssetsResponse copyWith(void Function(ListAssetsResponse) updates) => super.copyWith((message) => updates(message as ListAssetsResponse)) as ListAssetsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListAssetsResponse create() => ListAssetsResponse._();
  ListAssetsResponse createEmptyInstance() => create();
  static $pb.PbList<ListAssetsResponse> createRepeated() => $pb.PbList<ListAssetsResponse>();
  @$core.pragma('dart2js:noInline')
  static ListAssetsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListAssetsResponse>(create);
  static ListAssetsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<Asset> get assets => $_getList(0);
}

class UpdateAssetRequest extends $pb.GeneratedMessage {
  factory UpdateAssetRequest({
    $core.String? assetId,
    $core.String? name,
    $core.String? description,
  }) {
    final $result = create();
    if (assetId != null) {
      $result.assetId = assetId;
    }
    if (name != null) {
      $result.name = name;
    }
    if (description != null) {
      $result.description = description;
    }
    return $result;
  }
  UpdateAssetRequest._() : super();
  factory UpdateAssetRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdateAssetRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UpdateAssetRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.asset.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'assetId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdateAssetRequest clone() => UpdateAssetRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdateAssetRequest copyWith(void Function(UpdateAssetRequest) updates) => super.copyWith((message) => updates(message as UpdateAssetRequest)) as UpdateAssetRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateAssetRequest create() => UpdateAssetRequest._();
  UpdateAssetRequest createEmptyInstance() => create();
  static $pb.PbList<UpdateAssetRequest> createRepeated() => $pb.PbList<UpdateAssetRequest>();
  @$core.pragma('dart2js:noInline')
  static UpdateAssetRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateAssetRequest>(create);
  static UpdateAssetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get assetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set assetId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAssetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAssetId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => clearField(3);
}

class DeleteAssetRequest extends $pb.GeneratedMessage {
  factory DeleteAssetRequest({
    $core.String? assetId,
  }) {
    final $result = create();
    if (assetId != null) {
      $result.assetId = assetId;
    }
    return $result;
  }
  DeleteAssetRequest._() : super();
  factory DeleteAssetRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeleteAssetRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeleteAssetRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.asset.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'assetId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeleteAssetRequest clone() => DeleteAssetRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeleteAssetRequest copyWith(void Function(DeleteAssetRequest) updates) => super.copyWith((message) => updates(message as DeleteAssetRequest)) as DeleteAssetRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteAssetRequest create() => DeleteAssetRequest._();
  DeleteAssetRequest createEmptyInstance() => create();
  static $pb.PbList<DeleteAssetRequest> createRepeated() => $pb.PbList<DeleteAssetRequest>();
  @$core.pragma('dart2js:noInline')
  static DeleteAssetRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeleteAssetRequest>(create);
  static DeleteAssetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get assetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set assetId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAssetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAssetId() => clearField(1);
}

class UpdateValuationRequest extends $pb.GeneratedMessage {
  factory UpdateValuationRequest({
    $core.String? assetId,
    $fixnum.Int64? value,
    $core.String? source,
  }) {
    final $result = create();
    if (assetId != null) {
      $result.assetId = assetId;
    }
    if (value != null) {
      $result.value = value;
    }
    if (source != null) {
      $result.source = source;
    }
    return $result;
  }
  UpdateValuationRequest._() : super();
  factory UpdateValuationRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdateValuationRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UpdateValuationRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.asset.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'assetId')
    ..aInt64(2, _omitFieldNames ? '' : 'value')
    ..aOS(3, _omitFieldNames ? '' : 'source')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdateValuationRequest clone() => UpdateValuationRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdateValuationRequest copyWith(void Function(UpdateValuationRequest) updates) => super.copyWith((message) => updates(message as UpdateValuationRequest)) as UpdateValuationRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateValuationRequest create() => UpdateValuationRequest._();
  UpdateValuationRequest createEmptyInstance() => create();
  static $pb.PbList<UpdateValuationRequest> createRepeated() => $pb.PbList<UpdateValuationRequest>();
  @$core.pragma('dart2js:noInline')
  static UpdateValuationRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateValuationRequest>(create);
  static UpdateValuationRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get assetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set assetId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAssetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAssetId() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get value => $_getI64(1);
  @$pb.TagNumber(2)
  set value($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get source => $_getSZ(2);
  @$pb.TagNumber(3)
  set source($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSource() => $_has(2);
  @$pb.TagNumber(3)
  void clearSource() => clearField(3);
}

class ListValuationsRequest extends $pb.GeneratedMessage {
  factory ListValuationsRequest({
    $core.String? assetId,
  }) {
    final $result = create();
    if (assetId != null) {
      $result.assetId = assetId;
    }
    return $result;
  }
  ListValuationsRequest._() : super();
  factory ListValuationsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListValuationsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListValuationsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.asset.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'assetId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListValuationsRequest clone() => ListValuationsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListValuationsRequest copyWith(void Function(ListValuationsRequest) updates) => super.copyWith((message) => updates(message as ListValuationsRequest)) as ListValuationsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListValuationsRequest create() => ListValuationsRequest._();
  ListValuationsRequest createEmptyInstance() => create();
  static $pb.PbList<ListValuationsRequest> createRepeated() => $pb.PbList<ListValuationsRequest>();
  @$core.pragma('dart2js:noInline')
  static ListValuationsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListValuationsRequest>(create);
  static ListValuationsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get assetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set assetId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAssetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAssetId() => clearField(1);
}

class ListValuationsResponse extends $pb.GeneratedMessage {
  factory ListValuationsResponse({
    $core.Iterable<AssetValuation>? valuations,
  }) {
    final $result = create();
    if (valuations != null) {
      $result.valuations.addAll(valuations);
    }
    return $result;
  }
  ListValuationsResponse._() : super();
  factory ListValuationsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListValuationsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListValuationsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.asset.v1'), createEmptyInstance: create)
    ..pc<AssetValuation>(1, _omitFieldNames ? '' : 'valuations', $pb.PbFieldType.PM, subBuilder: AssetValuation.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListValuationsResponse clone() => ListValuationsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListValuationsResponse copyWith(void Function(ListValuationsResponse) updates) => super.copyWith((message) => updates(message as ListValuationsResponse)) as ListValuationsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListValuationsResponse create() => ListValuationsResponse._();
  ListValuationsResponse createEmptyInstance() => create();
  static $pb.PbList<ListValuationsResponse> createRepeated() => $pb.PbList<ListValuationsResponse>();
  @$core.pragma('dart2js:noInline')
  static ListValuationsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListValuationsResponse>(create);
  static ListValuationsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<AssetValuation> get valuations => $_getList(0);
}

class SetDepreciationRuleRequest extends $pb.GeneratedMessage {
  factory SetDepreciationRuleRequest({
    $core.String? assetId,
    DepreciationMethod? method,
    $core.int? usefulLifeYears,
    $core.double? salvageRate,
  }) {
    final $result = create();
    if (assetId != null) {
      $result.assetId = assetId;
    }
    if (method != null) {
      $result.method = method;
    }
    if (usefulLifeYears != null) {
      $result.usefulLifeYears = usefulLifeYears;
    }
    if (salvageRate != null) {
      $result.salvageRate = salvageRate;
    }
    return $result;
  }
  SetDepreciationRuleRequest._() : super();
  factory SetDepreciationRuleRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetDepreciationRuleRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetDepreciationRuleRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.asset.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'assetId')
    ..e<DepreciationMethod>(2, _omitFieldNames ? '' : 'method', $pb.PbFieldType.OE, defaultOrMaker: DepreciationMethod.DEPRECIATION_METHOD_UNSPECIFIED, valueOf: DepreciationMethod.valueOf, enumValues: DepreciationMethod.values)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'usefulLifeYears', $pb.PbFieldType.O3)
    ..a<$core.double>(4, _omitFieldNames ? '' : 'salvageRate', $pb.PbFieldType.OD)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetDepreciationRuleRequest clone() => SetDepreciationRuleRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetDepreciationRuleRequest copyWith(void Function(SetDepreciationRuleRequest) updates) => super.copyWith((message) => updates(message as SetDepreciationRuleRequest)) as SetDepreciationRuleRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetDepreciationRuleRequest create() => SetDepreciationRuleRequest._();
  SetDepreciationRuleRequest createEmptyInstance() => create();
  static $pb.PbList<SetDepreciationRuleRequest> createRepeated() => $pb.PbList<SetDepreciationRuleRequest>();
  @$core.pragma('dart2js:noInline')
  static SetDepreciationRuleRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetDepreciationRuleRequest>(create);
  static SetDepreciationRuleRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get assetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set assetId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAssetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAssetId() => clearField(1);

  @$pb.TagNumber(2)
  DepreciationMethod get method => $_getN(1);
  @$pb.TagNumber(2)
  set method(DepreciationMethod v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasMethod() => $_has(1);
  @$pb.TagNumber(2)
  void clearMethod() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get usefulLifeYears => $_getIZ(2);
  @$pb.TagNumber(3)
  set usefulLifeYears($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasUsefulLifeYears() => $_has(2);
  @$pb.TagNumber(3)
  void clearUsefulLifeYears() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get salvageRate => $_getN(3);
  @$pb.TagNumber(4)
  set salvageRate($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSalvageRate() => $_has(3);
  @$pb.TagNumber(4)
  void clearSalvageRate() => clearField(4);
}

class RunDepreciationRequest extends $pb.GeneratedMessage {
  factory RunDepreciationRequest({
    $core.String? assetId,
  }) {
    final $result = create();
    if (assetId != null) {
      $result.assetId = assetId;
    }
    return $result;
  }
  RunDepreciationRequest._() : super();
  factory RunDepreciationRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RunDepreciationRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RunDepreciationRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.asset.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'assetId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RunDepreciationRequest clone() => RunDepreciationRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RunDepreciationRequest copyWith(void Function(RunDepreciationRequest) updates) => super.copyWith((message) => updates(message as RunDepreciationRequest)) as RunDepreciationRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RunDepreciationRequest create() => RunDepreciationRequest._();
  RunDepreciationRequest createEmptyInstance() => create();
  static $pb.PbList<RunDepreciationRequest> createRepeated() => $pb.PbList<RunDepreciationRequest>();
  @$core.pragma('dart2js:noInline')
  static RunDepreciationRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RunDepreciationRequest>(create);
  static RunDepreciationRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get assetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set assetId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAssetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAssetId() => clearField(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
