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

import 'package:protobuf/protobuf.dart' as $pb;

class AssetType extends $pb.ProtobufEnum {
  static const AssetType ASSET_TYPE_UNSPECIFIED = AssetType._(0, _omitEnumNames ? '' : 'ASSET_TYPE_UNSPECIFIED');
  static const AssetType ASSET_TYPE_REAL_ESTATE = AssetType._(1, _omitEnumNames ? '' : 'ASSET_TYPE_REAL_ESTATE');
  static const AssetType ASSET_TYPE_VEHICLE = AssetType._(2, _omitEnumNames ? '' : 'ASSET_TYPE_VEHICLE');
  static const AssetType ASSET_TYPE_ELECTRONICS = AssetType._(3, _omitEnumNames ? '' : 'ASSET_TYPE_ELECTRONICS');
  static const AssetType ASSET_TYPE_FURNITURE = AssetType._(4, _omitEnumNames ? '' : 'ASSET_TYPE_FURNITURE');
  static const AssetType ASSET_TYPE_JEWELRY = AssetType._(5, _omitEnumNames ? '' : 'ASSET_TYPE_JEWELRY');
  static const AssetType ASSET_TYPE_OTHER = AssetType._(6, _omitEnumNames ? '' : 'ASSET_TYPE_OTHER');

  static const $core.List<AssetType> values = <AssetType> [
    ASSET_TYPE_UNSPECIFIED,
    ASSET_TYPE_REAL_ESTATE,
    ASSET_TYPE_VEHICLE,
    ASSET_TYPE_ELECTRONICS,
    ASSET_TYPE_FURNITURE,
    ASSET_TYPE_JEWELRY,
    ASSET_TYPE_OTHER,
  ];

  static final $core.Map<$core.int, AssetType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static AssetType? valueOf($core.int value) => _byValue[value];

  const AssetType._($core.int v, $core.String n) : super(v, n);
}

class DepreciationMethod extends $pb.ProtobufEnum {
  static const DepreciationMethod DEPRECIATION_METHOD_UNSPECIFIED = DepreciationMethod._(0, _omitEnumNames ? '' : 'DEPRECIATION_METHOD_UNSPECIFIED');
  static const DepreciationMethod DEPRECIATION_METHOD_STRAIGHT_LINE = DepreciationMethod._(1, _omitEnumNames ? '' : 'DEPRECIATION_METHOD_STRAIGHT_LINE');
  static const DepreciationMethod DEPRECIATION_METHOD_DOUBLE_DECLINING = DepreciationMethod._(2, _omitEnumNames ? '' : 'DEPRECIATION_METHOD_DOUBLE_DECLINING');
  static const DepreciationMethod DEPRECIATION_METHOD_NONE = DepreciationMethod._(3, _omitEnumNames ? '' : 'DEPRECIATION_METHOD_NONE');

  static const $core.List<DepreciationMethod> values = <DepreciationMethod> [
    DEPRECIATION_METHOD_UNSPECIFIED,
    DEPRECIATION_METHOD_STRAIGHT_LINE,
    DEPRECIATION_METHOD_DOUBLE_DECLINING,
    DEPRECIATION_METHOD_NONE,
  ];

  static final $core.Map<$core.int, DepreciationMethod> _byValue = $pb.ProtobufEnum.initByValue(values);
  static DepreciationMethod? valueOf($core.int value) => _byValue[value];

  const DepreciationMethod._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
