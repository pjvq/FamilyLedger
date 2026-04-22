//
//  Generated code. Do not modify.
//  source: asset.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use assetTypeDescriptor instead')
const AssetType$json = {
  '1': 'AssetType',
  '2': [
    {'1': 'ASSET_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'ASSET_TYPE_REAL_ESTATE', '2': 1},
    {'1': 'ASSET_TYPE_VEHICLE', '2': 2},
    {'1': 'ASSET_TYPE_ELECTRONICS', '2': 3},
    {'1': 'ASSET_TYPE_FURNITURE', '2': 4},
    {'1': 'ASSET_TYPE_JEWELRY', '2': 5},
    {'1': 'ASSET_TYPE_OTHER', '2': 6},
  ],
};

/// Descriptor for `AssetType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List assetTypeDescriptor = $convert.base64Decode(
    'CglBc3NldFR5cGUSGgoWQVNTRVRfVFlQRV9VTlNQRUNJRklFRBAAEhoKFkFTU0VUX1RZUEVfUk'
    'VBTF9FU1RBVEUQARIWChJBU1NFVF9UWVBFX1ZFSElDTEUQAhIaChZBU1NFVF9UWVBFX0VMRUNU'
    'Uk9OSUNTEAMSGAoUQVNTRVRfVFlQRV9GVVJOSVRVUkUQBBIWChJBU1NFVF9UWVBFX0pFV0VMUl'
    'kQBRIUChBBU1NFVF9UWVBFX09USEVSEAY=');

@$core.Deprecated('Use depreciationMethodDescriptor instead')
const DepreciationMethod$json = {
  '1': 'DepreciationMethod',
  '2': [
    {'1': 'DEPRECIATION_METHOD_UNSPECIFIED', '2': 0},
    {'1': 'DEPRECIATION_METHOD_STRAIGHT_LINE', '2': 1},
    {'1': 'DEPRECIATION_METHOD_DOUBLE_DECLINING', '2': 2},
    {'1': 'DEPRECIATION_METHOD_NONE', '2': 3},
  ],
};

/// Descriptor for `DepreciationMethod`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List depreciationMethodDescriptor = $convert.base64Decode(
    'ChJEZXByZWNpYXRpb25NZXRob2QSIwofREVQUkVDSUFUSU9OX01FVEhPRF9VTlNQRUNJRklFRB'
    'AAEiUKIURFUFJFQ0lBVElPTl9NRVRIT0RfU1RSQUlHSFRfTElORRABEigKJERFUFJFQ0lBVElP'
    'Tl9NRVRIT0RfRE9VQkxFX0RFQ0xJTklORxACEhwKGERFUFJFQ0lBVElPTl9NRVRIT0RfTk9ORR'
    'AD');

@$core.Deprecated('Use assetDescriptor instead')
const Asset$json = {
  '1': 'Asset',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'asset_type', '3': 4, '4': 1, '5': 14, '6': '.familyledger.asset.v1.AssetType', '10': 'assetType'},
    {'1': 'purchase_price', '3': 5, '4': 1, '5': 3, '10': 'purchasePrice'},
    {'1': 'current_value', '3': 6, '4': 1, '5': 3, '10': 'currentValue'},
    {'1': 'purchase_date', '3': 7, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'purchaseDate'},
    {'1': 'description', '3': 8, '4': 1, '5': 9, '10': 'description'},
    {'1': 'created_at', '3': 9, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'createdAt'},
    {'1': 'updated_at', '3': 10, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'updatedAt'},
  ],
};

