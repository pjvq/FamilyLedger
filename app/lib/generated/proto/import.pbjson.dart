//
//  Generated code. Do not modify.
//  source: import.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use parseCSVRequestDescriptor instead')
const ParseCSVRequest$json = {
  '1': 'ParseCSVRequest',
  '2': [
    {'1': 'csv_data', '3': 1, '4': 1, '5': 12, '10': 'csvData'},
    {'1': 'encoding', '3': 2, '4': 1, '5': 9, '10': 'encoding'},
  ],
};

/// Descriptor for `ParseCSVRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List parseCSVRequestDescriptor = $convert.base64Decode(
    'Cg9QYXJzZUNTVlJlcXVlc3QSGQoIY3N2X2RhdGEYASABKAxSB2NzdkRhdGESGgoIZW5jb2Rpbm'
    'cYAiABKAlSCGVuY29kaW5n');

@$core.Deprecated('Use parseCSVResponseDescriptor instead')
const ParseCSVResponse$json = {
  '1': 'ParseCSVResponse',
  '2': [
    {'1': 'headers', '3': 1, '4': 3, '5': 9, '10': 'headers'},
    {'1': 'preview_rows', '3': 2, '4': 3, '5': 11, '6': '.familyledger.import.v1.CSVRow', '10': 'previewRows'},
    {'1': 'total_rows', '3': 3, '4': 1, '5': 5, '10': 'totalRows'},
    {'1': 'session_id', '3': 4, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `ParseCSVResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List parseCSVResponseDescriptor = $convert.base64Decode(
    'ChBQYXJzZUNTVlJlc3BvbnNlEhgKB2hlYWRlcnMYASADKAlSB2hlYWRlcnMSQQoMcHJldmlld1'
    '9yb3dzGAIgAygLMh4uZmFtaWx5bGVkZ2VyLmltcG9ydC52MS5DU1ZSb3dSC3ByZXZpZXdSb3dz'
    'Eh0KCnRvdGFsX3Jvd3MYAyABKAVSCXRvdGFsUm93cxIdCgpzZXNzaW9uX2lkGAQgASgJUglzZX'
    'NzaW9uSWQ=');

@$core.Deprecated('Use cSVRowDescriptor instead')
const CSVRow$json = {
  '1': 'CSVRow',
  '2': [
    {'1': 'values', '3': 1, '4': 3, '5': 9, '10': 'values'},
  ],
};

/// Descriptor for `CSVRow`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cSVRowDescriptor = $convert.base64Decode(
    'CgZDU1ZSb3cSFgoGdmFsdWVzGAEgAygJUgZ2YWx1ZXM=');

@$core.Deprecated('Use fieldMappingDescriptor instead')
const FieldMapping$json = {
  '1': 'FieldMapping',
  '2': [
    {'1': 'csv_column', '3': 1, '4': 1, '5': 9, '10': 'csvColumn'},
    {'1': 'target_field', '3': 2, '4': 1, '5': 9, '10': 'targetField'},
  ],
};

/// Descriptor for `FieldMapping`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fieldMappingDescriptor = $convert.base64Decode(
    'CgxGaWVsZE1hcHBpbmcSHQoKY3N2X2NvbHVtbhgBIAEoCVIJY3N2Q29sdW1uEiEKDHRhcmdldF'
    '9maWVsZBgCIAEoCVILdGFyZ2V0RmllbGQ=');

@$core.Deprecated('Use confirmImportRequestDescriptor instead')
const ConfirmImportRequest$json = {
  '1': 'ConfirmImportRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'mappings', '3': 2, '4': 3, '5': 11, '6': '.familyledger.import.v1.FieldMapping', '10': 'mappings'},
    {'1': 'default_account_id', '3': 3, '4': 1, '5': 9, '10': 'defaultAccountId'},
    {'1': 'user_id', '3': 4, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `ConfirmImportRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List confirmImportRequestDescriptor = $convert.base64Decode(
    'ChRDb25maXJtSW1wb3J0UmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSWQSQA'
    'oIbWFwcGluZ3MYAiADKAsyJC5mYW1pbHlsZWRnZXIuaW1wb3J0LnYxLkZpZWxkTWFwcGluZ1II'
    'bWFwcGluZ3MSLAoSZGVmYXVsdF9hY2NvdW50X2lkGAMgASgJUhBkZWZhdWx0QWNjb3VudElkEh'
    'cKB3VzZXJfaWQYBCABKAlSBnVzZXJJZA==');

@$core.Deprecated('Use confirmImportResponseDescriptor instead')
const ConfirmImportResponse$json = {
  '1': 'ConfirmImportResponse',
  '2': [
    {'1': 'imported_count', '3': 1, '4': 1, '5': 5, '10': 'importedCount'},
    {'1': 'skipped_count', '3': 2, '4': 1, '5': 5, '10': 'skippedCount'},
    {'1': 'errors', '3': 3, '4': 3, '5': 9, '10': 'errors'},
  ],
};

/// Descriptor for `ConfirmImportResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List confirmImportResponseDescriptor = $convert.base64Decode(
    'ChVDb25maXJtSW1wb3J0UmVzcG9uc2USJQoOaW1wb3J0ZWRfY291bnQYASABKAVSDWltcG9ydG'
    'VkQ291bnQSIwoNc2tpcHBlZF9jb3VudBgCIAEoBVIMc2tpcHBlZENvdW50EhYKBmVycm9ycxgD'
    'IAMoCVIGZXJyb3Jz');

