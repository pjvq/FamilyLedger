//
//  Generated code. Do not modify.
//  source: sync.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use operationTypeDescriptor instead')
const OperationType$json = {
  '1': 'OperationType',
  '2': [
    {'1': 'OPERATION_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'OPERATION_TYPE_CREATE', '2': 1},
    {'1': 'OPERATION_TYPE_UPDATE', '2': 2},
    {'1': 'OPERATION_TYPE_DELETE', '2': 3},
  ],
};

/// Descriptor for `OperationType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List operationTypeDescriptor = $convert.base64Decode(
    'Cg1PcGVyYXRpb25UeXBlEh4KGk9QRVJBVElPTl9UWVBFX1VOU1BFQ0lGSUVEEAASGQoVT1BFUk'
    'FUSU9OX1RZUEVfQ1JFQVRFEAESGQoVT1BFUkFUSU9OX1RZUEVfVVBEQVRFEAISGQoVT1BFUkFU'
    'SU9OX1RZUEVfREVMRVRFEAM=');

@$core.Deprecated('Use syncOperationDescriptor instead')
const SyncOperation$json = {
  '1': 'SyncOperation',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'entity_type', '3': 2, '4': 1, '5': 9, '10': 'entityType'},
    {'1': 'entity_id', '3': 3, '4': 1, '5': 9, '10': 'entityId'},
    {'1': 'op_type', '3': 4, '4': 1, '5': 14, '6': '.familyledger.sync.v1.OperationType', '10': 'opType'},
    {'1': 'payload', '3': 5, '4': 1, '5': 9, '10': 'payload'},
    {'1': 'client_id', '3': 6, '4': 1, '5': 9, '10': 'clientId'},
    {'1': 'timestamp', '3': 7, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'timestamp'},
  ],
};

/// Descriptor for `SyncOperation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncOperationDescriptor = $convert.base64Decode(
    'Cg1TeW5jT3BlcmF0aW9uEg4KAmlkGAEgASgJUgJpZBIfCgtlbnRpdHlfdHlwZRgCIAEoCVIKZW'
    '50aXR5VHlwZRIbCgllbnRpdHlfaWQYAyABKAlSCGVudGl0eUlkEjwKB29wX3R5cGUYBCABKA4y'
    'Iy5mYW1pbHlsZWRnZXIuc3luYy52MS5PcGVyYXRpb25UeXBlUgZvcFR5cGUSGAoHcGF5bG9hZB'
    'gFIAEoCVIHcGF5bG9hZBIbCgljbGllbnRfaWQYBiABKAlSCGNsaWVudElkEjgKCXRpbWVzdGFt'
    'cBgHIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCXRpbWVzdGFtcA==');

@$core.Deprecated('Use pushOperationsRequestDescriptor instead')
const PushOperationsRequest$json = {
  '1': 'PushOperationsRequest',
  '2': [
    {'1': 'operations', '3': 1, '4': 3, '5': 11, '6': '.familyledger.sync.v1.SyncOperation', '10': 'operations'},
  ],
};

/// Descriptor for `PushOperationsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pushOperationsRequestDescriptor = $convert.base64Decode(
    'ChVQdXNoT3BlcmF0aW9uc1JlcXVlc3QSQwoKb3BlcmF0aW9ucxgBIAMoCzIjLmZhbWlseWxlZG'
    'dlci5zeW5jLnYxLlN5bmNPcGVyYXRpb25SCm9wZXJhdGlvbnM=');

@$core.Deprecated('Use pushOperationsResponseDescriptor instead')
const PushOperationsResponse$json = {
  '1': 'PushOperationsResponse',
  '2': [
    {'1': 'accepted_count', '3': 1, '4': 1, '5': 5, '10': 'acceptedCount'},
    {'1': 'failed_ids', '3': 2, '4': 3, '5': 9, '10': 'failedIds'},
  ],
};

/// Descriptor for `PushOperationsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pushOperationsResponseDescriptor = $convert.base64Decode(
    'ChZQdXNoT3BlcmF0aW9uc1Jlc3BvbnNlEiUKDmFjY2VwdGVkX2NvdW50GAEgASgFUg1hY2NlcH'
    'RlZENvdW50Eh0KCmZhaWxlZF9pZHMYAiADKAlSCWZhaWxlZElkcw==');

@$core.Deprecated('Use pullChangesRequestDescriptor instead')
const PullChangesRequest$json = {
  '1': 'PullChangesRequest',
  '2': [
    {'1': 'since', '3': 1, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'since'},
    {'1': 'client_id', '3': 2, '4': 1, '5': 9, '10': 'clientId'},
  ],
};

/// Descriptor for `PullChangesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pullChangesRequestDescriptor = $convert.base64Decode(
    'ChJQdWxsQ2hhbmdlc1JlcXVlc3QSMAoFc2luY2UYASABKAsyGi5nb29nbGUucHJvdG9idWYuVG'
    'ltZXN0YW1wUgVzaW5jZRIbCgljbGllbnRfaWQYAiABKAlSCGNsaWVudElk');

@$core.Deprecated('Use pullChangesResponseDescriptor instead')
const PullChangesResponse$json = {
  '1': 'PullChangesResponse',
  '2': [
    {'1': 'operations', '3': 1, '4': 3, '5': 11, '6': '.familyledger.sync.v1.SyncOperation', '10': 'operations'},
    {'1': 'server_time', '3': 2, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'serverTime'},
  ],
};

/// Descriptor for `PullChangesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pullChangesResponseDescriptor = $convert.base64Decode(
    'ChNQdWxsQ2hhbmdlc1Jlc3BvbnNlEkMKCm9wZXJhdGlvbnMYASADKAsyIy5mYW1pbHlsZWRnZX'
    'Iuc3luYy52MS5TeW5jT3BlcmF0aW9uUgpvcGVyYXRpb25zEjsKC3NlcnZlcl90aW1lGAIgASgL'
    'MhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIKc2VydmVyVGltZQ==');