/// Descriptor for `Asset`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assetDescriptor = $convert.base64Decode(
    'CgVBc3NldBIOCgJpZBgBIAEoCVICaWQSFwoHdXNlcl9pZBgCIAEoCVIGdXNlcklkEhIKBG5hbW'
    'UYAyABKAlSBG5hbWUSPwoKYXNzZXRfdHlwZRgEIAEoDjIgLmZhbWlseWxlZGdlci5hc3NldC52'
    'MS5Bc3NldFR5cGVSCWFzc2V0VHlwZRIlCg5wdXJjaGFzZV9wcmljZRgFIAEoA1INcHVyY2hhc2'
    'VQcmljZRIjCg1jdXJyZW50X3ZhbHVlGAYgASgDUgxjdXJyZW50VmFsdWUSPwoNcHVyY2hhc2Vf'
    'ZGF0ZRgHIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSDHB1cmNoYXNlRGF0ZRIgCg'
    'tkZXNjcmlwdGlvbhgIIAEoCVILZGVzY3JpcHRpb24SOQoKY3JlYXRlZF9hdBgJIAEoCzIaLmdv'
    'b2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCWNyZWF0ZWRBdBI5Cgp1cGRhdGVkX2F0GAogASgLMh'
    'ouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJdXBkYXRlZEF0');

@$core.Deprecated('Use assetValuationDescriptor instead')
const AssetValuation$json = {
  '1': 'AssetValuation',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'asset_id', '3': 2, '4': 1, '5': 9, '10': 'assetId'},
    {'1': 'value', '3': 3, '4': 1, '5': 3, '10': 'value'},
    {'1': 'source', '3': 4, '4': 1, '5': 9, '10': 'source'},
    {'1': 'valuation_date', '3': 5, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'valuationDate'},
  ],
};

/// Descriptor for `AssetValuation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assetValuationDescriptor = $convert.base64Decode(
    'Cg5Bc3NldFZhbHVhdGlvbhIOCgJpZBgBIAEoCVICaWQSGQoIYXNzZXRfaWQYAiABKAlSB2Fzc2'
    'V0SWQSFAoFdmFsdWUYAyABKANSBXZhbHVlEhYKBnNvdXJjZRgEIAEoCVIGc291cmNlEkEKDnZh'
    'bHVhdGlvbl9kYXRlGAUgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFINdmFsdWF0aW'
    '9uRGF0ZQ==');

@$core.Deprecated('Use depreciationRuleDescriptor instead')
const DepreciationRule$json = {
  '1': 'DepreciationRule',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'asset_id', '3': 2, '4': 1, '5': 9, '10': 'assetId'},
    {'1': 'method', '3': 3, '4': 1, '5': 14, '6': '.familyledger.asset.v1.DepreciationMethod', '10': 'method'},
    {'1': 'useful_life_years', '3': 4, '4': 1, '5': 5, '10': 'usefulLifeYears'},
    {'1': 'salvage_rate', '3': 5, '4': 1, '5': 1, '10': 'salvageRate'},
    {'1': 'created_at', '3': 6, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'createdAt'},
  ],
};

/// Descriptor for `DepreciationRule`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List depreciationRuleDescriptor = $convert.base64Decode(
    'ChBEZXByZWNpYXRpb25SdWxlEg4KAmlkGAEgASgJUgJpZBIZCghhc3NldF9pZBgCIAEoCVIHYX'
    'NzZXRJZBJBCgZtZXRob2QYAyABKA4yKS5mYW1pbHlsZWRnZXIuYXNzZXQudjEuRGVwcmVjaWF0'
    'aW9uTWV0aG9kUgZtZXRob2QSKgoRdXNlZnVsX2xpZmVfeWVhcnMYBCABKAVSD3VzZWZ1bExpZm'
    'VZZWFycxIhCgxzYWx2YWdlX3JhdGUYBSABKAFSC3NhbHZhZ2VSYXRlEjkKCmNyZWF0ZWRfYXQY'
    'BiABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgljcmVhdGVkQXQ=');

@$core.Deprecated('Use createAssetRequestDescriptor instead')
const CreateAssetRequest$json = {
  '1': 'CreateAssetRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'asset_type', '3': 2, '4': 1, '5': 14, '6': '.familyledger.asset.v1.AssetType', '10': 'assetType'},
    {'1': 'purchase_price', '3': 3, '4': 1, '5': 3, '10': 'purchasePrice'},
    {'1': 'purchase_date', '3': 4, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'purchaseDate'},
    {'1': 'description', '3': 5, '4': 1, '5': 9, '10': 'description'},
  ],
};

/// Descriptor for `CreateAssetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createAssetRequestDescriptor = $convert.base64Decode(
    'ChJDcmVhdGVBc3NldFJlcXVlc3QSEgoEbmFtZRgBIAEoCVIEbmFtZRI/Cgphc3NldF90eXBlGA'
    'IgASgOMiAuZmFtaWx5bGVkZ2VyLmFzc2V0LnYxLkFzc2V0VHlwZVIJYXNzZXRUeXBlEiUKDnB1'
    'cmNoYXNlX3ByaWNlGAMgASgDUg1wdXJjaGFzZVByaWNlEj8KDXB1cmNoYXNlX2RhdGUYBCABKA'
    'syGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgxwdXJjaGFzZURhdGUSIAoLZGVzY3JpcHRp'
    'b24YBSABKAlSC2Rlc2NyaXB0aW9u');

@$core.Deprecated('Use getAssetRequestDescriptor instead')
const GetAssetRequest$json = {
  '1': 'GetAssetRequest',
  '2': [
    {'1': 'asset_id', '3': 1, '4': 1, '5': 9, '10': 'assetId'},
  ],
};

/// Descriptor for `GetAssetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAssetRequestDescriptor = $convert.base64Decode(
    'Cg9HZXRBc3NldFJlcXVlc3QSGQoIYXNzZXRfaWQYASABKAlSB2Fzc2V0SWQ=');

@$core.Deprecated('Use listAssetsRequestDescriptor instead')
const ListAssetsRequest$json = {
  '1': 'ListAssetsRequest',
  '2': [
    {'1': 'asset_type', '3': 1, '4': 1, '5': 14, '6': '.familyledger.asset.v1.AssetType', '10': 'assetType'},
  ],
};

/// Descriptor for `ListAssetsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAssetsRequestDescriptor = $convert.base64Decode(
    'ChFMaXN0QXNzZXRzUmVxdWVzdBI/Cgphc3NldF90eXBlGAEgASgOMiAuZmFtaWx5bGVkZ2VyLm'
    'Fzc2V0LnYxLkFzc2V0VHlwZVIJYXNzZXRUeXBl');

@$core.Deprecated('Use listAssetsResponseDescriptor instead')
const ListAssetsResponse$json = {
  '1': 'ListAssetsResponse',
  '2': [
    {'1': 'assets', '3': 1, '4': 3, '5': 11, '6': '.familyledger.asset.v1.Asset', '10': 'assets'},
  ],
};

/// Descriptor for `ListAssetsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAssetsResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0QXNzZXRzUmVzcG9uc2USNAoGYXNzZXRzGAEgAygLMhwuZmFtaWx5bGVkZ2VyLmFzc2'
    'V0LnYxLkFzc2V0UgZhc3NldHM=');

@$core.Deprecated('Use updateAssetRequestDescriptor instead')
const UpdateAssetRequest$json = {
  '1': 'UpdateAssetRequest',
  '2': [
    {'1': 'asset_id', '3': 1, '4': 1, '5': 9, '10': 'assetId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
  ],
};

/// Descriptor for `UpdateAssetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateAssetRequestDescriptor = $convert.base64Decode(
    'ChJVcGRhdGVBc3NldFJlcXVlc3QSGQoIYXNzZXRfaWQYASABKAlSB2Fzc2V0SWQSEgoEbmFtZR'
    'gCIAEoCVIEbmFtZRIgCgtkZXNjcmlwdGlvbhgDIAEoCVILZGVzY3JpcHRpb24=');

@$core.Deprecated('Use deleteAssetRequestDescriptor instead')
const DeleteAssetRequest$json = {
  '1': 'DeleteAssetRequest',
  '2': [
    {'1': 'asset_id', '3': 1, '4': 1, '5': 9, '10': 'assetId'},
  ],
};

/// Descriptor for `DeleteAssetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteAssetRequestDescriptor = $convert.base64Decode(
    'ChJEZWxldGVBc3NldFJlcXVlc3QSGQoIYXNzZXRfaWQYASABKAlSB2Fzc2V0SWQ=');

@$core.Deprecated('Use updateValuationRequestDescriptor instead')
const UpdateValuationRequest$json = {
  '1': 'UpdateValuationRequest',
  '2': [
    {'1': 'asset_id', '3': 1, '4': 1, '5': 9, '10': 'assetId'},
    {'1': 'value', '3': 2, '4': 1, '5': 3, '10': 'value'},
    {'1': 'source', '3': 3, '4': 1, '5': 9, '10': 'source'},
  ],
};

/// Descriptor for `UpdateValuationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateValuationRequestDescriptor = $convert.base64Decode(
    'ChZVcGRhdGVWYWx1YXRpb25SZXF1ZXN0EhkKCGFzc2V0X2lkGAEgASgJUgdhc3NldElkEhQKBX'
    'ZhbHVlGAIgASgDUgV2YWx1ZRIWCgZzb3VyY2UYAyABKAlSBnNvdXJjZQ==');

@$core.Deprecated('Use listValuationsRequestDescriptor instead')
const ListValuationsRequest$json = {
  '1': 'ListValuationsRequest',
  '2': [
    {'1': 'asset_id', '3': 1, '4': 1, '5': 9, '10': 'assetId'},
  ],
};

/// Descriptor for `ListValuationsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listValuationsRequestDescriptor = $convert.base64Decode(
    'ChVMaXN0VmFsdWF0aW9uc1JlcXVlc3QSGQoIYXNzZXRfaWQYASABKAlSB2Fzc2V0SWQ=');

@$core.Deprecated('Use listValuationsResponseDescriptor instead')
const ListValuationsResponse$json = {
  '1': 'ListValuationsResponse',
  '2': [
    {'1': 'valuations', '3': 1, '4': 3, '5': 11, '6': '.familyledger.asset.v1.AssetValuation', '10': 'valuations'},
  ],
};

/// Descriptor for `ListValuationsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listValuationsResponseDescriptor = $convert.base64Decode(
    'ChZMaXN0VmFsdWF0aW9uc1Jlc3BvbnNlEkUKCnZhbHVhdGlvbnMYASADKAsyJS5mYW1pbHlsZW'
    'RnZXIuYXNzZXQudjEuQXNzZXRWYWx1YXRpb25SCnZhbHVhdGlvbnM=');

@$core.Deprecated('Use setDepreciationRuleRequestDescriptor instead')
const SetDepreciationRuleRequest$json = {
  '1': 'SetDepreciationRuleRequest',
  '2': [
    {'1': 'asset_id', '3': 1, '4': 1, '5': 9, '10': 'assetId'},
    {'1': 'method', '3': 2, '4': 1, '5': 14, '6': '.familyledger.asset.v1.DepreciationMethod', '10': 'method'},
    {'1': 'useful_life_years', '3': 3, '4': 1, '5': 5, '10': 'usefulLifeYears'},
    {'1': 'salvage_rate', '3': 4, '4': 1, '5': 1, '10': 'salvageRate'},
  ],
};

/// Descriptor for `SetDepreciationRuleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDepreciationRuleRequestDescriptor = $convert.base64Decode(
    'ChpTZXREZXByZWNpYXRpb25SdWxlUmVxdWVzdBIZCghhc3NldF9pZBgBIAEoCVIHYXNzZXRJZB'
    'JBCgZtZXRob2QYAiABKA4yKS5mYW1pbHlsZWRnZXIuYXNzZXQudjEuRGVwcmVjaWF0aW9uTWV0'
    'aG9kUgZtZXRob2QSKgoRdXNlZnVsX2xpZmVfeWVhcnMYAyABKAVSD3VzZWZ1bExpZmVZZWFycx'
    'IhCgxzYWx2YWdlX3JhdGUYBCABKAFSC3NhbHZhZ2VSYXRl');

@$core.Deprecated('Use runDepreciationRequestDescriptor instead')
const RunDepreciationRequest$json = {
  '1': 'RunDepreciationRequest',
  '2': [
    {'1': 'asset_id', '3': 1, '4': 1, '5': 9, '10': 'assetId'},
  ],
};

/// Descriptor for `RunDepreciationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List runDepreciationRequestDescriptor = $convert.base64Decode(
    'ChZSdW5EZXByZWNpYXRpb25SZXF1ZXN0EhkKCGFzc2V0X2lkGAEgASgJUgdhc3NldElk');

